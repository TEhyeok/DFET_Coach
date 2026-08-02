import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/clinical_reports.dart';
import '../../state/clinical_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_card.dart';
import '../../widgets/clinical/comparison_card.dart';
import 'components/action_recommendation_card.dart';
import 'components/axis_radar_chart.dart';
import 'components/cross_insight_card.dart';
import 'components/integrated_score_card.dart';

class InsightDetailScreen extends ConsumerWidget {
  const InsightDetailScreen({super.key, required this.snapshotId});

  final String snapshotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(healthSnapshotProvider(snapshotId)).when(
          data: (snapshot) {
            if (snapshot == null) {
              return const Center(child: Text('스냅샷을 찾을 수 없습니다'));
            }
            final snapshots = ref.watch(healthSnapshotsProvider).valueOrNull ??
                const [];
            final currentIndex = snapshots.indexWhere(
              (item) => item.snapshotId == snapshot.snapshotId,
            );
            final previous = currentIndex >= 0 && currentIndex + 1 < snapshots.length
                ? snapshots[currentIndex + 1]
                : null;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Text(
                  '통합 건강 상세',
                  style: TextStyle(
                    color: context.wellness.textPrimary,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('yyyy.MM.dd').format(snapshot.asOf)} 기준 · 정책 ${snapshot.policyVersion ?? '미승인'}',
                  style: TextStyle(
                    color: context.wellness.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                IntegratedScoreCard(snapshot: snapshot),
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
                  child: AxisRadarChart(axes: snapshot.axes),
                ),
                if (previous != null) ...[
                  const SizedBox(height: 18),
                  _SnapshotComparison(current: snapshot, previous: previous),
                ],
                if (snapshot.insights.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    '축간 인사이트',
                    style: TextStyle(
                      color: context.wellness.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final insight in snapshot.insights) ...[
                    CrossInsightCard(insight: insight),
                    if (insight.action != null) ...[
                      const SizedBox(height: 8),
                      ActionRecommendationCard(insight: insight),
                    ],
                    const SizedBox(height: 10),
                  ],
                ],
                Text(
                  '인사이트는 인과관계를 확정하지 않으며 건강관리 참고용입니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.wellness.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('스냅샷을 불러오지 못했습니다')),
        );
  }
}

class _SnapshotComparison extends StatelessWidget {
  const _SnapshotComparison({required this.current, required this.previous});

  final HealthSnapshot current;
  final HealthSnapshot previous;

  static const _labels = {
    'fitness': '운동',
    'diet': '식단',
    'gut': '장',
    'blood': '혈액',
  };

  @override
  Widget build(BuildContext context) {
    final comparisons = <({String title, double before, double after})>[];
    if (current.overallScore != null && previous.overallScore != null) {
      comparisons.add((
        title: '통합 점수',
        before: previous.overallScore!,
        after: current.overallScore!,
      ));
    }
    for (final entry in _labels.entries) {
      final before = previous.axes[entry.key];
      final after = current.axes[entry.key];
      if (before != null && after != null) {
        comparisons.add((title: '${entry.value} 축', before: before, after: after));
      }
    }
    if (comparisons.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '이전 스냅샷 대비',
          style: TextStyle(
            color: context.wellness.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${DateFormat('yyyy.MM.dd').format(previous.asOf)} → ${DateFormat('yyyy.MM.dd').format(current.asOf)}',
          style: TextStyle(color: context.wellness.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        for (final comparison in comparisons) ...[
          ComparisonCard(
            title: comparison.title,
            value: '${comparison.before.toStringAsFixed(1)} → ${comparison.after.toStringAsFixed(1)}',
            label: _deltaLabel(comparison.after - comparison.before),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          '전후 변화는 동일 정책 기준의 참고 비교이며 개입의 인과효과를 의미하지 않습니다.',
          style: TextStyle(color: context.wellness.textTertiary, fontSize: 11),
        ),
      ],
    );
  }

  String _deltaLabel(double delta) {
    if (delta.abs() < 0.05) return '변화 없음';
    return '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)}';
  }
}
