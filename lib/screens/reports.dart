import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../widgets/app_card.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../theme/text_styles.dart';
import '../utils/responsive_layout.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String selectedPeriod = 'week';
  DateTime selectedMonth = DateTime.now();
  bool isLoading = false;
  int? _loadTimeMs; // 로딩 시간 (디버그용)

  // 캐시된 데이터
  Map<String, Map<String, dynamic>>? _weeklyData;
  Map<int, Map<String, dynamic>>? _monthlyData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null || uid == 'guest') {
      // 게스트 모드: 오늘 데이터만 사용
      _loadGuestData();
      return;
    }

    setState(() {
      isLoading = true;
      _loadTimeMs = null;
    });

    final stopwatch = Stopwatch()..start();

    try {
      final firestoreService = ref.read(firestoreServiceProvider);

      if (selectedPeriod == 'week') {
        final result = await firestoreService.loadWeeklyData(uid);
        _weeklyData =
            Map<String, Map<String, dynamic>>.from(result['data'] as Map);
      } else {
        final result =
            await firestoreService.loadMonthlyData(uid, selectedMonth);
        _monthlyData =
            Map<int, Map<String, dynamic>>.from(result['data'] as Map);
      }
    } catch (e) {
      // 오류 시 게스트 데이터 사용
      _loadGuestData();
    }

    stopwatch.stop();

    if (mounted) {
      setState(() {
        isLoading = false;
        _loadTimeMs = stopwatch.elapsedMilliseconds;
      });
      if (kDebugMode) {
        debugPrint(
            '📊 [ReportsScreen] 데이터 로드 완료: ${stopwatch.elapsedMilliseconds}ms');
      }
    }
  }

  void _loadGuestData() {
    final wellnessScore = ref.read(wellnessScoreProvider);
    final totalCalories = ref.read(totalCaloriesProvider);
    final totalWorkoutTime = ref.read(totalWorkoutTimeProvider);
    final totalProtein = ref.read(totalProteinProvider);

    final hasData = totalCalories > 0 || totalWorkoutTime > 0;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 주간 데이터 (오늘만 데이터 있음)
    _weeklyData = {};
    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateString = DateFormat('yyyy-MM-dd').format(date);
      if (dateString == today && hasData) {
        _weeklyData![dateString] = {
          'calories': totalCalories,
          'protein': totalProtein,
          'workoutTime': totalWorkoutTime,
          'wellnessScore': wellnessScore,
        };
      } else {
        _weeklyData![dateString] = {
          'calories': 0,
          'protein': 0,
          'workoutTime': 0,
          'wellnessScore': 0,
        };
      }
    }

    // 월간 데이터
    _monthlyData = {};
    final now = DateTime.now();
    final currentWeek = ((now.day - 1) / 7).floor() + 1;
    for (int week = 1; week <= 4; week++) {
      if (week == currentWeek && hasData) {
        _monthlyData![week] = {
          'calories': totalCalories,
          'protein': totalProtein,
          'workoutTime': totalWorkoutTime,
          'wellnessScore': wellnessScore,
        };
      } else {
        _monthlyData![week] = {
          'calories': 0,
          'protein': 0,
          'workoutTime': 0,
          'wellnessScore': 0,
        };
      }
    }
  }

  void _showMonthPicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      helpText: '월 선택',
      locale: const Locale('ko', 'KR'),
    );

    if (picked != null && mounted) {
      setState(() {
        selectedMonth = DateTime(picked.year, picked.month);
      });
      _loadData();
    }
  }

  List<String> _getWeeklyLabels() {
    final labels = <String>[];
    // DateTime.weekday: 1=월, 2=화, 3=수, 4=목, 5=금, 6=토, 7=일
    final dayNames = ['월', '화', '수', '목', '금', '토', '일'];

    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      labels.add(dayNames[date.weekday - 1]);
    }
    return labels;
  }

  @override
  Widget build(BuildContext context) {
    if (_weeklyData == null || _monthlyData == null) {
      _loadGuestData();
    }

    final isWeekly = selectedPeriod == 'week';

    // 데이터 추출
    List<double> wellnessData;
    List<int> caloriesData;
    List<int> workoutsData;
    List<String> labels;

    if (isWeekly) {
      final sortedDates = _weeklyData!.keys.toList()..sort();
      wellnessData = sortedDates
          .map((d) => (_weeklyData![d]!['wellnessScore'] as int).toDouble())
          .toList();
      caloriesData =
          sortedDates.map((d) => _weeklyData![d]!['calories'] as int).toList();
      workoutsData = sortedDates
          .map((d) => _weeklyData![d]!['workoutTime'] as int)
          .toList();
      labels = _getWeeklyLabels();
    } else {
      wellnessData = [1, 2, 3, 4]
          .map((w) => (_monthlyData![w]!['wellnessScore'] as int).toDouble())
          .toList();
      caloriesData = [1, 2, 3, 4]
          .map((w) => _monthlyData![w]!['calories'] as int)
          .toList();
      workoutsData = [1, 2, 3, 4]
          .map((w) => _monthlyData![w]!['workoutTime'] as int)
          .toList();
      labels = ['1주', '2주', '3주', '4주'];
    }

    final hasAnyData =
        caloriesData.any((c) => c > 0) || workoutsData.any((w) => w > 0);
    final dataLength = isWeekly ? 7 : 4;

    // 화면 크기 기반 비율 계산 (한 화면에 토글+차트1개가 보이도록 압축)
    final screenHeight = MediaQuery.of(context).size.height;
    final safeAreaPadding = MediaQuery.of(context).padding;
    final availableHeight =
        screenHeight - safeAreaPadding.top - safeAreaPadding.bottom - 140;
    final selectorHeight = (availableHeight * 0.07).clamp(52.0, 64.0);
    final chartHeight = (availableHeight * 0.24).clamp(180.0, 240.0);
    final summaryHeight = (availableHeight * 0.18).clamp(160.0, 200.0);

    return Stack(
      children: [
        ListView(
          padding: ResponsiveLayout.pagePadding(context),
          children: [
            ResponsiveConstrainedBox(
              child: Column(
                children: [
                  // Period selector
                  SizedBox(
                    height: selectorHeight,
                    child: AppCard(
                      child: Row(
                        children: [
                          _periodButton(context, '주간', 'week'),
                          const SizedBox(width: 8),
                          _periodButton(context, '월간', 'month'),
                          if (!isWeekly) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _showMonthPicker,
                              icon: const Icon(Icons.calendar_month, size: 20),
                              tooltip: '월 선택',
                              style: IconButton.styleFrom(
                                backgroundColor: context.wellness.primary
                                    .withValues(alpha: 0.1),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (!isWeekly) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${selectedMonth.year}년 ${selectedMonth.month}월',
                      style: AppTextStyles.caption
                          .copyWith(color: context.wellness.primary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  // 디버그: 로딩 시간 표시 (디버그 빌드에서만)
                  if (kDebugMode && _loadTimeMs != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '⏱️ 로딩 시간: ${_loadTimeMs}ms',
                      style: AppTextStyles.caption.copyWith(
                        color: _loadTimeMs! < 1000
                            ? context.wellness.primary
                            : context.wellness.warning,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 8),

                  if (!hasAnyData)
                    _buildEmptyState(context, chartHeight + summaryHeight)
                  else ...[
                  // Wellness score trend
                  SizedBox(
                    height: chartHeight,
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '웰니스 점수 추이',
                            style: AppTextStyles.h3.copyWith(
                                color: context.wellness.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: LineChart(
                              LineChartData(
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: 25,
                                  getDrawingHorizontalLine: (value) {
                                    return FlLine(
                                      color: context.wellness.border,
                                      strokeWidth: 1,
                                    );
                                  },
                                ),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 30,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          value.toInt().toString(),
                                          style: AppTextStyles.caption.copyWith(
                                              color: context
                                                  .wellness.textTertiary),
                                        );
                                      },
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: 1,
                                      getTitlesWidget: (value, meta) {
                                        final index = value.toInt();
                                        if (index >= 0 &&
                                            index < labels.length) {
                                          return Text(labels[index],
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                      color: context.wellness
                                                          .textTertiary));
                                        }
                                        return const Text('');
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: false),
                                minY: 0,
                                maxY: 100,
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: wellnessData
                                        .asMap()
                                        .entries
                                        .map((e) =>
                                            FlSpot(e.key.toDouble(), e.value))
                                        .toList(),
                                    isCurved: false,
                                    color: context.wellness.primary,
                                    barWidth: 3,
                                    dotData: const FlDotData(show: true),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: context.wellness.primary
                                          .withValues(alpha: 0.1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Calories bar chart
                  SizedBox(
                    height: chartHeight,
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '칼로리 섭취량',
                            style: AppTextStyles.h3.copyWith(
                                color: context.wellness.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: 500,
                                  getDrawingHorizontalLine: (value) {
                                    return FlLine(
                                      color: context.wellness.border,
                                      strokeWidth: 1,
                                    );
                                  },
                                ),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 35,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          '${(value / 1000).toStringAsFixed(1)}k',
                                          style: AppTextStyles.caption.copyWith(
                                              color: context
                                                  .wellness.textTertiary),
                                        );
                                      },
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        final index = value.toInt();
                                        if (index >= 0 &&
                                            index < labels.length) {
                                          return Text(labels[index],
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                      color: context.wellness
                                                          .textTertiary));
                                        }
                                        return const Text('');
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: false),
                                barGroups: List.generate(dataLength, (index) {
                                  return BarChartGroupData(
                                    x: index,
                                    barRods: [
                                      BarChartRodData(
                                        toY: caloriesData[index].toDouble(),
                                        color: context.wellness.accent,
                                        width: isWeekly ? 12 : 20,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ],
                                  );
                                }),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Summary stats
                  SizedBox(
                    height: summaryHeight,
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isWeekly ? '이번 주 요약' : '이번 달 요약',
                            style: AppTextStyles.h3.copyWith(
                                color: context.wellness.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _statRow(
                                  context,
                                  '평균 웰니스 점수',
                                  hasAnyData
                                      ? '${(wellnessData.reduce((a, b) => a + b) / wellnessData.length).round()}점'
                                      : '0점',
                                  context.wellness.primary,
                                ),
                                _statRow(
                                  context,
                                  '총 칼로리 섭취',
                                  hasAnyData
                                      ? '${caloriesData.reduce((a, b) => a + b).toStringAsFixed(0)} kcal'
                                      : '0 kcal',
                                  context.wellness.accent,
                                ),
                                _statRow(
                                  context,
                                  '총 운동 시간',
                                  hasAnyData
                                      ? '${workoutsData.reduce((a, b) => a + b)}분'
                                      : '0분',
                                  context.wellness.info,
                                ),
                                _statRow(
                                  context,
                                  '목표 달성률',
                                  hasAnyData
                                      ? '${((wellnessData.reduce((a, b) => a + b) / wellnessData.length) / 100 * 100).round()}%'
                                      : '0%',
                                  context.wellness.primary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (isLoading)
          Container(
            color: Colors.black26,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, double height) {
    return SizedBox(
      height: height.clamp(280.0, 560.0),
      child: AppCard(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insights_outlined,
                size: 48,
                color: context.wellness.textTertiary,
              ),
              const SizedBox(height: 12),
              Text(
                '아직 표시할 데이터가 없어요',
                style: AppTextStyles.h3
                    .copyWith(color: context.wellness.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                '식단과 운동을 기록하면 추이가 여기에 나타나요.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: context.wellness.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _periodButton(BuildContext context, String label, String value) {
    final isSelected = selectedPeriod == value;
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          setState(() => selectedPeriod = value);
          _loadData();
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected
              ? context.wellness.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          side: BorderSide(
            color:
                isSelected ? context.wellness.primary : context.wellness.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? context.wellness.primary
                : context.wellness.textTertiary,
          ),
        ),
      ),
    );
  }

  Widget _statRow(
      BuildContext context, String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.body
              .copyWith(color: context.wellness.textSecondary),
        ),
        Text(
          value,
          style: AppTextStyles.h3.copyWith(color: color),
        ),
      ],
    );
  }
}
