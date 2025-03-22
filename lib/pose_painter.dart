import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  PosePainter(this.absoluteImageSize, this.poses);

  final Size absoluteImageSize;
  final List<Pose> poses;

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    final Paint dotPaint =
        Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.green
          ..strokeWidth = 2;

    final Paint leftLinePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.yellow;

    final Paint rightLinePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.blueAccent;

    for (final pose in poses) {
      pose.landmarks.forEach((_, landmark) {
        canvas.drawCircle(
          Offset(landmark.x * scaleX, landmark.y * scaleY),
          3,
          dotPaint,
        );
      });

      void paintLine(
        PoseLandmarkType type1,
        PoseLandmarkType type2,
        Paint paintType,
      ) {
        final PoseLandmark? joint1 = pose.landmarks[type1];
        final PoseLandmark? joint2 = pose.landmarks[type2];
        if (joint1 != null && joint2 != null) {
          canvas.drawLine(
            Offset(joint1.x * scaleX, joint1.y * scaleY),
            Offset(joint2.x * scaleX, joint2.y * scaleY),
            paintType,
          );
        }
      }

      // Arms
      paintLine(
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftElbow,
        leftLinePaint,
      );
      paintLine(
        PoseLandmarkType.leftElbow,
        PoseLandmarkType.leftWrist,
        leftLinePaint,
      );
      paintLine(
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightElbow,
        rightLinePaint,
      );
      paintLine(
        PoseLandmarkType.rightElbow,
        PoseLandmarkType.rightWrist,
        rightLinePaint,
      );

      // Body
      paintLine(
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftHip,
        leftLinePaint,
      );
      paintLine(
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightHip,
        rightLinePaint,
      );

      // Legs
      paintLine(
        PoseLandmarkType.leftHip,
        PoseLandmarkType.leftKnee,
        leftLinePaint,
      );
      paintLine(
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.leftAnkle,
        leftLinePaint,
      );
      paintLine(
        PoseLandmarkType.rightHip,
        PoseLandmarkType.rightKnee,
        rightLinePaint,
      );
      paintLine(
        PoseLandmarkType.rightKnee,
        PoseLandmarkType.rightAnkle,
        rightLinePaint,
      );
    }
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.poses != poses;
  }
}
