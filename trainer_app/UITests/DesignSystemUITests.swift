import XCTest

/// TC-DF016-04 (AC-DF-016.4, F-VIZ-07.7): every interactive DesignSystem component has a tap target of at least
/// 44×44 pt. `--preview-design-system` shows the gallery with synthetic values.
final class DesignSystemUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func test_TC_DF016_04_tapTargetsAreAtLeast44pt() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--preview-design-system"]
    app.launch()
    XCTAssertTrue(element("preview.designSystem", in: app).waitForExistence(timeout: 30))
    for id in ["sync.badge.retry", "empty.action"] {
      let target = element(id, in: app)
      if !target.exists { app.swipeUp() }
      XCTAssertTrue(target.waitForExistence(timeout: 10), id)
      XCTAssertGreaterThanOrEqual(target.frame.width, 44, id)
      XCTAssertGreaterThanOrEqual(target.frame.height, 44, id)
    }
    XCTAssertFalse(element("metric.row.waistCircumference", in: app).exists, "a value without a source has no row")
    // The rendered row speaks the full template (AC-DF-016.5), and a failed badge shows its reason (AC-DF-016.1).
    let weight = element("metric.row.weightKg", in: app)
    XCTAssertTrue(weight.exists)
    XCTAssertEqual(weight.label, "체중 72.4kg, 출처 기기 측정 · SYN-DEVICE, 2026.09.21, 변화 산정 준비 중")
    XCTAssertTrue(element("sync.badge.reason", in: app).exists)
  }

  private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any)[identifier].firstMatch
  }
}
