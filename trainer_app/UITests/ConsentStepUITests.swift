import XCTest

/// DF-110 MVP: the TR-14 consent step after registration, in preview mode (`--preview-members`): synthetic published
/// versions, captures kept in memory and never sent, no server state. Synthetic data only.
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

  // MARK: Helpers

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

  private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any)[identifier].firstMatch
  }
}
