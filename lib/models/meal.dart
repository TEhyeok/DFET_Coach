import 'package:intl/intl.dart';

class Meal {
  final String id;
  final String time;
  final String name;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final String date; // 날짜 문자열 (yyyy-MM-dd 형식)
  final Map<String, dynamic>? aiTokenUsage; // AI 토큰 사용량 정보

  Meal({
    required this.id,
    required this.time,
    required this.name,
    required this.calories,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    String? date,
    this.aiTokenUsage,
  }) : date = date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// 오늘 날짜 문자열 반환
  static String get todayString =>
      DateFormat('yyyy-MM-dd').format(DateTime.now());

  Meal copyWith({
    String? id,
    String? time,
    String? name,
    int? calories,
    int? protein,
    int? carbs,
    int? fat,
    String? date,
    Map<String, dynamic>? aiTokenUsage,
  }) {
    return Meal(
      id: id ?? this.id,
      time: time ?? this.time,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      date: date ?? this.date,
      aiTokenUsage: aiTokenUsage ?? this.aiTokenUsage,
    );
  }

  /// Firestore에서 Meal 객체 생성
  factory Meal.fromFirestore(Map<String, dynamic> data, String id) {
    return Meal(
      id: id,
      time: data['time'] as String? ?? '',
      name: data['name'] as String? ?? '',
      calories: data['calories'] as int? ?? 0,
      protein: data['protein'] as int? ?? 0,
      carbs: data['carbs'] as int? ?? 0,
      fat: data['fat'] as int? ?? 0,
      date: data['date'] as String? ??
          DateFormat('yyyy-MM-dd').format(DateTime.now()),
      aiTokenUsage: data['aiTokenUsage'] as Map<String, dynamic>?,
    );
  }

  /// Meal 객체를 Firestore 형식으로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'time': time,
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'date': date,
      if (aiTokenUsage != null) 'aiTokenUsage': aiTokenUsage,
    };
  }
}
