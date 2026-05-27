import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminTheme {
  // --- Colors ---
  // --- Colors ---
  static const Color background = Color(0xFF000000); // Pure Black
  static const Color surface = Color(0xFF121212); // Material Dark Surface
  static const Color surfaceHighlight = Color(0xFF1E1E1E); // Slightly lighter for hover

  static const Color primary = Color(0xFF6C5DD3); // Modern Purple
  static const Color secondary = Color(0xFF3F8CFF); // Bright Blue
  static const Color accent = Color(0xFF00D2FF); // Cyan/Neon

  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF1C40F);
  static const Color error = Color(0xFFFF4757);

  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0AEC0);
  static const Color textDisabled = Color(0xFF4A5568);

  // --- Gradients ---
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C5DD3), Color(0xFF8F75FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF00D2FF), Color(0xFF3A7BD5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF121212), Color(0xFF0A0A0A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // --- Text Styles ---
  static TextStyle get displayLarge => GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textWhite,
      );

  static TextStyle get displayMedium => GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textWhite,
      );

  static TextStyle get displaySmall => GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textWhite,
      );

  static TextStyle get titleLarge => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textWhite,
      );

  static TextStyle get titleMedium => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textWhite,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        color: textSecondary,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        color: textSecondary,
      );

  // --- Light Mode Colors ---
  static const Color backgroundLight = Color(0xFFF7F9FC); // Light Background
  static const Color surfaceLight = Color(0xFFFFFFFF); // White Surface
  static const Color surfaceHighlightLight = Color(0xFFF1F5F9); // Light Hover

  static const Color textPrimaryLight = Color(0xFF1A202C); // Dark Text
  static const Color textSecondaryLight = Color(0xFF718096); // Gray Text
  static const Color textDisabledLight = Color(0xFFA0AEC0); // Disabled Text

  // --- Gradients (Light) ---
  static const LinearGradient surfaceGradientLight = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // --- Glassmorphism ---
  static BoxDecoration glassDecoration({
    double opacity = 0.05, // Reduced opacity for darker look
    double borderRadius = 16,
    Color color = Colors.white,
    bool isLight = false,
  }) {
    return BoxDecoration(
      color: isLight ? color.withOpacity(0.7) : const Color(0xFF1E1E1E).withOpacity(0.6), // Darker glass in dark mode
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isLight ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.08),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isLight ? 0.05 : 0.1),
          blurRadius: 16,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSurface: textWhite,
      ),
      textTheme: TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        titleLarge: titleLarge,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
      ),
      iconTheme: const IconThemeData(color: textSecondary),
      dividerColor: Colors.white.withOpacity(0.05),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: backgroundLight,
      primaryColor: primary,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: surfaceLight,
        error: error,
        onPrimary: Colors.white,
        onSurface: textPrimaryLight,
      ),
      textTheme: TextTheme(
        displayLarge: displayLarge.copyWith(color: textPrimaryLight),
        displayMedium: displayMedium.copyWith(color: textPrimaryLight),
        titleLarge: titleLarge.copyWith(color: textPrimaryLight),
        bodyLarge: bodyLarge.copyWith(color: textSecondaryLight),
        bodyMedium: bodyMedium.copyWith(color: textSecondaryLight),
      ),
      iconTheme: const IconThemeData(color: textSecondaryLight),
      dividerColor: Colors.black.withOpacity(0.05),
    );
  }
}

class AdminColors {
  static const Color primary = AdminTheme.primary;
  static const Color secondary = AdminTheme.secondary;
  static const Color background = AdminTheme.background; // Added
  static const Color surface = AdminTheme.surface;
  static const Color border = Color(0xFF2D2D2D); // Dark border
  static const Color error = AdminTheme.error; // Added
  
  static const Color textPrimary = AdminTheme.textWhite;
  static const Color textSecondary = AdminTheme.textSecondary;
  static const Color textTertiary = AdminTheme.textDisabled; // Added
}
