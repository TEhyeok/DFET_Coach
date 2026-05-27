import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meal.dart';
import '../services/firestore_service.dart';
import '../services/mock_data_service.dart';
import '../core/utils/app_logger.dart';
import 'app_state.dart'; // For firestoreServiceProvider

// Meals State Notifier
class MealsNotifier extends StateNotifier<List<Meal>> {
  final FirestoreService _firestoreService;
  final String? _uid;
  final String _date;

  MealsNotifier(this._firestoreService, this._uid, this._date) : super([]) {
    _loadMeals();
  }

  /// Firestore에서 식단 데이터 로드
  Future<void> _loadMeals() async {
    // 게스트 모드거나 uid가 없으면 빈 상태로 시작 (오늘 데이터 없음)
    if (_uid == null || _uid == 'guest') {
      AppLogger.info('[MealsNotifier] 게스트 모드 - 예시 데이터 로드');
      state =
          _date == Meal.todayString ? MockDataService.getMockMeals() : <Meal>[];
      return;
    }

    try {
      AppLogger.debug(
          '[MealsNotifier] Firestore에서 식단 로드 중... (uid: $_uid, date: $_date)');
      final meals = await _firestoreService.loadMealsByDate(_uid!, _date);

      // Firestore 데이터 그대로 사용 (빈 리스트도 그대로 유지)
      state = meals;

      if (meals.isEmpty) {
        AppLogger.info('[MealsNotifier] 신규 계정 - 빈 상태로 시작');
      } else {
        AppLogger.info('[MealsNotifier] Firestore에서 ${meals.length}개 식단 로드 완료');
      }
    } catch (e, stackTrace) {
      AppLogger.error('[MealsNotifier] 식단 로드 실패', e, stackTrace);
      // 로드 실패 시 빈 상태로 시작
      state = [];
    }
  }

  Future<void> addMeal(Meal meal) async {
    try {
      final mealForDate = meal.copyWith(date: _date);

      // 로컬 상태 업데이트
      state = [...state, mealForDate];

      // 게스트가 아닌 경우만 Firestore에 저장
      if (_uid != null && _uid != 'guest') {
        await _firestoreService.addMeal(mealForDate, _uid!);
        AppLogger.info('[MealsNotifier] 식단 추가 완료: ${mealForDate.name}');
      } else {
        AppLogger.info('[MealsNotifier] 게스트 모드 - 로컬에만 저장: ${mealForDate.name}');
      }
    } catch (e, stackTrace) {
      AppLogger.error('[MealsNotifier] 식단 추가 실패 - 로컬만 유지', e, stackTrace);
      // Firestore 저장 실패 시에도 로컬 상태는 유지
    }
  }

  Future<void> updateMeal(String id, Meal updatedMeal) async {
    try {
      final mealForDate = updatedMeal.copyWith(date: _date);

      // 로컬 상태 업데이트
      state = [
        for (final meal in state)
          if (meal.id == id) mealForDate else meal,
      ];

      // 게스트가 아닌 경우만 Firestore에 업데이트
      if (_uid != null && _uid != 'guest') {
        await _firestoreService.updateMeal(mealForDate, _uid!);
        AppLogger.info('[MealsNotifier] 식단 업데이트 완료: ${mealForDate.name}');
      } else {
        AppLogger.info(
            '[MealsNotifier] 게스트 모드 - 로컬에만 업데이트: ${mealForDate.name}');
      }
    } catch (e, stackTrace) {
      AppLogger.error('[MealsNotifier] 식단 업데이트 실패 - 로컬만 유지', e, stackTrace);
    }
  }

  Future<void> deleteMeal(String id) async {
    try {
      // 로컬 상태 업데이트
      state = state.where((meal) => meal.id != id).toList();

      // 게스트가 아닌 경우만 Firestore에서 삭제
      if (_uid != null && _uid != 'guest') {
        await _firestoreService.deleteMeal(id, _uid!);
        AppLogger.info('[MealsNotifier] 식단 삭제 완료: $id');
      } else {
        AppLogger.info('[MealsNotifier] 게스트 모드 - 로컬에서만 삭제: $id');
      }
    } catch (e, stackTrace) {
      AppLogger.error('[MealsNotifier] 식단 삭제 실패 - 로컬만 유지', e, stackTrace);
    }
  }
}

final mealsProvider =
    StateNotifierProvider.autoDispose<MealsNotifier, List<Meal>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final uid = ref.watch(currentUidProvider);
  final selectedDate = ref.watch(selectedDateStringProvider);
  return MealsNotifier(firestoreService, uid, selectedDate);
});

// Computed providers
final totalCaloriesProvider = Provider<int>((ref) {
  final meals = ref.watch(mealsProvider);
  return meals.fold(0, (sum, meal) => sum + meal.calories);
});

final totalProteinProvider = Provider<int>((ref) {
  final meals = ref.watch(mealsProvider);
  return meals.fold(0, (sum, meal) => sum + meal.protein);
});

final totalCarbsProvider = Provider<int>((ref) {
  final meals = ref.watch(mealsProvider);
  return meals.fold(0, (sum, meal) => sum + meal.carbs);
});

final totalFatProvider = Provider<int>((ref) {
  final meals = ref.watch(mealsProvider);
  return meals.fold(0, (sum, meal) => sum + meal.fat);
});
