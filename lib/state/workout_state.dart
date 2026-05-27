import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workout.dart';
import '../services/firestore_service.dart';
import '../services/mock_data_service.dart';
import '../core/utils/app_logger.dart';
import 'app_state.dart'; // For firestoreServiceProvider

// Workouts State Notifier
class WorkoutsNotifier extends StateNotifier<List<Workout>> {
  final FirestoreService _firestoreService;
  final String? _uid;
  final String _date;

  WorkoutsNotifier(this._firestoreService, this._uid, this._date) : super([]) {
    _loadWorkouts();
  }

  /// Firestore에서 운동 데이터 로드
  Future<void> _loadWorkouts() async {
    // 게스트 모드거나 uid가 없으면 빈 상태로 시작 (오늘 데이터 없음)
    if (_uid == null || _uid == 'guest') {
      AppLogger.info('[WorkoutsNotifier] 게스트 모드 - 예시 데이터 로드');
      state = _date == Workout.todayString
          ? MockDataService.getMockWorkouts()
          : <Workout>[];
      return;
    }

    try {
      AppLogger.debug(
          '[WorkoutsNotifier] Firestore에서 운동 로드 중... (uid: $_uid, date: $_date)');
      final workouts = await _firestoreService.loadWorkoutsByDate(_uid!, _date);

      // Firestore 데이터 그대로 사용 (빈 리스트도 그대로 유지)
      state = workouts;

      if (workouts.isEmpty) {
        AppLogger.info('[WorkoutsNotifier] 신규 계정 - 빈 상태로 시작');
      } else {
        AppLogger.info(
            '[WorkoutsNotifier] Firestore에서 ${workouts.length}개 운동 로드 완료');
      }
    } catch (e, stackTrace) {
      AppLogger.error('[WorkoutsNotifier] 운동 로드 실패', e, stackTrace);
      // 로드 실패 시 빈 상태로 시작
      state = [];
    }
  }

  Future<void> addWorkout(Workout workout) async {
    try {
      final workoutForDate = workout.copyWith(date: _date);

      // 로컬 상태 업데이트
      state = [...state, workoutForDate];

      // 게스트가 아닌 경우만 Firestore에 저장
      if (_uid != null && _uid != 'guest') {
        await _firestoreService.addWorkout(workoutForDate, _uid!);
        AppLogger.info('[WorkoutsNotifier] 운동 추가 완료: ${workoutForDate.name}');
      } else {
        AppLogger.info(
            '[WorkoutsNotifier] 게스트 모드 - 로컬에만 저장: ${workoutForDate.name}');
      }
    } catch (e, stackTrace) {
      AppLogger.error('[WorkoutsNotifier] 운동 추가 실패 - 로컬만 유지', e, stackTrace);
    }
  }

  Future<void> deleteWorkout(String id) async {
    try {
      // 로컬 상태 업데이트
      state = state.where((workout) => workout.id != id).toList();

      // 게스트가 아닌 경우만 Firestore에서 삭제
      if (_uid != null && _uid != 'guest') {
        await _firestoreService.deleteWorkout(id, _uid!);
        AppLogger.info('[WorkoutsNotifier] 운동 삭제 완료: $id');
      } else {
        AppLogger.info('[WorkoutsNotifier] 게스트 모드 - 로컬에서만 삭제: $id');
      }
    } catch (e, stackTrace) {
      AppLogger.error('[WorkoutsNotifier] 운동 삭제 실패 - 로컬만 유지', e, stackTrace);
    }
  }
}

final workoutsProvider =
    StateNotifierProvider.autoDispose<WorkoutsNotifier, List<Workout>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final uid = ref.watch(currentUidProvider);
  final selectedDate = ref.watch(selectedDateStringProvider);
  return WorkoutsNotifier(firestoreService, uid, selectedDate);
});

final totalWorkoutTimeProvider = Provider<int>((ref) {
  final workouts = ref.watch(workoutsProvider);
  return workouts.fold(0, (sum, workout) {
    if (workout.category == 'cardio') {
      return sum + workout.duration;
    } else {
      return sum + (workout.sets.length * 3); // Estimate 3 min per set
    }
  });
});
