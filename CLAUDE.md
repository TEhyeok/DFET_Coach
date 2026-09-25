# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Karpathy-Inspired Coding Guidelines

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" -> "Write tests for invalid inputs, then make them pass"
- "Fix the bug" -> "Write a test that reproduces it, then make it pass"
- "Refactor X" -> "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```text
1. [Step] -> verify: [check]
2. [Step] -> verify: [check]
3. [Step] -> verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

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

## D-FET Coach v1 개발
- 정본: [docs/PRD_V1.md](docs/PRD_V1.md). 개발 문서: [docs/v1/00_README.md](docs/v1/00_README.md)(지도), [docs/v1/13_DEV_ENVIRONMENT_AND_AGENT_PLAYBOOK.md](docs/v1/13_DEV_ENVIRONMENT_AND_AGENT_PLAYBOOK.md)(에이전트 규약).
- 작업은 이슈의 에이전트 작업 지시서(V1-T08)에 적힌 수정 허용 경로 안에서만 한다.
- 금지: main 직접 푸시·병합·배포, 운영 데이터 접근·이관 실행, 비밀 파일(.env*, .secret.local, GoogleService-Info.plist 값, 키)과 output/·tmp/ 열람.
- 금지: GitHub 이슈 생성, PRD 직접 수정(수정 제안만).
- 모든 검증은 합성 데이터와 에뮬레이터로 하고 증빙을 PR에 첨부한다.
