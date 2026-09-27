#if DEBUG
import Foundation
import TrainerDomain

/// DEBUG preview `MemberDirectory` (DF-013, DF-113): synthetic assigned and pending members, a scripted failure, or
/// members held until the test releases them.
struct PreviewMemberDirectory: MemberDirectory {
  let script: PreviewMemberScript
  let gate: PreviewMemberGate

  func observeAssignedMembers() -> AsyncThrowingStream<[Member], Error> {
    switch script {
    case let .members(members, _, waitsForRelease):
      return stream(members, waitsForRelease: waitsForRelease)
    case let .failure(error):
      return AsyncThrowingStream { $0.finish(throwing: error) }
    }
  }

  func observePendingMembers() -> AsyncThrowingStream<[PendingMember], Error> {
    switch script {
    case let .members(_, pending, waitsForRelease):
      return stream(pending, waitsForRelease: waitsForRelease)
    case let .failure(error):
      return AsyncThrowingStream { $0.finish(throwing: error) }
    }
  }

  private func stream<T: Sendable>(_ value: T, waitsForRelease: Bool) -> AsyncThrowingStream<T, Error> {
    let gate = gate
    return AsyncThrowingStream { continuation in
      guard waitsForRelease else {
        continuation.yield(value)
        return
      }
      let task = Task {
        while !gate.isReleased {
          guard (try? await Task.sleep(nanoseconds: 100_000_000)) != nil else { return }
        }
        continuation.yield(value)
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }
}

/// `--preview-members-slow`: the member list stays loading until `preview.releaseMembers` is tapped. Deterministic
/// however long the launch takes on a CI runner.
final class PreviewMemberGate: @unchecked Sendable {
  private let lock = NSLock()
  private var released = false

  var isReleased: Bool { lock.withLock { released } }

  func release() {
    lock.withLock { released = true }
  }
}

/// DEBUG preview consent (DF-113): each member's scripted `EffectiveConsent`, or no consent at all (`.none`) for a
/// member the script does not name, such as one registered in this launch.
struct PreviewConsentSource: EffectiveConsentSource {
  let script: [MemberKey: EffectiveConsent]

  func observe(member: MemberKey) -> AsyncStream<EffectiveConsent> {
    let value = script[member] ?? .none
    return AsyncStream { $0.yield(value) }
  }
}
#endif
