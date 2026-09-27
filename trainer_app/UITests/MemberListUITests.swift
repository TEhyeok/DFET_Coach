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
    XCTAssertTrue(element("tr02.loading", in: app).waitForExistence(timeout: 10))
    XCTAssertFalse(element("tr02.empty", in: app).exists)
    XCTAssertFalse(element("tr02.row.0", in: app).exists)
    element("preview.releaseMembers", in: app).tap()
    XCTAssertTrue(element("tr02.row.0", in: app).waitForExistence(timeout: 10))
    XCTAssertFalse(element("tr02.loading", in: app).exists)
  }

  /// A size-class change while the list loads keeps the subscription: the new list appears before the old one
  /// disappears, so a stop on disappear would cancel the only subscription and leave the skeleton forever.
  @MainActor
  func testResizeWhileLoadingKeepsTheSubscription() throws {
    let app = launch(["--preview-members-slow", "--preview-width=375", "--preview-resizable"])
    let toggle = element("preview.toggleWidth", in: app)
    XCTAssertTrue(toggle.waitForExistence(timeout: 10))
    element("nav.members", in: app).tap()
    XCTAssertTrue(element("tr02.loading", in: app).waitForExistence(timeout: 10))
    toggle.tap()  // wide
    XCTAssertTrue(element("tr02.loading", in: app).waitForExistence(timeout: 10))
    toggle.tap()  // narrow again
    element("preview.releaseMembers", in: app).tap()
    XCTAssertTrue(element("tr02.row.0", in: app).waitForExistence(timeout: 10), "the list was lost on resize")
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
