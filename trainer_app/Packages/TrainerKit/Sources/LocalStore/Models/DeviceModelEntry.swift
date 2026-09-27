import Foundation
import SwiftData

extension LocalStoreSchemaV1_2 {
  /// One body composition device this iPad has used (TR-11 device picker, DF-127, ASM-P1a-14). A device setting like
  /// `StationProfile`: never synced, kept on logout, and holding no member data.
  @Model
  final class DeviceModelEntry {
    /// `trainerUid` + U+001F + `name` (`DeviceModelEntry.key(trainerUid:name:)`): one row per trainer and name.
    @Attribute(.unique) var id: String
    var trainerUid: String
    /// `DeviceModelName.normalize`d, 1~64 UTF-16 units. Case is kept (ASM-09-13).
    var name: String
    /// The picker lists the most recently used first; the form preselects the first (V1-09 §10.3).
    var lastUsedAt: Date

    init(trainerUid: String, name: String, lastUsedAt: Date) {
      id = Self.key(trainerUid: trainerUid, name: name)
      self.trainerUid = trainerUid
      self.name = name
      self.lastUsedAt = lastUsedAt
    }

    static func key(trainerUid: String, name: String) -> String {
      trainerUid + "\u{1F}" + name
    }
  }
}

extension DeviceModelEntry: TrainerScopedModel {
  static func ownedBy(_ trainerUid: String) -> Predicate<DeviceModelEntry> {
    #Predicate<DeviceModelEntry> { $0.trainerUid == trainerUid }
  }
}
