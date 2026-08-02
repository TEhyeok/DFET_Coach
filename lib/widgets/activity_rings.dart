import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../theme/text_styles.dart';

class ActivityRings extends StatefulWidget {
  final double nutritionProgress; // 0.0 ~ 1.0
  final double exerciseProgress; // 0.0 ~ 1.0
  final double wellnessProgress; // 0.0 ~ 1.0
  final int wellnessScore; // 0 ~ 100

  const ActivityRings({
    super.key,
    required this.nutritionProgress,
    required this.exerciseProgress,
    required this.wellnessProgress,
    required this.wellnessScore,
  });

  @override
  State<ActivityRings> createState() => _ActivityRingsState();
}

class _ActivityRingsState extends State<ActivityRings>
    with TickerProviderStateMixin {
  late AnimationController _controller1;
  late AnimationController _controller2;
  late AnimationController _controller3;
  late AnimationController _scoreController;

  late Animation<double> _animation1;
  late Animation<double> _animation2;
  late Animation<double> _animation3;
  late Animation<int> _scoreAnimation;

  @override
  void initState() {
    super.initState();

    // 3개 링 애니메이션 (순차적으로 시작)
    _controller1 = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _controller2 = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _controller3 = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _scoreController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animation1 = Tween<double>(begin: 0, end: widget.nutritionProgress)
        .animate(
            CurvedAnimation(parent: _controller1, curve: Curves.easeOutCubic));
    _animation2 = Tween<double>(begin: 0, end: widget.exerciseProgress).animate(
        CurvedAnimation(parent: _controller2, curve: Curves.easeOutCubic));
    _animation3 = Tween<double>(begin: 0, end: widget.wellnessProgress).animate(
        CurvedAnimation(parent: _controller3, curve: Curves.easeOutCubic));
    _scoreAnimation = IntTween(begin: 0, end: widget.wellnessScore).animate(
        CurvedAnimation(parent: _scoreController, curve: Curves.easeOut));

    // 순차적 시작 (각각 300ms 간격)
    _controller1.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _controller2.forward();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _controller3.forward();
    });
    _scoreController.forward();
  }

  @override
  void didUpdateWidget(ActivityRings oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Progress 값이 변경되었는지 확인
    if (oldWidget.nutritionProgress != widget.nutritionProgress ||
        oldWidget.exerciseProgress != widget.exerciseProgress ||
        oldWidget.wellnessProgress != widget.wellnessProgress ||
        oldWidget.wellnessScore != widget.wellnessScore) {
      // 새로운 값으로 애니메이션 재설정
      _animation1 = Tween<double>(
        begin: _animation1.value, // 현재값부터 시작
        end: widget.nutritionProgress,
      ).animate(
          CurvedAnimation(parent: _controller1, curve: Curves.easeOutCubic));

      _animation2 = Tween<double>(
        begin: _animation2.value,
        end: widget.exerciseProgress,
      ).animate(
          CurvedAnimation(parent: _controller2, curve: Curves.easeOutCubic));

      _animation3 = Tween<double>(
        begin: _animation3.value,
        end: widget.wellnessProgress,
      ).animate(
          CurvedAnimation(parent: _controller3, curve: Curves.easeOutCubic));

      _scoreAnimation = IntTween(
        begin: _scoreAnimation.value,
        end: widget.wellnessScore,
      ).animate(
          CurvedAnimation(parent: _scoreController, curve: Curves.easeOut));

      // 애니메이션 리셋 후 재시작
      _controller1.reset();
      _controller2.reset();
      _controller3.reset();
      _scoreController.reset();

      _controller1.forward();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _controller2.forward();
      });
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _controller3.forward();
      });
      _scoreController.forward();
    }
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '활동 링',
      value: '영양 ${(widget.nutritionProgress * 100).toInt()}%, '
          '운동 ${(widget.exerciseProgress * 100).toInt()}%, '
          '웰니스 ${widget.wellnessScore}점',
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 사용 가능한 공간에 맞게 크기 조정
          final availableHeight = constraints.maxHeight;
          final ringSize = (availableHeight * 0.75).clamp(120.0, 240.0);
          final scoreFontSize = (ringSize * 0.2).clamp(24.0, 48.0);

          return FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 링 + 중앙 점수
                SizedBox(
                  height: ringSize,
                  width: ringSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 3개 링
                      AnimatedBuilder(
                        animation: Listenable.merge(
                            [_controller1, _controller2, _controller3]),
                        builder: (context, child) {
                          return CustomPaint(
                            size: Size(ringSize, ringSize),
                            painter: ActivityRingsPainter(
                              nutrition: _animation1.value,
                              exercise: _animation2.value,
                              wellness: _animation3.value,
                              scaleFactor: ringSize / 240,
                              trackColor: context.wellness.border,
                              nutritionColor: context.wellness.energy,
                              exerciseColor: context.wellness.primary,
                              wellnessColor: context.wellness.info,
                            ),
                          );
                        },
                      ),
                      // 중앙 점수
                      AnimatedBuilder(
                        animation: _scoreController,
                        builder: (context, child) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_scoreAnimation.value}',
                                style: AppTextStyles.number.copyWith(
                                  fontSize: scoreFontSize,
                                  color: context.wellness.textPrimary,
                                ),
                              ),
                              Text(
                                '평균 점수',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: scoreFontSize * 0.28,
                                  color: context.wellness.textTertiary,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // 범례
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLegend(context, '영양', widget.nutritionProgress,
                        context.wellness.energy),
                    const SizedBox(width: 12),
                    _buildLegend(context, '운동', widget.exerciseProgress,
                        context.wellness.primary),
                    const SizedBox(width: 12),
                    _buildLegend(context, '웰니스', widget.wellnessProgress,
                        context.wellness.info),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegend(
      BuildContext context, String label, double progress, Color color) {
    return Column(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.caption
              .copyWith(color: context.wellness.textTertiary),
        ),
        Text(
          '${(progress * 100).toInt()}%',
          style: AppTextStyles.bodySmall
              .copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class ActivityRingsPainter extends CustomPainter {
  final double nutrition;
  final double exercise;
  final double wellness;
  final double scaleFactor;
  final Color trackColor;
  final Color nutritionColor;
  final Color exerciseColor;
  final Color wellnessColor;

  ActivityRingsPainter({
    required this.nutrition,
    required this.exercise,
    required this.wellness,
    this.scaleFactor = 1.0,
    this.trackColor = WellnessColors.border,
    this.nutritionColor = WellnessColors.energy,
    this.exerciseColor = WellnessColors.primary,
    this.wellnessColor = WellnessColors.info,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final startAngle = -pi / 2; // 12시 방향부터 시작

    // 링 설정 (바깥 → 안쪽) - scaleFactor 적용
    // 스포티 테마: 바깥 링(영양)=에너지 라임, 운동=프라이머리, 웰니스=인포 블루 (테마 적응)
    final rings = [
      {
        'progress': nutrition,
        'color': nutritionColor,
        'radius': 110.0 * scaleFactor,
        'strokeWidth': 18.0 * scaleFactor
      },
      {
        'progress': exercise,
        'color': exerciseColor,
        'radius': 85.0 * scaleFactor,
        'strokeWidth': 18.0 * scaleFactor
      },
      {
        'progress': wellness,
        'color': wellnessColor,
        'radius': 60.0 * scaleFactor,
        'strokeWidth': 18.0 * scaleFactor
      },
    ];

    for (var ring in rings) {
      final progress = ring['progress'] as double;
      final color = ring['color'] as Color;
      final radius = ring['radius'] as double;
      final strokeWidth = ring['strokeWidth'] as double;

      // 배경 링 (회색)
      final bgPaint = Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        0,
        2 * pi,
        false,
        bgPaint,
      );

      // 진행 링 (컬러)
      if (progress > 0) {
        final progressPaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          2 * pi * progress,
          false,
          progressPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant ActivityRingsPainter oldDelegate) {
    return oldDelegate.nutrition != nutrition ||
        oldDelegate.exercise != exercise ||
        oldDelegate.wellness != wellness ||
        oldDelegate.scaleFactor != scaleFactor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.nutritionColor != nutritionColor ||
        oldDelegate.exerciseColor != exerciseColor ||
        oldDelegate.wellnessColor != wellnessColor;
  }
}
