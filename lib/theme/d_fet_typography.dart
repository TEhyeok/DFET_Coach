import 'package:flutter/material.dart';

abstract final class DfetTypography {
  static const uiFontFamily = 'IBMPlexSansKR';
  static const displayFontFamily = 'GowunBatang';
  static const dataFontFamily = 'IBMPlexMono';

  static const tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static TextTheme applyUiFont(
    TextTheme base, {
    required Color bodyColor,
    required Color displayColor,
  }) {
    return base.apply(
      fontFamily: uiFontFamily,
      bodyColor: bodyColor,
      displayColor: displayColor,
    );
  }

  static TextStyle displayStyle({
    required Color color,
    required double fontSize,
    FontWeight fontWeight = FontWeight.w700,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      color: color,
      fontFamily: displayFontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle dataStyle({
    required Color color,
    required double fontSize,
    FontWeight fontWeight = FontWeight.w700,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      color: color,
      fontFamily: dataFontFamily,
      fontFeatures: tabularFigures,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}
