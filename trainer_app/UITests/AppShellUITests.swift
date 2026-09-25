import XCTest

/// DF-017 AppShell UI tests. Every launch uses `--preview-*` (DEBUG, synthetic data, no Firebase).
final class AppShellUITests: XCTestCase {
  private let sidebarIDs: Set<String> = ["nav.today", "nav.members", "nav.settings"]

  override func setUpWithError() throws {
    continueAfterFailure = false
    XCUIDevice.shared.orientation = .landscapeLeft
  }

  override func tearDownWithError() throws {
    XCUIDevice.shared.orientation = .landscapeLeft
  }

  /// TC-DF017-05 (AC-DF-017.2, AC-DF-017.4): three sidebar items with every flag off; the selection survives
  /// landscape -> portrait -> landscape.
  @MainActor
  func testSidebarThreeItemsAndSelectionSurvivesRotation_TC_DF017_05() throws {
    let app = launch(["--preview-empty"])
    XCTAssertEqual(sidebarItems(in: app), sidebarIDs)

    element("nav.settings", in: app).tap()
    XCTAssertTrue(element("tr15.root", in: app).waitForExistence(timeout: 10))

    XCUIDevice.shared.orientation = .portrait
    XCTAssertTrue(element("tr15.root", in: app).waitForExistence(timeout: 10), "selection lost after portrait")
    XCTAssertFalse(element("tr02.root", in: app).exists)

    XCUIDevice.shared.orientation = .landscapeLeft
    XCTAssertTrue(element("tr15.root", in: app).waitForExistence(timeout: 10), "selection lost after landscape")
    XCTAssertEqual(sidebarItems(in: app), sidebarIDs)
    attachScreenshot(app, name: "TC-DF017-05 landscape after rotation")
  }

  /// AC-DF-017.2 on screen: with every flag off the member detail offers no gated entry point.
  @MainActor
  func testAllFlagsOffMemberDetailHasNoEntries_AC_DF_017_2() throws {
    let app = launch(["--preview-members"])
    openFirstMember(in: app)
    let entries = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'tr03.entry.'"))
    XCTAssertEqual(entries.count, 0)
  }

  /// AC-DF-017.5: a DEBUG flag override shows the entry; tapping it opens `common.comingSoon`, not a blank screen.
  @MainActor
  func testOverriddenFlagEntryOpensComingSoon_AC_DF_017_5() throws {
    let app = launch(["--preview-members", "--preview-flags=soapV2"])
    // soapV2 on: the default route is TR-01; go to the member list first.
    element("nav.members", in: app).tap()
    openFirstMember(in: app)
    let start = element("tr03.entry.startSession", in: app)
    XCTAssertTrue(start.waitForExistence(timeout: 10))
    XCTAssertFalse(element("tr03.entry.lidar", in: app).exists)
    start.tap()
    XCTAssertTrue(element("common.comingSoon", in: app).waitForExistence(timeout: 10))
    attachScreenshot(app, name: "AC-DF-017.5 coming soon")
    element("common.close", in: app).tap()
    XCTAssertTrue(element("tr03.root", in: app).waitForExistence(timeout: 10))
  }

  /// AC-DF-017.4: a 375pt compact window (1/3 Split View simulation) shows the sidebar as a stack, inside the
  /// window, and navigation still works.
  @MainActor
  func testOneThirdSplitViewSimulation_AC_DF_017_4() throws {
    let app = launch(["--preview-members", "--preview-width=375"])
    XCTAssertEqual(sidebarItems(in: app), sidebarIDs)
    let windowMinX = app.windows.firstMatch.frame.minX
    for id in sidebarIDs.sorted() {
      let frame = element(id, in: app).frame
      XCTAssertGreaterThanOrEqual(frame.minX, windowMinX, id)
      XCTAssertLessThanOrEqual(frame.maxX, windowMinX + 375.5, "\(id) is clipped")
    }
    attachScreenshot(app, name: "AC-DF-017.4 1/3 Split View simulation (375pt)")

    element("nav.members", in: app).tap()
    let row = element("tr02.row.syn-0001", in: app)
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    XCTAssertLessThanOrEqual(row.frame.maxX, windowMinX + 375.5)
    row.tap()
    XCTAssertTrue(element("tr03.root", in: app).waitForExistence(timeout: 10))
  }

  // MARK: Helpers

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

  private func sidebarItems(in app: XCUIApplication) -> Set<String> {
    _ = element("nav.members", in: app).waitForExistence(timeout: 10)
    let query = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'nav.'"))
    return Set(query.allElementsBoundByIndex.map(\.identifier))
  }

  private func openFirstMember(in app: XCUIApplication) {
    let row = element("tr02.row.syn-0001", in: app)
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    row.tap()
    XCTAssertTrue(element("tr03.root", in: app).waitForExistence(timeout: 10))
  }

  private func attachScreenshot(_ app: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
