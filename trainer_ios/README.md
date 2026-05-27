# D-FET Trainer iOS

Native SwiftUI iPad-first trainer app for SOAP notes, Apple Pencil session capture, member management, and trainer analytics.

## Structure

- `DFETTrainer/App`: app entry and iPad navigation shell
- `DFETTrainer/DesignSystem`: Health-style colors, cards, charts, Pencil controls
- `DFETTrainer/Domain`: trainer members, SOAP models, repository protocol, preview repository, app store
- `DFETTrainer/Features`: Login, Summary, Members, SOAP, Reports, Settings
- `DFETTrainerShared`: app/widget snapshot models
- `DFETTrainerWidgets`: WidgetKit extension for today sessions, SOAP todo, reassessment

## Build

```bash
cd trainer_ios
xcodegen generate
xcodebuild -scheme DFETTrainer -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' build
```

## Scope

- Standalone iOS app bundle: `kr.co.dfet.trainer`
- iPad-first SwiftUI navigation using `NavigationSplitView`
- SOAP workspace built with PencilKit and structured inputs
- WidgetKit extension reads an App Group JSON snapshot
- Firebase integration is intentionally isolated behind `TrainerRepository` for the next implementation pass.
