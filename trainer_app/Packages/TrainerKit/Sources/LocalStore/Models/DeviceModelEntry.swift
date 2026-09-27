import Foundation
import SwiftData

extension LocalStoreSchemaV1_2 {
  /// Trainer-scoped device names survive draft cleanup and are reused across members (ASM-P1a-14).
  @Model
  final class DeviceModelEntry {
    @Attribute(.unique) var id: UUID
    var trainerUid: String
    var name: String
    var lastUsedAt: Date

    init(trainerUid: String, name: String, lastUsedAt: Date) {
      id = UUID()
      self.trainerUid = trainerUid
      self.name = name
      self.lastUsedAt = lastUsedAt
    }
  }
}

typealias DeviceModelEntry = LocalStoreSchemaV1_2.DeviceModelEntry

extension DeviceModelEntry: TrainerScopedModel {
  static func ownedBy(_ trainerUid: String) -> Predicate<DeviceModelEntry> {
    #Predicate<DeviceModelEntry> { $0.trainerUid == trainerUid }
  }
}
