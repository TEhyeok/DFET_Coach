import FeatureAuth
import SwiftUI
import TrainerDomain

/// Top of the window: configuration-missing screen, or the AppShell with the environment's flags and members.
struct AppRootView: View {
  let environment: AppEnvironment
  /// Used only for `.live`. The app passes FirebaseData's implementation (`AppBootstrap.liveAuthService()`).
  let liveAuth: any AuthService
  /// Used only for `.live`: the signed-in trainer's services (member directory, registration on LocalStore).
  let liveServices: @MainActor (_ session: TrainerSession, _ gate: AuthGateModel) -> ShellServices

  var body: some View {
    switch environment {
    case .misconfigured:
      ConfigurationMissingView()
    case .live:
      // Trainer-claim login in front of the shell; claim loss returns here (DF-012).
      AuthGate(auth: liveAuth) { session, gate in
        RootSplitView(flags: environment.flags, services: liveServices(session, gate))
          .id(session.uid)  // a different trainer gets a fresh shell and subscription
      }
    #if DEBUG
    case let .preview(preview):
      PreviewRootView(preview: preview)
    #endif
    }
  }
}
