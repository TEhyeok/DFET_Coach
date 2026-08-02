import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/user_profile.dart';
import '../../models/meal.dart';
import '../../models/workout.dart';
import '../../theme/tokens.dart';
import '../services/analytics_service.dart';

/// 사용자별 분석 데이터 Provider
final userAnalyticsProvider =
    FutureProvider.family<UserAnalytics, String>((ref, uid) async {
  final analyticsService = AnalyticsService();
  return await analyticsService.getUserAnalytics(uid);
});

/// 사용자 상세 확장 위젯
class UserDetailExpandable extends ConsumerStatefulWidget {
  final UserProfile user;

  const UserDetailExpandable({
    super.key,
    required this.user,
  });

  @override
  ConsumerState<UserDetailExpandable> createState() =>
      _UserDetailExpandableState();
}

class _UserDetailExpandableState extends ConsumerState<UserDetailExpandable>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _mealPage = 0;
  int _workoutPage = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analyticsAsync = ref.watch(userAnalyticsProvider(widget.user.uid));

    return Container(
      constraints: const BoxConstraints(maxHeight: 600),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 2),
        ),
      ),
      child: analyticsAsync.when(
        data: (analytics) => _buildContent(analytics),
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(48.0),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('데이터 로드 실패: $error'),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(UserAnalytics analytics) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 기본 정보 섹션
          _buildBasicInfo(),

          const Divider(height: 1),

          // 탭 바
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.brandPrimary,
              unselectedLabelColor: AppColors.textSubtle,
              indicatorColor: AppColors.brandPrimary,
              tabs: const [
                Tab(text: '일간 통계'),
                Tab(text: '주간 통계'),
                Tab(text: '월간 통계'),
              ],
            ),
          ),

          // 탭 내용
          Container(
            height: 400,
            color: Colors.white,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDailyStats(analytics),
                _buildWeeklyStats(analytics),
                _buildMonthlyStats(analytics),
              ],
            ),
          ),

          const Divider(height: 1),

          // 식단/운동 기록
          _buildRecordsSection(analytics),
        ],
      ),
    );
  }

  /// 기본 정보 섹션
  Widget _buildBasicInfo() {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final isActive = widget.user.lastLoginAt.isAfter(sevenDaysAgo);

    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Row(
        children: [
          // 프로필 사진
          CircleAvatar(
            radius: 40,
            backgroundColor:
                isActive ? AppColors.brandPrimary : Colors.grey.shade400,
            backgroundImage: widget.user.photoURL != null
                ? NetworkImage(widget.user.photoURL!)
                : null,
            child: widget.user.photoURL == null
                ? Text(
                    widget.user.displayName?.isNotEmpty == true
                        ? widget.user.displayName![0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 32,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 24),

          // 기본 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user.displayName ?? '이름 없음',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.user.email ?? '-',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSubtle,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildInfoChip(
                      icon: Icons.fingerprint,
                      label: 'UID: ${widget.user.uid.substring(0, 8)}...',
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      icon: widget.user.provider == 'google'
                          ? Icons.mail
                          : Icons.apple,
                      label: widget.user.provider?.toUpperCase() ?? 'Email',
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      icon: isActive ? Icons.check_circle : Icons.cancel,
                      label: isActive ? 'Active' : 'Inactive',
                      color: isActive ? AppColors.success : AppColors.textWeak,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 가입/로그인 정보
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildDateInfo(
                label: '마지막 로그인',
                date: widget.user.lastLoginAt,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF1E1E1E),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      title: const Text('Delete User',
                          style: TextStyle(color: Colors.white)),
                      content: Text(
                          'Are you sure you want to delete ${widget.user.displayName}?',
                          style: const TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel',
                              style: TextStyle(color: Colors.grey)),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            // Call AdminService deleteUser (Mock)
                            // Note: In a real app, we would use a provider to call the service and refresh the list
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('User deleted (Mock)')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                          child: const Text('Delete',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete User'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  foregroundColor: Colors.red,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? AppColors.brandPrimary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color ?? AppColors.brandPrimary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color ?? AppColors.brandPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateInfo({required String label, required DateTime date}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSubtle,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          DateFormat('yyyy-MM-dd HH:mm').format(date),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// 일간 통계 (최근 7일)
  Widget _buildDailyStats(UserAnalytics analytics) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '최근 7일 칼로리 섭취량',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _buildCaloriesLineChart(analytics.dailyCalories),
          ),
          const SizedBox(height: 32),
          const Text(
            '최근 7일 운동 횟수',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _buildWorkoutsBarChart(analytics.dailyWorkouts),
          ),
        ],
      ),
    );
  }

  /// 주간 통계 (최근 4주)
  Widget _buildWeeklyStats(UserAnalytics analytics) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatCard(
            title: '주간 평균 칼로리',
            value: '${analytics.weeklyAvgCalories.toStringAsFixed(0)} kcal',
            icon: Icons.restaurant,
            color: AppColors.brandPrimary,
          ),
          const SizedBox(height: 16),
          _buildStatCard(
            title: '주간 평균 운동 빈도',
            value: '${analytics.weeklyWorkoutFrequency.toStringAsFixed(1)}회/주',
            icon: Icons.fitness_center,
            color: AppColors.success,
          ),
          const SizedBox(height: 16),
          _buildStatCard(
            title: '평균 자세 점수',
            value: analytics.avgPostureScore > 0
                ? '${analytics.avgPostureScore.toStringAsFixed(1)}점'
                : '데이터 없음',
            icon: Icons.assessment,
            color: AppColors.info,
          ),
        ],
      ),
    );
  }

  /// 월간 통계 (최근 6개월)
  Widget _buildMonthlyStats(UserAnalytics analytics) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '영양소 비율 분석',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _buildNutrientsPieChart(analytics.dailyNutrients),
          ),
          const SizedBox(height: 24),
          Text(
            '전체 기록: 식단 ${analytics.recentMeals.length}개, 운동 ${analytics.recentWorkouts.length}개',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSubtle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSubtle,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 식단/운동 기록 섹션
  Widget _buildRecordsSection(UserAnalytics analytics) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 식단 기록
          const Text(
            '최근 식단 기록',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildMealsTable(analytics.recentMeals),
          const SizedBox(height: 32),

          // 운동 기록
          const Text(
            '최근 운동 기록',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildWorkoutsTable(analytics.recentWorkouts),
        ],
      ),
    );
  }

  /// 식단 테이블
  Widget _buildMealsTable(List<Meal> meals) {
    final itemsPerPage = 10;
    final totalPages = (meals.length / itemsPerPage).ceil();
    final startIndex = _mealPage * itemsPerPage;
    final endIndex = (startIndex + itemsPerPage).clamp(0, meals.length);
    final pageMeals = meals.sublist(startIndex, endIndex);

    return Column(
      children: [
        Table(
          border: TableBorder.all(color: Colors.grey.shade300),
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(3),
            3: FlexColumnWidth(1),
            4: FlexColumnWidth(1),
            5: FlexColumnWidth(1),
            6: FlexColumnWidth(1),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade100),
              children: const [
                Padding(
                  padding: EdgeInsets.all(12.0),
                  child:
                      Text('날짜', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.all(12.0),
                  child:
                      Text('시간', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('음식명',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('칼로리',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('단백질',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('탄수화물',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.all(12.0),
                  child:
                      Text('지방', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            ...pageMeals.map((meal) => TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(meal.date),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(meal.time),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(meal.name),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text('${meal.calories}'),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text('${meal.protein}g'),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text('${meal.carbs}g'),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text('${meal.fat}g'),
                    ),
                  ],
                )),
          ],
        ),
        if (totalPages > 1) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed:
                    _mealPage > 0 ? () => setState(() => _mealPage--) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              ...List.generate(totalPages, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton(
                    onPressed: () => setState(() => _mealPage = index),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _mealPage == index
                          ? AppColors.brandPrimary
                          : Colors.grey.shade300,
                      foregroundColor: _mealPage == index
                          ? Colors.white
                          : AppColors.textBody,
                      minimumSize: const Size(40, 40),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text('${index + 1}'),
                  ),
                );
              }),
              IconButton(
                onPressed: _mealPage < totalPages - 1
                    ? () => setState(() => _mealPage++)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// 운동 테이블
  Widget _buildWorkoutsTable(List<Workout> workouts) {
    final itemsPerPage = 10;
    final totalPages = (workouts.length / itemsPerPage).ceil();
    final startIndex = _workoutPage * itemsPerPage;
    final endIndex = (startIndex + itemsPerPage).clamp(0, workouts.length);
    final pageWorkouts = workouts.sublist(startIndex, endIndex);

    return Column(
      children: [
        Table(
          border: TableBorder.all(color: Colors.grey.shade300),
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(3),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(2),
            4: FlexColumnWidth(2),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade100),
              children: const [
                Padding(
                  padding: EdgeInsets.all(12.0),
                  child:
                      Text('날짜', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('운동명',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('카테고리',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('세트/시간',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('자세 점수',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            ...pageWorkouts.map((workout) => TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(workout.date),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(workout.name),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(workout.category),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(workout.displaySummary),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        workout.postureScore != null
                            ? '${workout.postureScore!.toStringAsFixed(1)}점'
                            : '-',
                      ),
                    ),
                  ],
                )),
          ],
        ),
        if (totalPages > 1) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _workoutPage > 0
                    ? () => setState(() => _workoutPage--)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              ...List.generate(totalPages, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton(
                    onPressed: () => setState(() => _workoutPage = index),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _workoutPage == index
                          ? AppColors.brandPrimary
                          : Colors.grey.shade300,
                      foregroundColor: _workoutPage == index
                          ? Colors.white
                          : AppColors.textBody,
                      minimumSize: const Size(40, 40),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text('${index + 1}'),
                  ),
                );
              }),
              IconButton(
                onPressed: _workoutPage < totalPages - 1
                    ? () => setState(() => _workoutPage++)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// 칼로리 라인 차트
  Widget _buildCaloriesLineChart(Map<String, double> dailyCalories) {
    if (dailyCalories.isEmpty) {
      return const Center(child: Text('데이터 없음'));
    }

    final sortedEntries = dailyCalories.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 &&
                    value.toInt() < sortedEntries.length) {
                  final date = sortedEntries[value.toInt()].key;
                  return Text(
                    date.substring(5), // MM-dd
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              sortedEntries.length,
              (index) => FlSpot(index.toDouble(), sortedEntries[index].value),
            ),
            isCurved: true,
            color: AppColors.brandPrimary,
            barWidth: 3,
            dotData: FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  /// 운동 횟수 바 차트
  Widget _buildWorkoutsBarChart(Map<String, int> dailyWorkouts) {
    if (dailyWorkouts.isEmpty) {
      return const Center(child: Text('데이터 없음'));
    }

    final sortedEntries = dailyWorkouts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return BarChart(
      BarChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 &&
                    value.toInt() < sortedEntries.length) {
                  final date = sortedEntries[value.toInt()].key;
                  return Text(
                    date.substring(5), // MM-dd
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        barGroups: List.generate(
          sortedEntries.length,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: sortedEntries[index].value.toDouble(),
                color: AppColors.success,
                width: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 영양소 파이 차트
  Widget _buildNutrientsPieChart(Map<String, Map<String, int>> dailyNutrients) {
    if (dailyNutrients.isEmpty) {
      return const Center(child: Text('데이터 없음'));
    }

    int totalProtein = 0;
    int totalCarbs = 0;
    int totalFat = 0;

    for (var nutrients in dailyNutrients.values) {
      totalProtein += nutrients['protein'] ?? 0;
      totalCarbs += nutrients['carbs'] ?? 0;
      totalFat += nutrients['fat'] ?? 0;
    }

    final total = totalProtein + totalCarbs + totalFat;
    if (total == 0) {
      return const Center(child: Text('데이터 없음'));
    }

    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: totalProtein.toDouble(),
            title: '단백질\n${(totalProtein / total * 100).toStringAsFixed(1)}%',
            color: AppColors.info,
            radius: 80,
          ),
          PieChartSectionData(
            value: totalCarbs.toDouble(),
            title: '탄수화물\n${(totalCarbs / total * 100).toStringAsFixed(1)}%',
            color: AppColors.warn,
            radius: 80,
          ),
          PieChartSectionData(
            value: totalFat.toDouble(),
            title: '지방\n${(totalFat / total * 100).toStringAsFixed(1)}%',
            color: AppColors.danger,
            radius: 80,
          ),
        ],
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }
}
