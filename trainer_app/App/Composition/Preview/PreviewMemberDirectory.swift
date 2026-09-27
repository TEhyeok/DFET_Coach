#if DEBUG
import TrainerDomain

/// `--preview-members*`: a `MemberDirectory` that emits the scripted list once, or fails (DF-013, TC-DF013-04).
struct PreviewMemberDirectory: MemberDirectory {
  let script: PreviewMemberScript

  func observeAssignedMembers() -> AsyncThrowingStream<[Member], Error> {
    let script = script
    return AsyncThrowingStream { continuation in
      switch script {
      case let .members(members):
        continuation.yield(members)
      case let .failure(error):
        continuation.finish(throwing: error)
      }
    }
  }
}
#endif
