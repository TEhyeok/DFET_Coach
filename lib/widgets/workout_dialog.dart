import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/workout.dart';
import '../theme/tokens.dart';
import '../theme/text_styles.dart';
import '../screens/posture_assessment_screen.dart';
import '../services/pose_detection_service.dart';
import '../state/date_state.dart';
import '../utils/ios_navigation.dart';

class WorkoutDialog extends StatefulWidget {
  final Workout? workout;
  final Function(Workout) onSave;
  final bool isSheet;
  final DateTime? date;

  const WorkoutDialog({
    super.key,
    this.workout,
    required this.onSave,
    this.isSheet = false,
    this.date,
  });

  @override
  State<WorkoutDialog> createState() => _WorkoutDialogState();
}

class _WorkoutDialogState extends State<WorkoutDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _durationController;
  late final TextEditingController _weightController;
  late final TextEditingController _repsController;
  String _selectedCategory = 'strength';
  bool _isLoading = false;
  final List<WorkoutSet> _sets = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.workout?.name ?? '');
    _nameController.addListener(_handleNameChanged);
    _durationController = TextEditingController(
        text: widget.workout?.duration.toString() ?? '30');
    _weightController = TextEditingController();
    _repsController = TextEditingController();
    _selectedCategory = widget.workout?.category ?? 'strength';
    if (widget.workout != null) {
      _sets.addAll(widget.workout!.sets);
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleNameChanged);
    _nameController.dispose();
    _durationController.dispose();
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  void _handleNameChanged() {
    if (mounted) setState(() {});
  }

  void _addSet() {
    if (_weightController.text.isNotEmpty && _repsController.text.isNotEmpty) {
      setState(() {
        _sets.add(WorkoutSet(
          weight: double.tryParse(_weightController.text) ?? 0,
          reps: int.tryParse(_repsController.text) ?? 0,
        ));
        _weightController.clear();
        _repsController.clear();
      });
    }
  }

  void _removeSet(int index) {
    setState(() {
      _sets.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategory == 'strength' && _sets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 1세트를 추가해주세요')),
      );
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    final now = DateTime.now();
    final selectedDate = widget.date ?? now;
    final timestamp = widget.workout?.timestamp ??
        DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          now.hour,
          now.minute,
        );

    final workout = Workout(
      id: widget.workout?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      category: _selectedCategory,
      sets: _selectedCategory == 'strength' ? _sets : [],
      duration: _selectedCategory != 'strength'
          ? (int.tryParse(_durationController.text) ?? 30)
          : 0,
      timestamp: timestamp,
      date: widget.workout?.date ?? dateKey(selectedDate),
    );

    widget.onSave(workout);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.workout == null ? '운동 추가' : '운동 수정',
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: 20),
            _buildTextField('운동명', _nameController,
                hint: '벤치프레스', required: true),
            const SizedBox(height: 16),
            Text('운동 유형', style: AppTextStyles.body),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildCategoryChip('strength', '근력', Icons.fitness_center),
                const SizedBox(width: 8),
                _buildCategoryChip('cardio', '유산소', Icons.directions_run),
                const SizedBox(width: 8),
                _buildCategoryChip(
                    'flexibility', '유연성', Icons.self_improvement),
              ],
            ),
            const SizedBox(height: 16),

            // Posture Check Button for specific exercises
            if (_selectedCategory == 'strength' &&
                (_nameController.text.toLowerCase().contains('스쿼트') ||
                    _nameController.text.toLowerCase().contains('푸시업') ||
                    _nameController.text.toLowerCase().contains('플랭크'))) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.info.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.camera_alt, color: AppColors.info, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('자세 확인 가능',
                              style: AppTextStyles.label
                                  .copyWith(color: AppColors.info)),
                          Text('카메라로 실시간 자세를 평가할 수 있습니다',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: context.wellness.textTertiary)),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _checkPosture(context),
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('확인'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.info,
                        side: BorderSide(color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_selectedCategory == 'strength') ...[
              Text('세트 정보', style: AppTextStyles.body),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _buildTextField('무게(kg)', _weightController,
                          isNumber: true, hint: '60')),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildTextField('횟수', _repsController,
                          isNumber: true, hint: '10')),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _addSet,
                    icon: const Icon(Icons.add_circle,
                        color: AppColors.brandPrimary),
                    tooltip: '세트 추가',
                  ),
                ],
              ),
              if (_sets.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _sets.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final set = entry.value;
                    return Chip(
                      label: Text('$index세트: ${set.weight}kg × ${set.reps}회',
                          style: AppTextStyles.bodySmall),
                      backgroundColor: AppColors.brandPrimary.withOpacity(0.1),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _removeSet(entry.key),
                    );
                  }).toList(),
                ),
              ],
            ] else ...[
              _buildTextField('운동 시간 (분)', _durationController,
                  isNumber: true, hint: '30', required: true),
            ],
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
      backgroundColor: context.wellness.bgCard,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.xxl)),
      child: content,
    );
  }

  Widget _buildCategoryChip(String value, String label, IconData icon) {
    final isSelected = _selectedCategory == value;
    return Expanded(
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: isSelected
                    ? AppColors.brandPrimary
                    : context.wellness.textTertiary),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        onSelected: (selected) {
          setState(() => _selectedCategory = value);
        },
        backgroundColor: context.wellness.bgRoot,
        selectedColor: AppColors.brandPrimary.withOpacity(0.1),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    String? hint,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))]
          : null,
      style: TextStyle(color: context.wellness.textPrimary),
      validator: (value) {
        if (required && (value == null || value.isEmpty)) {
          return '필수 입력 항목입니다';
        }
        if (isNumber && value != null && value.isNotEmpty) {
          final num = double.tryParse(value);
          if (num == null) {
            return '숫자만 입력 가능합니다';
          }
          if (num < 0) {
            return '0 이상의 값을 입력하세요';
          }
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: context.wellness.textTertiary),
        hintStyle:
            TextStyle(color: context.wellness.textTertiary.withOpacity(0.5)),
        filled: true,
        fillColor: context.wellness.bgRoot,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.wellness.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.wellness.border),
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

  void _checkPosture(BuildContext context) {
    ExerciseType? exerciseType;
    final exerciseName = _nameController.text.toLowerCase();

    if (exerciseName.contains('스쿼트')) {
      exerciseType = ExerciseType.squat;
    } else if (exerciseName.contains('푸시업')) {
      exerciseType = ExerciseType.pushup;
    } else if (exerciseName.contains('플랭크')) {
      exerciseType = ExerciseType.plank;
    }

    if (exerciseType != null) {
      Navigator.push(
        context,
        adaptivePageRoute(
          builder: (context) => PostureAssessmentScreen(
            initialExercise: exerciseType,
          ),
          fullscreenDialog: true,
        ),
      );
    }
  }
}
