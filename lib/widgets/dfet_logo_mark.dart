import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class DfetLogoMark extends StatelessWidget {
  const DfetLogoMark({
    super.key,
    required this.size,
    this.contrastBackground = true,
    this.backgroundColor = PremiumColors.backgroundStart,
    this.borderColor,
    this.borderRadius,
    this.paddingRatio = 0.14,
    this.showShadow = true,
  });

  final double size;
  final bool contrastBackground;
  final Color backgroundColor;
  final Color? borderColor;
  final double? borderRadius;
  final double paddingRatio;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      'assets/image/D-FET_logo.png',
      fit: BoxFit.contain,
    );

    if (!contrastBackground) {
      return SizedBox(
        width: size,
        height: size,
        child: logo,
      );
    }

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * paddingRatio),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius ?? size * 0.24),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.14),
        ),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: size * 0.22,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      child: logo,
    );
  }
}
