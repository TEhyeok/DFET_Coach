import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../theme/text_styles.dart';

/// 고단백 식품 다이얼로그
class ProteinFoodsDialog extends StatelessWidget {
  const ProteinFoodsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('💪', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('고단백 식품 가이드', style: AppTextStyles.h2),
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
            const Text(
              '단백질이 풍부한 식품들이에요. 탭하면 식사에 추가할 수 있어요!',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildFoodItem(
                      context,
                      icon: '🍗',
                      name: '닭가슴살',
                      amount: '100g',
                      protein: 23,
                      calories: 165,
                    ),
                    _buildFoodItem(
                      context,
                      icon: '🥚',
                      name: '삶은 달걀',
                      amount: '2개',
                      protein: 12,
                      calories: 140,
                    ),
                    _buildFoodItem(
                      context,
                      icon: '🥛',
                      name: '그릭요거트',
                      amount: '1컵 (170g)',
                      protein: 15,
                      calories: 130,
                    ),
                    _buildFoodItem(
                      context,
                      icon: '🐟',
                      name: '연어',
                      amount: '100g',
                      protein: 20,
                      calories: 206,
                    ),
                    _buildFoodItem(
                      context,
                      icon: '🍖',
                      name: '소고기',
                      amount: '100g',
                      protein: 26,
                      calories: 250,
                    ),
                    _buildFoodItem(
                      context,
                      icon: '🥜',
                      name: '아몬드',
                      amount: '28g (한 줌)',
                      protein: 6,
                      calories: 164,
                    ),
                    _buildFoodItem(
                      context,
                      icon: '🧀',
                      name: '두부',
                      amount: '1/2모 (150g)',
                      protein: 10,
                      calories: 94,
                    ),
                    _buildFoodItem(
                      context,
                      icon: '🥫',
                      name: '참치 캔',
                      amount: '1캔 (100g)',
                      protein: 25,
                      calories: 116,
                    ),
                    _buildFoodItem(
                      context,
                      icon: '🥤',
                      name: '프로틴 쉐이크',
                      amount: '1스쿱 (30g)',
                      protein: 24,
                      calories: 120,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  // 식사 탭으로 이동 신호
                  Navigator.pop(context, 'add_meal');
                },
                child: const Text('식사 기록하러 가기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodItem(
    BuildContext context, {
    required String icon,
    required String name,
    required String amount,
    required int protein,
    required int calories,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.bgApp,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgStroke),
      ),
      child: ListTile(
        leading: Text(icon, style: const TextStyle(fontSize: 32)),
        title: Text(name, style: AppTextStyles.bodyLarge),
        subtitle: Text(amount, style: AppTextStyles.caption),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${protein}g',
              style: AppTextStyles.h3.copyWith(color: AppColors.brandPrimary),
            ),
            Text(
              '${calories}kcal',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        onTap: () {
          Navigator.pop(context);
          // 해당 식품으로 식사 추가 다이얼로그 열기 신호
          Navigator.pop(context, {
            'action': 'add_meal',
            'food': {
              'name': name,
              'protein': protein,
              'calories': calories,
            },
          });
        },
      ),
    );
  }
}
