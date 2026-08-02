import 'package:flutter/material.dart';

import '../../../models/clinical_reports.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/app_card.dart';

class CrossInsightCard extends StatelessWidget {
  const CrossInsightCard({super.key, required this.insight});

  final HealthInsight insight;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.wellness.primarySubtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.hub_outlined,
              color: context.wellness.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(
                    color: context.wellness.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  insight.body,
                  style: TextStyle(
                    color: context.wellness.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '축간 관계는 연관 가능성으로만 해석합니다.',
                  style: TextStyle(
                    color: context.wellness.textTertiary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
