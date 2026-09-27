import Foundation
import TrainerContracts
import XCTest
@testable import TrainerDomain

/// DF-203 MVP slice: default station from the protocol, capture conditions, shutter gate.
final class CaptureTests: XCTestCase {
  func testDefaultStationComesFromTheGeneratedProtocol() {
    let station = DefaultStation.profile
    XCTAssertEqual(station.id, "default-v1")
    XCTAssertEqual(station.protocolVersion, PostureProtocolV1.protocolVersion)
    let bump = "a change of the default values needs a new station id (default-v2), see DefaultStation"
    XCTAssertEqual(station.cameraHeightCm, 100, bump)
    XCTAssertEqual(station.cameraDistanceM, 3.0, bump)
    XCTAssertTrue(PostureProtocolV1.cameraHeightCm.contains(station.cameraHeightCm))
    XCTAssertTrue(PostureProtocolV1.cameraDistanceM.contains(station.cameraDistanceM))
  }

  func test_AC_ASM_01_3_conditionsHaveRequiredKeys() {
    let conditions = CaptureConditionsBuilder.build(profile: DefaultStation.profile, clothing: .fitted)
    guard case let .object(fields) = conditions.jsonValue else { return XCTFail("object expected") }
    XCTAssertEqual(Set(fields.keys), ["clothing", "barefoot", "markersPlaced", "verbalConsentCheck", "cameraHeightCm", "cameraDistanceM"])
    XCTAssertEqual(fields["clothing"], .string("fitted"))
    for key in ["barefoot", "markersPlaced", "verbalConsentCheck"] {
      XCTAssertEqual(fields[key], .bool(false), "\(key): not checked in the MVP, never written true")
    }
    XCTAssertEqual(fields["cameraHeightCm"], .number(100))
    XCTAssertEqual(fields["cameraDistanceM"], .number(3.0))
  }

  func testLevelAndPitchAreWrittenOnlyWhenMeasured() {
    var conditions = CaptureConditionsBuilder.build(profile: DefaultStation.profile, clothing: .regular)
    conditions.levelDeg = 0.4
    conditions.pitchDeg = -1.2
    guard case let .object(fields) = conditions.jsonValue else { return XCTFail("object expected") }
    XCTAssertEqual(fields["levelDeg"], .number(0.4))
    XCTAssertEqual(fields["pitchDeg"], .number(-1.2))
  }

  /// The full document map has exactly the keys the rules allow (`captureConditions.keys().hasOnly([...])`).
  func testAllKeysAreTheRulesHasOnlyList() throws {
    var conditions = CaptureConditionsBuilder.build(profile: DefaultStation.profile, clothing: .unknown)
    conditions.levelDeg = 0
    conditions.pitchDeg = 0
    guard case let .object(fields) = conditions.jsonValue else { return XCTFail("object expected") }
    XCTAssertEqual(Set(fields.keys), try Self.rulesCaptureConditionKeys())
  }

  private static func rulesCaptureConditionKeys() throws -> Set<String> {
    let rules = try String(
      contentsOf: FixtureLoader.repositoryRoot.appendingPathComponent("firestore.rules"), encoding: .utf8)
    let marker = "captureConditions.keys().hasOnly(["
    guard let start = rules.range(of: marker), let end = rules[start.upperBound...].range(of: "])") else {
      XCTFail("firestore.rules: captureConditions.keys().hasOnly([...]) not found")
      return []
    }
    let list = rules[start.upperBound..<end.lowerBound]
    let keys = list.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(["'"])) }
    return Set(keys)
  }

  func test_AC_ASM_01_2_clothingNotSelectedBlocksTheShutter() {
    var checklist = CaptureChecklist()
    XCTAssertEqual(ShutterGate.evaluate(checklist).reasons, [.clothingNotSelected])
    XCTAssertFalse(ShutterGate.evaluate(checklist).canShoot)
    checklist.clothing = .unknown
    XCTAssertTrue(ShutterGate.evaluate(checklist).canShoot)
  }

  func test_AC_DF_203_3_newSessionResetsTheChecklist() {
    var checklist = CaptureChecklist(clothing: .fitted)
    checklist.reset()
    XCTAssertNil(checklist.clothing)
    XCTAssertFalse(ShutterGate.evaluate(checklist).canShoot)
  }

  func testClothingOptionsAreTheProtocols() {
    XCTAssertEqual(PostureProtocolV1.clothingOptions, [.fitted, .regular, .unknown])
  }
}
