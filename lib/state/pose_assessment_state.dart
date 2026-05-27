import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/pose_evaluation_service.dart';

/// 현재 선택된 운동 타입
final selectedExerciseProvider = StateProvider<ExerciseType>((ref) {
  return ExerciseType.none;
});

/// 평가 결과 상태
final evaluationResultProvider = StateProvider<EvaluationResult>((ref) {
  return EvaluationResult.empty;
});

/// 평가 활성화 상태
final isAssessmentActiveProvider = StateProvider<bool>((ref) => false);

/// 포즈 감지 상태 (전신 보이는지)
final isPoseDetectedProvider = StateProvider<bool>((ref) => false);

/// 평가 서비스 Provider
final evaluationServiceProvider = Provider<PoseEvaluationService>((ref) {
  return PoseEvaluationService();
});

/// 평가 히스토리 (세션 내 최고 점수)
final sessionBestScoreProvider = StateProvider<double>((ref) => 0);

/// 평가 카운트
final evaluationCountProvider = StateProvider<int>((ref) => 0);
