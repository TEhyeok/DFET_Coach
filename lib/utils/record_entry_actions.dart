import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/meal.dart';
import '../screens/posture_assessment_screen.dart';
import '../services/image_picker_service.dart';
import '../services/pose_detection_service.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/ios_adaptive_sheet.dart';
import '../widgets/meal_dialog.dart';
import '../widgets/workout_dialog.dart';
import 'ios_navigation.dart';

class RecordEntryActions {
  const RecordEntryActions._();

  static Future<void> showManualMeal(
    BuildContext context,
    WidgetRef ref, {
    Meal? meal,
  }) async {
    final useSheet = isCupertinoTarget;
    final selectedDate = ref.read(selectedDateStringProvider);

    await showAdaptiveEntrySheet<void>(
      context: context,
      builder: (context) => MealDialog(
        meal: meal,
        isSheet: useSheet,
        showPhotoSection: false,
        date: selectedDate,
        onSave: (updatedMeal) {
          if (meal != null) {
            ref
                .read(mealsProvider.notifier)
                .updateMeal(meal.id, updatedMeal.copyWith(id: meal.id));
          } else {
            ref.read(mealsProvider.notifier).addMeal(updatedMeal);
          }
        },
      ),
    );
  }

  static Future<void> showPhotoMeal(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final imagePickerService = ImagePickerService();
    final source = await _selectImageSource(context);
    if (source == null) return;

    final selectedImage = source == ImageSource.camera
        ? await imagePickerService.pickFromCamera()
        : await imagePickerService.pickFromGallery();

    if (selectedImage == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              source == ImageSource.camera
                  ? '카메라를 사용할 수 없습니다'
                  : '갤러리에 접근할 수 없습니다',
            ),
            backgroundColor: AppColors.warn,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    await showAdaptiveEntrySheet<void>(
      context: context,
      builder: (context) => MealDialog(
        isSheet: isCupertinoTarget,
        showPhotoSection: true,
        initialImage: selectedImage,
        date: ref.read(selectedDateStringProvider),
        onSave: (meal) {
          ref.read(mealsProvider.notifier).addMeal(meal);
        },
      ),
    );
  }

  static Future<void> showWorkout(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showAdaptiveEntrySheet<void>(
      context: context,
      builder: (context) => WorkoutDialog(
        isSheet: isCupertinoTarget,
        date: ref.read(selectedDateProvider),
        onSave: (workout) {
          ref.read(workoutsProvider.notifier).addWorkout(workout);
        },
      ),
    );
  }

  static Future<void> showPostureAssessment(
    BuildContext context, {
    ExerciseType? initialExercise,
  }) async {
    await Navigator.of(context).push(
      adaptivePageRoute(
        fullscreenDialog: true,
        builder: (context) => PostureAssessmentScreen(
          initialExercise: initialExercise,
        ),
      ),
    );
  }

  static Future<ImageSource?> _selectImageSource(BuildContext context) async {
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    if (isIOS) {
      return showCupertinoModalPopup<ImageSource>(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: const Text('음식 사진 추가'),
          message: const Text('사진을 선택하거나 촬영하세요'),
          actions: [
            CupertinoActionSheetAction(
              child: const Text('갤러리에서 선택'),
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
            ),
            CupertinoActionSheetAction(
              child: const Text('사진 촬영'),
              onPressed: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('취소'),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      );
    }

    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(
              Icons.photo_library,
              color: AppColors.brandPrimary,
            ),
            title: const Text('갤러리에서 선택'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(
              Icons.camera_alt,
              color: AppColors.brandPrimary,
            ),
            title: const Text('사진 촬영'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
