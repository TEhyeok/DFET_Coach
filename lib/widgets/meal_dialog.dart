import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/meal.dart';
import '../theme/tokens.dart';
import '../theme/text_styles.dart';
import '../services/image_picker_service.dart';
import '../services/nutrition_analyzer_service.dart';
import '../core/utils/app_logger.dart';

class MealDialog extends StatefulWidget {
  final Meal? meal;
  final Function(Meal) onSave;
  final bool showPhotoSection;
  final XFile? initialImage;
  final bool isSheet;
  final String? date;

  const MealDialog({
    super.key,
    this.meal,
    required this.onSave,
    this.showPhotoSection = false,
    this.initialImage,
    this.isSheet = false,
    this.date,
  });

  @override
  State<MealDialog> createState() => _MealDialogState();
}

class _MealDialogState extends State<MealDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _timeController;
  late final TextEditingController _nameController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;
  bool _isLoading = false;

  // 이미지 선택
  XFile? _selectedImage;
  bool _isLoadingImage = false;
  final _imagePickerService = ImagePickerService();

  // AI 분석
  bool _isAnalyzing = false;
  final _nutritionAnalyzer = NutritionAnalyzerService();
  Map<String, dynamic>? _analysisResult;

  // ScaffoldMessenger for showing snackbars
  ScaffoldMessengerState? _scaffoldMessenger;

  @override
  void initState() {
    super.initState();
    _timeController = TextEditingController(text: widget.meal?.time ?? '');
    _nameController = TextEditingController(text: widget.meal?.name ?? '');
    _caloriesController =
        TextEditingController(text: widget.meal?.calories.toString() ?? '');
    _proteinController =
        TextEditingController(text: widget.meal?.protein.toString() ?? '0');
    _carbsController =
        TextEditingController(text: widget.meal?.carbs.toString() ?? '0');
    _fatController =
        TextEditingController(text: widget.meal?.fat.toString() ?? '0');
    _selectedImage = widget.initialImage;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safely capture ScaffoldMessenger from the parent context
    try {
      _scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    } catch (e) {
      AppLogger.warning('[MealDialog] ScaffoldMessenger not found', e);
      _scaffoldMessenger = null;
    }
  }

  @override
  void dispose() {
    _timeController.dispose();
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (_scaffoldMessenger != null) {
      _scaffoldMessenger!.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor ?? AppColors.brandPrimary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _timeController.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  /// 이미지 소스 선택 (iOS/Android 대응)
  Future<void> _showImageSourceActionSheet() async {
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    if (isIOS) {
      // iOS 스타일
      showCupertinoModalPopup<void>(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: const Text('음식 사진 추가'),
          message: const Text('사진을 선택하거나 촬영하세요'),
          actions: [
            CupertinoActionSheetAction(
              child: const Text('🖼️ 갤러리에서 선택'),
              onPressed: () async {
                Navigator.pop(context);
                await _pickImage(ImageSource.gallery);
              },
            ),
            CupertinoActionSheetAction(
              child: const Text('📷 사진 촬영'),
              onPressed: () async {
                Navigator.pop(context);
                await _pickImage(ImageSource.camera);
              },
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('취소'),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      );
    } else {
      // Android/Web 스타일
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.bgCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library,
                  color: AppColors.brandPrimary),
              title: const Text('갤러리에서 선택'),
              onTap: () async {
                Navigator.pop(context);
                await _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.camera_alt, color: AppColors.brandPrimary),
              title: const Text('사진 촬영'),
              onTap: () async {
                Navigator.pop(context);
                await _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    }
  }

  /// 이미지 선택
  Future<void> _pickImage(ImageSource source) async {
    setState(() => _isLoadingImage = true);

    XFile? image;
    if (source == ImageSource.camera) {
      image = await _imagePickerService.pickFromCamera();
    } else {
      image = await _imagePickerService.pickFromGallery();
    }

    setState(() => _isLoadingImage = false);

    if (image != null) {
      HapticFeedback.lightImpact();
      setState(() => _selectedImage = image);
    } else {
      // 권한 거부 또는 취소
      if (mounted) {
        _showSnackBar(
          source == ImageSource.camera ? '카메라를 사용할 수 없습니다' : '갤러리에 접근할 수 없습니다',
          backgroundColor: AppColors.warn,
        );
      }
    }
  }

  /// 이미지 삭제
  void _deleteImage() {
    final deletedImage = _selectedImage;
    setState(() {
      _selectedImage = null;
      _analysisResult = null;
    });

    if (_scaffoldMessenger != null) {
      _scaffoldMessenger!.showSnackBar(
        SnackBar(
          content: const Text('사진이 삭제되었습니다'),
          action: SnackBarAction(
            label: '취소',
            onPressed: () => setState(() => _selectedImage = deletedImage),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 음식이 아닌 경우 경고 다이얼로그
  Future<void> _showNotFoodDialog(String reason) async {
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    if (isIOS) {
      // iOS 스타일
      await showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('음식이 아닙니다'),
          content: Text(
              '이 이미지는 음식이 아닌 것 같습니다.\n\n감지된 내용: $reason\n\n음식 사진을 다시 촬영해주세요.'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('다시 촬영'),
            ),
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(context).pop();
                // 사용자가 그래도 진행하고 싶을 수 있음 (예: 잘못 감지된 경우)
              },
              child: const Text('직접 입력'),
            ),
          ],
        ),
      );
    } else {
      // Android 스타일
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: const Text('음식이 아닙니다', style: AppTextStyles.h3),
          content: Text(
            '이 이미지는 음식이 아닌 것 같습니다.\n\n감지된 내용: $reason\n\n음식 사진을 다시 촬영해주세요.',
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // 사용자가 그래도 진행하고 싶을 수 있음
              },
              child: const Text('직접 입력'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('다시 촬영'),
            ),
          ],
        ),
      );
    }
  }

  /// AI로 음식 분석
  Future<void> _analyzeWithAI() async {
    if (_selectedImage == null) {
      AppLogger.warning('[MealDialog] 선택된 이미지가 없습니다');
      return;
    }

    // Race condition 방지: 이미 분석 중이면 중복 호출 방지
    if (_isAnalyzing) {
      AppLogger.debug('[MealDialog] 이미 분석 중입니다. 중복 호출 무시');
      return;
    }

    AppLogger.info('[MealDialog] AI 분석 시작...');
    setState(() => _isAnalyzing = true);

    try {
      // 이미지 바이트 읽기
      final imageBytes = await _selectedImage!.readAsBytes();
      AppLogger.debug('[MealDialog] 이미지 크기: ${imageBytes.length} bytes');

      // Gemini API 호출
      final result = await _nutritionAnalyzer.analyzeFood(imageBytes);
      AppLogger.info('[MealDialog] 분석 결과: $result');

      setState(() {
        _analysisResult = result;
        _isAnalyzing = false;
      });

      // 음식 여부 체크 (최우선)
      final isFood = result['is_food'] ?? true; // 기본값 true (하위 호환성)

      if (!isFood) {
        // 음식이 아닌 경우
        final reason = result['reason'] ?? '알 수 없음';
        AppLogger.warning('[MealDialog] 음식이 아님: $reason');

        if (mounted) {
          await _showNotFoodDialog(reason);
        }
        return;
      }

      // 결과를 입력 필드에 자동 채우기 (음식인 경우만)
      if (result['name'] != null && result['name'] != '분석 실패') {
        _nameController.text = result['name'] ?? '';
        _caloriesController.text = result['calories']?.toString() ?? '';
        _proteinController.text = result['protein']?.toString() ?? '0';
        _carbsController.text = result['carbs']?.toString() ?? '0';
        _fatController.text = result['fat']?.toString() ?? '0';

        AppLogger.debug('[MealDialog] 입력 필드에 결과 채움');

        // 성공 메시지
        if (mounted) {
          _showSnackBar(
            'AI 분석 완료: ${result['confidence']} 정확도',
            backgroundColor: AppColors.brandPrimary,
          );
        }
      } else {
        // 분석 실패
        if (mounted) {
          _showSnackBar(
            '분석 실패: ${result['error'] ?? '알 수 없는 오류'}',
            backgroundColor: AppColors.warn,
          );
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('[MealDialog] 분석 중 에러', e, stackTrace);

      setState(() => _isAnalyzing = false);

      if (mounted) {
        _showSnackBar(
          '분석 중 오류 발생: $e',
          backgroundColor: AppColors.danger,
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    // Simulate save delay
    await Future.delayed(const Duration(milliseconds: 300));

    final meal = Meal(
      id: widget.meal?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      time: _timeController.text.isEmpty
          ? '${TimeOfDay.now().hour.toString().padLeft(2, '0')}:${TimeOfDay.now().minute.toString().padLeft(2, '0')}'
          : _timeController.text,
      name: _nameController.text,
      calories: int.tryParse(_caloriesController.text) ?? 0,
      protein: int.tryParse(_proteinController.text) ?? 0,
      carbs: int.tryParse(_carbsController.text) ?? 0,
      fat: int.tryParse(_fatController.text) ?? 0,
      date: widget.meal?.date ?? widget.date,
      aiTokenUsage: _analysisResult?['aiTokenUsage'],
    );

    widget.onSave(meal);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // 키보드 높이를 고려한 패딩 계산
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.meal == null ? '식단 추가' : '식단 수정',
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: 20),

            // 이미지 선택 영역 (showPhotoSection이 true일 때만 표시)
            if (widget.showPhotoSection && _isLoadingImage)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (widget.showPhotoSection && _selectedImage == null)
              Semantics(
                label: '음식 사진 추가 버튼',
                hint: '탭하여 카메라 또는 갤러리를 선택하세요',
                child: OutlinedButton.icon(
                  onPressed: _showImageSourceActionSheet,
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('사진으로 추가'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              )
            else if (widget.showPhotoSection && _selectedImage != null)
              Column(
                children: [
                  Semantics(
                    label: '선택된 음식 사진',
                    image: true,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: kIsWeb
                            ? Image.network(_selectedImage!.path,
                                fit: BoxFit.cover)
                            : Image.file(File(_selectedImage!.path),
                                fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // AI 분석 버튼
                  if (_isAnalyzing)
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('AI가 음식을 분석하는 중...', style: AppTextStyles.body),
                      ],
                    )
                  else
                    FilledButton.icon(
                      onPressed: _analyzeWithAI,
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('AI로 영양소 분석'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: AppColors.brandPrimary,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: _deleteImage,
                        icon: const Icon(Icons.close,
                            size: 18, color: AppColors.danger),
                        label: const Text('삭제',
                            style: TextStyle(color: AppColors.danger)),
                      ),
                      TextButton.icon(
                        onPressed: _showImageSourceActionSheet,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('다시 선택'),
                      ),
                    ],
                  ),
                  if (_analysisResult != null &&
                      _analysisResult!['confidence'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Chip(
                        avatar: Icon(
                          _analysisResult!['confidence'] == '높음'
                              ? Icons.check_circle
                              : Icons.info,
                          size: 18,
                        ),
                        label: Text('정확도: ${_analysisResult!['confidence']}'),
                        backgroundColor: _analysisResult!['confidence'] == '높음'
                            ? AppColors.brandPrimary.withOpacity(0.2)
                            : AppColors.warn.withOpacity(0.2),
                      ),
                    ),
                ],
              ),
            if (widget.showPhotoSection) const SizedBox(height: 16),
            GestureDetector(
              onTap: _selectTime,
              child: AbsorbPointer(
                child: _buildTextField('시간 (HH:MM)', _timeController,
                    hint: '07:30', icon: Icons.access_time),
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField('음식명', _nameController,
                hint: '닭가슴살 샐러드', required: true),
            const SizedBox(height: 16),
            _buildTextField('칼로리 (kcal)', _caloriesController,
                isNumber: true, hint: '350', required: true),
            const SizedBox(height: 20),
            Text('영양소 (선택)', style: AppTextStyles.body),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _buildTextField('단백질(g)', _proteinController,
                        isNumber: true, hint: '0')),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildTextField('탄수화물(g)', _carbsController,
                        isNumber: true, hint: '0')),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildTextField('지방(g)', _fatController,
                        isNumber: true, hint: '0')),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('저장'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (widget.isSheet) {
      return content;
    }

    return Dialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.xxl)),
      insetPadding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 40,
        bottom: keyboardHeight > 0 ? keyboardHeight + 16 : 40,
      ),
      child: content,
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    String? hint,
    bool required = false,
    IconData? icon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters:
          isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
      style: const TextStyle(color: AppColors.textStrong),
      validator: (value) {
        if (required && (value == null || value.isEmpty)) {
          return '필수 입력 항목입니다';
        }
        if (isNumber && value != null && value.isNotEmpty) {
          final num = int.tryParse(value);
          if (num == null) {
            return '숫자만 입력 가능합니다';
          }
          if (num < 0) {
            return '0 이상의 값을 입력하세요';
          }
          if (required && num > 10000) {
            return '값이 너무 큽니다';
          }
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon:
            icon != null ? Icon(icon, color: AppColors.textSubtle) : null,
        labelStyle: const TextStyle(color: AppColors.textSubtle),
        hintStyle: TextStyle(color: AppColors.textSubtle.withOpacity(0.5)),
        filled: true,
        fillColor: AppColors.bgApp,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.bgStroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.bgStroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brandPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 2),
        ),
      ),
    );
  }
}
