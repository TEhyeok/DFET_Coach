import '../models/workout_metadata.dart';
import '../core/utils/app_logger.dart';

/// 코칭 상관관계 분석 서비스
/// 특허 핵심 기술: 운동 메타데이터 → 영양 처방 연동
class CoachingCorrelationService {
  /// 운동 기록 기반 영양 처방 생성
  /// [workoutLogs]: 오늘 수행한 운동 목록
  /// [currentNutrition]: 현재까지 섭취한 영양소
  static NutritionPrescription generateNutritionPlan({
    required List<WorkoutMetadata> workoutLogs,
    required DailyNutrition currentNutrition,
  }) {
    if (workoutLogs.isEmpty) {
      return NutritionPrescription.standard();
    }

    // 1. 오늘의 총 운동 강도 점수 계산
    final intensityScore = _calculateTotalIntensity(workoutLogs);

    // 2. 주요 운동 타입 분석
    final primaryExercise = _getPrimaryExerciseType(workoutLogs);

    // 3. 상관관계 기반 영양 처방 결정
    final prescription = _correlateToNutrition(
      intensityScore: intensityScore,
      primaryExercise: primaryExercise,
      currentNutrition: currentNutrition,
    );

    AppLogger.info(
        '[CorrelationService] 처방 생성: $primaryExercise (강도: $intensityScore) → ${prescription.type}');

    return prescription;
  }

  /// 총 운동 강도 점수 계산
  static double _calculateTotalIntensity(List<WorkoutMetadata> logs) {
    double total = 0;
    for (final log in logs) {
      final baseScore = switch (log.intensity) {
        ExerciseIntensity.high => 3.0,
        ExerciseIntensity.medium => 2.0,
        ExerciseIntensity.low => 1.0,
      };
      // 시간 가중치 (30분 기준)
      final timeWeight = (log.durationSeconds / 1800).clamp(0.5, 2.0);
      total += baseScore * timeWeight;
    }
    return total;
  }

  /// 주요 운동 타입 결정 (가장 오래 수행한 운동)
  static String _getPrimaryExerciseType(List<WorkoutMetadata> logs) {
    if (logs.isEmpty) return 'NONE';

    final sorted = [...logs]
      ..sort((a, b) => b.durationSeconds.compareTo(a.durationSeconds));
    return sorted.first.exerciseType;
  }

  /// 상관관계 분석 → 영양 처방
  static NutritionPrescription _correlateToNutrition({
    required double intensityScore,
    required String primaryExercise,
    required DailyNutrition currentNutrition,
  }) {
    // 대근육 + 고강도 운동
    final isLargeMusclework = ['SQUAT', 'DEADLIFT', 'BENCH', 'ROW']
        .contains(primaryExercise.toUpperCase());

    // 유산소/유연성 운동
    final isCardioOrFlexibility = ['YOGA', 'PILATES', 'RUNNING', 'CYCLING']
        .contains(primaryExercise.toUpperCase());

    // 결정 매트릭스
    if (isLargeMusclework && intensityScore >= 4.0) {
      // 고강도 대근육 → 탄수화물 우선 회복
      return NutritionPrescription(
        type: PrescriptionType.highCarb,
        carbsAdjustment: 50, // +50g
        proteinAdjustment: 20, // +20g
        message: '하체/대근육 고강도 운동 완료! 글리코겐 회복을 위해 현미밥이나 파스타를 드세요.',
        recommendedFoods: ['현미밥', '파스타', '감자', '바나나'],
      );
    } else if (isLargeMusclework && intensityScore >= 2.0) {
      // 중강도 대근육 → 균형 회복
      return NutritionPrescription(
        type: PrescriptionType.balanced,
        carbsAdjustment: 30,
        proteinAdjustment: 30,
        message: '근력 운동 수행 완료! 근육 합성을 위해 단백질과 탄수화물을 함께 섭취하세요.',
        recommendedFoods: ['닭가슴살 덮밥', '연어 샐러드', '두부 스테이크'],
      );
    } else if (isCardioOrFlexibility) {
      // 유산소/유연성 → 가벼운 식사
      return NutritionPrescription(
        type: PrescriptionType.light,
        carbsAdjustment: 0,
        proteinAdjustment: 10,
        message: '가벼운 운동 후에는 소화가 편한 식사가 좋아요. 샐러드나 가벼운 포케를 추천해요.',
        recommendedFoods: ['샐러드', '포케', '그릭요거트', '과일'],
      );
    } else {
      // 기본
      return NutritionPrescription.standard();
    }
  }

  /// 식단 수행 여부 확인 (역방향 피드백)
  static bool isRecoveryMealCompleted({
    required NutritionPrescription prescription,
    required DailyNutrition actualIntake,
  }) {
    switch (prescription.type) {
      case PrescriptionType.highCarb:
        return actualIntake.carbs >=
            (actualIntake.targetCarbs + prescription.carbsAdjustment * 0.7);
      case PrescriptionType.highProtein:
        return actualIntake.protein >=
            (actualIntake.targetProtein + prescription.proteinAdjustment * 0.7);
      case PrescriptionType.balanced:
      case PrescriptionType.light:
      case PrescriptionType.standard:
        return true; // 특별한 조건 없음
    }
  }
}

/// 영양 처방 결과
class NutritionPrescription {
  final PrescriptionType type;
  final int carbsAdjustment;
  final int proteinAdjustment;
  final String message;
  final List<String> recommendedFoods;

  NutritionPrescription({
    required this.type,
    required this.carbsAdjustment,
    required this.proteinAdjustment,
    required this.message,
    required this.recommendedFoods,
  });

  factory NutritionPrescription.standard() {
    return NutritionPrescription(
      type: PrescriptionType.standard,
      carbsAdjustment: 0,
      proteinAdjustment: 0,
      message: '오늘도 균형 잡힌 식사를 챙겨주세요!',
      recommendedFoods: [],
    );
  }
}

enum PrescriptionType {
  highCarb, // 고탄수 (글리코겐 회복)
  highProtein, // 고단백 (근합성)
  balanced, // 균형
  light, // 가벼운 식사
  standard, // 기본
}

/// 일일 영양 섭취 현황 (for correlation)
class DailyNutrition {
  final int carbs;
  final int protein;
  final int fat;
  final int calories;
  final int targetCarbs;
  final int targetProtein;

  DailyNutrition({
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.calories,
    this.targetCarbs = 300,
    this.targetProtein = 100,
  });
}
