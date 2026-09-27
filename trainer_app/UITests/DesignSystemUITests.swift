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
    XCTAssertTrue(element("metric.row.weightKg", in: app).exists)
  }

  private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any)[identifier].firstMatch
  }
}
