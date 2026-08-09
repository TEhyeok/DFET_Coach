import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'd_fet_axis_glyph.dart';

class DfetAxisPalette {
  const DfetAxisPalette._();

  static Color color(BuildContext context, DfetAxis axis) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return switch ((axis, isDark)) {
      (DfetAxis.motion, false) => const Color(0xFF1F5FD1),
      (DfetAxis.nutrition, false) => const Color(0xFFB85C00),
      (DfetAxis.gut, false) => const Color(0xFF684AC5),
      (DfetAxis.blood, false) => const Color(0xFFB93E50),
      (DfetAxis.motion, true) => const Color(0xFF3478F6),
      (DfetAxis.nutrition, true) => const Color(0xFFF59E45),
      (DfetAxis.gut, true) => const Color(0xFF8A6FE8),
      (DfetAxis.blood, true) => const Color(0xFFE85D68),
    };
  }

  static Color surface(BuildContext context, DfetAxis axis) =>
      color(context, axis).withValues(alpha: 0.12);
}

class DfetAxisAssetIcon extends StatelessWidget {
  const DfetAxisAssetIcon({
    super.key,
    required this.axis,
    this.size = 32,
    this.active = true,
  });

  final DfetAxis axis;
  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget image = Image.asset(
      _assetPath(axis),
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );

    if (!active || isDark) {
      image = ColorFiltered(
        colorFilter: ColorFilter.mode(
          active
              ? DfetAxisPalette.color(context, axis)
              : context.wellness.textTertiary,
          BlendMode.srcIn,
        ),
        child: image,
      );
    }

    return Semantics(
      image: true,
      label: '${_axisLabel(axis)} 축 아이콘',
      child: SizedBox.square(dimension: size, child: image),
    );
  }

  static String _assetPath(DfetAxis axis) => switch (axis) {
        DfetAxis.motion => 'assets/images/axis_icons/axis_motion.png',
        DfetAxis.nutrition => 'assets/images/axis_icons/axis_nutrition.png',
        DfetAxis.gut => 'assets/images/axis_icons/axis_gut.png',
        DfetAxis.blood => 'assets/images/axis_icons/axis_blood.png',
      };

  static String _axisLabel(DfetAxis axis) => switch (axis) {
        DfetAxis.motion => '운동',
        DfetAxis.nutrition => '식단',
        DfetAxis.gut => '장',
        DfetAxis.blood => '혈액',
      };
}
