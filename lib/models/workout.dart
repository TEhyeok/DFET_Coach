import 'package:intl/intl.dart';

class WorkoutSet {
  final int reps;
  final double weight;

  WorkoutSet({required this.reps, required this.weight});

  /// Firestore에서 WorkoutSet 객체 생성
  factory WorkoutSet.fromFirestore(Map<String, dynamic> data) {
    return WorkoutSet(
      reps: data['reps'] as int? ?? 0,
      weight: (data['weight'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// WorkoutSet 객체를 Firestore 형식으로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'reps': reps,
      'weight': weight,
    };
  }
}

class Workout {
  final String id;
  final String name;
  final String category; // 'strength', 'cardio', 'flexibility'
  final List<WorkoutSet> sets;
  final int duration; // minutes for cardio
  final DateTime timestamp;
  final String date; // 날짜 문자열 (yyyy-MM-dd 형식)
  final double? postureScore; // 자세 평가 점수 (0-100)
  final String? formFeedback; // 자세 개선 피드백
  final String? assessmentVideoPath; // 평가 영상 경로 (선택적)

  Workout({
    required this.id,
    required this.name,
    required this.category,
    this.sets = const [],
    this.duration = 0,
    required this.timestamp,
    String? date,
    this.postureScore,
    this.formFeedback,
    this.assessmentVideoPath,
  }) : date = date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// 오늘 날짜 문자열 반환
  static String get todayString => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Workout copyWith({
    String? id,
    String? name,
    String? category,
    List<WorkoutSet>? sets,
    int? duration,
    DateTime? timestamp,
    String? date,
    double? postureScore,
    String? formFeedback,
    String? assessmentVideoPath,
  }) {
    return Workout(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      sets: sets ?? this.sets,
      duration: duration ?? this.duration,
      timestamp: timestamp ?? this.timestamp,
      date: date ?? this.date,
      postureScore: postureScore ?? this.postureScore,
      formFeedback: formFeedback ?? this.formFeedback,
      assessmentVideoPath: assessmentVideoPath ?? this.assessmentVideoPath,
    );
  }

  String get displaySummary {
    if (category == 'cardio') {
      return '$duration분';
    } else {
      return '${sets.length}세트';
    }
  }

  /// Firestore에서 Workout 객체 생성
  factory Workout.fromFirestore(Map<String, dynamic> data, String id) {
    return Workout(
      id: id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? 'strength',
      sets: (data['sets'] as List<dynamic>?)
          ?.map((setData) => WorkoutSet.fromFirestore(setData as Map<String, dynamic>))
          .toList() ?? [],
      duration: data['duration'] as int? ?? 0,
      timestamp: (data['timestamp'] as dynamic)?.toDate() ?? DateTime.now(),
      date: data['date'] as String? ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
      postureScore: (data['postureScore'] as num?)?.toDouble(),
      formFeedback: data['formFeedback'] as String?,
      assessmentVideoPath: data['assessmentVideoPath'] as String?,
    );
  }

  /// Workout 객체를 Firestore 형식으로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'sets': sets.map((set) => set.toFirestore()).toList(),
      'duration': duration,
      'timestamp': timestamp,
      'date': date,
      if (postureScore != null) 'postureScore': postureScore,
      if (formFeedback != null) 'formFeedback': formFeedback,
      if (assessmentVideoPath != null) 'assessmentVideoPath': assessmentVideoPath,
    };
  }
}
