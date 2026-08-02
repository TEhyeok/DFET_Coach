import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/meal.dart';
import '../models/soap_note.dart';
import '../models/workout.dart';
import '../models/user_profile.dart';
import '../core/utils/app_logger.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 오늘 날짜 문자열 반환 (yyyy-MM-dd 형식)
  String get _todayString => DateFormat('yyyy-MM-dd').format(DateTime.now());

  // Collection references
  CollectionReference get _usersCollection => _firestore.collection('users');

  CollectionReference get _soapNotesCollection =>
      _firestore.collection('soap_notes');

  /// 사용자별 식단 컬렉션 참조
  CollectionReference _mealsCollection(String uid) =>
      _firestore.collection('users').doc(uid).collection('meals');

  /// 사용자별 운동 컬렉션 참조
  CollectionReference _workoutsCollection(String uid) =>
      _firestore.collection('users').doc(uid).collection('workouts');

  // MEALS CRUD

  /// Firestore에서 사용자별 오늘 식단 데이터 로드
  Future<List<Meal>> loadMeals(String uid) async {
    final stopwatch = Stopwatch()..start();
    try {
      final today = _todayString;
      AppLogger.debug(
          '[FirestoreService] 오늘($today) 식단 데이터 로드 중... (uid: $uid)');

      final snapshot = await _mealsCollection(uid)
          .where('date', isEqualTo: today)
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.warning('[FirestoreService] 식단 로드 타임아웃 (10초)');
          throw TimeoutException('식단 데이터 로드가 10초를 초과했습니다');
        },
      );

      final meals = snapshot.docs
          .map((doc) =>
              Meal.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Sort by time (newest first)
      meals.sort((a, b) => b.time.compareTo(a.time));

      stopwatch.stop();
      AppLogger.info(
          '[FirestoreService] ⏱️ 오늘($today) 식단 ${meals.length}개 로드 완료 (${stopwatch.elapsedMilliseconds}ms)');
      return meals;
    } catch (e, stackTrace) {
      stopwatch.stop();
      AppLogger.error(
          '[FirestoreService] ❌ 식단 로드 실패 (${stopwatch.elapsedMilliseconds}ms)',
          e,
          stackTrace);
      return []; // 실패 시 빈 리스트 반환
    }
  }

  /// Firestore에서 특정 날짜의 식단 데이터 로드
  Future<List<Meal>> loadMealsByDate(String uid, String date) async {
    final stopwatch = Stopwatch()..start();
    try {
      AppLogger.debug('[FirestoreService] $date 식단 데이터 로드 중... (uid: $uid)');

      final snapshot = await _mealsCollection(uid)
          .where('date', isEqualTo: date)
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.warning('[FirestoreService] 식단 로드 타임아웃 (10초)');
          throw TimeoutException('식단 데이터 로드가 10초를 초과했습니다');
        },
      );

      final meals = snapshot.docs
          .map((doc) =>
              Meal.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Sort by time (newest first)
      meals.sort((a, b) => b.time.compareTo(a.time));

      stopwatch.stop();
      AppLogger.info(
          '[FirestoreService] ⏱️ $date 식단 ${meals.length}개 로드 완료 (${stopwatch.elapsedMilliseconds}ms)');
      return meals;
    } catch (e, stackTrace) {
      stopwatch.stop();
      AppLogger.error(
          '[FirestoreService] ❌ 식단 로드 실패 (${stopwatch.elapsedMilliseconds}ms)',
          e,
          stackTrace);
      return [];
    }
  }

  /// 식단 추가 (Firestore + 로컬)
  Future<void> addMeal(Meal meal, String uid) async {
    try {
      AppLogger.debug('[FirestoreService] 식단 추가: ${meal.name} (uid: $uid)');

      await _mealsCollection(uid).doc(meal.id).set({
        'time': meal.time,
        'name': meal.name,
        'calories': meal.calories,
        'protein': meal.protein,
        'carbs': meal.carbs,
        'fat': meal.fat,
        'date': meal.date,
        if (meal.aiTokenUsage != null) 'aiTokenUsage': meal.aiTokenUsage,
        'timestamp': FieldValue.serverTimestamp(),
      }).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.warning('[FirestoreService] 식단 추가 타임아웃 (10초)');
          throw TimeoutException('식단 추가가 10초를 초과했습니다');
        },
      );

      AppLogger.info('[FirestoreService] 식단 추가 성공: ${meal.id}');
    } catch (e, stackTrace) {
      AppLogger.error('[FirestoreService] 식단 추가 실패', e, stackTrace);
      rethrow;
    }
  }

  /// 식단 업데이트
  Future<void> updateMeal(Meal meal, String uid) async {
    try {
      AppLogger.debug('[FirestoreService] 식단 업데이트: ${meal.id} (uid: $uid)');

      await _mealsCollection(uid).doc(meal.id).update({
        'time': meal.time,
        'name': meal.name,
        'calories': meal.calories,
        'protein': meal.protein,
        'carbs': meal.carbs,
        'fat': meal.fat,
        'date': meal.date,
        if (meal.aiTokenUsage != null) 'aiTokenUsage': meal.aiTokenUsage,
      }).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.warning('[FirestoreService] 식단 업데이트 타임아웃 (10초)');
          throw TimeoutException('식단 업데이트가 10초를 초과했습니다');
        },
      );

      AppLogger.info('[FirestoreService] 식단 업데이트 성공: ${meal.id}');
    } catch (e, stackTrace) {
      AppLogger.error('[FirestoreService] 식단 업데이트 실패', e, stackTrace);
      rethrow;
    }
  }

  /// 식단 삭제
  Future<void> deleteMeal(String id, String uid) async {
    try {
      AppLogger.debug('[FirestoreService] 식단 삭제: $id (uid: $uid)');

      await _mealsCollection(uid).doc(id).delete().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.warning('[FirestoreService] 식단 삭제 타임아웃 (10초)');
          throw TimeoutException('식단 삭제가 10초를 초과했습니다');
        },
      );

      AppLogger.info('[FirestoreService] 식단 삭제 성공: $id');
    } catch (e, stackTrace) {
      AppLogger.error('[FirestoreService] 식단 삭제 실패', e, stackTrace);
      rethrow;
    }
  }

  // WORKOUTS CRUD

  /// Firestore에서 사용자별 오늘 운동 데이터 로드
  Future<List<Workout>> loadWorkouts(String uid) async {
    final stopwatch = Stopwatch()..start();
    try {
      final today = _todayString;
      AppLogger.debug(
          '[FirestoreService] 오늘($today) 운동 데이터 로드 중... (uid: $uid)');

      final snapshot = await _workoutsCollection(uid)
          .where('date', isEqualTo: today)
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.warning('[FirestoreService] 운동 로드 타임아웃 (10초)');
          throw TimeoutException('운동 데이터 로드가 10초를 초과했습니다');
        },
      );

      final workouts = snapshot.docs
          .map((doc) =>
              Workout.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Sort by timestamp (newest first)
      workouts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      stopwatch.stop();
      AppLogger.info(
          '[FirestoreService] ⏱️ 오늘($today) 운동 ${workouts.length}개 로드 완료 (${stopwatch.elapsedMilliseconds}ms)');
      return workouts;
    } catch (e, stackTrace) {
      stopwatch.stop();
      AppLogger.error(
          '[FirestoreService] ❌ 운동 로드 실패 (${stopwatch.elapsedMilliseconds}ms)',
          e,
          stackTrace);
      return [];
    }
  }

  /// Firestore에서 특정 날짜의 운동 데이터 로드
  Future<List<Workout>> loadWorkoutsByDate(String uid, String date) async {
    final stopwatch = Stopwatch()..start();
    try {
      AppLogger.debug('[FirestoreService] $date 운동 데이터 로드 중... (uid: $uid)');

      final snapshot = await _workoutsCollection(uid)
          .where('date', isEqualTo: date)
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.warning('[FirestoreService] 운동 로드 타임아웃 (10초)');
          throw TimeoutException('운동 데이터 로드가 10초를 초과했습니다');
        },
      );

      final workouts = snapshot.docs
          .map((doc) =>
              Workout.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Sort by timestamp (newest first)
      workouts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      stopwatch.stop();
      AppLogger.info(
          '[FirestoreService] ⏱️ $date 운동 ${workouts.length}개 로드 완료 (${stopwatch.elapsedMilliseconds}ms)');
      return workouts;
    } catch (e, stackTrace) {
      stopwatch.stop();
      AppLogger.error(
          '[FirestoreService] ❌ 운동 로드 실패 (${stopwatch.elapsedMilliseconds}ms)',
          e,
          stackTrace);
      return [];
    }
  }

  /// 운동 추가
  Future<void> addWorkout(Workout workout, String uid) async {
    try {
      AppLogger.debug('[FirestoreService] 운동 추가: ${workout.name} (uid: $uid)');

      await _workoutsCollection(uid)
          .doc(workout.id)
          .set(workout.toFirestore())
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.warning('[FirestoreService] 운동 추가 타임아웃 (10초)');
          throw TimeoutException('운동 추가가 10초를 초과했습니다');
        },
      );

      AppLogger.info('[FirestoreService] 운동 추가 성공: ${workout.id}');
    } catch (e, stackTrace) {
      AppLogger.error('[FirestoreService] 운동 추가 실패', e, stackTrace);
      rethrow;
    }
  }

  /// 운동 삭제
  Future<void> deleteWorkout(String id, String uid) async {
    try {
      AppLogger.debug('[FirestoreService] 운동 삭제: $id (uid: $uid)');

      await _workoutsCollection(uid).doc(id).delete().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.warning('[FirestoreService] 운동 삭제 타임아웃 (10초)');
          throw TimeoutException('운동 삭제가 10초를 초과했습니다');
        },
      );

      AppLogger.info('[FirestoreService] 운동 삭제 성공: $id');
    } catch (e, stackTrace) {
      AppLogger.error('[FirestoreService] 운동 삭제 실패', e, stackTrace);
      rethrow;
    }
  }

  // WEEKLY/MONTHLY DATA QUERIES

  /// 주간 데이터 조회 (오늘 기준 지난 7일)
  Future<Map<String, dynamic>> loadWeeklyData(String uid) async {
    final stopwatch = Stopwatch()..start();
    try {
      AppLogger.debug('[FirestoreService] 📊 주간 데이터 조회 시작 (uid: $uid)');
      final now = DateTime.now();
      final weekData = <String, Map<String, dynamic>>{};

      // 7일치 날짜 생성
      final dates = List.generate(7, (i) {
        final date = now.subtract(Duration(days: 6 - i));
        return DateFormat('yyyy-MM-dd').format(date);
      });

      // 병렬로 모든 날짜의 데이터 로드
      final allMeals =
          await Future.wait(dates.map((date) => loadMealsByDate(uid, date)));
      final allWorkouts =
          await Future.wait(dates.map((date) => loadWorkoutsByDate(uid, date)));

      // 날짜별 데이터 처리
      for (int i = 0; i < dates.length; i++) {
        final dateString = dates[i];
        final meals = allMeals[i];
        final workouts = allWorkouts[i];

        // 해당 날짜의 총합 계산
        final totalCalories = meals.fold(0, (total, m) => total + m.calories);
        final totalProtein = meals.fold(0, (total, m) => total + m.protein);
        final totalWorkoutTime = workouts.fold(0, (total, w) {
          if (w.category == 'cardio') {
            return total + w.duration;
          } else {
            return total + (w.sets.length * 3);
          }
        });

        // 웰니스 점수 계산
        int wellnessScore = 0;
        if (totalCalories > 0 || totalProtein > 0 || totalWorkoutTime > 0) {
          wellnessScore = 50;
          wellnessScore += ((totalCalories / 2000) * 30).clamp(0, 30).toInt();
          wellnessScore += ((totalProtein / 100) * 20).clamp(0, 20).toInt();
          wellnessScore += ((totalWorkoutTime / 60) * 30).clamp(0, 30).toInt();
          if (totalCalories > 2500) wellnessScore -= 10;
          wellnessScore = wellnessScore.clamp(0, 100);
        }

        weekData[dateString] = {
          'calories': totalCalories,
          'protein': totalProtein,
          'workoutTime': totalWorkoutTime,
          'wellnessScore': wellnessScore,
        };
      }

      stopwatch.stop();
      AppLogger.info(
          '[FirestoreService] ⏱️ 주간 데이터 로드 완료: ${weekData.length}일 (${stopwatch.elapsedMilliseconds}ms)');
      return {'data': weekData};
    } catch (e, stackTrace) {
      stopwatch.stop();
      AppLogger.error(
          '[FirestoreService] ❌ 주간 데이터 로드 실패 (${stopwatch.elapsedMilliseconds}ms)',
          e,
          stackTrace);
      return {'data': <String, Map<String, dynamic>>{}};
    }
  }

  /// 월간 데이터 조회 (특정 월의 4주 데이터)
  Future<Map<String, dynamic>> loadMonthlyData(
      String uid, DateTime month) async {
    final stopwatch = Stopwatch()..start();
    try {
      AppLogger.debug(
          '[FirestoreService] 📊 월간 데이터 조회 시작 (uid: $uid, month: ${month.year}-${month.month})');
      final monthData = <int, Map<String, dynamic>>{};

      // 해당 월의 마지막 날
      final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

      // 모든 날짜 수집
      final allDates = <String>[];
      final weekDayMapping = <int, List<int>>{}; // week -> [day indices]

      for (int week = 1; week <= 4; week++) {
        final weekStartDay = (week - 1) * 7 + 1;
        final weekEndDay = (week * 7).clamp(1, lastDayOfMonth.day);
        weekDayMapping[week] = [];

        for (int day = weekStartDay;
            day <= weekEndDay && day <= lastDayOfMonth.day;
            day++) {
          final date = DateTime(month.year, month.month, day);
          final dateString = DateFormat('yyyy-MM-dd').format(date);
          weekDayMapping[week]!.add(allDates.length);
          allDates.add(dateString);
        }
      }

      // 병렬로 모든 날짜의 데이터 로드
      final allMeals =
          await Future.wait(allDates.map((date) => loadMealsByDate(uid, date)));
      final allWorkouts = await Future.wait(
          allDates.map((date) => loadWorkoutsByDate(uid, date)));

      // 주별로 집계
      for (int week = 1; week <= 4; week++) {
        int weekCalories = 0;
        int weekProtein = 0;
        int weekWorkoutTime = 0;
        int daysWithData = 0;
        int totalWellnessScore = 0;

        for (final dayIndex in weekDayMapping[week]!) {
          final meals = allMeals[dayIndex];
          final workouts = allWorkouts[dayIndex];

          final dayCalories = meals.fold(0, (total, m) => total + m.calories);
          final dayProtein = meals.fold(0, (total, m) => total + m.protein);
          final dayWorkoutTime = workouts.fold(0, (total, w) {
            if (w.category == 'cardio') {
              return total + w.duration;
            } else {
              return total + (w.sets.length * 3);
            }
          });

          weekCalories += dayCalories;
          weekProtein += dayProtein;
          weekWorkoutTime += dayWorkoutTime;

          if (dayCalories > 0 || dayWorkoutTime > 0) {
            daysWithData++;
            int dayScore = 50;
            dayScore += ((dayCalories / 2000) * 30).clamp(0, 30).toInt();
            dayScore += ((dayProtein / 100) * 20).clamp(0, 20).toInt();
            dayScore += ((dayWorkoutTime / 60) * 30).clamp(0, 30).toInt();
            if (dayCalories > 2500) dayScore -= 10;
            totalWellnessScore += dayScore.clamp(0, 100);
          }
        }

        monthData[week] = {
          'calories': weekCalories,
          'protein': weekProtein,
          'workoutTime': weekWorkoutTime,
          'wellnessScore': daysWithData > 0
              ? (totalWellnessScore / daysWithData).round()
              : 0,
        };
      }

      stopwatch.stop();
      AppLogger.info(
          '[FirestoreService] ⏱️ 월간 데이터 로드 완료: ${month.year}-${month.month} (${stopwatch.elapsedMilliseconds}ms)');
      return {
        'data': monthData,
        'month': month,
      };
    } catch (e, stackTrace) {
      stopwatch.stop();
      AppLogger.error(
          '[FirestoreService] ❌ 월간 데이터 로드 실패 (${stopwatch.elapsedMilliseconds}ms)',
          e,
          stackTrace);
      return {'data': <int, Map<String, dynamic>>{}};
    }
  }

  // STREAM LISTENERS

  /// 실시간 사용자별 식단 스트림 (오늘 날짜만)
  Stream<List<Meal>> mealsStream(String uid) {
    try {
      final today = _todayString;
      AppLogger.debug(
          '[FirestoreService] 식단 스트림 구독 시작 (uid: $uid, date: $today)');

      return _mealsCollection(uid)
          .where('date', isEqualTo: today)
          .snapshots()
          .map((snapshot) {
        final meals = snapshot.docs
            .map((doc) =>
                Meal.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .toList();
        // Sort by time (newest first)
        meals.sort((a, b) => b.time.compareTo(a.time));
        AppLogger.debug('[FirestoreService] 식단 스트림 업데이트: ${meals.length}개');
        return meals;
      });
    } catch (e, stackTrace) {
      AppLogger.error('[FirestoreService] 식단 스트림 생성 실패', e, stackTrace);
      return Stream.value([]);
    }
  }

  /// 실시간 사용자별 운동 스트림 (오늘 날짜만)
  Stream<List<Workout>> workoutsStream(String uid) {
    try {
      final today = _todayString;
      AppLogger.debug(
          '[FirestoreService] 운동 스트림 구독 시작 (uid: $uid, date: $today)');

      return _workoutsCollection(uid)
          .where('date', isEqualTo: today)
          .snapshots()
          .map((snapshot) {
        final workouts = snapshot.docs
            .map((doc) => Workout.fromFirestore(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList();
        // Sort by timestamp (newest first)
        workouts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        AppLogger.debug('[FirestoreService] 운동 스트림 업데이트: ${workouts.length}개');
        return workouts;
      });
    } catch (e, stackTrace) {
      AppLogger.error('[FirestoreService] 운동 스트림 생성 실패', e, stackTrace);
      return Stream.value([]);
    }
  }

  // SOAP NOTES CRUD

  Future<List<SoapNote>> loadTrainerSoapNotes(String trainerId) async {
    try {
      AppLogger.debug('[FirestoreService] SOAP 노트 로드: trainer=$trainerId');

      final snapshot = await _soapNotesCollection
          .where('trainerId', isEqualTo: trainerId)
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.warning('[FirestoreService] SOAP 노트 로드 타임아웃');
          throw TimeoutException('SOAP 노트 로드가 10초를 초과했습니다');
        },
      );

      final notes = snapshot.docs
          .map((doc) => SoapNote.fromFirestore(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      return notes;
    } catch (e, stackTrace) {
      AppLogger.error('[FirestoreService] SOAP 노트 로드 실패', e, stackTrace);
      return [];
    }
  }

  Future<List<SoapNote>> loadMemberSoapNotes({
    required String memberId,
    String? memberEmail,
  }) async {
    try {
      AppLogger.debug('[FirestoreService] 회원 SOAP 노트 로드: member=$memberId');

      final memberIdSnapshot = await _soapNotesCollection
          .where('memberId', isEqualTo: memberId)
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.warning('[FirestoreService] 회원 SOAP 노트 로드 타임아웃');
          throw TimeoutException('회원 SOAP 노트 로드가 10초를 초과했습니다');
        },
      );

      final byId = <String, SoapNote>{};
      for (final doc in memberIdSnapshot.docs) {
        final note = SoapNote.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
        if (note.isSharedWithMember) {
          byId[note.id] = note;
        }
      }

      final normalizedEmail = memberEmail?.trim();
      if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
        final emailSnapshot = await _soapNotesCollection
            .where('memberEmail', isEqualTo: normalizedEmail)
            .get()
            .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            AppLogger.warning('[FirestoreService] 회원 이메일 SOAP 노트 로드 타임아웃');
            throw TimeoutException('회원 SOAP 노트 로드가 10초를 초과했습니다');
          },
        );

        for (final doc in emailSnapshot.docs) {
          final note = SoapNote.fromFirestore(
            doc.data() as Map<String, dynamic>,
            doc.id,
          );
          if (note.isSharedWithMember) {
            byId[note.id] = note;
          }
        }
      }

      final notes = byId.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return notes;
    } catch (e, stackTrace) {
      AppLogger.error('[FirestoreService] 회원 SOAP 노트 로드 실패', e, stackTrace);
      return [];
    }
  }

  Future<void> saveSoapNote(SoapNote note) async {
    try {
      AppLogger.debug('[FirestoreService] SOAP 노트 저장: ${note.id}');

      await _soapNotesCollection.doc(note.id).set(note.toFirestore()).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.warning('[FirestoreService] SOAP 노트 저장 타임아웃');
          throw TimeoutException('SOAP 노트 저장이 10초를 초과했습니다');
        },
      );

      AppLogger.info('[FirestoreService] SOAP 노트 저장 성공: ${note.id}');
    } catch (e, stackTrace) {
      AppLogger.error('[FirestoreService] SOAP 노트 저장 실패', e, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteSoapNote(String id) async {
    try {
      AppLogger.debug('[FirestoreService] SOAP 노트 삭제: $id');

      await _soapNotesCollection.doc(id).delete().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.warning('[FirestoreService] SOAP 노트 삭제 타임아웃');
          throw TimeoutException('SOAP 노트 삭제가 10초를 초과했습니다');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[FirestoreService] SOAP 노트 삭제 실패', e, stackTrace);
      rethrow;
    }
  }

  // USER PROFILE CRUD

  /// 사용자 프로필 가져오기
  Future<DocumentSnapshot<Map<String, dynamic>>> getUserProfile(
      String uid) async {
    try {
      AppLogger.debug('[FirestoreService] 사용자 프로필 로드: $uid');
      return await _usersCollection.doc(uid).get()
          as DocumentSnapshot<Map<String, dynamic>>;
    } catch (e, stackTrace) {
      AppLogger.error('[FirestoreService] 사용자 프로필 로드 실패', e, stackTrace);
      rethrow;
    }
  }

  /// 사용자 프로필 저장
  Future<void> saveUserProfile(UserProfile profile) async {
    try {
      AppLogger.debug('[FirestoreService] 사용자 프로필 저장: ${profile.uid}');

      await _usersCollection.doc(profile.uid).set(profile.toMap()).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.warning('[FirestoreService] 프로필 저장 타임아웃 (10초)');
          throw TimeoutException('프로필 저장이 10초를 초과했습니다');
        },
      );

      AppLogger.info('[FirestoreService] 프로필 저장 성공: ${profile.email}');
    } catch (e, stackTrace) {
      AppLogger.error('[FirestoreService] 프로필 저장 실패', e, stackTrace);
      rethrow;
    }
  }

  /// 신규 프로필을 한 번만 생성한다. 인증 직후 중복 초기화가 발생해도
  /// 먼저 생성된 문서(및 케어 유형)를 덮어쓰지 않는다.
  Future<UserProfile> createUserProfileIfAbsent(UserProfile profile) async {
    final reference = _usersCollection.doc(profile.uid);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (snapshot.exists) {
        return UserProfile.fromMap(
          snapshot.data()! as Map<String, dynamic>,
          profile.uid,
        );
      }
      transaction.set(reference, profile.toMap());
      return profile;
    });
  }

  /// 사용자 프로필 업데이트
  Future<void> updateUserProfile(UserProfile profile) async {
    try {
      AppLogger.debug('[FirestoreService] 사용자 프로필 업데이트: ${profile.uid}');

      await _usersCollection.doc(profile.uid).update(profile.toMap()).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.warning('[FirestoreService] 프로필 업데이트 타임아웃 (10초)');
          throw TimeoutException('프로필 업데이트가 10초를 초과했습니다');
        },
      );

      AppLogger.info('[FirestoreService] 프로필 업데이트 성공: ${profile.email}');
    } catch (e, stackTrace) {
      AppLogger.error('[FirestoreService] 프로필 업데이트 실패', e, stackTrace);
      rethrow;
    }
  }

  /// 사용자 데이터 삭제 (회원탈퇴 시)
  Future<void> deleteUserData(String uid) async {
    try {
      AppLogger.debug('[FirestoreService] 사용자 데이터 삭제: $uid');

      // 배치 삭제
      final batch = _firestore.batch();

      // 사용자 프로필 삭제
      batch.delete(_usersCollection.doc(uid));

      // 사용자별 식단 데이터 삭제
      final mealsSnapshot = await _mealsCollection(uid).get();
      for (final doc in mealsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // 사용자별 운동 데이터 삭제
      final workoutsSnapshot = await _workoutsCollection(uid).get();
      for (final doc in workoutsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      AppLogger.info('[FirestoreService] 사용자 데이터 삭제 완료: $uid');
    } catch (e, stackTrace) {
      AppLogger.error('[FirestoreService] 사용자 데이터 삭제 실패', e, stackTrace);
      rethrow;
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}
