#if DEBUG
import Foundation
import TrainerDomain

/// DEBUG preview registrar (DF-108): keeps registrations in memory and returns synthetic 20-character IDs. Nothing
/// is sent anywhere.
final class PreviewPendingMemberRegistrar: PendingMemberRegistrar, @unchecked Sendable {
  private let lock = NSLock()
  private var registered: [PendingMemberDraft] = []

  func register(_ draft: PendingMemberDraft) async throws -> String {
    guard draft.problems(now: Date()).isEmpty else { throw PendingMemberRegistrationError.invalidDraft }
    let count = lock.withLock { () -> Int in
      registered.append(draft)
      return registered.count
    }
    return "SynPending" + String(format: "%010d", count)
  }
}
#endif
