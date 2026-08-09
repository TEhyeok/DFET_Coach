import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design_system/d_fet_axis_glyph.dart';
import '../../design_system/d_fet_axis_icon.dart';
import '../../models/clinical_reports.dart';
import '../../theme/d_fet_typography.dart';
import '../../theme/motion_tokens.dart';
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

class _TodaySignalScreenState extends State<TodaySignalScreen>
    with SingleTickerProviderStateMixin {
  static const _axisKeys = ['fitness', 'diet', 'gut', 'blood'];

  late final AnimationController _entranceController;
  bool _completed = false;
  bool? _animationsDisabled;

  String get _storageKey => 'clinical_action_completed_${widget.insight.id}';

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: DfetMotion.pageEnter,
    );
    _loadCompleted();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (_animationsDisabled == disabled) return;
    _animationsDisabled = disabled;
    if (disabled) {
      _entranceController.value = 1;
    } else {
      _entranceController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
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
            _StaggerReveal(
              animation: _entranceController,
              begin: 0,
              end: 0.28,
              child: _TodayHeader(
                asOf: widget.current.asOf,
                onProfileTap: widget.onProfileTap,
              ),
            ),
            const SizedBox(height: 38),
            _StaggerReveal(
              animation: _entranceController,
              begin: 0.08,
              end: 0.4,
              child: _ChangeHeadline(
                improvedCount: improvedCount,
                totalCount: deltas.length,
              ),
            ),
            const SizedBox(height: 34),
            _StaggerReveal(
              animation: _entranceController,
              begin: 0.18,
              end: 0.54,
              child: _TodayAxisRail(deltas: deltas),
            ),
            const SizedBox(height: 42),
            _StaggerReveal(
              animation: _entranceController,
              begin: 0.3,
              end: 0.68,
              child: _ActionPulsePanel(
                completed: _completed,
                title: action['title']?.toString() ?? '오늘의 생활 루틴',
                duration: action['duration']?.toString() ?? '5분',
                onToggle: _toggleCompleted,
              ),
            ),
            const SizedBox(height: 34),
            _StaggerReveal(
              animation: _entranceController,
              begin: 0.46,
              end: 0.78,
              child: const _CheckInProgress(currentDay: 5, totalDays: 7),
            ),
            const SizedBox(height: 28),
            _StaggerReveal(
              animation: _entranceController,
              begin: 0.6,
              end: 0.9,
              child: _EvidenceRibbon(
                body: widget.insight.body,
                onTap: widget.onOpenInsight,
              ),
            ),
            const SizedBox(height: 14),
            _StaggerReveal(
              animation: _entranceController,
              begin: 0.7,
              end: 1,
              child: Text(
                '생활 기록과 지표 변화의 연관 가능성을 보여주는 비진단 정보입니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.wellness.textTertiary,
                  fontSize: 10,
                  height: 1.4,
                ),
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

class _StaggerReveal extends StatelessWidget {
  const _StaggerReveal({
    required this.animation,
    required this.begin,
    required this.end,
    required this.child,
  });

  final Animation<double> animation;
  final double begin;
  final double end;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(begin, end, curve: DfetMotion.emphasized),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
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
          style: DfetTypography.displayStyle(
            color: context.wellness.textPrimary,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            height: 1.16,
            letterSpacing: -1.35,
          ),
        ),
      ),
    );
  }
}

class _TodayAxisRail extends StatefulWidget {
  const _TodayAxisRail({required this.deltas});

  final List<double?> deltas;

  @override
  State<_TodayAxisRail> createState() => _TodayAxisRailState();
}

class _TodayAxisRailState extends State<_TodayAxisRail> {
  int? _selectedIndex;

  static const _labels = ['운동', '식단', '장', '혈액'];
  static const _axes = [
    DfetAxis.motion,
    DfetAxis.nutrition,
    DfetAxis.gut,
    DfetAxis.blood,
  ];

  void _select(int index) {
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = _selectedIndex == index ? null : index);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / _axes.length;
        final nodeSize = math.min(78.0, math.max(58.0, cellWidth - 10));
        return Column(
          children: [
            Stack(
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
                          delta: widget.deltas[index],
                          size: nodeSize,
                          selected: _selectedIndex == index,
                          onTap: () => _select(index),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            AnimatedSize(
              duration: DfetMotion.standard,
              curve: DfetMotion.emphasized,
              child: AnimatedSwitcher(
                duration: DfetMotion.standard,
                switchInCurve: DfetMotion.emphasized,
                switchOutCurve: DfetMotion.emphasized,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: -1,
                    child: child,
                  ),
                ),
                child: _selectedIndex == null
                    ? const SizedBox(
                        key: ValueKey('axis-detail-empty'),
                        width: double.infinity,
                      )
                    : Padding(
                        key: ValueKey(_selectedIndex),
                        padding: const EdgeInsets.only(top: 16),
                        child: _AxisDetail(
                          axis: _axes[_selectedIndex!],
                          label: _labels[_selectedIndex!],
                          delta: widget.deltas[_selectedIndex!],
                        ),
                      ),
              ),
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
    required this.selected,
    required this.onTap,
  });

  final DfetAxis axis;
  final String label;
  final double? delta;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final axisColor = DfetAxisPalette.color(context, axis);
    final value = delta == null
        ? '확인 필요'
        : '${delta! > 0 ? '+' : ''}${delta!.toStringAsFixed(0)}';
    return Semantics(
      button: true,
      selected: selected,
      label:
          '$label 변화 자세히 보기, ${delta == null ? '확인 필요' : '${delta!.toStringAsFixed(0)}점 변화'}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onTap,
          radius: size * 0.65,
          child: AnimatedScale(
            scale: selected ? 1.06 : 1,
            duration: DfetMotion.quick,
            curve: DfetMotion.emphasized,
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: DfetMotion.quick,
                      curve: DfetMotion.emphasized,
                      width: size,
                      height: size,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? context.wellness.bgCard
                            : const Color(0xFFFBF8F1),
                        border: Border.all(
                          color: selected ? axisColor : const Color(0xFF0D1933),
                          width: selected ? 5 : 4,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: axisColor.withValues(alpha: 0.25),
                                  blurRadius: 18,
                                  spreadRadius: 2,
                                ),
                              ]
                            : const [],
                      ),
                      child: DfetAxisAssetIcon(axis: axis, size: size * 0.58),
                    ),
                    Positioned(
                      bottom: -5,
                      child: AnimatedContainer(
                        duration: DfetMotion.quick,
                        width: selected ? 19 : 16,
                        height: selected ? 19 : 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: axisColor,
                          border: Border.all(
                            color:
                                Theme.of(context).brightness == Brightness.dark
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
                    color: delta == null
                        ? context.wellness.textSecondary
                        : axisColor,
                    fontSize: delta == null ? 11 : 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AxisDetail extends StatelessWidget {
  const _AxisDetail({
    required this.axis,
    required this.label,
    required this.delta,
  });

  final DfetAxis axis;
  final String label;
  final double? delta;

  @override
  Widget build(BuildContext context) {
    final axisColor = DfetAxisPalette.color(context, axis);
    final message = switch (delta) {
      null => '$label 축은 비교할 기록이 더 필요해요',
      > 0 => '$label 축은 이전 기록보다 ${delta!.toStringAsFixed(0)}점 좋아졌어요',
      < 0 => '$label 축은 이전 기록보다 ${delta!.abs().toStringAsFixed(0)}점 낮게 관찰됐어요',
      _ => '$label 축은 이전 기록과 같은 흐름이에요',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: axisColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: axisColor.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          DfetAxisAssetIcon(axis: axis, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: context.wellness.textPrimary,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPulsePanel extends StatefulWidget {
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
  State<_ActionPulsePanel> createState() => _ActionPulsePanelState();
}

class _ActionPulsePanelState extends State<_ActionPulsePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: DfetMotion.pulse,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulseController.value = 1;
    } else if (_pulseController.isDismissed) {
      _pulseController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _ActionPulsePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.completed != widget.completed &&
        !MediaQuery.disableAnimationsOf(context)) {
      _pulseController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completed = widget.completed;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipPath(
          clipper: const _ActionPanelClipper(),
          child: ColoredBox(
            color: const Color(0xFF0D1933),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) => CustomPaint(
                        painter: _PulsePainter(_pulseController.value),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 48, 30, 46),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: DfetMotion.standard,
                        switchInCurve: DfetMotion.emphasized,
                        child: Text(
                          completed ? '오늘의 한 걸음 완료' : '오늘의 한 가지',
                          key: ValueKey('eyebrow-$completed'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      AnimatedSwitcher(
                        duration: DfetMotion.standard,
                        switchInCurve: DfetMotion.emphasized,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.18),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: Text(
                          completed ? '오늘 신호를 이었어요' : widget.title,
                          key: ValueKey('title-$completed'),
                          style: DfetTypography.displayStyle(
                            color: Colors.white,
                            fontSize: 27,
                            height: 1.18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.7,
                          ),
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
                                  TextSpan(text: '${widget.duration} · '),
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
                          onTap: widget.onToggle,
                          borderRadius: BorderRadius.circular(36),
                          child: AnimatedContainer(
                            duration: DfetMotion.standard,
                            curve: DfetMotion.emphasized,
                            height: 58,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(36),
                              gradient: LinearGradient(
                                colors: completed
                                    ? const [
                                        Color(0xFF1769E8),
                                        Color(0xFF8058EF),
                                      ]
                                    : const [
                                        Color(0xFFFF4D55),
                                        Color(0xFFFF675B),
                                      ],
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: DfetMotion.quick,
                              child: Row(
                                key: ValueKey('button-$completed'),
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
          child: AnimatedScale(
            scale: completed ? 1.12 : 1,
            duration: DfetMotion.standard,
            curve: DfetMotion.emphasized,
            child: AnimatedContainer(
              duration: DfetMotion.standard,
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed
                    ? const Color(0xFF8058EF)
                    : const Color(0xFFFF5A57),
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 30),
            ),
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
  const _PulsePainter(this.progress);

  final double progress;

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
          math.pi * 0.78 +
              dash * 0.32 +
              progress * 0.24 * (ring.isEven ? 1 : -1),
          0.17,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) =>
      oldDelegate.progress != progress;
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
