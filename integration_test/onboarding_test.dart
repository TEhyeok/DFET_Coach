import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dfet_coach/screens/onboarding_screen.dart';
import 'package:dfet_coach/state/app_state.dart';
import 'package:dfet_coach/models/user_profile.dart';

/// 온보딩 흐름 E2E 통합 테스트 (실제 디바이스/시뮬레이터에서 실행).
///
/// 좌표가 아닌 위젯 텍스트로 탭하므로 안정적이다.
/// Firebase 부팅(main())은 테스트 환경에서 초기화 실패하므로, OnboardingScreen
/// 위젯을 직접 ProviderScope + MaterialApp 으로 감싸고 SharedPreferences mock 을
/// 주입한다.
///
/// 실행:
///   flutter test integration_test/onboarding_test.dart
///   flutter test integration_test/ -d `device-id`   // 실제 디바이스
///
/// 참고: 헤드리스 `flutter test` 로 돌릴 때 google_fonts 가 번들되지 않은 Outfit
/// 폰트를 로드하려다 비동기 예외를 던질 수 있다(allowRuntimeFetching=false).
/// 이는 라이브 통합 바인딩에서만 표면화되는 환경 잡음이며, 실제 디바이스에서는
/// 폰트가 정상 로드되어 발생하지 않는다. test/onboarding_flow_test.dart 의 동일
/// 흐름이 기본 위젯 테스트 바인딩에서 통과함으로 흐름 자체의 정합성은 검증된다.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // 실기기/시뮬레이터에서는 폰트 런타임 페칭이 가능하므로 기본값(true) 유지.
  // (헤드리스 widget test와 달리 integration_test는 네트워크/디바이스 폰트 사용 가능)

  Future<ProviderContainer> pumpOnboarding(WidgetTester tester) async {
    // 폰 크기로 설정 (기본 800x600은 온보딩 내용이 넘쳐 오버플로우)
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('E2E: 온보딩 전체 흐름 완주 → guestCareType 저장 + 온보딩 완료',
      (tester) async {
    final container = await pumpOnboarding(tester);

    // 0: Welcome — "시작하기"
    expect(find.text('시작하기'), findsOneWidget);
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    // 1: 케어유형 → 장내미생물 케어 선택 후 "다음"
    await tester.tap(find.text('장내미생물 케어'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    // 2~7: 목표/성별/나이/키/몸무게/활동량 — 모두 선택 없이 "다음"으로 통과 가능
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
    }

    // 8: 권한 페이지 — "완료" 버튼 존재
    expect(find.text('완료'), findsOneWidget);
    await tester.tap(find.text('완료'));
    // _completeOnboarding: 3초 AI 분석 시뮬레이션 후 저장.
    // 완료 후 로딩 스피너가 계속 돌아 pumpAndSettle은 timeout 되므로 고정 pump 사용.
    await tester.pump(); // setState(_isAnalyzing=true)
    await tester.pump(const Duration(seconds: 4)); // 3초 지연 경과
    await tester.pump(); // 저장 후 상태 반영

    // 게스트 케어유형이 microbiome으로 저장되었는지
    expect(
      container.read(guestCareTypeProvider),
      UserCareType.microbiome,
    );
    // 온보딩 완료 플래그
    expect(container.read(hasSeenOnboardingProvider), true);
  });
}
