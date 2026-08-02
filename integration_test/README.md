# Integration tests

End-to-end tests that drive the real app UI by widget text (not coordinates).

## Run

On the default test environment (headless, widget-driven parts run under `flutter test`):

```bash
flutter test integration_test/onboarding_test.dart
```

On a connected real device or simulator:

```bash
# list available devices first
flutter devices

# then run against a specific device id
flutter test integration_test/ -d <device-id>
```

## What is covered

- `onboarding_test.dart` — full onboarding E2E flow:
  `시작하기` → `장내미생물 케어` → `다음` (x7 across 목표/성별/나이/키/몸무게/활동량) →
  `완료`, then asserts `guestCareTypeProvider == UserCareType.microbiome` and
  `hasSeenOnboardingProvider == true`.

## Notes

- The test wraps `OnboardingScreen` directly in `ProviderScope` + `MaterialApp`
  with a mocked `SharedPreferences` instead of booting `main()`, because Firebase
  initialization fails in the test environment.
- `GoogleFonts.config.allowRuntimeFetching = false` disables font network fetching.
- A fixed phone view size (`1179x2556`, dpr `3.0`) avoids layout overflow.
