import 'package:flutter/material.dart';
import '../../../theme/tokens.dart';

/// 카테고리 카드 (Soft Wellness 스타일)
/// dfet_final 의 HMECategoryCard 를 이식 — 화이트 카드 + 큰 라운드 + 부드러운 그림자.
class MicrobiomeCategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;
  final VoidCallback? onTap;

  const MicrobiomeCategoryCard({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.wellness.bgCard,
          borderRadius: WellnessRadius.cardLarge,
          boxShadow: WellnessShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: context.wellness.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
