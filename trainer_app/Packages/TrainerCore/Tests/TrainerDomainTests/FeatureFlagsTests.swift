import Foundation
import TrainerContracts
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

  // MARK: - DF-027 generated keys and init(map:) (TC-DF027-03, same table as the Dart TC-DF027-02)

  func test_AC_DF_027_1_keyIsTheGeneratedContractEnumAndEveryDefaultIsFalse() {
    XCTAssertTrue(FeatureFlags.Key.self == FeatureFlagKey.self)
    XCTAssertEqual(FeatureFlagKey.allCases.count, 8)
    for key in FeatureFlagKey.allCases {
      XCTAssertFalse(key.defaultValue, key.rawValue)
    }
  }

  func test_AC_DF_027_3_missingDocumentReadsAllOff() {
    XCTAssertEqual(FeatureFlags(map: nil), .allOff)
    XCTAssertEqual(FeatureFlags(map: [:]), .allOff)
  }

  func test_AC_DF_027_3_missingSoapV2KeyReadsFalse() {
    let flags = FeatureFlags(map: ["gut": true, "blood": true, "insights": true, "lidarBeta": true])
    XCTAssertFalse(flags.soapV2)
    XCTAssertEqual(flags, FeatureFlags(gut: true, blood: true, insights: true, lidarBeta: true))
  }

  func test_AC_DF_027_3_nonBooleanValuesReadFalse() {
    let nonBooleans: [(String, Any)] = [
      ("string true", "true"),
      ("string TRUE", "TRUE"),
      ("Int 1", 1),
      ("Double 1", 1.0),
      ("NSNumber 1", NSNumber(value: 1)),
      ("NSNumber 1.0", NSNumber(value: 1.0)),
      ("NSNull", NSNull()),
      ("array", [true]),
      ("map", ["enabled": true]),
    ]
    for (label, value) in nonBooleans {
      for key in FeatureFlagKey.allCases {
        XCTAssertFalse(FeatureFlags(map: [key.rawValue: value])[key], "\(key.rawValue) = \(label)")
      }
    }
  }

  func test_AC_DF_027_3_realBooleansAreRead() throws {
    // Firestore hands booleans over as the CFBoolean singletons; JSONSerialization does too.
    let parsed = try JSONSerialization.jsonObject(with: Data(#"{"soapV2": true, "gut": false}"#.utf8))
    let json = try XCTUnwrap(parsed as? [String: Any])
    XCTAssertEqual(FeatureFlags(map: json), FeatureFlags(soapV2: true))
    XCTAssertEqual(FeatureFlags(map: ["soapV2": NSNumber(value: true)]), FeatureFlags(soapV2: true))
    for key in FeatureFlagKey.allCases {
      XCTAssertEqual(FeatureFlags(map: [key.rawValue: true]), FeatureFlags(enabled: [key]), key.rawValue)
      XCTAssertEqual(FeatureFlags(map: [key.rawValue: false]), .allOff, key.rawValue)
    }
  }

  func test_AC_DF_027_3_unknownAndAuditKeysAreIgnored() {
    let flags = FeatureFlags(map: ["soapV2": true, "updatedBy": "admin", "updatedAt": Date(), "futureFlag": true])
    XCTAssertEqual(flags, FeatureFlags(soapV2: true))
  }
}
