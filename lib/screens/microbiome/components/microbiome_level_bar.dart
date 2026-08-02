import 'package:flutter/material.dart';
import '../../../theme/tokens.dart';

/// 3단계 레벨 바 (낮음/평균/높음) — Soft Wellness 스타일.
/// dfet_final 의 HMELevelBar 를 이식 — 그라데이션 제거, 솔리드 색상 사용.
class MicrobiomeLevelBar extends StatelessWidget {
  final String label;
  final String level;

  const MicrobiomeLevelBar({
    super.key,
    required this.label,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final levelColor = _getLevelColor(context, level);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: context.wellness.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  level,
                  style: TextStyle(
                    color: levelColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildSegment(context, 0, level)),
              const SizedBox(width: 6),
              Expanded(child: _buildSegment(context, 1, level)),
              const SizedBox(width: 6),
              Expanded(child: _buildSegment(context, 2, level)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegment(BuildContext context, int index, String currentLevel) {
    final bool isActive = _isSegmentActive(index, currentLevel);
    final Color color = _getSegmentBaseColor(context, index);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? color : context.wellness.borderSubtle,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Color _getSegmentBaseColor(BuildContext context, int index) {
    if (index == 0) return context.wellness.danger;
    if (index == 1) return context.wellness.warning;
    return context.wellness.primary;
  }

  bool _isSegmentActive(int index, String currentLevel) {
    if (_isLow(currentLevel)) return index == 0;
    if (_isAvg(currentLevel)) return index == 1;
    if (_isHigh(currentLevel)) return index == 2;
    return false;
  }

  bool _isLow(String level) =>
      level.contains('낮음') ||
      level.contains('부족') ||
      level.contains('주의') ||
      level.contains('위험');
  bool _isAvg(String level) =>
      level.contains('평균') || level.contains('보통') || level.contains('적정');
  bool _isHigh(String level) =>
      level.contains('높음') ||
      level.contains('과다') ||
      level.contains('좋음') ||
      level.contains('우수') ||
      level.contains('안전');

  Color _getLevelColor(BuildContext context, String level) {
    if (_isLow(level)) return context.wellness.danger;
    if (_isAvg(level)) return context.wellness.warning;
    if (_isHigh(level)) return context.wellness.primary;
    return context.wellness.textTertiary;
  }
}
