import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/admin_service.dart';
import '../models/user_stats.dart';

import '../../theme/admin_theme.dart';

/// 사용자 상세 페이지 Provider
final userStatsProvider =
    FutureProvider.family<UserStats, String>((ref, uid) async {
  final adminService = AdminService();
  return await adminService.getUserStats(uid, days: 30);
});

/// 사용자 상세 페이지
class UserDetailPage extends ConsumerWidget {
  final String uid;
  final String userName;

  const UserDetailPage({
    super.key,
    required this.uid,
    required this.userName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(userStatsProvider(uid));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            '$userName Details',
            style: AdminTheme.displaySmall,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          bottom: TabBar(
            indicatorColor: AdminTheme.accent,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.5),
            labelStyle: AdminTheme.titleMedium,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Nutrition'),
              Tab(text: 'Workout'),
            ],
          ),
        ),
        body: statsAsync.when(
          data: (stats) => TabBarView(
            children: [
              _buildOverviewTab(context, stats),
              _buildNutritionTab(context, stats),
              _buildWorkoutTab(context, stats),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AdminTheme.error),
                const SizedBox(height: 16),
                Text(
                  'Data Load Failed: $error',
                  style: AdminTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(userStatsProvider(uid)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context, UserStats stats) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUserInfoCard(stats),
          const SizedBox(height: 32),
          _buildStatsGrid(stats),
          const SizedBox(height: 32),
          _buildSectionTitle('Wellness Score Trend'),
          const SizedBox(height: 16),
          _buildWellnessChart(stats),
        ],
      ),
    );
  }

  Widget _buildNutritionTab(BuildContext context, UserStats stats) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Daily Calories'),
                    const SizedBox(height: 16),
                    _buildCaloriesChart(stats),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Daily Protein'),
                    const SizedBox(height: 16),
                    _buildProteinChart(stats),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Macronutrient Distribution'),
                    const SizedBox(height: 16),
                    _buildNutritionPieChart(stats),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Recent Meals (AI Analysis)'),
                    const SizedBox(height: 16),
                    _buildRecentMealsList(stats),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutTab(BuildContext context, UserStats stats) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Daily Workout Duration'),
                    const SizedBox(height: 16),
                    _buildWorkoutChart(stats),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Exercise Frequency'),
                    const SizedBox(height: 16),
                    _buildExerciseFrequencyChart(stats),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard(UserStats stats) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminTheme.glassDecoration(
        color: AdminTheme.surface,
        opacity: 0.6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: AdminTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AdminTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  stats.displayName.isNotEmpty
                      ? stats.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stats.displayName,
                      style: AdminTheme.displaySmall.copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stats.email,
                      style: AdminTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              if (stats.isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AdminTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AdminTheme.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'Active',
                    style: AdminTheme.bodyMedium.copyWith(
                      color: AdminTheme.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Divider(color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  'Joined',
                  stats.createdAt != null
                      ? DateFormat('MMM d, yyyy').format(stats.createdAt!)
                      : '-',
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  'Last Login',
                  stats.lastLoginAt != null
                      ? DateFormat('MMM d, yyyy').format(stats.lastLoginAt!)
                      : '-',
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  'Days Active',
                  stats.daysSinceLastLogin != null
                      ? '${stats.daysSinceLastLogin} days ago'
                      : '-',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AdminTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AdminTheme.titleMedium,
        ),
      ],
    );
  }

  Widget _buildStatsGrid(UserStats stats) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Meals',
            '${stats.totalMeals}',
            Icons.restaurant_menu_rounded,
            AdminTheme.secondary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Total Workouts',
            '${stats.totalWorkouts}',
            Icons.fitness_center_rounded,
            AdminTheme.warning,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Avg Calories',
            stats.nutritionSummary.avgCaloriesPerDay.toStringAsFixed(0),
            Icons.local_fire_department_rounded,
            AdminTheme.error,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Avg Protein',
            '${stats.nutritionSummary.avgProteinPerDay.toStringAsFixed(0)}g',
            Icons.egg_alt_rounded,
            AdminTheme.success,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'AI Tokens',
            '${stats.totalAiTokens}',
            Icons.auto_awesome_rounded,
            const Color(0xFF9B51E0),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminTheme.glassDecoration(
        color: AdminTheme.surface,
        opacity: 0.6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: AdminTheme.displaySmall.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AdminTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AdminTheme.titleLarge,
    );
  }

  Widget _buildCaloriesChart(UserStats stats) {
    final sortedDates = stats.dailyStats.keys.toList()..sort();
    final spots = <FlSpot>[];

    for (int i = 0; i < sortedDates.length; i++) {
      final dateKey = sortedDates[i];
      final calories = stats.dailyStats[dateKey]?.calories ?? 0;
      spots.add(FlSpot(i.toDouble(), calories.toDouble()));
    }

    return _buildLineChart(
      spots,
      AdminTheme.secondary,
      'kcal',
      maxY: 3000,
    );
  }

  Widget _buildProteinChart(UserStats stats) {
    final sortedDates = stats.dailyStats.keys.toList()..sort();
    final spots = <FlSpot>[];

    for (int i = 0; i < sortedDates.length; i++) {
      final dateKey = sortedDates[i];
      final protein = stats.dailyStats[dateKey]?.protein ?? 0;
      spots.add(FlSpot(i.toDouble(), protein.toDouble()));
    }

    return _buildLineChart(
      spots,
      AdminTheme.success,
      'g',
      maxY: 200,
    );
  }

  Widget _buildWorkoutChart(UserStats stats) {
    final sortedDates = stats.dailyStats.keys.toList()..sort();
    final spots = <FlSpot>[];

    for (int i = 0; i < sortedDates.length; i++) {
      final dateKey = sortedDates[i];
      final workoutTime = stats.dailyStats[dateKey]?.workoutTime ?? 0;
      spots.add(FlSpot(i.toDouble(), workoutTime.toDouble()));
    }

    return _buildLineChart(
      spots,
      AdminTheme.warning,
      'min',
      maxY: 120,
    );
  }

  Widget _buildWellnessChart(UserStats stats) {
    final sortedDates = stats.dailyStats.keys.toList()..sort();
    final spots = <FlSpot>[];

    for (int i = 0; i < sortedDates.length; i++) {
      final dateKey = sortedDates[i];
      final score = stats.dailyStats[dateKey]?.wellnessScore ?? 0;
      spots.add(FlSpot(i.toDouble(), score.toDouble()));
    }

    return _buildLineChart(
      spots,
      AdminTheme.primary,
      'pt',
      maxY: 100,
    );
  }

  Widget _buildLineChart(
    List<FlSpot> spots,
    Color color,
    String unit, {
    double maxY = 100,
  }) {
    if (spots.isEmpty) {
      return Container(
        height: 250,
        alignment: Alignment.center,
        decoration: AdminTheme.glassDecoration(
          color: AdminTheme.surface,
          opacity: 0.6,
        ),
        child: Text(
          'No Data',
          style: AdminTheme.bodyLarge,
        ),
      );
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.all(24),
      decoration: AdminTheme.glassDecoration(
        color: AdminTheme.surface,
        opacity: 0.6,
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.white.withValues(alpha: 0.05),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: spots.length > 10 ? 5 : 1,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= spots.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${value.toInt() + 1}d',
                      style: AdminTheme.bodyMedium.copyWith(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: maxY / 5,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}$unit',
                    style: AdminTheme.bodyMedium.copyWith(fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: spots.length.toDouble() - 1,
          minY: 0,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.3),
                    color.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionPieChart(UserStats stats) {
    final summary = stats.nutritionSummary;
    final total = summary.totalProtein + summary.totalCarbs + summary.totalFat;

    if (total == 0) {
      return Container(
        height: 250,
        alignment: Alignment.center,
        decoration: AdminTheme.glassDecoration(
          color: AdminTheme.surface,
          opacity: 0.6,
        ),
        child: Text(
          'No Data',
          style: AdminTheme.bodyLarge,
        ),
      );
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.all(24),
      decoration: AdminTheme.glassDecoration(
        color: AdminTheme.surface,
        opacity: 0.6,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: summary.totalProtein.toDouble(),
                    title: 'Protein',
                    color: AdminTheme.success,
                    radius: 80,
                    titleStyle:
                        AdminTheme.titleMedium.copyWith(color: Colors.white),
                  ),
                  PieChartSectionData(
                    value: summary.totalCarbs.toDouble(),
                    title: 'Carbs',
                    color: AdminTheme.secondary,
                    radius: 80,
                    titleStyle:
                        AdminTheme.titleMedium.copyWith(color: Colors.white),
                  ),
                  PieChartSectionData(
                    value: summary.totalFat.toDouble(),
                    title: 'Fat',
                    color: AdminTheme.error,
                    radius: 80,
                    titleStyle:
                        AdminTheme.titleMedium.copyWith(color: Colors.white),
                  ),
                ],
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLegendItem(
                    'Protein', '${summary.totalProtein}g', AdminTheme.success),
                const SizedBox(height: 8),
                _buildLegendItem(
                    'Carbs', '${summary.totalCarbs}g', AdminTheme.secondary),
                const SizedBox(height: 8),
                _buildLegendItem(
                    'Fat', '${summary.totalFat}g', AdminTheme.error),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AdminTheme.textWhite,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AdminTheme.textWhite,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExerciseFrequencyChart(UserStats stats) {
    final frequency = stats.workoutSummary.exerciseFrequency;

    if (frequency.isEmpty) {
      return Container(
        height: 250,
        alignment: Alignment.center,
        decoration: AdminTheme.glassDecoration(
          color: AdminTheme.surface,
          opacity: 0.6,
        ),
        child: Text(
          'No Data',
          style: AdminTheme.bodyLarge,
        ),
      );
    }

    final sortedEntries = frequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      height: 250,
      padding: const EdgeInsets.all(24),
      decoration: AdminTheme.glassDecoration(
        color: AdminTheme.surface,
        opacity: 0.6,
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: sortedEntries.first.value.toDouble() * 1.2,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= sortedEntries.length) {
                    return const SizedBox();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      sortedEntries[value.toInt()].key,
                      style: AdminTheme.bodyMedium.copyWith(fontSize: 10),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: AdminTheme.bodyMedium.copyWith(fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.white.withValues(alpha: 0.05),
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(show: false),
          barGroups: sortedEntries.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.value.toDouble(),
                  gradient: AdminTheme.primaryGradient,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRecentMealsList(UserStats stats) {
    if (stats.recentMeals.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        decoration: AdminTheme.glassDecoration(
          color: AdminTheme.surface,
          opacity: 0.6,
        ),
        child: Text(
          'No Meals Recorded',
          style: AdminTheme.bodyLarge,
        ),
      );
    }

    return Container(
      decoration: AdminTheme.glassDecoration(
        color: AdminTheme.surface,
        opacity: 0.6,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: stats.recentMeals.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.white.withValues(alpha: 0.05),
        ),
        itemBuilder: (context, index) {
          final meal = stats.recentMeals[index];
          final hasAiData = meal.aiTokenUsage != null;
          final tokenCount = hasAiData ? meal.aiTokenUsage!['totalTokens'] : 0;

          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: hasAiData
                  ? AdminTheme.primary.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.05),
              child: Icon(
                Icons.restaurant,
                color: hasAiData ? AdminTheme.primary : AdminTheme.textDisabled,
                size: 20,
              ),
            ),
            title: Text(
              meal.name,
              style: AdminTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${meal.date} ${meal.time} • ${meal.calories}kcal',
              style: AdminTheme.bodyMedium,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasAiData)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AdminTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome,
                            size: 12, color: AdminTheme.accent),
                        const SizedBox(width: 4),
                        Text(
                          '$tokenCount tokens',
                          style: AdminTheme.bodyMedium.copyWith(
                            color: AdminTheme.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    'Manual',
                    style: AdminTheme.bodyMedium.copyWith(
                      color: AdminTheme.textDisabled,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
