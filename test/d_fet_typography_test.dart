import 'package:dfet_coach/theme/app_theme.dart';
import 'package:dfet_coach/theme/d_fet_typography.dart';
import 'package:dfet_coach/theme/ios_text_styles.dart';
import 'package:dfet_coach/theme/ios_theme.dart';
import 'package:dfet_coach/widgets/clinical/score_gauge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('폰트 자산이 앱 번들에 포함된다', () async {
    final ui = await rootBundle.load('assets/fonts/IBMPlexSansKR-Regular.ttf');
    final display = await rootBundle.load('assets/fonts/GowunBatang-Bold.ttf');
    final data = await rootBundle.load('assets/fonts/IBMPlexMono-SemiBold.ttf');

    expect(ui.lengthInBytes, greaterThan(2000000));
    expect(display.lengthInBytes, greaterThan(7000000));
    expect(data.lengthInBytes, greaterThan(100000));
  });

  test('Material과 Cupertino 기본 한글 글꼴이 IBM Plex Sans KR로 통일된다', () {
    expect(
      appThemeLight().textTheme.bodyMedium?.fontFamily,
      DfetTypography.uiFontFamily,
    );
    expect(
      appThemeDark().textTheme.bodyMedium?.fontFamily,
      DfetTypography.uiFontFamily,
    );
    expect(
      iosThemeLight().textTheme.textStyle.fontFamily,
      DfetTypography.uiFontFamily,
    );
    expect(
      iosThemeDark().textTheme.textStyle.fontFamily,
      DfetTypography.uiFontFamily,
    );
    expect(
      IOSTextStyles.number.fontFamily,
      DfetTypography.dataFontFamily,
    );
    expect(
      DfetTypography.displayStyle(color: Colors.black, fontSize: 40).fontFamily,
      DfetTypography.displayFontFamily,
    );
  });

  testWidgets('점수는 IBM Plex Mono와 고정폭 숫자 기능을 사용한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appThemeLight(),
        home: const Scaffold(body: ScoreGauge(score: 86)),
      ),
    );

    final score = tester.widget<Text>(find.text('86'));
    expect(score.style?.fontFamily, DfetTypography.dataFontFamily);
    expect(
      score.style?.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
    expect(tester.takeException(), isNull);
  });
}
