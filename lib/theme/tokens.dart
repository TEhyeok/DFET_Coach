import 'package:flutter/material.dart';

/// Apple-inspired Design System
/// Based on Apple's Human Interface Guidelines

// ============================================================================
// APPLE COLORS - Light Mode
// ============================================================================

class AppleColors {
  // System Backgrounds
  static const bgPrimary = Color(0xFFF5F5F7); // Light gray background
  static const bgSecondary = Color(0xFFFFFFFF); // White
  static const bgTertiary = Color(0xFFFAFAFA); // Subtle gray

  // System Fill Colors
  static const fillPrimary = Color(0x14000000); // 8% black
  static const fillSecondary = Color(0x0F000000); // 6% black
  static const fillTertiary = Color(0x0A000000); // 4% black

  // Label Colors (Text)
  static const labelPrimary = Color(0xFF1D1D1F); // Almost black
  static const labelSecondary = Color(0xFF86868B); // Gray
  static const labelTertiary = Color(0xFFC7C7CC); // Light gray
  static const labelQuaternary = Color(0xFFE5E5EA); // Very light gray

  // Tint Colors (Accents)
  static const blue = Color(0xFF0071E3); // Apple Blue
  static const green = Color(0xFF34C759); // Success
  static const orange = Color(0xFFFF9500); // Warning
  static const red = Color(0xFFFF3B30); // Error/Destructive
  static const purple = Color(0xFF5E5CE6); // Purple accent
  static const pink = Color(0xFFFF2D55); // Pink accent

  // Separator Colors
  static const separatorOpaque = Color(0xFFC6C6C8);
  static const separatorNonOpaque = Color(0x3C3C4336);
}

// ============================================================================
// ADMIN COLORS - Optimized for Admin Dashboard
// ============================================================================

class AdminColors {
  // Backgrounds
  static const scaffoldBg = AppleColors.bgPrimary; // #F5F5F7
  static const cardBg = AppleColors.bgSecondary; // #FFFFFF
  static const sidebarBg = AppleColors.bgTertiary; // #FAFAFA

  // Text - Apple Typography Scale
  static const textPrimary = AppleColors.labelPrimary; // #1D1D1F
  static const textSecondary = AppleColors.labelSecondary; // #86868B
  static const textTertiary = AppleColors.labelTertiary; // #C7C7CC

  // Legacy naming for compatibility
  static const textStrong = AppleColors.labelPrimary;
  static const textBody = AppleColors.labelSecondary;
  static const textSubtle = AppleColors.labelTertiary;

  // Sidebar (Light Mode)
  static const sidebarText = AppleColors.labelPrimary;
  static const sidebarTextSubtle = AppleColors.labelSecondary;
  static const sidebarSelected = Color(0xFFE8F4FF); // Light blue tint
  static const sidebarHover = AppleColors.fillTertiary;

  // Brand Colors
  static const primary = AppleColors.blue; // #0071E3
  static const primaryLight = Color(0xFF4DA3FF); // Lighter blue
  static const primaryDark = Color(0xFF0056B3); // Darker blue
  static const primarySubtle = Color(0xFFE8F4FF); // Very light blue

  // Semantic Colors
  static const success = AppleColors.green; // #34C759
  static const warning = AppleColors.orange; // #FF9500
  static const error = AppleColors.red; // #FF3B30
  static const info = AppleColors.purple; // #5E5CE6

  static const secondary = AppleColors.pink; // #FF2D55

  // Separator
  static const separator = AppleColors.separatorOpaque;
  static const separatorLight = AppleColors.separatorNonOpaque;
}

// ============================================================================
// APPLE RADIUS - Rounded corners
// ============================================================================

class AppleRadius {
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;

  // Preset BorderRadius
  static const card = BorderRadius.all(Radius.circular(16.0));
  static const button = BorderRadius.all(Radius.circular(12.0));
  static const input = BorderRadius.all(Radius.circular(12.0));
  static const sidebar = BorderRadius.all(Radius.circular(16.0));
  static const avatar = BorderRadius.all(Radius.circular(12.0));
}

// Legacy support
class AppRadius {
  static const card = AppleRadius.card;
  static const button = AppleRadius.button;
  static const input = AppleRadius.input;
}

class Radii {
  static const xl = AppleRadius.md;
  static const xxl = AppleRadius.lg;
}

// ============================================================================
// APPLE SPACING - Consistent spacing system
// ============================================================================

class AppleSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 48.0;
  static const double massive = 64.0;

  // Section spacing
  static const double sectionGap = 56.0;
  static const double cardPadding = 32.0;
  static const double listItemPadding = 16.0;
}

// Legacy support
class Spacing {
  static const s = AppleSpacing.sm;
  static const m = AppleSpacing.md;
  static const l = AppleSpacing.lg;
  static const xl = AppleSpacing.xl;
  static const xxl = AppleSpacing.xxl;
}

// ============================================================================
// APPLE SHADOWS - Subtle elevation
// ============================================================================

class AppleShadows {
  // Card shadow - subtle and soft
  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  // Elevated card - more prominent
  static List<BoxShadow> cardElevated = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  // Hover state
  static List<BoxShadow> cardHover = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];

  // Sidebar shadow
  static List<BoxShadow> sidebar = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(2, 0),
    ),
  ];
}

// ============================================================================
// PREMIUM COLORS - New Design System
// ============================================================================

class PremiumColors {
  static const primary = Color(0xFFE94560); // Neon Pink
  static const backgroundStart = Color(0xFF1A1A2E); // Deep Blue
  static const backgroundEnd = Color(0xFF16213E); // Darker Blue
  static const cardBackground = Color(0xFF1F2943); // Slightly lighter blue for cards
  static const textWhite = Colors.white;
  static const textGrey = Colors.white70;
  static const secondary = Color(0xFF64D2FF); // Light Blue
}

// ============================================================================
// LEGACY SUPPORT - Updated to map to Premium Colors
// ============================================================================

class AppColorsDark {
  static const bgRoot   = PremiumColors.backgroundStart;
  static const bgApp    = PremiumColors.backgroundStart;
  static const bgCard   = PremiumColors.cardBackground;
  static const bgStroke = Color(0xFF2E3A59); // Subtle stroke
  static const textStrong = PremiumColors.textWhite;
  static const textBody   = PremiumColors.textGrey;
  static const textSubtle = Colors.white38;
  static const brandPrimary = PremiumColors.primary;
  static const brandPrimaryHover = Color(0xFFD63D56);
  static const accentGold = Color(0xFFFFB545);
  static const danger = Color(0xFFEF4444);
  static const warn   = Color(0xFFF59E0B);
  static const info   = Color(0xFF60A5FA);
}

class AppColorsLight {
  // Keeping Light mode as is for Admin, or mapping to Dark if we want full dark mode app
  // For now, let's keep it standard light for Admin, but Mobile App uses Dark mostly.
  static const bgRoot   = Color(0xFFFFFFFF);
  static const bgApp    = Color(0xFFF8F9FA);
  static const bgCard   = Color(0xFFFFFFFF);
  static const bgStroke = Color(0xFFE5E7EB);
  static const textStrong = Color(0xFF111827);
  static const textBody   = Color(0xFF374151);
  static const textSubtle = Color(0xFF6B7280);
  static const brandPrimary = Color(0xFF22C55E);
  static const brandPrimaryHover = Color(0xFF16A34A);
  static const accentGold = Color(0xFFEAB308);
  static const danger = Color(0xFFDC2626);
  static const warn   = Color(0xFFF59E0B);
  static const info   = Color(0xFF3B82F6);
}

class AppColors {
  static const bgRoot   = PremiumColors.backgroundStart;
  static const bgApp    = PremiumColors.backgroundStart;
  static const bgCard   = PremiumColors.cardBackground;
  static const bgStroke = Color(0xFF2E3A59);
  static const textStrong = PremiumColors.textWhite;
  static const textBody   = PremiumColors.textGrey;
  static const textSubtle = Colors.white38;
  static const textWeak = Colors.white24;
  static const brandPrimary = PremiumColors.primary;
  static const brandPrimaryHover = Color(0xFFD63D56);
  static const accentGold = Color(0xFFFFD60A);
  static const danger = Color(0xFFFF453A);
  static const warn   = Color(0xFFFF9F0A);
  static const info   = Color(0xFF64D2FF);
  static const success = Color(0xFF30D158);
}
