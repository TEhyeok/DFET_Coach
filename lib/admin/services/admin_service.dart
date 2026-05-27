import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/meal.dart';
import '../../models/workout.dart';
import '../../models/user_profile.dart';
import '../models/user_stats.dart';
import '../../core/utils/app_logger.dart';

/// 관리자 전용 서비스
class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 모든 사용자 프로필 조회
  Future<List<UserProfile>> getAllUsers() async {
    try {
      AppLogger.debug('[AdminService] 모든 사용자 조회 시작');
      final snapshot = await _firestore.collection('users').get();

      final users = snapshot.docs.map((doc) {
        return UserProfile.fromMap(doc.data(), doc.id);
      }).toList();

      AppLogger.info('[AdminService] 총 ${users.length}명의 사용자 조회 완료');
      return users;
    } catch (e, stackTrace) {
      AppLogger.error('[AdminService] 사용자 조회 실패', e, stackTrace);
      return [];
    }
  }

  /// 특정 사용자의 통계 조회
  Future<UserStats> getUserStats(String uid, {int days = 30}) async {
    try {
      AppLogger.debug('[AdminService] 사용자 $uid 통계 조회 (최근 $days일)');

      // 사용자 프로필
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data();

      if (userData == null) {
        throw Exception('사용자를 찾을 수 없습니다');
      }

      final profile = UserProfile.fromMap(userData, uid);

      // 날짜 범위 계산
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));
      final startDateString = DateFormat('yyyy-MM-dd').format(startDate);

      // 식사 데이터 조회
      final mealsSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('meals')
          .where('date', isGreaterThanOrEqualTo: startDateString)
          .get();

      final meals = mealsSnapshot.docs
          .map((doc) => Meal.fromFirestore(doc.data(), doc.id))
          .toList();

      // 운동 데이터 조회
      final workoutsSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('workouts')
          .where('date', isGreaterThanOrEqualTo: startDateString)
          .get();

      final workouts = workoutsSnapshot.docs
          .map((doc) => Workout.fromFirestore(doc.data(), doc.id))
          .toList();

      // 일별 통계 계산
      final dailyStats = _calculateDailyStats(meals, workouts, days);

      // 영양 요약
      final nutritionSummary = NutritionSummary.fromMeals(meals, days);

      // 운동 요약
      final workoutSummary = WorkoutSummary.fromWorkouts(workouts, days);

      // AI 토큰 사용량 계산
      int totalAiTokens = 0;
      for (final meal in meals) {
        if (meal.aiTokenUsage != null) {
          totalAiTokens += (meal.aiTokenUsage!['totalTokens'] as int? ?? 0);
        }
      }

      // 최근 식사 정렬 (최신순)
      meals.sort((a, b) {
        final dateCompare = b.date.compareTo(a.date);
        if (dateCompare != 0) return dateCompare;
        return b.time.compareTo(a.time);
      });

      final stats = UserStats(
        uid: uid,
        email: profile.email ?? '',
        displayName: profile.displayName ?? '',
        createdAt: profile.createdAt,
        lastLoginAt: profile.lastLoginAt,
        totalMeals: meals.length,
        totalWorkouts: workouts.length,
        totalAiTokens: totalAiTokens,
        recentMeals: meals,
        dailyStats: dailyStats,
        nutritionSummary: nutritionSummary,
        workoutSummary: workoutSummary,
      );

      AppLogger.info('[AdminService] 사용자 $uid 통계 조회 완료');
      return stats;
    } catch (e, stackTrace) {
      AppLogger.error('[AdminService] 사용자 통계 조회 실패', e, stackTrace);
      rethrow;
    }
  }

  /// 일별 통계 계산
  Map<String, DailyStats> _calculateDailyStats(
    List<Meal> meals,
    List<Workout> workouts,
    int days,
  ) {
    final Map<String, DailyStats> dailyStats = {};
    final now = DateTime.now();

    // 모든 날짜 초기화
    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: days - i - 1));
      final dateString = DateFormat('yyyy-MM-dd').format(date);
      dailyStats[dateString] = DailyStats(date: dateString);
    }

    // 식사 데이터 집계
    final mealsByDate = <String, List<Meal>>{};
    for (final meal in meals) {
      mealsByDate.putIfAbsent(meal.date, () => []).add(meal);
    }

    for (final entry in mealsByDate.entries) {
      final dateString = entry.key;
      final dayMeals = entry.value;

      final calories = dayMeals.fold<int>(0, (sum, m) => sum + m.calories);
      final protein = dayMeals.fold<int>(0, (sum, m) => sum + m.protein);
      final carbs = dayMeals.fold<int>(0, (sum, m) => sum + m.carbs);
      final fat = dayMeals.fold<int>(0, (sum, m) => sum + m.fat);

      dailyStats[dateString] = DailyStats(
        date: dateString,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        workoutTime: dailyStats[dateString]?.workoutTime ?? 0,
      );
    }

    // 운동 데이터 집계
    final workoutsByDate = <String, List<Workout>>{};
    for (final workout in workouts) {
      workoutsByDate.putIfAbsent(workout.date, () => []).add(workout);
    }

    for (final entry in workoutsByDate.entries) {
      final dateString = entry.key;
      final dayWorkouts = entry.value;

      int workoutTime = 0;
      for (final workout in dayWorkouts) {
        if (workout.category == 'cardio') {
          workoutTime += workout.duration;
        } else {
          workoutTime += workout.sets.length * 3; // 세트당 약 3분
        }
      }

      final existing = dailyStats[dateString];
      if (existing != null) {
        dailyStats[dateString] = DailyStats(
          date: dateString,
          calories: existing.calories,
          protein: existing.protein,
          carbs: existing.carbs,
          fat: existing.fat,
          workoutTime: workoutTime,
        );
      }
    }

    return dailyStats;
  }

  /// 전체 통계 요약
  Future<AdminDashboardStats> getDashboardStats() async {
    try {
      AppLogger.debug('[AdminService] 대시보드 통계 조회 시작');

      final users = await getAllUsers();
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));

      int activeUsers = 0;
      int totalMeals = 0;
      int totalWorkouts = 0;
      int totalAiTokens = 0;
      final Map<String, int> dailyAiTokenUsage = {};

      // 최근 7일 날짜 키 초기화
      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: 6 - i));
        final dateString = DateFormat('yyyy-MM-dd').format(date);
        dailyAiTokenUsage[dateString] = 0;
      }

      // 각 사용자별 데이터 집계
      // 주의: 사용자 수가 많아지면 이 방식은 비효율적이므로 Cloud Functions로 이관 필요
      for (final user in users) {
        // 활성 사용자 계산 (최근 7일 이내 로그인)
        if (user.lastLoginAt != null &&
            user.lastLoginAt!.isAfter(sevenDaysAgo)) {
          activeUsers++;
        }

        // 식단 데이터 조회 및 집계
        final mealsSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('meals')
            .get();
        
        totalMeals += mealsSnapshot.docs.length;

        for (final doc in mealsSnapshot.docs) {
          final data = doc.data();
          final meal = Meal.fromFirestore(data, doc.id);
          
          // AI 토큰 사용량 집계
          if (meal.aiTokenUsage != null) {
            final tokens = (meal.aiTokenUsage!['totalTokens'] as int? ?? 0);
            totalAiTokens += tokens;

            // 일별 토큰 사용량 (최근 7일만)
            if (dailyAiTokenUsage.containsKey(meal.date)) {
              dailyAiTokenUsage[meal.date] = 
                  (dailyAiTokenUsage[meal.date] ?? 0) + tokens;
            }
          }
        }

        // 운동 데이터 조회 및 집계
        final workoutsSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('workouts')
            .get();
        
        totalWorkouts += workoutsSnapshot.docs.length;
      }

      final stats = AdminDashboardStats(
        totalUsers: users.length,
        activeUsers: activeUsers,
        totalMeals: totalMeals,
        totalWorkouts: totalWorkouts,
        totalAiTokens: totalAiTokens,
        dailyAiTokenUsage: dailyAiTokenUsage,
        recentUsers: users
          ..sort((a, b) => (b.createdAt ?? DateTime(2000))
              .compareTo(a.createdAt ?? DateTime(2000))),
      );

      AppLogger.info('[AdminService] 대시보드 통계 조회 완료');
      return stats;
    } catch (e, stackTrace) {
      AppLogger.error('[AdminService] 대시보드 통계 조회 실패', e, stackTrace);
      return AdminDashboardStats(
        totalUsers: 0,
        activeUsers: 0,
        totalMeals: 0,
        totalWorkouts: 0,
        totalAiTokens: 0,
        dailyAiTokenUsage: {},
        recentUsers: [],
      );
    }
  }

  /// 사용자 검색
  Future<List<UserProfile>> searchUsers(String query) async {
    try {
      final allUsers = await getAllUsers();

      if (query.isEmpty) return allUsers;

      final lowerQuery = query.toLowerCase();
      return allUsers.where((user) {
        final email = user.email?.toLowerCase() ?? '';
        final name = user.displayName?.toLowerCase() ?? '';
        return email.contains(lowerQuery) || name.contains(lowerQuery);
      }).toList();
    } catch (e, stackTrace) {
      AppLogger.error('[AdminService] 사용자 검색 실패', e, stackTrace);
      return [];
    }
  }

  /// 사용자 삭제 (Mock)
  Future<void> deleteUser(String uid) async {
    try {
      AppLogger.info('[AdminService] 사용자 삭제 시도: $uid');
      // 실제 삭제 로직은 위험하므로 여기서는 로그만 남기고 성공으로 처리
      // await _firestore.collection('users').doc(uid).delete();
      await Future.delayed(const Duration(seconds: 1)); // 네트워크 지연 시뮬레이션
      AppLogger.info('[AdminService] 사용자 삭제 완료 (Mock): $uid');
    } catch (e, stackTrace) {
      AppLogger.error('[AdminService] 사용자 삭제 실패', e, stackTrace);
      rethrow;
    }
  }

  /// 상세 분석 데이터 조회 (Mock Data 포함)
  Future<AnalyticsStats> getAnalyticsData() async {
    await Future.delayed(const Duration(milliseconds: 800)); // 로딩 시뮬레이션

    // Mock Data 생성
    final now = DateTime.now();
    final dates = List.generate(30, (i) => now.subtract(Duration(days: 29 - i)));
    
    // 1. User Growth (Cumulative)
    int baseUsers = 150;
    final userGrowth = dates.map((date) {
      baseUsers += (date.day % 3); // Randomish growth
      return FlSpot(date.millisecondsSinceEpoch.toDouble(), baseUsers.toDouble());
    }).toList();

    // 2. Daily Active Users (DAU)
    final dau = dates.map((date) {
      final value = 20 + (date.day % 15) + (date.weekday == 6 || date.weekday == 7 ? 10 : 0);
      return FlSpot(date.millisecondsSinceEpoch.toDouble(), value.toDouble());
    }).toList();

    // 3. Revenue (Mock)
    final revenue = dates.map((date) {
      final value = (date.day % 5) * 10000 + 50000;
      return FlSpot(date.millisecondsSinceEpoch.toDouble(), value.toDouble());
    }).toList();

    return AnalyticsStats(
      userGrowth: userGrowth,
      dau: dau,
      revenue: revenue,
    );
  }
}

class AnalyticsStats {
  final List<FlSpot> userGrowth;
  final List<FlSpot> dau;
  final List<FlSpot> revenue;

  AnalyticsStats({
    required this.userGrowth,
    required this.dau,
    required this.revenue,
  });
}

/// 관리자 대시보드 통계
class AdminDashboardStats {
  final int totalUsers;
  final int activeUsers;
  final int totalMeals;
  final int totalWorkouts;
  final int totalAiTokens;
  final Map<String, int> dailyAiTokenUsage; // 날짜별 토큰 사용량 (yyyy-MM-dd)
  final List<UserProfile> recentUsers;

  AdminDashboardStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.totalMeals,
    required this.totalWorkouts,
    required this.totalAiTokens,
    required this.dailyAiTokenUsage,
    required this.recentUsers,
  });
}
