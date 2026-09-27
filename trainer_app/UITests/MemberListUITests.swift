import XCTest

/// TC-DF013-04 (AC-DF-013.2, AC-DF-013.5): the empty and failed member lists are different views, and a failure is
/// never shown as an empty list. `--preview-members*` launches use synthetic data and no Firebase.
final class MemberListUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
    XCUIDevice.shared.orientation = .landscapeLeft
  }

  @MainActor
  func testEmptyListShowsTheEmptyStateOnly_TC_DF013_04() throws {
    let app = launch(["--preview-members-empty"])
    let empty = element("tr02.empty", in: app)
    XCTAssertTrue(empty.waitForExistence(timeout: 10))
    XCTAssertEqual(empty.label, "아직 담당 회원이 없어요")
    XCTAssertFalse(element("tr02.retry", in: app).exists)
    XCTAssertFalse(element("tr02.list", in: app).exists)
  }

  @MainActor
  func testFailedListShowsRetryNotEmpty_TC_DF013_04() throws {
    let app = launch(["--preview-members-error"])
    let retry = element("tr02.retry", in: app)
    XCTAssertTrue(retry.waitForExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts["불러오기 실패"].exists)
    XCTAssertFalse(element("tr02.empty", in: app).exists)
    XCTAssertGreaterThanOrEqual(retry.frame.width, 44)
    XCTAssertGreaterThanOrEqual(retry.frame.height, 44)
    retry.tap()  // the preview fails again: still the failed view, still no empty state
    XCTAssertTrue(element("tr02.retry", in: app).waitForExistence(timeout: 10))
    XCTAssertFalse(element("tr02.empty", in: app).exists)
  }

  @MainActor
  func testLoadedListShowsRowsWithLocalAvatars() throws {
    let app = launch(["--preview-members"])
    XCTAssertTrue(element("tr02.row.0", in: app).waitForExistence(timeout: 10))
    XCTAssertTrue(element("tr02.list", in: app).exists)
    for index in 0..<3 {
      XCTAssertTrue(element("tr02.row.\(index)", in: app).exists, "row \(index)")
    }
    XCTAssertTrue(app.staticTexts["SYN-0001"].exists)
  }

  /// AC-DF-013.5: while the first list loads the skeleton shows, then the rows replace it.
  @MainActor
  func testSkeletonWhileLoading() throws {
    let app = launch(["--preview-members-slow"])
    XCTAssertTrue(element("tr02.loading", in: app).waitForExistence(timeout: 5))
    XCTAssertFalse(element("tr02.empty", in: app).exists)
    XCTAssertTrue(element("tr02.row.0", in: app).waitForExistence(timeout: 15))
    XCTAssertFalse(element("tr02.loading", in: app).exists)
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
}
