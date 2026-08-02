import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/app_card.dart';
import '../widgets/loading_state.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../theme/text_styles.dart';
import '../models/meal.dart';
import '../utils/record_entry_actions.dart';
import '../utils/responsive_layout.dart';

class MealsScreen extends ConsumerWidget {
  const MealsScreen({
    super.key,
    this.showEntryActions = true,
    this.contentPadding,
  });

  final bool showEntryActions;
  final EdgeInsets? contentPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = ref.watch(mealsProvider);
    final totalCalories = ref.watch(totalCaloriesProvider);
    final totalProtein = ref.watch(totalProteinProvider);
    final totalCarbs = ref.watch(totalCarbsProvider);
    final totalFat = ref.watch(totalFatProvider);
    final isToday = ref.watch(isSelectedDateTodayProvider);

    // Daily calorie goal
    const dailyGoal = 2000;
    final calorieProgress = (totalCalories / dailyGoal).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = ResponsiveLayout.isTablet(context);
        final useTwoColumns = isTablet && constraints.maxWidth >= 900;
        final screenHeight = MediaQuery.of(context).size.height;
        final safeAreaPadding = MediaQuery.of(context).padding;
        final availableHeight = screenHeight -
            safeAreaPadding.top -
            safeAreaPadding.bottom -
            (isTablet ? 96 : 140);
        final calorieCardHeight =
            (availableHeight * 0.10).clamp(92.0, 120.0).toDouble();
        final macroCardHeight =
            (availableHeight * 0.24).clamp(240.0, 320.0).toDouble();
        final mealsListHeight = useTwoColumns
            ? (availableHeight * 0.72).clamp(520.0, 720.0).toDouble()
            : (availableHeight * 0.40).clamp(320.0, 620.0).toDouble();
        final feedbackCard = totalProtein < 100
            ? _buildProteinFeedbackCard(context, totalProtein)
            : const SizedBox.shrink();

        return SingleChildScrollView(
          padding: contentPadding ?? ResponsiveLayout.pagePadding(context),
          child: ResponsiveConstrainedBox(
            child: useTwoColumns
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            SizedBox(
                              height: calorieCardHeight,
                              child: _buildCalorieCard(context, totalCalories,
                                  dailyGoal, calorieProgress),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: macroCardHeight,
                              child: _buildMacroCard(
                                  context, totalProtein, totalCarbs, totalFat),
                            ),
                            if (totalProtein < 100) ...[
                              const SizedBox(height: 16),
                              feedbackCard,
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 6,
                        child: SizedBox(
                          height: mealsListHeight,
                          child:
                              _buildMealsListCard(context, ref, meals, isToday),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      SizedBox(
                        height: calorieCardHeight,
                        child: _buildCalorieCard(
                            context, totalCalories, dailyGoal, calorieProgress),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: macroCardHeight,
                        child: _buildMacroCard(
                            context, totalProtein, totalCarbs, totalFat),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: mealsListHeight,
                        child:
                            _buildMealsListCard(context, ref, meals, isToday),
                      ),
                      if (totalProtein < 100) ...[
                        const SizedBox(height: 12),
                        feedbackCard,
                      ],
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildCalorieCard(BuildContext context, int totalCalories,
      int dailyGoal, double calorieProgress) {
    return AppCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '일일 칼로리',
                style: AppTextStyles.h3
                    .copyWith(color: context.wellness.textPrimary),
              ),
              Text('$totalCalories / $dailyGoal kcal',
                  style: AppTextStyles.body
                      .copyWith(color: context.wellness.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: calorieProgress,
              minHeight: 12,
              backgroundColor: context.wellness.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                calorieProgress > 0.9 ? AppColors.warn : AppColors.brandPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCard(BuildContext context, int totalProtein,
      int totalCarbs, int totalFat) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '영양소 비율',
            style:
                AppTextStyles.h3.copyWith(color: context.wellness.textPrimary),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: [
                        PieChartSectionData(
                          value: totalProtein.toDouble() * 4,
                          color: AppColors.brandPrimary,
                          title: '${totalProtein}g',
                          radius: 40,
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          value: totalCarbs.toDouble() * 4,
                          color: AppColors.accentGold,
                          title: '${totalCarbs}g',
                          radius: 40,
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          value: totalFat.toDouble() * 9,
                          color: AppColors.info,
                          title: '${totalFat}g',
                          radius: 40,
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _macroLegend(
                          context, '단백질', totalProtein, AppColors.brandPrimary),
                      const SizedBox(height: 8),
                      _macroLegend(
                          context, '탄수화물', totalCarbs, AppColors.accentGold),
                      const SizedBox(height: 8),
                      _macroLegend(context, '지방', totalFat, AppColors.info),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealsListCard(
      BuildContext context, WidgetRef ref, List<Meal> meals, bool isToday) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isToday ? '오늘 식단' : '선택 날짜 식단',
                style: AppTextStyles.h3
                    .copyWith(color: context.wellness.textPrimary),
              ),
              if (showEntryActions)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          RecordEntryActions.showManualMeal(context, ref),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('수동', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                    ),
                    const SizedBox(width: 6),
                    FilledButton.icon(
                      onPressed: () =>
                          RecordEntryActions.showPhotoMeal(context, ref),
                      icon: const Icon(Icons.camera_alt, size: 16),
                      label: const Text('사진', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: meals.isEmpty
                ? Center(
                    child: EmptyStateWidget(
                      icon: Icons.restaurant_outlined,
                      title: '아직 식단이 없습니다',
                      subtitle:
                          isToday ? '오늘 먹은 음식을 기록해보세요' : '선택한 날짜의 식단을 기록해보세요',
                    ),
                  )
                : ListView.builder(
                    itemCount: meals.length,
                    itemBuilder: (context, index) {
                      final meal = meals[index];
                      return Dismissible(
                        key: Key(meal.id),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) {
                          final deletedMeal = meal;
                          ref.read(mealsProvider.notifier).deleteMeal(meal.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${deletedMeal.name} 삭제됨'),
                              action: SnackBarAction(
                                label: '취소',
                                onPressed: () {
                                  ref
                                      .read(mealsProvider.notifier)
                                      .addMeal(deletedMeal);
                                },
                              ),
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        },
                        child: GestureDetector(
                          onTap: () => RecordEntryActions.showManualMeal(
                            context,
                            ref,
                            meal: meal,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(meal.time,
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                  color: context.wellness
                                                      .textTertiary)),
                                      Text(meal.name,
                                          style: AppTextStyles.bodyLarge
                                              .copyWith(
                                                  color: context.wellness
                                                      .textPrimary)),
                                      if (meal.protein > 0 ||
                                          meal.carbs > 0 ||
                                          meal.fat > 0)
                                        Text(
                                          'P:${meal.protein}g C:${meal.carbs}g F:${meal.fat}g',
                                          style: AppTextStyles.caption.copyWith(
                                              color: context
                                                  .wellness.textTertiary),
                                        ),
                                    ],
                                  ),
                                ),
                                Text('${meal.calories} kcal',
                                    style: AppTextStyles.label.copyWith(
                                        color:
                                            context.wellness.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProteinFeedbackCard(BuildContext context, int totalProtein) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '결핍: 단백질 ${100 - totalProtein}g 부족  →  추천 식단 보기를 눌러 채우세요',
          style: AppTextStyles.body
              .copyWith(color: context.wellness.textSecondary),
        ),
      ),
    );
  }

  Widget _macroLegend(
      BuildContext context, String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: context.wellness.textTertiary)),
            Text('${value}g',
                style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.wellness.textSecondary)),
          ],
        ),
      ],
    );
  }
}
