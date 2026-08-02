import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/workout_metadata.dart';
import '../core/utils/app_logger.dart';

/// 로컬 미디어 메타데이터 관리 서비스
/// 특허 핵심 기술: 영상 파일에 운동 메타데이터 주입 및 추출
class LocalMetadataService {
  static const _uuid = Uuid();

  /// 운동 메타데이터 생성
  static WorkoutMetadata createMetadata({
    required String exerciseType,
    required ExerciseIntensity intensity,
    required int durationSeconds,
    required int repCount,
  }) {
    return WorkoutMetadata(
      id: _uuid.v4(),
      exerciseType: exerciseType,
      intensity: intensity,
      durationSeconds: durationSeconds,
      repCount: repCount,
      timestamp: DateTime.now(),
    );
  }

  /// 비디오 파일에 메타데이터 주입
  /// 현재 구현: 별도 사이드카 파일(.dfet) 방식 (크로스 플랫폼 호환성)
  /// 향후: Native 코드로 XMP/EXIF 직접 수정 가능
  static Future<bool> injectMetadata(
      File videoFile, WorkoutMetadata meta) async {
    try {
      final sidecarPath = '${videoFile.path}.dfet';
      final sidecarFile = File(sidecarPath);

      await sidecarFile.writeAsString(meta.toMetadataString());

      AppLogger.info(
          '[LocalMetadataService] 메타데이터 주입 완료: ${meta.exerciseType}');
      return true;
    } catch (e) {
      AppLogger.error('[LocalMetadataService] 메타데이터 주입 실패', e);
      return false;
    }
  }

  /// 비디오 파일에서 메타데이터 읽기
  static Future<WorkoutMetadata?> readMetadata(File videoFile) async {
    try {
      final sidecarPath = '${videoFile.path}.dfet';
      final sidecarFile = File(sidecarPath);

      if (!await sidecarFile.exists()) {
        return null;
      }

      final raw = await sidecarFile.readAsString();
      return WorkoutMetadata.fromMetadataString(raw);
    } catch (e) {
      AppLogger.error('[LocalMetadataService] 메타데이터 읽기 실패', e);
      return null;
    }
  }

  /// 메타데이터 업데이트 (코칭 상태 변경 시)
  static Future<bool> updateCoachingStatus(
    File videoFile, {
    bool? nutritionLogged,
    bool? restLogged,
  }) async {
    try {
      final existing = await readMetadata(videoFile);
      if (existing == null) return false;

      final updated = existing.copyWith(
        coachingStatus: existing.coachingStatus.copyWith(
          nutritionLogged: nutritionLogged,
          restLogged: restLogged,
        ),
      );

      return await injectMetadata(videoFile, updated);
    } catch (e) {
      AppLogger.error('[LocalMetadataService] 상태 업데이트 실패', e);
      return false;
    }
  }

  /// 영상-메타데이터 쌍 검증
  static Future<bool> hasValidMetadata(File videoFile) async {
    final meta = await readMetadata(videoFile);
    return meta != null;
  }
}
