import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design_system/d_fet_axis_glyph.dart';
import '../../design_system/d_fet_axis_icon.dart';
import '../../models/clinical_reports.dart';
import '../../theme/d_fet_typography.dart';
import '../../theme/tokens.dart';

class TodaySignalScreen extends StatefulWidget {
  const TodaySignalScreen({
    super.key,
    required this.current,
    required this.previous,
    required this.insight,
    required this.onOpenInsight,
    this.onProfileTap,
  });

  final HealthSnapshot current;
  final HealthSnapshot previous;
  final HealthInsight insight;
  final VoidCallback onOpenInsight;
  final VoidCallback? onProfileTap;

  @override
  State<TodaySignalScreen> createState() => _TodaySignalScreenState();
}

class _TodaySignalScreenState extends State<TodaySignalScreen> {
  static const _axisKeys = ['fitness', 'diet', 'gut', 'blood'];

  bool _completed = false;

  String get _storageKey => 'clinical_action_completed_${widget.insight.id}';

  @override
  void initState() {
    super.initState();
    _loadCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canvas = isDark ? context.wellness.bgRoot : const Color(0xFFFBF8F1);
    final deltas = _axisDeltas();
    final improvedCount =
        deltas.where((delta) => delta != null && delta > 0).length;
    final action = widget.insight.action ?? const <String, dynamic>{};

    return ColoredBox(
      color: canvas,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 34),
          children: [
            _TodayHeader(
              asOf: widget.current.asOf,
              onProfileTap: widget.onProfileTap,
            ),
            const SizedBox(height: 38),
            _ChangeHeadline(
              improvedCount: improvedCount,
              totalCount: deltas.length,
            ),
            const SizedBox(height: 34),
            _TodayAxisRail(deltas: deltas),
            const SizedBox(height: 42),
            _ActionPulsePanel(
              completed: _completed,
              title: action['title']?.toString() ?? '오늘의 생활 루틴',
              duration: action['duration']?.toString() ?? '5분',
              onToggle: _toggleCompleted,
            ),
            const SizedBox(height: 34),
            const _CheckInProgress(currentDay: 5, totalDays: 7),
            const SizedBox(height: 28),
            _EvidenceRibbon(
              body: widget.insight.body,
              onTap: widget.onOpenInsight,
            ),
            const SizedBox(height: 14),
            Text(
              '생활 기록과 지표 변화의 연관 가능성을 보여주는 비진단 정보입니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.wellness.textTertiary,
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<double?> _axisDeltas() {
    return [
      for (final key in _axisKeys)
        switch ((widget.current.axes[key], widget.previous.axes[key])) {
          (final double current, final double previous) => current - previous,
          _ => null,
        },
    ];
  }

  Future<void> _loadCompleted() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _completed = preferences.getBool(_storageKey) ?? false);
  }

  Future<void> _toggleCompleted() async {
    HapticFeedback.mediumImpact();
    final nextValue = !_completed;
    setState(() => _completed = nextValue);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_storageKey, nextValue);
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.asOf, this.onProfileTap});

  final DateTime asOf;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '오늘의 신호',
                style: TextStyle(
                  color: context.wellness.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 32,
                height: 3,
                color: context.wellness.textPrimary,
              ),
              const SizedBox(height: 10),
              Text(
                '합성 데이터 · ${DateFormat('yyyy.MM.dd').format(asOf)} 기준',
                style: TextStyle(
                  color: context.wellness.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Semantics(
          button: onProfileTap != null,
          label: 'D-FET 프로필',
          child: InkResponse(
            onTap: onProfileTap,
            radius: 30,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF0D1933),
                  ),
                  child: const Text(
                    'D',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Positioned(
                  right: -1,
                  top: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFF5A57),
                    ),
                    child: SizedBox.square(dimension: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChangeHeadline extends StatelessWidget {
  const _ChangeHeadline({
    required this.improvedCount,
    required this.totalCount,
  });

  final int improvedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final fontSize = MediaQuery.sizeOf(context).width < 350 ? 37.0 : 44.0;
    return Semantics(
      header: true,
      label: '$totalCount개 축 중 $improvedCount개가 좋아졌어요',
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '$totalCount개 축 중\n'),
              TextSpan(
                text: '$improvedCount개',
                style: const TextStyle(color: Color(0xFF1769E8)),
              ),
              const TextSpan(text: '가 좋아졌어요'),
            ],
          ),
          style: TextStyle(
            color: context.wellness.textPrimary,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            height: 1.16,
            letterSpacing: -1.1,
          ),
        ),
      ),
    );
  }
}

class _TodayAxisRail extends StatelessWidget {
  const _TodayAxisRail({required this.deltas});

  final List<double?> deltas;

  static const _labels = ['운동', '식단', '장', '혈액'];
  static const _axes = [
    DfetAxis.motion,
    DfetAxis.nutrition,
    DfetAxis.gut,
    DfetAxis.blood,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / _axes.length;
        final nodeSize = math.min(78.0, math.max(58.0, cellWidth - 10));
        return Stack(
          children: [
            Positioned(
              left: cellWidth / 2,
              right: cellWidth / 2,
              top: nodeSize / 2 - 5,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1933),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < _axes.length; index++)
                  Expanded(
                    child: _TodayAxisNode(
                      axis: _axes[index],
                      label: _labels[index],
                      delta: deltas[index],
                      size: nodeSize,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _TodayAxisNode extends StatelessWidget {
  const _TodayAxisNode({
    required this.axis,
    required this.label,
    required this.delta,
    required this.size,
  });

  final DfetAxis axis;
  final String label;
  final double? delta;
  final double size;

  @override
  Widget build(BuildContext context) {
    final axisColor = DfetAxisPalette.color(context, axis);
    final value = delta == null
        ? '확인 필요'
        : '${delta! > 0 ? '+' : ''}${delta!.toStringAsFixed(0)}';
    return Semantics(
      label:
          '$label 축, ${delta == null ? '확인 필요' : '${delta!.toStringAsFixed(0)}점 변화'}',
      excludeSemantics: true,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? context.wellness.bgCard
                      : const Color(0xFFFBF8F1),
                  border: Border.all(
                    color: const Color(0xFF0D1933),
                    width: 4,
                  ),
                ),
                child: DfetAxisAssetIcon(axis: axis, size: size * 0.58),
              ),
              Positioned(
                bottom: -5,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: axisColor,
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? context.wellness.bgRoot
                          : const Color(0xFFFBF8F1),
                      width: 3,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: 1,
            height: 14,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: context.wellness.textTertiary,
                  width: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: context.wellness.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DfetTypography.dataStyle(
              color: delta == null ? context.wellness.textSecondary : axisColor,
              fontSize: delta == null ? 11 : 21,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPulsePanel extends StatelessWidget {
  const _ActionPulsePanel({
    required this.completed,
    required this.title,
    required this.duration,
    required this.onToggle,
  });

  final bool completed;
  final String title;
  final String duration;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipPath(
          clipper: const _ActionPanelClipper(),
          child: ColoredBox(
            color: const Color(0xFF0D1933),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: IgnorePointer(
                      child: CustomPaint(painter: _PulsePainter())),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 48, 30, 46),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        completed ? '오늘의 한 걸음 완료' : '오늘의 한 가지',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        completed ? '오늘 신호를 이었어요' : title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          height: 1.18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(width: 174, height: 1, color: Colors.white24),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: const DfetAxisAssetIcon(
                              axis: DfetAxis.nutrition,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: '$duration · '),
                                  const TextSpan(
                                    text: '식단',
                                    style: TextStyle(color: Color(0xFFFF8A25)),
                                  ),
                                  const TextSpan(text: '  →  '),
                                  const TextSpan(
                                    text: '장',
                                    style: TextStyle(color: Color(0xFF8B68F6)),
                                  ),
                                ],
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Semantics(
                        button: true,
                        label: completed ? '오늘 행동 완료 취소' : '오늘 행동 완료 표시',
                        child: InkWell(
                          onTap: onToggle,
                          borderRadius: BorderRadius.circular(36),
                          child: Ink(
                            height: 58,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(36),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF4D55), Color(0xFFFF675B)],
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  completed
                                      ? Icons.undo_rounded
                                      : Icons.check_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  completed ? '완료 취소' : '완료 표시',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 2,
          bottom: 74,
          child: Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFF5A57),
            ),
            child:
                const Icon(Icons.check_rounded, color: Colors.white, size: 30),
          ),
        ),
      ],
    );
  }
}

class _ActionPanelClipper extends CustomClipper<Path> {
  const _ActionPanelClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 76)
      ..quadraticBezierTo(0, 26, 66, 24)
      ..lineTo(size.width * 0.77, 4)
      ..quadraticBezierTo(size.width, 0, size.width, 80)
      ..lineTo(size.width, size.height * 0.44)
      ..cubicTo(
        size.width * 0.87,
        size.height * 0.52,
        size.width,
        size.height * 0.66,
        size.width * 0.88,
        size.height * 0.82,
      )
      ..quadraticBezierTo(
          size.width * 0.82, size.height, size.width * 0.67, size.height)
      ..lineTo(76, size.height)
      ..quadraticBezierTo(0, size.height - 10, 0, size.height - 84)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _PulsePainter extends CustomPainter {
  const _PulsePainter();

  static const _colors = [
    Color(0xFF1B71F2),
    Color(0xFFFF8A25),
    Color(0xFF8058EF),
    Color(0xFFFF5A57),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width + 2, size.height - 60);
    for (var ring = 0; ring < _colors.length; ring++) {
      final paint = Paint()
        ..color = _colors[ring]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final radius = 42.0 + ring * 18;
      final rect = Rect.fromCircle(center: center, radius: radius);
      for (var dash = 0; dash < 8; dash++) {
        canvas.drawArc(
          rect,
          math.pi * 0.78 + dash * 0.32,
          0.17,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CheckInProgress extends StatelessWidget {
  const _CheckInProgress({required this.currentDay, required this.totalDays});

  final int currentDay;
  final int totalDays;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${totalDays - currentDay}일 더 기록하면 다시 비교할 수 있어요',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.wellness.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            for (var day = 1; day <= totalDays; day++) ...[
              if (day > 1)
                Expanded(
                  child: Container(
                    height: 1,
                    color: day <= currentDay
                        ? context.wellness.textPrimary
                        : context.wellness.border,
                  ),
                ),
              _DayNode(day: day, currentDay: currentDay),
            ],
          ],
        ),
      ],
    );
  }
}

class _DayNode extends StatelessWidget {
  const _DayNode({required this.day, required this.currentDay});

  final int day;
  final int currentDay;

  @override
  Widget build(BuildContext context) {
    final isCurrent = day == currentDay;
    final isFuture = day > currentDay;
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                isCurrent ? context.wellness.textPrimary : Colors.transparent,
            border: Border.all(
              color: isFuture
                  ? context.wellness.border
                  : context.wellness.textPrimary,
              width: isFuture ? 1 : 2,
            ),
          ),
          child: isCurrent
              ? Text(
                  '$day',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 5),
        Text(
          '$day일',
          style: TextStyle(
            color: isCurrent
                ? context.wellness.textPrimary
                : context.wellness.textSecondary,
            fontSize: 10,
            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _EvidenceRibbon extends StatelessWidget {
  const _EvidenceRibbon({required this.body, required this.onTap});

  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.wellness.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: context.wellness.borderSubtle),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0D1933),
                ),
                child: const Icon(
                  Icons.article_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '근거 한 줄',
                      style: TextStyle(
                        color: context.wellness.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.wellness.textSecondary,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: context.wellness.textPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
