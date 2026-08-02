import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/admin_service.dart';

import '../../theme/admin_theme.dart';

final analyticsProvider = FutureProvider<AnalyticsStats>((ref) async {
  final adminService = AdminService();
  return await adminService.getAnalyticsData();
});

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(analyticsProvider);

    return analyticsAsync.when(
      data: (stats) => _buildContent(context, stats),
      loading: () => const Center(
          child: CircularProgressIndicator(color: AdminTheme.primary)),
      error: (error, stack) => Center(
        child: Text('Failed to load analytics: $error',
            style: AdminTheme.bodyLarge.copyWith(color: AdminTheme.error)),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AnalyticsStats stats) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Analytics Overview', style: AdminTheme.displayMedium),
          const SizedBox(height: 8),
          Text('Deep dive into your app performance.',
              style: AdminTheme.bodyLarge),
          const SizedBox(height: 32),

          // Charts Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 1000;
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildChartCard(
                          title: 'User Growth',
                          subtitle: 'Cumulative users over last 30 days',
                          child: _buildLineChart(
                              stats.userGrowth, AdminTheme.primary),
                        ),
                      ),
                      if (isWide) ...[
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildChartCard(
                            title: 'Daily Active Users (DAU)',
                            subtitle: 'Unique logins per day',
                            child:
                                _buildBarChart(stats.dau, AdminTheme.success),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (!isWide) ...[
                    const SizedBox(height: 24),
                    _buildChartCard(
                      title: 'Daily Active Users (DAU)',
                      subtitle: 'Unique logins per day',
                      child: _buildBarChart(stats.dau, AdminTheme.success),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _buildChartCard(
                    title: 'Revenue Trends (Mock)',
                    subtitle: 'Estimated revenue based on subscriptions',
                    child: _buildLineChart(stats.revenue, AdminTheme.accent,
                        isCurved: true, showArea: true),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(
      {required String title,
      required String subtitle,
      required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminTheme.glassDecoration(
        color: AdminTheme.surface,
        opacity: 0.6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AdminTheme.titleLarge),
          const SizedBox(height: 4),
          Text(subtitle, style: AdminTheme.bodyMedium),
          const SizedBox(height: 32),
          SizedBox(height: 300, child: child),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<FlSpot> spots, Color color,
      {bool isCurved = true, bool showArea = true}) {
    if (spots.isEmpty) return const Center(child: Text('No Data'));

    double minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    double maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    double interval = (maxY - minY) / 5;
    if (interval == 0) interval = 10;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: interval,
              getTitlesWidget: (value, meta) => Text(
                NumberFormat.compact().format(value),
                style: AdminTheme.bodyMedium.copyWith(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 5 * 86400000, // ~5 days
              getTitlesWidget: (value, meta) {
                final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(DateFormat('MM/dd').format(date),
                      style: AdminTheme.bodyMedium.copyWith(fontSize: 10)),
                );
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: isCurved,
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: showArea,
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.3),
                  color.withValues(alpha: 0.0)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(List<FlSpot> spots, Color color) {
    if (spots.isEmpty) return const Center(child: Text('No Data'));

    double maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    double interval = maxY / 5;
    if (interval == 0) interval = 10;

    return BarChart(
      BarChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                // Show every 5th label to avoid crowding
                if (value.toInt() % 5 != 0) return const SizedBox.shrink();
                final date = DateTime.fromMillisecondsSinceEpoch(
                    spots[value.toInt()].x.toInt());
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(DateFormat('MM/dd').format(date),
                      style: AdminTheme.bodyMedium.copyWith(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: spots.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.y,
                color: color,
                width: 12,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
