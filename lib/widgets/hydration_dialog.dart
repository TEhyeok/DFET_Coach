import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../theme/text_styles.dart';

/// 수분 섭취 기록 다이얼로그
class HydrationDialog extends StatefulWidget {
  const HydrationDialog({super.key});

  @override
  State<HydrationDialog> createState() => _HydrationDialogState();
}

class _HydrationDialogState extends State<HydrationDialog> {
  int waterIntake = 0; // ml 단위
  final int dailyGoal = 2000; // 2L = 2000ml

  void _addWater(int amount) {
    setState(() {
      waterIntake += amount;
      if (waterIntake > dailyGoal) waterIntake = dailyGoal;
    });
  }

  void _reset() {
    setState(() {
      waterIntake = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = (waterIntake / dailyGoal).clamp(0.0, 1.0);

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
                const Text('💧', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('수분 섭취', style: AppTextStyles.h2),
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
              '오늘 마신 물의 양을 기록해보세요',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 24),

            // 진행률 표시
            Center(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 12,
                          backgroundColor: AppColors.bgStroke,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress >= 1.0 ? AppColors.brandPrimary : AppColors.info,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(waterIntake / 1000).toStringAsFixed(1)}L',
                            style: AppTextStyles.number.copyWith(fontSize: 28),
                          ),
                          Text(
                            '/ ${(dailyGoal / 1000).toStringAsFixed(1)}L',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(progress * 100).toInt()}% 달성',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: progress >= 1.0 ? AppColors.brandPrimary : AppColors.textSubtle,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 빠른 추가 버튼
            const Text('빠른 추가', style: AppTextStyles.bodySmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildQuickAddButton('한 컵', 200),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildQuickAddButton('물병', 500),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildQuickAddButton('1L', 1000),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 리셋 및 완료 버튼
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    child: const Text('초기화'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () {
                      // TODO: 실제로 수분 섭취 데이터 저장
                      Navigator.pop(context, waterIntake);
                    },
                    child: const Text('저장'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAddButton(String label, int amount) {
    return OutlinedButton(
      onPressed: () => _addWater(amount),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall,
          ),
          Text(
            '${amount}ml',
            style: AppTextStyles.caption.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}
