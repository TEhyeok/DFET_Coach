import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dfet_coach/screens/login_screen.dart';
import 'package:dfet_coach/screens/record_hub_screen.dart';
import 'package:dfet_coach/state/app_state.dart';
import 'package:dfet_coach/services/firestore_service.dart';
import 'package:dfet_coach/models/meal.dart';
import 'package:dfet_coach/models/workout.dart';

/// 로그인/기록 흐름 자동 검증 (위젯 테스트 — 시뮬레이터 불필요).
///
/// onboarding_flow_test.dart 의 검증된 패턴을 그대로 따른다:
/// - ProviderContainer + UncontrolledProviderScope + MaterialApp
/// - SharedPreferences.setMockInitialValues
/// - GoogleFonts.config.allowRuntimeFetching = false
/// - tester.view.physicalSize = Size(1179, 2556), dpr 3.0
/// - 좌표가 아닌 위젯 텍스트/타입으로만 탭 → 안정적
///
/// 참고: LoginScreen / RecordHubScreen 은 실제 앱에서 Firebase(authState,
/// firestore)에 의존한다. 위젯 테스트에는 Firebase 가 초기화되어 있지 않으므로
/// 아래 두 가지를 오버라이드해 Firebase 접근을 차단한다.
/// - authStateProvider → null 스트림 (AuthService/FirebaseAuth 미사용)
/// - firestoreServiceProvider → _FakeFirestoreService (FirebaseFirestore 미생성)
/// 두 오버라이드 모두 "추가" 로직에는 관여하지 않는다(게스트/비로그인 경로에서는
/// MealsNotifier/WorkoutsNotifier 가 Firestore 를 호출하지 않음). 따라서 식단/운동
/// 추가 로직 자체는 실제 코드(addMeal/addWorkout)가 그대로 실행되어 검증된다.

/// FirebaseFirestore.instance 를 건드리지 않기 위해 extends 가 아닌 implements 사용.
/// 비로그인(uid == null) 경로에서는 어떤 메서드도 호출되지 않으므로 noSuchMethod 로 충분.
class _FakeFirestoreService implements FirestoreService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUpAll(() {
    // 테스트 환경에서 폰트 네트워크 페칭 비활성화
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// 뷰포트/바인딩 의존 없이 Firebase 차단 오버라이드만 적용한 컨테이너 생성.
  /// (위젯을 펌프하지 않는 순수 상태-레벨 테스트에서 사용)
  Future<ProviderContainer> _buildContainer() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Firebase 미초기화 환경 → 인증 스트림은 항상 비로그인(null)
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        // FirebaseFirestore.instance 접근 방지용 페이크
        firestoreServiceProvider.overrideWithValue(_FakeFirestoreService()),
      ],
    );
  }

  /// 공통 setup 헬퍼 — onboarding_flow_test.dart 와 동일한 뷰/폰트/프리퍼런스 설정.
  /// Firebase 의존 provider 는 오버라이드로 차단한다.
  ///
  /// [widePhysicalWidth] 가 true 면 가로폭을 넓혀 다이얼로그 내부 FilterChip Row 가
  /// 오버플로우하지 않도록 한다(lib 코드는 수정 불가하므로 뷰포트로 회피).
  Future<ProviderContainer> _makeContainer(
    WidgetTester tester, {
    bool widePhysicalWidth = false,
  }) async {
    // 폰 크기로 설정 (기본 800x600 은 컨텐츠가 넘쳐 오버플로우)
    // 다이얼로그 테스트는 더 넓은 폭이 필요(태블릿 분기 920 logical 미만 유지).
    tester.view.physicalSize =
        widePhysicalWidth ? const Size(2400, 2600) : const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    return _buildContainer();
  }

  // ---------------------------------------------------------------------------
  // TEST 1 — 게스트 로그인 진입
  // ---------------------------------------------------------------------------
  group('게스트 로그인 진입', () {
    testWidgets('"게스트로 계속하기" 탭 시 isGuestModeProvider 가 true 가 된다',
        (tester) async {
      // LoginScreen 은 플랫폼별 레이아웃 분기. iOS(Cupertino) 경로를 테스트한다.
      // (foundation 변수는 테스트 본문 종료 전에 반드시 원복해야 invariant 통과)
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final container = await _makeContainer(tester);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const CupertinoApp(home: LoginScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // 진입 전: 게스트 모드 false
        expect(container.read(isGuestModeProvider), false);

        // 게스트 버튼 존재 확인 후 탭 (네트워크/Firebase 미접근, provider 만 변경)
        expect(find.text('게스트로 계속하기'), findsOneWidget);
        await tester.tap(find.text('게스트로 계속하기'));
        await tester.pump();

        // 게스트 모드 true, 트레이너 게스트는 false, 로그인 상태 true
        expect(container.read(isGuestModeProvider), true);
        expect(container.read(isTrainerGuestModeProvider), false);
        expect(container.read(isLoggedInProvider), true);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  // ---------------------------------------------------------------------------
  // TEST 2 — 식단 직접 입력으로 식단 추가
  // ---------------------------------------------------------------------------
  group('식단 직접 입력으로 식단 추가', () {
    // RecordHubScreen 의 "식단 직접 입력" 은 Android(Material) 경로에서
    // showDialog 로 MealDialog 를 띄운다(TextFormField 기반). iOS 경로는
    // showCupertinoModalPopup(showAdaptiveEntrySheet) 를 쓰는데, 위젯 테스트의
    // 모달 라우트/애니메이션과 SafeArea 처리가 더 단순한 Material 경로로 구동한다.
    testWidgets('"식단 직접 입력" → 다이얼로그에서 음식명/칼로리 입력 후 저장 시 mealsProvider 에 추가',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final container = await _makeContainer(tester, widePhysicalWidth: true);

        // 비로그인(uid == null) → mock 데이터 없이 빈 상태로 시작
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: RecordHubScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // mealsProvider 가 구독되도록 listen (autoDispose 유지)
        final sub = container.listen(mealsProvider, (_, __) {});
        addTearDown(sub.close);
        final initialCount = container.read(mealsProvider).length;

        // 액션 행 탭 → MealDialog(다이얼로그) 오픈
        expect(find.text('식단 직접 입력'), findsOneWidget);
        await tester.tap(find.text('식단 직접 입력'));
        await tester.pumpAndSettle();

        // 다이얼로그가 열렸는지 확인 ("식단 추가" 제목 + 음식명 라벨)
        expect(find.text('식단 추가'), findsOneWidget);
        expect(find.widgetWithText(TextFormField, '음식명'), findsOneWidget);

        // 필수 필드 입력: 음식명 + 칼로리
        await tester.enterText(
            find.widgetWithText(TextFormField, '음식명'), '테스트 닭가슴살');
        await tester.enterText(
            find.widgetWithText(TextFormField, '칼로리 (kcal)'), '420');

        // 저장 버튼 탭 (저장 시 300ms delay 후 onSave → addMeal → Navigator.pop)
        await tester.tap(find.widgetWithText(FilledButton, '저장'));
        await tester.pump(); // setState(_isLoading=true)
        await tester.pump(const Duration(milliseconds: 400)); // delay 경과
        await tester.pumpAndSettle(); // pop 애니메이션 정리

        // mealsProvider 에 추가되었는지 검증
        final meals = container.read(mealsProvider);
        expect(meals.length, initialCount + 1);
        expect(meals.any((m) => m.name == '테스트 닭가슴살'), true);
        expect(
          meals.firstWhere((m) => m.name == '테스트 닭가슴살').calories,
          420,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('상태 레벨 검증 — mealsProvider.addMeal 직접 호출 시 저장된다', () async {
      // 실제 다이얼로그 흐름과 별개로, 추가 로직 자체를 순수 상태 레벨에서 검증.
      final container = await _buildContainer();
      addTearDown(container.dispose);

      final sub = container.listen(mealsProvider, (_, __) {});
      addTearDown(sub.close);

      final before = container.read(mealsProvider).length;
      await container.read(mealsProvider.notifier).addMeal(
            Meal(
              id: 't-meal-1',
              time: '12:00',
              name: '상태검증 식단',
              calories: 333,
            ),
          );

      final meals = container.read(mealsProvider);
      expect(meals.length, before + 1);
      expect(meals.any((m) => m.name == '상태검증 식단'), true);
    });
  });

  // ---------------------------------------------------------------------------
  // TEST 3 — 운동 기록 추가
  // ---------------------------------------------------------------------------
  group('운동 기록 추가', () {
    testWidgets('"운동 기록 추가" → 다이얼로그에서 운동명/세트 입력 후 저장 시 workoutsProvider 에 추가',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final container = await _makeContainer(tester, widePhysicalWidth: true);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: RecordHubScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final sub = container.listen(workoutsProvider, (_, __) {});
        addTearDown(sub.close);
        final initialCount = container.read(workoutsProvider).length;

        // 액션 행 탭 → WorkoutDialog 오픈
        expect(find.text('운동 기록 추가'), findsOneWidget);
        await tester.tap(find.text('운동 기록 추가'));
        await tester.pumpAndSettle();

        // 다이얼로그 오픈 확인
        expect(find.text('운동 추가'), findsOneWidget);
        expect(find.widgetWithText(TextFormField, '운동명'), findsOneWidget);

        // 운동명 입력 (기본 카테고리: strength → 세트 1개 이상 필요)
        await tester.enterText(
            find.widgetWithText(TextFormField, '운동명'), '테스트 벤치프레스');
        await tester.pumpAndSettle();

        // 무게/횟수 입력 후 세트 추가 버튼(+) 탭
        await tester.enterText(
            find.widgetWithText(TextFormField, '무게(kg)'), '60');
        await tester.enterText(
            find.widgetWithText(TextFormField, '횟수'), '10');
        await tester.tap(find.byTooltip('세트 추가'));
        await tester.pumpAndSettle();

        // 세트가 추가되었는지 (칩 표시) 확인
        expect(find.textContaining('1세트'), findsOneWidget);

        // 저장
        await tester.tap(find.widgetWithText(FilledButton, '저장'));
        await tester.pump(); // _isLoading = true
        await tester.pump(const Duration(milliseconds: 400)); // delay 경과
        await tester.pumpAndSettle();

        // workoutsProvider 에 추가되었는지 검증
        final workouts = container.read(workoutsProvider);
        expect(workouts.length, initialCount + 1);
        final added = workouts.firstWhere((w) => w.name == '테스트 벤치프레스');
        expect(added.category, 'strength');
        expect(added.sets.length, 1);
        expect(added.sets.first.weight, 60);
        expect(added.sets.first.reps, 10);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('상태 레벨 검증 — workoutsProvider.addWorkout 직접 호출 시 저장된다', () async {
      final container = await _buildContainer();
      addTearDown(container.dispose);

      final sub = container.listen(workoutsProvider, (_, __) {});
      addTearDown(sub.close);

      final before = container.read(workoutsProvider).length;
      await container.read(workoutsProvider.notifier).addWorkout(
            Workout(
              id: 't-workout-1',
              name: '상태검증 운동',
              category: 'cardio',
              duration: 30,
              timestamp: DateTime(2026, 6, 18, 9, 0),
            ),
          );

      final workouts = container.read(workoutsProvider);
      expect(workouts.length, before + 1);
      expect(workouts.any((w) => w.name == '상태검증 운동'), true);
    });
  });
}
