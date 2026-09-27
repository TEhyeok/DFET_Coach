#if DEBUG
import Foundation
import TrainerDomain

/// DEBUG preview registrar (DF-108): keeps registrations in memory and returns synthetic 20-character IDs. Nothing
/// is sent anywhere, so every registration stays a device-only pending member that TR-02 lists (DF-113).
final class PreviewPendingMemberRegistrar: PendingMemberRegistrar, LocalPendingMemberSource, @unchecked Sendable {
  private let lock = NSLock()
  private var registered: [PendingMember] = []
  private var observers: [UUID: AsyncStream<[PendingMember]>.Continuation] = [:]

  func register(_ draft: PendingMemberDraft) async throws -> String {
    guard draft.problems(now: Date()).isEmpty else { throw PendingMemberRegistrationError.invalidDraft }
    // Yielded under the lock, so observers see the lists in registration order.
    return lock.withLock {
      let id = "SynPending" + String(format: "%010d", registered.count + 1)
      registered.append(PendingMember(id: id, displayName: draft.trimmedName))
      observers.values.forEach { $0.yield(registered) }
      return id
    }
  }

  func observeLocalPendingMembers() -> AsyncStream<[PendingMember]> {
    AsyncStream { continuation in
      let token = UUID()
      lock.withLock {
        observers[token] = continuation
        continuation.yield(registered)
      }
      continuation.onTermination = { [weak self] _ in
        self?.lock.withLock { _ = self?.observers.removeValue(forKey: token) }
      }
    }
  }
}
#endif
