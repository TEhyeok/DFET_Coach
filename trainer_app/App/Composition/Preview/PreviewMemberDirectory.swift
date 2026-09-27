#if DEBUG
import TrainerDomain

/// `--preview-members*`: a `MemberDirectory` that emits the scripted list once, or fails (DF-013, TC-DF013-04).
struct PreviewMemberDirectory: MemberDirectory {
  let script: PreviewMemberScript

  func observeAssignedMembers() -> AsyncThrowingStream<[Member], Error> {
    let script = script
    return AsyncThrowingStream { continuation in
      switch script {
      case let .members(members, delay) where delay > 0:
        let task = Task {
          try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
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
#endif
