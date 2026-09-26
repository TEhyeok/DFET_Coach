import Foundation
import SwiftData
import TrainerContracts
import TrainerDomain

extension LocalStoreSchemaV1 {
  /// In-person consent capture (V1-05 §12.2). While `captureState == pending` the member's other Outbox items are
  /// `blocked(awaitingConsent)`. Unconfirmed captures are destroyed after `expiresAt` (AS-32, `LocalRetention`).
  @Model
  final class LocalConsentCapture {
    /// UUID string, equal to the request `clientCaptureId`.
    @Attribute(.unique) var captureId: String
    var trainerUid: String
    var memberKey: String
    /// `[{consentType, action, documentVersion}]`.
    var selectionsJSON: Data
    var signatureBinaryId: UUID
    var capturedAt: Date
    /// `LocalConsentCaptureState` raw value.
    var captureState: String
    var serverRecordIds: [String]
    var serverConfirmedAt: Date?
    /// `capturedAt + LocalRetention.window` (AS-32).
    var expiresAt: Date
    var syncState: String
    var lastErrorCode: String?

    init(
      captureId: String,
      trainerUid: String,
      memberKey: MemberKey,
      selectionsJSON: Data,
      signatureBinaryId: UUID,
      capturedAt: Date,
      captureState: LocalConsentCaptureState = .pending,
      serverRecordIds: [String] = [],
      serverConfirmedAt: Date? = nil,
      syncState: SyncState = .localSaved,
      lastErrorCode: String? = nil
    ) {
      self.captureId = captureId
      self.trainerUid = trainerUid
      self.memberKey = memberKey.storageValue
      self.selectionsJSON = selectionsJSON
      self.signatureBinaryId = signatureBinaryId
      self.capturedAt = capturedAt
      self.captureState = captureState.rawValue
      self.serverRecordIds = serverRecordIds
      self.serverConfirmedAt = serverConfirmedAt
      self.expiresAt = capturedAt.addingTimeInterval(LocalRetention.window)
      self.syncState = syncState.rawValue
      self.lastErrorCode = lastErrorCode
    }

    var entityRef: String { LocalEntityRef.consent(captureId: captureId) }
  }
}

extension LocalConsentCapture: TrainerScopedModel {
  static func ownedBy(_ trainerUid: String) -> Predicate<LocalConsentCapture> {
    #Predicate<LocalConsentCapture> { $0.trainerUid == trainerUid }
  }
}
