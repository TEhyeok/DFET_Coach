import 'package:flutter/cupertino.dart';
import 'd_fet_typography.dart';
import 'tokens.dart';

/// iOS Human Interface Guidelines 타이포그래피 스케일
/// SF Pro 스타일을 시스템 폰트로 구현
class IOSTextStyles {
  // Large Title (iOS 네비게이션 바 큰 제목)
  static const largeTitle = TextStyle(
    fontFamily: DfetTypography.uiFontFamily,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.37,
    height: 1.2,
    color: AppColors.textStrong,
  );

  // Title 1 (주요 제목)
  static const title1 = TextStyle(
    fontFamily: DfetTypography.uiFontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.36,
    height: 1.3,
    color: AppColors.textStrong,
  );

  // Title 2 (부제목)
  static const title2 = TextStyle(
    fontFamily: DfetTypography.uiFontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.35,
    height: 1.3,
    color: AppColors.textStrong,
  );

  // Title 3 (카드 제목)
  static const title3 = TextStyle(
    fontFamily: DfetTypography.uiFontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.38,
    height: 1.4,
    color: AppColors.textStrong,
  );

  // Headline (강조 텍스트)
  static const headline = TextStyle(
    fontFamily: DfetTypography.uiFontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.41,
    height: 1.4,
    color: AppColors.textStrong,
  );

  // Body (기본 본문)
  static const body = TextStyle(
    fontFamily: DfetTypography.uiFontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.41,
    height: 1.5,
    color: AppColors.textBody,
  );

  // Callout (리스트 아이템)
  static const callout = TextStyle(
    fontFamily: DfetTypography.uiFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.32,
    height: 1.4,
    color: AppColors.textBody,
  );

  // Subheadline (보조 텍스트)
  static const subheadline = TextStyle(
    fontFamily: DfetTypography.uiFontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.24,
    height: 1.4,
    color: AppColors.textSubtle,
  );

  // Footnote (작은 설명)
  static const footnote = TextStyle(
    fontFamily: DfetTypography.uiFontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.08,
    height: 1.4,
    color: AppColors.textSubtle,
  );

  // Caption 1 (매우 작은 텍스트)
  static const caption1 = TextStyle(
    fontFamily: DfetTypography.uiFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.3,
    color: AppColors.textSubtle,
  );

  // Caption 2 (가장 작은 텍스트)
  static const caption2 = TextStyle(
    fontFamily: DfetTypography.uiFontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.07,
    height: 1.3,
    color: AppColors.textSubtle,
  );

  // ===== 특수 용도 =====

  // 숫자 강조 (KPI 등)
  static const number = TextStyle(
    fontFamily: DfetTypography.dataFontFamily,
    fontFeatures: DfetTypography.tabularFigures,
    fontSize: 48,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.1,
    color: AppColors.textStrong,
  );

  // 탭 바 라벨
  static const tabLabel = TextStyle(
    fontFamily: DfetTypography.uiFontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.12,
    height: 1.2,
    color: AppColors.textSubtle,
  );

  // 버튼 텍스트
  static const button = TextStyle(
    fontFamily: DfetTypography.uiFontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.41,
    height: 1.2,
  );

  /// Dynamic Type 지원 헬퍼
  /// iOS 접근성 설정의 텍스트 크기를 반영
  static TextStyle scaledStyle(TextStyle style, BuildContext context) {
    final scaleFactor = MediaQuery.textScalerOf(context).scale(1);
    return style.copyWith(
      fontSize: (style.fontSize ?? 17) * scaleFactor.clamp(0.8, 1.5),
    );
  }
}
