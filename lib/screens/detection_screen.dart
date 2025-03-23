import 'dart:io';
import 'dart:math';
import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamifiedfitnessapp/model/exercise_dart_model.dart';
import 'package:gamifiedfitnessapp/pose_painter.dart';
import 'package:gamifiedfitnessapp/screens/squat_game.dart';
import 'package:gamifiedfitnessapp/screens/jumping_jack_game.dart';
import 'package:gamifiedfitnessapp/screens/bicep_curl_game.dart'; // Import the bicep curl game
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:gamifiedfitnessapp/screens/pushup_game.dart';

class DetectionScreen extends StatefulWidget {
  final ExerciseDataModel exerciseDataModel;
  final List<CameraDescription> cameras;
  final isLoweredStreamController = StreamController<bool>.broadcast();
  DetectionScreen({required this.exerciseDataModel, required this.cameras});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
  // void dispose() {
  //   // Add the new stream to the dispose method
  //   _isLoweredStreamController.close();
  //   super.dispose();
  // }
}

class _DetectionScreenState extends State<DetectionScreen> {
  dynamic controller;
  bool isBusy = false;
  late Size size;

  // Pose detector
  late PoseDetector poseDetector;

  // State for showing game
  bool _showGame = false;
  final _isSquattingStreamController = StreamController<bool>.broadcast();
  // Stream for jumping jack hand positions
  final _landmarksStreamController =
      StreamController<Map<PoseLandmarkType, PoseLandmark>>.broadcast();
  // Stream for bicep curl state
  final _isCurlingStreamController = StreamController<bool>.broadcast();
  final _isLoweredStreamController = StreamController<bool>.broadcast();
  // Track current camera index
  int _currentCameraIndex = 1; // Default to front camera (index 1)

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  // Initialize the camera feed
  initializeCamera() async {
    // Initialize detector
    final options = PoseDetectorOptions(mode: PoseDetectionMode.stream);
    poseDetector = PoseDetector(options: options);

    controller = CameraController(
      widget.cameras[_currentCameraIndex],
      ResolutionPreset.medium,
      imageFormatGroup:
          Platform.isAndroid
              ? ImageFormatGroup.nv21
              : ImageFormatGroup.bgra8888,
    );
    await controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      controller.startImageStream(
        (image) => {
          if (!isBusy) {isBusy = true, img = image, doPoseEstimationOnFrame()},
        },
      );
    });
  }

  // Handle camera toggle
  void toggleCamera(CameraLensDirection direction) async {
    if (controller != null) {
      await controller.stopImageStream();
      await controller.dispose();
    }

    // Find the camera index with the requested direction
    int newIndex = widget.cameras.indexWhere(
      (camera) => camera.lensDirection == direction,
    );

    if (newIndex != -1) {
      _currentCameraIndex = newIndex;

      controller = CameraController(
        widget.cameras[_currentCameraIndex],
        ResolutionPreset.medium,
        imageFormatGroup:
            Platform.isAndroid
                ? ImageFormatGroup.nv21
                : ImageFormatGroup.bgra8888,
      );

      try {
        await controller.initialize();
        if (mounted) {
          controller.startImageStream(
            (image) => {
              if (!isBusy)
                {isBusy = true, img = image, doPoseEstimationOnFrame()},
            },
          );
          setState(() {});
        }
      } catch (e) {
        print("Error toggling camera: $e");
      }
    }
  }

  // Pose detection on a frame
  dynamic _scanResults;
  CameraImage? img;
  doPoseEstimationOnFrame() async {
    var inputImage = _inputImageFromCameraImage();
    if (inputImage != null) {
      final List<Pose> poses = await poseDetector.processImage(inputImage!);
      print("pose=" + poses.length.toString());
      _scanResults = poses;
      if (poses.length > 0) {
        if (widget.exerciseDataModel.type == ExerciseType.PushUps) {
          detectPushUp(poses.first.landmarks);
        } else if (widget.exerciseDataModel.type == ExerciseType.Squats) {
          detectSquat(poses.first.landmarks);
          // Stream squatting state for the game
          if (isSquatting) {
            _isSquattingStreamController.add(true);
          } else {
            _isSquattingStreamController.add(false);
          }
        } else if (widget.exerciseDataModel.type ==
            ExerciseType.DownwardDogPlank) {
          detectPlankToDownwardDog(poses.first);
        } else if (widget.exerciseDataModel.type == ExerciseType.JumpingJack) {
          detectJumpingJack(poses.first);
          // Stream landmarks for the jumping jack game
          _landmarksStreamController.add(poses.first.landmarks);
        } else if (widget.exerciseDataModel.type == ExerciseType.BicepCurl) {
          detectBicepCurl(poses.first.landmarks);
          // Stream curling state for the game
          if (isCurling) {
            _isCurlingStreamController.add(true);
          } else {
            _isCurlingStreamController.add(false);
          }
        }
      }
    }
    setState(() {
      _scanResults;
      isBusy = false;
    });
  }

  // Close all resources
  @override
  void dispose() {
    controller?.dispose();
    poseDetector.close();
    _isSquattingStreamController.close();
    _landmarksStreamController.close();
    _isCurlingStreamController.close();
    _isLoweredStreamController.close(); // ✅ Local stream closed
    widget.isLoweredStreamController.close(); // existing one
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> stackChildren = [];
    size = MediaQuery.of(context).size;

    // If showing the game, render the appropriate game screen
    if (_showGame) {
      if (widget.exerciseDataModel.type == ExerciseType.Squats) {
        return Scaffold(
          body: SquatGame(
            isSquattingStream: _isSquattingStreamController.stream,
            cameraController: controller,
            poseResults: _scanResults,
            onGameComplete: (score) {
              setState(() {
                _showGame = false;
              });
            },
            onCameraToggle: (direction) {
              toggleCamera(direction);
            },
          ),
        );
      } else if (widget.exerciseDataModel.type == ExerciseType.PushUps) {
        return Scaffold(
          body: PushUpGame(
            isLoweredStream:
                _isLoweredStreamController.stream, // ✅ Local stream here
            cameraController: controller,
            poseResults: _scanResults,
            onGameComplete: (score) {
              print("Game completed with score: $score");
              setState(() {
                _showGame = false;
              });
            },
            onCameraToggle: (direction) {
              toggleCamera(direction);
            },
          ),
        );
      } else if (widget.exerciseDataModel.type == ExerciseType.JumpingJack) {
        return Scaffold(
          body: JumpingJackGame(
            landmarksStream: _landmarksStreamController.stream,
            cameraController: controller,
            poseResults: _scanResults,
            onGameComplete: (score) {
              setState(() {
                _showGame = false;
              });
            },
            onCameraToggle: (direction) {
              toggleCamera(direction);
            },
          ),
        );
      } else if (widget.exerciseDataModel.type == ExerciseType.BicepCurl) {
        return Scaffold(
          body: BicepCurlGame(
            isCurlingStream: _isCurlingStreamController.stream,
            cameraController: controller,
            poseResults: _scanResults,
            onGameComplete: (score) {
              setState(() {
                _showGame = false;
              });
            },
            onCameraToggle: (direction) {
              toggleCamera(direction);
            },
          ),
        );
      }
    }

    if (controller != null) {
      stackChildren.add(
        Positioned(
          top: 0.0,
          left: 0.0,
          width: size.width,
          height: size.height,
          child: Container(
            child:
                (controller.value.isInitialized)
                    ? AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: CameraPreview(controller),
                    )
                    : Container(),
          ),
        ),
      );

      stackChildren.add(
        Positioned(
          top: 0.0,
          left: 0.0,
          width: size.width,
          height: size.height,
          child: buildResult(),
        ),
      );

      // Exercise counter display
      stackChildren.add(
        Align(
          alignment: Alignment.bottomCenter,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  color: widget.exerciseDataModel.color,
                ),
                child: Center(
                  child: Text(
                    widget.exerciseDataModel.type == ExerciseType.PushUps
                        ? "$pushUpCount"
                        : widget.exerciseDataModel.type == ExerciseType.Squats
                        ? "$squatCount"
                        : widget.exerciseDataModel.type ==
                            ExerciseType.DownwardDogPlank
                        ? "$plankToDownwardDogCount"
                        : widget.exerciseDataModel.type ==
                            ExerciseType.BicepCurl
                        ? "$bicepCurlCount"
                        : "$jumpingJackCount",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                width: 70,
                height: 70,
              ),

              // Add game button for Squats, Jumping Jacks, or Bicep Curls
              if (widget.exerciseDataModel.type == ExerciseType.PushUps ||
                  widget.exerciseDataModel.type == ExerciseType.Squats ||
                  widget.exerciseDataModel.type == ExerciseType.JumpingJack ||
                  widget.exerciseDataModel.type == ExerciseType.BicepCurl)
                Container(
                  margin: EdgeInsets.only(left: 20, bottom: 20),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showGame = true;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.exerciseDataModel.color,
                      shape: CircleBorder(),
                      padding: EdgeInsets.all(15),
                    ),
                    child: Icon(
                      Icons.sports_esports,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),

              // Add camera toggle button in the main screen too
              Container(
                margin: EdgeInsets.only(left: 20, bottom: 20),
                child: ElevatedButton(
                  onPressed: () {
                    // Toggle between front and back cameras
                    CameraLensDirection newDirection =
                        controller.description.lensDirection ==
                                CameraLensDirection.back
                            ? CameraLensDirection.front
                            : CameraLensDirection.back;
                    toggleCamera(newDirection);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    shape: CircleBorder(),
                    padding: EdgeInsets.all(15),
                  ),
                  child: Icon(
                    controller.description.lensDirection ==
                            CameraLensDirection.back
                        ? Icons.camera_front
                        : Icons.camera_rear,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      // Improved header with exercise info
      stackChildren.add(
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: EdgeInsets.only(top: 50, left: 20, right: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: widget.exerciseDataModel.color,
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    widget.exerciseDataModel.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Image.asset(
                    'assets/${widget.exerciseDataModel.image}',
                    height: 50,
                  ),
                ],
              ),
            ),
            width: MediaQuery.of(context).size.width,
            height: 70,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        margin: const EdgeInsets.only(top: 0),
        color: Colors.black,
        child: Stack(children: stackChildren),
      ),
    );
  }

  int pushUpCount = 0;
  bool isLowered = false;
  void detectPushUp(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = landmarks[PoseLandmarkType.rightElbow];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftElbow == null ||
        rightElbow == null ||
        leftWrist == null ||
        rightWrist == null ||
        leftHip == null ||
        rightHip == null) {
      return;
    }

    double leftElbowAngle = calculateAngle(leftShoulder, leftElbow, leftWrist);
    double rightElbowAngle = calculateAngle(
      rightShoulder,
      rightElbow,
      rightWrist,
    );
    double avgElbowAngle = (leftElbowAngle + rightElbowAngle) / 2;

    double torsoAngle = calculateAngle(
      leftShoulder,
      leftHip,
      leftKnee ?? rightKnee!,
    );

    bool inPlankPosition = torsoAngle > 150 && torsoAngle < 190;

    double shoulderHeight = (leftShoulder.y + rightShoulder.y) / 2;
    double hipHeight = (leftHip.y + rightHip.y) / 2;
    bool shouldersAligned = (shoulderHeight - hipHeight).abs() < 50;

    if (avgElbowAngle < 100 && inPlankPosition && shouldersAligned) {
      if (!isLowered) {
        isLowered = true;
        _isLoweredStreamController.add(true); // ✅ Local stream used here
        print("Pushup lowered position detected");
      }
    } else if (avgElbowAngle > 150 &&
        isLowered &&
        inPlankPosition &&
        shouldersAligned) {
      pushUpCount++;
      isLowered = false;
      _isLoweredStreamController.add(false); // ✅ Local stream used here
      print("Pushup count: $pushUpCount");
      setState(() {});
    }
  }

  int squatCount = 0;
  bool isSquatting = false;
  void detectSquat(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];

    if (leftHip == null ||
        rightHip == null ||
        leftKnee == null ||
        rightKnee == null ||
        leftAnkle == null ||
        rightAnkle == null ||
        leftShoulder == null ||
        rightShoulder == null) {
      return; // Skip detection if any key landmark is missing
    }

    // Calculate angles
    double leftKneeAngle = calculateAngle(leftHip, leftKnee, leftAnkle);
    double rightKneeAngle = calculateAngle(rightHip, rightKnee, rightAnkle);
    double avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2;

    double hipY = (leftHip.y + rightHip.y) / 2;
    double kneeY = (leftKnee.y + rightKnee.y) / 2;

    bool deepSquat = avgKneeAngle < 90; // Ensuring squat is deep enough

    if (deepSquat && hipY > kneeY) {
      if (!isSquatting) {
        isSquatting = true;
      }
    } else if (!deepSquat && isSquatting) {
      squatCount++;
      isSquatting = false;

      // Update UI
      setState(() {});
    }
  }

  int plankToDownwardDogCount = 0;
  bool isInDownwardDog = false;
  void detectPlankToDownwardDog(Pose pose) {
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    if (leftHip == null ||
        rightHip == null ||
        leftShoulder == null ||
        rightShoulder == null ||
        leftAnkle == null ||
        rightAnkle == null ||
        leftWrist == null ||
        rightWrist == null) {
      return; // Skip detection if any key landmark is missing
    }

    // **Step 1: Detect Plank Position**
    bool isPlank =
        (leftHip.y - leftShoulder.y).abs() < 30 &&
        (rightHip.y - rightShoulder.y).abs() < 30 &&
        (leftHip.y - leftAnkle.y).abs() > 100 &&
        (rightHip.y - rightAnkle.y).abs() > 100;

    // **Step 2: Detect Downward Dog Position**
    bool isDownwardDog =
        (leftHip.y < leftShoulder.y - 50) &&
        (rightHip.y < rightShoulder.y - 50) &&
        (leftAnkle.y > leftHip.y) &&
        (rightAnkle.y > rightHip.y);

    // **Step 3: Count Repetitions**
    if (isDownwardDog && !isInDownwardDog) {
      isInDownwardDog = true;
    } else if (isPlank && isInDownwardDog) {
      plankToDownwardDogCount++;
      isInDownwardDog = false;

      // Print count
      print("Plank to Downward Dog Count: $plankToDownwardDogCount");
    }
  }

  int jumpingJackCount = 0;
  bool isJumping = false;
  bool isJumpingJackOpen = false;
  void detectJumpingJack(Pose pose) {
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    if (leftAnkle == null ||
        rightAnkle == null ||
        leftHip == null ||
        rightHip == null ||
        leftShoulder == null ||
        rightShoulder == null ||
        leftWrist == null ||
        rightWrist == null) {
      return; // Skip detection if any landmark is missing
    }

    // Calculate distances
    double legSpread = (rightAnkle.x - leftAnkle.x).abs();
    double armHeight = (leftWrist.y + rightWrist.y) / 2; // Average wrist height
    double hipHeight = (leftHip.y + rightHip.y) / 2; // Average hip height
    double shoulderWidth = (rightShoulder.x - leftShoulder.x).abs();

    // Define thresholds based on shoulder width
    double legThreshold =
        shoulderWidth * 1.2; // Legs should be ~1.2x shoulder width apart
    double armThreshold =
        hipHeight - shoulderWidth * 0.5; // Arms should be above shoulders

    // Check if arms are raised and legs are spread
    bool armsUp = armHeight < armThreshold;
    bool legsApart = legSpread > legThreshold;

    // Detect full jumping jack cycle
    if (armsUp && legsApart && !isJumpingJackOpen) {
      isJumpingJackOpen = true;
    } else if (!armsUp && !legsApart && isJumpingJackOpen) {
      jumpingJackCount++;
      isJumpingJackOpen = false;

      // Print the count
      print("Jumping Jack Count: $jumpingJackCount");
    }
  }

  // New function to detect bicep curls
  int bicepCurlCount = 0;
  bool isCurling = false;
  void detectBicepCurl(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = landmarks[PoseLandmarkType.rightElbow];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftElbow == null ||
        rightElbow == null ||
        leftWrist == null ||
        rightWrist == null) {
      return; // Skip if any key landmark is missing
    }

    // Calculate elbow angles
    double leftElbowAngle = calculateAngle(leftShoulder, leftElbow, leftWrist);
    double rightElbowAngle = calculateAngle(
      rightShoulder,
      rightElbow,
      rightWrist,
    );

    // We'll use either the left or right arm depending on which is more visible
    double elbowAngle = leftElbowAngle;

    // Check if right arm is more clearly visible
    bool useRightArm =
        rightShoulder.likelihood > leftShoulder.likelihood &&
        rightElbow.likelihood > leftElbow.likelihood &&
        rightWrist.likelihood > leftWrist.likelihood;

    if (useRightArm) {
      elbowAngle = rightElbowAngle;
    }

    // Consider doing a bicep curl when elbow angle is less than 90 degrees
    if (elbowAngle < 60 && !isCurling) {
      isCurling = true;
    } else if (elbowAngle > 150 && isCurling) {
      bicepCurlCount++;
      isCurling = false;
      print("Bicep Curl Count: $bicepCurlCount");
      setState(() {});
    }
  }

  // Function to calculate angle between three points (shoulder, elbow, wrist)
  double calculateAngle(
    PoseLandmark shoulder,
    PoseLandmark elbow,
    PoseLandmark wrist,
  ) {
    double a = distance(elbow, wrist);
    double b = distance(shoulder, elbow);
    double c = distance(shoulder, wrist);

    double angle = acos((b * b + a * a - c * c) / (2 * b * a)) * (180 / pi);
    return angle;
  }

  // Helper function to calculate Euclidean distance
  double distance(PoseLandmark p1, PoseLandmark p2) {
    return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2));
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };
  InputImage? _inputImageFromCameraImage() {
    // get image rotation
    // it is used in android to convert the InputImage from Dart to Java
    // `rotation` is not used in iOS to convert the InputImage from Dart to Obj-C
    // in both platforms `rotation` and `camera.lensDirection` can be used to compensate `x` and `y` coordinates on a canvas
    final camera = widget.cameras[_currentCameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    // get image format
    final format = InputImageFormatValue.fromRawValue(img!.format.raw);
    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888))
      return null;

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (img!.planes.length != 1) return null;
    final plane = img!.planes.first;

    // compose InputImage using bytes
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(img!.width.toDouble(), img!.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }

  //Show rectangles around detected objects
  Widget buildResult() {
    if (_scanResults == null ||
        controller == null ||
        !controller.value.isInitialized) {
      return Text('');
    }
    final Size imageSize = Size(
      controller.value.previewSize!.height,
      controller.value.previewSize!.width,
    );

    // Check camera direction correctly based on the current active camera
    bool isFrontCamera =
        controller.description.lensDirection == CameraLensDirection.front;

    CustomPainter painter = PosePainter(
      imageSize,
      _scanResults,
      isFrontCamera: isFrontCamera,
    );
    return CustomPaint(painter: painter);
  }
}
