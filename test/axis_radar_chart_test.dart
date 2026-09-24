import 'package:dfet_coach/screens/insights/components/axis_radar_chart.dart';
import 'package:dfet_coach/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('누락 축을 0점으로 보간하지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appThemeLight(),
        home: const Scaffold(
          body: AxisRadarChart(
            axes: {
              'fitness': 82,
              'diet': 74,
              'gut': 86,
              'blood': null,
            },
          ),
        ),
      ),
    );

    expect(find.text('레이더 차트 산정 준비 중'), findsOneWidget);
    expect(find.textContaining('혈액은 0점으로 채우지 않습니다'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
