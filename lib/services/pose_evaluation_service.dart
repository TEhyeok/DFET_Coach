import 'dart:math' as math;
import 'dart:math' show Point;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// 운동 타입
enum ExerciseType { squat, pushup, plank, none }

/// 평가 결과
class EvaluationResult {
  final double score;
  final String feedback;
  final bool isGoodForm;

  const EvaluationResult({
    required this.score,
    required this.feedback,
    required this.isGoodForm,
  });

  static const empty = EvaluationResult(
    score: 0,
    feedback: '',
    isGoodForm: false,
  );
}

/// 자세 평가 전용 서비스 (순수 로직만 담당)
class PoseEvaluationService {
  /// 스쿼트 평가
  EvaluationResult evaluateSquat(Pose pose) {
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    if (leftHip == null || leftKnee == null || leftAnkle == null ||
        rightHip == null || rightKnee == null || rightAnkle == null) {
      return const EvaluationResult(
        score: 0,
        feedback: '하체가 보이지 않습니다',
        isGoodForm: false,
      );
    }

    // 무릎 각도 계산
    final leftAngle = _calculateAngle(
      Point(leftHip.x.toDouble(), leftHip.y.toDouble()),
      Point(leftKnee.x.toDouble(), leftKnee.y.toDouble()),
      Point(leftAnkle.x.toDouble(), leftAnkle.y.toDouble()),
    );
    final rightAngle = _calculateAngle(
      Point(rightHip.x.toDouble(), rightHip.y.toDouble()),
      Point(rightKnee.x.toDouble(), rightKnee.y.toDouble()),
      Point(rightAnkle.x.toDouble(), rightAnkle.y.toDouble()),
    );

    final avgAngle = (leftAngle + rightAngle) / 2;

    // 평가
    double score;
    String feedback;

    if (avgAngle < 70) {
      score = 70;
      feedback = '너무 깊습니다';
    } else if (avgAngle > 120) {
      score = 60;
      feedback = '더 내려가세요';
    } else if (avgAngle >= 80 && avgAngle <= 100) {
      score = 100;
      feedback = '완벽합니다!';
    } else {
      score = 85;
      feedback = '좋습니다';
    }

    // 무릎 정렬 체크
    if ((leftKnee.x - leftAnkle.x).abs() > 50) {
      feedback += ' (무릎 정렬 주의)';
      score -= 10;
    }

    return EvaluationResult(
      score: score.clamp(0, 100),
      feedback: feedback,
      isGoodForm: score >= 80,
    );
  }

  /// 푸시업 평가
  EvaluationResult evaluatePushup(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];

    if (leftShoulder == null || leftElbow == null ||
        leftWrist == null || leftHip == null) {
      return const EvaluationResult(
        score: 0,
        feedback: '상체가 보이지 않습니다',
        isGoodForm: false,
      );
    }

    // 팔꿈치 각도
    final elbowAngle = _calculateAngle(
      Point(leftShoulder.x.toDouble(), leftShoulder.y.toDouble()),
      Point(leftElbow.x.toDouble(), leftElbow.y.toDouble()),
      Point(leftWrist.x.toDouble(), leftWrist.y.toDouble()),
    );

    double score;
    String feedback;

    if (elbowAngle < 60) {
      score = 70;
      feedback = '더 내려가세요';
    } else if (elbowAngle > 100) {
      score = 75;
      feedback = '팔을 더 구부리세요';
    } else {
      score = 90;
      feedback = '좋은 팔꿈치 각도';
    }

    // 몸 정렬 체크
    final bodyDiff = (leftShoulder.y - leftHip.y).abs();
    if (bodyDiff > 30) {
      feedback += ' (몸 일직선 유지)';
      score -= 15;
    }

    return EvaluationResult(
      score: score.clamp(0, 100),
      feedback: feedback,
      isGoodForm: score >= 80,
    );
  }

  /// 플랭크 평가
  EvaluationResult evaluatePlank(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    if (leftShoulder == null || leftHip == null || leftAnkle == null ||
        rightShoulder == null || rightHip == null || rightAnkle == null) {
      return const EvaluationResult(
        score: 0,
        feedback: '전신이 보이지 않습니다',
        isGoodForm: false,
      );
    }

    // 몸 중심점
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

    final bodyAngle = _calculateAngle(shoulderCenter, hipCenter, ankleCenter);

    double score;
    String feedback;

    if (bodyAngle > 170 && bodyAngle < 190) {
      score = 100;
      feedback = '완벽한 플랭크!';
    } else if (bodyAngle < 160) {
      score = 70;
      feedback = '엉덩이가 너무 높습니다';
    } else if (bodyAngle > 200) {
      score = 70;
      feedback = '엉덩이가 너무 낮습니다';
    } else {
      score = 85;
      feedback = '좋은 자세입니다';
    }

    return EvaluationResult(
      score: score,
      feedback: feedback,
      isGoodForm: score >= 80,
    );
  }

  /// 운동 타입에 따른 평가
  EvaluationResult evaluate(Pose pose, ExerciseType type) {
    switch (type) {
      case ExerciseType.squat:
        return evaluateSquat(pose);
      case ExerciseType.pushup:
        return evaluatePushup(pose);
      case ExerciseType.plank:
        return evaluatePlank(pose);
      default:
        return EvaluationResult.empty;
    }
  }

  /// 필수 랜드마크 체크
  bool hasRequiredLandmarks(Pose pose, ExerciseType type) {
    final required = _getRequiredLandmarks(type);
    for (final landmark in required) {
      if (pose.landmarks[landmark] == null) return false;
      if (pose.landmarks[landmark]!.likelihood < 0.5) return false;
    }
    return true;
  }

  List<PoseLandmarkType> _getRequiredLandmarks(ExerciseType type) {
    switch (type) {
      case ExerciseType.squat:
        return [
          PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip,
          PoseLandmarkType.leftKnee,
          PoseLandmarkType.rightKnee,
          PoseLandmarkType.leftAnkle,
          PoseLandmarkType.rightAnkle,
        ];
      case ExerciseType.pushup:
        return [
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.leftElbow,
          PoseLandmarkType.leftWrist,
          PoseLandmarkType.leftHip,
        ];
      case ExerciseType.plank:
        return [
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.rightShoulder,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip,
          PoseLandmarkType.leftAnkle,
          PoseLandmarkType.rightAnkle,
        ];
      default:
        return [];
    }
  }

  double _calculateAngle(Point<double> a, Point<double> b, Point<double> c) {
    final radians = math.atan2(c.y - b.y, c.x - b.x) -
        math.atan2(a.y - b.y, a.x - b.x);
    var angle = (radians * 180 / math.pi).abs();
    if (angle > 180) angle = 360 - angle;
    return angle;
  }
}
