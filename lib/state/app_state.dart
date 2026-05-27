import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';

// Export sub-states
export 'auth_state.dart';
export 'user_state.dart';
export 'meal_state.dart';
export 'workout_state.dart';
export 'pose_state.dart';
export 'onboarding_state.dart';
export 'date_state.dart';

import 'meal_state.dart';
import 'workout_state.dart';

// === App Global State Providers ===

/// 현재 선택된 탭 인덱스 (iOS: 0=홈, 1=기록, 2=코칭, 3=커뮤니티, 4=내 정보)
final currentTabIndexProvider = StateProvider<int>((ref) => 0);

/// Wellness Score - 식단과 운동 데이터를 기반으로 동적 계산
final wellnessScoreProvider = Provider<int>((ref) {
  final totalCalories = ref.watch(totalCaloriesProvider);
  final totalProtein = ref.watch(totalProteinProvider);
  final totalWorkoutTime = ref.watch(totalWorkoutTimeProvider);

  // 데이터가 없으면 0점
  if (totalCalories == 0 && totalProtein == 0 && totalWorkoutTime == 0) {
    return 0;
  }

  // 점수 계산 (100점 만점)
  int score = 50; // 기본 점수

  // 칼로리 점수 (목표: 2000kcal, 최대 30점)
  final calorieScore = ((totalCalories / 2000) * 30).clamp(0, 30).toInt();
  score += calorieScore;

  // 단백질 점수 (목표: 100g, 최대 20점)
  final proteinScore = ((totalProtein / 100) * 20).clamp(0, 20).toInt();
  score += proteinScore;

  // 운동 시간 점수 (목표: 60분, 최대 30점)
  final workoutScore = ((totalWorkoutTime / 60) * 30).clamp(0, 30).toInt();
  score += workoutScore;

  // 과도한 칼로리는 감점
  if (totalCalories > 2500) {
    score -= 10;
  }

  return score.clamp(0, 100);
});

// Firestore Service Provider
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});
