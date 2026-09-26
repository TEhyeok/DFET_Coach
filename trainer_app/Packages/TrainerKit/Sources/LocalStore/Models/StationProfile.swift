import Foundation
import SwiftData

extension LocalStoreSchemaV1 {
  /// Device-local posture capture station (V1-05 §12.2). The server stores only its id (V1-05 §4.6).
  @Model
  final class StationProfile {
    /// = `stationProfileId`.
    @Attribute(.unique) var id: String
    var trainerUid: String
    var name: String
    var cameraHeightCm: Double
    var cameraDistanceM: Double
    var protocolVersion: String
    var note: String?
    var createdLocallyAt: Date

    init(
      id: String,
      trainerUid: String,
      name: String,
      cameraHeightCm: Double,
      cameraDistanceM: Double,
      protocolVersion: String,
      note: String? = nil,
      createdLocallyAt: Date
    ) {
      self.id = id
      self.trainerUid = trainerUid
      self.name = name
      self.cameraHeightCm = cameraHeightCm
      self.cameraDistanceM = cameraDistanceM
      self.protocolVersion = protocolVersion
      self.note = note
      self.createdLocallyAt = createdLocallyAt
    }
  }
}

extension StationProfile: TrainerScopedModel {
  static func ownedBy(_ trainerUid: String) -> Predicate<StationProfile> {
    #Predicate<StationProfile> { $0.trainerUid == trainerUid }
  }
}
