import 'package:flutter/material.dart';

/// 스마트 추천 우선순위
enum RecommendationPriority {
  critical, // 긴급 (빨강)
  warning, // 경고 (주황)
  improve, // 개선 (노랑)
  good, // 양호 (초록)
  excellent, // 완벽 (파랑)
}

/// 스마트 추천 카테고리
enum RecommendationCategory {
  protein, // 단백질
  calories, // 칼로리
  exercise, // 운동
  hydration, // 수분
  motivation, // 동기부여
  achievement, // 성취
  advice, // 일반 조언
  sleep, // 수면
}

/// 스마트 추천 모델
class SmartRecommendation {
  final String icon;
  final String title;
  final String message;
  final String actionLabel;
  final RecommendationPriority priority;
  final RecommendationCategory category;
  final Color? accentColor;
  final int? progressValue;
  final int? progressGoal;

  const SmartRecommendation({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.priority,
    required this.category,
    this.accentColor,
    this.progressValue,
    this.progressGoal,
  });

  /// 우선순위별 색상
  Color get priorityColor {
    switch (priority) {
      case RecommendationPriority.critical:
        return const Color(0xFFEF4444); // 빨강
      case RecommendationPriority.warning:
        return const Color(0xFFF97316); // 주황
      case RecommendationPriority.improve:
        return const Color(0xFFF59E0B); // 노랑
      case RecommendationPriority.good:
        return const Color(0xFF10B981); // 초록
      case RecommendationPriority.excellent:
        return const Color(0xFF3B82F6); // 파랑
    }
  }

  /// 우선순위 점수 (높을수록 우선순위 높음)
  int get priorityScore {
    switch (priority) {
      case RecommendationPriority.critical:
        return 5;
      case RecommendationPriority.warning:
        return 4;
      case RecommendationPriority.improve:
        return 3;
      case RecommendationPriority.good:
        return 2;
      case RecommendationPriority.excellent:
        return 1;
    }
  }
}
