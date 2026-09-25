# D-FET Trainer (`trainer_app/`)

Canonical iPad app for trainers (decision D2, [ADR-001](../docs/v1/adr/ADR-001-independent-trainer-app.md)).
Bundle `kr.co.dfet.trainer`, iOS 17.0+, iPad only (`TARGETED_DEVICE_FAMILY = 2` until DF-904 / Q-22 says otherwise).
This folder was created by DF-008 as a buildable skeleton; screens arrive with DF-017 and later stories.

## Layout

| Path | What | Notes |
|---|---|---|
| `project.yml`, `.xcodegen-version` | XcodeGen spec, pinned generator (2.44.1) | Edit the spec, never the generated project |
| `DFETTrainer.xcodeproj/` | Generated, **committed** | CI regenerates it and fails on any diff |
| `App/` | App target: `DFETTrainerApp`, `AppDelegate`, `Composition/LaunchConfiguration`, `AppShell/` placeholders, `Resources/` | No Firebase import here (V1-04 ASM-04-03) |
| `Config/{Debug,Release}.xcconfig` | Build configuration, no secrets | `GoogleService-Info.plist` goes here locally, untracked |
| `Packages/TrainerCore` | Pure Swift: TrainerContracts, TrainerDomain, PostureMath, SyncEngine, TrainerAnalytics | iOS 17 + macOS 14, `swift test` on macOS. No UIKit/SwiftUI/SwiftData/Firebase imports |
| `Packages/TrainerKit` | iOS-only: LocalStore, FirebaseData, PostureVision, DesignSystem, 11 Feature* targets | Firebase SDK is declared here and linked **only** by `FirebaseData` |
| `AppTests/` | Host-less unit tests for App code (`LaunchConfiguration`) | |
| `UITests/` | XCUITest (`--preview-*` launches) | |
| `IntegrationTests/` | Emulator integration tests (DF-107) | Placeholder only; CI skips it |
| `scripts/ci_pick_ipad.sh` | Prints one available iPad simulator UDID (creates one if none exists) | |

`TrainerContracts/Generated/` is owned by DF-004 (contracts generator); do not edit it by hand.

## Commands

Run from the repository root.

```bash
xcodegen version                                   # must print 2.44.1 (install the release zip, not brew)
xcodegen generate --spec trainer_app/project.yml --project trainer_app
git diff --exit-code -- trainer_app/DFETTrainer.xcodeproj

swift test --package-path trainer_app/Packages/TrainerCore

UDID=$(bash trainer_app/scripts/ci_pick_ipad.sh)
xcodebuild test -project trainer_app/DFETTrainer.xcodeproj -scheme DFETTrainer \
  -destination "id=${UDID}" -clonedSourcePackagesDirPath trainer_app/.spm \
  -skip-testing:DFETTrainerIntegrationTests CODE_SIGNING_ALLOWED=NO

xcodebuild build -project trainer_app/DFETTrainer.xcodeproj -scheme DFETTrainer -configuration Release \
  -destination 'generic/platform=iOS' -clonedSourcePackagesDirPath trainer_app/.spm CODE_SIGNING_ALLOWED=NO
```

The same steps run in `.github/workflows/trainer-app.yml` (job `trainer-app`), which only runs when
`trainer_app/**`, `contracts/**` or the workflow file changes.

## Launch modes (`App/Composition/LaunchConfiguration.swift`)

| Build | Arguments | GoogleService-Info.plist | Mode |
|---|---|---|---|
| Debug | `--preview-<scenario>` (e.g. `--preview-empty`) | not needed | `preview`: Firebase is never configured |
| Debug | `--use-emulator` [`--emulator-host=<ip>`] | required | `emulator` (default host 127.0.0.1, project `demo-dfet`) |
| Debug / Release | none | missing | `misconfigured`: configuration-missing screen, never preview data |
| Debug / Release | none | present | `production` |

Release builds ignore `--preview-*`, `--use-emulator` and `--emulator-host=`.
App Check: DEBUG uses `AppCheckDebugProviderFactory`, Release uses App Attest
(`FirebaseBootstrap.configure(_:)` in FirebaseData).

## GoogleService-Info.plist rules (ADR-019)

- Never commit it. `trainer_app/.gitignore` ignores `Config/GoogleService-Info.plist`.
- `project.yml` does **not** reference the plist. The app target's "Copy Firebase config if present" build phase
  copies it into the bundle only when it exists, so builds without it (CI, agents) still succeed.
- The owner keeps the file outside the repository and copies it into `Config/` only for device or production builds.
  CI injection from the `TRAINER_GOOGLE_SERVICE_INFO_PLIST_B64` secret is added by DF-034.
- AI agents never create, open or print this file.

## Relationship to `trainer_ios/`

`trainer_ios/` is the frozen source of earlier prototypes. It is read-only reference material for porting
(XcodeGen skeleton, App Check setup, `--preview-*` arguments) and is deleted at the end of P1a (DF-142).
Differences: iOS 17.0 instead of 16.0, iPad only instead of `"1,2"`, no widget extension or App Group,
Firebase isolated in `FirebaseData`.

