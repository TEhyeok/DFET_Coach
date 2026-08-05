import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        Text(
          '나의 건강 변화',
          style: TextStyle(
            color: context.wellness.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '좋아진 흐름을 확인하고 오늘 할 수 있는 한 가지를 이어가세요.',
          style: TextStyle(color: context.wellness.textSecondary, fontSize: 12),
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
