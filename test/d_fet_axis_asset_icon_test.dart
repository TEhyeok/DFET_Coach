import 'package:dfet_coach/design_system/d_fet_axis_glyph.dart';
import 'package:dfet_coach/design_system/d_fet_axis_icon.dart';
import 'package:dfet_coach/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('승인된 이미지 자산으로 네 가지 건강 축을 구분한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appThemeLight(),
        home: const Scaffold(
          body: Row(
            children: [
              DfetAxisAssetIcon(axis: DfetAxis.motion),
              DfetAxisAssetIcon(axis: DfetAxis.nutrition),
              DfetAxisAssetIcon(axis: DfetAxis.gut),
              DfetAxisAssetIcon(axis: DfetAxis.blood),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();

    expect(find.byType(Image), findsNWidgets(4));
    expect(find.bySemanticsLabel('운동 축 아이콘'), findsOneWidget);
    expect(find.bySemanticsLabel('식단 축 아이콘'), findsOneWidget);
    expect(find.bySemanticsLabel('장 축 아이콘'), findsOneWidget);
    expect(find.bySemanticsLabel('혈액 축 아이콘'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('다크 모드와 비활성 상태에서도 축 형태가 보존된다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appThemeLight(),
        darkTheme: appThemeDark(),
        themeMode: ThemeMode.dark,
        home: const Scaffold(
          body: Row(
            children: [
              DfetAxisAssetIcon(axis: DfetAxis.gut),
              DfetAxisAssetIcon(axis: DfetAxis.blood, active: false),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNWidgets(2));
    expect(find.byType(ColorFiltered), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
