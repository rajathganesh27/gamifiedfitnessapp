import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:gamifiedfitnessapp/model/exercise_dart_model.dart';
import 'package:gamifiedfitnessapp/pose_painter.dart';

class DetectionScreen extends StatefulWidget {
  final ExerciseDataModel exerciseDataModel;
  final List<CameraDescription> cameras;

  DetectionScreen({required this.exerciseDataModel, required this.cameras});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  late CameraController controller;
  late PoseDetector poseDetector;
  CameraImage? img;
  List<Pose> _scanResults = [];
  bool isBusy = false;
  Size? screenSize;

  // Repetition counters
  int pushUpCount = 0;
  int squatCount = 0;
  int plankToDownwardDogCount = 0;
  int jumpingJackCount = 0;

  // State flags
  bool isLowered = false;
  bool isSquatting = false;
  bool isInDownwardDog = false;
  bool isJumpingJackOpen = false;

  @override
  void initState() {
    super.initState();
    initPoseDetector();
    initCamera();
  }

  void initPoseDetector() {
    final options = PoseDetectorOptions(mode: PoseDetectionMode.stream);
    poseDetector = PoseDetector(options: options);
  }

  void initCamera() async {
    controller = CameraController(
      widget.cameras[0],
      ResolutionPreset.medium,
      imageFormatGroup:
          Platform.isAndroid
              ? ImageFormatGroup.nv21
              : ImageFormatGroup.bgra8888,
    );

    await controller.initialize();

    if (!mounted) return;

    controller.startImageStream((CameraImage image) async {
      if (!isBusy) {
        isBusy = true;
        img = image;
        await processImage();
        isBusy = false;
      }
    });

    setState(() {});
  }

  Future<void> processImage() async {
    final inputImage = _inputImageFromCameraImage();
    if (inputImage == null) return;

    final poses = await poseDetector.processImage(inputImage);
    _scanResults = poses;

    if (poses.isNotEmpty) {
      final landmarks = poses.first.landmarks;
      switch (widget.exerciseDataModel.type) {
        case ExerciseType.PushUps:
          detectPushUp(landmarks);
          break;
        case ExerciseType.Squats:
          detectSquat(landmarks);
          break;
        case ExerciseType.DownwardDogPlank:
          detectPlankToDownwardDog(poses.first);
          break;
        case ExerciseType.JumpingJack:
          detectJumpingJack(poses.first);
          break;
      }
    }

    setState(() {});
  }

  InputImage? _inputImageFromCameraImage() {
    if (img == null) return null;

    final camera = widget.cameras[0];
    final sensorOrientation = camera.sensorOrientation;

    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    final format = InputImageFormatValue.fromRawValue(img!.format.raw);
    if (rotation == null || format == null) return null;

    final plane = img!.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(img!.width.toDouble(), img!.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  int lastPushUpTimestamp = DateTime.now().millisecondsSinceEpoch;

  void detectPushUp(Map<PoseLandmarkType, PoseLandmark> l) {
    final s = l[PoseLandmarkType.leftShoulder];
    final e = l[PoseLandmarkType.leftElbow];
    final w = l[PoseLandmarkType.leftWrist];
    final h = l[PoseLandmarkType.leftHip];
    final k = l[PoseLandmarkType.leftKnee];

    if (s == null || e == null || w == null || h == null || k == null) return;

    final elbowAngle = calculateAngle(s, e, w);
    final torsoAngle = calculateAngle(s, h, k);

    // Debug output
    print("Elbow: $elbowAngle, Torso: $torsoAngle");

    int now = DateTime.now().millisecondsSinceEpoch;

    if (elbowAngle < 90 && torsoAngle > 160) {
      isLowered = true;
    } else if (elbowAngle > 160 && isLowered) {
      // Only count if at least 600ms passed since last push-up
      if (now - lastPushUpTimestamp > 600) {
        pushUpCount++;
        print("✔️ Push-up counted: $pushUpCount");
        lastPushUpTimestamp = now;
      }
      isLowered = false;
    }
  }

  void detectSquat(Map<PoseLandmarkType, PoseLandmark> l) {
    final h = l[PoseLandmarkType.leftHip];
    final k = l[PoseLandmarkType.leftKnee];
    final a = l[PoseLandmarkType.leftAnkle];
    if (h == null || k == null || a == null) return;

    final angle = calculateAngle(h, k, a);
    if (angle < 90) {
      isSquatting = true;
    } else if (angle > 160 && isSquatting) {
      squatCount++;
      isSquatting = false;
    }
  }

  void detectPlankToDownwardDog(Pose pose) {
    final h = pose.landmarks[PoseLandmarkType.leftHip];
    final s = pose.landmarks[PoseLandmarkType.leftShoulder];
    final a = pose.landmarks[PoseLandmarkType.leftAnkle];
    if (h == null || s == null || a == null) return;

    if ((h.y < s.y - 50) && (a.y > h.y)) {
      isInDownwardDog = true;
    } else if ((h.y - s.y).abs() < 30 && isInDownwardDog) {
      plankToDownwardDogCount++;
      isInDownwardDog = false;
    }
  }

  void detectJumpingJack(Pose pose) {
    final lw = pose.landmarks[PoseLandmarkType.leftWrist];
    final rw = pose.landmarks[PoseLandmarkType.rightWrist];
    final la = pose.landmarks[PoseLandmarkType.leftAnkle];
    final ra = pose.landmarks[PoseLandmarkType.rightAnkle];
    final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rs = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (lw == null ||
        rw == null ||
        la == null ||
        ra == null ||
        ls == null ||
        rs == null)
      return;

    double shoulderWidth = (rs.x - ls.x).abs();
    double legSpread = (ra.x - la.x).abs();
    double armHeight = (lw.y + rw.y) / 2;

    if (armHeight < ls.y - 40 && legSpread > shoulderWidth * 1.2) {
      isJumpingJackOpen = true;
    } else if (armHeight > ls.y + 40 &&
        legSpread < shoulderWidth * 0.8 &&
        isJumpingJackOpen) {
      jumpingJackCount++;
      isJumpingJackOpen = false;
    }
  }

  double calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    double ab = distance(a, b);
    double bc = distance(b, c);
    double ac = distance(a, c);
    return acos((ab * ab + bc * bc - ac * ac) / (2 * ab * bc)) * (180 / pi);
  }

  double distance(PoseLandmark a, PoseLandmark b) {
    return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2));
  }

  @override
  void dispose() {
    controller.dispose();
    poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count =
        widget.exerciseDataModel.type == ExerciseType.PushUps
            ? pushUpCount
            : widget.exerciseDataModel.type == ExerciseType.Squats
            ? squatCount
            : widget.exerciseDataModel.type == ExerciseType.DownwardDogPlank
            ? plankToDownwardDogCount
            : jumpingJackCount;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (controller.value.isInitialized)
            Positioned.fill(child: CameraPreview(controller)),
          if (_scanResults.isNotEmpty)
            Positioned.fill(
              child: CustomPaint(
                painter: PosePainter(
                  Size(
                    controller.value.previewSize!.height,
                    controller.value.previewSize!.width,
                  ),
                  _scanResults,
                ),
              ),
            ),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: EdgeInsets.only(top: 50),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: widget.exerciseDataModel.color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.exerciseDataModel.title,
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  SizedBox(width: 10),
                  Image.asset(
                    'assets/${widget.exerciseDataModel.image}',
                    height: 40,
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: EdgeInsets.only(bottom: 30),
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: widget.exerciseDataModel.color,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  "$count",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
