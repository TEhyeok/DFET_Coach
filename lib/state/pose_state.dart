import 'package:flutter_riverpod/flutter_riverpod.dart';

// Pose Detection State
class PostureAssessment {
  final String exerciseType;
  final double score;
  final String feedback;
  final DateTime timestamp;

  PostureAssessment({
    required this.exerciseType,
    required this.score,
    required this.feedback,
    required this.timestamp,
  });
}

class PostureAssessmentNotifier extends StateNotifier<PostureAssessment?> {
  PostureAssessmentNotifier() : super(null);

  void updateAssessment(PostureAssessment assessment) {
    state = assessment;
  }

  void clearAssessment() {
    state = null;
  }
}

final postureAssessmentProvider =
    StateNotifierProvider<PostureAssessmentNotifier, PostureAssessment?>((ref) {
  return PostureAssessmentNotifier();
});

// Exercise Form Score Provider
final exerciseFormScoreProvider = StateProvider<double>((ref) => 0.0);

// Pose Detection Results Provider
class PoseDetectionResults {
  final List<Map<String, dynamic>> keypoints;
  final double confidence;

  PoseDetectionResults({
    required this.keypoints,
    required this.confidence,
  });
}

final poseDetectionResultsProvider =
    StateProvider<PoseDetectionResults?>((ref) => null);
