import 'package:dfet_coach/demo/clinical_demo_data.dart';
import 'package:dfet_coach/screens/dashboard.dart';
import 'package:dfet_coach/services/clinical_repository.dart';
import 'package:dfet_coach/services/firestore_service.dart';
import 'package:dfet_coach/state/app_state.dart';
import 'package:dfet_coach/state/clinical_state.dart';
import 'package:dfet_coach/theme/app_theme.dart';
import 'package:dfet_coach/theme/d_fet_typography.dart';
import 'package:dfet_coach/widgets/clinical/gut_health_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeFirestoreService implements FirestoreService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

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
    final headline = tester.widget<Text>(find.textContaining('4개가 좋아졌어요'));
    expect(headline.style?.fontFamily, DfetTypography.displayFontFamily);

    await tester.tap(find.text('운동'));
    await tester.pumpAndSettle();
    expect(find.text('운동 축은 이전 기록보다 9점 좋아졌어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('스냅샷이 부족한 홈은 공통 장 건강 요약 컴포넌트를 사용한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          firestoreServiceProvider.overrideWithValue(_FakeFirestoreService()),
          healthSnapshotsProvider.overrideWith((ref) => Stream.value(const [])),
          gutReportsProvider.overrideWith(
            (ref) => Stream.value(clinicalDemoGutReports),
          ),
          featureFlagsProvider.overrideWith(
            (ref) => Stream.value(const AppFeatureFlags.enabled()),
          ),
          userProfileProvider.overrideWith((ref) async => clinicalDemoProfile),
        ],
        child: MaterialApp(
          theme: appThemeLight(),
          home: const Scaffold(body: DashboardScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GutHealthSummaryCard), findsOneWidget);
    expect(find.text('오늘의 장 건강'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
