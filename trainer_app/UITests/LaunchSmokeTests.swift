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
    XCTAssertTrue(app.otherElements["app.root"].waitForExistence(timeout: 30))
    XCTAssertFalse(app.otherElements["app.configMissing"].exists)
  }

  /// §8.2 / NFR-03: without a plist and without `--preview-*` the app shows the configuration-missing
  /// screen instead of falling back to preview data. CI and agent builds never contain the plist.
  @MainActor
  func testMissingPlistShowsConfigMissing() throws {
    // With a locally placed plist the app would start in production mode; never launch that from a test.
    let plist = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("Config/GoogleService-Info.plist")
    if FileManager.default.fileExists(atPath: plist.path) {
      throw XCTSkip("Config/GoogleService-Info.plist is present locally")
    }
    let app = XCUIApplication()
    app.launchArguments = []
    app.launch()
    XCTAssertTrue(app.otherElements["app.configMissing"].waitForExistence(timeout: 30))
    XCTAssertFalse(app.otherElements["app.root"].exists)
  }
}
