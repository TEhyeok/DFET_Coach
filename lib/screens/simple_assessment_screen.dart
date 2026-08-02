import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';

import '../services/simple_pose_camera.dart';
import '../services/pose_evaluation_service.dart';
import '../state/pose_assessment_state.dart';
import '../theme/tokens.dart';

/// 간소화된 자세 평가 화면
class SimpleAssessmentScreen extends ConsumerStatefulWidget {
  const SimpleAssessmentScreen({super.key});

  @override
  ConsumerState<SimpleAssessmentScreen> createState() =>
      _SimpleAssessmentScreenState();
}

class _SimpleAssessmentScreenState
    extends ConsumerState<SimpleAssessmentScreen> {
  SimplePoseCamera? _camera;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _camera = SimplePoseCamera();
    await _camera!.initialize();

    if (!mounted) return;

    // 포즈 스트림 구독
    _camera!.poseStream.listen((pose) {
      if (!mounted) return;

      final exercise = ref.read(selectedExerciseProvider);
      if (exercise == ExerciseType.none) return;

      final service = ref.read(evaluationServiceProvider);

      if (pose != null && service.hasRequiredLandmarks(pose, exercise)) {
        ref.read(isPoseDetectedProvider.notifier).state = true;
        final result = service.evaluate(pose, exercise);
        ref.read(evaluationResultProvider.notifier).state = result;

        // 최고 점수 업데이트
        final best = ref.read(sessionBestScoreProvider);
        if (result.score > best) {
          ref.read(sessionBestScoreProvider.notifier).state = result.score;
        }
      } else {
        ref.read(isPoseDetectedProvider.notifier).state = false;
      }
    });

    _camera!.errorStream.listen((error) {
      if (mounted) {
        setState(() => _error = error);
      }
    });

    if (_camera!.isReady && mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedExercise = ref.watch(selectedExerciseProvider);
    final result = ref.watch(evaluationResultProvider);
    final isPoseDetected = ref.watch(isPoseDetectedProvider);
    final bestScore = ref.watch(sessionBestScoreProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 카메라 미리보기
          if (!_isLoading && _camera?.controller != null)
            Positioned.fill(
              child: CameraPreview(_camera!.controller!),
            ),

          // 로딩
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.brandPrimary),
            ),

          // 에러
          if (_error != null)
            Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),

          // 상단 바
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  if (bestScore > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(150),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '최고: ${bestScore.toInt()}점',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 운동 선택 (중앙)
          if (selectedExercise == ExerciseType.none)
            Center(
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(200),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '운동 선택',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildExerciseButton(
                        ExerciseType.squat, '스쿼트', Icons.fitness_center),
                    const SizedBox(height: 12),
                    _buildExerciseButton(
                        ExerciseType.pushup, '푸시업', Icons.sports_gymnastics),
                    const SizedBox(height: 12),
                    _buildExerciseButton(
                        ExerciseType.plank, '플랭크', Icons.self_improvement),
                  ],
                ),
              ),
            ),

          // 하단 피드백
          if (selectedExercise != ExerciseType.none)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withAlpha(220),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 포즈 상태
                    if (!isPoseDetected)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(150),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.warning, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              '전신이 보이도록 위치를 조정하세요',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),

                    // 점수
                    if (isPoseDetected) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 24),
                        decoration: BoxDecoration(
                          color: _getScoreColor(result.score).withAlpha(180),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${result.score.toInt()}점',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              result.feedback,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // 운동 변경 버튼
                    TextButton.icon(
                      onPressed: () {
                        ref.read(selectedExerciseProvider.notifier).state =
                            ExerciseType.none;
                        ref.read(sessionBestScoreProvider.notifier).state = 0;
                        ref.read(evaluationResultProvider.notifier).state =
                            EvaluationResult.empty;
                      },
                      icon: const Icon(Icons.swap_horiz, color: Colors.white70),
                      label: const Text(
                        '운동 변경',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExerciseButton(ExerciseType type, String name, IconData icon) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          ref.read(selectedExerciseProvider.notifier).state = type;
        },
        icon: Icon(icon),
        label: Text(name),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.orange;
    return Colors.red;
  }
}
