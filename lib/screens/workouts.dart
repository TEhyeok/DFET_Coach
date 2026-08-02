import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/app_card.dart';
import '../widgets/loading_state.dart';
import '../models/workout.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../theme/text_styles.dart';
import '../utils/record_entry_actions.dart';
import '../utils/responsive_layout.dart';
import 'package:intl/intl.dart';

class WorkoutsScreen extends ConsumerWidget {
  const WorkoutsScreen({
    super.key,
    this.showEntryActions = true,
    this.contentPadding,
  });

  final bool showEntryActions;
  final EdgeInsets? contentPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workouts = ref.watch(workoutsProvider);
    final totalTime = ref.watch(totalWorkoutTimeProvider);
    final isToday = ref.watch(isSelectedDateTodayProvider);

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
        final summaryHeight =
            (availableHeight * 0.18).clamp(150.0, 220.0).toDouble();
        final listHeight = useTwoColumns
            ? (availableHeight * 0.72).clamp(520.0, 720.0).toDouble()
            : (availableHeight * 0.64).clamp(340.0, 640.0).toDouble();

        return SingleChildScrollView(
          padding: contentPadding ?? ResponsiveLayout.pagePadding(context),
          child: ResponsiveConstrainedBox(
            child: useTwoColumns
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: SizedBox(
                          height: summaryHeight,
                          child: _buildSummaryCard(context, workouts.length,
                              totalTime, summaryHeight, isToday),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 7,
                        child: SizedBox(
                          height: listHeight,
                          child: _buildWorkoutListCard(
                              context, ref, workouts, isToday),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      SizedBox(
                        height: summaryHeight,
                        child: _buildSummaryCard(context, workouts.length,
                            totalTime, summaryHeight, isToday),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: listHeight,
                        child: _buildWorkoutListCard(
                            context, ref, workouts, isToday),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(BuildContext context, int workoutCount,
      int totalTime, double summaryHeight, bool isToday) {
    return AppCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isToday ? '오늘의 운동' : '선택 날짜 운동',
            style:
                AppTextStyles.h3.copyWith(color: context.wellness.textPrimary),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryCell(context, '$workoutCount', '운동', summaryHeight),
              _summaryCell(context, '$totalTime분', '총 시간', summaryHeight),
              _summaryCell(context, '${(totalTime * 5).toStringAsFixed(0)}',
                  'kcal 소모', summaryHeight),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutListCard(BuildContext context, WidgetRef ref,
      List<Workout> workouts, bool isToday) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '운동 기록',
                style: AppTextStyles.h3
                    .copyWith(color: context.wellness.textPrimary),
              ),
              if (showEntryActions)
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () =>
                          RecordEntryActions.showPostureAssessment(context),
                      icon: const Icon(Icons.camera_alt, size: 16),
                      label:
                          const Text('자세 평가', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.info,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      onPressed: () =>
                          RecordEntryActions.showWorkout(context, ref),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                      child: const Text('+ 추가', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: workouts.isEmpty
                ? Center(
                    child: EmptyStateWidget(
                      icon: Icons.fitness_center_outlined,
                      title: '아직 운동 기록이 없습니다',
                      subtitle:
                          isToday ? '오늘 한 운동을 기록해보세요' : '선택한 날짜의 운동을 기록해보세요',
                      action: showEntryActions
                          ? FilledButton.icon(
                              onPressed: () =>
                                  RecordEntryActions.showWorkout(context, ref),
                              icon: const Icon(Icons.add),
                              label: const Text('운동 추가'),
                            )
                          : null,
                    ),
                  )
                : ListView.builder(
                    itemCount: workouts.length,
                    itemBuilder: (context, index) {
                      final workout = workouts[index];
                      return Dismissible(
                        key: Key(workout.id),
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
                        onDismissed: (_) => ref
                            .read(workoutsProvider.notifier)
                            .deleteWorkout(workout.id),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.wellness.bgRoot,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: context.wellness.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: _getCategoryColor(
                                                  workout.category)
                                              .withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          _getCategoryIcon(workout.category),
                                          color: _getCategoryColor(
                                              workout.category),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(workout.name,
                                              style: AppTextStyles.h3.copyWith(
                                                  color: context
                                                      .wellness.textPrimary)),
                                          Text(
                                            DateFormat('HH:mm')
                                                .format(workout.timestamp),
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                                    color: context.wellness
                                                        .textTertiary),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Text(workout.displaySummary,
                                      style: AppTextStyles.label.copyWith(
                                          color:
                                              context.wellness.textSecondary)),
                                ],
                              ),
                              if (workout.category == 'strength' &&
                                  workout.sets.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Divider(
                                    color: context.wellness.border, height: 1),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children:
                                      workout.sets.asMap().entries.map((entry) {
                                    final idx = entry.key + 1;
                                    final set = entry.value;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.brandPrimary
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '$idx세트: ${set.weight}kg × ${set.reps}회',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.brandPrimary,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
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

  Widget _summaryCell(
      BuildContext context, String value, String label, double height) {
    final valueFontSize = (height * 0.30).clamp(18.0, 28.0);
    final labelFontSize = (height * 0.12).clamp(10.0, 12.0);

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.kpi.copyWith(
              color: AppColors.brandPrimary,
              fontSize: valueFontSize,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: labelFontSize,
              color: context.wellness.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'strength':
        return Icons.fitness_center;
      case 'cardio':
        return Icons.directions_run;
      case 'flexibility':
        return Icons.self_improvement;
      default:
        return Icons.sports_gymnastics;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'strength':
        return AppColors.brandPrimary;
      case 'cardio':
        return AppColors.info;
      case 'flexibility':
        return AppColors.accentGold;
      default:
        return AppColors.textSubtle;
    }
  }
}
