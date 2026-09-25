import XCTest
@testable import TrainerDomain

/// DF-017: `FeatureFlags` holds the eight `appConfig/features` keys and defaults every one to false (ADR-010).
final class FeatureFlagsTests: XCTestCase {
  func testEightKeysInContractOrder() {
    XCTAssertEqual(
      FeatureFlags.Key.allCases.map(\.rawValue),
      ["gut", "blood", "insights", "soapV2", "bodyComposition", "bodyAssessment", "memberShare", "lidarBeta"])
  }

  func testAllOffHasEveryKeyFalse() {
    for key in FeatureFlags.Key.allCases {
      XCTAssertFalse(FeatureFlags.allOff[key], key.rawValue)
    }
    XCTAssertEqual(FeatureFlags(), .allOff)
    XCTAssertEqual(FixedFeatureFlagsProvider.allOff.current, .allOff)
  }

  func testSubscriptTouchesOnlyItsOwnKey() {
    for key in FeatureFlags.Key.allCases {
      let flags = FeatureFlags(enabled: [key])
      for other in FeatureFlags.Key.allCases {
        XCTAssertEqual(flags[other], other == key, "\(key.rawValue) on -> \(other.rawValue)")
      }
    }
  }
}
