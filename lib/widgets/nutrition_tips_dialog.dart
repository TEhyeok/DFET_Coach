import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../theme/text_styles.dart';

/// 영양 조언 다이얼로그
class NutritionTipsDialog extends StatelessWidget {
  const NutritionTipsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.wellness.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🥗', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('건강한 식습관 팁', style: AppTextStyles.h2),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTipCard(
                      context,
                      icon: '🍳',
                      title: '아침 식사는 필수',
                      description:
                          '하루의 시작은 균형 잡힌 아침 식사로! 단백질과 복합 탄수화물을 함께 섭취하세요.',
                    ),
                    _buildTipCard(
                      context,
                      icon: '🥤',
                      title: '충분한 수분 섭취',
                      description:
                          '하루 2L 이상의 물을 마시세요. 식사 30분 전에 물 한 잔을 마시면 포만감에 도움이 됩니다.',
                    ),
                    _buildTipCard(
                      context,
                      icon: '🥦',
                      title: '채소를 많이',
                      description:
                          '매 끼니 접시의 절반은 채소로 채우세요. 다양한 색깔의 채소를 먹으면 좋아요.',
                    ),
                    _buildTipCard(
                      context,
                      icon: '🍚',
                      title: '통곡물 선택',
                      description:
                          '흰쌀밥 대신 현미, 귀리, 퀴노아 등 통곡물을 선택하세요. 식이섬유가 풍부합니다.',
                    ),
                    _buildTipCard(
                      context,
                      icon: '⏰',
                      title: '규칙적인 식사 시간',
                      description: '가능한 매일 같은 시간에 식사하세요. 신진대사 안정화에 도움이 됩니다.',
                    ),
                    _buildTipCard(
                      context,
                      icon: '🍕',
                      title: '80/20 원칙',
                      description: '80%는 건강한 식사, 20%는 좋아하는 음식. 완벽하지 않아도 괜찮아요!',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard(
    BuildContext context, {
    required String icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.wellness.bgRoot,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.wellness.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyLarge),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: context.wellness.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
