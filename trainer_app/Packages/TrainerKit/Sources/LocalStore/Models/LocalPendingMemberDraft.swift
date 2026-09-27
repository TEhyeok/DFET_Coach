import Foundation
import SwiftData

extension LocalStoreSchemaV1_1 {
  /// A member registered on site before they have an account (TR-14, DF-108, V1-05 §12.2). The row exists from the
  /// moment the trainer saves, offline or not; the `pendingMembers/{id}` create goes through the Outbox (stage 0), so
  /// records and consent captures for this member can be made at once and are sent after it. Its sync state and
  /// error are the Outbox item's. `LocalOutboxStore` deletes the row once the create is acked, so the display name
  /// is not kept on the device longer than needed (ASM-05-38); after that it comes from the Firestore cache.
  @Model
  final class LocalPendingMemberDraft {
    /// A 20-character auto ID (the rules' R-05 shape).
    @Attribute(.unique) var pendingMemberId: String
    var trainerUid: String
    var displayName: String
    /// `Sex` raw value.
    var sex: String
    var birthYear: Int
    var ageConfirmed14: Bool
    var createdLocallyAt: Date
    /// The Outbox item that creates the server document; later items of this member point at it (`dependsOn`).
    var outboxItemId: UUID

    init(
      pendingMemberId: String, trainerUid: String, displayName: String, sex: String, birthYear: Int,
      ageConfirmed14: Bool, createdLocallyAt: Date, outboxItemId: UUID
    ) {
      self.pendingMemberId = pendingMemberId
      self.trainerUid = trainerUid
      self.displayName = displayName
      self.sex = sex
      self.birthYear = birthYear
      self.ageConfirmed14 = ageConfirmed14
      self.createdLocallyAt = createdLocallyAt
      self.outboxItemId = outboxItemId
    }
  }
}

extension LocalPendingMemberDraft: TrainerScopedModel {
  static func ownedBy(_ trainerUid: String) -> Predicate<LocalPendingMemberDraft> {
    #Predicate<LocalPendingMemberDraft> { $0.trainerUid == trainerUid }
  }
}
