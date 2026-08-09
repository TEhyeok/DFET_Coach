import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../theme/d_fet_typography.dart';
import '../../theme/tokens.dart';

class ScoreGauge extends StatelessWidget {
  const ScoreGauge({
    super.key,
    required this.score,
    this.label = '참고용 점수',
    this.size = 148,
  });

  final double? score;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final accessibleHeight =
        size * 0.72 + (textScale > 1 ? (textScale - 1).clamp(0, 1) * 64 : 0);
    final color = score == null
        ? context.wellness.textTertiary
        : context.wellness.primary;
    return Semantics(
      label: score == null ? '점수 산정 준비 중' : '$label ${score!.round()}점',
      child: SizedBox(
        width: size,
        height: accessibleHeight,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            CustomPaint(
              size: Size(size, size * 0.62),
              painter: _GaugePainter(
                progress: ((score ?? 0) / 100).clamp(0, 1),
                trackColor: context.wellness.bgSubtle,
                color: color,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    score?.round().toString() ?? '--',
                    style: DfetTypography.dataStyle(
                      color: context.wellness.textPrimary,
                      fontSize: size * 0.23,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    score == null ? '산정 준비 중' : label,
                    style: TextStyle(
                      color: context.wellness.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.progress,
    required this.trackColor,
    required this.color,
  });

  final double progress;
  final Color trackColor;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.085;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      (size.height - strokeWidth) * 1.7,
    );
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, math.pi, math.pi, false, track);
    if (progress > 0) {
      canvas.drawArc(rect, math.pi, math.pi * progress, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return progress != oldDelegate.progress ||
        trackColor != oldDelegate.trackColor ||
        color != oldDelegate.color;
  }
}
