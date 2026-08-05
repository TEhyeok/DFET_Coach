import 'package:dfet_coach/demo/design_lab_atoms_screen.dart';
import 'package:dfet_coach/design_system/d_fet_axis_glyph.dart';
import 'package:dfet_coach/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> pumpDesignLab(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScaleFactor = 1,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    MaterialApp(
      theme: appThemeLight(),
      darkTheme: appThemeDark(),
      themeMode: themeMode,
      home: const DesignLabAtomsScreen(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('기본 아이콘 없이 D-FET 4축 벡터 심볼을 렌더한다', (tester) async {
    await pumpDesignLab(tester);
    final semantics = tester.ensureSemantics();

    expect(find.text('4-AXIS\nSIGNAL GLYPHS'), findsOneWidget);
    expect(find.byType(DfetAxisGlyph), findsNWidgets(11));
    expect(find.byType(Icon), findsNothing);
    expect(
      find.bySemanticsLabel('운동 축 측정 중 신호'),
      findsAtLeastNWidgets(1),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('축을 선택하면 상태·크기 표본이 같은 신호로 전환된다', (tester) async {
    await pumpDesignLab(tester);
    final semantics = tester.ensureSemantics();

    await tester.tap(find.bySemanticsLabel('장 축 신호 선택'));
    await tester.pump();

    expect(find.text('SELECTED / DIVERSITY LOOP'), findsOneWidget);
    expect(find.bySemanticsLabel('장 축 측정 중 신호'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('320px·글자 1.3과 다크 모드에서 레이아웃이 유지된다', (tester) async {
    await pumpDesignLab(
      tester,
      size: const Size(320, 780),
      textScaleFactor: 1.3,
      themeMode: ThemeMode.dark,
    );

    await tester.scrollUntilVisible(
      find.text('CONSTRUCTION RULE'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('CONSTRUCTION RULE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
