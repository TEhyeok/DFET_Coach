import 'package:dfet_coach/models/clinical_reports.dart';
import 'package:dfet_coach/theme/app_theme.dart';
import 'package:dfet_coach/widgets/clinical/alpha_metric_grid.dart';
import 'package:dfet_coach/widgets/clinical/composition_bar.dart';
import 'package:dfet_coach/widgets/clinical/range_bar.dart';
import 'package:dfet_coach/widgets/clinical/score_gauge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const metrics = <String, MetricAssessment>{
  'shannon': MetricAssessment(value: 2.4, score: null, status: 'unscored', label: '산정 준비 중'),
  'simpson': MetricAssessment(value: 0.82, score: null, status: 'unscored', label: '산정 준비 중'),
  'chao1': MetricAssessment(value: 312, score: null, status: 'unscored', label: '산정 준비 중'),
  'observedOtus': MetricAssessment(value: 248, score: null, status: 'unscored', label: '산정 준비 중'),
};

Widget clinicalSummary(Brightness brightness, double textScale) {
  final theme = brightness == Brightness.light ? appThemeLight() : appThemeDark();
  return MaterialApp(
    theme: theme,
    darkTheme: appThemeDark(),
    themeMode: brightness == Brightness.light ? ThemeMode.light : ThemeMode.dark,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            Center(child: ScoreGauge(score: null)),
            SizedBox(height: 20),
            RangeBar(value: 24, lower: 10, upper: 40, unit: 'U/L'),
            SizedBox(height: 20),
            CompositionBar(items: [
              TaxonAbundance(name: 'Firmicutes', value: 55),
              TaxonAbundance(name: 'Bacteroidota', value: 40),
            ]),
            SizedBox(height: 20),
            AlphaMetricGrid(metrics: metrics),
          ],
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('임상 컴포넌트 ${width}px / text $scale overflow 없음', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(clinicalSummary(Brightness.light, scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('임상 요약 라이트 골든', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(clinicalSummary(Brightness.light, 1));
    await tester.pumpAndSettle();
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/clinical_summary_light.png'));
  });

  testWidgets('임상 요약 다크 골든', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(clinicalSummary(Brightness.dark, 1));
    await tester.pumpAndSettle();
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/clinical_summary_dark.png'));
  });
}
