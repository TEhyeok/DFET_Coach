import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dfet_coach/screens/record_hub_screen.dart';
import 'package:dfet_coach/screens/ios_profile_screen.dart';
import 'package:dfet_coach/screens/report_hub_screen.dart';
import 'package:dfet_coach/screens/reports.dart';
import 'package:dfet_coach/screens/microbiome/microbiome_screen.dart';
import 'package:dfet_coach/state/app_state.dart';
import 'package:dfet_coach/services/firestore_service.dart';

/// RENDER CHECK — 컴팩트 개편된 4개 화면이 iPhone 15 Pro 뷰포트에서
/// RenderFlex/unbounded/assertion 예외 없이 렌더되는지 검증한다.
/// 셸이 Scaffold를 제공하므로 각 화면을 Scaffold(body:) 로 감싼다.
class _FakeFirestoreService implements FirestoreService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<ProviderContainer> makeContainer() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        firestoreServiceProvider.overrideWithValue(_FakeFirestoreService()),
      ],
    );
  }

  Future<void> renderOk(
    WidgetTester tester,
    Widget screen, {
    Brightness brightness = Brightness.light,
  }) async {
    // iPhone 15 Pro
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = await makeContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(body: screen),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  }

  group('컴팩트 화면 렌더 검증 (라이트)', () {
    testWidgets('RecordHubScreen', (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await renderOk(t, const RecordHubScreen());
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('IOSProfileScreen', (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await renderOk(t, const IOSProfileScreen());
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('MicrobiomeScreen', (t) async {
      await renderOk(t, const MicrobiomeScreen());
    });

    testWidgets('ReportHubScreen', (t) async {
      await renderOk(t, const ReportHubScreen());
    });

    testWidgets('ReportsScreen', (t) async {
      await renderOk(t, const ReportsScreen());
    });
  });

  group('컴팩트 화면 렌더 검증 (다크)', () {
    testWidgets('MicrobiomeScreen dark', (t) async {
      await renderOk(t, const MicrobiomeScreen(),
          brightness: Brightness.dark);
    });

    testWidgets('ReportHubScreen dark', (t) async {
      await renderOk(t, const ReportHubScreen(), brightness: Brightness.dark);
    });
  });
}
