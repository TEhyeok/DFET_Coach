import '../models/smart_recommendation.dart';

/// 스마트 코치 서비스 - 개인화된 건강 조언 제공
class SmartCoachService {
  /// 날짜 기반 시드 (매일 다른 메시지 표시용)
  static int _getDailySeed() {
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day;
  }

  /// 메인 추천 가져오기
  static SmartRecommendation getRecommendation({
    required int protein,
    required int calories,
    required int workoutTime,
    required int mealsCount,
    required int wellnessScore,
  }) {
    final recommendations = <SmartRecommendation>[];
    final hour = DateTime.now().hour;
    final weekday = DateTime.now().weekday; // 1=월, 7=일

    // 1. 긴급 상황 체크
    recommendations.addAll(_getCriticalRecommendations(
      calories: calories,
      workoutTime: workoutTime,
      protein: protein,
    ));

    // 2. 경고 상황 체크
    recommendations.addAll(_getWarningRecommendations(
      protein: protein,
      calories: calories,
      mealsCount: mealsCount,
    ));

    // 3. 개선 필요 체크
    recommendations.addAll(_getImprovementRecommendations(
      protein: protein,
      workoutTime: workoutTime,
      hour: hour,
    ));

    // 4. 성취 메시지
    recommendations.addAll(_getAchievementRecommendations(
      wellnessScore: wellnessScore,
      protein: protein,
      workoutTime: workoutTime,
    ));

    // 5. 요일별 동기부여
    recommendations.addAll(_getMotivationalRecommendations(
      weekday: weekday,
      hour: hour,
    ));

    // 우선순위별 정렬 후 최상위 반환
    recommendations.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

    // 같은 우선순위라면 날짜 기반으로 로테이션
    if (recommendations.isNotEmpty) {
      final topPriority = recommendations.first.priorityScore;
      final topRecommendations =
          recommendations.where((r) => r.priorityScore == topPriority).toList();

      if (topRecommendations.length > 1) {
        final seed = _getDailySeed();
        final index = seed % topRecommendations.length;
        return topRecommendations[index];
      }

      return recommendations.first;
    }

    // 기본 메시지
    return _getDefaultRecommendation(hour);
  }

  /// 긴급 추천 (빨강)
  static List<SmartRecommendation> _getCriticalRecommendations({
    required int calories,
    required int workoutTime,
    required int protein,
  }) {
    final recommendations = <SmartRecommendation>[];

    // 칼로리 과다 섭취
    if (calories > 2500) {
      recommendations.add(SmartRecommendation(
        icon: '⚠️',
        title: '칼로리 주의',
        message:
            '오늘 목표보다 ${calories - 2000}kcal 높아요.\n내일은 가벼운 샐러드로 시작해보는 건 어떨까요?',
        actionLabel: '건강 식단 보기',
        priority: RecommendationPriority.critical,
        category: RecommendationCategory.calories,
        progressValue: calories,
        progressGoal: 2000,
      ));
    }

    // 운동 전혀 안 함
    if (workoutTime == 0 && DateTime.now().hour >= 18) {
      final messages = [
        '오늘 아직 운동을 안 하셨네요!\n10분만 걸어도 좋아요. 지금 시작해볼까요?',
        '하루가 거의 끝나가요.\n가벼운 스트레칭이라도 어떨까요?',
        '몸이 움직임을 기다리고 있어요.\n계단 오르기 5분은 어때요?',
      ];
      final seed = _getDailySeed();
      final message = messages[seed % messages.length];

      recommendations.add(SmartRecommendation(
        icon: '🏃',
        title: '운동 시작하기',
        message: message,
        actionLabel: '운동 기록하기',
        priority: RecommendationPriority.critical,
        category: RecommendationCategory.exercise,
      ));
    }

    return recommendations;
  }

  /// 경고 추천 (주황)
  static List<SmartRecommendation> _getWarningRecommendations({
    required int protein,
    required int calories,
    required int mealsCount,
  }) {
    final recommendations = <SmartRecommendation>[];

    // 심각한 단백질 부족
    if (protein < 60) {
      final deficit = 100 - protein;
      final messages = [
        '단백질이 ${deficit}g 부족해요!\n삶은 달걀 2개면 12g을 채울 수 있어요.',
        '근육 유지를 위해 단백질이 필요해요.\n닭가슴살 샐러드 어떠세요?',
        '단백질 부족이 심각해요.\n그릭요거트 한 컵으로 15g 채우기!',
      ];
      final seed = _getDailySeed();
      final message = messages[seed % messages.length];

      recommendations.add(SmartRecommendation(
        icon: '🥩',
        title: '단백질 보충 필요',
        message: message,
        actionLabel: '단백질 식품 보기',
        priority: RecommendationPriority.warning,
        category: RecommendationCategory.protein,
        progressValue: protein,
        progressGoal: 100,
      ));
    }

    // 칼로리 부족
    if (calories < 1500 && DateTime.now().hour >= 18) {
      recommendations.add(SmartRecommendation(
        icon: '🍽️',
        title: '에너지 부족',
        message: '오늘 ${2000 - calories}kcal 부족해요.\n영양가 있는 저녁 식사로 채워보세요!',
        actionLabel: '식단 추천 보기',
        priority: RecommendationPriority.warning,
        category: RecommendationCategory.calories,
      ));
    }

    // 식사 횟수 부족
    if (mealsCount == 0 && DateTime.now().hour >= 14) {
      recommendations.add(SmartRecommendation(
        icon: '😰',
        title: '식사 건너뛰지 마세요',
        message: '오늘 아직 기록된 식사가 없어요.\n규칙적인 식사가 건강의 기본이에요!',
        actionLabel: '식사 기록하기',
        priority: RecommendationPriority.warning,
        category: RecommendationCategory.calories,
      ));
    }

    return recommendations;
  }

  /// 개선 추천 (노랑)
  static List<SmartRecommendation> _getImprovementRecommendations({
    required int protein,
    required int workoutTime,
    required int hour,
  }) {
    final recommendations = <SmartRecommendation>[];

    // 단백질 부족 (중간)
    if (protein >= 60 && protein < 100) {
      final deficit = 100 - protein;

      if (hour < 12) {
        final messages = [
          '아침에 단백질 ${deficit}g 더 필요해요.\n달걀 프라이 2개로 12g 채우기!',
          '모닝 프로틴 타임!\n그릭요거트 한 컵이면 15g 완성.',
          '아침 단백질이 조금 부족해요.\n연어 한 토막으로 20g 보충!',
        ];
        final seed = _getDailySeed();
        recommendations.add(SmartRecommendation(
          icon: '🥚',
          title: '아침 단백질 보충',
          message: messages[seed % messages.length],
          actionLabel: '아침 메뉴 보기',
          priority: RecommendationPriority.improve,
          category: RecommendationCategory.protein,
          progressValue: protein,
          progressGoal: 100,
        ));
      } else if (hour < 18) {
        final messages = [
          '오후 간식으로 프로틴바 어때요?\n20g을 한 번에 채울 수 있어요.',
          '점심에 단백질을 더 추가해보세요.\n두부 한 모면 10g이에요.',
          '간식 시간! 견과류 한 줌이면\n단백질 6g + 건강한 지방까지!',
        ];
        final seed = _getDailySeed();
        recommendations.add(SmartRecommendation(
          icon: '🥜',
          title: '간식으로 단백질',
          message: messages[seed % messages.length],
          actionLabel: '간식 추천 보기',
          priority: RecommendationPriority.improve,
          category: RecommendationCategory.protein,
        ));
      } else {
        final messages = [
          '저녁 식사에 단백질을 추가하세요.\n닭가슴살 100g이면 23g이에요!',
          '오늘 마지막 기회예요.\n생선구이 한 토막으로 20g 완성!',
          '저녁에 두부 요리 어때요?\n부드럽고 단백질도 풍부해요.',
        ];
        final seed = _getDailySeed();
        recommendations.add(SmartRecommendation(
          icon: '🍗',
          title: '저녁 단백질',
          message: messages[seed % messages.length],
          actionLabel: '저녁 메뉴 보기',
          priority: RecommendationPriority.improve,
          category: RecommendationCategory.protein,
        ));
      }
    }

    // 운동 부족
    if (workoutTime > 0 && workoutTime < 30) {
      final messages = [
        '$workoutTime분 운동했어요! 좋아요!\n20분만 더 하면 목표 달성이에요.',
        '시작이 반이에요! 이미 $workoutTime분 했으니\n조금만 더 힘내볼까요?',
        '$workoutTime분도 대단해요.\n가벼운 걷기 20분으로 마무리해요!',
      ];
      final seed = _getDailySeed();
      recommendations.add(SmartRecommendation(
        icon: '💪',
        title: '조금만 더!',
        message: messages[seed % messages.length],
        actionLabel: '운동 추가하기',
        priority: RecommendationPriority.improve,
        category: RecommendationCategory.exercise,
        progressValue: workoutTime,
        progressGoal: 60,
      ));
    }

    return recommendations;
  }

  /// 성취 메시지 (초록, 파랑)
  static List<SmartRecommendation> _getAchievementRecommendations({
    required int wellnessScore,
    required int protein,
    required int workoutTime,
  }) {
    final recommendations = <SmartRecommendation>[];

    // 완벽한 하루
    if (wellnessScore >= 90 && protein >= 100 && workoutTime >= 60) {
      final messages = [
        '오늘 완벽해요! 🎉\n영양, 운동 모두 달성했어요. 자랑스러워요!',
        '프로 운동선수 같은 하루네요!\n이 페이스를 꾸준히 유지해봐요.',
        '건강 마스터! 🏆\n오늘의 당신은 1등입니다!',
      ];
      final seed = _getDailySeed();
      recommendations.add(SmartRecommendation(
        icon: '🌟',
        title: '완벽한 하루!',
        message: messages[seed % messages.length],
        actionLabel: '리포트 보기',
        priority: RecommendationPriority.excellent,
        category: RecommendationCategory.achievement,
      ));
    }
    // 양호한 진행
    else if (wellnessScore >= 70) {
      final messages = [
        '잘하고 있어요! 웰니스 $wellnessScore점!\n이 페이스면 목표 달성이 가까워요.',
        '순조로운 하루네요.\n꾸준함이 결국 승리해요!',
        '$wellnessScore점! 훌륭해요.\n조금만 더 노력하면 완벽해요!',
      ];
      final seed = _getDailySeed();
      recommendations.add(SmartRecommendation(
        icon: '👍',
        title: '순조로워요',
        message: messages[seed % messages.length],
        actionLabel: '진행 상황 보기',
        priority: RecommendationPriority.good,
        category: RecommendationCategory.achievement,
      ));
    }

    return recommendations;
  }

  /// 동기부여 메시지
  static List<SmartRecommendation> _getMotivationalRecommendations({
    required int weekday,
    required int hour,
  }) {
    final recommendations = <SmartRecommendation>[];

    // 요일별 메시지
    switch (weekday) {
      case 1: // 월요일
        if (hour < 12) {
          recommendations.add(SmartRecommendation(
            icon: '🔥',
            title: '새로운 한 주!',
            message: '월요일은 새로운 시작이에요.\n가벼운 스트레칭으로 몸을 깨워보세요!',
            actionLabel: '오늘의 목표 보기',
            priority: RecommendationPriority.good,
            category: RecommendationCategory.motivation,
          ));
        }
        break;
      case 3: // 수요일
        recommendations.add(SmartRecommendation(
          icon: '⚡',
          title: '중간 점검!',
          message: '이번 주 중간이에요.\n지금까지 잘하고 있나요? 확인해봐요!',
          actionLabel: '주간 리포트',
          priority: RecommendationPriority.good,
          category: RecommendationCategory.motivation,
        ));
        break;
      case 5: // 금요일
        if (hour >= 18) {
          recommendations.add(SmartRecommendation(
            icon: '🎊',
            title: '금요일 저녁!',
            message: '한 주 수고했어요!\n하지만 건강 습관은 계속 이어가요.',
            actionLabel: '주말 계획 보기',
            priority: RecommendationPriority.good,
            category: RecommendationCategory.motivation,
          ));
        }
        break;
      case 7: // 일요일
        if (hour >= 18) {
          recommendations.add(SmartRecommendation(
            icon: '📝',
            title: '주말 마무리',
            message: '내일부터 새로운 한 주!\n오늘 준비를 잘 해두세요.',
            actionLabel: '이번 주 돌아보기',
            priority: RecommendationPriority.good,
            category: RecommendationCategory.motivation,
          ));
        }
        break;
    }

    return recommendations;
  }

  /// 기본 추천 메시지
  static SmartRecommendation _getDefaultRecommendation(int hour) {
    final messages = [
      SmartRecommendation(
        icon: '💧',
        title: '수분 섭취',
        message: '물은 충분히 마시고 계신가요?\n하루 2L가 목표예요!',
        actionLabel: '수분 기록하기',
        priority: RecommendationPriority.improve,
        category: RecommendationCategory.hydration,
      ),
      SmartRecommendation(
        icon: '🌙',
        title: '휴식도 중요해요',
        message: '오늘 밤 7-8시간 숙면하셨나요?\n충분한 수면이 회복의 핵심이에요!',
        actionLabel: '수면 팁 보기',
        priority: RecommendationPriority.improve,
        category: RecommendationCategory.sleep,
      ),
      SmartRecommendation(
        icon: '🧘',
        title: '스트레스 관리',
        message: '5분 명상으로 마음을 정리해보세요.\n몸만큼 마음도 중요해요!',
        actionLabel: '명상 시작하기',
        priority: RecommendationPriority.improve,
        category: RecommendationCategory.advice,
      ),
    ];

    final seed = _getDailySeed();
    return messages[seed % messages.length];
  }
}
