import XCTest

/// TC-DF013-04 (AC-DF-013.2, AC-DF-013.5): the empty and failed member lists are different views, and a failure is
/// never shown as an empty list. DF-113 (TC-113-01..04): pending rows, consent chips, search and TR-03 with the member's
/// key. `--preview-members*` launches use synthetic data and no Firebase.
final class MemberListUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
    XCUIDevice.shared.orientation = .landscapeLeft
  }

  /// TC-113-03 (AC-DF-113.3): no assigned and no pending member shows `tr02.empty` and one '대기 회원 추가' button.
  @MainActor
  func testEmptyListShowsTheEmptyStateOnly_TC_DF013_04() throws {
    let app = launch(["--preview-members-empty"])
    let empty = element("tr02.empty", in: app)
    XCTAssertTrue(empty.waitForExistence(timeout: 10))
    XCTAssertTrue(empty.staticTexts["아직 담당 회원이 없어요"].exists)
    let add = empty.buttons["empty.action"]
    XCTAssertTrue(add.exists)
    XCTAssertEqual(add.label, "대기 회원 추가")
    XCTAssertEqual(empty.buttons.count, 1)
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

  /// TC-113-01, TC-113-02 (AC-DF-113.1/.2): assigned and pending members in name order, the '대기' badge on pending
  /// rows only, and each row's chip from its effective consent (three MVP states).
  @MainActor
  func testPendingMembersShowTheBadgeAndTheirConsentChips_TC_113_01_02() throws {
    let app = launch(["--preview-members-pending"])
    XCTAssertTrue(element("tr02.row.4", in: app).waitForExistence(timeout: 10))
    let expected = [
      "SYN-0001, 동의 ①②③",
      "SYN-0002, 동의 필요",
      "SYN-P001, 대기, 동의 확인 대기",
      "SYN-P002, 대기, 동의 ①②③",
      "SYN-P003, 대기, 동의 필요",
    ]
    for (index, label) in expected.enumerated() {
      let row = element("tr02.row.\(index)", in: app)
      XCTAssertTrue(waitForLabel(row, label), "row \(index): \(row.label)")
    }
    XCTAssertFalse(element("tr02.row.5", in: app).exists)
  }

  /// TC-113-04 (AC-DF-113.5): the list is filtered as the trainer types, ignoring case and spaces.
  @MainActor
  func testSearchFiltersByDisplayName_TC_113_04() throws {
    let app = launch(["--preview-members-pending"])
    let search = element("tr02.search", in: app)
    XCTAssertTrue(search.waitForExistence(timeout: 10))
    XCTAssertEqual(search.placeholderValue, "회원 검색")
    search.tap()
    search.typeText("p 002")
    XCTAssertTrue(waitForLabel(element("tr02.row.0", in: app), "SYN-P002, 대기, 동의 ①②③"))
    XCTAssertFalse(element("tr02.row.1", in: app).exists)
    search.typeText("x")
    XCTAssertTrue(element("tr02.row.0", in: app).waitForNonExistence(timeout: 5))
    XCTAssertFalse(element("tr02.empty", in: app).exists, "no match is not the empty state")
  }

  /// DF-113: a pending member's row opens TR-03 with its `MemberKey.pending`.
  @MainActor
  func testAPendingRowOpensTR03WithItsPendingKey() throws {
    let app = launch(["--preview-members-pending"])
    let row = element("tr02.row.2", in: app)
    XCTAssertTrue(waitForLabel(row, "SYN-P001, 대기, 동의 확인 대기"))
    row.tap()
    let detail = element("tr03.root", in: app)
    XCTAssertTrue(detail.waitForExistence(timeout: 10))
    XCTAssertEqual(detail.value as? String, "pending:SynPendingList000001")
    XCTAssertTrue(row.isSelected)
    element("tr02.row.0", in: app).tap()
    XCTAssertTrue(waitForValue(element("tr03.root", in: app), "uid:syn-0001"))
  }

  /// A member registered from the empty state is listed at once, before the server has it (the preview registrar
  /// never sends): the '대기' badge and '동의 필요' until consent is recorded.
  @MainActor
  func testAMemberRegisteredFromTheEmptyStateIsListed() throws {
    let app = launch(["--preview-members-empty"])
    let add = element("empty.action", in: app)
    XCTAssertTrue(add.waitForExistence(timeout: 10))
    add.tap()
    XCTAssertTrue(element("tr14.register.root", in: app).waitForExistence(timeout: 10))
    let name = element("tr14.register.displayName", in: app)
    name.tap()
    name.typeText("SYN Member B")
    element("tr14.register.sex.unspecified", in: app).tap()
    element("tr14.register.age14Confirm", in: app).switches.firstMatch.tap()
    element("tr14.register.birthYear", in: app).tap()
    let year = app.buttons["2011"].firstMatch  // near the top of the menu, and eligible (AgeGate, 2026)
    XCTAssertTrue(year.waitForExistence(timeout: 5))
    year.tap()
    app.buttons["tr14.register.next"].firstMatch.tap()
    XCTAssertTrue(element("tr14.consent.root", in: app).waitForExistence(timeout: 10))
    element("common.close", in: app).tap()

    XCTAssertTrue(waitForLabel(element("tr02.row.0", in: app), "SYN Member B, 대기, 동의 필요"))
    XCTAssertFalse(element("tr02.empty", in: app).exists)
  }

  private func waitForLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval = 10) -> Bool {
    let predicate = NSPredicate(format: "label == %@", label)
    return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout)
      == .completed
  }

  private func waitForValue(_ element: XCUIElement, _ value: String, timeout: TimeInterval = 10) -> Bool {
    let predicate = NSPredicate(format: "value == %@", value)
    return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout)
      == .completed
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
