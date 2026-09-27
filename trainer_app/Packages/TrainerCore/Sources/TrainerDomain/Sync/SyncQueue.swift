import Foundation

/// What TR-15 shows about the Outbox and what the trainer can do with it (DF-018): the unsynced count, the failed
/// items, '다시 시도' and '모두 다시 시도'. The SyncEngine implements it.
public protocol SyncQueueService: Sendable {
  /// Items not yet on the server (neither acked nor superseded): the current count, then every change.
  func pendingCount() async -> AsyncStream<Int>
  /// Items that failed and wait for the trainer: the current list, then every change.
  func failedItems() async -> AsyncStream<[OutboxItem]>
  func retry(_ id: UUID) async
  func retryAll() async
}

/// Deck keys that describe an Outbox item on TR-15 (V1-12 §3.1). Never a member name or a path (AC-DF-018.3).
public enum SyncQueueLabels {
  /// The kind of record, from the entity reference prefix.
  public static func kindKey(_ item: OutboxItem) -> String {
    switch item.entityRef.rawValue.split(separator: ":", maxSplits: 1).first.map(String.init) {
    case "soap": return "tr15.queue.kind.soap"
    case "bodyComposition": return "tr15.queue.kind.bodyComposition"
    case "circumference": return "tr15.queue.kind.circumference"
    case "posture": return "tr15.queue.kind.posture"
    case "pendingMember": return "tr15.queue.kind.pendingMember"
    case "consent": return "tr15.queue.kind.consent"
    default: return "tr15.queue.kind.other"
    }
  }

  /// The reason line of a failed item (V1-12 §3.1): rule rejections, consent, upload checks and file size have their
  /// own sentence; transient errors that ran out of attempts are 'retry limit'; anything else is a defect.
  public static func reasonKey(_ item: OutboxItem) -> String {
    switch item.lastErrorCode {
    case "permission-denied", "failed-precondition": return "sync.reason.ruleDenied"
    case "consent-rejected": return "sync.reason.consentRejected"
    case "upload-unverified", "upload-mismatch": return "sync.reason.uploadMismatch"
    case "file-too-large": return "sync.reason.fileTooLarge"
    case "unavailable", "deadline-exceeded", "unknown", "write-uncommitted", "protected-data-unavailable":
      return "sync.reason.retryLimit"
    default: return "common.devDefect"
    }
  }
}
