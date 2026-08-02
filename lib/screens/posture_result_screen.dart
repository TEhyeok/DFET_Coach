import 'package:flutter/material.dart';
import '../services/video_pose_analyzer.dart';
import '../services/pose_detection_service.dart';
import '../theme/tokens.dart';
import '../theme/text_styles.dart';

class PostureResultScreen extends StatelessWidget {
  final VideoAnalysisResult result;
  final VoidCallback? onRetry;
  final VoidCallback? onClose;

  const PostureResultScreen({
    super.key,
    required this.result,
    this.onRetry,
    this.onClose,
  });

  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.orange;
    if (score >= 60) return Colors.amber;
    return Colors.red;
  }

  String _getScoreGrade(double score) {
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }

  String _getExerciseName() {
    switch (result.exerciseType) {
      case ExerciseType.squat:
        return '스쿼트';
      case ExerciseType.pushup:
        return '푸시업';
      case ExerciseType.plank:
        return '플랭크';
      default:
        return '운동';
    }
  }

  IconData _getExerciseIcon() {
    switch (result.exerciseType) {
      case ExerciseType.squat:
        return Icons.fitness_center;
      case ExerciseType.pushup:
        return Icons.sports_gymnastics;
      case ExerciseType.plank:
        return Icons.self_improvement;
      default:
        return Icons.sports;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final scoreColor = _getScoreColor(result.averageScore);
    final circleSize = screenSize.width * 0.32;
    final scoreFontSize = screenSize.width * 0.12;

    return Scaffold(
      backgroundColor: AppColors.bgRoot,
      appBar: AppBar(
        title: const Text('자세 평가 결과'),
        backgroundColor: AppColors.bgCard,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onClose,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Score Section (35% of space)
              Flexible(
                flex: 35,
                child:
                    _buildScoreSection(scoreColor, circleSize, scoreFontSize),
              ),

              const SizedBox(height: 12),

              // Analysis Info (10% of space)
              Flexible(
                flex: 10,
                child: _buildAnalysisInfo(),
              ),

              const SizedBox(height: 12),

              // Feedback Section (35% of space)
              Flexible(
                flex: 35,
                child: _buildFeedbackSection(),
              ),

              const SizedBox(height: 12),

              // Action Buttons (20% of space)
              Flexible(
                flex: 20,
                child: _buildActionButtons(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreSection(
      Color scoreColor, double circleSize, double fontSize) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scoreColor, width: 2),
      ),
      child: Row(
        children: [
          // Score Circle
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: scoreColor, width: 6),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    result.averageScore.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                  Text(
                    '점',
                    style: TextStyle(
                      fontSize: fontSize * 0.35,
                      color: scoreColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Exercise Info & Grade
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getExerciseIcon(),
                      size: 24,
                      color: scoreColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getExerciseName(),
                      style: AppTextStyles.h3,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '등급 ${_getScoreGrade(result.averageScore)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildCompactInfoItem(
            Icons.videocam,
            '분석 프레임',
            '${result.analyzedFrames}/${result.totalFrames}',
          ),
          Container(
            width: 1,
            height: 30,
            color: AppColors.bgStroke,
          ),
          _buildCompactInfoItem(
            Icons.check_circle,
            '감지율',
            '${((result.analyzedFrames / result.totalFrames) * 100).toStringAsFixed(0)}%',
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfoItem(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.brandPrimary, size: 20),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSubtle,
                fontSize: 11,
              ),
            ),
            Text(
              value,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeedbackSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: AppColors.accentGold,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '피드백',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                result.feedback,
                style: AppTextStyles.bodySmall.copyWith(
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (result.averageScore < 80) ...[
            const Divider(height: 16),
            _buildCollapsibleTips(),
          ],
        ],
      ),
    );
  }

  Widget _buildCollapsibleTips() {
    return Theme(
      data: ThemeData(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Row(
          children: [
            Icon(
              Icons.tips_and_updates,
              color: AppColors.info,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              '개선 팁 보기',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.info,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        children: _getImprovementTips()
            .take(3)
            .map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $tip',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.info,
                      fontSize: 12,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('다시 촬영'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: AppColors.brandPrimary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: onClose,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('완료'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<String> _getImprovementTips() {
    switch (result.exerciseType) {
      case ExerciseType.squat:
        return [
          '발을 어깨 너비로 벌리고 발끝은 바깥쪽으로',
          '무릎이 발끝을 넘지 않도록 주의',
          '허벅지가 바닥과 평행이 될 때까지',
          '등을 곧게 펴고 정면을 바라보기',
        ];
      case ExerciseType.pushup:
        return [
          '손을 어깨 너비보다 약간 넓게',
          '몸을 일직선으로 유지',
          '팔꿈치를 90도까지 구부리기',
          '코어에 힘을 주어 허리가 처지지 않도록',
        ];
      case ExerciseType.plank:
        return [
          '팔꿈치를 어깨 바로 아래에 위치',
          '몸을 일직선으로 유지',
          '엉덩이가 너무 높거나 낮지 않도록',
          '코어에 힘을 주고 규칙적으로 호흡',
        ];
      default:
        return ['올바른 자세로 운동하세요'];
    }
  }
}
