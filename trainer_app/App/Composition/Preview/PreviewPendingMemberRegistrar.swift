#if DEBUG
import Foundation
import TrainerDomain

/// DEBUG preview registrar (DF-108): keeps registrations in memory and returns synthetic 20-character IDs. Nothing
/// is sent anywhere, so every registration stays a device-only pending member that TR-02 lists (DF-113). A cancel
/// (AC-DF-113.6, AC-DF-110.5) stays a device-only cancel: TR-02 hides the member, whether the scenario's server list
/// or this launch's registrations have it.
final class PreviewPendingMemberRegistrar: PendingMemberRegistrar, PendingMemberCanceller, LocalPendingMemberSource,
  @unchecked Sendable
{
  private let lock = NSLock()
  private var device = DevicePendingMembers()
  private var observers: [UUID: AsyncStream<DevicePendingMembers>.Continuation] = [:]

  func register(_ draft: PendingMemberDraft) async throws -> String {
    guard draft.problems(now: Date()).isEmpty else { throw PendingMemberRegistrationError.invalidDraft }
    // Yielded under the lock, so observers see the values in registration order.
    return lock.withLock {
      let id = "SynPending" + String(format: "%010d", device.registered.count + 1)
      device.registered.append(PendingMember(id: id, displayName: draft.trimmedName))
      observers.values.forEach { $0.yield(device) }
      return id
    }
  }

  func cancel(pendingMemberId: String) async throws {
    lock.withLock {
      device.cancelled.insert(pendingMemberId)
      observers.values.forEach { $0.yield(device) }
    }
  }

  func observeLocalPendingMembers() -> AsyncStream<DevicePendingMembers> {
    AsyncStream { continuation in
      let token = UUID()
      lock.withLock {
        observers[token] = continuation
        continuation.yield(device)
      }
      continuation.onTermination = { [weak self] _ in
        self?.lock.withLock { _ = self?.observers.removeValue(forKey: token) }
      }
    }
  }
}
#endif
