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

  testWidgets('라이트 Material 색상도 Wellness 표면 글자색을 사용한다', (tester) async {
    final theme = appThemeLight();
    await tester.pumpWidget(MaterialApp(theme: theme, home: const SizedBox()));
    final scheme = theme.colorScheme;

    expect(scheme.onSurface, WellnessColors.textPrimary);
    expect(scheme.onSurfaceVariant, WellnessColors.textSecondary);
  });

  test('다크 모드 본문과 보조 글자는 모든 기본 배경에서 4.5:1 이상이다', () {
    const backgrounds = [
      WellnessColorsDark.bgRoot,
      WellnessColorsDark.bgCard,
      WellnessColorsDark.bgSubtle,
    ];
    const textColors = [
      WellnessColorsDark.textPrimary,
      WellnessColorsDark.textSecondary,
      WellnessColorsDark.textTertiary,
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

  testWidgets('다크 Material 표면과 내비게이션도 다크 Wellness 색상을 사용한다', (tester) async {
    final theme = appThemeDark();
    await tester.pumpWidget(MaterialApp(theme: theme, home: const SizedBox()));
    final scheme = theme.colorScheme;

    expect(scheme.surface, WellnessColorsDark.bgCard);
    expect(scheme.onSurface, WellnessColorsDark.textPrimary);
    expect(scheme.onSurfaceVariant, WellnessColorsDark.textSecondary);
    expect(
      theme.navigationBarTheme.backgroundColor,
      WellnessColorsDark.bgCard,
    );
  });
}
