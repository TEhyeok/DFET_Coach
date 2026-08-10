import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../design_system/d_fet_evidence.dart';
import '../../models/clinical_reports.dart';
import '../../state/clinical_state.dart';
import '../../theme/tokens.dart';
import 'components/action_recommendation_card.dart';
import 'components/health_timeline.dart';
import 'components/integrated_score_card.dart';
import 'components/progress_efficacy_card.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(healthSnapshotsProvider).when(
          data: (snapshots) => snapshots.isEmpty
              ? const _InsightsEmpty()
              : _InsightsHub(snapshots: snapshots),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const _InsightsEmpty(
            message: '통합 인사이트를 불러오지 못했습니다',
          ),
        );
  }
}

class _InsightsHub extends StatelessWidget {
  const _InsightsHub({required this.snapshots});

  final List<HealthSnapshot> snapshots;

  @override
  Widget build(BuildContext context) {
    final latest = snapshots.first;
    final previous = snapshots.length > 1 ? snapshots[1] : null;
    final actions = latest.insights.where((insight) => insight.action != null);
    final primaryAction = actions.isEmpty ? null : actions.first;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        DfetReportHeader(
          axis: null,
          eyebrow: 'HEALTH SNAPSHOT · 4 AXES',
          title: '나의 건강 변화',
          subtitle:
              '${DateFormat('yyyy.MM.dd').format(latest.asOf)} 기준 · 좋아진 흐름과 오늘의 한 가지를 확인하세요.',
        ),
        const SizedBox(height: 16),
        ProgressEfficacyCard(
          current: latest,
          previous: previous,
          onTap: () => context.push('/insights/${latest.snapshotId}'),
        ),
        if (primaryAction != null) ...[
          const SizedBox(height: 20),
          _sectionTitle(context, '오늘 이어갈 한 가지'),
          const SizedBox(height: 10),
          ActionRecommendationCard(insight: primaryAction),
        ],
        const SizedBox(height: 20),
        _sectionTitle(context, '현재 4축 균형'),
        const SizedBox(height: 10),
        IntegratedScoreCard(
          snapshot: latest,
          onTap: () => context.push('/insights/${latest.snapshotId}'),
        ),
        const SizedBox(height: 12),
        DfetEvidenceRibbon(
          source: '4축 HealthSnapshot',
          coverage: '완성도 ${(latest.completeness * 100).round()}%',
          policyVersion: latest.policyVersion,
          tone: latest.missingAxes.isNotEmpty || latest.policyVersion == null
              ? DfetEvidenceTone.pending
              : DfetEvidenceTone.neutral,
          detail: latest.missingAxes.isEmpty
              ? '운동·식단·장·혈액 데이터를 같은 기준시점으로 묶었습니다. 축간 흐름은 연관 가능성으로만 표현하며 인과관계나 의료 진단을 의미하지 않습니다.'
              : '누락 축 ${latest.missingAxes.map(_axisLabel).join(', ')}은 임의 보간하지 않았습니다. 완성도와 누락 상태를 유지한 채 승인된 정책에서 계산 가능한 정보만 표시합니다.',
        ),
        const SizedBox(height: 20),
        Text(
          '건강 타임라인',
          style: TextStyle(
            color: context.wellness.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        HealthTimeline(snapshots: snapshots),
      ],
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

  static String _axisLabel(String axis) => switch (axis) {
        'fitness' => '운동',
        'diet' => '식단',
        'gut' => '장',
        'blood' => '혈액',
        _ => axis,
      };
}

class _InsightsEmpty extends StatelessWidget {
  const _InsightsEmpty({this.message = '아직 생성된 통합 스냅샷이 없습니다'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hub_outlined,
              size: 54,
              color: context.wellness.textTertiary,
            ),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              '축이 부족한 경우 값을 임의 보간하지 않고 누락 축을 표시합니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.wellness.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
