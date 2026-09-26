import Foundation
import SwiftData
import TrainerDomain

extension LocalStoreSchemaV1 {
  /// TR-01 local 'today' list row (V1-05 §12.2). There is no server reservation entity (AS-21). Carry-over copies
  /// unfinished rows to the new `dayKey` and fills `carriedOverFromDayKey` (DF-125).
  @Model
  final class TodayListEntry {
    @Attribute(.unique) var id: UUID
    var trainerUid: String
    var memberKey: String
    /// `yyyy-MM-dd` calendar day in `Asia/Seoul`.
    var dayKey: String
    var order: Int
    var addedAt: Date
    var carriedOverFromDayKey: String?

    init(
      id: UUID = UUID(),
      trainerUid: String,
      memberKey: MemberKey,
      dayKey: String,
      order: Int,
      addedAt: Date,
      carriedOverFromDayKey: String? = nil
    ) {
      self.id = id
      self.trainerUid = trainerUid
      self.memberKey = memberKey.storageValue
      self.dayKey = dayKey
      self.order = order
      self.addedAt = addedAt
      self.carriedOverFromDayKey = carriedOverFromDayKey
    }
  }
}

extension TodayListEntry: TrainerScopedModel {
  static func ownedBy(_ trainerUid: String) -> Predicate<TodayListEntry> {
    #Predicate<TodayListEntry> { $0.trainerUid == trainerUid }
  }
}
