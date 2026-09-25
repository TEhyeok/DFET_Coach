import SwiftUI

/// Top of the window: configuration-missing screen, or the AppShell with the environment's flags and members.
struct AppRootView: View {
  let environment: AppEnvironment

  var body: some View {
    switch environment {
    case .misconfigured:
      ConfigurationMissingView()
    case .live:
      // Login (FeatureAuth) is placed in front of the shell by DF-012.
      RootSplitView(flags: environment.flags, members: environment.members)
    #if DEBUG
    case let .preview(preview):
      PreviewRootView(preview: preview)
    #endif
    }
  }
}
