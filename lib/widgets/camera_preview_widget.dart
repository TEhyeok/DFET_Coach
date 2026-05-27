import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/pose_detection_service.dart';
import '../services/video_pose_analyzer.dart';
import '../theme/text_styles.dart';
import '../core/utils/app_logger.dart';
import '../screens/posture_result_screen.dart';
import '../utils/ios_navigation.dart';
import '../utils/responsive_layout.dart';

class CameraPreviewWidget extends StatefulWidget {
  final PoseDetectionService poseService;
  final ExerciseType exerciseType;
  final VoidCallback? onClose;

  const CameraPreviewWidget({
    super.key,
    required this.poseService,
    required this.exerciseType,
    this.onClose,
  });

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isLoading = true;
  String? _errorMessage;

  // Recording state
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  static const int _maxRecordingSeconds = 30;

  // Analysis state
  bool _isAnalyzing = false;
  int _analysisProgress = 0;
  int _analysisTotalFrames = 10;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        throw Exception('카메라를 찾을 수 없습니다');
      }

      // Use back camera for better quality
      final camera = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      AppLogger.info('[CameraPreview] Camera initialized successfully');
    } catch (e) {
      AppLogger.error('[CameraPreview] Camera initialization failed', e);
      if (mounted) {
        setState(() {
          _errorMessage = '카메라 초기화 실패: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  bool _isRunningOnSimulator() {
    // iOS 시뮬레이터 감지
    if (!kIsWeb && Platform.isIOS) {
      if (Platform.environment.containsKey('SIMULATOR_DEVICE_NAME') ||
          Platform.environment.containsKey('SIMULATOR_ROOT')) {
        return true;
      }

      // 추가 체크: 시뮬레이터는 일반적으로 전면 카메라만 제공
      if (kDebugMode) {
        // 디버그 모드에서 iOS라면 시뮬레이터일 가능성 높음
        // 실제 디바이스 테스트가 어려우므로 보수적으로 접근
        return true; // 일단 시뮬레이터로 간주
      }
    }
    return false;
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    // 시뮬레이터 체크
    if (_isRunningOnSimulator()) {
      _showSimulatorWarning();
      return;
    }

    try {
      await _cameraController!.startVideoRecording();

      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });

      // Start timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_recordingSeconds >= _maxRecordingSeconds) {
          _stopRecording();
        } else {
          setState(() {
            _recordingSeconds++;
          });
        }
      });

      AppLogger.info('[CameraPreview] Recording started');
    } catch (e) {
      AppLogger.error('[CameraPreview] Failed to start recording', e);
      _showError('녹화를 시작할 수 없습니다: $e');
    }
  }

  void _showSimulatorWarning() {
    final isIOS = !kIsWeb && Platform.isIOS;

    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('시뮬레이터 제한'),
          content: const Text(
            'iOS 시뮬레이터에서는 비디오 녹화가 지원되지 않습니다.\n\n'
            '실제 iPhone 또는 iPad에서 테스트해주세요.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('시뮬레이터 제한'),
        content: const Text(
          '시뮬레이터에서는 비디오 녹화가 지원되지 않습니다.\n\n'
          '실제 디바이스에서 테스트해주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || _cameraController == null) {
      return;
    }

    _recordingTimer?.cancel();

    try {
      final videoFile = await _cameraController!.stopVideoRecording();

      setState(() {
        _isRecording = false;
      });

      AppLogger.info('[CameraPreview] Recording stopped: ${videoFile.path}');

      // Start analysis
      await _analyzeVideo(videoFile.path);
    } catch (e) {
      AppLogger.error('[CameraPreview] Failed to stop recording', e);
      setState(() {
        _isRecording = false;
      });
      _showError('녹화를 중지할 수 없습니다: $e');
    }
  }

  Future<void> _analyzeVideo(String videoPath) async {
    setState(() {
      _isAnalyzing = true;
      _analysisProgress = 0;
    });

    try {
      final analyzer = VideoPoseAnalyzer();
      await analyzer.initialize();

      final result = await analyzer.analyzeVideo(
        videoPath: videoPath,
        exerciseType: widget.exerciseType,
        maxFrames: _analysisTotalFrames,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _analysisProgress = current;
              _analysisTotalFrames = total;
            });
          }
        },
      );

      await analyzer.dispose();

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });

        // Navigate to results screen
        Navigator.of(context).pushReplacement(
          adaptivePageRoute(
            builder: (context) => PostureResultScreen(
              result: result,
              onRetry: () {
                Navigator.of(context).pushReplacement(
                  adaptivePageRoute(
                    builder: (context) => CameraPreviewWidget(
                      poseService: widget.poseService,
                      exerciseType: widget.exerciseType,
                      onClose: widget.onClose,
                    ),
                  ),
                );
              },
              onClose: () {
                // 결과 화면에서 닫기 버튼을 누르면 이전 화면으로 돌아감
                Navigator.of(context).pop();
                // 원래 onClose 콜백도 호출 (mounted 체크가 되어 있음)
                widget.onClose?.call();
              },
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('[CameraPreview] Video analysis failed', e);
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        _showError('영상 분석 실패: $e');
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getExerciseName() {
    switch (widget.exerciseType) {
      case ExerciseType.squat:
        return '스쿼트';
      case ExerciseType.pushup:
        return '푸시업';
      case ExerciseType.plank:
        return '플랭크';
      default:
        return '운동';
    }
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_errorMessage != null) {
      return _buildErrorScreen();
    }

    if (_isAnalyzing) {
      return _buildAnalyzingScreen();
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return _buildLoadingScreen();
    }

    return _buildCameraScreen();
  }

  Widget _buildLoadingScreen() {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) widget.onClose?.call();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                '카메라 준비 중...',
                style: AppTextStyles.body.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: AppTextStyles.body.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: widget.onClose,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                child: const Text('닫기'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyzingScreen() {
    final progress = _analysisTotalFrames > 0
        ? _analysisProgress / _analysisTotalFrames
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Colors.green,
                strokeWidth: 6,
              ),
              const SizedBox(height: 32),
              Text(
                '자세 분석 중...',
                style: AppTextStyles.h2.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                '$_analysisProgress / $_analysisTotalFrames 프레임',
                style: AppTextStyles.body.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[800],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraScreen() {
    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;

    if (ResponsiveLayout.isTablet(context) && size.width >= 900) {
      return _buildTabletCameraScreen();
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          if (_isRecording) {
            await _stopRecording();
          }
          await _cameraController?.dispose();
          widget.onClose?.call();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Camera Preview
            Center(
              child: AspectRatio(
                aspectRatio: deviceRatio,
                child: CameraPreview(_cameraController!),
              ),
            ),

            // Top Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  right: 16,
                  bottom: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: _isRecording ? null : widget.onClose,
                      icon: Icon(
                        Icons.close,
                        color: _isRecording ? Colors.grey : Colors.white,
                        size: 28,
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          _getExerciseName(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_isRecording) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatTime(_recordingSeconds),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),

            // Bottom Controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 24,
                  left: 32,
                  right: 32,
                  top: 24,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Instructions
                    if (!_isRecording)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '전신이 보이도록 카메라를 고정하고\n운동을 수행하세요',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Record Button
                    GestureDetector(
                      onTap: _isRecording ? _stopRecording : _startRecording,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 4,
                          ),
                        ),
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: _isRecording ? 32 : 64,
                            height: _isRecording ? 32 : 64,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(
                                _isRecording ? 8 : 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      _isRecording ? '정지하려면 탭' : '녹화 시작',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletCameraScreen() {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          if (_isRecording) {
            await _stopRecording();
          }
          await _cameraController?.dispose();
          widget.onClose?.call();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _cameraController!.value.aspectRatio,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              ),
              Container(
                width: 360,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.86),
                  border: Border(
                    left: BorderSide(color: Colors.white.withOpacity(0.12)),
                  ),
                ),
                child: _buildTabletControlPanel(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletControlPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _isRecording ? null : widget.onClose,
              icon: Icon(
                Icons.close,
                color: _isRecording ? Colors.grey : Colors.white,
                size: 28,
              ),
            ),
            const Spacer(),
            if (_isRecording)
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatTime(_recordingSeconds),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          _getExerciseName(),
          style: AppTextStyles.h2.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 12),
        Text(
          '전신이 보이도록 카메라를 고정하고 운동을 수행하세요',
          style: AppTextStyles.body.copyWith(color: Colors.white70),
        ),
        const Spacer(),
        Center(child: _buildRecordButton()),
        const SizedBox(height: 12),
        Text(
          _isRecording ? '정지하려면 탭' : '녹화 시작',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: _isRecording ? _stopRecording : _startRecording,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 4,
          ),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isRecording ? 32 : 64,
            height: _isRecording ? 32 : 64,
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(
                _isRecording ? 8 : 32,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
