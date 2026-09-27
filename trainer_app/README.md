# D-FET Trainer (`trainer_app/`)

Canonical iPad app for trainers (decision D2, [ADR-001](../docs/v1/adr/ADR-001-independent-trainer-app.md)).
Bundle `kr.co.dfet.trainer`, iOS 17.0+, iPad only (`TARGETED_DEVICE_FAMILY = 2` until DF-904 / Q-22 says otherwise).
This folder was created by DF-008 as a buildable skeleton. DF-017 added the AppShell (routes, dependency
assembly, flag-gated entry points); screens arrive with later stories.

## Layout

| Path | What | Notes |
|---|---|---|
| `project.yml`, `.xcodegen-version` | XcodeGen spec, pinned generator (2.44.1) | Edit the spec, never the generated project |
| `DFETTrainer.xcodeproj/` | Generated, **committed** | CI regenerates it and fails on any diff |
| `App/` | App target: `DFETTrainerApp`, `AppDelegate`, `Composition/` (`LaunchConfiguration`, `FirebaseAppBootstrap`, DEBUG-only `Preview/`), `AppShell/`, `Resources/` | No Firebase import here (V1-04 ASM-04-03) |
| `Config/{Debug,Release}.xcconfig` | Build configuration, no secrets | `GoogleService-Info.plist` goes here locally, untracked |
| `Packages/TrainerCore` | Pure Swift: TrainerContracts, TrainerDomain, PostureMath, SyncEngine, TrainerAnalytics | iOS 17 + macOS 14, `swift test` on macOS. No UIKit/SwiftUI/SwiftData/Firebase imports |
| `Packages/TrainerKit` | iOS-only: LocalStore, FirebaseData, PostureVision, DesignSystem, 11 Feature* targets | Firebase SDK is declared here and linked **only** by `FirebaseData` |
| `AppTests/` | Host-less unit tests for pure App code (`LaunchConfiguration`, `AppEnvironment`, `FlagGate`, `TrainerRoute`, `LayoutMode`, `ShellNavigation`) | Sources listed one by one in `project.yml` |
| `UITests/` | XCUITest (`--preview-*` launches) | |
| `IntegrationTests/` | Auth, member, remote-write, consent and measurement emulator tests | Run the scripts below; the general unit job skips emulator tests |
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
`trainer_app/**`, `contracts/**` or the workflow file changes. On `main` and manual runs it also injects the
Firebase config; see [CI injection](#ci-injection-githubworkflowstrainer-appyml-job-trainer-app).

## Launch modes (`App/Composition/LaunchConfiguration.swift`)

| Build | Arguments | GoogleService-Info.plist | Mode |
|---|---|---|---|
| Debug | `--preview-<scenario>` (e.g. `--preview-empty`) | not needed | `preview`: Firebase is never configured |
| Debug | `--use-emulator` [`--emulator-host=<ip>`] | not needed, never read | `emulator` (default host 127.0.0.1): synthetic options, project `demo-dfet`, local App Check provider |
| Debug / Release | none | missing | `misconfigured`: configuration-missing screen, never preview data |
| Debug / Release | none | present | `production` |

Rows are checked top to bottom. Release builds ignore `--preview-*`, `--use-emulator` and `--emulator-host=`.
The app resolves this once through `AppEnvironment.resolveAtLaunch(arguments:processEnvironment:bootstrap:)`
(process arguments + XCTest guard, build configuration, plist presence from `AppBootstrap.firebase(bundle:)`); the
unit tests call the same function.
App Check: DEBUG uses `AppCheckDebugProviderFactory`, Release uses App Attest
(`FirebaseBootstrap.configure(_:)` in FirebaseData). Emulator mode never uses the bundled plist or the App Check
exchange endpoint, so it cannot reach the production project even when a plist is present locally.

## AppShell (`App/AppShell/`, DF-017)

| File | Role |
|---|---|
| `AppEnvironment.swift` | `AppEnvironment.resolveAtLaunch(...)` / `resolve(arguments:isDebug:bootstrap:)` -> `.live` (FirebaseData, flags fixed to `.allOff` until P1a), `.preview` (DEBUG only, in-memory synthetic data) or `.misconfigured` (no Firebase call). Firebase is configured through the injected `AppBootstrap` for `.live` only |
| `TrainerRoute.swift` | `today` (TR-01), `members` (TR-02), `memberDetail(uid:)` (TR-03), `settings` (TR-15). No schedule/program/alerts (AS-21) |
| `FlagGate.swift` | `EntryPoint` list and the pure `FlagGate.isEntryVisible(_:flags:)` table (AC-IA-02). Gated entries without a screen open `common.comingSoon` |
| `LayoutMode.swift` | `LayoutMode.for(width:)`: detail width < 1120pt is `.compact` (ASM-P0-22) |
| `RootSplitView.swift` | NavigationSplitView (sidebar, content, detail); a compact size class switches to a NavigationStack |
| `ShellNavigation.swift` | Layout-independent place (sidebar selection + detail) and its mapping to/from the stack path, so a size-class change keeps the screen (NFR-12) |

`FeatureFlags` (8 keys, `.allOff`) lives in `TrainerCore/TrainerDomain/FeatureFlags.swift`; DF-027 swaps its key
constants for the generated `FeatureFlagKey`.

## Preview arguments (DEBUG only)

Every argument below is ignored in Release. Any `--preview-*` argument means preview mode (no Firebase, synthetic
`SYN-*` data only). The first known scenario name wins; without one the scenario is `empty`. An unknown
`--preview-<name>` (for example the typo `--preview-member`) shows `preview.unknownArgument` instead of the shell.

| Argument | Effect |
|---|---|
| `--preview-empty` | Shell with every flag off and no members |
| `--preview-login` | Signed-out state: login placeholder (`login.root`) until DF-012 |
| `--preview-members` | Three synthetic members (`SYN-0001`..`SYN-0003`) |
| `--preview-workflow --preview-flags=bodyComposition` | Interactive synthetic registration → consent → body composition entry and history; in-memory only, cleared on relaunch |
| `--preview-members-empty` | Member list query succeeded with 0 rows (`tr02.empty`) |
| `--preview-members-error` | Member list failed (`common.loadFailed` + `common.retry`), never shown as empty |
| `--preview-members-slow` | Member list stays loading (`tr02.loading`) until the DEBUG button `preview.releaseMembers` is tapped |
| `--preview-design-system` | DesignSystem gallery (`preview.designSystem`): every component with synthetic values, for layout checks and light/dark review (DF-016) |
| `--preview-queue-failed` | TR-15 upload queue with two synthetic failed items (a rule rejection and a retry limit); retrying succeeds at once |
| `--preview-landscape` | Requests landscape orientation (ported from `trainer_ios`) |
| `--preview-flags=<k1,k2>` | Local flag override for client entry points only (ADR-010 §3-6); unknown keys are ignored |
| `--preview-width=<pt>` | Renders the shell in a window of this width with a compact size class (1/3 Split View simulation, e.g. `375`) |
| `--preview-resizable` | With `--preview-width=`: a `preview.toggleWidth` button switches between that width and the full window at runtime (size-class change test, TC-DF017-06) |

## Registration, consent and measurements

TR-14 registers a pending member, then presents the three published core consent cards with no preselection.
Refusing required consent cancels that pending registration. The DEC-22 MVP records grants for pending members;
signatures, withdrawals and signed-up-member consent capture remain deferred.

`LocalWorkflowService` saves each capture or measurement atomically with its Outbox item before returning.
The engine sends member creation, consent, measurement and the optional pending-member height update in that
order. Local consent allows values-only drafts while awaiting server confirmation. Height entry appears after
health-data consent is confirmed. The save badge follows the engine's actual state, and server acknowledgements
are required before it says synced. Recent device names are kept per trainer in SwiftData schema 1.2; the migration
also makes the deferred consent signature optional while preserving existing signature IDs.

The `bodyComposition` flag controls the TR-03 measurement entry and history. A DEBUG demo can use the preview
arguments above; the server rule independently requires the flag for a real write.

For the real Apple client → emulator workflow, with Node 22, Java 21, Firebase CLI and installed Functions dependencies:

```bash
bash trainer_app/scripts/test_workflow_emulator.sh
```

The script creates an isolated Functions source directory from explicit source paths, uses only synthetic values
and project `demo-dfet`, and never copies local Firebase configuration or environment files. It runs the consent,
body composition and registration cancellation integration tests. `test_auth_emulator.sh` runs the broader auth
and remote-writer suite separately.
For concurrent development, use a dedicated simulator with `XCODEBUILD_DESTINATION='id=<UDID>'` and set
`DFET_EMULATOR_PORT_OFFSET=1000` to move every emulator port together. DEBUG test clients use the same offset;
Release ignores it. The script refuses occupied ports without stopping another run.

## GoogleService-Info.plist rules (ADR-019, DF-034)

- Never commit it. Both `trainer_app/.gitignore` and the root `.gitignore` ignore `Config/GoogleService-Info.plist`;
  `git check-ignore trainer_app/Config/GoogleService-Info.plist` prints the path (AC-DF-034.1).
- `project.yml` does **not** reference the plist. The app target's "Copy Firebase config if present" build phase
  copies it into the bundle only when it exists, so builds without it (CI, agents) still succeed and launch in
  `misconfigured` mode.
- AI agents never create, open or print this file.

### Local placement (owner only)

1. Download `GoogleService-Info.plist` for the iOS app `kr.co.dfet.trainer` from the Firebase console (project
   settings, registered by DF-903). Keep the original outside the repository, e.g. `~/secure/dfet/trainer/`.
2. Only for a device or production-connected build, copy it to `trainer_app/Config/GoogleService-Info.plist`.
   Do not paste its contents anywhere (chat, issues, logs).
3. Never commit it. Before committing, `git status --short trainer_app/Config` must list nothing new; remove the copy
   when you are done (`rm trainer_app/Config/GoogleService-Info.plist`).

### CI injection (`.github/workflows/trainer-app.yml`, job `trainer-app`)

| Item | Value |
|---|---|
| Repository secret | `TRAINER_GOOGLE_SERVICE_INFO_PLIST_B64`: the plist, base64-encoded on one line. The owner registers it after DF-903, e.g. `base64 -i ~/secure/dfet/trainer/GoogleService-Info.plist \| gh secret set TRAINER_GOOGLE_SERVICE_INFO_PLIST_B64` (reads stdin, prints nothing) |
| Job env | `TRAINER_PLIST_CONFIGURED` = whether the secret is non-empty (a boolean, never the value) |
| When it injects | `push` to `main` and `workflow_dispatch`, and only when the secret is set. `pull_request` (same-repo or fork) never injects: GitHub exposes secrets to same-repo PRs, so the event decides (AC-DF-034.2) |
| What runs with it | Tests and the plist-less Release build run first on every event. After injection, one extra Release build checks that the bundle contains the file |
| Leak guards | The secret is only in the injection step's own env (xcodebuild steps never hold it); `set +x`; `base64 --decode` straight into the file; no step prints it; test results are uploaded only on `pull_request`; an `if: always()` step deletes the file and its bundle copy |
| Static check | `bash tool/lint/check-workflow-secrets.sh .github/workflows/trainer-app.yml` (C1 gate, C2 no printing, C3 PR-only artifacts, C4 cleanup). `tool/lint/static-guards.sh` runs it as W1 in the required `static-guards` job (AC-DF-034.3) |
| Owner log check (AC-DF-034.5) | After the first injecting `main` run: `gh run view <run-id> --log \| grep -cF "$KEY"` for the plist's `API_KEY` and `GOOGLE_APP_ID` values (kept in shell variables, never written down) must both print `0`; record only "0 hits", the run ID and the time in `docs/v1/evidence/G-02.md` |

Without the secret (forks, agents, before DF-903) the job still passes: every build runs without the plist.

## Relationship to `trainer_ios/`

`trainer_ios/` is the frozen source of earlier prototypes. It is read-only reference material for porting
(XcodeGen skeleton, App Check setup, `--preview-*` arguments) and is deleted at the end of P1a (DF-142).
Differences: iOS 17.0 instead of 16.0, iPad only instead of `"1,2"`, no widget extension or App Group,
Firebase isolated in `FirebaseData`.
