import 'package:dfet_coach/theme/app_theme.dart';
import 'package:dfet_coach/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

double contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('라이트 모드 본문과 보조 글자는 모든 기본 배경에서 4.5:1 이상이다', () {
    const backgrounds = [
      WellnessColors.bgRoot,
      WellnessColors.bgCard,
      WellnessColors.bgSubtle,
    ];
    const textColors = [
      WellnessColors.textPrimary,
      WellnessColors.textSecondary,
      WellnessColors.textTertiary,
    ];

    for (final background in backgrounds) {
      for (final textColor in textColors) {
        expect(
          contrastRatio(textColor, background),
          greaterThanOrEqualTo(4.5),
          reason: '$textColor 글자가 $background 배경에서 흐립니다.',
        );
      }
    }
  });

  test('라이트 Material 색상도 Wellness 표면 글자색을 사용한다', () {
    final scheme = appThemeLight().colorScheme;

    expect(scheme.onSurface, WellnessColors.textPrimary);
    expect(scheme.onSurfaceVariant, WellnessColors.textSecondary);
  });
}
