import FirebaseFirestore
import Foundation
import TrainerDomain

/// The live flags of live and emulator builds: `appConfig/features` from a Firestore listener (ADR-010, V1-05 §4.17,
/// AC-IA-02). The rules let any signed-in user read it, so the shell subscribes once a trainer is signed in; every
/// change reaches the entry points while the app runs. Fail-closed like `FeatureFlags(map:)`: no document or no key is
/// off, and a read that fails (refused, or the listener's error) gives `.allOff` and ends the stream. The listener is
/// in `FirestoreListenerRegistry`, so logout removes it.
public final class FirestoreFeatureFlags: FeatureFlagsProvider, @unchecked Sendable {
  static let path = "appConfig/features"

  private let lock = NSLock()
  private var latest = FeatureFlags.allOff

  /// Touches no Firebase API: the listener starts with the first `updates()`.
  public init() {}

  public var current: FeatureFlags { lock.withLock { latest } }

  public func updates() -> AsyncStream<FeatureFlags> {
    AsyncStream { continuation in
      let registration = Firestore.firestore().document(Self.path).addSnapshotListener { snapshot, error in
        if error != nil {
          self.publish(.allOff, to: continuation)
          continuation.finish()
          return
        }
        guard let snapshot else { return }
        self.publish(Self.flags(document: snapshot.exists ? snapshot.data() : nil), to: continuation)
      }
      let token = FirestoreListenerRegistry.shared.add(registration)
      continuation.onTermination = { _ in FirestoreListenerRegistry.shared.remove(token) }
    }
  }

  /// The flags of a snapshot's data; nil (no document) is every flag off.
  static func flags(document data: [String: Any]?) -> FeatureFlags {
    FeatureFlags(map: data)
  }

  private func publish(_ flags: FeatureFlags, to continuation: AsyncStream<FeatureFlags>.Continuation) {
    lock.withLock { latest = flags }
    continuation.yield(flags)
  }
}
