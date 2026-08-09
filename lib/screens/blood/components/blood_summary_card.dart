import 'package:flutter/material.dart';

import '../../../design_system/d_fet_axis_glyph.dart';
import '../../../design_system/d_fet_axis_icon.dart';
import '../../../models/clinical_reports.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/clinical/score_gauge.dart';

class BloodSummaryCard extends StatelessWidget {
  const BloodSummaryCard({super.key, required this.report, this.onTap});

  final BloodReport report;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          ScoreGauge(
              score: report.overall.score,
              label: report.overall.label,
              size: 112),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const DfetAxisAssetIcon(
                      axis: DfetAxis.blood,
                      size: 22,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '혈액 생화학 요약',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.wellness.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${report.biomarkers.length}/13 항목 수신',
                    style: TextStyle(
                        color: context.wellness.textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  report.reviewCount > 0
                      ? '검토 필요 ${report.reviewCount}개'
                      : report.overall.label,
                  style: TextStyle(
                    color: report.reviewCount > 0
                        ? context.wellness.warning
                        : context.wellness.primaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded,
                color: context.wellness.textTertiary),
        ],
      ),
    );
  }
}
