import Foundation
import SwiftData

extension LocalStoreSchemaV1 {
  /// Device-local filter memory (F-VIZ-05.2, V1-05 §12.2). Keys are trainer-wide, not per member (ASM-05-39):
  /// `timeline.kinds` (P1a, DF-114), P2 keys in DF-329.
  @Model
  final class FilterPreference {
    @Attribute(.unique) var key: String
    var trainerUid: String
    var valueJSON: Data
    var updatedLocallyAt: Date

    init(key: String, trainerUid: String, valueJSON: Data, updatedLocallyAt: Date) {
      self.key = key
      self.trainerUid = trainerUid
      self.valueJSON = valueJSON
      self.updatedLocallyAt = updatedLocallyAt
    }
  }
}

extension FilterPreference: TrainerScopedModel {
  static func ownedBy(_ trainerUid: String) -> Predicate<FilterPreference> {
    #Predicate<FilterPreference> { $0.trainerUid == trainerUid }
  }
}
