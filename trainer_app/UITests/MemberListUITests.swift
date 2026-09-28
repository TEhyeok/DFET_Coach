import XCTest

/// TC-DF013-04 (AC-DF-013.2, AC-DF-013.5): the empty and failed member lists are different views, and a failure is
/// never shown as an empty list. DF-113 (TC-113-01..05, 07): pending rows, consent chips on one line, search, the
/// pending row menu (cancel, consent step again) and the TR-03 shell. `--preview-members*` launches use synthetic data
/// and no Firebase.
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

  /// Review: short names and the consent chips never wrap syllable by syllable. At the landscape content column
  /// (~288pt) and at a 375pt window every name and chip text is one line: the chip goes under the name when the row
  /// cannot hold both at full width.
  @MainActor
  func testNamesAndChipsStayOnOneLineInNarrowRows() throws {
    for arguments in [["--preview-members-pending"], ["--preview-members-pending", "--preview-width=375"]] {
      let app = launch(arguments)
      if arguments.count > 1 { element("nav.members", in: app).tap() }
      XCTAssertTrue(waitForLabel(element("tr02.row.4", in: app), "SYN-P003, 대기, 동의 필요"), "\(arguments)")
      let badge = app.staticTexts.matching(NSPredicate(format: "label == '대기'")).firstMatch
      let line = badge.frame.height  // one caption line
      XCTAssertGreaterThan(line, 0)
      for chip in ["동의 ①②③", "동의 필요", "동의 확인 대기"] {
        let texts = app.staticTexts.matching(NSPredicate(format: "label == %@", chip)).allElementsBoundByIndex
        XCTAssertFalse(texts.isEmpty, chip)
        for text in texts {
          XCTAssertLessThan(text.frame.height, line * 1.5, "\(arguments) '\(chip)' wraps: \(text.frame)")
          XCTAssertGreaterThan(text.frame.width, text.frame.height, "\(arguments) '\(chip)' is stacked")
        }
      }
      for name in ["SYN-0001", "SYN-0002", "SYN-P001", "SYN-P002", "SYN-P003"] {
        let text = app.staticTexts[name].firstMatch
        XCTAssertTrue(text.exists, name)
        XCTAssertLessThan(text.frame.height, line * 2, "\(arguments) '\(name)' wraps: \(text.frame)")
      }
      attachScreenshot(app, name: "TR-02 rows \(arguments.joined(separator: " "))")
      app.terminate()
    }
  }

  /// AC-DF-113.6: a pending row's menu cancels the registration after the trainer confirms
  /// (`tr02.cancelPending.confirm`); the row leaves the list. An assigned row has no such menu.
  @MainActor
  func test_AC_DF_113_6_thePendingRowMenuCancelsTheRegistration() throws {
    let app = launch(["--preview-members-pending"])
    let row = element("tr02.row.4", in: app)
    XCTAssertTrue(waitForLabel(row, "SYN-P003, 대기, 동의 필요"))
    row.press(forDuration: 1.2)
    let cancel = app.buttons["등록 취소"].firstMatch
    XCTAssertTrue(cancel.waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["동의 받기"].exists, "'동의 필요' offers the consent step again")
    cancel.tap()
    let alert = app.alerts.firstMatch
    XCTAssertTrue(alert.waitForExistence(timeout: 5))
    XCTAssertTrue(alert.staticTexts["대기 회원 등록을 취소할까요? 연결된 기록은 5영업일 안에 파기돼요."].exists)
    alert.buttons["등록 취소"].firstMatch.tap()
    XCTAssertTrue(element("tr02.row.4", in: app).waitForNonExistence(timeout: 10))
    XCTAssertFalse(listRow(named: "SYN-P003", in: app).exists)
    XCTAssertEqual(element("tr02.row.3", in: app).label, "SYN-P002, 대기, 동의 ①②③")

    // An awaiting pending row offers only the cancel; an assigned row has no menu at all.
    element("tr02.row.2", in: app).press(forDuration: 1.2)
    XCTAssertTrue(app.buttons["등록 취소"].firstMatch.waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["동의 받기"].exists)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.95)).tap()  // dismiss the menu
    XCTAssertTrue(app.buttons["등록 취소"].firstMatch.waitForNonExistence(timeout: 5))
    element("tr02.row.0", in: app).press(forDuration: 1.2)
    XCTAssertFalse(app.buttons["등록 취소"].firstMatch.waitForExistence(timeout: 2))
  }

  /// Review (AC-DF-110.5 gap): a pending member without consent gets the TR-14 consent step again from its row menu;
  /// a new capture of ①②③ turns its chip '동의 확인 대기'.
  @MainActor
  func testThePendingRowMenuReopensTheConsentStep() throws {
    let app = launch(["--preview-members-pending"])
    let row = element("tr02.row.4", in: app)
    XCTAssertTrue(waitForLabel(row, "SYN-P003, 대기, 동의 필요"))
    row.press(forDuration: 1.2)
    let take = app.buttons["동의 받기"].firstMatch
    XCTAssertTrue(take.waitForExistence(timeout: 5))
    take.tap()
    let step = element("tr14.consent.root", in: app)
    XCTAssertTrue(step.waitForExistence(timeout: 10))
    XCTAssertEqual(step.value as? String, "SynPendingList000003")
    for type in ["required", "healthData", "bodyImaging"] {
      app.buttons["tr14.consent.grant.\(type)"].firstMatch.tap()
    }
    app.buttons["tr14.consent.submit"].firstMatch.tap()
    XCTAssertTrue(waitForLabel(element("tr14.consent.result", in: app), "동의 확인 대기"))
    element("common.close", in: app).tap()
    XCTAssertTrue(waitForLabel(listRow(named: "SYN-P003", in: app), "SYN-P003, 대기, 동의 확인 대기"))
  }

  /// AC-DF-113.8: a row opens the TR-03 shell with the member's name, '대기' badge and chip, `common.comingSoon`, and,
  /// for a pending member that needs consent, '동의 받기' into TR-14's consent step.
  @MainActor
  func test_AC_DF_113_8_aRowOpensTheTR03Shell() throws {
    let app = launch(["--preview-members-pending"])
    let row = element("tr02.row.4", in: app)
    XCTAssertTrue(waitForLabel(row, "SYN-P003, 대기, 동의 필요"))
    row.tap()
    let detail = element("tr03.root", in: app)
    XCTAssertTrue(waitForValue(detail, "pending:SynPendingList000003"))
    XCTAssertTrue(waitForLabel(detail.descendants(matching: .any)["tr03.header"].firstMatch, "SYN-P003, 대기, 동의 필요"))
    XCTAssertTrue(detail.descendants(matching: .any)["common.comingSoon"].firstMatch.exists)
    attachScreenshot(app, name: "AC-DF-113.8 TR-03 pending")

    element("tr02.row.2", in: app).tap()  // awaiting: no '동의 받기'
    XCTAssertTrue(waitForValue(element("tr03.root", in: app), "pending:SynPendingList000001"))
    XCTAssertTrue(waitForLabel(element("tr03.header", in: app), "SYN-P001, 대기, 동의 확인 대기"))
    XCTAssertFalse(element("tr03.takeConsent", in: app).exists)
    element("tr02.row.0", in: app).tap()  // assigned: no badge
    XCTAssertTrue(waitForLabel(element("tr03.header", in: app), "SYN-0001, 동의 ①②③"))
    XCTAssertFalse(element("tr03.takeConsent", in: app).exists)

    element("tr02.row.4", in: app).tap()
    let take = element("tr03.takeConsent", in: app)
    XCTAssertTrue(take.waitForExistence(timeout: 10))
    XCTAssertEqual(take.label, "동의 받기")
    take.tap()
    let step = element("tr14.consent.root", in: app)
    XCTAssertTrue(step.waitForExistence(timeout: 10))
    XCTAssertEqual(step.value as? String, "SynPendingList000003")
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

  /// The TR-02 row whose spoken label starts with `name` (rows are identified by position, `tr02.row.<n>`).
  private func listRow(named name: String, in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH 'tr02.row.' AND label BEGINSWITH %@", name + ",")).firstMatch
  }

  private func attachScreenshot(_ app: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
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
