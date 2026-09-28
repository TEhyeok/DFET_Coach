import XCTest

/// DF-110 MVP: the TR-14 consent step after registration, in preview mode (`--preview-members`): synthetic published
/// versions, captures kept in memory and never sent, no server state unless `--preview-consent-confirm` plays it.
/// Synthetic data only.
final class ConsentStepUITests: XCTestCase {
  private let types = ["required", "healthData", "bodyImaging"]
  private let typeNames = ["① 서비스 이용 필수 동의", "② 건강정보 수집·이용", "③ 신체 사진·영상·3D 정보"]

  override func setUpWithError() throws {
    continueAfterFailure = false
    XCUIDevice.shared.orientation = .landscapeLeft
  }

  /// Register a member, answer ①②③ with '동의', submit: the capture is saved and the chip reads '동의 확인 대기'
  /// (nothing reaches a server in preview).
  @MainActor
  func test_AC_DF_110_2_registerThenGrantTheThreeCoreConsents() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--preview-members"]
    app.launch()
    register(in: app)

    let root = element("tr14.consent.root", in: app)
    XCTAssertTrue(root.waitForExistence(timeout: 10))
    XCTAssertEqual(root.value as? String, "SynPending0000000001")
    XCTAssertTrue(element("tr14.consent.handToMember", in: app).waitForExistence(timeout: 10))

    // AC-DF-110.2: every answer unselected, no 'agree to all', submit off. AC-DF-110.9: labels name the type.
    for (type, name) in zip(types, typeNames) {
      let grant = app.buttons["tr14.consent.grant.\(type)"].firstMatch
      let refuse = app.buttons["tr14.consent.refuse.\(type)"].firstMatch
      XCTAssertTrue(grant.exists, type)
      XCTAssertFalse(grant.isSelected, type)
      XCTAssertFalse(refuse.isSelected, type)
      XCTAssertEqual(grant.label, "\(name) 동의")
      XCTAssertEqual(refuse.label, "\(name) 동의하지 않음")
      XCTAssertGreaterThanOrEqual(grant.frame.height, 44)
    }
    XCTAssertFalse(app.buttons["tr14.consent.grant.sharing"].exists, "④⑤ are not asked in the MVP")
    let submit = app.buttons["tr14.consent.submit"].firstMatch
    XCTAssertFalse(submit.isEnabled)

    try app.performAccessibilityAudit(for: [.sufficientElementDescription, .hitRegion]) { issue in
      issue.element?.elementType == .other
    }

    for type in types {
      let grant = app.buttons["tr14.consent.grant.\(type)"].firstMatch
      grant.tap()
      XCTAssertTrue(grant.isSelected, type)
    }
    XCTAssertTrue(submit.isEnabled)
    submit.tap()

    XCTAssertTrue(element("tr14.consent.returnToTrainer", in: app).waitForExistence(timeout: 10))
    let chip = element("tr14.consent.result", in: app)
    XCTAssertTrue(chip.waitForExistence(timeout: 10))
    XCTAssertEqual(chip.label, "동의 확인 대기")

    app.buttons["common.close"].firstMatch.tap()
    XCTAssertTrue(root.waitForNonExistence(timeout: 10))
  }

  /// ① refused: `consent.requiredFirst` and no submit. Refusing ② records ① and ③ only: the chip reads '동의 필요'.
  @MainActor
  func testRequiredRefusalBlocksAndARefusedHealthConsentNeedsConsent() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--preview-members"]
    app.launch()
    register(in: app)
    XCTAssertTrue(element("tr14.consent.handToMember", in: app).waitForExistence(timeout: 10))

    // ① refused: the notice appears under ① and nothing can be submitted (all answered: ConsentStepModelTests).
    app.buttons["tr14.consent.refuse.required"].firstMatch.tap()
    let notice = element("consent.requiredFirst", in: app)
    XCTAssertTrue(notice.waitForExistence(timeout: 5))
    XCTAssertEqual(notice.label, "① 필수 동의를 먼저 받아야 해요.")
    let submit = app.buttons["tr14.consent.submit"].firstMatch
    XCTAssertFalse(submit.isEnabled)

    let grantRequired = app.buttons["tr14.consent.grant.required"].firstMatch
    grantRequired.tap()
    XCTAssertTrue(grantRequired.isSelected)
    XCTAssertTrue(notice.waitForNonExistence(timeout: 5))
    app.buttons["tr14.consent.refuse.healthData"].firstMatch.tap()
    app.buttons["tr14.consent.grant.bodyImaging"].firstMatch.tap()
    XCTAssertTrue(submit.isEnabled)
    submit.tap()

    let chip = element("tr14.consent.result", in: app)
    XCTAssertTrue(chip.waitForExistence(timeout: 10))
    XCTAssertEqual(chip.label, "동의 필요")
  }

  /// DF-110 + DF-113 wiring: TR-02's row chip and TR-14's result chip read one effective consent. After ①②③ the new
  /// pending member's row reads '동의 확인 대기'; when the server's part arrives (`preview.confirmConsent`: the capture
  /// is confirmed and the state is granted, as recordConsent and its listener do) it reads '동의 ①②③'. The row opens
  /// TR-03 with the member's pending key.
  @MainActor
  func testTheRowChipAwaitsTheServerThenShowsTheCoreConsents() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--preview-members", "--preview-consent-confirm"]
    app.launch()
    register(in: app)
    XCTAssertTrue(element("tr14.consent.handToMember", in: app).waitForExistence(timeout: 10))
    for type in types {
      app.buttons["tr14.consent.grant.\(type)"].firstMatch.tap()
    }
    app.buttons["tr14.consent.submit"].firstMatch.tap()
    let chip = element("tr14.consent.result", in: app)
    XCTAssertTrue(chip.waitForExistence(timeout: 10))
    XCTAssertEqual(chip.label, "동의 확인 대기")
    app.buttons["common.close"].firstMatch.tap()
    XCTAssertTrue(element("tr14.consent.root", in: app).waitForNonExistence(timeout: 10))

    let row = listRow(named: "SYN Member B", in: app)
    XCTAssertTrue(waitForLabel(row, "SYN Member B, 대기, 동의 확인 대기"), row.label)
    element("preview.confirmConsent", in: app).tap()
    XCTAssertTrue(waitForLabel(row, "SYN Member B, 대기, 동의 ①②③"), row.label)
    // A member without any consent keeps '동의 필요'.
    XCTAssertEqual(listRow(named: "SYN-0001", in: app).label, "SYN-0001, 동의 필요")

    row.tap()
    let detail = element("tr03.root", in: app)
    XCTAssertTrue(detail.waitForExistence(timeout: 10))
    XCTAssertEqual(detail.value as? String, "pending:SynPending0000000001")
  }

  /// AC-DF-110.5 (review): ① refused for a new pending member offers '등록 취소'; after the confirmation the step shows
  /// `tr14.consent.requiredRefusedPending`, nothing is recorded and TR-02 no longer lists the member.
  @MainActor
  func test_AC_DF_110_5_refusingRequiredCancelsTheRegistration() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--preview-members"]
    app.launch()
    register(in: app)
    XCTAssertTrue(element("tr14.consent.handToMember", in: app).waitForExistence(timeout: 10))
    XCTAssertFalse(element("tr14.consent.cancelRegistration", in: app).exists)
    app.buttons["tr14.consent.refuse.required"].firstMatch.tap()
    let cancel = app.buttons["tr14.consent.cancelRegistration"].firstMatch
    XCTAssertTrue(cancel.waitForExistence(timeout: 5))
    XCTAssertEqual(cancel.label, "등록 취소")
    cancel.tap()
    let alert = app.alerts.firstMatch
    XCTAssertTrue(alert.waitForExistence(timeout: 5))
    XCTAssertTrue(alert.staticTexts["대기 회원 등록을 취소할까요? 연결된 기록은 5영업일 안에 파기돼요."].exists)
    alert.buttons["등록 취소"].firstMatch.tap()

    let done = element("tr14.consent.requiredRefusedPending", in: app)
    XCTAssertTrue(done.waitForExistence(timeout: 10))
    XCTAssertEqual(done.label, "필수 동의를 받지 않아 회원 등록을 취소했어요")
    XCTAssertFalse(element("tr14.consent.result", in: app).exists, "no consent was recorded")
    app.buttons["common.close"].firstMatch.tap()
    XCTAssertTrue(element("tr14.consent.root", in: app).waitForNonExistence(timeout: 10))
    XCTAssertTrue(element("tr02.row.2", in: app).waitForExistence(timeout: 10))
    XCTAssertFalse(listRow(named: "SYN Member B", in: app).exists, "the cancelled member is not listed")
  }

  /// Review: a step closed before anything was answered is not a dead end. The member stays '동의 필요' in TR-02, and
  /// TR-03's '동의 받기' opens the consent step for it again.
  @MainActor
  func testAStepClosedBeforeAnsweringCanBeTakenAgainFromTR03() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--preview-members"]
    app.launch()
    register(in: app)
    XCTAssertTrue(element("tr14.consent.handToMember", in: app).waitForExistence(timeout: 10))
    app.buttons["common.close"].firstMatch.tap()
    XCTAssertTrue(element("tr14.consent.root", in: app).waitForNonExistence(timeout: 10))

    let row = listRow(named: "SYN Member B", in: app)
    XCTAssertTrue(waitForLabel(row, "SYN Member B, 대기, 동의 필요"), row.label)
    row.tap()
    let take = element("tr03.takeConsent", in: app)
    XCTAssertTrue(take.waitForExistence(timeout: 10))
    take.tap()
    let root = element("tr14.consent.root", in: app)
    XCTAssertTrue(root.waitForExistence(timeout: 10))
    XCTAssertEqual(root.value as? String, "SynPending0000000001")
    for type in types {
      app.buttons["tr14.consent.grant.\(type)"].firstMatch.tap()
    }
    app.buttons["tr14.consent.submit"].firstMatch.tap()
    XCTAssertTrue(waitForLabel(element("tr14.consent.result", in: app), "동의 확인 대기"))
    app.buttons["common.close"].firstMatch.tap()
    XCTAssertTrue(waitForLabel(row, "SYN Member B, 대기, 동의 확인 대기"), row.label)
    XCTAssertFalse(element("tr03.takeConsent", in: app).exists, "waiting for the server: no second capture")
  }

  /// Review (re-entry after a partial consent): ①② granted and ③ refused leave the member '동의 필요'. Taking consent
  /// again shows ①② as held, without answers ('동의 확인 대기' while the server has not confirmed, '동의함' after), so ②
  /// cannot be refused and silently stay granted; only ③ is asked.
  @MainActor
  func testTakingConsentAgainAsksOnlyTheTypesNotHeld() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--preview-members", "--preview-consent-confirm"]
    app.launch()
    register(in: app)
    XCTAssertTrue(element("tr14.consent.handToMember", in: app).waitForExistence(timeout: 10))
    app.buttons["tr14.consent.grant.required"].firstMatch.tap()
    app.buttons["tr14.consent.grant.healthData"].firstMatch.tap()
    app.buttons["tr14.consent.refuse.bodyImaging"].firstMatch.tap()
    app.buttons["tr14.consent.submit"].firstMatch.tap()
    XCTAssertTrue(waitForLabel(element("tr14.consent.result", in: app), "동의 필요"))
    app.buttons["common.close"].firstMatch.tap()
    XCTAssertTrue(element("tr14.consent.root", in: app).waitForNonExistence(timeout: 10))

    // Waiting for the server: ①② read '동의 확인 대기' and have no answers.
    let row = listRow(named: "SYN Member B", in: app)
    XCTAssertTrue(waitForLabel(row, "SYN Member B, 대기, 동의 필요"), row.label)
    row.tap()
    let take = element("tr03.takeConsent", in: app)
    XCTAssertTrue(take.waitForExistence(timeout: 10))
    take.tap()
    XCTAssertTrue(element("tr14.consent.handToMember", in: app).waitForExistence(timeout: 10))
    for (type, name) in zip(types.prefix(2), typeNames) {
      let state = element("consent.state.awaiting.\(type)", in: app)
      XCTAssertTrue(state.waitForExistence(timeout: 10), type)
      XCTAssertEqual(state.label, "\(name) 동의 확인 대기")
      XCTAssertFalse(app.buttons["tr14.consent.grant.\(type)"].exists, type)
      XCTAssertFalse(app.buttons["tr14.consent.refuse.\(type)"].exists, type)
    }
    XCTAssertTrue(app.buttons["tr14.consent.refuse.bodyImaging"].exists)
    XCTAssertFalse(app.buttons["tr14.consent.submit"].firstMatch.isEnabled, "③ unanswered")
    app.buttons["common.close"].firstMatch.tap()
    XCTAssertTrue(element("tr14.consent.root", in: app).waitForNonExistence(timeout: 10))

    // Confirmed by the server: ①② read '동의함'; granting ③ records it alone.
    element("preview.confirmConsent", in: app).tap()
    XCTAssertTrue(waitForLabel(row, "SYN Member B, 대기, 동의 필요"), row.label)
    XCTAssertTrue(take.waitForExistence(timeout: 10))
    take.tap()
    XCTAssertTrue(element("tr14.consent.handToMember", in: app).waitForExistence(timeout: 10))
    for (type, name) in zip(types.prefix(2), typeNames) {
      let state = element("consent.state.granted.\(type)", in: app)
      XCTAssertTrue(state.waitForExistence(timeout: 10), type)
      XCTAssertEqual(state.label, "\(name) 동의함")
      XCTAssertFalse(app.buttons["tr14.consent.refuse.\(type)"].exists, type)
    }
    let submit = app.buttons["tr14.consent.submit"].firstMatch
    app.buttons["tr14.consent.grant.bodyImaging"].firstMatch.tap()
    XCTAssertTrue(submit.isEnabled)
    submit.tap()
    XCTAssertTrue(waitForLabel(element("tr14.consent.result", in: app), "동의 확인 대기"))
    app.buttons["common.close"].firstMatch.tap()
    element("preview.confirmConsent", in: app).tap()
    XCTAssertTrue(waitForLabel(row, "SYN Member B, 대기, 동의 ①②③"), row.label)
  }

  // MARK: Helpers

  private func waitForLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval = 10) -> Bool {
    let predicate = NSPredicate(format: "label == %@", label)
    return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout)
      == .completed
  }

  /// TR-02 '대기 회원 추가' → TR-14 registration with synthetic values → '다음'.
  private func register(in app: XCUIApplication) {
    let add = element("tr02.addPending", in: app)
    XCTAssertTrue(add.waitForExistence(timeout: 30))
    add.tap()
    XCTAssertTrue(element("tr14.register.root", in: app).waitForExistence(timeout: 10))
    let name = element("tr14.register.displayName", in: app)
    name.tap()
    name.typeText("SYN Member B")
    element("tr14.register.sex.unspecified", in: app).tap()
    element("tr14.register.age14Confirm", in: app).switches.firstMatch.tap()
    element("tr14.register.birthYear", in: app).tap()
    let year = app.buttons["2011"].firstMatch
    XCTAssertTrue(year.waitForExistence(timeout: 5))
    year.tap()
    let next = app.buttons["tr14.register.next"].firstMatch
    XCTAssertTrue(next.isEnabled)
    next.tap()
  }

  /// The TR-02 row whose spoken label starts with `name` (rows are identified by position, `tr02.row.<n>`).
  private func listRow(named name: String, in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH 'tr02.row.' AND label BEGINSWITH %@", name + ",")).firstMatch
  }

  private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any)[identifier].firstMatch
  }
}
