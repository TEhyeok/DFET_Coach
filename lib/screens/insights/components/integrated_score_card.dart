import 'package:flutter/material.dart';

import '../../../models/clinical_reports.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/clinical/score_gauge.dart';

class IntegratedScoreCard extends StatelessWidget {
  const IntegratedScoreCard({
    super.key,
    required this.snapshot,
    this.onTap,
  });

  final HealthSnapshot snapshot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          ScoreGauge(
            score: snapshot.overallScore,
            label: snapshot.label,
            size: 112,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '4축 통합 건강',
                  style: TextStyle(
                    color: context.wellness.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '데이터 완성도 ${(snapshot.completeness * 100).round()}%',
                  style: TextStyle(
                    color: context.wellness.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 7),
                LinearProgressIndicator(
                  value: snapshot.completeness,
                  minHeight: 6,
                  borderRadius: WellnessRadius.chip,
                  color: context.wellness.primary,
                  backgroundColor: context.wellness.bgSubtle,
                ),
                if (snapshot.missingAxes.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    '누락: ${snapshot.missingAxes.map(_axisLabel).join(', ')}',
                    style: TextStyle(
                      color: context.wellness.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final axis in const [
                      'fitness',
                      'diet',
                      'gut',
                      'blood',
                    ])
                      if (snapshot.axes[axis] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: context.wellness.bgSubtle,
                            borderRadius: WellnessRadius.chip,
                          ),
                          child: Text(
                            '${_axisLabel(axis)} ${snapshot.axes[axis]!.round()}',
                            style: TextStyle(
                              color: context.wellness.textSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                  ],
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
