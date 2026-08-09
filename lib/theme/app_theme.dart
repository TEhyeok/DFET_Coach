import 'package:flutter/material.dart';

import 'd_fet_typography.dart';
import 'tokens.dart';

/// 라이트 테마 (Admin Web 등에서 사용)
ThemeData appThemeLight() {
  final base = ThemeData.light(useMaterial3: true);
  final textTheme = DfetTypography.applyUiFont(
    base.textTheme,
    bodyColor: AppColorsLight.textBody,
    displayColor: AppColorsLight.textBody,
  );
  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColorsLight.brandPrimary,
      brightness: Brightness.light,
      surface: AppColorsLight.bgCard,
      primary: AppColorsLight.brandPrimary,
      onPrimary: Colors.white,
      onSurface: WellnessColors.textPrimary,
      onSurfaceVariant: WellnessColors.textSecondary,
      secondary: AppColorsLight.accentGold,
      error: AppColorsLight.danger,
    ),
    scaffoldBackgroundColor: AppColorsLight.bgApp,
    cardTheme: CardThemeData(
      color: AppColorsLight.bgCard,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xxl),
        side: const BorderSide(color: AppColorsLight.bgStroke),
      ),
      margin: const EdgeInsets.all(0),
    ),
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColorsLight.bgApp,
      foregroundColor: AppColorsLight.textStrong,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColorsLight.bgCard,
      indicatorColor: AppColorsLight.brandPrimary.withValues(alpha: 0.15),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelSmall?.copyWith(
          color:
              selected ? WellnessColors.primary : WellnessColors.textTertiary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: WellnessColors.primary);
        }
        return const IconThemeData(color: WellnessColors.textTertiary);
      }),
    ),
  );
}

/// 다크 테마 (모바일 앱 메인 테마)
ThemeData appThemeDark() {
  final base = ThemeData.dark(useMaterial3: true);
  final textTheme = DfetTypography.applyUiFont(
    base.textTheme,
    bodyColor: WellnessColorsDark.textPrimary,
    displayColor: WellnessColorsDark.textPrimary,
  );
  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: WellnessColorsDark.primary,
      brightness: Brightness.dark,
      surface: WellnessColorsDark.bgCard,
      primary: WellnessColorsDark.primary,
      onPrimary: WellnessColorsDark.onPrimary,
      onSurface: WellnessColorsDark.textPrimary,
      onSurfaceVariant: WellnessColorsDark.textSecondary,
      secondary: WellnessColorsDark.accent,
      error: WellnessColorsDark.danger,
    ),
    scaffoldBackgroundColor: WellnessColorsDark.bgApp,
    cardTheme: CardThemeData(
      color: WellnessColorsDark.bgCard,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xxl),
        side: const BorderSide(color: WellnessColorsDark.border),
      ),
      margin: const EdgeInsets.all(0),
    ),
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: WellnessColorsDark.bgApp,
      foregroundColor: WellnessColorsDark.textPrimary,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: WellnessColorsDark.bgCard,
      indicatorColor: WellnessColorsDark.primary.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelSmall?.copyWith(
          color: selected
              ? WellnessColorsDark.primaryDark
              : WellnessColorsDark.textSecondary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: WellnessColorsDark.primaryDark);
        }
        return const IconThemeData(color: WellnessColorsDark.textSecondary);
      }),
    ),
  );
}
