import XCTest

/// DF-018 TR-15 UI tests. Every launch uses `--preview-*` (DEBUG, synthetic data, no Firebase).
final class SettingsUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
    XCUIDevice.shared.orientation = .landscapeLeft
  }

  /// TC-DF018-04 (AC-DF-018.3): two failed items with kind and reason, '다시 시도' per item and '모두 다시 시도'. No
  /// member name or path is shown.
  @MainActor
  func testQueueShowsFailedItemsAndRetries_TC_DF018_04() throws {
    let app = launch(["--preview-queue-failed"])
    element("nav.settings", in: app).tap()
    XCTAssertTrue(element("tr15.root", in: app).waitForExistence(timeout: 10))
    element("tr15.queue", in: app).tap()

    XCTAssertTrue(element("tr15.queue.item.0", in: app).waitForExistence(timeout: 10))
    XCTAssertTrue(element("tr15.queue.item.1", in: app).exists)
    let leaks = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'soap_notes' OR label CONTAINS 'Syn'"))
    XCTAssertEqual(leaks.count, 0, "no path or ID on screen")
    attachScreenshot(app, name: "TC-DF018-04 queue with two failed items")

    element("tr15.queue.retry.0", in: app).tap()
    let second = element("tr15.queue.item.1", in: app)
    XCTAssertTrue(second.waitForNonExistence(timeout: 10), "the retried item left the queue")
    XCTAssertTrue(element("tr15.queue.item.0", in: app).exists)

    element("tr15.queue.retryAll", in: app).tap()
    XCTAssertTrue(element("tr15.queue.empty", in: app).waitForExistence(timeout: 10))
  }

  /// AC-DF-018.2 on screen: with unsynced records logout warns and offers sync now, keep and log out, or cancel; no
  /// choice deletes anything.
  @MainActor
  func testLogoutWithUnsyncedRecordsOffersNoDelete() throws {
    let app = launch(["--preview-queue-failed"])
    element("nav.settings", in: app).tap()
    XCTAssertTrue(element("tr15.root", in: app).waitForExistence(timeout: 10))
    XCTAssertTrue(element("tr15.version", in: app).exists)
    element("tr15.logout", in: app).tap()

    let alert = app.alerts.firstMatch
    XCTAssertTrue(alert.waitForExistence(timeout: 10))
    XCTAssertEqual(alert.buttons.count, 3)
    XCTAssertEqual(alert.buttons.matching(NSPredicate(format: "label CONTAINS '삭제'")).count, 0)
    attachScreenshot(app, name: "TC-DF018-02 unsynced logout warning")
    alert.buttons["취소"].tap()
    XCTAssertTrue(alert.waitForNonExistence(timeout: 10))
    XCTAssertTrue(element("tr15.root", in: app).exists)
  }

  private func launch(_ arguments: [String]) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = arguments
    app.launch()
    XCTAssertTrue(element("app.root", in: app).waitForExistence(timeout: 30))
    return app
  }

  private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any)[identifier].firstMatch
  }

  private func attachScreenshot(_ app: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
