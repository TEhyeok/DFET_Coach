import 'package:flutter/material.dart';
import '../../models/clinical_reports.dart';
import '../../theme/tokens.dart';
import '../app_card.dart';

class GutHealthSummaryCard extends StatelessWidget {
  const GutHealthSummaryCard({
    super.key,
    required this.report,
    required this.onTap,
  });

  final GutReport? report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: report == null ? context.wellness.bgSubtle : null,
              border: Border.all(
                color: report == null
                    ? context.wellness.border
                    : context.wellness.energy,
                width: report == null ? 2 : 5,
              ),
            ),
            child: report == null
                ? Icon(Icons.eco_rounded, color: context.wellness.textTertiary)
                : Text(
                    report!.overall.score?.round().toString() ?? '--',
                    style: TextStyle(
                      color: context.wellness.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report == null ? '장 건강 리포트 없음' : '오늘의 장 건강',
                  style: TextStyle(
                    color: context.wellness.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  report == null ? '검사 진행하기' : report!.overall.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: context.wellness.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: context.wellness.textTertiary),
        ],
      ),
    );
  }
}
