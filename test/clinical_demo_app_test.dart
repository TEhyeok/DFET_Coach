import 'package:dfet_coach/demo/clinical_demo_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpClinicalDemo(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScaleFactor = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(
    tester.platformDispatcher.clearTextScaleFactorTestValue,
  );

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
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
  });

  testWidgets('통합 케어 데모에서 장·혈액·인사이트 화면을 전환한다', (tester) async {
    await pumpClinicalDemo(tester);

    expect(find.text('오늘의 신호'), findsOneWidget);
    expect(find.textContaining('좋아졌어요'), findsOneWidget);
    expect(find.text('+12'), findsOneWidget);

    await tester.tap(find.text('장 건강').last);
    await tester.pumpAndSettle();
    expect(find.text('장 건강 리포트'), findsOneWidget);
    expect(find.text('알파 다양성'), findsOneWidget);

    await tester.tap(find.text('혈액').last);
    await tester.pumpAndSettle();
    expect(find.text('혈액 생화학 리포트'), findsOneWidget);
    expect(find.textContaining('표준 코드와 단위'), findsOneWidget);

    await tester.tap(find.text('인사이트').last);
    await tester.pumpAndSettle();
    expect(find.text('나의 건강 변화'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('건강 타임라인'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('건강 타임라인'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('이전 대비 변화와 오늘 행동 완료 피드백을 제공한다', (tester) async {
    await pumpClinicalDemo(tester);

    expect(find.textContaining('좋아졌어요'), findsOneWidget);
    expect(find.text('+12'), findsOneWidget);
    expect(find.text('오늘의 한 가지'), findsOneWidget);

    final actionButton = find.text('완료 표시');
    await Scrollable.ensureVisible(
      tester.element(actionButton),
      alignment: 0.55,
    );
    await tester.pumpAndSettle();
    await tester.tap(actionButton);
    await tester.pumpAndSettle();

    expect(find.text('오늘의 한 걸음 완료'), findsOneWidget);
    expect(find.text('완료 취소'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await pumpClinicalDemo(tester);
    expect(find.text('오늘의 한 걸음 완료'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320px와 글자 배율 2.0에서도 Today Signal이 넘치지 않는다', (tester) async {
    await pumpClinicalDemo(
      tester,
      size: const Size(320, 780),
      textScaleFactor: 2,
    );

    expect(find.textContaining('좋아졌어요'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('완료 표시'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('완료 표시'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('장 16S 세부 지표와 전문가 리포트를 렌더한다', (tester) async {
    await pumpClinicalDemo(tester);

    await tester.tap(find.text('장 건강').last);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.text('알파 다양성 상세')),
      alignment: 0.45,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('알파 다양성 상세'));
    await tester.pumpAndSettle();
    expect(find.text('알파 다양성'), findsAtLeastNWidgets(1));
    expect(find.text('Shannon'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.text('전문가용 통합 상세')),
      alignment: 0.45,
    );
    await tester.pumpAndSettle();
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
    await tester.scrollUntilVisible(
      find.text('4축 통합 건강'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('4축 통합 건강'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('이전 스냅샷 대비'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('이전 스냅샷 대비'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('데이터에서 발견한 흐름'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('데이터에서 발견한 흐름'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
