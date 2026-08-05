import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design_system/d_fet_axis_glyph.dart';
import '../theme/tokens.dart';

class DesignLabAtomsScreen extends StatefulWidget {
  const DesignLabAtomsScreen({super.key});

  @override
  State<DesignLabAtomsScreen> createState() => _DesignLabAtomsScreenState();
}

class _DesignLabAtomsScreenState extends State<DesignLabAtomsScreen> {
  DfetAxis _selectedAxis = DfetAxis.motion;

  @override
  Widget build(BuildContext context) {
    final colors = context.wellness;
    return Scaffold(
      backgroundColor: colors.bgRoot,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LabTopBar(onClose: () => Navigator.of(context).pop()),
              const SizedBox(height: 32),
              Text(
                'ATOM / 01',
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '4-AXIS\nSIGNAL GLYPHS',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 33,
                  height: 0.98,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.4,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '축의 특징을 먼저 읽고, 측정 상태를 이어서 봅니다. 동작 궤적, 영양 유입, 미생물 군집, 혈액 파형이 기능의 고유 신호가 됩니다.',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              const DfetSignalDivider(),
              const SizedBox(height: 14),
              _LabSectionLabel(
                index: '01',
                title: 'SIGNAL FAMILY',
                detail: 'SELECT ONE AXIS',
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 320 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.15;
                  return GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: compact ? 0.72 : 0.95,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final axis in DfetAxis.values)
                        _AxisLabTile(
                          axis: axis,
                          selected: _selectedAxis == axis,
                          glyphSize: compact ? 58 : 72,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedAxis = axis);
                          },
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              _LabSectionLabel(
                index: '02',
                title: 'SIGNAL STATES',
                detail: 'SELECTED / ${_axisEnglish(_selectedAxis)}',
              ),
              const SizedBox(height: 12),
              _InstrumentPanel(
                child: Row(
                  children: [
                    for (final state in DfetSignalState.values)
                      Expanded(
                        child: _StateSpecimen(
                          axis: _selectedAxis,
                          signalState: state,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _LabSectionLabel(
                index: '03',
                title: 'OPTICAL SCALE',
                detail: '24 / 40 / 64',
              ),
              const SizedBox(height: 12),
              _InstrumentPanel(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final size in [24.0, 40.0, 64.0])
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DfetAxisGlyph(
                              axis: _selectedAxis,
                              signalState: DfetSignalState.live,
                              size: size,
                            ),
                            const SizedBox(height: 9),
                            Text(
                              '${size.round()} PX',
                              style: TextStyle(
                                color: colors.textTertiary,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _LabSectionLabel(
                index: '04',
                title: 'CONSTRUCTION RULE',
                detail: 'SYSTEM LOCKED',
              ),
              const SizedBox(height: 12),
              _InstrumentPanel(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _RuleToken(code: 'S', value: '2.6', label: 'TRACE'),
                    _RuleToken(code: 'G', value: '8', label: 'GRID'),
                    _RuleToken(code: 'N', value: '2.8', label: 'NODE'),
                    _RuleToken(code: 'C', value: '9', label: 'CORNER'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'DFET VISUAL INSTRUMENT / REV.02',
                style: TextStyle(
                  color: colors.textTertiary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabTopBar extends StatelessWidget {
  const _LabTopBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.wellness;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'D-FET / DESIGN LAB',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'VISUAL INSTRUMENT SYSTEM',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textTertiary,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          label: '디자인 랩 닫기',
          child: GestureDetector(
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: colors.energy, width: 3),
                  top: BorderSide(color: colors.border),
                  right: BorderSide(color: colors.border),
                  bottom: BorderSide(color: colors.border),
                ),
              ),
              child: Text(
                'RETURN',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AxisLabTile extends StatelessWidget {
  const _AxisLabTile({
    required this.axis,
    required this.selected,
    required this.glyphSize,
    required this.onTap,
  });

  final DfetAxis axis;
  final bool selected;
  final double glyphSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.wellness;
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      selected: selected,
      label: '${_axisKorean(axis)} 축 신호 선택',
      child: GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          painter: _InstrumentPanelPainter(
            background: colors.bgCard,
            border: selected ? colors.energy : colors.border,
            grid: colors.borderSubtle,
            selected: selected,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _axisCode(axis),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        style: TextStyle(
                          color: selected ? colors.accent : colors.textTertiary,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        selected ? 'LIVE' : 'IDLE',
                        style: TextStyle(
                          color: selected ? colors.accent : colors.textTertiary,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Center(
                  child: DfetAxisGlyph(
                    axis: axis,
                    signalState:
                        selected ? DfetSignalState.live : DfetSignalState.idle,
                    size: glyphSize,
                  ),
                ),
                const Spacer(),
                Text(
                  _axisKorean(axis),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _axisEnglish(axis),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
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

class _LabSectionLabel extends StatelessWidget {
  const _LabSectionLabel({
    required this.index,
    required this.title,
    required this.detail,
  });

  final String index;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.wellness;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.textPrimary,
          ),
          child: Text(
            index,
            style: TextStyle(
              color: colors.bgRoot,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: colors.textTertiary,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _InstrumentPanel extends StatelessWidget {
  const _InstrumentPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.wellness;
    return CustomPaint(
      painter: _InstrumentPanelPainter(
        background: colors.bgCard,
        border: colors.border,
        grid: colors.borderSubtle,
        selected: false,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
        child: child,
      ),
    );
  }
}

class _InstrumentPanelPainter extends CustomPainter {
  const _InstrumentPanelPainter({
    required this.background,
    required this.border,
    required this.grid,
    required this.selected,
  });

  final Color background;
  final Color border;
  final Color grid;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    const cut = 12.0;
    final shape = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width - cut, 0)
      ..lineTo(size.width, cut)
      ..lineTo(size.width, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height - cut)
      ..close();
    canvas.drawPath(shape, Paint()..color = background);
    canvas.save();
    canvas.clipPath(shape);
    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.42)
      ..strokeWidth = 0.7;
    for (var x = 32.0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 32.0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    canvas.restore();
    canvas.drawPath(
      shape,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.8 : 1,
    );
    if (selected) {
      canvas.drawLine(
        const Offset(0, 0),
        Offset(42, 0),
        Paint()
          ..color = border
          ..strokeWidth = 4,
      );
      canvas.drawCircle(const Offset(42, 0), 3.2, Paint()..color = border);
    }
  }

  @override
  bool shouldRepaint(covariant _InstrumentPanelPainter oldDelegate) {
    return background != oldDelegate.background ||
        border != oldDelegate.border ||
        grid != oldDelegate.grid ||
        selected != oldDelegate.selected;
  }
}

class _StateSpecimen extends StatelessWidget {
  const _StateSpecimen({required this.axis, required this.signalState});

  final DfetAxis axis;
  final DfetSignalState signalState;

  @override
  Widget build(BuildContext context) {
    final colors = context.wellness;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DfetAxisGlyph(axis: axis, signalState: signalState, size: 42),
        const SizedBox(height: 8),
        Text(
          _stateCode(signalState),
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _RuleToken extends StatelessWidget {
  const _RuleToken({
    required this.code,
    required this.value,
    required this.label,
  });

  final String code;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.wellness;
    return Container(
      width: 68,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: colors.energy, width: 2),
          top: BorderSide(color: colors.borderSubtle),
          right: BorderSide(color: colors.borderSubtle),
          bottom: BorderSide(color: colors.borderSubtle),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$code / $value',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: colors.textTertiary,
              fontSize: 7,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

String _axisCode(DfetAxis axis) => switch (axis) {
      DfetAxis.motion => 'AX-01',
      DfetAxis.nutrition => 'AX-02',
      DfetAxis.gut => 'AX-03',
      DfetAxis.blood => 'AX-04',
    };

String _axisKorean(DfetAxis axis) => switch (axis) {
      DfetAxis.motion => '운동',
      DfetAxis.nutrition => '식단',
      DfetAxis.gut => '장',
      DfetAxis.blood => '혈액',
    };

String _axisEnglish(DfetAxis axis) => switch (axis) {
      DfetAxis.motion => 'MOTION TRACE',
      DfetAxis.nutrition => 'NUTRIENT INTAKE',
      DfetAxis.gut => 'MICROBE FIELD',
      DfetAxis.blood => 'HEMO PULSE',
    };

String _stateCode(DfetSignalState state) => switch (state) {
      DfetSignalState.idle => 'IDLE',
      DfetSignalState.live => 'LIVE',
      DfetSignalState.locked => 'LOCK',
      DfetSignalState.off => 'OFF',
    };
