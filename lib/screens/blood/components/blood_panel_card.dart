import 'package:flutter/material.dart';
import '../../../models/clinical_reports.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/app_card.dart';

class BloodPanelCard extends StatelessWidget {
  const BloodPanelCard({
    super.key,
    required this.panel,
    required this.summary,
    this.onTap,
  });

  final String panel;
  final BloodPanelSummary summary;
  final VoidCallback? onTap;

  static const labels = {
    'liver': '간 기능',
    'kidney': '신장 기능',
    'metabolic': '대사·혈당',
    'lipid': '지질',
  };

  static const icons = {
    'liver': Icons.health_and_safety_outlined,
    'kidney': Icons.water_drop_outlined,
    'metabolic': Icons.monitor_heart_outlined,
    'lipid': Icons.insights_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icons[panel] ?? Icons.science_outlined,
                  size: 20, color: context.wellness.primary),
              const Spacer(),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: summary.score == null
                      ? context.wellness.textTertiary
                      : context.wellness.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(labels[panel] ?? panel,
              style: TextStyle(
                color: context.wellness.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 4),
          Text(summary.score?.round().toString() ?? '산정 준비 중',
              style: TextStyle(
                  color: context.wellness.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: summary.completeness,
            minHeight: 5,
            borderRadius: WellnessRadius.chip,
            color: context.wellness.primary,
            backgroundColor: context.wellness.bgSubtle,
          ),
        ],
      ),
    );
  }
}
