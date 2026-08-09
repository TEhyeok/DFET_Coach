import 'package:dfet_coach/design_system/d_fet_axis_glyph.dart';
import 'package:dfet_coach/design_system/d_fet_axis_icon.dart';
import 'package:dfet_coach/design_system/d_fet_signal_rail.dart';
import 'package:dfet_coach/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _items = [
  DfetSignalItem(
    axis: DfetAxis.motion,
    label: '운동',
    value: '+9',
    semanticLabel: '운동 축, 9점 상승',
  ),
  DfetSignalItem(
    axis: DfetAxis.nutrition,
    label: '식단',
    value: '+6',
    semanticLabel: '식단 축, 6점 상승',
  ),
  DfetSignalItem(
    axis: DfetAxis.gut,
    label: '장',
    value: '+12',
    semanticLabel: '장 축, 12점 상승',
  ),
  DfetSignalItem(
    axis: DfetAxis.blood,
    label: '혈액',
    value: '확인 필요',
    active: false,
    semanticLabel: '혈액 축, 확인 필요',
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('네 축을 연결된 신호 노드와 의미 라벨로 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appThemeLight(),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(20),
            child: DfetSignalRail(items: _items),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();

    expect(find.byType(DfetAxisAssetIcon), findsNWidgets(4));
    expect(find.bySemanticsLabel('운동 축, 9점 상승'), findsOneWidget);
    expect(find.bySemanticsLabel('식단 축, 6점 상승'), findsOneWidget);
    expect(find.bySemanticsLabel('장 축, 12점 상승'), findsOneWidget);
    expect(find.bySemanticsLabel('혈액 축, 확인 필요'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('320px·글자 2.0·다크 모드에서 레이아웃이 유지된다', (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(
      tester.platformDispatcher.clearTextScaleFactorTestValue,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: appThemeLight(),
        darkTheme: appThemeDark(),
        themeMode: ThemeMode.dark,
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(20),
            child: DfetSignalRail(items: _items),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DfetAxisAssetIcon), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });
}
