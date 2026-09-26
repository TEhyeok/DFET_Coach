import Foundation
import TrainerContracts

// Allowed values of the LocalStore state and kind attributes (V1-05 §12.2). Every attribute is stored as the
// English `rawValue` below; Korean raw values are forbidden (AC-DF-014.5, V1-05 §9.1 key notation).
// `syncState` uses the contracts-generated `SyncState` (vocab `syncState`) instead of a local copy.

/// `LocalSoapDraft.lockState`: `editable` = server `status: draft`, `pendingFinalize` = local lock while the finalize
/// item is queued (F-SOAP-04.2), `finalized` = the server confirmed the finalize.
enum LocalSoapLockState: String, CaseIterable, Sendable {
  case editable
  case pendingFinalize
  case finalized
}

/// `LocalMeasurementDraft.kind`. Also the prefix of its Outbox `entityRef` (`bodyComposition:<id>`).
enum LocalMeasurementKind: String, CaseIterable, Sendable {
  case bodyComposition
  case circumference
}

/// `LocalConsentCapture.captureState` (V1-04 §9.1).
enum LocalConsentCaptureState: String, CaseIterable, Sendable {
  case pending
  case confirmed
  case failed
}

/// `OutboxItem.stage`: processing order inside one member (NFR-05, V1-04 §10.1).
enum LocalOutboxStage: Int, CaseIterable, Sendable {
  case memberKey = 0
  case consent = 1
  case document = 2
  case upload = 3
  case pathRecord = 4
  case finalize = 5
}

/// `OutboxItem.kind`: the same values as V1-04 §10.2 `OutboxKind`.
enum LocalOutboxKind: String, CaseIterable, Sendable {
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

/// `OutboxItem.state`: the same values as V1-04 §10.2 `OutboxItemState`. The reason of `failed` is `lastErrorCode`.
enum LocalOutboxState: String, CaseIterable, Sendable {
  case queued
  case inFlight
  case acked
  case failed
  case blocked
}

/// `OutboxItem.blockedReason`, set only while `state == blocked`.
enum LocalOutboxBlockedReason: String, CaseIterable, Sendable {
  case awaitingConsent
}

/// `LocalBinary.kind` and the `Binaries/<folder>/` it is written under (V1-04 §9.2).
public enum LocalBinaryKind: String, CaseIterable, Sendable {
  case ink
  case posture
  case bodycompReport
  case signature

  /// Folder under `<partition>/Binaries/` (V1-04 §9.2).
  public var folderName: String {
    switch self {
    case .ink: return "ink"
    case .posture: return "posture"
    case .bodycompReport: return "bodycomp"
    case .signature: return "signatures"
    }
  }
}

/// `QuickPhrase.category`: the SOAP section the phrase belongs to.
enum LocalQuickPhraseCategory: String, CaseIterable, Sendable {
  case subjective = "S"
  case objective = "O"
  case assessment = "A"
  case plan = "P"
}

/// Prefixes of `OutboxItem.entityRef` (V1-05 §12.2, V1-06 `LocalEntityRef`).
enum LocalEntityRef {
  static func soap(noteId: String) -> String { "soap:\(noteId)" }
  static func measurement(kind: String, recordId: String) -> String { "\(kind):\(recordId)" }
  static func consent(captureId: String) -> String { "consent:\(captureId)" }
}
