import 'package:dfet_coach/demo/clinical_demo_data.dart';
import 'package:dfet_coach/screens/dashboard.dart';
import 'package:dfet_coach/state/clinical_state.dart';
import 'package:dfet_coach/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('운영 대시보드가 비교 가능한 스냅샷을 Today Signal로 표시한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          healthSnapshotsProvider.overrideWith(
            (ref) => Stream.value(clinicalDemoSnapshots),
          ),
        ],
        child: MaterialApp(
          theme: appThemeLight(),
          home: const Scaffold(body: DashboardScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('오늘의 신호'), findsOneWidget);
    expect(find.textContaining('4개가 좋아졌어요'), findsOneWidget);
    expect(find.text('+12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
