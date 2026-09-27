import Foundation
import TrainerDomain
import XCTest
@testable import FeatureAssessment

/// DF-203: the station line keeps one decimal for camera values (V1-12 §2.6, `0 생략 금지`).
final class CaptureSetupViewsTests: XCTestCase {
  func testCameraValuesKeepOneDecimal() {
    XCTAssertEqual(StationSummaryView.oneDecimal(100), "100.0")
    XCTAssertEqual(StationSummaryView.oneDecimal(3), "3.0")
    XCTAssertEqual(StationSummaryView.oneDecimal(2.5), "2.5")
  }

  /// The line as the app shows it, with the app's catalog read from disk (this bundle has no catalog of its own):
  /// the default station's draft name, never its key.
  func testDefaultStationSummaryUsesTheCatalogName() throws {
    let catalog = try Self.appCatalog()
    let localize: (String) -> String = { catalog[$0] ?? $0 }
    XCTAssertEqual(StationSummaryView.summary(DefaultStation.profile, localize: localize),
                   "기본 스테이션(프로토콜 v1 초안) · 카메라 높이 100.0cm · 거리 3.0m")
    let own = StationProfileValue(id: "s1", name: "가상 스튜디오", cameraHeightCm: 95, cameraDistanceM: 2.75,
                                  protocolVersion: DefaultStation.profile.protocolVersion)
    XCTAssertEqual(StationSummaryView.summary(own, localize: localize), "가상 스튜디오 · 카메라 높이 95.0cm · 거리 2.8m")
  }

  /// `ko` values of trainer_app/App/Resources/Localizable.xcstrings.
  private static func appCatalog() throws -> [String: String] {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<5 { url.deleteLastPathComponent() }  // …/trainer_app
    let data = try Data(contentsOf: url.appendingPathComponent("App/Resources/Localizable.xcstrings"))
    let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    let strings = try XCTUnwrap(root["strings"] as? [String: [String: Any]])
    return strings.compactMapValues { entry in
      ((entry["localizations"] as? [String: Any])?["ko"] as? [String: Any])
        .flatMap { $0["stringUnit"] as? [String: Any] }?["value"] as? String
    }
  }
}
