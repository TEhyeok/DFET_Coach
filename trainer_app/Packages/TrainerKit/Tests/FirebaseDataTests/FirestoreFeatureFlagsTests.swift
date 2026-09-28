import Foundation
import TrainerDomain
import XCTest
@testable import FirebaseData

/// The live flags provider (DF-127 review finding 1): the document it reads and its fail-closed mapping. The listener
/// itself runs against the emulator (`FeatureFlagsEmulatorTests`); no Firebase app exists in unit tests.
final class FirestoreFeatureFlagsTests: XCTestCase {
  func testItReadsTheFeaturesDocument() {
    XCTAssertEqual(FirestoreFeatureFlags.path, "appConfig/features")
  }

  /// Before the first snapshot every flag is off, and creating the provider touches no Firebase API.
  func testEveryFlagIsOffBeforeTheFirstSnapshot() {
    XCTAssertEqual(FirestoreFeatureFlags().current, .allOff)
  }

  /// A missing document is all off; only a real `true` turns a key on (the `init(map:)` table).
  func testSnapshotsMapFailClosed() {
    XCTAssertEqual(FirestoreFeatureFlags.flags(document: nil), .allOff)
    XCTAssertEqual(FirestoreFeatureFlags.flags(document: ["bodyComposition": true, "updatedBy": "synth-admin"]),
                   FeatureFlags(bodyComposition: true))
    XCTAssertEqual(FirestoreFeatureFlags.flags(document: ["bodyComposition": "true", "soapV2": 1]), .allOff)
  }
}
