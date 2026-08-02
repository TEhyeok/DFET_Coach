import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:camera/camera.dart';

class PoseOverlayPainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;

  PoseOverlayPainter({
    required this.poses,
    required this.imageSize,
    required this.rotation,
    required this.cameraLensDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.green;

    final Paint pointPaint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 3.0
      ..color = Colors.green;

    for (final pose in poses) {
      // Draw pose landmarks
      pose.landmarks.forEach((_, landmark) {
        canvas.drawCircle(
          Offset(
            translateX(landmark.x.toDouble(), size),
            translateY(landmark.y.toDouble(), size),
          ),
          5,
          pointPaint,
        );
      });

      // Draw connections between landmarks
      final leftPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = Colors.lightBlue;

      final rightPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = Colors.orange;

      // Draw body connections
      _drawLine(canvas, size, pose, PoseLandmarkType.leftShoulder,
          PoseLandmarkType.leftElbow, leftPaint);
      _drawLine(canvas, size, pose, PoseLandmarkType.leftElbow,
          PoseLandmarkType.leftWrist, leftPaint);
      _drawLine(canvas, size, pose, PoseLandmarkType.leftShoulder,
          PoseLandmarkType.leftHip, leftPaint);
      _drawLine(canvas, size, pose, PoseLandmarkType.leftHip,
          PoseLandmarkType.leftKnee, leftPaint);
      _drawLine(canvas, size, pose, PoseLandmarkType.leftKnee,
          PoseLandmarkType.leftAnkle, leftPaint);

      _drawLine(canvas, size, pose, PoseLandmarkType.rightShoulder,
          PoseLandmarkType.rightElbow, rightPaint);
      _drawLine(canvas, size, pose, PoseLandmarkType.rightElbow,
          PoseLandmarkType.rightWrist, rightPaint);
      _drawLine(canvas, size, pose, PoseLandmarkType.rightShoulder,
          PoseLandmarkType.rightHip, rightPaint);
      _drawLine(canvas, size, pose, PoseLandmarkType.rightHip,
          PoseLandmarkType.rightKnee, rightPaint);
      _drawLine(canvas, size, pose, PoseLandmarkType.rightKnee,
          PoseLandmarkType.rightAnkle, rightPaint);

      // Connect shoulders and hips
      _drawLine(canvas, size, pose, PoseLandmarkType.leftShoulder,
          PoseLandmarkType.rightShoulder, paint);
      _drawLine(canvas, size, pose, PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip, paint);
    }
  }

  void _drawLine(
    Canvas canvas,
    Size size,
    Pose pose,
    PoseLandmarkType type1,
    PoseLandmarkType type2,
    Paint paint,
  ) {
    final landmark1 = pose.landmarks[type1];
    final landmark2 = pose.landmarks[type2];

    if (landmark1 != null && landmark2 != null) {
      canvas.drawLine(
        Offset(
          translateX(landmark1.x.toDouble(), size),
          translateY(landmark1.y.toDouble(), size),
        ),
        Offset(
          translateX(landmark2.x.toDouble(), size),
          translateY(landmark2.y.toDouble(), size),
        ),
        paint,
      );
    }
  }

  double translateX(double x, Size size) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        return x * size.width / imageSize.height;
      case InputImageRotation.rotation270deg:
        return size.width - x * size.width / imageSize.height;
      default:
        switch (cameraLensDirection) {
          case CameraLensDirection.front:
            return size.width - x * size.width / imageSize.width;
          default:
            return x * size.width / imageSize.width;
        }
    }
  }

  double translateY(double y, Size size) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return y * size.height / imageSize.width;
      default:
        return y * size.height / imageSize.height;
    }
  }

  @override
  bool shouldRepaint(covariant PoseOverlayPainter oldDelegate) {
    return oldDelegate.imageSize != imageSize || oldDelegate.poses != poses;
  }
}
