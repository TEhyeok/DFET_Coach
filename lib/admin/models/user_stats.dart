import '../../models/meal.dart';
import '../../models/workout.dart';

/// 사용자 통계 데이터
class UserStats {
  final String uid;
  final String email;
  final String displayName;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  // 통계 데이터
  final int totalMeals;
  final int totalWorkouts;
  final int totalAiTokens; // 총 AI 토큰 사용량
  final List<Meal> recentMeals; // 최근 식사 목록 (토큰 사용량 확인용)
  final Map<String, DailyStats> dailyStats; // 날짜별 통계
  final NutritionSummary nutritionSummary;
  final WorkoutSummary workoutSummary;

  UserStats({
    required this.uid,
    required this.email,
    required this.displayName,
    this.createdAt,
    this.lastLoginAt,
    this.totalMeals = 0,
    this.totalWorkouts = 0,
    this.totalAiTokens = 0,
    this.recentMeals = const [],
    this.dailyStats = const {},
    required this.nutritionSummary,
    required this.workoutSummary,
  });

  /// 활성 사용자 여부 (최근 7일 이내 활동)
  bool get isActive {
    if (lastLoginAt == null) return false;
    final now = DateTime.now();
    final diff = now.difference(lastLoginAt!);
    return diff.inDays <= 7;
  }

  /// 최근 활동일 (일 단위)
  int? get daysSinceLastLogin {
    if (lastLoginAt == null) return null;
    final now = DateTime.now();
    return now.difference(lastLoginAt!).inDays;
  }
}

/// 일별 통계
class DailyStats {
  final String date; // yyyy-MM-dd
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int workoutTime; // 분 단위

  DailyStats({
    required this.date,
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.workoutTime = 0,
  });

  /// 웰니스 점수 계산 (0-100)
  int get wellnessScore {
    int score = 50;

    // 칼로리 (최대 30점)
    score += ((calories / 2000) * 30).clamp(0, 30).toInt();

    // 단백질 (최대 20점)
    score += ((protein / 100) * 20).clamp(0, 20).toInt();

    // 운동 시간 (최대 30점)
    score += ((workoutTime / 60) * 30).clamp(0, 30).toInt();

    // 과다 칼로리 페널티
    if (calories > 2500) score -= 10;

    return score.clamp(0, 100);
  }
}

/// 영양 요약
class NutritionSummary {
  final int totalCalories;
  final int totalProtein;
  final int totalCarbs;
  final int totalFat;
  final double avgCaloriesPerDay;
  final double avgProteinPerDay;

  NutritionSummary({
    this.totalCalories = 0,
    this.totalProtein = 0,
    this.totalCarbs = 0,
    this.totalFat = 0,
    this.avgCaloriesPerDay = 0,
    this.avgProteinPerDay = 0,
  });

  factory NutritionSummary.fromMeals(List<Meal> meals, int days) {
    final totalCalories = meals.fold<int>(0, (sum, m) => sum + m.calories);
    final totalProtein = meals.fold<int>(0, (sum, m) => sum + m.protein);
    final totalCarbs = meals.fold<int>(0, (sum, m) => sum + m.carbs);
    final totalFat = meals.fold<int>(0, (sum, m) => sum + m.fat);

    return NutritionSummary(
      totalCalories: totalCalories,
      totalProtein: totalProtein,
      totalCarbs: totalCarbs,
      totalFat: totalFat,
      avgCaloriesPerDay: days > 0 ? totalCalories / days : 0,
      avgProteinPerDay: days > 0 ? totalProtein / days : 0,
    );
  }
}

/// 운동 요약
class WorkoutSummary {
  final int totalWorkouts;
  final int totalSets;
  final int totalCardioMinutes;
  final double avgWorkoutsPerWeek;
  final Map<String, int> exerciseFrequency; // 운동별 빈도

  WorkoutSummary({
    this.totalWorkouts = 0,
    this.totalSets = 0,
    this.totalCardioMinutes = 0,
    this.avgWorkoutsPerWeek = 0,
    this.exerciseFrequency = const {},
  });

  factory WorkoutSummary.fromWorkouts(List<Workout> workouts, int days) {
    final totalWorkouts = workouts.length;
    int totalSets = 0;
    int totalCardioMinutes = 0;
    final Map<String, int> exerciseFrequency = {};

    for (final workout in workouts) {
      if (workout.category == 'strength') {
        totalSets += workout.sets.length;
      } else if (workout.category == 'cardio') {
        totalCardioMinutes += workout.duration;
      }

      // 운동 이름별 빈도
      exerciseFrequency[workout.name] =
          (exerciseFrequency[workout.name] ?? 0) + 1;
    }

    final weeks = days / 7;

    return WorkoutSummary(
      totalWorkouts: totalWorkouts,
      totalSets: totalSets,
      totalCardioMinutes: totalCardioMinutes,
      avgWorkoutsPerWeek: weeks > 0 ? totalWorkouts / weeks : 0,
      exerciseFrequency: exerciseFrequency,
    );
  }
}
