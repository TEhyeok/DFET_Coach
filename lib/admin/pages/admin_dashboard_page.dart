import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/admin_service.dart';

import '../../theme/admin_theme.dart';


/// 대시보드 통계 Provider
final dashboardStatsProvider = FutureProvider((ref) async {
  final adminService = AdminService();
  return await adminService.getDashboardStats();
});

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return statsAsync.when(
      data: (stats) => _buildContent(context, stats),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AdminTheme.error),
            const SizedBox(height: 16),
            Text('Data Load Failed: $error', style: AdminTheme.bodyLarge),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.refresh(dashboardStatsProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AdminDashboardStats stats) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayUsers = stats.recentUsers.where((user) {
      return user.createdAt != null && user.createdAt!.isAfter(todayStart);
    }).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          Text(
            'Welcome back, Admin!',
            style: AdminTheme.displayMedium,
          ),
          Text(
            'Here is what\'s happening with your app today.',
            style: AdminTheme.bodyLarge,
          ),
          const SizedBox(height: 32),

          // Stats Cards Row 1
          Row(
            children: [
              Expanded(
                child: _buildStatsCard(
                  label: 'Total Users',
                  value: '${stats.totalUsers}',
                  change: '+20%',
                  icon: Icons.people_alt_rounded,
                  color: AdminTheme.primary,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildStatsCard(
                  label: 'Active Users',
                  value: '${stats.activeUsers}',
                  change: stats.totalUsers > 0
                      ? '+${((stats.activeUsers / stats.totalUsers) * 100).toStringAsFixed(0)}%'
                      : '+0%',
                  icon: Icons.trending_up_rounded,
                  color: AdminTheme.success,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildStatsCard(
                  label: 'New Signups',
                  value: '$todayUsers',
                  change: '+100%',
                  icon: Icons.person_add_rounded,
                  color: AdminTheme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stats Cards Row 2
          Row(
            children: [
              Expanded(
                child: _buildStatsCard(
                  label: 'Total Meals',
                  value: '${stats.totalMeals}',
                  change: 'Accumulated',
                  icon: Icons.restaurant_menu_rounded,
                  color: AdminTheme.secondary,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildStatsCard(
                  label: 'Workouts',
                  value: '${stats.totalWorkouts}',
                  change: 'Accumulated',
                  icon: Icons.fitness_center_rounded,
                  color: AdminTheme.warning,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildStatsCard(
                  label: 'AI Tokens',
                  value: NumberFormat('#,###').format(stats.totalAiTokens),
                  change: 'Gemini API',
                  icon: Icons.auto_awesome_rounded,
                  color: const Color(0xFF9B51E0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Charts Area
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildAiUsageChart(stats),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 1,
                child: _buildActivityPieChart(stats),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Bottom Area
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDailyActiveUsersChart(stats),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildRecentUsersList(context, stats),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard({
    required String label,
    required String value,
    required String change,
    required IconData icon,
    required Color color,
  }) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AdminTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  change,
                  style: AdminTheme.bodyMedium.copyWith(
                    color: AdminTheme.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            value,
            style: AdminTheme.displayMedium,
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

  Widget _buildAiUsageChart(AdminDashboardStats stats) {
    final sortedKeys = stats.dailyAiTokenUsage.keys.toList()..sort();
    final spots = sortedKeys.asMap().entries.map((entry) {
      final count = stats.dailyAiTokenUsage[entry.value] ?? 0;
      return FlSpot(entry.key.toDouble(), count.toDouble());
    }).toList();

    // Calculate max value for dynamic Y-axis
    double maxTokens = 0;
    for (var count in stats.dailyAiTokenUsage.values) {
      if (count > maxTokens) maxTokens = count.toDouble();
    }
    
    // Add 20% padding to the top, minimum 100 if all zero
    final double maxY = maxTokens > 0 ? maxTokens * 1.2 : 100;
    
    // Calculate a nice interval (aim for ~5 grid lines)
    double interval = maxY / 5;
    if (interval == 0) interval = 20;
    
    // Round interval to nice numbers (10, 50, 100, 500, 1000, etc.)
    if (interval > 10) {
      final magnitude = (interval / 10).ceil() * 10;
      interval = magnitude.toDouble();
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminTheme.glassDecoration(
        color: AdminTheme.surface,
        opacity: 0.6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI Token Usage', style: AdminTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Last 7 days trend', style: AdminTheme.bodyMedium),
          const SizedBox(height: 32),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                maxY: maxY,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withOpacity(0.05),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: interval,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const Text('');
                        return Text(
                          value >= 1000
                              ? '${(value / 1000).toStringAsFixed(1)}k'
                              : value.toInt().toString(),
                          style: AdminTheme.bodyMedium.copyWith(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < sortedKeys.length) {
                          final dateStr = sortedKeys[value.toInt()];
                          final date = DateFormat('yyyy-MM-dd').parse(dateStr);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('MM/dd').format(date),
                              style: AdminTheme.bodyMedium.copyWith(fontSize: 10),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AdminTheme.accent,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 6,
                          color: AdminTheme.background,
                          strokeWidth: 3,
                          strokeColor: AdminTheme.accent,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AdminTheme.accent.withOpacity(0.3),
                          AdminTheme.accent.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityPieChart(AdminDashboardStats stats) {
    final activeCount = stats.activeUsers;
    final inactiveCount = stats.totalUsers - stats.activeUsers;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminTheme.glassDecoration(
        color: AdminTheme.surface,
        opacity: 0.6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('User Activity', style: AdminTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Active vs Inactive', style: AdminTheme.bodyMedium),
          const SizedBox(height: 32),
          SizedBox(
            height: 300,
            child: PieChart(
              PieChartData(
                sectionsSpace: 0,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    value: activeCount.toDouble(),
                    title: '${((activeCount / stats.totalUsers) * 100).toStringAsFixed(0)}%',
                    color: AdminTheme.primary,
                    radius: 80,
                    titleStyle: AdminTheme.titleLarge,
                  ),
                  PieChartSectionData(
                    value: inactiveCount.toDouble(),
                    title: '',
                    color: AdminTheme.surfaceHighlight,
                    radius: 60,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Active', AdminTheme.primary),
              const SizedBox(width: 24),
              _buildLegendItem('Inactive', AdminTheme.surfaceHighlight),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyActiveUsersChart(AdminDashboardStats stats) {
    final now = DateTime.now();
    final last7Days = List.generate(7, (i) {
      return DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
    });

    final barGroups = last7Days.asMap().entries.map((entry) {
      final day = entry.value;
      final sevenDaysAgo = day.subtract(const Duration(days: 7));
      final activeCount = stats.recentUsers.where((user) {
        if (user.lastLoginAt == null) return false;
        final loginDay = DateTime(
          user.lastLoginAt!.year,
          user.lastLoginAt!.month,
          user.lastLoginAt!.day,
        );
        return loginDay.isAtSameMomentAs(day) ||
            (loginDay.isAfter(sevenDaysAgo) && loginDay.isBefore(day));
      }).length;

      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: activeCount.toDouble(),
            gradient: AdminTheme.primaryGradient,
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: stats.totalUsers.toDouble(), // Max possible
              color: Colors.white.withOpacity(0.05),
            ),
          ),
        ],
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminTheme.glassDecoration(
        color: AdminTheme.surface,
        opacity: 0.6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily Active Users', style: AdminTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Engagement over last 7 days', style: AdminTheme.bodyMedium),
          const SizedBox(height: 32),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < last7Days.length) {
                          final day = last7Days[value.toInt()];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('E').format(day),
                              style: AdminTheme.bodyMedium,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentUsersList(BuildContext context, AdminDashboardStats stats) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Users', style: AdminTheme.titleLarge),
              TextButton(
                onPressed: () {}, // TODO: Navigate to users list
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (stats.recentUsers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('No users found', style: AdminTheme.bodyMedium),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stats.recentUsers.take(5).length,
              separatorBuilder: (context, index) => Divider(
                height: 24,
                color: Colors.white.withOpacity(0.05),
              ),
              itemBuilder: (context, index) {
                final user = stats.recentUsers[index];
                final now = DateTime.now();
                final sevenDaysAgo = now.subtract(const Duration(days: 7));
                final isActive = user.lastLoginAt != null &&
                    user.lastLoginAt!.isAfter(sevenDaysAgo);

                return InkWell(
                  onTap: () {
                    context.push(
                      '/admin/users/${user.uid}',
                      extra: {'userName': user.displayName ?? user.email ?? 'Unknown'},
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: isActive
                              ? AdminTheme.primaryGradient
                              : AdminTheme.surfaceGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          (user.displayName?.isNotEmpty ?? false)
                              ? user.displayName![0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName ?? user.email ?? 'Unknown',
                              style: AdminTheme.bodyLarge.copyWith(
                                color: AdminTheme.textWhite,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              user.createdAt != null
                                  ? DateFormat('MMM d, yyyy').format(user.createdAt!)
                                  : '-',
                              style: AdminTheme.bodyMedium.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AdminTheme.success.withOpacity(0.1)
                              : AdminTheme.surfaceHighlight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isActive
                                ? AdminTheme.success.withOpacity(0.3)
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? AdminTheme.success
                                : AdminTheme.textDisabled,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
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
        Text(label, style: AdminTheme.bodyMedium),
      ],
    );
  }
}
