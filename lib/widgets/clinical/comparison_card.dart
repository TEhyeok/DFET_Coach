import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

class ComparisonCard extends StatelessWidget {
  const ComparisonCard({
    super.key,
    required this.title,
    required this.value,
    required this.label,
    this.icon = Icons.compare_arrows_rounded,
  });

  final String title;
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.wellness.bgCard,
        borderRadius: WellnessRadius.card,
        border: Border.all(color: context.wellness.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.wellness.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: context.wellness.textSecondary, fontSize: 12)),
                const SizedBox(height: 3),
                Text(value,
                    style: TextStyle(
                        color: context.wellness.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Flexible(
            child: Text(label,
                textAlign: TextAlign.end,
                style: TextStyle(
                    color: context.wellness.primaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
