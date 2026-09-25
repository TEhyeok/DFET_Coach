import XCTest

/// TC-DF008-03 / AC-DF-008.4: the Debug app launched with `--preview-empty` shows the root view
/// without any Firebase configuration.
final class LaunchSmokeTests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testPreviewEmptyLaunch() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--preview-empty"]
    app.launch()
    XCTAssertTrue(app.otherElements["app.root"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.otherElements["app.configMissing"].exists)
  }
}
