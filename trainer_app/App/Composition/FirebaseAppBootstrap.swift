import FeatureAuth
import FirebaseData
import Foundation
import TrainerDomain

extension AppBootstrap {
  /// The real bootstrap: plist presence from the bundle and `FirebaseBootstrap.configure(_:)` from FirebaseData.
  /// The App target still imports no Firebase module (AC-DF-008.2, V1-04 ASM-04-03).
  static func firebase(bundle: Bundle) -> AppBootstrap {
    AppBootstrap(plistPresent: LaunchConfiguration.plistPresent(in: bundle)) { backend in
      switch backend {
      case .production:
        FirebaseBootstrap.configure(.production)
      case let .emulator(host):
        FirebaseBootstrap.configure(.emulator(host: host))
      }
    }
  }

  /// FirebaseData's `AuthService` (DF-012). Firebase Auth is touched only when a method is called, i.e. after
  /// `configureLive` has run for a `.live` environment.
  static func liveAuthService() -> any AuthService {
    FirebaseAuthService()
  }

  /// FirebaseData's `MemberDirectory` for the signed-in trainer (DF-013, DF-113).
  static func liveMemberDirectory(trainerUid: String) -> any MemberDirectory {
    FirestoreMemberDirectory(trainerUid: trainerUid)
  }

  /// FirebaseData's `RemoteWriter` for the signed-in trainer (DF-104); the SyncEngine's document writes.
  static func liveRemoteWriter(trainerUid: String) -> any RemoteWriter {
    FirestoreRemoteWriter(trainerUid: trainerUid)
  }

  /// The signed-in trainer's shell services (DF-108, DF-018): FirebaseData's member directory, registration on the
  /// LocalStore partition with the SyncEngine sending to FirebaseData, its queue for TR-15 and the full logout.
  /// `gate` signs the trainer out as a user sign-out (no claim-revoked notice); tests without a gate pass nil.
  @MainActor
  static func liveServices(session: TrainerSession, gate: AuthGateModel? = nil) -> ShellServices {
    let trainerUid = session.uid
    let runtime = SessionRuntime.Cache.shared.runtime(trainerUid: trainerUid) {
      SyncRemote(
        writer: liveRemoteWriter(trainerUid: trainerUid), uploader: StorageBinaryUploader(),
        callable: FunctionsCallableClient(), currentUid: { FirebaseAuthService.currentUid() },
        sessions: { liveAuthService().sessionStream() })
    }
    return ShellServices(
      memberDirectory: liveMemberDirectory(trainerUid: trainerUid),
      localPendingMembers: runtime?.localPendingMembers ?? SessionRuntime.NoLocalPendingMembers(),
      consentStatus: UnresolvedConsentSource(),
      registrar: runtime?.registrar ?? SessionRuntime.UnavailableRegistrar(),
      syncQueue: runtime?.engine ?? SessionRuntime.UnavailableSyncQueue(),
      signOut: LiveSessionSignOut(
        trainerUid: trainerUid,
        signOutAuth: { @MainActor in
          if let gate {
            try await gate.signOut(discardUnsynced: false)
          } else {
            try await liveAuthService().signOut(discardUnsynced: false)
          }
        },
        teardownRemote: { try await FirestoreSessionTeardown.run() }),
      accountName: session.displayName)
  }
}
