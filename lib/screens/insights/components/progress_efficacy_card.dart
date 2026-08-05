import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/clinical_reports.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/app_card.dart';

class ProgressEfficacyCard extends StatelessWidget {
  const ProgressEfficacyCard({
    super.key,
    required this.current,
    this.previous,
    this.onTap,
  });

  final HealthSnapshot current;
  final HealthSnapshot? previous;
  final VoidCallback? onTap;

  static const _axisLabels = {
    'fitness': '운동',
    'diet': '식단',
    'gut': '장',
    'blood': '혈액',
  };

  @override
  Widget build(BuildContext context) {
    final changes = _axisChanges();
    final improvedCount = changes.where((item) => item.delta > 0.05).length;
    final overallDelta =
        previous?.overallScore != null && current.overallScore != null
            ? current.overallScore! - previous!.overallScore!
            : null;
    final isPositive = overallDelta != null && overallDelta > 0.05;
    final accent = isPositive
        ? context.wellness.success
        : overallDelta == null
            ? context.wellness.info
            : context.wellness.warning;

    return Semantics(
      button: onTap != null,
      label: _semanticLabel(overallDelta, improvedCount, changes.length),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isPositive
                        ? Icons.trending_up_rounded
                        : Icons.insights_rounded,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        previous == null ? '나의 기준점' : '지난 검사 이후 변화',
                        style: TextStyle(
                          color: context.wellness.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _headline(overallDelta),
                        style: TextStyle(
                          color: context.wellness.textPrimary,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.wellness.textTertiary,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: context.wellness.bgSubtle,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _progressMessage(improvedCount, changes.length),
                    style: TextStyle(
                      color: context.wellness.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    previous == null
                        ? '다음 검사부터 같은 정책 기준으로 변화를 비교해 드려요.'
                        : '기록한 생활 루틴과 좋은 변화가 함께 관찰되고 있어요.',
                    style: TextStyle(
                      color: context.wellness.textSecondary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (changes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final change in changes)
                    _AxisDeltaChip(
                      label: change.label,
                      delta: change.delta,
                    ),
                ],
              ),
            ],
            if (previous != null) ...[
              const SizedBox(height: 12),
              Text(
                '${DateFormat('yyyy.MM.dd').format(previous!.asOf)} → '
                '${DateFormat('yyyy.MM.dd').format(current.asOf)} · 동일 정책 기준',
                style: TextStyle(
                  color: context.wellness.textTertiary,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<({String label, double delta})> _axisChanges() {
    if (previous == null) return const [];
    final changes = <({String label, double delta})>[];
    for (final entry in _axisLabels.entries) {
      final before = previous!.axes[entry.key];
      final after = current.axes[entry.key];
      if (before != null && after != null) {
        changes.add((label: entry.value, delta: after - before));
      }
    }
    return changes;
  }

  String _headline(double? delta) {
    if (previous == null) return '통합 기준점이 생겼어요';
    if (delta == null) return '비교 가능한 점수를 준비 중이에요';
    if (delta.abs() < 0.05) return '균형을 안정적으로 유지했어요';
    return '통합 건강 ${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)}';
  }

  String _progressMessage(int improvedCount, int totalCount) {
    if (previous == null) return '오늘부터 변화가 쌓이기 시작해요';
    if (totalCount > 0 && improvedCount == totalCount) {
      return '$totalCount개 축 모두 상승 흐름이에요';
    }
    if (improvedCount > 0) return '$totalCount개 축 중 $improvedCount개가 좋아졌어요';
    return '현재 흐름을 확인하고 다음 행동을 조정해 보세요';
  }

  String _semanticLabel(double? delta, int improvedCount, int totalCount) {
    final change = delta == null
        ? '통합 점수 비교 준비 중'
        : '통합 점수 변화 ${delta.toStringAsFixed(1)}';
    return '$change, $totalCount개 축 중 $improvedCount개 상승';
  }
}

class _AxisDeltaChip extends StatelessWidget {
  const _AxisDeltaChip({required this.label, required this.delta});

  final String label;
  final double delta;

  @override
  Widget build(BuildContext context) {
    final isPositive = delta > 0.05;
    final isNeutral = delta.abs() <= 0.05;
    final color = isNeutral
        ? context.wellness.textSecondary
        : isPositive
            ? context.wellness.success
            : context.wellness.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: WellnessRadius.chip,
      ),
      child: Text(
        '$label ${delta > 0 ? '+' : ''}${delta.toStringAsFixed(0)}',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
