import 'package:flutter/material.dart';

import '../../../models/clinical_reports.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/app_card.dart';

class ActionRecommendationCard extends StatelessWidget {
  const ActionRecommendationCard({super.key, required this.insight});

  final HealthInsight insight;

  @override
  Widget build(BuildContext context) {
    final action = insight.action;
    if (action == null) return const SizedBox.shrink();
    final title = action['title']?.toString() ?? '생활관리 제안';
    final description = action['description']?.toString() ?? '';
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.task_alt_rounded, color: context.wellness.accent),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.wellness.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: TextStyle(
                      color: context.wellness.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
