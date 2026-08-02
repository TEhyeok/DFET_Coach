import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workout_metadata.dart';
import '../models/workout.dart';
import 'workout_state.dart';

/// 오늘의 운동 기록을 WorkoutMetadata 형태로 변환하여 제공
/// CoachingCorrelationService에서 사용
final todayWorkoutMetadataProvider = Provider<List<WorkoutMetadata>>((ref) {
  final workouts = ref.watch(workoutsProvider);

  return workouts.map((workout) {
    // Workout 모델을 WorkoutMetadata로 변환
    final intensity = _determineIntensity(workout);
    final exerciseType = _normalizeExerciseType(workout.name);

    return WorkoutMetadata(
      id: workout.id,
      exerciseType: exerciseType,
      intensity: intensity,
      durationSeconds: workout.duration * 60, // minutes to seconds
      repCount: workout.sets.fold(0, (sum, set) => sum + set.reps),
      timestamp: workout.timestamp,
    );
  }).toList();
});

/// 운동 강도 결정 (sets/reps 기반)
ExerciseIntensity _determineIntensity(Workout workout) {
  if (workout.category == 'cardio') {
    // 유산소: 시간 기준
    if (workout.duration >= 45) return ExerciseIntensity.high;
    if (workout.duration >= 20) return ExerciseIntensity.medium;
    return ExerciseIntensity.low;
  } else {
    // 웨이트: 세트 수 기준
    final totalSets = workout.sets.length;
    if (totalSets >= 4) return ExerciseIntensity.high;
    if (totalSets >= 2) return ExerciseIntensity.medium;
    return ExerciseIntensity.low;
  }
}

/// 운동 이름 정규화 (영어 대문자로)
String _normalizeExerciseType(String name) {
  final lowerName = name.toLowerCase();

  if (lowerName.contains('스쿼트') || lowerName.contains('squat')) {
    return 'SQUAT';
  }
  if (lowerName.contains('푸시업') ||
      lowerName.contains('pushup') ||
      lowerName.contains('press')) {
    return 'BENCH';
  }
  if (lowerName.contains('데드') || lowerName.contains('dead')) {
    return 'DEADLIFT';
  }
  if (lowerName.contains('로우') || lowerName.contains('row')) return 'ROW';
  if (lowerName.contains('런') ||
      lowerName.contains('run') ||
      lowerName.contains('조깅')) {
    return 'RUNNING';
  }
  if (lowerName.contains('사이클') ||
      lowerName.contains('cycle') ||
      lowerName.contains('자전거')) {
    return 'CYCLING';
  }
  if (lowerName.contains('요가') || lowerName.contains('yoga')) return 'YOGA';
  if (lowerName.contains('필라테스') || lowerName.contains('pilates')) {
    return 'PILATES';
  }

  return name.toUpperCase();
}
