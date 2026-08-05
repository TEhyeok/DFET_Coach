import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum DfetAxis { motion, nutrition, gut, blood }

enum DfetSignalState { idle, live, locked, off }

class DfetAxisGlyph extends StatelessWidget {
  const DfetAxisGlyph({
    super.key,
    required this.axis,
    this.signalState = DfetSignalState.idle,
    this.size = 64,
  });

  final DfetAxis axis;
  final DfetSignalState signalState;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.wellness;
    final foreground = switch (signalState) {
      DfetSignalState.idle => colors.textSecondary,
      DfetSignalState.live => colors.textPrimary,
      DfetSignalState.locked => colors.textPrimary,
      DfetSignalState.off => colors.textTertiary.withValues(alpha: 0.45),
    };
    final signal = switch (signalState) {
      DfetSignalState.idle => colors.textTertiary,
      DfetSignalState.live => colors.energy,
      DfetSignalState.locked => colors.success,
      DfetSignalState.off => colors.textTertiary.withValues(alpha: 0.35),
    };

    return Semantics(
      image: true,
      label: '${_axisLabel(axis)} 축 ${_stateLabel(signalState)} 신호',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _DfetAxisGlyphPainter(
              axis: axis,
              signalState: signalState,
              foreground: foreground,
              signal: signal,
            ),
          ),
        ),
      ),
    );
  }

  static String _axisLabel(DfetAxis axis) => switch (axis) {
        DfetAxis.motion => '운동',
        DfetAxis.nutrition => '식단',
        DfetAxis.gut => '장',
        DfetAxis.blood => '혈액',
      };

  static String _stateLabel(DfetSignalState state) => switch (state) {
        DfetSignalState.idle => '대기',
        DfetSignalState.live => '측정 중',
        DfetSignalState.locked => '확정',
        DfetSignalState.off => '비활성',
      };
}

class _DfetAxisGlyphPainter extends CustomPainter {
  const _DfetAxisGlyphPainter({
    required this.axis,
    required this.signalState,
    required this.foreground,
    required this.signal,
  });

  final DfetAxis axis;
  final DfetSignalState signalState;
  final Color foreground;
  final Color signal;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);

    final frame = Paint()
      ..color = foreground.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.square;
    final trace = Paint()
      ..color = foreground
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;
    final activeTrace = Paint()
      ..color = signal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;

    _drawInstrumentFrame(canvas, frame);
    switch (axis) {
      case DfetAxis.motion:
        _drawMotion(canvas, trace, activeTrace);
        break;
      case DfetAxis.nutrition:
        _drawNutrition(canvas, trace, activeTrace);
        break;
      case DfetAxis.gut:
        _drawGut(canvas, trace, activeTrace);
        break;
      case DfetAxis.blood:
        _drawBlood(canvas, trace, activeTrace);
        break;
    }
    _drawStateTerminal(canvas, trace);
    canvas.restore();
  }

  void _drawInstrumentFrame(Canvas canvas, Paint paint) {
    final corners = <Path>[
      Path()
        ..moveTo(15, 6)
        ..lineTo(6, 6)
        ..lineTo(6, 15),
      Path()
        ..moveTo(49, 6)
        ..lineTo(58, 6)
        ..lineTo(58, 15),
      Path()
        ..moveTo(6, 49)
        ..lineTo(6, 58)
        ..lineTo(15, 58),
      Path()
        ..moveTo(49, 58)
        ..lineTo(58, 58)
        ..lineTo(58, 49),
    ];
    for (final corner in corners) {
      canvas.drawPath(corner, paint);
    }
    for (final y in [23.0, 32.0, 41.0]) {
      canvas.drawLine(const Offset(6, 0) + Offset(0, y), Offset(9, y), paint);
      canvas.drawLine(Offset(55, y), Offset(58, y), paint);
    }
  }

  void _drawMotion(Canvas canvas, Paint trace, Paint active) {
    _node(canvas, const Offset(38, 14), signal, hollow: true);

    final body = Path()
      ..moveTo(35, 20)
      ..lineTo(30, 31)
      ..lineTo(38, 39)
      ..lineTo(48, 34);
    canvas.drawPath(body, trace);
    canvas.drawLine(const Offset(32, 25), const Offset(23, 20), trace);
    canvas.drawLine(const Offset(32, 25), const Offset(43, 28), trace);
    canvas.drawLine(const Offset(30, 31), const Offset(22, 44), trace);
    canvas.drawLine(const Offset(22, 44), const Offset(13, 44), trace);
    canvas.drawLine(const Offset(30, 31), const Offset(38, 39), active);
    canvas.drawLine(const Offset(38, 39), const Offset(48, 34), active);

    canvas.drawLine(const Offset(12, 25), const Offset(20, 25), trace);
    canvas.drawLine(const Offset(10, 31), const Offset(18, 31), trace);
    canvas.drawLine(const Offset(12, 37), const Offset(18, 37), trace);
    _node(canvas, const Offset(30, 31), trace.color);
  }

  void _drawNutrition(Canvas canvas, Paint trace, Paint active) {
    for (final source in [
      (const Offset(20, 16), 24.0),
      (const Offset(32, 12), 25.0),
      (const Offset(44, 17), 25.0),
    ]) {
      _node(canvas, source.$1, trace.color, hollow: true);
      canvas.drawLine(source.$1 + const Offset(0, 4),
          Offset(source.$1.dx, source.$2), trace);
    }

    canvas.drawLine(const Offset(17, 28), const Offset(47, 28), active);
    final bowl = Path()
      ..moveTo(15, 31)
      ..cubicTo(17, 42, 23, 48, 32, 48)
      ..cubicTo(41, 48, 47, 42, 49, 31);
    canvas.drawPath(bowl, trace);
    canvas.drawLine(const Offset(21, 37), const Offset(43, 37), trace);
    _node(canvas, const Offset(32, 48), signal);
  }

  void _drawGut(Canvas canvas, Paint trace, Paint active) {
    final field = Paint()
      ..color = trace.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(const Offset(20, 21), const Offset(31, 31), field);
    canvas.drawLine(const Offset(31, 31), const Offset(46, 20), field);
    canvas.drawLine(const Offset(31, 31), const Offset(20, 44), field);
    canvas.drawLine(const Offset(31, 31), const Offset(47, 43), active);
    canvas.drawLine(const Offset(20, 21), const Offset(20, 44), field);

    canvas.drawCircle(const Offset(31, 31), 7, field);
    canvas.drawCircle(const Offset(20, 21), 4, field);
    canvas.drawCircle(const Offset(46, 20), 3, field);
    canvas.drawCircle(const Offset(20, 44), 3, field);
    canvas.drawCircle(const Offset(47, 43), 5, field);
    _node(canvas, const Offset(31, 31), trace.color);
    _node(canvas, const Offset(47, 43), signal);
  }

  void _drawBlood(Canvas canvas, Paint trace, Paint active) {
    final drop = Path()
      ..moveTo(32, 12)
      ..cubicTo(28, 20, 19, 29, 19, 38)
      ..cubicTo(19, 47, 25, 51, 32, 51)
      ..cubicTo(39, 51, 45, 47, 45, 38)
      ..cubicTo(45, 29, 36, 20, 32, 12);
    canvas.drawPath(drop, trace);

    final pulse = Path()
      ..moveTo(14, 36)
      ..lineTo(23, 36)
      ..lineTo(27, 29)
      ..lineTo(32, 43)
      ..lineTo(37, 33)
      ..lineTo(41, 36)
      ..lineTo(50, 36);
    canvas.drawPath(pulse, active);
    _node(canvas, const Offset(14, 36), trace.color, hollow: true);
    _node(canvas, const Offset(50, 36), signal);
  }

  void _drawStateTerminal(Canvas canvas, Paint trace) {
    switch (signalState) {
      case DfetSignalState.idle:
        canvas.drawCircle(
          const Offset(53, 53),
          2.5,
          Paint()
            ..color = signal
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
        break;
      case DfetSignalState.live:
        _node(canvas, const Offset(53, 53), signal);
        canvas.drawLine(const Offset(45, 53), const Offset(49, 53), trace);
        break;
      case DfetSignalState.locked:
        _node(canvas, const Offset(53, 53), signal);
        canvas.drawCircle(
          const Offset(53, 53),
          5,
          Paint()
            ..color = signal
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
        break;
      case DfetSignalState.off:
        canvas.drawLine(
          const Offset(49, 49),
          const Offset(57, 57),
          Paint()
            ..color = signal
            ..strokeWidth = 1.4,
        );
        break;
    }
  }

  void _node(Canvas canvas, Offset center, Color color, {bool hollow = false}) {
    final paint = Paint()
      ..color = color
      ..style = hollow ? PaintingStyle.stroke : PaintingStyle.fill
      ..strokeWidth = 1.6;
    canvas.drawCircle(center, hollow ? 2.4 : 2.8, paint);
  }

  @override
  bool shouldRepaint(covariant _DfetAxisGlyphPainter oldDelegate) {
    return axis != oldDelegate.axis ||
        signalState != oldDelegate.signalState ||
        foreground != oldDelegate.foreground ||
        signal != oldDelegate.signal;
  }
}

class DfetSignalDivider extends StatelessWidget {
  const DfetSignalDivider({super.key, this.height = 20});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _DfetSignalDividerPainter(
          line: context.wellness.border,
          signal: context.wellness.energy,
        ),
      ),
    );
  }
}

class _DfetSignalDividerPainter extends CustomPainter {
  const _DfetSignalDividerPainter({required this.line, required this.signal});

  final Color line;
  final Color signal;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final linePaint = Paint()
      ..color = line
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset.zero + Offset(0, y), Offset(size.width, y), linePaint);
    final start = math.min(42.0, size.width * 0.18);
    canvas.drawLine(
      Offset(start, y),
      Offset(start + 28, y),
      Paint()
        ..color = signal
        ..strokeWidth = 3,
    );
    canvas.drawCircle(Offset(start + 28, y), 3.5, Paint()..color = signal);
  }

  @override
  bool shouldRepaint(covariant _DfetSignalDividerPainter oldDelegate) {
    return line != oldDelegate.line || signal != oldDelegate.signal;
  }
}
