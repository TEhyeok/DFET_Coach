import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/meal.dart';
import '../../models/workout.dart';

/// Analytics 데이터 모델
class AnalyticsData {
  final int totalUsers;
  final int activeUsers;
  final int todaySignups;
  final Map<String, int> dailyActiveUsers; // 날짜별 활성 사용자 수
  final Map<String, int> dailySignups; // 날짜별 가입자 수
  final Map<String, int> topFoods; // 인기 음식 TOP 10
  final Map<String, int> topWorkouts; // 인기 운동 TOP 10
  final double avgCalories; // 평균 칼로리
  final double avgWorkoutFrequency; // 주간 평균 운동 빈도
  final Map<String, int> postureScoreDistribution; // 자세 점수 분포

  AnalyticsData({
    required this.totalUsers,
    required this.activeUsers,
    required this.todaySignups,
    required this.dailyActiveUsers,
    required this.dailySignups,
    required this.topFoods,
    required this.topWorkouts,
    required this.avgCalories,
    required this.avgWorkoutFrequency,
    required this.postureScoreDistribution,
  });
}

/// 사용자별 상세 통계 데이터
class UserAnalytics {
  final Map<String, double> dailyCalories; // 날짜별 칼로리
  final Map<String, int> dailyWorkouts; // 날짜별 운동 횟수
  final Map<String, Map<String, int>> dailyNutrients; // 날짜별 영양소
  final List<Meal> recentMeals;
  final List<Workout> recentWorkouts;
  final double weeklyAvgCalories;
  final double weeklyWorkoutFrequency;
  final double avgPostureScore;

  UserAnalytics({
    required this.dailyCalories,
    required this.dailyWorkouts,
    required this.dailyNutrients,
    required this.recentMeals,
    required this.recentWorkouts,
    required this.weeklyAvgCalories,
    required this.weeklyWorkoutFrequency,
    required this.avgPostureScore,
  });
}

/// Analytics 서비스
class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 전체 분석 데이터 가져오기 (최적화된 버전 - 단일 패스)
  Future<AnalyticsData> getAnalyticsData() async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // 전체 사용자 수
    final usersSnapshot = await _firestore.collection('users').get();
    final totalUsers = usersSnapshot.docs.length;

    // 초기화
    int activeUsers = 0;
    int todaySignups = 0;
    Map<String, int> dailySignups = {};
    Map<String, int> dailyActiveUsers = {};
    Map<String, int> foodCounts = {};
    Map<String, int> workoutCounts = {};
    double totalCalories = 0;
    int mealCount = 0;
    int totalWorkouts = 0;
    Map<String, int> postureDistribution = {
      '0-20': 0,
      '20-40': 0,
      '40-60': 0,
      '60-80': 0,
      '80-100': 0,
    };

    // 모든 사용자 데이터를 한 번에 수집
    final List<Future<void>> userFutures = [];

    for (var userDoc in usersSnapshot.docs) {
      final data = userDoc.data();

      // 사용자 메타데이터 처리
      final lastLoginAt = data['lastLoginAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['lastLoginAt'] as int)
          : null;
      final createdAt = data['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int)
          : null;

      // 활성 사용자 카운트
      if (lastLoginAt != null && lastLoginAt.isAfter(sevenDaysAgo)) {
        activeUsers++;
        final dateKey = '${lastLoginAt.year}-${lastLoginAt.month.toString().padLeft(2, '0')}-${lastLoginAt.day.toString().padLeft(2, '0')}';
        dailyActiveUsers[dateKey] = (dailyActiveUsers[dateKey] ?? 0) + 1;
      }

      // 가입자 카운트
      if (createdAt != null) {
        final isToday = createdAt.year == now.year &&
            createdAt.month == now.month &&
            createdAt.day == now.day;
        if (isToday) todaySignups++;

        if (createdAt.isAfter(thirtyDaysAgo)) {
          final dateKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
          dailySignups[dateKey] = (dailySignups[dateKey] ?? 0) + 1;
        }
      }

      // 식단 및 운동 데이터를 병렬로 가져오기
      userFutures.add(_collectUserData(
        userDoc.id,
        now,
        sevenDaysAgo,
        foodCounts,
        workoutCounts,
        postureDistribution,
      ).then((result) {
        totalCalories += result['calories'] as double;
        mealCount += result['mealCount'] as int;
        totalWorkouts += result['workoutCount'] as int;
      }));
    }

    // 모든 사용자 데이터 수집 완료 대기
    await Future.wait(userFutures);

    // 인기 음식/운동 TOP 10 정렬
    final sortedFoods = foodCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topFoods = Map.fromEntries(sortedFoods.take(10));

    final sortedWorkouts = workoutCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topWorkouts = Map.fromEntries(sortedWorkouts.take(10));

    // 평균 계산
    final avgCalories = mealCount > 0 ? totalCalories / mealCount : 0.0;
    final avgWorkoutFreq = totalUsers > 0 ? totalWorkouts / totalUsers : 0.0;

    return AnalyticsData(
      totalUsers: totalUsers,
      activeUsers: activeUsers,
      todaySignups: todaySignups,
      dailyActiveUsers: dailyActiveUsers,
      dailySignups: dailySignups,
      topFoods: topFoods,
      topWorkouts: topWorkouts,
      avgCalories: avgCalories,
      avgWorkoutFrequency: avgWorkoutFreq,
      postureScoreDistribution: postureDistribution,
    );
  }

  /// 사용자별 데이터 수집 (병렬 처리용)
  Future<Map<String, dynamic>> _collectUserData(
    String uid,
    DateTime now,
    DateTime sevenDaysAgo,
    Map<String, int> foodCounts,
    Map<String, int> workoutCounts,
    Map<String, int> postureDistribution,
  ) async {
    double calories = 0;
    int mealCount = 0;
    int workoutCount = 0;

    // 식단 및 운동 데이터를 병렬로 가져오기
    final results = await Future.wait([
      _firestore
          .collection('users')
          .doc(uid)
          .collection('meals')
          .limit(50)
          .get(),
      _firestore
          .collection('users')
          .doc(uid)
          .collection('workouts')
          .where('timestamp', isGreaterThan: sevenDaysAgo)
          .get(),
    ]);

    final mealsSnapshot = results[0];
    final workoutsSnapshot = results[1];

    // 식단 데이터 처리
    for (var mealDoc in mealsSnapshot.docs) {
      final meal = Meal.fromFirestore(mealDoc.data(), mealDoc.id);
      foodCounts[meal.name] = (foodCounts[meal.name] ?? 0) + 1;
      calories += meal.calories;
      mealCount++;
    }

    // 운동 데이터 처리
    workoutCount = workoutsSnapshot.docs.length;
    for (var workoutDoc in workoutsSnapshot.docs) {
      final workout = Workout.fromFirestore(workoutDoc.data(), workoutDoc.id);
      workoutCounts[workout.name] = (workoutCounts[workout.name] ?? 0) + 1;

      if (workout.postureScore != null) {
        final score = workout.postureScore!;
        if (score <= 20) postureDistribution['0-20'] = postureDistribution['0-20']! + 1;
        else if (score <= 40) postureDistribution['20-40'] = postureDistribution['20-40']! + 1;
        else if (score <= 60) postureDistribution['40-60'] = postureDistribution['40-60']! + 1;
        else if (score <= 80) postureDistribution['60-80'] = postureDistribution['60-80']! + 1;
        else postureDistribution['80-100'] = postureDistribution['80-100']! + 1;
      }
    }

    return {
      'calories': calories,
      'mealCount': mealCount,
      'workoutCount': workoutCount,
    };
  }

  /// 사용자별 상세 분석 데이터
  Future<UserAnalytics> getUserAnalytics(String uid) async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // 최근 30개 식단 기록
    final mealsSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('meals')
        .orderBy('date', descending: true)
        .limit(30)
        .get();

    final recentMeals = mealsSnapshot.docs
        .map((doc) => Meal.fromFirestore(doc.data(), doc.id))
        .toList();

    // 최근 30개 운동 기록
    final workoutsSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('workouts')
        .orderBy('timestamp', descending: true)
        .limit(30)
        .get();

    final recentWorkouts = workoutsSnapshot.docs
        .map((doc) => Workout.fromFirestore(doc.data(), doc.id))
        .toList();

    // 일별 칼로리 계산 (최근 7일)
    Map<String, double> dailyCalories = {};
    Map<String, int> dailyWorkouts = {};
    Map<String, Map<String, int>> dailyNutrients = {};

    for (var meal in recentMeals) {
      final mealDate = DateTime.tryParse(meal.date);
      if (mealDate != null && mealDate.isAfter(sevenDaysAgo)) {
        dailyCalories[meal.date] = (dailyCalories[meal.date] ?? 0) + meal.calories;

        if (!dailyNutrients.containsKey(meal.date)) {
          dailyNutrients[meal.date] = {'protein': 0, 'carbs': 0, 'fat': 0};
        }
        dailyNutrients[meal.date]!['protein'] =
            (dailyNutrients[meal.date]!['protein']! + meal.protein);
        dailyNutrients[meal.date]!['carbs'] =
            (dailyNutrients[meal.date]!['carbs']! + meal.carbs);
        dailyNutrients[meal.date]!['fat'] =
            (dailyNutrients[meal.date]!['fat']! + meal.fat);
      }
    }

    // 일별 운동 횟수 (최근 7일)
    for (var workout in recentWorkouts) {
      if (workout.timestamp.isAfter(sevenDaysAgo)) {
        final dateKey = '${workout.timestamp.year}-${workout.timestamp.month.toString().padLeft(2, '0')}-${workout.timestamp.day.toString().padLeft(2, '0')}';
        dailyWorkouts[dateKey] = (dailyWorkouts[dateKey] ?? 0) + 1;
      }
    }

    // 주간 평균 칼로리
    final weeklyCalories = dailyCalories.values.fold<double>(0, (sum, cal) => sum + cal);
    final weeklyAvgCalories = dailyCalories.isNotEmpty ? (weeklyCalories / dailyCalories.length).toDouble() : 0.0;

    // 주간 평균 운동 빈도
    final weeklyWorkouts = dailyWorkouts.values.fold<int>(0, (sum, count) => sum + count);
    final weeklyWorkoutFrequency = (weeklyWorkouts / 7.0).toDouble();

    // 평균 자세 점수
    final postureScores = recentWorkouts
        .where((w) => w.postureScore != null)
        .map((w) => w.postureScore!)
        .toList();
    final avgPostureScore = postureScores.isNotEmpty
        ? (postureScores.fold<double>(0, (sum, score) => sum + score) / postureScores.length).toDouble()
        : 0.0;

    return UserAnalytics(
      dailyCalories: dailyCalories,
      dailyWorkouts: dailyWorkouts,
      dailyNutrients: dailyNutrients,
      recentMeals: recentMeals,
      recentWorkouts: recentWorkouts,
      weeklyAvgCalories: weeklyAvgCalories,
      weeklyWorkoutFrequency: weeklyWorkoutFrequency,
      avgPostureScore: avgPostureScore,
    );
  }

}
