import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

/// 라이트 테마 (Admin Web 등에서 사용)
ThemeData appThemeLight() {
  final base = ThemeData.light(useMaterial3: true);
  final textTheme = GoogleFonts.outfitTextTheme(base.textTheme).apply(
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
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.labelSmall?.copyWith(color: AppColorsLight.textSubtle),
      ),
    ),
  );
}

/// 다크 테마 (모바일 앱 메인 테마)
ThemeData appThemeDark() {
  final base = ThemeData.dark(useMaterial3: true);
  final textTheme = GoogleFonts.outfitTextTheme(base.textTheme).apply(
    bodyColor: AppColorsDark.textBody,
    displayColor: AppColorsDark.textBody,
  );
  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColorsDark.brandPrimary,
      brightness: Brightness.dark,
      surface: AppColorsDark.bgCard,
      primary: AppColorsDark.brandPrimary,
      onPrimary: Colors.white,
      secondary: AppColorsDark.accentGold,
      error: AppColorsDark.danger,
    ),
    scaffoldBackgroundColor: AppColorsDark.bgApp,
    cardTheme: CardThemeData(
      color: AppColorsDark.bgCard,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xxl),
        side: const BorderSide(color: AppColorsDark.bgStroke),
      ),
      margin: const EdgeInsets.all(0),
    ),
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColorsDark.bgApp,
      foregroundColor: AppColorsDark.textStrong,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColorsDark.bgCard,
      indicatorColor: AppColorsDark.brandPrimary.withValues(alpha: 0.15),
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.labelSmall?.copyWith(color: AppColorsDark.textSubtle),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColorsDark.brandPrimary);
        }
        return const IconThemeData(color: AppColorsDark.textSubtle);
      }),
    ),
  );
}
