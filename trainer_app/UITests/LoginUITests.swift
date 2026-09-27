import XCTest

/// TC-DF012-04: the `--preview-login` gate (DEBUG, scripted synthetic accounts in `PreviewAuthService`, no Firebase).
final class LoginUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
    XCUIDevice.shared.orientation = .landscapeLeft
  }

  @MainActor
  func testLoginErrorsAndSuccess_TC_DF012_04() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--preview-login"]
    app.launch()

    XCTAssertTrue(app.otherElements["login.root"].waitForExistence(timeout: 30))
    for id in ["auth.email", "auth.password", "auth.submit"] {
      XCTAssertTrue(element(id, in: app).exists, "missing \(id)")
    }
    XCTAssertFalse(element("auth.submit", in: app).isEnabled, "submit needs email and password")
    XCTAssertFalse(app.otherElements["app.root"].exists)

    signIn(app, email: "member@example.invalid", password: "anything")
    assertError(app, "트레이너 권한이 없는 계정이에요. 트레이너 계정으로 로그인하세요.")
    attachScreenshot(app, name: "TC-DF012-04 notTrainer")

    signIn(app, email: "trainer@example.invalid", password: "wrong")
    assertError(app, "이메일 또는 비밀번호가 맞지 않아요.")

    signIn(app, email: "offline@example.invalid", password: "anything")
    assertError(app, "서버에 연결할 수 없어요. 잠시 뒤 다시 시도해 주세요.")

    signIn(app, email: "trainer@example.invalid", password: "preview-only-password")
    XCTAssertTrue(app.otherElements["app.root"].waitForExistence(timeout: 10))
    XCTAssertFalse(app.otherElements["login.root"].exists)
  }

  /// AC-DF-012.3 on screen: the claim is revoked while signed in; returning to the foreground re-checks it and the
  /// login screen shows the lock notice (`--preview-login`, synthetic `revoked@example.invalid`).
  @MainActor
  func testClaimRevokedShowsLockNotice_TC_DF012_04() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--preview-login"]
    app.launch()
    XCTAssertTrue(app.otherElements["login.root"].waitForExistence(timeout: 30))

    signIn(app, email: "revoked@example.invalid", password: "preview-only-password")
    XCTAssertTrue(app.otherElements["app.root"].waitForExistence(timeout: 10))
    XCTAssertFalse(element("auth.locked", in: app).exists)

    XCUIDevice.shared.press(.home)
    app.activate()
    let notice = element("auth.locked", in: app)
    XCTAssertTrue(notice.waitForExistence(timeout: 15))
    XCTAssertEqual(notice.label, "계정 권한이 바뀌어 다시 로그인해야 해요.")
    XCTAssertTrue(app.otherElements["login.root"].exists)
    attachScreenshot(app, name: "TC-DF012-04 claim revoked")
  }

  private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any)[identifier].firstMatch
  }

  private func signIn(_ app: XCUIApplication, email: String, password: String) {
    replaceText(in: element("auth.email", in: app), with: email)
    replaceText(in: element("auth.password", in: app), with: password)
    let submit = element("auth.submit", in: app)
    XCTAssertTrue(submit.isEnabled)
    if submit.isHittable {
      submit.tap()
    } else {
      element("auth.password", in: app).typeText("\n")  // the keyboard covers the button: submit from the field
    }
  }

  /// Clears the field and types `text`. Tapping near the trailing edge puts the cursor after any existing text.
  private func replaceText(in field: XCUIElement, with text: String) {
    field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
    if let current = field.value as? String, !current.isEmpty, current != field.placeholderValue {
      field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
    }
    field.typeText(text)
  }

  private func assertError(_ app: XCUIApplication, _ text: String, file: StaticString = #filePath, line: UInt = #line) {
    let error = element("auth.error", in: app)
    let predicate = NSPredicate(format: "label == %@", text)
    let found = expectation(for: predicate, evaluatedWith: error)
    wait(for: [found], timeout: 10)
    XCTAssertEqual(error.label, text, file: file, line: line)
  }

  private func attachScreenshot(_ app: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
