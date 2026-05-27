import 'dart:io';
import 'dart:math' as math;
import 'dart:math' show Point;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../core/utils/app_logger.dart';
import 'pose_detection_service.dart';

/// Analysis result for a video
class VideoAnalysisResult {
  final double averageScore;
  final String feedback;
  final int analyzedFrames;
  final int totalFrames;
  final List<FrameAnalysis> frameResults;
  final ExerciseType exerciseType;

  VideoAnalysisResult({
    required this.averageScore,
    required this.feedback,
    required this.analyzedFrames,
    required this.totalFrames,
    required this.frameResults,
    required this.exerciseType,
  });
}

/// Analysis result for a single frame
class FrameAnalysis {
  final int frameIndex;
  final double score;
  final String feedback;
  final bool poseDetected;

  FrameAnalysis({
    required this.frameIndex,
    required this.score,
    required this.feedback,
    required this.poseDetected,
  });
}

/// Service to analyze exercise videos for posture evaluation
class VideoPoseAnalyzer {
  PoseDetector? _poseDetector;

  Future<void> initialize() async {
    final options = PoseDetectorOptions(
      mode: PoseDetectionMode.single,
      model: PoseDetectionModel.accurate,
    );
    _poseDetector = PoseDetector(options: options);
    AppLogger.info('[VideoPoseAnalyzer] Initialized');
  }

  Future<void> dispose() async {
    await _poseDetector?.close();
    _poseDetector = null;
    AppLogger.info('[VideoPoseAnalyzer] Disposed');
  }

  /// Analyze a video file for exercise posture
  Future<VideoAnalysisResult> analyzeVideo({
    required String videoPath,
    required ExerciseType exerciseType,
    int maxFrames = 10,
    Function(int current, int total)? onProgress,
  }) async {
    if (_poseDetector == null) {
      throw Exception('VideoPoseAnalyzer not initialized');
    }

    AppLogger.info('[VideoPoseAnalyzer] Starting analysis: $videoPath');
    AppLogger.info('[VideoPoseAnalyzer] Exercise type: $exerciseType');

    final List<FrameAnalysis> frameResults = [];
    int analyzedCount = 0;

    // Extract frames from video
    for (int i = 0; i < maxFrames; i++) {
      onProgress?.call(i + 1, maxFrames);

      try {
        // Calculate timestamp for this frame (spread evenly across video)
        // Assuming ~10 second video, extract frames at different times
        final timeMs = (i * 1000); // Every second

        final thumbnailPath = await VideoThumbnail.thumbnailFile(
          video: videoPath,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 720,
          quality: 85,
          timeMs: timeMs,
        );

        if (thumbnailPath == null) {
          AppLogger.warning('[VideoPoseAnalyzer] Failed to extract frame $i');
          continue;
        }

        // Analyze the frame
        final frameResult = await _analyzeFrame(
          imagePath: thumbnailPath,
          frameIndex: i,
          exerciseType: exerciseType,
        );

        frameResults.add(frameResult);
        if (frameResult.poseDetected) {
          analyzedCount++;
        }

        // Clean up thumbnail file
        try {
          await File(thumbnailPath).delete();
        } catch (e) {
          // Ignore cleanup errors
        }

        AppLogger.debug('[VideoPoseAnalyzer] Frame $i: score=${frameResult.score}');
      } catch (e) {
        AppLogger.error('[VideoPoseAnalyzer] Error analyzing frame $i', e);
      }
    }

    // Calculate average score
    double totalScore = 0;
    int validScores = 0;
    for (final result in frameResults) {
      if (result.poseDetected && result.score > 0) {
        totalScore += result.score;
        validScores++;
      }
    }

    final averageScore = validScores > 0 ? totalScore / validScores : 0.0;

    // Generate overall feedback
    final feedback = _generateOverallFeedback(
      averageScore,
      exerciseType,
      analyzedCount,
      maxFrames,
    );

    AppLogger.info('[VideoPoseAnalyzer] Analysis complete: avg score=$averageScore');

    return VideoAnalysisResult(
      averageScore: averageScore,
      feedback: feedback,
      analyzedFrames: analyzedCount,
      totalFrames: maxFrames,
      frameResults: frameResults,
      exerciseType: exerciseType,
    );
  }

  Future<FrameAnalysis> _analyzeFrame({
    required String imagePath,
    required int frameIndex,
    required ExerciseType exerciseType,
  }) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final poses = await _poseDetector!.processImage(inputImage);

      if (poses.isEmpty) {
        return FrameAnalysis(
          frameIndex: frameIndex,
          score: 0,
          feedback: '포즈 감지 안됨',
          poseDetected: false,
        );
      }

      final pose = poses.first;
      final evaluation = _evaluatePose(pose, exerciseType);

      return FrameAnalysis(
        frameIndex: frameIndex,
        score: evaluation.score,
        feedback: evaluation.feedback,
        poseDetected: true,
      );
    } catch (e) {
      AppLogger.error('[VideoPoseAnalyzer] Frame analysis error', e);
      return FrameAnalysis(
        frameIndex: frameIndex,
        score: 0,
        feedback: '분석 오류',
        poseDetected: false,
      );
    }
  }

  _PoseEvaluation _evaluatePose(Pose pose, ExerciseType exerciseType) {
    switch (exerciseType) {
      case ExerciseType.squat:
        return _evaluateSquat(pose);
      case ExerciseType.pushup:
        return _evaluatePushup(pose);
      case ExerciseType.plank:
        return _evaluatePlank(pose);
      default:
        return _PoseEvaluation(score: 0, feedback: '알 수 없는 운동');
    }
  }

  _PoseEvaluation _evaluateSquat(Pose pose) {
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    if (leftHip == null || leftKnee == null || leftAnkle == null ||
        rightHip == null || rightKnee == null || rightAnkle == null) {
      return _PoseEvaluation(score: 0, feedback: '하체가 보이지 않습니다');
    }

    // Calculate knee angles
    final leftKneeAngle = _calculateAngle(
      Point(leftHip.x.toDouble(), leftHip.y.toDouble()),
      Point(leftKnee.x.toDouble(), leftKnee.y.toDouble()),
      Point(leftAnkle.x.toDouble(), leftAnkle.y.toDouble()),
    );
    final rightKneeAngle = _calculateAngle(
      Point(rightHip.x.toDouble(), rightHip.y.toDouble()),
      Point(rightKnee.x.toDouble(), rightKnee.y.toDouble()),
      Point(rightAnkle.x.toDouble(), rightAnkle.y.toDouble()),
    );

    final avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2;

    double score = 100.0;
    String feedback = '';

    // Evaluate squat depth and form
    if (avgKneeAngle < 60) {
      feedback = '너무 깊게 내려갔습니다';
      score = 70;
    } else if (avgKneeAngle > 130) {
      feedback = '더 깊게 내려가세요';
      score = 60;
    } else if (avgKneeAngle >= 80 && avgKneeAngle <= 100) {
      feedback = '완벽한 자세입니다!';
      score = 100;
    } else if (avgKneeAngle >= 70 && avgKneeAngle <= 110) {
      feedback = '좋은 자세입니다';
      score = 85;
    } else {
      feedback = '자세를 조정해주세요';
      score = 75;
    }

    // Check knee alignment
    final leftKneeX = leftKnee.x;
    final leftAnkleX = leftAnkle.x;
    if ((leftKneeX - leftAnkleX).abs() > 50) {
      feedback += ' (무릎 정렬 주의)';
      score -= 10;
    }

    return _PoseEvaluation(score: score, feedback: feedback);
  }

  _PoseEvaluation _evaluatePushup(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (leftShoulder == null || leftElbow == null || leftWrist == null ||
        rightShoulder == null || rightElbow == null || rightWrist == null ||
        leftHip == null || rightHip == null) {
      return _PoseEvaluation(score: 0, feedback: '상체가 보이지 않습니다');
    }

    // Calculate elbow angles
    final leftElbowAngle = _calculateAngle(
      Point(leftShoulder.x.toDouble(), leftShoulder.y.toDouble()),
      Point(leftElbow.x.toDouble(), leftElbow.y.toDouble()),
      Point(leftWrist.x.toDouble(), leftWrist.y.toDouble()),
    );
    final rightElbowAngle = _calculateAngle(
      Point(rightShoulder.x.toDouble(), rightShoulder.y.toDouble()),
      Point(rightElbow.x.toDouble(), rightElbow.y.toDouble()),
      Point(rightWrist.x.toDouble(), rightWrist.y.toDouble()),
    );

    final avgElbowAngle = (leftElbowAngle + rightElbowAngle) / 2;

    double score = 100.0;
    String feedback = '';

    // Check body alignment
    final shoulderCenterY = (leftShoulder.y + rightShoulder.y) / 2;
    final hipCenterY = (leftHip.y + rightHip.y) / 2;
    final bodyAngle = (shoulderCenterY - hipCenterY).abs();

    // Evaluate elbow angle
    if (avgElbowAngle < 60) {
      feedback = '더 내려가세요';
      score = 70;
    } else if (avgElbowAngle > 120) {
      feedback = '팔을 더 구부리세요';
      score = 75;
    } else if (avgElbowAngle >= 80 && avgElbowAngle <= 100) {
      feedback = '완벽한 팔꿈치 각도입니다!';
      score = 100;
    } else {
      feedback = '좋은 자세입니다';
      score = 85;
    }

    // Check body alignment
    if (bodyAngle > 30) {
      feedback += ' (몸통 정렬 주의)';
      score -= 15;
    }

    return _PoseEvaluation(score: score, feedback: feedback);
  }

  _PoseEvaluation _evaluatePlank(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    if (leftShoulder == null || rightShoulder == null ||
        leftHip == null || rightHip == null ||
        leftAnkle == null || rightAnkle == null) {
      return _PoseEvaluation(score: 0, feedback: '전신이 보이지 않습니다');
    }

    // Calculate body line angle
    final shoulderCenter = Point<double>(
      (leftShoulder.x + rightShoulder.x) / 2,
      (leftShoulder.y + rightShoulder.y) / 2,
    );
    final hipCenter = Point<double>(
      (leftHip.x + rightHip.x) / 2,
      (leftHip.y + rightHip.y) / 2,
    );
    final ankleCenter = Point<double>(
      (leftAnkle.x + rightAnkle.x) / 2,
      (leftAnkle.y + rightAnkle.y) / 2,
    );

    final bodyLineAngle = _calculateAngle(shoulderCenter, hipCenter, ankleCenter);

    double score = 100.0;
    String feedback = '';

    if (bodyLineAngle > 170 && bodyLineAngle < 190) {
      feedback = '완벽한 플랭크 자세입니다!';
      score = 100;
    } else if (bodyLineAngle < 160) {
      feedback = '엉덩이가 너무 높습니다';
      score = 70;
    } else if (bodyLineAngle > 200) {
      feedback = '엉덩이가 너무 낮습니다';
      score = 70;
    } else {
      feedback = '좋은 자세입니다';
      score = 85;
    }

    return _PoseEvaluation(score: score, feedback: feedback);
  }

  double _calculateAngle(Point<double> a, Point<double> b, Point<double> c) {
    final radians = math.atan2(c.y - b.y, c.x - b.x) -
        math.atan2(a.y - b.y, a.x - b.x);
    var angle = (radians * 180 / math.pi).abs();

    if (angle > 180) {
      angle = 360 - angle;
    }

    return angle;
  }

  String _generateOverallFeedback(
    double averageScore,
    ExerciseType exerciseType,
    int analyzedFrames,
    int totalFrames,
  ) {
    String exerciseName;
    switch (exerciseType) {
      case ExerciseType.squat:
        exerciseName = '스쿼트';
        break;
      case ExerciseType.pushup:
        exerciseName = '푸시업';
        break;
      case ExerciseType.plank:
        exerciseName = '플랭크';
        break;
      default:
        exerciseName = '운동';
    }

    if (analyzedFrames < totalFrames / 2) {
      return '영상에서 자세를 충분히 감지하지 못했습니다.\n'
          '전신이 잘 보이는 위치에서 다시 촬영해주세요.';
    }

    if (averageScore >= 90) {
      return '훌륭합니다! $exerciseName 자세가 매우 좋습니다.\n'
          '이 자세를 유지하며 운동을 계속하세요.';
    } else if (averageScore >= 75) {
      return '좋은 $exerciseName 자세입니다.\n'
          '몇 가지 세부 사항을 개선하면 더 효과적인 운동이 될 수 있습니다.';
    } else if (averageScore >= 60) {
      return '$exerciseName 자세에 개선이 필요합니다.\n'
          '올바른 자세 가이드를 참고하여 교정해주세요.';
    } else {
      return '$exerciseName 자세를 다시 확인해주세요.\n'
          '부상 방지를 위해 올바른 자세를 익힌 후 운동하세요.';
    }
  }
}

class _PoseEvaluation {
  final double score;
  final String feedback;

  _PoseEvaluation({required this.score, required this.feedback});
}
