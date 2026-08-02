import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

class PoseDetector {
  PoseDetector({required this.options});

  final PoseDetectorOptions options;

  Future<List<Pose>> processImage(InputImage inputImage) async => const [];

  Future<void> close() async {}
}

class PoseDetectorOptions {
  const PoseDetectorOptions({
    this.model = PoseDetectionModel.base,
    this.mode = PoseDetectionMode.stream,
  });

  final PoseDetectionModel model;
  final PoseDetectionMode mode;
}

enum PoseDetectionModel { base, accurate }

enum PoseDetectionMode { single, stream }

enum PoseLandmarkType {
  nose,
  leftEyeInner,
  leftEye,
  leftEyeOuter,
  rightEyeInner,
  rightEye,
  rightEyeOuter,
  leftEar,
  rightEar,
  leftMouth,
  rightMouth,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftPinky,
  rightPinky,
  leftIndex,
  rightIndex,
  leftThumb,
  rightThumb,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
  leftHeel,
  rightHeel,
  leftFootIndex,
  rightFootIndex,
}

class Pose {
  const Pose({required this.landmarks});

  final Map<PoseLandmarkType, PoseLandmark> landmarks;
}

class PoseLandmark {
  const PoseLandmark({
    required this.type,
    required this.x,
    required this.y,
    required this.z,
    required this.likelihood,
  });

  final PoseLandmarkType type;
  final double x;
  final double y;
  final double z;
  final double likelihood;
}

class InputImage {
  const InputImage._({
    this.filePath,
    this.bytes,
    required this.type,
    this.metadata,
  });

  factory InputImage.fromFilePath(String path) =>
      InputImage._(filePath: path, type: InputImageType.file);

  factory InputImage.fromFile(File file) =>
      InputImage._(filePath: file.path, type: InputImageType.file);

  factory InputImage.fromBytes({
    required Uint8List bytes,
    required InputImageMetadata metadata,
  }) =>
      InputImage._(
        bytes: bytes,
        type: InputImageType.bytes,
        metadata: metadata,
      );

  final String? filePath;
  final Uint8List? bytes;
  final InputImageType type;
  final InputImageMetadata? metadata;
}

enum InputImageType { file, bytes }

class InputImageMetadata {
  const InputImageMetadata({
    required this.size,
    required this.rotation,
    required this.format,
    required this.bytesPerRow,
  });

  final Size size;
  final InputImageRotation rotation;
  final InputImageFormat format;
  final int bytesPerRow;
}

enum InputImageRotation {
  rotation0deg,
  rotation90deg,
  rotation180deg,
  rotation270deg,
}

extension InputImageRotationValue on InputImageRotation {
  int get rawValue => switch (this) {
        InputImageRotation.rotation0deg => 0,
        InputImageRotation.rotation90deg => 90,
        InputImageRotation.rotation180deg => 180,
        InputImageRotation.rotation270deg => 270,
      };

  static InputImageRotation? fromRawValue(int rawValue) {
    for (final value in InputImageRotation.values) {
      if (value.rawValue == rawValue) return value;
    }
    return null;
  }
}

enum InputImageFormat { nv21, yv12, yuv_420_888, yuv420, bgra8888 }

extension InputImageFormatValue on InputImageFormat {
  int get rawValue => switch (this) {
        InputImageFormat.nv21 => 17,
        InputImageFormat.yv12 => 842094169,
        InputImageFormat.yuv_420_888 => 35,
        InputImageFormat.yuv420 => 875704438,
        InputImageFormat.bgra8888 => 1111970369,
      };

  static InputImageFormat? fromRawValue(int rawValue) {
    for (final value in InputImageFormat.values) {
      if (value.rawValue == rawValue) return value;
    }
    return null;
  }
}
