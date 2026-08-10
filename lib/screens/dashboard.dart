import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../state/app_state.dart';
import '../state/clinical_state.dart';
import '../models/user_profile.dart';
import '../design_system/d_fet_axis_glyph.dart';
import '../design_system/d_fet_axis_icon.dart';
import '../widgets/app_card.dart';
import '../widgets/activity_rings.dart';
import '../theme/tokens.dart';
import '../theme/text_styles.dart';
import '../services/smart_coach_service.dart';
import '../services/clinical_repository.dart';
import '../models/smart_recommendation.dart';
import '../widgets/protein_foods_dialog.dart';
import '../widgets/nutrition_tips_dialog.dart';
import '../widgets/hydration_dialog.dart';
import '../widgets/breakfast_menu_dialog.dart';
import '../widgets/clinical/gut_health_summary_card.dart';
import '../core/utils/app_logger.dart';
import '../services/coaching_correlation_service.dart';
import '../state/workout_metadata_state.dart';
import '../utils/responsive_layout.dart';
import 'dashboard/today_signal_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Future<void> _refresh() async {
    // 햅틱 피드백
    HapticFeedback.lightImpact();
    // 데이터 새로고침 시뮬레이션
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshotsState = ref.watch(healthSnapshotsProvider);
    if (snapshotsState.isLoading) {
      return ColoredBox(
        color: Theme.of(context).brightness == Brightness.dark
            ? context.wellness.bgRoot
            : const Color(0xFFFBF8F1),
        child: Center(
          child: CupertinoActivityIndicator(
            color: context.wellness.textPrimary,
          ),
        ),
      );
    }

    final snapshots = snapshotsState.valueOrNull;
    if (snapshots != null &&
        snapshots.length > 1 &&
        snapshots.first.insights.isNotEmpty) {
      final latest = snapshots.first;
      return TodaySignalScreen(
        current: latest,
        previous: snapshots[1],
        insight: latest.insights.first,
        onOpenInsight: () => context.push('/insights/${latest.snapshotId}'),
        onProfileTap: () => context.go('/home/myPage'),
      );
    }

    final score = ref.watch(wellnessScoreProvider);
    final totalCalories = ref.watch(totalCaloriesProvider);
    final totalProtein = ref.watch(totalProteinProvider);
    final totalWorkoutTime = ref.watch(totalWorkoutTimeProvider);
    final meals = ref.watch(mealsProvider);
    final isToday = ref.watch(isSelectedDateTodayProvider);

    // 케어 유형 (장 건강 카드 노출 여부)
    final careType = _resolveCareType();
    final featureFlags = ref.watch(featureFlagsProvider).valueOrNull ??
        const AppFeatureFlags.disabled();
    final showGutHealth = featureFlags.gut &&
        (careType == UserCareType.microbiome || careType == UserCareType.both);

    // 할 일 계산
    final todos =
        _calculateTodos(totalCalories, totalProtein, totalWorkoutTime);

    // 진행률 계산
    final calorieProgress = (totalCalories / 2000).clamp(0.0, 1.0);
    final exerciseProgress = (totalWorkoutTime / 60).clamp(0.0, 1.0);
    final wellnessProgress = (score / 100).clamp(0.0, 1.0);

    // 평균 점수 계산 (0-100)
    final averageScore =
        ((calorieProgress + exerciseProgress + wellnessProgress) / 3 * 100)
            .toInt();

    // iOS 스타일 체크
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = ResponsiveLayout.isTablet(context);
        final useTwoColumns = isTablet && constraints.maxWidth >= 920;

        // 가용 높이 기반 카드 높이 (장 건강 카드 자리 확보 위해 컴팩트하게).
        final screenHeight = MediaQuery.of(context).size.height;
        final safeAreaPadding = MediaQuery.of(context).padding;
        final chromeHeight = isTablet ? 96 : 140;
        final gutReserve = showGutHealth ? 92.0 : 0.0; // 장 건강 카드 + 간격
        final availableHeight = screenHeight -
            safeAreaPadding.top -
            safeAreaPadding.bottom -
            chromeHeight -
            gutReserve;
        final heroCardHeight =
            (availableHeight * 0.46).clamp(260.0, 460.0).ceilToDouble();
        final kpiHeight =
            (availableHeight * 0.18).clamp(110.0, 150.0).ceilToDouble();
        final feedbackHeight =
            (availableHeight * 0.30).clamp(180.0, 320.0).ceilToDouble();

        final heroCard = SizedBox(
          height: heroCardHeight,
          child: _buildHeroCard(
            context,
            averageScore,
            calorieProgress,
            exerciseProgress,
            wellnessProgress,
            totalCalories,
            totalWorkoutTime,
            isToday,
          ),
        );
        final kpiRow = SizedBox(
          height: kpiHeight,
          child: _buildKpiRow(
              context, totalCalories, totalWorkoutTime, todos, kpiHeight),
        );
        final feedbackCard = SizedBox(
          height: feedbackHeight,
          child: _buildSmartFeedback(
            totalProtein,
            totalCalories,
            totalWorkoutTime,
            meals.length,
            score,
          ),
        );

        if (useTwoColumns) {
          return SingleChildScrollView(
            child: ResponsiveConstrainedBox(
              child: Padding(
                padding: ResponsiveLayout.pagePadding(context),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          if (showGutHealth) ...[
                            _buildGutHealthCard(context),
                            const SizedBox(height: 16),
                          ],
                          SizedBox(height: 480, child: heroCard),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          SizedBox(height: 140, child: kpiRow),
                          const SizedBox(height: 16),
                          SizedBox(height: 300, child: feedbackCard),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // 폰: 컴팩트 카드 + CustomScrollView(안전망). 일반 기기에선 한 화면에 모두 표시.
        return CustomScrollView(
          slivers: [
            if (isIOS) CupertinoSliverRefreshControl(onRefresh: _refresh),
            SliverToBoxAdapter(
              child: ResponsiveConstrainedBox(
                child: Padding(
                  padding: ResponsiveLayout.pagePadding(context),
                  child: Column(
                    children: [
                      if (showGutHealth) ...[
                        _buildGutHealthCard(context),
                        const SizedBox(height: 10),
                      ],
                      heroCard,
                      const SizedBox(height: 10),
                      kpiRow,
                      const SizedBox(height: 10),
                      feedbackCard,
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        );
      },
    );
  }

  /// 현재 사용자(로그인/게스트)의 케어 유형
  CareType _resolveCareType() {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    if (profile != null) return profile.careType;
    return ref.watch(guestCareTypeProvider);
  }

  /// 홈 상단 '오늘의 장 건강' 요약 카드 (탭 시 상세로 이동)
  Widget _buildGutHealthCard(BuildContext context) {
    // 최신 장 건강 리포트. 실제 검사 데이터가 없으면 null → '리포트 없음' 빈 상태 노출.
    final report = ref.watch(latestGutReportProvider);

    void openDetail() {
      context.push('/home/gut');
    }

    if (report.isLoading) {
      return AppCard(
        padding: const EdgeInsets.all(18),
        child: const SizedBox(
          height: 60,
          child: Center(child: CupertinoActivityIndicator()),
        ),
      );
    }

    return GutHealthSummaryCard(
      report: report.valueOrNull,
      onTap: openDetail,
    );
  }

  Widget _buildKpiRow(BuildContext context, int totalCalories,
      int totalWorkoutTime, int todos, double height) {
    // height는 무시 — 외부 Expanded/SizedBox가 높이를 제어한다.
    return SizedBox.expand(
      child: Row(
        children: [
          Expanded(
            child: _buildKpiCard(
              icon: Icons.local_fire_department,
              label: '칼로리',
              value: totalCalories,
              goal: 2000,
              unit: 'kcal',
              color: AppColors.accentGold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildKpiCard(
              icon: Icons.fitness_center,
              label: '운동',
              value: totalWorkoutTime,
              goal: 60,
              unit: '분',
              color: const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildKpiCard(
              icon: Icons.assignment,
              label: '할 일',
              value: todos,
              goal: 0,
              unit: '개',
              color: context.wellness.textTertiary,
              inverse: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    int score,
    double calorieProgress,
    double exerciseProgress,
    double wellnessProgress,
    int totalCalories,
    int totalWorkoutTime,
    bool isToday,
  ) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = '좋은 아침이에요';
    } else if (hour < 18) {
      greeting = '좋은 오후예요';
    } else {
      greeting = '편안한 저녁이에요';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.xxl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: context.wellness.bgCard,
            borderRadius: BorderRadius.circular(Radii.xxl),
            border: Border.all(
              color: context.wellness.borderSubtle,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                greeting,
                style: AppTextStyles.h3
                    .copyWith(color: context.wellness.textPrimary),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ActivityRings(
                  nutritionProgress: calorieProgress,
                  exerciseProgress: exerciseProgress,
                  wellnessProgress: wellnessProgress,
                  wellnessScore: score,
                ),
              ),
              const SizedBox(height: 8),
              _buildQuickSummary(totalCalories, totalWorkoutTime, isToday),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickSummary(int calories, int workoutTime, bool isToday) {
    final overallProgress = ((calories / 2000) + (workoutTime / 60)) / 2;

    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: overallProgress),
          duration: const Duration(milliseconds: 1500),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: context.wellness.bgSubtle,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      value > 0.85
                          ? context.wellness.energy
                          : context.wellness.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${isToday ? '오늘' : '선택 날짜'} 목표 ${(value * 100).toInt()}% 달성!',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.wellness.textSecondary,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required IconData icon,
    required String label,
    required int value,
    required int goal,
    required String unit,
    required Color color,
    bool inverse = false,
  }) {
    final progress = goal > 0
        ? (value / goal).clamp(0.0, 1.0)
        : (inverse ? (value == 0 ? 1.0 : 0.0) : 1.0);

    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return AppCard(
          padding: const EdgeInsets.all(12),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: 8),
                Text(
                  '$animatedValue',
                  style: AppTextStyles.kpi.copyWith(fontSize: 20, color: color),
                ),
                Text(
                  unit,
                  style: AppTextStyles.caption
                      .copyWith(color: context.wellness.textTertiary),
                ),
                const SizedBox(height: 4),
                if (goal > 0) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width:
                          60, // Give it a fixed width inside FittedBox to ensure it renders correctly
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: context.wellness.bgSubtle,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '/$goal',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      color: context.wellness.textTertiary,
                    ),
                  ),
                ] else
                  Text(
                    label,
                    style: AppTextStyles.caption
                        .copyWith(color: context.wellness.textTertiary),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSmartFeedback(
    int protein,
    int calories,
    int workoutTime,
    int mealsCount,
    int wellnessScore,
  ) {
    // 오늘의 운동 메타데이터 가져오기
    final workoutMetadataList = ref.watch(todayWorkoutMetadataProvider);

    // 운동 기록이 있으면 영양 처방 생성
    NutritionPrescription? nutritionPrescription;
    if (workoutMetadataList.isNotEmpty) {
      nutritionPrescription = CoachingCorrelationService.generateNutritionPlan(
        workoutLogs: workoutMetadataList,
        currentNutrition: DailyNutrition(
          carbs: (calories * 0.5 / 4).round(), // 추정 탄수화물
          protein: protein,
          fat: (calories * 0.3 / 9).round(), // 추정 지방
          calories: calories,
        ),
      );
    }

    // 스마트 코치 서비스에서 추천 가져오기
    final recommendation = SmartCoachService.getRecommendation(
      protein: protein,
      calories: calories,
      workoutTime: workoutTime,
      mealsCount: mealsCount,
      wellnessScore: wellnessScore,
    );

    // 영양 처방이 있고 기본 타입이 아니면 처방 메시지 우선 표시
    final displayMessage = (nutritionPrescription != null &&
            nutritionPrescription.type != PrescriptionType.standard)
        ? nutritionPrescription.message
        : recommendation.message;

    final displayTitle = (nutritionPrescription != null &&
            nutritionPrescription.type != PrescriptionType.standard)
        ? '운동-영양 맞춤 코칭'
        : recommendation.title;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 헤더: 아이콘 + 타이틀 + 우선순위 배지
          Row(
            children: [
              DfetAxisAssetIcon(
                axis: _recommendationAxis(recommendation.category),
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      style: AppTextStyles.h3
                          .copyWith(color: context.wellness.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            recommendation.priorityColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getPriorityLabel(recommendation.priority),
                        style: AppTextStyles.caption.copyWith(
                          color: recommendation.priorityColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 진행률 바 (있는 경우)
          if (recommendation.progressValue != null &&
              recommendation.progressGoal != null) ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (recommendation.progressValue! /
                              recommendation.progressGoal!)
                          .clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: context.wellness.bgSubtle,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          recommendation.priorityColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${recommendation.progressValue}/${recommendation.progressGoal}',
                  style: AppTextStyles.caption.copyWith(
                    color: recommendation.priorityColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // 메시지
          Expanded(
            child: Text(
              displayMessage,
              style: AppTextStyles.body
                  .copyWith(color: context.wellness.textSecondary),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),

          // 액션 버튼
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _handleRecommendationAction(recommendation),
              style: FilledButton.styleFrom(
                backgroundColor: recommendation.priorityColor,
              ),
              child: Text(recommendation.actionLabel),
            ),
          ),
        ],
      ),
    );
  }

  /// 우선순위 라벨 텍스트
  String _getPriorityLabel(RecommendationPriority priority) {
    switch (priority) {
      case RecommendationPriority.critical:
        return '긴급';
      case RecommendationPriority.warning:
        return '경고';
      case RecommendationPriority.improve:
        return '개선';
      case RecommendationPriority.good:
        return '양호';
      case RecommendationPriority.excellent:
        return '완벽';
    }
  }

  DfetAxis _recommendationAxis(RecommendationCategory category) {
    return switch (category) {
      RecommendationCategory.protein ||
      RecommendationCategory.calories ||
      RecommendationCategory.hydration =>
        DfetAxis.nutrition,
      RecommendationCategory.exercise => DfetAxis.motion,
      RecommendationCategory.achievement ||
      RecommendationCategory.motivation =>
        DfetAxis.motion,
      RecommendationCategory.advice => DfetAxis.nutrition,
      RecommendationCategory.sleep => DfetAxis.motion,
    };
  }

  int _calculateTodos(int calories, int protein, int workoutTime) {
    int todos = 0;
    if (calories < 1800) todos++;
    if (protein < 100) todos++;
    if (workoutTime < 30) todos++;
    return todos;
  }

  /// 추천 액션 핸들러
  void _handleRecommendationAction(SmartRecommendation recommendation) {
    HapticFeedback.selectionClick();

    switch (recommendation.category) {
      case RecommendationCategory.protein:
        if (recommendation.actionLabel.contains('식품')) {
          _showProteinFoodsDialog();
        } else if (recommendation.actionLabel.contains('아침') ||
            recommendation.actionLabel.contains('메뉴')) {
          _showBreakfastMenuDialog();
        } else {
          _navigateToTab(1); // Meals tab
        }
        break;

      case RecommendationCategory.calories:
        if (recommendation.actionLabel.contains('식단') ||
            recommendation.actionLabel.contains('조언')) {
          _showNutritionTipsDialog();
        } else {
          _navigateToTab(1); // Meals tab
        }
        break;

      case RecommendationCategory.exercise:
        _navigateToTab(_isIOS ? 1 : 2);
        break;

      case RecommendationCategory.hydration:
        _showHydrationDialog();
        break;

      case RecommendationCategory.achievement:
      case RecommendationCategory.motivation:
        _navigateToTab(_isIOS ? 2 : 3);
        break;

      default:
        _showNutritionTipsDialog();
    }
  }

  /// 고단백 식품 가이드 다이얼로그 표시
  Future<void> _showProteinFoodsDialog() async {
    final result = await showDialog<dynamic>(
      context: context,
      builder: (context) => const ProteinFoodsDialog(),
    );

    // 다이얼로그에서 반환된 결과 처리
    if (result != null && mounted) {
      if (result == 'add_meal') {
        // 식사 탭으로 이동
        _navigateToTab(1);
      } else if (result is Map && result['action'] == 'add_meal') {
        // 특정 식품 정보와 함께 식사 탭으로 이동
        // TODO: 식품 정보를 식사 다이얼로그에 전달하는 로직 추가 가능
        _navigateToTab(1);
      }
    }
  }

  /// 영양 조언 다이얼로그 표시
  Future<void> _showNutritionTipsDialog() async {
    await showDialog(
      context: context,
      builder: (context) => const NutritionTipsDialog(),
    );
  }

  /// 수분 섭취 다이얼로그 표시
  Future<void> _showHydrationDialog() async {
    final waterIntake = await showDialog<int>(
      context: context,
      builder: (context) => const HydrationDialog(),
    );

    if (waterIntake != null && mounted) {
      // TODO: 수분 섭취 데이터를 Firestore에 저장하는 로직 추가
      // 현재는 다이얼로그에서만 표시하고 실제 저장은 하지 않음
      // 추후 수분 섭취 추적 기능 구현 시 여기에 저장 로직 추가
      AppLogger.info('[Dashboard] 수분 섭취 기록: ${waterIntake}ml');
    }
  }

  /// 아침 메뉴 추천 다이얼로그 표시
  Future<void> _showBreakfastMenuDialog() async {
    await showDialog(
      context: context,
      builder: (context) => const BreakfastMenuDialog(),
    );
  }

  /// 특정 탭으로 이동
  void _navigateToTab(int tabIndex) {
    ref.read(currentTabIndexProvider.notifier).state = tabIndex;
  }

  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
}
