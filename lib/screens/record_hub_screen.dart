import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/record_types.dart';
import '../services/pose_detection_service.dart';
import '../state/app_state.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import '../utils/record_entry_actions.dart';
import '../utils/responsive_layout.dart';
import '../widgets/app_card.dart';
import '../widgets/ios_adaptive_sheet.dart';
import 'meals.dart';
import 'workouts.dart';

class RecordHubScreen extends ConsumerStatefulWidget {
  const RecordHubScreen({super.key});

  @override
  ConsumerState<RecordHubScreen> createState() => _RecordHubScreenState();
}

class _RecordHubScreenState extends ConsumerState<RecordHubScreen> {
  RecordSection _selectedSection = RecordSection.meals;
  ExerciseType _selectedExercise = ExerciseType.squat;

  @override
  Widget build(BuildContext context) {
    final meals = ref.watch(mealsProvider);
    final workouts = ref.watch(workoutsProvider);
    final totalCalories = ref.watch(totalCaloriesProvider);
    final totalWorkoutTime = ref.watch(totalWorkoutTimeProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final isToday = ref.watch(isSelectedDateTodayProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = ResponsiveLayout.isTablet(context);
        final useSplit = isTablet && constraints.maxWidth >= 920;

        if (useSplit) {
          return Padding(
            padding: ResponsiveLayout.pagePadding(context),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 340,
                  child: SingleChildScrollView(
                    child: _buildControlPanel(
                      mealsCount: meals.length,
                      workoutsCount: workouts.length,
                      totalCalories: totalCalories,
                      totalWorkoutTime: totalWorkoutTime,
                      selectedDate: selectedDate,
                      isToday: isToday,
                      showTitle: true,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildSectionView(
                    EdgeInsets.zero,
                    constraints.maxHeight -
                        ResponsiveLayout.pagePadding(context).vertical,
                  ),
                ),
              ],
            ),
          );
        }

        final sectionHeight =
            (constraints.maxHeight * 0.72).clamp(460.0, 720.0).toDouble();

        return ListView(
          padding: ResponsiveLayout.compactPagePadding(context),
          children: [
            _buildControlPanel(
              mealsCount: meals.length,
              workoutsCount: workouts.length,
              totalCalories: totalCalories,
              totalWorkoutTime: totalWorkoutTime,
              selectedDate: selectedDate,
              isToday: isToday,
              showTitle: false,
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: sectionHeight,
              child: _buildSectionView(
                EdgeInsets.zero,
                sectionHeight,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlPanel({
    required int mealsCount,
    required int workoutsCount,
    required int totalCalories,
    required int totalWorkoutTime,
    required DateTime selectedDate,
    required bool isToday,
    required bool showTitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle) ...[
          Text('기록 허브', style: AppTextStyles.h2),
          const SizedBox(height: 6),
          Text(
            _dateSubtitle(selectedDate, isToday),
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSubtle,
            ),
          ),
          const SizedBox(height: 16),
        ],
        _buildDateNavigator(selectedDate, isToday),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(child: _summaryMetric('$mealsCount', '식단')),
              _metricDivider(),
              Expanded(child: _summaryMetric('$workoutsCount', '운동')),
              _metricDivider(),
              Expanded(child: _summaryMetric('$totalCalories', 'kcal')),
              _metricDivider(),
              Expanded(child: _summaryMetric('${totalWorkoutTime}분', '시간')),
            ],
          ),
        ),
        const SizedBox(height: 14),
        IOSActionRow(
          icon: CupertinoIcons.camera,
          title: RecordEntryMode.photoMeal.title,
          subtitle: 'AI 분석',
          color: AppColors.brandPrimary,
          onPressed: () => RecordEntryActions.showPhotoMeal(context, ref),
        ),
        const SizedBox(height: 10),
        IOSActionRow(
          icon: CupertinoIcons.pencil,
          title: RecordEntryMode.manualMeal.title,
          subtitle: '영양 정보 입력',
          color: AppColors.accentGold,
          onPressed: () => RecordEntryActions.showManualMeal(context, ref),
        ),
        const SizedBox(height: 10),
        IOSActionRow(
          icon: CupertinoIcons.flame,
          title: RecordEntryMode.workout.title,
          subtitle: '세트 또는 시간 입력',
          color: AppColors.info,
          onPressed: () => RecordEntryActions.showWorkout(context, ref),
        ),
        const SizedBox(height: 10),
        IOSActionRow(
          icon: CupertinoIcons.person_crop_rectangle,
          title: RecordEntryMode.posture.title,
          subtitle: '스쿼트, 푸시업, 플랭크',
          color: AppColors.success,
          onPressed: () {
            setState(() => _selectedSection = RecordSection.posture);
          },
        ),
        const SizedBox(height: 14),
        _buildSegmentedControl(),
      ],
    );
  }

  Widget _buildDateNavigator(DateTime selectedDate, bool isToday) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _dateIconButton(
            icon: CupertinoIcons.chevron_left,
            onPressed: () => _moveDate(-1),
          ),
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              onPressed: _pickDate,
              child: Column(
                children: [
                  Text(
                    _dateTitle(selectedDate, isToday),
                    style: AppTextStyles.h3,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('yyyy.MM.dd').format(selectedDate),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSubtle,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _dateIconButton(
            icon: CupertinoIcons.chevron_right,
            onPressed: isToday ? null : () => _moveDate(1),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            minSize: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: isToday
                ? Colors.white.withOpacity(0.06)
                : AppColors.brandPrimary.withOpacity(0.22),
            borderRadius: BorderRadius.circular(12),
            onPressed: isToday
                ? null
                : () {
                    ref.read(selectedDateProvider.notifier).state =
                        dateOnly(DateTime.now());
                  },
            child: Text(
              '오늘',
              style: AppTextStyles.caption.copyWith(
                color: isToday ? AppColors.textSubtle : AppColors.textStrong,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return CupertinoButton(
      minSize: 34,
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Icon(
        icon,
        color: onPressed == null ? Colors.white24 : AppColors.textStrong,
        size: 20,
      ),
    );
  }

  void _moveDate(int days) {
    final current = ref.read(selectedDateProvider);
    final today = dateOnly(DateTime.now());
    final next = dateOnly(current.add(Duration(days: days)));
    ref.read(selectedDateProvider.notifier).state =
        next.isAfter(today) ? today : next;
  }

  Future<void> _pickDate() async {
    final current = ref.read(selectedDateProvider);
    final today = dateOnly(DateTime.now());
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    if (isIOS) {
      var selected = current;
      final picked = await showCupertinoModalPopup<DateTime>(
        context: context,
        builder: (context) => Container(
          height: 320,
          color: AppColors.bgCard,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('취소'),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        onPressed: () => Navigator.pop(context, selected),
                        child: const Text('선택'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: current,
                    maximumDate: today,
                    minimumYear: 2024,
                    maximumYear: today.year,
                    onDateTimeChanged: (value) => selected = dateOnly(value),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (picked != null) {
        ref.read(selectedDateProvider.notifier).state = dateOnly(picked);
      }
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2024),
      lastDate: today,
    );

    if (picked != null) {
      ref.read(selectedDateProvider.notifier).state = dateOnly(picked);
    }
  }

  String _dateTitle(DateTime date, bool isToday) {
    if (isToday) return '오늘';
    final today = dateOnly(DateTime.now());
    if (date == today.subtract(const Duration(days: 1))) return '어제';
    return '${date.month}월 ${date.day}일 ${_weekdayLabel(date)}';
  }

  String _dateSubtitle(DateTime date, bool isToday) {
    return isToday ? '오늘의 기록' : '${_dateTitle(date, isToday)} 기록';
  }

  String _weekdayLabel(DateTime date) {
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return labels[date.weekday - 1];
  }

  Widget _buildSegmentedControl() {
    return CupertinoSlidingSegmentedControl<RecordSection>(
      groupValue: _selectedSection,
      backgroundColor: Colors.white.withOpacity(0.06),
      thumbColor: AppColors.brandPrimary.withOpacity(0.28),
      children: {
        for (final section in RecordSection.values)
          section: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              section.label,
              style: TextStyle(
                color: _selectedSection == section
                    ? AppColors.textStrong
                    : AppColors.textSubtle,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
      },
      onValueChanged: (value) {
        if (value == null) return;
        setState(() => _selectedSection = value);
      },
    );
  }

  Widget _buildSectionView(EdgeInsets padding, double availableHeight) {
    final minHeight = availableHeight.clamp(420.0, 760.0).toDouble();

    switch (_selectedSection) {
      case RecordSection.meals:
        return MealsScreen(
          showEntryActions: false,
          contentPadding: padding,
        );
      case RecordSection.workouts:
        return WorkoutsScreen(
          showEntryActions: false,
          contentPadding: padding,
        );
      case RecordSection.posture:
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: _buildPosturePanel(),
          ),
        );
    }
  }

  Widget _buildPosturePanel() {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('자세 평가', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _exerciseOption(
                  ExerciseType.squat,
                  '스쿼트',
                  CupertinoIcons.arrow_down_right_arrow_up_left,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _exerciseOption(
                  ExerciseType.pushup,
                  '푸시업',
                  CupertinoIcons.sportscourt,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _exerciseOption(
                  ExerciseType.plank,
                  '플랭크',
                  CupertinoIcons.rectangle_compress_vertical,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          CupertinoButton(
            color: AppColors.success,
            borderRadius: BorderRadius.circular(14),
            onPressed: () => RecordEntryActions.showPostureAssessment(
              context,
              initialExercise: _selectedExercise,
            ),
            child: const Text(
              '평가 시작',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: const Text(
              '전신이 보이도록 카메라를 고정하고 밝은 곳에서 진행하세요.',
              style: TextStyle(
                color: AppColors.textSubtle,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _exerciseOption(ExerciseType type, String label, IconData icon) {
    final selected = _selectedExercise == type;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => setState(() => _selectedExercise = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.success.withOpacity(0.16)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                selected ? AppColors.success.withOpacity(0.75) : Colors.white10,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? AppColors.success : AppColors.textSubtle,
              size: 28,
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.textStrong : AppColors.textSubtle,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryMetric(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: AppTextStyles.h3.copyWith(color: AppColors.textStrong),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSubtle),
        ),
      ],
    );
  }

  Widget _metricDivider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white10,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
