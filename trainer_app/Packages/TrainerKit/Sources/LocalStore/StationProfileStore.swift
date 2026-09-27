import Foundation
import SwiftData
import TrainerDomain

/// Why `StationProfileStore` refused a request.
public enum StationProfileStoreError: Error, Equatable, Sendable {
  /// The station id already belongs to another trainer in this store. Each trainer has their own LocalStore
  /// partition (`LocalStoreLocation`), so this means the store was opened for the wrong trainer.
  case ownedByAnotherTrainer
}

/// The trainer's capture stations in LocalStore (DF-203). DEC-22 MVP: one default station.
///
/// Assumes one store per trainer (`LocalStoreLocation`); the `trainerUid` check is a second line of defence, so a
/// station row that belongs to another trainer is refused, never taken over.
public struct StationProfileStore {
  private let context: ModelContext

  public init(context: ModelContext) {
    self.context = context
  }

  /// The default station of `trainerUid`, created the first time (idempotent, and the same row after a restart).
  /// Called when TR-07 opens (AC-DF-203.2 MVP form). A stored row is returned as stored; `now` only dates a new row.
  public func ensureDefault(trainerUid: String, now: Date = Date()) throws -> StationProfileValue {
    let id = DefaultStation.id
    // By id, not by owner: the id is unique across the store, so another trainer's row must be seen to be refused.
    let existing = try context.fetch(FetchDescriptor<StationProfile>(predicate: #Predicate { $0.id == id })).first
    if let existing {
      guard existing.trainerUid == trainerUid else { throw StationProfileStoreError.ownedByAnotherTrainer }
      return StationProfileValue(
        id: existing.id, name: existing.name, cameraHeightCm: existing.cameraHeightCm,
        cameraDistanceM: existing.cameraDistanceM, protocolVersion: existing.protocolVersion)
    }
    let value = DefaultStation.profile
    context.insert(StationProfile(
      id: value.id, trainerUid: trainerUid, name: value.name, cameraHeightCm: value.cameraHeightCm,
      cameraDistanceM: value.cameraDistanceM, protocolVersion: value.protocolVersion, createdLocallyAt: now))
    try context.save()
    return value
  }
}
