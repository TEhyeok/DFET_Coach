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

  /// FirebaseData's `MemberDirectory` for the signed-in trainer (DF-013).
  static func liveMemberDirectory(trainerUid: String) -> any MemberDirectory {
    FirestoreMemberDirectory(trainerUid: trainerUid)
  }

  /// FirebaseData's `RemoteWriter` for the signed-in trainer (DF-104); the SyncEngine's document writes.
  static func liveRemoteWriter(trainerUid: String) -> any RemoteWriter {
    FirestoreRemoteWriter(trainerUid: trainerUid)
  }

  /// The signed-in trainer's shell services (DF-108): FirebaseData's member directory, and registration on the
  /// LocalStore partition with the SyncEngine sending to FirebaseData.
  @MainActor
  static func liveServices(trainerUid: String) -> ShellServices {
    let runtime = SessionRuntime.Cache.shared.runtime(trainerUid: trainerUid) {
      SyncRemote(
        writer: liveRemoteWriter(trainerUid: trainerUid), uploader: StorageBinaryUploader(),
        callable: FunctionsCallableClient())
    }
    return ShellServices(
      memberDirectory: liveMemberDirectory(trainerUid: trainerUid),
      registrar: runtime?.registrar ?? SessionRuntime.UnavailableRegistrar())
  }
}
