import Foundation
import SwiftData
import TrainerDomain

/// Frozen V1 shape of `OutboxItem`, kept only so SwiftData can migrate V1 stores (DF-108). Do not change it: the
/// current model is `LocalStoreSchemaV1_1.OutboxItem` in Models/OutboxItem.swift.
extension LocalStoreSchemaV1 {
  /// One server write waiting to be applied (V1-05 §12.2, V1-04 §10.2).
  @Model
  final class OutboxItem {
    @Attribute(.unique) var id: UUID
    /// Server idempotency key: equal to `id`, or `UUID(LocalConsentCapture.captureId)` for a consent item.
    var requestId: UUID
    var trainerUid: String
    var memberKey: String
    /// `soap:<noteId>`, `bodyComposition:<recordId>`, `circumference:<measurementId>`, `posture:<assessmentId>`,
    /// `pendingMember:<pendingMemberId>`, `consent:<captureId>`.
    var entityRef: String
    /// Monotonic per `memberKey`.
    var sequence: Int64
    /// `LocalOutboxStage` raw value (0...5).
    var stage: Int
    /// `LocalOutboxKind` raw value.
    var kind: String
    var targetPath: String
    var payloadJSON: Data?
    var binaryId: UUID?
    var dependsOn: [UUID]
    var attempts: Int
    var nextAttemptAt: Date
    /// `LocalOutboxState` raw value.
    var state: String
    /// `LocalOutboxBlockedReason` raw value, only while `state == blocked`.
    var blockedReason: String?
    var lastErrorCode: String?
    var createdAt: Date

    init(
      id: UUID = UUID(),
      requestId: UUID? = nil,
      trainerUid: String,
      memberKey: MemberKey,
      entityRef: String,
      sequence: Int64,
      stage: LocalOutboxStage,
      kind: LocalOutboxKind,
      targetPath: String,
      payloadJSON: Data? = nil,
      binaryId: UUID? = nil,
      dependsOn: [UUID] = [],
      attempts: Int = 0,
      nextAttemptAt: Date? = nil,
      state: LocalOutboxState = .queued,
      blockedReason: LocalOutboxBlockedReason? = nil,
      lastErrorCode: String? = nil,
      createdAt: Date
    ) {
      self.id = id
      self.requestId = requestId ?? id
      self.trainerUid = trainerUid
      self.memberKey = memberKey.storageValue
      self.entityRef = entityRef
      self.sequence = sequence
      self.stage = stage.rawValue
      self.kind = kind.rawValue
      self.targetPath = targetPath
      self.payloadJSON = payloadJSON
      self.binaryId = binaryId
      self.dependsOn = dependsOn
      self.attempts = attempts
      self.nextAttemptAt = nextAttemptAt ?? createdAt
      self.state = state.rawValue
      self.blockedReason = state == .blocked ? blockedReason?.rawValue : nil
      self.lastErrorCode = lastErrorCode
      self.createdAt = createdAt
    }
  }
}
