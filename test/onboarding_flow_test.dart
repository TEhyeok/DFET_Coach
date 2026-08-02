import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dfet_coach/screens/onboarding_screen.dart';
import 'package:dfet_coach/state/onboarding_state.dart';
import 'package:dfet_coach/state/app_state.dart';
import 'package:dfet_coach/models/user_profile.dart';

/// 온보딩 흐름 자동 검증 (위젯 테스트 — 시뮬레이터 불필요).
/// 좌표가 아닌 위젯 텍스트로 탭하므로 안정적.
void main() {
  setUpAll(() {
    // 테스트 환경에서 Outfit 폰트 네트워크 페칭 비활성화
    GoogleFonts.config.allowRuntimeFetching = false;
  });

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

  testWidgets('Welcome → 케어유형 페이지로 진입한다', (tester) async {
    await pumpOnboarding(tester);

    // Welcome 페이지에 "시작하기" 버튼이 있다
    expect(find.text('시작하기'), findsOneWidget);

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    // 케어유형 선택 페이지 진입 확인
    expect(find.text('운동 · 신체조성'), findsOneWidget);
    expect(find.text('장내미생물 케어'), findsOneWidget);
    expect(find.text('통합 케어'), findsOneWidget);
  });

  testWidgets('케어유형 미선택 시 "다음" 비활성, 선택 후 활성', (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    // 케어유형 페이지: "다음" 버튼은 있지만 미선택이라 비활성(onPressed == null)
    final nextBtn = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('다음'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(nextBtn.onPressed, isNull, reason: '미선택 시 다음 비활성이어야 함');

    // 장내미생물 케어 선택
    await tester.tap(find.text('장내미생물 케어'));
    await tester.pumpAndSettle();

    final nextBtn2 = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('다음'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(nextBtn2.onPressed, isNotNull, reason: '선택 후 다음 활성이어야 함');
  });

  testWidgets('전체 흐름 완주 → guestCareType 저장 + 온보딩 완료', (tester) async {
    final container = await pumpOnboarding(tester);

    // 0: Welcome
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    // 1: 케어유형 → 장내미생물 선택
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
