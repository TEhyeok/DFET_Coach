#if DEBUG
import Foundation
import TrainerDomain

/// DEBUG TR-15 queue (DF-018): an in-memory Outbox view. `--preview-queue-failed` starts with two synthetic failed
/// items; '다시 시도' succeeds at once and removes the item. Nothing is sent anywhere.
final class PreviewSyncQueue: SyncQueueService, @unchecked Sendable {
  private let lock = NSLock()
  private var failed: [OutboxItem]
  private var countContinuations: [UUID: AsyncStream<Int>.Continuation] = [:]
  private var failedContinuations: [UUID: AsyncStream<[OutboxItem]>.Continuation] = [:]

  init(failed: [OutboxItem] = []) {
    self.failed = failed
  }

  /// A rule rejection of a SOAP note and a pending member out of attempts. Synthetic IDs only.
  static func syntheticFailures() -> [OutboxItem] {
    let created = Date(timeIntervalSince1970: 1_780_000_000)
    return [
      OutboxItem(
        memberKey: .uid("syn-0001"), entityRef: .soap(noteId: "SynNote0000000000001"), sequence: 1, stage: .document,
        kind: .createDocument, target: .document(path: "soap_notes/SynNote0000000000001"), attempts: 1,
        state: .failed, lastErrorCode: "permission-denied", createdAt: created),
      OutboxItem(
        memberKey: .pending("SynPending0000000001"), entityRef: .pendingMember(id: "SynPending0000000001"),
        sequence: 1, stage: .memberKey, kind: .createDocument,
        target: .document(path: "pending_members/SynPending0000000001"), attempts: 5, state: .failed,
        lastErrorCode: "unavailable", createdAt: created.addingTimeInterval(60)),
    ]
  }

  func pendingCount() async -> AsyncStream<Int> {
    AsyncStream { continuation in
      let id = UUID()
      lock.withLock {
        countContinuations[id] = continuation
        continuation.yield(failed.count)
      }
      continuation.onTermination = { [weak self] _ in
        self?.lock.withLock { _ = self?.countContinuations.removeValue(forKey: id) }
      }
    }
  }

  func failedItems() async -> AsyncStream<[OutboxItem]> {
    AsyncStream { continuation in
      let id = UUID()
      lock.withLock {
        failedContinuations[id] = continuation
        continuation.yield(failed)
      }
      continuation.onTermination = { [weak self] _ in
        self?.lock.withLock { _ = self?.failedContinuations.removeValue(forKey: id) }
      }
    }
  }

  func retry(_ id: UUID) async {
    update { $0.removeAll { $0.id == id } }
  }

  func retryAll() async {
    update { $0.removeAll() }
  }

  private func update(_ change: (inout [OutboxItem]) -> Void) {
    lock.withLock {
      change(&failed)
      countContinuations.values.forEach { $0.yield(failed.count) }
      failedContinuations.values.forEach { $0.yield(failed) }
    }
  }
}

/// DEBUG TR-15 logout: signs the preview account out, which returns `--preview-login` to the login gate.
struct PreviewSessionSignOut: SessionSignOut {
  let auth: PreviewAuthService

  func signOut() async throws {
    try await auth.signOut(discardUnsynced: false)
  }
}
#endif
