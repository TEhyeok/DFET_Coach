import 'dart:math' as math;
import 'dart:math' show Point;
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter/services.dart';
import '../models/user_calibration.dart';

// Exercise types
enum ExerciseType { squat, pushup, plank, none }

// 자세 준비 상태
class PoseReadinessStatus {
  final bool isReady;
  final double confidence;
  final List<String> missingParts;
  final String guidanceMessage;
  final double lightingQuality; // 0.0 ~ 1.0, higher is better

  PoseReadinessStatus({
    required this.isReady,
    required this.confidence,
    required this.missingParts,
    required this.guidanceMessage,
    this.lightingQuality = 1.0,
  });
}

class PoseDetectionService {
  PoseDetector? _poseDetector;
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isDetecting = false;

  // Callback functions
  Function(List<Pose>)? onPoseDetected;
  Function(String)? onError;
  Function(double)? onFormScoreUpdate;
  Function(String)? onFeedbackUpdate;
  Function(PoseReadinessStatus)? onReadinessUpdate;

  ExerciseType currentExercise = ExerciseType.none;
  bool isEvaluationActive = false; // 평가 활성화 상태

  // Lighting tracking
  double _lastLightingQuality = 1.0;

  // User calibration
  UserCalibration? _userCalibration;
  Function(UserCalibration)? onCalibrationComplete;
  bool _isCalibrating = false;
  final List<Pose> _calibrationPoses = [];

  Future<void> initialize() async {
    try {
      // Initialize pose detector
      final options = PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.accurate,
      );
      _poseDetector = PoseDetector(options: options);

      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        throw Exception('No cameras available');
      }
    } catch (e) {
      onError?.call('Failed to initialize pose detection: $e');
    }
  }

  Future<void> startCamera({int cameraIndex = 0}) async {
    if (_cameras == null || _cameras!.isEmpty) {
      onError?.call('No cameras available');
      return;
    }

    try {
      final camera = _cameras![cameraIndex];
      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      await _cameraController!.startImageStream(_processCameraImage);
    } catch (e) {
      onError?.call('Failed to start camera: $e');
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      // Calculate lighting quality first
      _lastLightingQuality = _calculateLightingQuality(image);

      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      final InputImageRotation imageRotation = _getImageRotation();

      final InputImageFormat inputImageFormat =
          InputImageFormatValue.fromRawValue(
                image.format.raw,
              ) ??
              InputImageFormat.nv21;

      final InputImageMetadata inputImageData = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      final InputImage inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: inputImageData,
      );

      final poses = await _poseDetector!.processImage(inputImage);

      if (poses.isNotEmpty) {
        onPoseDetected?.call(poses);

        // 준비 상태 체크 (항상 실행)
        final readinessStatus = _checkReadiness(poses.first);
        onReadinessUpdate?.call(readinessStatus);

        // 평가가 활성화된 경우에만 자세 평가 수행
        if (isEvaluationActive) {
          _evaluatePose(poses.first);
        }
      } else {
        // 포즈가 감지되지 않음
        onReadinessUpdate?.call(PoseReadinessStatus(
          isReady: false,
          confidence: 0,
          missingParts: ['전신'],
          guidanceMessage: _lastLightingQuality < 0.3
              ? '조명이 너무 어둡습니다. 밝은 곳으로 이동해주세요.'
              : '카메라에 전신이 보이도록 위치를 조정해주세요',
          lightingQuality: _lastLightingQuality,
        ));
      }
    } catch (e) {
      onError?.call('Error processing image: $e');
    }

    _isDetecting = false;
  }

  /// Calculate image brightness/lighting quality from camera image
  /// Returns value between 0.0 (very dark) and 1.0 (well lit)
  double _calculateLightingQuality(CameraImage image) {
    try {
      // Use Y plane (luminance) from YUV format
      if (image.planes.isEmpty) return 1.0;

      final yPlane = image.planes[0];
      final bytes = yPlane.bytes;

      // Sample pixels for performance (every 50th pixel)
      int totalBrightness = 0;
      int sampleCount = 0;
      const sampleInterval = 50;

      for (int i = 0; i < bytes.length; i += sampleInterval) {
        totalBrightness += bytes[i];
        sampleCount++;
      }

      if (sampleCount == 0) return 1.0;

      // Average brightness (0-255)
      final avgBrightness = totalBrightness / sampleCount;

      // Convert to 0-1 scale with thresholds
      // < 50: very dark (quality < 0.3)
      // 50-100: dim (quality 0.3-0.6)
      // 100-180: good (quality 0.6-0.9)
      // > 180: bright (quality 0.9-1.0)
      if (avgBrightness < 50) {
        return (avgBrightness / 50) * 0.3;
      } else if (avgBrightness < 100) {
        return 0.3 + ((avgBrightness - 50) / 50) * 0.3;
      } else if (avgBrightness < 180) {
        return 0.6 + ((avgBrightness - 100) / 80) * 0.3;
      } else {
        return 0.9 + ((avgBrightness - 180) / 75) * 0.1;
      }
    } catch (e) {
      // If calculation fails, assume lighting is OK
      return 1.0;
    }
  }

  InputImageRotation _getImageRotation() {
    if (_cameraController == null) return InputImageRotation.rotation0deg;

    final sensorOrientation = _cameraController!.description.sensorOrientation;

    InputImageRotation? rotation;
    switch (sensorOrientation) {
      case 0:
        rotation = InputImageRotation.rotation0deg;
        break;
      case 90:
        rotation = InputImageRotation.rotation90deg;
        break;
      case 180:
        rotation = InputImageRotation.rotation180deg;
        break;
      case 270:
        rotation = InputImageRotation.rotation270deg;
        break;
      default:
        rotation = InputImageRotation.rotation0deg;
    }

    return rotation;
  }

  /// 자세 준비 상태 체크
  PoseReadinessStatus _checkReadiness(Pose pose) {
    List<String> missingParts = [];
    double totalConfidence = 0;
    int requiredCount = 0;

    // 운동별 필요한 랜드마크 체크
    List<PoseLandmarkType> requiredLandmarks = [];

    switch (currentExercise) {
      case ExerciseType.squat:
        requiredLandmarks = [
          PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip,
          PoseLandmarkType.leftKnee,
          PoseLandmarkType.rightKnee,
          PoseLandmarkType.leftAnkle,
          PoseLandmarkType.rightAnkle,
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.rightShoulder,
        ];
        break;
      case ExerciseType.pushup:
        requiredLandmarks = [
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.rightShoulder,
          PoseLandmarkType.leftElbow,
          PoseLandmarkType.rightElbow,
          PoseLandmarkType.leftWrist,
          PoseLandmarkType.rightWrist,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip,
        ];
        break;
      case ExerciseType.plank:
        requiredLandmarks = [
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.rightShoulder,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip,
          PoseLandmarkType.leftAnkle,
          PoseLandmarkType.rightAnkle,
        ];
        break;
      default:
        // 기본: 주요 관절 체크
        requiredLandmarks = [
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.rightShoulder,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip,
        ];
    }

    // 각 랜드마크 체크
    Map<String, String> landmarkNames = {
      'leftShoulder': '왼쪽 어깨',
      'rightShoulder': '오른쪽 어깨',
      'leftElbow': '왼쪽 팔꿈치',
      'rightElbow': '오른쪽 팔꿈치',
      'leftWrist': '왼쪽 손목',
      'rightWrist': '오른쪽 손목',
      'leftHip': '왼쪽 엉덩이',
      'rightHip': '오른쪽 엉덩이',
      'leftKnee': '왼쪽 무릎',
      'rightKnee': '오른쪽 무릎',
      'leftAnkle': '왼쪽 발목',
      'rightAnkle': '오른쪽 발목',
    };

    for (final landmarkType in requiredLandmarks) {
      final landmark = pose.landmarks[landmarkType];
      requiredCount++;

      if (landmark == null) {
        final name = landmarkNames[landmarkType.name] ?? landmarkType.name;
        missingParts.add(name);
      } else {
        // 신뢰도가 낮은 경우도 체크 (0.5 미만)
        if (landmark.likelihood < 0.5) {
          final name = landmarkNames[landmarkType.name] ?? landmarkType.name;
          missingParts.add('$name (불명확)');
        } else {
          totalConfidence += landmark.likelihood;
        }
      }
    }

    // 준비 상태 판단
    bool isReady = missingParts.isEmpty;
    double avgConfidence =
        requiredCount > 0 ? totalConfidence / requiredCount : 0;

    // Check lighting quality
    bool hasGoodLighting = _lastLightingQuality >= 0.5;

    // 가이드 메시지 생성
    String guidanceMessage;
    if (!hasGoodLighting && _lastLightingQuality < 0.3) {
      // Very dark - prioritize lighting message
      guidanceMessage = '조명이 너무 어둡습니다. 밝은 곳으로 이동해주세요.';
      isReady = false; // Can't be ready with very poor lighting
    } else if (isReady) {
      if (!hasGoodLighting) {
        guidanceMessage = '자세가 감지되었습니다. 조명을 더 밝게 해주시면 더 정확한 평가가 가능합니다.';
      } else if (avgConfidence > 0.8) {
        guidanceMessage = '준비 완료! 평가를 시작할 수 있습니다.';
      } else if (avgConfidence > 0.6) {
        guidanceMessage = '자세가 감지되었습니다. 카메라를 정면으로 향하게 해주세요.';
      } else {
        guidanceMessage = '자세가 감지되었습니다. 조명을 더 밝게 해주세요.';
      }
    } else {
      if (missingParts.length > 4) {
        guidanceMessage = '전신이 보이도록 뒤로 물러서주세요.';
      } else {
        final parts = missingParts.take(3).join(', ');
        guidanceMessage = '$parts이(가) 보이지 않습니다.';
      }
    }

    return PoseReadinessStatus(
      isReady: isReady,
      confidence: avgConfidence,
      missingParts: missingParts,
      guidanceMessage: guidanceMessage,
      lightingQuality: _lastLightingQuality,
    );
  }

  void _evaluatePose(Pose pose) {
    switch (currentExercise) {
      case ExerciseType.squat:
        _evaluateSquat(pose);
        break;
      case ExerciseType.pushup:
        _evaluatePushup(pose);
        break;
      case ExerciseType.plank:
        _evaluatePlank(pose);
        break;
      default:
        break;
    }
  }

  void _evaluateSquat(Pose pose) {
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    if (leftHip != null &&
        leftKnee != null &&
        leftAnkle != null &&
        rightHip != null &&
        rightKnee != null &&
        rightAnkle != null) {
      // Calculate knee angles
      final leftKneeAngle = _calculateAngle(
          Point(leftHip.x.toDouble(), leftHip.y.toDouble()),
          Point(leftKnee.x.toDouble(), leftKnee.y.toDouble()),
          Point(leftAnkle.x.toDouble(), leftAnkle.y.toDouble()));
      final rightKneeAngle = _calculateAngle(
          Point(rightHip.x.toDouble(), rightHip.y.toDouble()),
          Point(rightKnee.x.toDouble(), rightKnee.y.toDouble()),
          Point(rightAnkle.x.toDouble(), rightAnkle.y.toDouble()));

      // Average knee angle
      final avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2;

      // Get calibrated thresholds (or defaults)
      final targetAngle = getSquatTargetAngle();
      final minDepth = getMinSquatDepth();

      // Evaluate form using calibrated or default values
      double score = 100.0;
      String feedback = '';

      if (avgKneeAngle < minDepth - 20) {
        feedback = '너무 깊게 내려갔습니다';
        score = 70;
      } else if (avgKneeAngle > targetAngle + 30) {
        feedback = '더 깊게 내려가세요';
        score = 60;
      } else if (avgKneeAngle >= targetAngle - 10 &&
          avgKneeAngle <= targetAngle + 10) {
        feedback = '완벽한 자세입니다!';
        score = 100;
      } else if (avgKneeAngle >= minDepth && avgKneeAngle <= targetAngle + 20) {
        feedback = '좋은 자세입니다';
        score = 85;
      } else {
        feedback = '자세를 조정해주세요';
        score = 75;
      }

      // Add calibration hint if not calibrated
      if (!hasValidCalibration) {
        feedback += '\n(개인 보정 적용 시 더 정확한 평가 가능)';
      }

      // Check knee alignment
      final leftKneeX = leftKnee.x;
      final leftAnkleX = leftAnkle.x;
      if ((leftKneeX - leftAnkleX).abs() > 50) {
        feedback += '\n무릎이 발끝을 넘어갔습니다';
        score -= 15;
      }

      onFormScoreUpdate?.call(score);
      onFeedbackUpdate?.call(feedback);
    }
  }

  void _evaluatePushup(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];

    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (leftShoulder != null &&
        leftElbow != null &&
        leftWrist != null &&
        rightShoulder != null &&
        rightElbow != null &&
        rightWrist != null &&
        leftHip != null &&
        rightHip != null) {
      // Calculate elbow angles
      final leftElbowAngle = _calculateAngle(
          Point(leftShoulder.x.toDouble(), leftShoulder.y.toDouble()),
          Point(leftElbow.x.toDouble(), leftElbow.y.toDouble()),
          Point(leftWrist.x.toDouble(), leftWrist.y.toDouble()));
      final rightElbowAngle = _calculateAngle(
          Point(rightShoulder.x.toDouble(), rightShoulder.y.toDouble()),
          Point(rightElbow.x.toDouble(), rightElbow.y.toDouble()),
          Point(rightWrist.x.toDouble(), rightWrist.y.toDouble()));

      final avgElbowAngle = (leftElbowAngle + rightElbowAngle) / 2;

      // Check body alignment
      final shoulderCenterY = (leftShoulder.y + rightShoulder.y) / 2;
      final hipCenterY = (leftHip.y + rightHip.y) / 2;
      final bodyAngle = (shoulderCenterY - hipCenterY).abs();

      double score = 100.0;
      String feedback = '';

      // Evaluate elbow angle
      if (avgElbowAngle < 60) {
        feedback = '더 내려가세요';
        score = 70;
      } else if (avgElbowAngle > 100) {
        feedback = '팔을 더 구부리세요';
        score = 75;
      } else {
        feedback = '좋은 팔꿈치 각도입니다';
        score = 90;
      }

      // Check body alignment
      if (bodyAngle > 30) {
        feedback += '\n몸을 일직선으로 유지하세요';
        score -= 20;
      }

      onFormScoreUpdate?.call(score);
      onFeedbackUpdate?.call(feedback);
    }
  }

  void _evaluatePlank(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    if (leftShoulder != null &&
        rightShoulder != null &&
        leftHip != null &&
        rightHip != null &&
        leftAnkle != null &&
        rightAnkle != null) {
      // Calculate body alignment
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

      // Calculate the angle of the body line
      final bodyLineAngle =
          _calculateAngle(shoulderCenter, hipCenter, ankleCenter);

      double score = 100.0;
      String feedback = '';

      // Ideal plank should have body in straight line (angle close to 180)
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

      onFormScoreUpdate?.call(score);
      onFeedbackUpdate?.call(feedback);
    }
  }

  double _calculateAngle(Point<double> a, Point<double> b, Point<double> c) {
    final radians =
        math.atan2(c.y - b.y, c.x - b.x) - math.atan2(a.y - b.y, a.x - b.x);
    var angle = (radians * 180 / math.pi).abs();

    if (angle > 180) {
      angle = 360 - angle;
    }

    return angle;
  }

  void setExerciseType(ExerciseType type) {
    currentExercise = type;
  }

  /// 평가 시작
  void startEvaluation() {
    isEvaluationActive = true;
  }

  /// 평가 중지
  void stopEvaluation() {
    isEvaluationActive = false;
  }

  Future<void> stopCamera() async {
    try {
      await _cameraController?.stopImageStream();
      await _cameraController?.dispose();
      _cameraController = null;
    } catch (e) {
      // 카메라가 이미 정리되었거나 초기화되지 않은 경우 무시
    }
  }

  Future<void> dispose() async {
    await stopCamera();
    await _poseDetector?.close();
    _poseDetector = null;
    _isDetecting = false;
  }

  CameraController? get cameraController => _cameraController;
  bool get isInitialized => _cameraController?.value.isInitialized ?? false;

  // === CALIBRATION METHODS ===

  /// Set user calibration data
  void setCalibration(UserCalibration calibration) {
    _userCalibration = calibration;
  }

  /// Get current calibration
  UserCalibration? get calibration => _userCalibration;

  /// Start calibration process
  void startCalibration() {
    _isCalibrating = true;
    _calibrationPoses.clear();
  }

  /// Stop calibration and compute results
  UserCalibration? finishCalibration(String userId) {
    _isCalibrating = false;

    if (_calibrationPoses.isEmpty) {
      return null;
    }

    // Use the average of collected poses for calibration
    final measurements = _computeCalibrationMeasurements(_calibrationPoses);
    final calibration = UserCalibration.fromStandingPose(
      userId: userId,
      measurements: measurements,
    );

    _userCalibration = calibration;
    onCalibrationComplete?.call(calibration);
    _calibrationPoses.clear();

    return calibration;
  }

  /// Cancel calibration
  void cancelCalibration() {
    _isCalibrating = false;
    _calibrationPoses.clear();
  }

  /// Capture current pose for calibration
  void captureCalibrationPose(Pose pose) {
    if (_isCalibrating) {
      _calibrationPoses.add(pose);
    }
  }

  /// Compute body proportions from collected poses
  Map<String, double> _computeCalibrationMeasurements(List<Pose> poses) {
    if (poses.isEmpty) {
      return {};
    }

    // Use the last pose (most stable)
    final pose = poses.last;

    final measurements = <String, double>{};

    // Calculate limb lengths
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (leftShoulder != null && leftElbow != null && leftWrist != null) {
      final upperArmLength = _distance(leftShoulder, leftElbow);
      final forearmLength = _distance(leftElbow, leftWrist);
      measurements['armLengthRatio'] = upperArmLength / forearmLength;
    }

    if (leftHip != null && leftKnee != null && leftAnkle != null) {
      final thighLength = _distance(leftHip, leftKnee);
      final lowerLegLength = _distance(leftKnee, leftAnkle);
      measurements['legLengthRatio'] = thighLength / lowerLegLength;

      // Calculate natural knee angle (standing)
      final kneeAngle = _calculateAngle(
        Point(leftHip.x.toDouble(), leftHip.y.toDouble()),
        Point(leftKnee.x.toDouble(), leftKnee.y.toDouble()),
        Point(leftAnkle.x.toDouble(), leftAnkle.y.toDouble()),
      );
      measurements['naturalKneeAngle'] = kneeAngle;

      if (leftShoulder != null) {
        final torsoLength = _distance(leftShoulder, leftHip);
        final legLength = thighLength + lowerLegLength;
        measurements['torsoLengthRatio'] = torsoLength / legLength;

        // Natural hip angle
        final hipAngle = _calculateAngle(
          Point(leftShoulder.x.toDouble(), leftShoulder.y.toDouble()),
          Point(leftHip.x.toDouble(), leftHip.y.toDouble()),
          Point(leftKnee.x.toDouble(), leftKnee.y.toDouble()),
        );
        measurements['naturalHipAngle'] = hipAngle;

        if (rightShoulder != null) {
          final shoulderWidth = _distance(leftShoulder, rightShoulder);
          measurements['shoulderWidthRatio'] = shoulderWidth / torsoLength;
        }
      }
    }

    // Set default max flexion (can be adjusted during assessment)
    measurements['maxKneeFlexion'] = 90.0;
    measurements['maxHipFlexion'] = 90.0;

    return measurements;
  }

  /// Calculate distance between two landmarks
  double _distance(PoseLandmark a, PoseLandmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Get calibrated squat target angle (uses user calibration if available)
  double getSquatTargetAngle() {
    if (_userCalibration != null) {
      return _userCalibration!.getSquatTargetAngle();
    }
    return 90.0; // Default target
  }

  /// Get calibrated minimum squat depth
  double getMinSquatDepth() {
    if (_userCalibration != null) {
      return _userCalibration!.getMinSquatDepth();
    }
    return 72.0; // Default minimum (80% of 90)
  }

  /// Check if user has valid calibration
  bool get hasValidCalibration {
    return _userCalibration != null && _userCalibration!.isValid;
  }
}
