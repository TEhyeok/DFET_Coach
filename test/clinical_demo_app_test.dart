import 'package:dfet_coach/demo/clinical_demo_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpClinicalDemo(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: clinicalDemoOverrides,
      child: const ClinicalDemoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
  });

  testWidgets('통합 케어 데모에서 장·혈액·인사이트 화면을 전환한다', (tester) async {
    await pumpClinicalDemo(tester);

    expect(find.text('D-FET 통합 케어'), findsOneWidget);
    expect(find.text('통합 케어 회원'), findsOneWidget);
    expect(find.text('4축 통합 건강'), findsOneWidget);

    await tester.tap(find.text('장 건강').last);
    await tester.pumpAndSettle();
    expect(find.text('장 건강 리포트'), findsOneWidget);
    expect(find.text('알파 다양성'), findsOneWidget);

    await tester.tap(find.text('혈액').last);
    await tester.pumpAndSettle();
    expect(find.text('혈액 POCT'), findsOneWidget);
    expect(find.text('간·신장·대사·지질 13개 표준 항목'), findsOneWidget);

    await tester.tap(find.text('인사이트').last);
    await tester.pumpAndSettle();
    expect(find.text('통합 인사이트'), findsOneWidget);
    expect(find.text('건강 타임라인'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('장 16S 세부 지표와 전문가 리포트를 렌더한다', (tester) async {
    await pumpClinicalDemo(tester);

    await tester.tap(find.text('장 건강').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('알파 다양성 상세'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('알파 다양성 상세'));
    await tester.pumpAndSettle();
    expect(find.text('알파 다양성'), findsAtLeastNWidgets(1));
    expect(find.text('Shannon'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('전문가용 통합 상세'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('전문가용 통합 상세'));
    await tester.pumpAndSettle();
    expect(find.text('전문가 상세 분석'), findsOneWidget);
    expect(find.text('베타 다양성 (Bray-Curtis PCoA)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('혈액 13종 상세·추이와 4축 전후 비교를 렌더한다', (tester) async {
    await pumpClinicalDemo(tester);

    await tester.tap(find.text('혈액').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('혈액 생화학 요약'));
    await tester.pumpAndSettle();
    expect(find.text('혈액 검사 리포트'), findsAtLeastNWidgets(1));
    expect(find.text('ALT'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('인사이트').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('4축 통합 건강'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('이전 스냅샷 대비'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('이전 스냅샷 대비'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('축간 인사이트'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('축간 인사이트'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
