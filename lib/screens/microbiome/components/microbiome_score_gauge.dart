import 'dart:math';
import 'package:flutter/material.dart';
import '../../../theme/tokens.dart';

/// 종합 점수 게이지 (Soft Wellness 스타일)
/// dfet_final 의 HMEScoreGauge 를 이식 — 파란 그라데이션을 세이지 그린 솔리드로 교체.
class MicrobiomeScoreGauge extends StatefulWidget {
  final double score;
  final double size;
  final String label;

  const MicrobiomeScoreGauge({
    super.key,
    required this.score,
    this.size = 220,
    this.label = '종합 점수',
  });

  @override
  State<MicrobiomeScoreGauge> createState() => _MicrobiomeScoreGaugeState();
}

class _MicrobiomeScoreGaugeState extends State<MicrobiomeScoreGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _animation = Tween<double>(begin: 0, end: widget.score).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(MicrobiomeScoreGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _animation = Tween<double>(begin: oldWidget.score, end: widget.score)
          .animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final value = _animation.value;
          final color = _getScoreColor(context, value);
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _GaugePainter(
                  score: value,
                  color: color,
                  trackColor: context.wellness.primarySubtle,
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: context.wellness.textSecondary,
                      fontSize: widget.size * 0.07,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value.toStringAsFixed(0),
                        style: TextStyle(
                          color: context.wellness.textPrimary,
                          fontSize: widget.size * 0.28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -2.0,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        '/100',
                        style: TextStyle(
                          color: context.wellness.textTertiary,
                          fontSize: widget.size * 0.1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: WellnessRadius.chip,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      _getScoreLevel(value),
                      style: TextStyle(
                        color: context.wellness.onPrimary,
                        fontSize: widget.size * 0.08,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _getScoreLevel(double score) {
    if (score >= 80) return '매우 좋음';
    if (score >= 60) return '양호';
    if (score >= 40) return '보통';
    return '주의 필요';
  }

  Color _getScoreColor(BuildContext context, double score) {
    if (score >= 80) return context.wellness.energy; // 스포티 라임 (최고 등급)
    if (score >= 60) return context.wellness.primary;
    if (score >= 40) return context.wellness.warning;
    return context.wellness.danger;
  }
}

class _GaugePainter extends CustomPainter {
  final double score;
  final Color color;
  final Color trackColor;

  _GaugePainter({
    required this.score,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const startAngle = 150 * pi / 180;
    const sweepAngle = 240 * pi / 180;

    // 1. 배경 트랙
    final bgPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 10),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // 2. 진행 아크 (솔리드 세이지)
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final currentSweep = sweepAngle * (score / 100).clamp(0.0, 1.0);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 10),
      startAngle,
      currentSweep,
      false,
      progressPaint,
    );

    // 3. 끝점 인디케이터 점
    final endAngle = startAngle + currentSweep;
    final dotRadius = radius - 10;
    final dotX = center.dx + dotRadius * cos(endAngle);
    final dotY = center.dy + dotRadius * sin(endAngle);

    canvas.drawCircle(
      Offset(dotX, dotY),
      8,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(dotX, dotY),
      5,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.score != score ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}
