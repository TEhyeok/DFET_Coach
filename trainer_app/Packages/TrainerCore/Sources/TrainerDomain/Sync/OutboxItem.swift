import Foundation

/// The local record an Outbox item belongs to; the SyncEngine aggregates `syncState` per value (V1-05 §12.2).
/// Raw values are `soap:<noteId>`, `bodyComposition:<recordId>`, `circumference:<measurementId>`,
/// `posture:<assessmentId>`, `pendingMember:<pendingMemberId>` and `consent:<captureId>`.
public struct LocalEntityRef: Hashable, Sendable, CustomStringConvertible {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public static func soap(noteId: String) -> LocalEntityRef { LocalEntityRef(rawValue: "soap:\(noteId)") }
  public static func consent(captureId: String) -> LocalEntityRef { LocalEntityRef(rawValue: "consent:\(captureId)") }
  public static func measurement(kind: String, recordId: String) -> LocalEntityRef {
    LocalEntityRef(rawValue: "\(kind):\(recordId)")
  }

  public var description: String { rawValue }
}

/// Processing order inside one member (NFR-05, V1-04 §10.1). Same raw values as LocalStore `OutboxItem.stage`.
public enum OutboxStage: Int, CaseIterable, Comparable, Sendable {
  case memberKey = 0
  case consent = 1
  case document = 2
  case upload = 3
  case pathRecord = 4
  case finalize = 5

  public static func < (lhs: OutboxStage, rhs: OutboxStage) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// V1-04 §10.2 `OutboxKind`. Same raw values as LocalStore `OutboxItem.kind`.
public enum OutboxKind: String, CaseIterable, Sendable {
  case createDocument
  case updateDocument
  case deleteDocument
  case uploadBinary
  case deleteBinary
  case recordBinaryPath
  case finalize
  case callConsent
  case callFunction
}

public enum OutboxBlockedReason: String, CaseIterable, Sendable {
  case awaitingConsent
}

/// V1-04 §10.2 `OutboxItemState`. The reason of `.failed` is `OutboxItem.lastErrorCode`.
public enum OutboxItemState: Equatable, Sendable {
  case queued
  case inFlight
  case acked
  case failed
  case blocked(OutboxBlockedReason)
  /// Terminal: a newer consent capture of the same member replaced this unsent one. It is never sent, retried or
  /// counted as pending, so an older grant can never reach the server after a newer capture (V1-05 §12.3).
  case superseded

  /// LocalStore `OutboxItem.state` raw value.
  public var storageValue: String {
    switch self {
    case .queued: return "queued"
    case .inFlight: return "inFlight"
    case .acked: return "acked"
    case .failed: return "failed"
    case .blocked: return "blocked"
    case .superseded: return "superseded"
    }
  }
}

/// Where the item goes: a document path, a Storage path or a callable name.
public enum RemoteTarget: Equatable, Sendable {
  case document(path: String)
  case storage(path: String)
  case callable(name: String)
}

/// A local file to upload (`uploadBinary` only).
public struct LocalBinaryRef: Equatable, Sendable {
  public let localURL: URL
  public let contentType: String
  public let sha256: String

  public init(localURL: URL, contentType: String, sha256: String) {
    self.localURL = localURL
    self.contentType = contentType
    self.sha256 = sha256
  }
}

/// What the server returned for an acked item. `syncState` is `synced` only when every write was server-committed
/// and every upload verified (AC-DF-015.6).
public enum OutboxAck: Equatable, Sendable {
  case write(WriteAck)
  case upload(UploadReceipt)
  case call

  public var isConfirmed: Bool {
    switch self {
    case let .write(ack): return ack.serverCommitted
    case let .upload(receipt): return receipt.verified
    case .call: return true
    }
  }
}

/// One server write waiting to be applied (V1-04 §10.2). The LocalStore model (DF-014) persists the same fields.
public struct OutboxItem: Equatable, Identifiable, Sendable {
  public let id: UUID
  /// Server idempotency key: equal to `id`, or the consent capture ID for a consent item.
  public let requestId: UUID
  public let memberKey: MemberKey
  public let entityRef: LocalEntityRef
  /// Monotonic per `memberKey`; the member's items run in this order.
  public let sequence: Int64
  public let stage: OutboxStage
  public let kind: OutboxKind
  public let target: RemoteTarget
  /// Fields for create, update, path record and finalize; the payload of a callable.
  public var payload: JSONValue?
  public var binary: LocalBinaryRef?
  /// Items (possibly of another member, e.g. the pending-member create) that must be acked first.
  public var dependsOn: [UUID]
  public var attempts: Int
  public var nextAttemptAt: Date
  public var state: OutboxItemState
  public var lastErrorCode: String?
  public var ack: OutboxAck?
  public let createdAt: Date

  public init(
    id: UUID = UUID(), requestId: UUID? = nil, memberKey: MemberKey, entityRef: LocalEntityRef, sequence: Int64,
    stage: OutboxStage, kind: OutboxKind, target: RemoteTarget, payload: JSONValue? = nil,
    binary: LocalBinaryRef? = nil, dependsOn: [UUID] = [], attempts: Int = 0, nextAttemptAt: Date? = nil,
    state: OutboxItemState = .queued, lastErrorCode: String? = nil, ack: OutboxAck? = nil, createdAt: Date
  ) {
    self.id = id
    self.requestId = requestId ?? id
    self.memberKey = memberKey
    self.entityRef = entityRef
    self.sequence = sequence
    self.stage = stage
    self.kind = kind
    self.target = target
    self.payload = payload
    self.binary = binary
    self.dependsOn = dependsOn
    self.attempts = attempts
    self.nextAttemptAt = nextAttemptAt ?? createdAt
    self.state = state
    self.lastErrorCode = lastErrorCode
    self.ack = ack
    self.createdAt = createdAt
  }
}
