import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/pose_detection_service.dart';
import '../widgets/camera_preview_widget.dart';
import '../theme/tokens.dart';
import '../theme/text_styles.dart';
import '../core/utils/app_logger.dart';
import 'dart:io' show Platform;

class PostureAssessmentScreen extends StatefulWidget {
  final ExerciseType? initialExercise;

  const PostureAssessmentScreen({
    super.key,
    this.initialExercise,
  });

  @override
  State<PostureAssessmentScreen> createState() =>
      _PostureAssessmentScreenState();
}

class _PostureAssessmentScreenState extends State<PostureAssessmentScreen> {
  late PoseDetectionService _poseService;
  ExerciseType? _selectedExercise;
  bool _isLoading = false;
  bool _showCamera = false;
  int _initAttempts = 0; // 초기화 시도 횟수 추적 (무한 루프 방지)

  @override
  void initState() {
    super.initState();
    _poseService = PoseDetectionService();
    _selectedExercise = widget.initialExercise;
  }

  void _showPermissionDeniedDialog() {
    final isIOS = !kIsWeb && Platform.isIOS;

    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('카메라 권한 필요'),
          content:
              const Text('자세 평가 기능을 사용하려면 카메라 권한이 필요합니다.\n설정에서 권한을 허용해주세요.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('취소'),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              child: const Text('설정 열기'),
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('카메라 권한 필요'),
          content:
              const Text('자세 평가 기능을 사용하려면 카메라 권한이 필요합니다.\n설정에서 권한을 허용해주세요.'),
          actions: [
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text('설정 열기'),
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
            ),
          ],
        ),
      );
    }
  }

  void _showErrorDialog(String message) {
    final isIOS = !kIsWeb && Platform.isIOS;

    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('오류'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: const Text('확인'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('오류'),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text('확인'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }

  void _startAssessment() async {
    if (_selectedExercise == null) {
      _showErrorDialog('운동을 선택해주세요.');
      return;
    }

    // 무한 루프 방지: 최대 2번까지만 시도
    if (_initAttempts >= 2) {
      AppLogger.warning('[PostureAssessment] 초기화 재시도 횟수 초과 (2회)');
      _showErrorDialog('카메라를 초기화할 수 없습니다.\n기기를 재시작하거나 앱을 다시 실행해주세요.');
      _initAttempts = 0; // 카운터 리셋
      return;
    }

    _initAttempts++;
    AppLogger.info(
        '[PostureAssessment] Starting assessment (attempt $_initAttempts)');

    // 바로 카메라 초기화 시도
    setState(() {
      _isLoading = true;
    });

    try {
      await _poseService.initialize();
      AppLogger.info(
          '[PostureAssessment] Pose detection initialized successfully');
      _initAttempts = 0; // 성공 시 카운터 리셋
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showCamera = true;
        });
      }
    } catch (e) {
      AppLogger.error(
          '[PostureAssessment] Failed to initialize pose detection (attempt $_initAttempts)',
          e);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // 카메라 초기화 실패 시 권한 요청
        final status = await Permission.camera.request();
        AppLogger.debug(
            '[PostureAssessment] Camera permission request result: $status');

        if (status.isGranted || status.isLimited) {
          // 권한 허용되면 다시 시도 (최대 2번)
          _startAssessment();
        } else if (status.isPermanentlyDenied) {
          _initAttempts = 0; // 리셋
          _showPermissionDeniedDialog();
        } else {
          _initAttempts = 0; // 리셋
          _showErrorDialog('카메라 권한이 거부되었습니다.\n자세 평가 기능을 사용하려면 카메라 권한이 필요합니다.');
        }
      }
    }
  }

  @override
  void dispose() {
    _poseService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = !kIsWeb && Platform.isIOS;

    if (_showCamera) {
      return CameraPreviewWidget(
        poseService: _poseService,
        exerciseType: _selectedExercise!,
        onClose: () {
          if (mounted) {
            setState(() {
              _showCamera = false;
            });
          }
          // mounted가 false인 경우 아무것도 하지 않음 (이미 다른 화면으로 네비게이션됨)
        },
      );
    }

    if (isIOS) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('자세 평가'),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Text('닫기'),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        child: _buildBody(isIOS),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const Text('자세 평가'),
          backgroundColor: AppColors.bgCard,
        ),
        backgroundColor: AppColors.bgRoot,
        body: _buildBody(isIOS),
      );
    }
  }

  Widget _buildBody(bool isIOS) {
    if (_isLoading) {
      return Center(
        child: isIOS
            ? const CupertinoActivityIndicator()
            : const CircularProgressIndicator(
                color: AppColors.brandPrimary,
              ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Exercise Selection Title
            Text(
              '운동 선택',
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: 12),

            // Horizontal Exercise Options
            Row(
              children: [
                Expanded(
                  child: _buildCompactExerciseOption(
                    ExerciseType.squat,
                    '스쿼트',
                    Icons.fitness_center,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactExerciseOption(
                    ExerciseType.pushup,
                    '푸시업',
                    Icons.sports_gymnastics,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactExerciseOption(
                    ExerciseType.plank,
                    '플랭크',
                    Icons.self_improvement,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Start Button
            if (isIOS)
              CupertinoButton(
                color: AppColors.brandPrimary,
                borderRadius: BorderRadius.circular(Radii.xl),
                onPressed: _selectedExercise != null ? _startAssessment : null,
                child: const Text(
                  '평가 시작',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              )
            else
              FilledButton(
                onPressed: _selectedExercise != null ? _startAssessment : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.xl),
                  ),
                ),
                child: const Text(
                  '평가 시작',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

            const SizedBox(height: 12),

            // Collapsible Instructions
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                leading: Icon(
                  Icons.info_outline,
                  color: AppColors.textSubtle,
                  size: 20,
                ),
                title: Text(
                  '촬영 전 준비사항',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSubtle,
                  ),
                ),
                children: [
                  _buildCompactInstruction('• 카메라를 1.5~2m 거리에 고정'),
                  _buildCompactInstruction('• 밝은 조명 아래에서 촬영'),
                  _buildCompactInstruction('• 전신이 화면에 보이도록 위치'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactInstruction(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textSubtle,
        ),
      ),
    );
  }

  Widget _buildCompactExerciseOption(
    ExerciseType type,
    String title,
    IconData icon,
  ) {
    final isSelected = _selectedExercise == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedExercise = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandPrimary.withValues(alpha: 0.1)
              : AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.brandPrimary : AppColors.bgStroke,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.brandPrimary : AppColors.textSubtle,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color:
                    isSelected ? AppColors.brandPrimary : AppColors.textStrong,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Icon(
                Icons.check_circle,
                color: AppColors.brandPrimary,
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
