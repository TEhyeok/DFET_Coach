import 'package:dfet_coach/design_system/d_fet_axis_glyph.dart';
import 'package:dfet_coach/design_system/d_fet_evidence.dart';
import 'package:dfet_coach/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Widget _testApp({required ThemeMode themeMode, double textScale = 1}) {
  return MaterialApp(
    theme: appThemeLight(),
    darkTheme: appThemeDark(),
    themeMode: themeMode,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: const Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DfetReportHeader(
              axis: DfetAxis.gut,
              eyebrow: 'MICROBIOME · 16S',
              title: '장 건강 리포트',
              subtitle: '2026.08.10 채취 · 16S rRNA V3-V4',
            ),
            SizedBox(height: 16),
            DfetMetricValue(
              value: '2.481',
              unit: 'Shannon',
              axis: DfetAxis.gut,
            ),
            SizedBox(height: 16),
            DfetMetricValue(),
            SizedBox(height: 16),
            DfetEvidenceRibbon(
              source: '검사기관 · 16S V3-V4',
              coverage: '알파 4/4 · Phylum 8종',
              policyVersion: null,
              tone: DfetEvidenceTone.pending,
              detail: '승인 정책 전에는 점수와 판정을 생성하지 않습니다.',
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('근거 원자가 ${themeMode.name} 모드에서 상태를 구분한다', (tester) async {
      await tester.pumpWidget(_testApp(themeMode: themeMode));
      await tester.pumpAndSettle();

      expect(find.textContaining('2.481'), findsOneWidget);
      expect(find.textContaining('Shannon'), findsOneWidget);
      expect(find.text('산정 준비 중'), findsOneWidget);
      expect(find.text('정책 미승인'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('근거 리본을 탭하면 비진단 처리 원칙을 펼친다', (tester) async {
    await tester.pumpWidget(_testApp(themeMode: ThemeMode.light));
    await tester.pumpAndSettle();

    expect(find.text('승인 정책 전에는 점수와 판정을 생성하지 않습니다.'), findsNothing);
    await tester.tap(find.byType(DfetEvidenceRibbon));
    await tester.pumpAndSettle();

    expect(find.text('승인 정책 전에는 점수와 판정을 생성하지 않습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320px·글자 2.0에서도 근거 원자가 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testApp(themeMode: ThemeMode.light, textScale: 2),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
