import Foundation
import LocalStore
import os
import SwiftData
import TrainerDomain

/// TR-15 logout in the live app (DF-018, V1-04 §12.2 ②-⑦, ASM-P0-17). Unsynced records are never deleted: they stay
/// in the trainer's LocalStore partition and are sent after the same account signs in again.
///
/// Order: ② the SyncEngine stops; ③④ every Firestore listener is removed, Firestore terminated and its cache cleared;
/// ⑤ Firebase Auth signs out; ⑥ what the server already has is purged from the partition; ⑦ the runtime is dropped.
/// A failed ⑤ leaves the trainer signed in, so the runtime is put back and sends again.
struct LiveSessionSignOut: SessionSignOut {
  private static let logger = Logger(subsystem: "kr.co.dfet.trainer", category: "session")
  /// How long an item already being sent may take before Firestore is terminated under it.
  static let drainTimeout: Duration = .seconds(3)

  let trainerUid: String
  let auth: any AuthService
  /// FirebaseData's `FirestoreSessionTeardown.run()` (③④).
  let teardownRemote: @Sendable () async throws -> Void

  func signOut() async throws {
    let runtime = await SessionRuntime.Cache.shared.retire(trainerUid: trainerUid)
    await runtime?.stopSending(drainTimeout: Self.drainTimeout)
    do {
      try await teardownRemote()
    } catch {
      // Signing out still matters more than the cache: Firestore keeps pending writes per user and never sends them
      // under another account, and the next sign-in configures a fresh instance.
      Self.logger.fault("firestore teardown failed: \(String(describing: type(of: error)), privacy: .public)")
    }
    do {
      try await auth.signOut(discardUnsynced: false)
    } catch {
      if let runtime { await SessionRuntime.Cache.shared.reinstate(runtime) }
      throw error
    }
    if let runtime {
      await Self.purgeSynced(container: runtime.container, location: runtime.location, trainerUid: trainerUid)
    }
  }

  /// ⑥. A failure is logged only: the synced rows stay on the device until the next logout.
  private static func purgeSynced(container: ModelContainer, location: LocalStoreLocation, trainerUid: String) async {
    await Task.detached(priority: .utility) {
      do {
        let report = try LocalRetention(
          context: ModelContext(container), binaryStore: LocalBinaryStore(location: location), trainerUid: trainerUid
        ).purgeSynced()
        logger.info("purged synced records: outbox=\(report.destroyedOutboxItemIds.count, privacy: .public)")
      } catch {
        logger.error("purge after logout failed: \(String(describing: type(of: error)), privacy: .public)")
      }
    }.value
  }
}
