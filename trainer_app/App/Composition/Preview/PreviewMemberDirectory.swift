#if DEBUG
import Foundation
import TrainerDomain

/// DEBUG preview `MemberDirectory` (DF-013): synthetic members, a scripted failure, or members held until the test
/// releases them.
struct PreviewMemberDirectory: MemberDirectory {
  let script: PreviewMemberScript
  let gate: PreviewMemberGate

  func observeAssignedMembers() -> AsyncThrowingStream<[Member], Error> {
    let script = script
    let gate = gate
    return AsyncThrowingStream { continuation in
      switch script {
      case let .members(members, waitsForRelease: true):
        let task = Task {
          while !gate.isReleased {
            guard (try? await Task.sleep(nanoseconds: 100_000_000)) != nil else { return }
          }
          continuation.yield(members)
        }
        continuation.onTermination = { _ in task.cancel() }
      case let .members(members, _):
        continuation.yield(members)
      case let .failure(error):
        continuation.finish(throwing: error)
      }
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
#endif
