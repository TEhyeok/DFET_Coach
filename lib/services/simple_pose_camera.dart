import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// 간소화된 포즈 감지 카메라 서비스
class SimplePoseCamera {
  CameraController? _controller;
  PoseDetector? _detector;
  bool _isProcessing = false;

  final _poseStream = StreamController<Pose?>.broadcast();
  final _errorStream = StreamController<String>.broadcast();

  Stream<Pose?> get poseStream => _poseStream.stream;
  Stream<String> get errorStream => _errorStream.stream;
  CameraController? get controller => _controller;
  bool get isReady => _controller?.value.isInitialized ?? false;

  Future<void> initialize() async {
    try {
      // 카메라 초기화
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('카메라 없음');

      _controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _controller!.initialize();

      // ML Kit 초기화
      _detector = PoseDetector(
        options: PoseDetectorOptions(
          mode: PoseDetectionMode.stream,
          model: PoseDetectionModel.accurate,
        ),
      );

      // 이미지 스트림 시작
      await _controller!.startImageStream(_processImage);
    } catch (e) {
      _errorStream.add('초기화 실패: $e');
    }
  }

  void _processImage(CameraImage image) async {
    if (_isProcessing || _detector == null) return;
    _isProcessing = true;

    try {
      final inputImage = _convertImage(image);
      final poses = await _detector!.processImage(inputImage);
      _poseStream.add(poses.isNotEmpty ? poses.first : null);
    } catch (e) {
      _poseStream.add(null);
    }

    _isProcessing = false;
  }

  InputImage _convertImage(CameraImage image) {
    final allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }

    final rotation = _getRotation();
    final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;

    return InputImage.fromBytes(
      bytes: allBytes.done().buffer.asUint8List(),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  InputImageRotation _getRotation() {
    if (_controller == null) return InputImageRotation.rotation0deg;
    switch (_controller!.description.sensorOrientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Future<void> dispose() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    await _detector?.close();
    await _poseStream.close();
    await _errorStream.close();
    _controller = null;
    _detector = null;
  }
}
