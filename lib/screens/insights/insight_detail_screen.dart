import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../design_system/d_fet_evidence.dart';
import '../../models/clinical_reports.dart';
import '../../state/clinical_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_card.dart';
import '../../widgets/clinical/comparison_card.dart';
import 'components/action_recommendation_card.dart';
import 'components/axis_radar_chart.dart';
import 'components/cross_insight_card.dart';
import 'components/integrated_score_card.dart';
import 'components/progress_efficacy_card.dart';

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
            final snapshots =
                ref.watch(healthSnapshotsProvider).valueOrNull ?? const [];
            final currentIndex = snapshots.indexWhere(
              (item) => item.snapshotId == snapshot.snapshotId,
            );
            final previous =
                currentIndex >= 0 && currentIndex + 1 < snapshots.length
                    ? snapshots[currentIndex + 1]
                    : null;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                DfetReportHeader(
                  axis: null,
                  eyebrow: 'INTEGRATED · DETAIL',
                  title: '통합 건강 상세',
                  subtitle:
                      '${DateFormat('yyyy.MM.dd').format(snapshot.asOf)} 기준 · 완성도 ${(snapshot.completeness * 100).round()}%',
                ),
                const SizedBox(height: 16),
                ProgressEfficacyCard(
                  current: snapshot,
                  previous: previous,
                ),
                const SizedBox(height: 20),
                _sectionTitle(context, '현재 4축 균형'),
                const SizedBox(height: 10),
                IntegratedScoreCard(snapshot: snapshot),
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
                  child: AxisRadarChart(axes: snapshot.axes),
                ),
                if (snapshot.insights.any((item) => item.action != null)) ...[
                  const SizedBox(height: 20),
                  _sectionTitle(context, '오늘의 실천'),
                  const SizedBox(height: 4),
                  Text(
                    '부담 없는 한 가지부터 완료해 보세요.',
                    style: TextStyle(
                      color: context.wellness.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final insight in snapshot.insights
                      .where((item) => item.action != null)) ...[
                    ActionRecommendationCard(insight: insight),
                    const SizedBox(height: 10),
                  ],
                ],
                if (previous != null) ...[
                  const SizedBox(height: 10),
                  _SnapshotComparison(current: snapshot, previous: previous),
                ],
                if (snapshot.insights.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _sectionTitle(context, '데이터에서 발견한 흐름'),
                  const SizedBox(height: 10),
                  for (final insight in snapshot.insights) ...[
                    CrossInsightCard(insight: insight),
                    const SizedBox(height: 10),
                  ],
                ],
                const SizedBox(height: 8),
                DfetEvidenceRibbon(
                  source: '4축 HealthSnapshot',
                  coverage: '완성도 ${(snapshot.completeness * 100).round()}%',
                  policyVersion: snapshot.policyVersion,
                  tone: snapshot.missingAxes.isNotEmpty ||
                          snapshot.policyVersion == null
                      ? DfetEvidenceTone.pending
                      : DfetEvidenceTone.neutral,
                  detail: snapshot.missingAxes.isEmpty
                      ? '운동·식단·장·혈액 데이터를 같은 기준시점으로 묶었습니다. 축간 관계는 연관 가능성으로만 제공하며 인과관계나 의료 진단을 의미하지 않습니다.'
                      : '누락 축 ${snapshot.missingAxes.map(_SnapshotComparison.axisLabel).join(', ')}은 임의 보간하지 않았습니다. 정책 버전과 완성도를 함께 저장해 당시 결과를 재현합니다.',
                ),
                const SizedBox(height: 14),
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

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        color: context.wellness.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
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

  static String axisLabel(String axis) => _labels[axis] ?? axis;

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
        comparisons
            .add((title: '${entry.value} 축', before: before, after: after));
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
            value:
                '${comparison.before.toStringAsFixed(1)} → ${comparison.after.toStringAsFixed(1)}',
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
