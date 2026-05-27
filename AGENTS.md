# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project Overview

D-FET is a Flutter-based fitness tracking application with iOS-native design, meal/workout tracking, and AI-powered nutrition analysis using Firebase Gemini API.

**Important**: This project has a nested directory structure (`dfet_coach/dfet_coach/`). All commands below should be run from the inner `dfet_coach` directory (the one containing `pubspec.yaml`).

## Development Commands

### Running the App
```bash
# iOS Simulator (primary target)
flutter run

# Specific device
flutter run -d <device-id>

# List available devices
flutter devices
```

### Building
```bash
# iOS (requires Mac with Xcode)
flutter build ios --no-codesign

# Android
flutter build apk

# Clean build artifacts
flutter clean
```

### Dependencies
```bash
# Get packages
flutter pub get

# Update iOS pods
cd ios && pod install && cd ..

# Clean and reinstall (when pod issues occur)
cd ios && rm -rf Pods Podfile.lock && pod install && cd ..
```

### Firebase Configuration
```bash
# Reconfigure Firebase for platforms
flutterfire configure --project=dfetmanage --platforms=ios,android

# Switch Firebase project
firebase use <project-name>
```

### Testing and Analysis
```bash
# Run all tests
flutter test

# Run a specific test file
flutter test test/widget_test.dart

# Run static analysis
flutter analyze
```

## Architecture

### State Management
- **Riverpod** for global state management
- `StateNotifierProvider` pattern for mutable state (meals, workouts)
- `Provider` for computed/derived state (totals, aggregations)
- State lives in `lib/state/app_state.dart`

### Platform-Specific UI
The app uses **dual UI systems** based on platform:
- **iOS**: `CupertinoApp` with `CupertinoTabScaffold` (main target)
- **Android**: `MaterialApp` with `Scaffold` (fallback)

Platform detection:
```dart
final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
```

**Critical**: When using Material widgets (Dialogs, SnackBars) in CupertinoApp, the app wraps them with a `Material` builder in `main.dart` to ensure compatibility.

### Navigation Structure
Tab-based navigation with 5 main screens:
1. **Dashboard** - Activity rings, wellness score, quick stats
2. **Meals** - Food tracking with AI nutrition analysis
3. **Workouts** - Exercise logging (strength/cardio) with posture assessment feature
4. **Reports** - Weekly analytics and charts
5. **Tickets** - User requests/coaching

Each screen is a `ConsumerWidget` that watches relevant Riverpod providers.

### Posture Assessment Feature
Real-time AI-powered exercise form evaluation using **Google ML Kit Pose Detection**:

**Supported Exercises**:
- Squat - Knee angle and alignment analysis
- Pushup - Elbow angle and body alignment
- Plank - Body line straightness

**Architecture** (`lib/services/pose_detection_service.dart`):
- `PoseDetector` with stream mode for real-time analysis
- Exercise-specific evaluation methods: `_evaluateSquat()`, `_evaluatePushup()`, `_evaluatePlank()`
- Angle calculation using joint landmarks (shoulders, elbows, hips, knees, ankles)
- Callback system: `onPoseDetected`, `onFormScoreUpdate`, `onFeedbackUpdate`

**Camera Integration**:
- `CameraController` with `ResolutionPreset.high`
- Image stream processing with `_processCameraImage()`
- Proper rotation handling via `InputImageRotation`
- Camera lifecycle management (initialize → startImageStream → stopImageStream → dispose)

**Permission Handling**:
- `permission_handler` package for camera permissions
- Deferred permission request (only when user starts assessment)
- Platform-specific dialogs for permission denied cases
- `openAppSettings()` integration for permanently denied permissions

**UI Flow**:
1. User navigates to Workouts → Posture Assessment (or from workout dialog)
2. Select exercise type (squat/pushup/plank)
3. Tap "평가 시작" → Permission check → Camera initialization
4. `CameraPreviewWidget` displays live camera feed with pose overlay
5. Real-time feedback: form score (0-100) and text guidance
6. `PoseOverlayPainter` draws skeleton landmarks on camera preview

### Theme System
**Dual theme implementation**:
- `lib/theme/app_theme.dart` - Material theme (Android)
- `lib/theme/ios_theme.dart` - Cupertino theme (iOS)
- `lib/theme/tokens.dart` - Shared design tokens (colors, spacing, radii)
- `lib/theme/text_styles.dart` / `ios_text_styles.dart` - Typography

Color system is dark-mode focused with semantic naming (bgRoot, bgApp, bgCard, textStrong, brandPrimary, etc.).

### Firebase Integration

**Current setup**: Project `dfetmanage` with iOS + Android platforms only.

**Firebase Vertex AI (Gemini)**:
- Located in `lib/services/nutrition_analyzer_service.dart`
- Model: `gemini-2.0-flash-exp`
- API structure: `Content.multi([TextPart(...), InlineDataPart(...)])`
- Returns JSON with nutrition data: `{name, calories, protein, carbs, fat, confidence}`

**Image Handling**:
- `image_picker` package for camera/gallery access
- `XFile` for web compatibility
- `ImagePickerService` abstracts platform differences
- Permissions configured in `ios/Runner/Info.plist` and `android/app/src/main/AndroidManifest.xml`

### Key Patterns

**Dialogs**:
- Platform-specific: `CupertinoAlertDialog` (iOS) vs `AlertDialog` (Android)
- Always check `if (mounted)` before showing dialogs after async operations
- Use `context.mounted` for Flutter 3.7+

**Form Inputs**:
- `MealDialog` and `WorkoutDialog` use `GlobalKey<FormState>` for validation
- Controllers are disposed in widget lifecycle
- Separate "manual entry" vs "photo-based entry" flows in `MealDialog`

**AI Analysis Flow** (meals.dart):
1. User taps "사진 추가" → `_showPhotoMealFlow()`
2. Platform-specific ActionSheet/BottomSheet for camera/gallery selection
3. Image picker service returns `XFile`
4. `MealDialog` displays with `showPhotoSection: true` and `initialImage`
5. User taps "AI로 영양소 분석" → calls `NutritionAnalyzerService`
6. Results auto-populate form fields (user can edit before saving)

**State Updates**:
```dart
// Add meal
ref.read(mealsProvider.notifier).addMeal(meal);

// Watch for updates
final meals = ref.watch(mealsProvider);
final totalCalories = ref.watch(totalCaloriesProvider);
```

## iOS-Specific Considerations

### Minimum Version
- iOS 15.0+ required (set in `ios/Podfile`)
- Firebase SDK 12.2.0 has this requirement

### CocoaPods
- Always run `pod install` after changing dependencies
- Use `pod repo update` if encountering version resolution errors
- Clean derived data if build database locks occur:
  ```bash
  rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*
  ```

### Permissions
Required Info.plist keys:
- `NSCameraUsageDescription` - Camera access for food photos and posture assessment
- `NSPhotoLibraryUsageDescription` - Gallery access
- `NSBonjourServices` - Debug networking (development only)
- `NSLocalNetworkUsageDescription` - Local network for debugging

Note: Camera permission is also required for the posture assessment feature (handled by `permission_handler` package)

### CupertinoApp Localization
Must include Material localizations for Material widgets:
```dart
localizationsDelegates: const [
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
],
```

## Data Models

**Meal** (`lib/models/meal.dart`):
- Simple immutable model with `copyWith()`
- Fields: id, time (HH:MM), name, calories, protein, carbs, fat

**Workout** (`lib/models/workout.dart`):
- Category: 'strength' or 'cardio'
- Strength: includes `List<WorkoutSet>` (reps, weight)
- Cardio: includes duration (minutes)

## Firebase Gemini API Requirements

1. **Enable AI Logic** in Firebase Console:
   - Navigate to: Build → AI Logic (or Vertex AI)
   - Click "Get started" or "Enable"
   - Free tier: 15,000 requests/month

2. **API Call Structure**:
```dart
final model = FirebaseVertexAI.instance.generativeModel(
  model: 'gemini-2.0-flash-exp',
);

final response = await model.generateContent([
  Content.multi([
    TextPart(promptText),
    InlineDataPart('image/jpeg', imageBytes),
  ])
]);
```

3. **Expected JSON Response**:
```json
{
  "name": "음식명",
  "calories": 500,
  "protein": 30,
  "carbs": 60,
  "fat": 15,
  "confidence": "높음/중간/낮음"
}
```

4. **Error Handling**: Service includes JSON extraction logic to handle markdown code blocks (```json```) in responses.

## Common Issues

### Project Structure
- **Wrong directory**: Commands must be run from `dfet_coach/dfet_coach/` (inner directory with `pubspec.yaml`), not the parent directory
- If `flutter` commands fail, verify you're in the correct directory with `ls pubspec.yaml`

### Build Conflicts
- **Multiple Flutter instances**: Use `killall -9 Flutter Xcode` before rebuilding
- **Pod sync errors**: Delete `Pods/`, `Podfile.lock`, run `pod install`
- **Database locked**: Clean Xcode derived data:
  ```bash
  rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*
  ```
- **Stale build**: Run `flutter clean && flutter pub get` to reset build state

### Platform-Specific Bugs
- **Web not configured**: Only iOS/Android have Firebase setup (no web support currently)
- **Dialog not showing on iOS**: Ensure Material builder is present in CupertinoApp (see main.dart:49-54)
- **Image picker returns null**: Check permissions in `ios/Runner/Info.plist` and `android/app/src/main/AndroidManifest.xml`
- **Camera not initializing for pose detection**: Check camera permissions via `permission_handler`; ensure `NSCameraUsageDescription` is set in Info.plist
- **Pose detection lag**: ML Kit processes images asynchronously; `_isDetecting` flag prevents processing queue buildup

### API Errors
- **"Member not found" errors**: firebase_vertexai API uses `Content.multi()` + `InlineDataPart()`, not older API patterns
- **Gemini not responding**: Verify AI Logic is enabled in Firebase Console (Build → AI Logic)
- **JSON parsing fails**: Service includes extraction logic for markdown code blocks (```json```), but verify prompt asks for JSON-only output
- **API quota exceeded**: Free tier is 15,000 requests/month; check Firebase Console for usage
