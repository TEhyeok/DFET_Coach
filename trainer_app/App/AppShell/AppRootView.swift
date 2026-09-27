import FeatureAuth
import SwiftUI
import TrainerDomain

/// Top of the window: configuration-missing screen, or the AppShell with the environment's flags and members.
struct AppRootView: View {
  let environment: AppEnvironment
  /// Used only for `.live`. The app passes FirebaseData's implementation (`AppBootstrap.liveAuthService()`).
  let liveAuth: any AuthService

  var body: some View {
    switch environment {
    case .misconfigured:
      ConfigurationMissingView()
    case .live:
      // Trainer-claim login in front of the shell; claim loss returns here (DF-012).
      AuthGate(auth: liveAuth) { _ in
        RootSplitView(flags: environment.flags, members: environment.members)
      }
    #if DEBUG
    case let .preview(preview):
      PreviewRootView(preview: preview)
    #endif
    }
  }
}
