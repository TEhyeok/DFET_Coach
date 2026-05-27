import 'package:flutter/material.dart';
import '../services/pose_detection_service.dart';

/// A visual guide overlay showing where the user should position their body
class PoseSilhouetteGuide extends StatelessWidget {
  final ExerciseType exerciseType;
  final bool isReady;
  final double opacity;

  const PoseSilhouetteGuide({
    super.key,
    required this.exerciseType,
    this.isReady = false,
    this.opacity = 0.3,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SilhouettePainter(
        exerciseType: exerciseType,
        isReady: isReady,
        opacity: opacity,
      ),
      child: Container(),
    );
  }
}

class _SilhouettePainter extends CustomPainter {
  final ExerciseType exerciseType;
  final bool isReady;
  final double opacity;

  _SilhouettePainter({
    required this.exerciseType,
    required this.isReady,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isReady
          ? Colors.green.withAlpha((opacity * 255).toInt())
          : Colors.white.withAlpha((opacity * 255).toInt())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final fillPaint = Paint()
      ..color = isReady
          ? Colors.green.withAlpha((opacity * 0.3 * 255).toInt())
          : Colors.white.withAlpha((opacity * 0.1 * 255).toInt())
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    switch (exerciseType) {
      case ExerciseType.squat:
        _drawSquatSilhouette(canvas, size, centerX, centerY, paint, fillPaint);
        break;
      case ExerciseType.pushup:
        _drawPushupSilhouette(canvas, size, centerX, centerY, paint, fillPaint);
        break;
      case ExerciseType.plank:
        _drawPlankSilhouette(canvas, size, centerX, centerY, paint, fillPaint);
        break;
      default:
        _drawStandingSilhouette(canvas, size, centerX, centerY, paint, fillPaint);
    }

    // Draw alignment guides
    _drawAlignmentGuides(canvas, size, paint);
  }

  void _drawStandingSilhouette(
    Canvas canvas,
    Size size,
    double centerX,
    double centerY,
    Paint paint,
    Paint fillPaint,
  ) {
    final scale = size.height * 0.6;

    // Head
    final headRadius = scale * 0.08;
    final headCenter = Offset(centerX, centerY - scale * 0.35);
    canvas.drawCircle(headCenter, headRadius, fillPaint);
    canvas.drawCircle(headCenter, headRadius, paint);

    // Body (torso)
    final path = Path();
    // Shoulders
    final shoulderY = centerY - scale * 0.25;
    final shoulderWidth = scale * 0.2;
    path.moveTo(centerX - shoulderWidth, shoulderY);
    path.lineTo(centerX + shoulderWidth, shoulderY);

    // Right side
    path.lineTo(centerX + shoulderWidth * 0.8, centerY + scale * 0.1);
    path.lineTo(centerX + shoulderWidth * 0.6, centerY + scale * 0.35);

    // Left side
    path.lineTo(centerX - shoulderWidth * 0.6, centerY + scale * 0.35);
    path.lineTo(centerX - shoulderWidth * 0.8, centerY + scale * 0.1);
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);

    // Arms
    canvas.drawLine(
      Offset(centerX - shoulderWidth, shoulderY),
      Offset(centerX - shoulderWidth * 1.5, centerY + scale * 0.15),
      paint,
    );
    canvas.drawLine(
      Offset(centerX + shoulderWidth, shoulderY),
      Offset(centerX + shoulderWidth * 1.5, centerY + scale * 0.15),
      paint,
    );

    // Legs
    final hipY = centerY + scale * 0.1;
    final footY = centerY + scale * 0.45;
    canvas.drawLine(
      Offset(centerX - shoulderWidth * 0.4, hipY),
      Offset(centerX - shoulderWidth * 0.5, footY),
      paint,
    );
    canvas.drawLine(
      Offset(centerX + shoulderWidth * 0.4, hipY),
      Offset(centerX + shoulderWidth * 0.5, footY),
      paint,
    );
  }

  void _drawSquatSilhouette(
    Canvas canvas,
    Size size,
    double centerX,
    double centerY,
    Paint paint,
    Paint fillPaint,
  ) {
    final scale = size.height * 0.5;

    // Head (lower position for squat)
    final headRadius = scale * 0.08;
    final headCenter = Offset(centerX, centerY - scale * 0.15);
    canvas.drawCircle(headCenter, headRadius, fillPaint);
    canvas.drawCircle(headCenter, headRadius, paint);

    // Torso (leaning slightly forward)
    final shoulderY = centerY - scale * 0.05;
    final hipY = centerY + scale * 0.15;
    canvas.drawLine(
      Offset(centerX - scale * 0.15, shoulderY),
      Offset(centerX + scale * 0.15, shoulderY),
      paint,
    );

    // Arms extended forward for balance
    canvas.drawLine(
      Offset(centerX - scale * 0.15, shoulderY),
      Offset(centerX - scale * 0.25, shoulderY - scale * 0.05),
      paint,
    );
    canvas.drawLine(
      Offset(centerX + scale * 0.15, shoulderY),
      Offset(centerX + scale * 0.25, shoulderY - scale * 0.05),
      paint,
    );

    // Torso line
    canvas.drawLine(
      Offset(centerX, shoulderY),
      Offset(centerX, hipY),
      paint,
    );

    // Bent legs (squat position)
    final kneeY = centerY + scale * 0.25;
    final ankleY = centerY + scale * 0.35;

    // Left leg
    canvas.drawLine(
      Offset(centerX - scale * 0.1, hipY),
      Offset(centerX - scale * 0.2, kneeY),
      paint,
    );
    canvas.drawLine(
      Offset(centerX - scale * 0.2, kneeY),
      Offset(centerX - scale * 0.15, ankleY),
      paint,
    );

    // Right leg
    canvas.drawLine(
      Offset(centerX + scale * 0.1, hipY),
      Offset(centerX + scale * 0.2, kneeY),
      paint,
    );
    canvas.drawLine(
      Offset(centerX + scale * 0.2, kneeY),
      Offset(centerX + scale * 0.15, ankleY),
      paint,
    );

    // Draw text instruction
    _drawInstruction(canvas, size, '무릎을 90도로 구부려 주세요', centerY + scale * 0.5);
  }

  void _drawPushupSilhouette(
    Canvas canvas,
    Size size,
    double centerX,
    double centerY,
    Paint paint,
    Paint fillPaint,
  ) {
    final scale = size.width * 0.35;

    // Pushup is horizontal, so we draw it sideways
    final bodyY = centerY;

    // Head
    final headRadius = scale * 0.08;
    canvas.drawCircle(Offset(centerX - scale * 0.4, bodyY - scale * 0.05), headRadius, fillPaint);
    canvas.drawCircle(Offset(centerX - scale * 0.4, bodyY - scale * 0.05), headRadius, paint);

    // Body line (horizontal)
    canvas.drawLine(
      Offset(centerX - scale * 0.35, bodyY),
      Offset(centerX + scale * 0.35, bodyY),
      paint,
    );

    // Arms (supporting)
    canvas.drawLine(
      Offset(centerX - scale * 0.2, bodyY),
      Offset(centerX - scale * 0.2, bodyY + scale * 0.25),
      paint,
    );
    canvas.drawLine(
      Offset(centerX + scale * 0.1, bodyY),
      Offset(centerX + scale * 0.1, bodyY + scale * 0.25),
      paint,
    );

    // Legs
    canvas.drawLine(
      Offset(centerX + scale * 0.35, bodyY),
      Offset(centerX + scale * 0.45, bodyY + scale * 0.15),
      paint,
    );

    _drawInstruction(canvas, size, '옆으로 누워서 전신이 보이게 해주세요', centerY + scale * 0.5);
  }

  void _drawPlankSilhouette(
    Canvas canvas,
    Size size,
    double centerX,
    double centerY,
    Paint paint,
    Paint fillPaint,
  ) {
    final scale = size.width * 0.35;
    final bodyY = centerY;

    // Similar to pushup but static hold position
    // Head
    final headRadius = scale * 0.07;
    canvas.drawCircle(Offset(centerX - scale * 0.35, bodyY - scale * 0.03), headRadius, fillPaint);
    canvas.drawCircle(Offset(centerX - scale * 0.35, bodyY - scale * 0.03), headRadius, paint);

    // Body line (horizontal and straight)
    final bodyPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    canvas.drawLine(
      Offset(centerX - scale * 0.3, bodyY),
      Offset(centerX + scale * 0.35, bodyY),
      bodyPaint,
    );

    // Arms (elbows on ground)
    canvas.drawLine(
      Offset(centerX - scale * 0.2, bodyY),
      Offset(centerX - scale * 0.2, bodyY + scale * 0.2),
      paint,
    );

    // Feet
    canvas.drawLine(
      Offset(centerX + scale * 0.35, bodyY),
      Offset(centerX + scale * 0.38, bodyY + scale * 0.15),
      paint,
    );

    _drawInstruction(canvas, size, '몸을 일직선으로 유지하세요', centerY + scale * 0.4);
  }

  void _drawAlignmentGuides(Canvas canvas, Size size, Paint paint) {
    final guidePaint = Paint()
      ..color = Colors.white.withAlpha(50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Center vertical line
    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.1),
      Offset(size.width / 2, size.height * 0.9),
      guidePaint,
    );

    // Rule of thirds horizontal lines
    canvas.drawLine(
      Offset(size.width * 0.1, size.height / 3),
      Offset(size.width * 0.9, size.height / 3),
      guidePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 2 / 3),
      Offset(size.width * 0.9, size.height * 2 / 3),
      guidePaint,
    );
  }

  void _drawInstruction(Canvas canvas, Size size, String text, double y) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withAlpha(180),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, y),
    );
  }

  @override
  bool shouldRepaint(covariant _SilhouettePainter oldDelegate) {
    return oldDelegate.exerciseType != exerciseType ||
        oldDelegate.isReady != isReady ||
        oldDelegate.opacity != opacity;
  }
}
