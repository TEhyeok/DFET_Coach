import XCTest

/// DF-108 (TC-108-03, TC-108-06, TC-108-07): TR-14 registration from TR-02 in preview mode. Synthetic data only; the
/// preview registrar keeps registrations in memory.
final class PendingMemberRegistrationUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
    XCUIDevice.shared.orientation = .landscapeLeft
  }

  @MainActor
  func test_TC_108_03_06_registerAndOpenTheConsentStep() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--preview-members"]
    app.launch()
    let add = element("tr02.addPending", in: app)
    XCTAssertTrue(add.waitForExistence(timeout: 30))
    XCTAssertEqual(add.label, "대기 회원 추가")
    add.tap()
    XCTAssertTrue(element("tr14.register.root", in: app).waitForExistence(timeout: 10))

    // AC-DF-108.1: the four inputs only, nothing preselected, no contact fields.
    XCTAssertEqual(app.textFields.count, 1, "display name is the only text field (no phone, email or address)")
    for sex in ["female", "male", "unspecified"] {
      let option = element("tr14.register.sex.\(sex)", in: app)
      XCTAssertTrue(option.exists, sex)
      XCTAssertFalse(option.isSelected, "\(sex) is not preselected")
      XCTAssertGreaterThanOrEqual(option.frame.height, 44)
    }
    XCTAssertEqual(element("tr14.register.sex.female", in: app).label, "여성")
    XCTAssertTrue(element("tr14.register.birthYear", in: app).exists)
    XCTAssertTrue(element("tr14.register.age14Confirm", in: app).exists)
    let next = app.buttons["tr14.register.next"].firstMatch
    XCTAssertFalse(next.isEnabled)

    let name = element("tr14.register.displayName", in: app)
    name.tap()
    name.typeText("SYN Member A")
    element("tr14.register.sex.female", in: app).tap()
    XCTAssertTrue(element("tr14.register.sex.female", in: app).isSelected)
    element("tr14.register.age14Confirm", in: app).switches.firstMatch.tap()

    // AC-DF-108.2: a birth year under 14 blocks saving and says why.
    pickYear("2013", in: app)
    XCTAssertTrue(element("tr14.register.under14Blocked", in: app).waitForExistence(timeout: 5))
    XCTAssertFalse(next.isEnabled)
    pickYear("2011", in: app)
    XCTAssertFalse(element("tr14.register.under14Blocked", in: app).exists)
    XCTAssertTrue(next.isEnabled)

    // TC-108-07: controls pass an accessibility audit for labels and hit regions. Plain containers (element type
    // `other`, e.g. the shell's grouping views behind the sheet) have nothing to describe.
    try app.performAccessibilityAudit(for: [.sufficientElementDescription, .hitRegion]) { issue in
      issue.element?.elementType == .other
    }

    // AC-DF-108.4: saving closes the sheet and opens the consent step for the same pending member.
    next.tap()
    let consent = element("tr14.consent.root", in: app)
    XCTAssertTrue(consent.waitForExistence(timeout: 10))
    XCTAssertEqual(consent.value as? String, "SynPending0000000001")
    XCTAssertFalse(element("tr14.register.root", in: app).exists)
  }

  private func pickYear(_ year: String, in app: XCUIApplication) {
    element("tr14.register.birthYear", in: app).tap()
    let option = app.buttons[year].firstMatch
    XCTAssertTrue(option.waitForExistence(timeout: 5), year)
    option.tap()
  }

  private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any)[identifier].firstMatch
  }
}
