import Foundation
import SwiftData
import TrainerContracts
import TrainerDomain
import XCTest
@testable import LocalStore

/// DF-203 MVP: the default station exists once per trainer, is returned as stored, and survives a restart.
@MainActor
final class StationProfileTests: XCTestCase {
  private var temp: TemporaryDirectory?

  override func tearDown() {
    temp?.remove()
    temp = nil
    super.tearDown()
  }

  func test_AC_DF_203_2_ensureDefaultIsIdempotent() throws {
    let context = ModelContext(try LocalStoreContainer.make(inMemory: true))
    let stations = StationProfileStore(context: context)
    let first = try stations.ensureDefault(trainerUid: Synthetic.trainerA, now: Synthetic.now)
    let second = try stations.ensureDefault(trainerUid: Synthetic.trainerA, now: Synthetic.now.addingTimeInterval(60))
    XCTAssertEqual(first, second)
    XCTAssertEqual(first, DefaultStation.profile)
    let rows = try context.fetchOwned(StationProfile.self, by: Synthetic.trainerA)
    XCTAssertEqual(rows.count, 1)
    XCTAssertEqual(rows.first?.createdLocallyAt, Synthetic.now, "the second call inserted again (the unique id replaced the row)")
  }

  /// A stored default row is returned as stored, never replaced by the protocol's current values.
  func testEnsureDefaultReturnsTheStoredRow() throws {
    let context = ModelContext(try LocalStoreContainer.make(inMemory: true))
    context.insert(StationProfile(
      id: DefaultStation.id, trainerUid: Synthetic.trainerA, name: "가상 스테이션", cameraHeightCm: 95,
      cameraDistanceM: 2.8, protocolVersion: PostureProtocolV1.protocolVersion, createdLocallyAt: Synthetic.now))
    try context.save()
    let station = try StationProfileStore(context: context)
      .ensureDefault(trainerUid: Synthetic.trainerA, now: Synthetic.now.addingTimeInterval(60))
    XCTAssertEqual(station, StationProfileValue(
      id: DefaultStation.id, name: "가상 스테이션", cameraHeightCm: 95, cameraDistanceM: 2.8,
      protocolVersion: PostureProtocolV1.protocolVersion))
    XCTAssertEqual(try context.fetchOwned(StationProfile.self, by: Synthetic.trainerA).first?.createdLocallyAt, Synthetic.now)
  }

  /// One store per trainer is the rule; if a store is opened for the wrong trainer, another trainer's default row is
  /// refused, not taken over.
  func testAnotherTrainersDefaultRowIsRefusedNotTakenOver() throws {
    let context = ModelContext(try LocalStoreContainer.make(inMemory: true))
    let stations = StationProfileStore(context: context)
    _ = try stations.ensureDefault(trainerUid: Synthetic.trainerA, now: Synthetic.now)
    XCTAssertThrowsError(try stations.ensureDefault(trainerUid: Synthetic.trainerB, now: Synthetic.now)) { error in
      XCTAssertEqual(error as? StationProfileStoreError, .ownedByAnotherTrainer)
    }
    XCTAssertEqual(try context.fetchOwned(StationProfile.self, by: Synthetic.trainerA).count, 1)
    XCTAssertEqual(try context.fetchOwned(StationProfile.self, by: Synthetic.trainerB).count, 0)
  }

  func test_AC_DF_203_1_defaultStationSurvivesContainerReload() throws {
    let temp = try TemporaryDirectory()
    self.temp = temp
    let location = LocalStoreLocation(trainerUid: Synthetic.trainerA, applicationSupportURL: temp.url)
    do {
      let context = ModelContext(try LocalStoreContainer.make(location: location))
      _ = try StationProfileStore(context: context).ensureDefault(trainerUid: Synthetic.trainerA, now: Synthetic.now)
    }
    let reopened = ModelContext(try LocalStoreContainer.make(location: location))
    let rows = try reopened.fetchOwned(StationProfile.self, by: Synthetic.trainerA)
    XCTAssertEqual(rows.map(\.id), ["default-v1"])
    XCTAssertEqual(rows.first?.protocolVersion, PostureProtocolV1.protocolVersion)
    XCTAssertEqual(rows.first?.cameraHeightCm, 100)
    let again = try StationProfileStore(context: reopened).ensureDefault(trainerUid: Synthetic.trainerA, now: Synthetic.now)
    XCTAssertEqual(again.id, "default-v1")
    XCTAssertEqual(try reopened.fetchOwned(StationProfile.self, by: Synthetic.trainerA).count, 1)
  }
}
