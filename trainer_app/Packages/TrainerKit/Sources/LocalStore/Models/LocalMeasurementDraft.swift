import Foundation
import SwiftData
import TrainerContracts
import TrainerDomain

extension LocalStoreSchemaV1 {
  /// One body composition record or one circumference row per `trialIndex` (V1-05 §12.2). `payloadJSON` has the
  /// shape of the V1-05 §4.7 / §4.8 document.
  @Model
  final class LocalMeasurementDraft {
    @Attribute(.unique) var recordId: String
    var trainerUid: String
    var memberKey: String
    /// `LocalMeasurementKind` raw value.
    var kind: String
    var payloadJSON: Data
    var reportPhotoBinaryId: UUID?
    var syncState: String
    var lastErrorCode: String?
    var createdLocallyAt: Date
    var updatedLocallyAt: Date

    init(
      recordId: String,
      trainerUid: String,
      memberKey: MemberKey,
      kind: LocalMeasurementKind,
      payloadJSON: Data,
      reportPhotoBinaryId: UUID? = nil,
      syncState: SyncState = .localSaved,
      lastErrorCode: String? = nil,
      createdLocallyAt: Date,
      updatedLocallyAt: Date? = nil
    ) {
      self.recordId = recordId
      self.trainerUid = trainerUid
      self.memberKey = memberKey.storageValue
      self.kind = kind.rawValue
      self.payloadJSON = payloadJSON
      self.reportPhotoBinaryId = reportPhotoBinaryId
      self.syncState = syncState.rawValue
      self.lastErrorCode = lastErrorCode
      self.createdLocallyAt = createdLocallyAt
      self.updatedLocallyAt = updatedLocallyAt ?? createdLocallyAt
    }

    var entityRef: String { LocalEntityRef.measurement(kind: kind, recordId: recordId) }
  }
}

extension LocalMeasurementDraft: TrainerScopedModel {
  static func ownedBy(_ trainerUid: String) -> Predicate<LocalMeasurementDraft> {
    #Predicate<LocalMeasurementDraft> { $0.trainerUid == trainerUid }
  }
}
