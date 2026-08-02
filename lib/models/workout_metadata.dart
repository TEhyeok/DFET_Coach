/// 운동 메타데이터 모델
/// 로컬 갤러리 영상 파일에 주입되고 Firestore에 동기화되는 핵심 데이터
class WorkoutMetadata {
  final String id;
  final String exerciseType;
  final ExerciseIntensity intensity;
  final int durationSeconds;
  final int repCount;
  final DateTime timestamp;
  final String? localAssetId; // iOS: PHAsset ID, Android: MediaStore ID
  final CoachingStatus coachingStatus;

  WorkoutMetadata({
    required this.id,
    required this.exerciseType,
    required this.intensity,
    required this.durationSeconds,
    required this.repCount,
    required this.timestamp,
    this.localAssetId,
    CoachingStatus? coachingStatus,
  }) : coachingStatus = coachingStatus ?? CoachingStatus();

  /// 메타데이터 JSON 문자열로 변환 (파일 주입용)
  String toMetadataString() {
    return '''#DFET_META|v1.2|$id|$exerciseType|${intensity.name}|$durationSeconds|$repCount|${coachingStatus.nutritionLogged ? '1' : '0'}''';
  }

  /// 메타데이터 문자열 파싱
  static WorkoutMetadata? fromMetadataString(String raw) {
    if (!raw.startsWith('#DFET_META|')) return null;

    final parts = raw.split('|');
    if (parts.length < 8) return null;

    return WorkoutMetadata(
      id: parts[2],
      exerciseType: parts[3],
      intensity: ExerciseIntensity.values.firstWhere(
        (e) => e.name == parts[4],
        orElse: () => ExerciseIntensity.medium,
      ),
      durationSeconds: int.tryParse(parts[5]) ?? 0,
      repCount: int.tryParse(parts[6]) ?? 0,
      timestamp: DateTime.now(),
      coachingStatus: CoachingStatus(nutritionLogged: parts[7] == '1'),
    );
  }

  /// Firestore 저장용 Map
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'exerciseType': exerciseType,
      'intensity': intensity.index,
      'durationSeconds': durationSeconds,
      'repCount': repCount,
      'timestamp': timestamp.toIso8601String(),
      'localAssetId': localAssetId,
      'linkageStatus': coachingStatus.nutritionLogged ? 'COMPLETED' : 'PENDING',
    };
  }

  /// Firestore에서 복원
  factory WorkoutMetadata.fromFirestore(Map<String, dynamic> data) {
    return WorkoutMetadata(
      id: data['id'] ?? '',
      exerciseType: data['exerciseType'] ?? 'UNKNOWN',
      intensity: ExerciseIntensity.values[data['intensity'] ?? 1],
      durationSeconds: data['durationSeconds'] ?? 0,
      repCount: data['repCount'] ?? 0,
      timestamp: DateTime.tryParse(data['timestamp'] ?? '') ?? DateTime.now(),
      localAssetId: data['localAssetId'],
      coachingStatus: CoachingStatus(
        nutritionLogged: data['linkageStatus'] == 'COMPLETED',
      ),
    );
  }

  /// 복사본 생성 (상태 업데이트용)
  WorkoutMetadata copyWith({
    String? localAssetId,
    CoachingStatus? coachingStatus,
  }) {
    return WorkoutMetadata(
      id: id,
      exerciseType: exerciseType,
      intensity: intensity,
      durationSeconds: durationSeconds,
      repCount: repCount,
      timestamp: timestamp,
      localAssetId: localAssetId ?? this.localAssetId,
      coachingStatus: coachingStatus ?? this.coachingStatus,
    );
  }
}

/// 운동 강도 레벨
enum ExerciseIntensity {
  low, // 저강도: 요가, 스트레칭
  medium, // 중강도: 일반 웨이트
  high, // 고강도: HIIT, 대근육 고반복
}

/// 코칭 연동 상태
class CoachingStatus {
  final bool nutritionLogged;
  final bool restLogged;

  CoachingStatus({
    this.nutritionLogged = false,
    this.restLogged = false,
  });

  CoachingStatus copyWith({bool? nutritionLogged, bool? restLogged}) {
    return CoachingStatus(
      nutritionLogged: nutritionLogged ?? this.nutritionLogged,
      restLogged: restLogged ?? this.restLogged,
    );
  }
}
