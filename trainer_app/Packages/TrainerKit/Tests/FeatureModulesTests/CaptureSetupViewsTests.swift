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
    let catalog = try AppCatalog.values()
    let localize: (String) -> String = { catalog[$0] ?? $0 }
    XCTAssertEqual(StationSummaryView.summary(DefaultStation.profile, localize: localize),
                   "기본 스테이션(프로토콜 v1 초안) · 카메라 높이 100.0cm · 거리 3.0m")
    let own = StationProfileValue(id: "s1", name: "가상 스튜디오", cameraHeightCm: 95, cameraDistanceM: 2.75,
                                  protocolVersion: DefaultStation.profile.protocolVersion)
    XCTAssertEqual(StationSummaryView.summary(own, localize: localize), "가상 스튜디오 · 카메라 높이 95.0cm · 거리 2.8m")
  }
}
