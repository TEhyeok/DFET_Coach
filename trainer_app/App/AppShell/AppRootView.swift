import FeatureAuth
import SwiftUI
import TrainerDomain

/// Top of the window: configuration-missing screen, or the AppShell with the environment's flags and members.
struct AppRootView: View {
  let environment: AppEnvironment
  /// Used only for `.live`. The app passes FirebaseData's implementation (`AppBootstrap.liveAuthService()`).
  let liveAuth: any AuthService
  /// Used only for `.live`: the signed-in trainer's member directory (`AppBootstrap.liveMemberDirectory`).
  let liveMembers: (_ trainerUid: String) -> any MemberDirectory

  var body: some View {
    switch environment {
    case .misconfigured:
      ConfigurationMissingView()
    case .live:
      // Trainer-claim login in front of the shell; claim loss returns here (DF-012).
      AuthGate(auth: liveAuth) { session in
        RootSplitView(flags: environment.flags, memberDirectory: liveMembers(session.uid))
          .id(session.uid)  // a different trainer gets a fresh shell and subscription
      }
    #if DEBUG
    case let .preview(preview):
      PreviewRootView(preview: preview)
    #endif
    }
  }
}
