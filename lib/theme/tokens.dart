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
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  // Elevated card - more prominent
  static List<BoxShadow> cardElevated = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  // Hover state
  static List<BoxShadow> cardHover = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];

  // Sidebar shadow
  static List<BoxShadow> sidebar = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(2, 0),
    ),
  ];
}

// ============================================================================
// PREMIUM COLORS - New Design System
// ============================================================================

// 2026 개편: Soft Wellness 라이트 톤으로 값 교체 (멤버명 유지 → 전체 화면 일괄 전환)
class PremiumColors {
  static const primary = WellnessColors.primary; // 세이지 그린
  static const backgroundStart = WellnessColors.bgRoot; // 연한 민트 배경
  static const backgroundEnd = WellnessColors.bgRoot;
  static const cardBackground = WellnessColors.bgCard; // 화이트 카드
  static const textWhite = WellnessColors.textPrimary; // 다크 텍스트(라이트 배경용)
  static const textGrey = WellnessColors.textSecondary;
  static const secondary = WellnessColors.primaryLight;
}

// ============================================================================
// SOFT WELLNESS COLORS - New Light Design System (2026 개편)
// 파스텔 민트/세이지 · 부드럽고 친근 · 큰 라운드
// ============================================================================

// 2026 개편: 로고 기반 스포티 테마 (Navy #141F3A + Electric Lime #C6FF3D) — 라이트
class WellnessColors {
  // Backgrounds
  static const bgRoot = Color(0xFFF4F6FA); // 연한 쿨그레이 배경
  static const bgApp = Color(0xFFF4F6FA);
  static const bgCard = Color(0xFFFFFFFF); // 화이트 카드
  static const bgSubtle = Color(0xFFEAEEF5); // 칩/필드 (연그레이블루)

  // Brand — 라이트에서 primary=로고 네이비(버튼/강조), accent=라임(에너지)
  static const primary = Color(0xFF141F3A); // 로고 딥 네이비 (메인 액션)
  static const primaryDark = Color(0xFF0C1428); // 더 진한 네이비
  static const primaryLight = Color(0xFF2E3C5E); // 밝은 네이비
  static const primarySubtle = Color(0xFFE2E6F0); // 아주 연한 네이비 틴트
  static const onPrimary = Color(0xFFFFFFFF);

  // Energy accent — 일렉트릭 라임 (스포티 포인트). 라이트에선 진한 라임 텍스트 톤 병행
  static const accent = Color(0xFF5C8A00); // 라이트 배경용 가독 라임(텍스트/아이콘)
  static const accentSubtle = Color(0xFFEEF7D6); // 연한 라임 틴트(배경)
  // 링/게이지/진행바 등 굵은 그래픽 요소용 선명 라임 (라이트·다크 공통)
  static const energy = Color(0xFF9ACD1E); // 선명한 라임 그린

  // Text
  static const textPrimary = Color(0xFF141F3A); // 로고 네이비(거의 검정)
  static const textSecondary = Color(0xFF475467); // 본문: 흰 배경 대비 7.7:1
  static const textTertiary = Color(0xFF5F6B7C); // 보조: 연한 필드 배경 대비 4.6:1
  static const textOnTint = Color(0xFF141F3A);

  // Status
  static const success = Color(0xFF3FA34D);
  static const warning = Color(0xFFEE9A2C);
  static const danger = Color(0xFFE25247);
  static const info = Color(0xFF2C7BE5);

  // Borders
  static const border = Color(0xFFD8DEEA);
  static const borderSubtle = Color(0xFFE6EAF2);
}

/// Soft Wellness 라운드 (큰 라운드 특징)
class WellnessRadius {
  static const double sm = 14.0;
  static const double md = 18.0;
  static const double lg = 22.0;
  static const double xl = 28.0;

  static const card = BorderRadius.all(Radius.circular(22.0));
  static const cardLarge = BorderRadius.all(Radius.circular(28.0));
  static const chip = BorderRadius.all(Radius.circular(30.0));
  static const button = BorderRadius.all(Radius.circular(16.0));
}

/// 다크 — 로고 네이비 강화(차분·전문). primary=밝은 네이비-블루, 라임은 포인트(energy/accent)로만 절제.
class WellnessColorsDark {
  // Backgrounds (로고 네이비 계열 딥)
  static const bgRoot = Color(0xFF0E1730); // 딥 네이비
  static const bgApp = Color(0xFF0E1730);
  static const bgCard = Color(0xFF1A2444); // 카드(밝은 네이비)
  static const bgSubtle = Color(0xFF24305A); // 칩/필드

  // Brand — 다크에선 primary=밝은 네이비-블루(버튼/강조/탭), 그 위 텍스트는 흰색. 차분.
  static const primary = Color(0xFF6E8BD6); // 밝은 네이비-블루
  static const primaryDark = Color(0xFF8AA3E0);
  static const primaryLight = Color(0xFF4C68B0);
  static const primarySubtle = Color(0xFF22305A); // 네이비 틴트
  static const onPrimary = Color(0xFF0E1730); // primary 위 딥네이비 텍스트

  // 라임은 포인트로만 (게이지/링/소수 강조)
  static const accent = Color(0xFFC6FF3D); // 일렉트릭 라임 (절제된 포인트)
  static const accentSubtle = Color(0xFF2A3A1A);
  static const energy = Color(0xFFC6FF3D);

  // Text
  static const textPrimary = Color(0xFFEDF1FA); // 밝은 텍스트
  static const textSecondary = Color(0xFFA6B0CC);
  static const textTertiary = Color(0xFF909CBA); // 연한 필드 배경 대비 4.6:1
  static const textOnTint = Color(0xFF141F3A);

  // Status
  static const success = Color(0xFF5BD16A);
  static const warning = Color(0xFFF2B14E);
  static const danger = Color(0xFFF0746A);
  static const info = Color(0xFF5BA0F5);

  // Borders
  static const border = Color(0xFF2E3C64);
  static const borderSubtle = Color(0xFF263154);
}

/// Soft Wellness 부드러운 그림자
class WellnessShadows {
  static List<BoxShadow> card = [
    BoxShadow(
      color: const Color(0xFF1D9E75).withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
  static List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
  ];
}

// ============================================================================
// LEGACY SUPPORT - Updated to map to Premium Colors
// ============================================================================

class AppColorsDark {
  static const bgRoot = PremiumColors.backgroundStart;
  static const bgApp = PremiumColors.backgroundStart;
  static const bgCard = PremiumColors.cardBackground;
  static const bgStroke = Color(0xFF2E3A59); // Subtle stroke
  static const textStrong = PremiumColors.textWhite;
  static const textBody = PremiumColors.textGrey;
  static const textSubtle = Colors.white38;
  static const brandPrimary = PremiumColors.primary;
  static const brandPrimaryHover = Color(0xFFD63D56);
  static const accentGold = Color(0xFFFFB545);
  static const danger = Color(0xFFEF4444);
  static const warn = Color(0xFFF59E0B);
  static const info = Color(0xFF60A5FA);
}

class AppColorsLight {
  // Keeping Light mode as is for Admin, or mapping to Dark if we want full dark mode app
  // For now, let's keep it standard light for Admin, but Mobile App uses Dark mostly.
  static const bgRoot = Color(0xFFFFFFFF);
  static const bgApp = Color(0xFFF8F9FA);
  static const bgCard = Color(0xFFFFFFFF);
  static const bgStroke = Color(0xFFE5E7EB);
  static const textStrong = Color(0xFF111827);
  static const textBody = Color(0xFF374151);
  static const textSubtle = Color(0xFF6B7280);
  static const brandPrimary = Color(0xFF22C55E);
  static const brandPrimaryHover = Color(0xFF16A34A);
  static const accentGold = Color(0xFFEAB308);
  static const danger = Color(0xFFDC2626);
  static const warn = Color(0xFFF59E0B);
  static const info = Color(0xFF3B82F6);
}

// 2026 개편: Soft Wellness 라이트 톤으로 값 교체 (멤버명 유지)
class AppColors {
  static const bgRoot = WellnessColors.bgRoot;
  static const bgApp = WellnessColors.bgRoot;
  static const bgCard = WellnessColors.bgCard;
  static const bgStroke = WellnessColors.border;
  static const textStrong = WellnessColors.textPrimary;
  static const textBody = WellnessColors.textSecondary;
  static const textSubtle = WellnessColors.textTertiary;
  static const textWeak = WellnessColors.textTertiary;
  static const brandPrimary = WellnessColors.primary;
  static const brandPrimaryHover = WellnessColors.primaryDark;
  static const accentGold = Color(0xFFEBA53E); // 라이트에 맞춘 앰버
  static const danger = WellnessColors.danger;
  static const warn = WellnessColors.warning;
  static const info = WellnessColors.info;
  static const success = WellnessColors.success;
}

// ============================================================================
// WELLNESS SCHEME - 단계적 다크모드 전환용 (context 기반 색 룩업)
// 화면을 이 스킴으로 옮기면 라이트/다크가 자동 전환됨.
// 아직 const WellnessColors를 직접 쓰는 화면은 라이트 고정으로 동작.
// ============================================================================

class WellnessScheme {
  final Color bgRoot;
  final Color bgCard;
  final Color bgSubtle;
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color primarySubtle;
  final Color onPrimary;
  final Color accent;
  final Color accentSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color border;
  final Color borderSubtle;
  final Color energy;

  const WellnessScheme({
    required this.bgRoot,
    required this.bgCard,
    required this.bgSubtle,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.primarySubtle,
    required this.onPrimary,
    required this.accent,
    required this.accentSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.border,
    required this.borderSubtle,
    required this.energy,
  });

  static const light = WellnessScheme(
    bgRoot: WellnessColors.bgRoot,
    bgCard: WellnessColors.bgCard,
    bgSubtle: WellnessColors.bgSubtle,
    primary: WellnessColors.primary,
    primaryDark: WellnessColors.primaryDark,
    primaryLight: WellnessColors.primaryLight,
    primarySubtle: WellnessColors.primarySubtle,
    onPrimary: WellnessColors.onPrimary,
    accent: WellnessColors.accent,
    accentSubtle: WellnessColors.accentSubtle,
    textPrimary: WellnessColors.textPrimary,
    textSecondary: WellnessColors.textSecondary,
    textTertiary: WellnessColors.textTertiary,
    success: WellnessColors.success,
    warning: WellnessColors.warning,
    danger: WellnessColors.danger,
    info: WellnessColors.info,
    border: WellnessColors.border,
    borderSubtle: WellnessColors.borderSubtle,
    energy: WellnessColors.energy,
  );

  static const dark = WellnessScheme(
    bgRoot: WellnessColorsDark.bgRoot,
    bgCard: WellnessColorsDark.bgCard,
    bgSubtle: WellnessColorsDark.bgSubtle,
    primary: WellnessColorsDark.primary,
    primaryDark: WellnessColorsDark.primaryDark,
    primaryLight: WellnessColorsDark.primaryLight,
    primarySubtle: WellnessColorsDark.primarySubtle,
    onPrimary: WellnessColorsDark.onPrimary,
    accent: WellnessColorsDark.accent,
    accentSubtle: WellnessColorsDark.accentSubtle,
    textPrimary: WellnessColorsDark.textPrimary,
    textSecondary: WellnessColorsDark.textSecondary,
    textTertiary: WellnessColorsDark.textTertiary,
    success: WellnessColorsDark.success,
    warning: WellnessColorsDark.warning,
    danger: WellnessColorsDark.danger,
    info: WellnessColorsDark.info,
    border: WellnessColorsDark.border,
    borderSubtle: WellnessColorsDark.borderSubtle,
    energy: WellnessColorsDark.energy,
  );
}

extension WellnessContext on BuildContext {
  /// 현재 밝기에 맞는 Soft Wellness 색 스킴.
  WellnessScheme get wellness => Theme.of(this).brightness == Brightness.dark
      ? WellnessScheme.dark
      : WellnessScheme.light;
}
