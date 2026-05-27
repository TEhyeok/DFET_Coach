import '../models/meal.dart';
import '../models/workout.dart';

class MockDataService {
  /// 예시 식단 데이터
  static List<Meal> getMockMeals() {
    final now = DateTime.now();
    return [
      Meal(
        id: 'mock_meal_1',
        name: '닭가슴살 샐러드',
        calories: 350,
        protein: 30,
        carbs: 10,
        fat: 5,
        time: '08:00',
      ),
      Meal(
        id: 'mock_meal_2',
        name: '현미밥과 불고기',
        calories: 500,
        protein: 25,
        carbs: 60,
        fat: 15,
        time: '12:30',
      ),
      Meal(
        id: 'mock_meal_3',
        name: '프로틴 쉐이크',
        calories: 150,
        protein: 25,
        carbs: 5,
        fat: 2,
        time: '16:00',
      ),
    ];
  }

  /// 예시 운동 데이터
  static List<Workout> getMockWorkouts() {
    final now = DateTime.now();
    return [
      Workout(
        id: 'mock_workout_1',
        name: '아침 조깅',
        category: 'cardio',
        duration: 30,
        timestamp: now.subtract(const Duration(hours: 10)),
        sets: [],
      ),
      Workout(
        id: 'mock_workout_2',
        name: '전신 웨이트',
        category: 'strength',
        duration: 45,
        timestamp: now.subtract(const Duration(hours: 1)),
        sets: [
          WorkoutSet(reps: 12, weight: 20),
          WorkoutSet(reps: 10, weight: 25),
          WorkoutSet(reps: 8, weight: 30),
        ],
      ),
    ];
  }
}
