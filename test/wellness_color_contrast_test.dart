import 'package:dfet_coach/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrastRatio(Color foreground, Color background) {
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
  const minimumBodyTextContrast = 4.5;

  test('라이트 모드 텍스트 토큰이 모든 기본 배경에서 4.5:1 이상이다', () {
    const foregrounds = [
      WellnessColors.textPrimary,
      WellnessColors.textSecondary,
      WellnessColors.textTertiary,
    ];
    const backgrounds = [
      WellnessColors.bgRoot,
      WellnessColors.bgCard,
      WellnessColors.bgSubtle,
    ];

    for (final foreground in foregrounds) {
      for (final background in backgrounds) {
        expect(
          _contrastRatio(foreground, background),
          greaterThanOrEqualTo(minimumBodyTextContrast),
        );
      }
    }
  });

  test('다크 모드 텍스트 토큰이 모든 기본 배경에서 4.5:1 이상이다', () {
    const foregrounds = [
      WellnessColorsDark.textPrimary,
      WellnessColorsDark.textSecondary,
      WellnessColorsDark.textTertiary,
    ];
    const backgrounds = [
      WellnessColorsDark.bgRoot,
      WellnessColorsDark.bgCard,
      WellnessColorsDark.bgSubtle,
    ];

    for (final foreground in foregrounds) {
      for (final background in backgrounds) {
        expect(
          _contrastRatio(foreground, background),
          greaterThanOrEqualTo(minimumBodyTextContrast),
        );
      }
    }
  });
}
