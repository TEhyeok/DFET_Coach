import XCTest

/// TR-02 → TR-14 → TR-03 → TR-11, using only the in-memory synthetic workflow preview.
/// LocalStore/outbox persistence and server confirmation are covered by their integration tests.
final class ConsentBodyWorkflowUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
    XCUIDevice.shared.orientation = .landscapeLeft
  }

  @MainActor
  func testRegistrationConsentAndBodyCompositionRecord() throws {
    let app = launchWorkflow()
    register("SYN Workflow A", in: app)
    beginConsent(in: app)

    let submit = app.buttons["tr14.consent.submit"].firstMatch
    XCTAssertFalse(submit.isEnabled, "Every core item needs an explicit answer")
    XCTAssertFalse(app.buttons["모두 동의"].exists)
    for type in ["required", "healthData", "bodyImaging"] {
      let agree = element("tr14.card.\(type).agree", in: app)
      let disagree = element("tr14.card.\(type).disagree", in: app)
      reveal(agree, scrolling: "tr14.consent.root", in: app)
      XCTAssertFalse(agree.isSelected, "\(type) must not be preselected")
      XCTAssertFalse(disagree.isSelected, "\(type) must not be preselected")
      // Refusing the optional photo consent must still allow a health measurement.
      let answer = type == "bodyImaging" ? disagree : agree
      answer.tap()
      XCTAssertTrue(answer.isSelected)
      if type != "bodyImaging" { XCTAssertFalse(submit.isEnabled) }
    }
    reveal(submit, scrolling: "tr14.consent.root", in: app)
    XCTAssertTrue(submit.isEnabled)
    attachScreenshot(app, name: "Explicit consent choices with optional photo refusal")
    submit.tap()
    let complete = element("tr14.consent.complete", in: app)
    XCTAssertTrue(complete.waitForExistence(timeout: 10))
    XCTAssertTrue(element("tr14.consent.resultState", in: app).exists)
    complete.tap()

    XCTAssertTrue(element("tr03.root", in: app).waitForExistence(timeout: 10))
    XCTAssertEqual(element("tr03.memberName", in: app).label, "SYN Workflow A")
    element("tr03.measureMenu", in: app).tap()
    let bodyEntry = element("tr03.entry.bodyComposition", in: app)
    XCTAssertTrue(bodyEntry.waitForExistence(timeout: 5))
    bodyEntry.tap()
    XCTAssertTrue(element("tr11.root", in: app).waitForExistence(timeout: 10))

    let save = app.buttons["tr11.save"].firstMatch
    XCTAssertFalse(save.isEnabled)
    let device = app.textFields["tr11.device"].firstMatch
    XCTAssertTrue(device.waitForExistence(timeout: 5))
    device.tap()
    device.typeText("SYN Scale A")
    let fasting = app.buttons["tr11.fasting.yes"].firstMatch
    reveal(fasting, scrolling: "tr11.root", in: app)
    XCTAssertTrue(fasting.label.contains("공복"), "The fasting choice must have a readable title")
    XCTAssertTrue(app.buttons["tr11.fasting.no"].firstMatch.label.contains("공복 아님"))
    fasting.tap()
    XCTAssertTrue(fasting.isSelected)
    let weight = app.textFields["tr11.value.weightKg"].firstMatch
    reveal(weight, scrolling: "tr11.root", in: app)
    weight.tap()
    weight.typeText("65.4")
    XCTAssertTrue(save.isEnabled)
    XCTAssertFalse(element("tr11.consentNeeded", in: app).exists)
    save.tap()

    let saved = element("sync.badge.localSaved", in: app)
    reveal(saved, scrolling: "tr11.root", in: app)
    XCTAssertFalse(save.isEnabled, "A saved entry cannot be submitted twice")
    // The Form materializes only visible rows: the badge can sit at the bottom edge with the row below it unloaded.
    let newEntry = element("tr11.newEntry", in: app)
    reveal(newEntry, scrolling: "tr11.root", in: app)
    XCTAssertTrue(newEntry.exists)
    XCTAssertFalse(element("tr11.saveFailed", in: app).exists)
    attachScreenshot(app, name: "Body composition locally saved")
    element("tr11.close", in: app).tap()
    XCTAssertTrue(element("tr11.root", in: app).waitForNonExistence(timeout: 10))

    // Read the saved measurement through the member-detail history, after closing its input sheet.
    let record = app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "tr11.record.")).firstMatch
    reveal(record, scrolling: "tr03.root", in: app)
    XCTAssertTrue(app.staticTexts["SYN Scale A"].exists)
    record.tap()
    let metric = element("metric.row.weightKg", in: app)
    reveal(metric, scrolling: "tr03.root", in: app)
    XCTAssertTrue(metric.label.contains("65.4"), metric.label)
    XCTAssertTrue(metric.label.contains("kg"), metric.label)
    XCTAssertTrue(metric.label.contains("SYN Scale A"), metric.label)
    attachScreenshot(app, name: "Saved measurement in member history")
  }

  @MainActor
  func testRequiredRefusalCancelsPendingRegistration() throws {
    let app = launchWorkflow()
    register("SYN Cancelled A", in: app)
    beginConsent(in: app)

    let refusal = element("tr14.card.required.disagree", in: app)
    reveal(refusal, scrolling: "tr14.consent.root", in: app)
    refusal.tap()
    let submit = app.buttons["tr14.consent.submit"].firstMatch
    reveal(submit, scrolling: "tr14.consent.root", in: app)
    XCTAssertTrue(submit.isEnabled, "Required refusal does not require optional answers")
    submit.tap()
    let confirmation = app.alerts.firstMatch
    XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
    XCTAssertTrue(confirmation.staticTexts["서비스 이용에 동의하지 않고 회원 등록을 취소할까요?"]
      .waitForExistence(timeout: 5))
    confirmation.buttons["확인"].tap()
    XCTAssertTrue(element("tr14.consent.registrationCancelled", in: app).waitForExistence(timeout: 10))
    element("tr14.consent.complete", in: app).tap()

    XCTAssertTrue(element("tr14.consent.root", in: app).waitForNonExistence(timeout: 10))
    XCTAssertTrue(element("tr02.empty", in: app).waitForExistence(timeout: 10))
    XCTAssertFalse(element("tr02.row.0", in: app).exists)
    XCTAssertFalse(element("tr03.root", in: app).exists, "A cancelled member must not open a detail page")
    attachScreenshot(app, name: "Required refusal returns to empty member list")
  }

  @MainActor
  func testConsentChoicesAndSubmitRemainReachableWithLargestText() throws {
    let app = launchWorkflow(extraArguments: [
      "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
    ])
    register("SYN Large Text A", in: app)
    beginConsent(in: app)

    for type in ["required", "healthData", "bodyImaging"] {
      let agree = element("tr14.card.\(type).agree", in: app)
      reveal(agree, scrolling: "tr14.consent.root", in: app)
      XCTAssertFalse(agree.isSelected)
      XCTAssertGreaterThanOrEqual(agree.frame.height, 44)
      XCTAssertGreaterThanOrEqual(agree.frame.width, 44)
      agree.tap()
      let disagree = element("tr14.card.\(type).disagree", in: app)
      reveal(disagree, scrolling: "tr14.consent.root", in: app)
      XCTAssertFalse(disagree.isSelected)
      XCTAssertGreaterThanOrEqual(disagree.frame.height, 44)
      XCTAssertGreaterThanOrEqual(disagree.frame.width, 44)
    }
    let submit = app.buttons["tr14.consent.submit"].firstMatch
    reveal(submit, scrolling: "tr14.consent.root", in: app)
    XCTAssertTrue(submit.isEnabled)
    XCTAssertGreaterThanOrEqual(submit.frame.height, 44)
    XCTAssertGreaterThanOrEqual(submit.frame.width, 44)
    attachScreenshot(app, name: "Consent choices and submit at largest accessibility text")
    submit.tap()
    XCTAssertTrue(element("tr14.consent.complete", in: app).waitForExistence(timeout: 10))
  }

  @MainActor
  private func launchWorkflow(extraArguments: [String] = []) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--preview-workflow", "--preview-flags=bodyComposition"] + extraArguments
    app.launch()
    XCTAssertTrue(element("app.root", in: app).waitForExistence(timeout: 30))
    XCTAssertTrue(element("tr02.empty", in: app).waitForExistence(timeout: 10))
    return app
  }

  @MainActor
  private func register(_ name: String, in app: XCUIApplication) {
    element("tr02.addPending", in: app).tap()
    XCTAssertTrue(element("tr14.register.root", in: app).waitForExistence(timeout: 10))
    let displayName = element("tr14.register.displayName", in: app)
    displayName.tap()
    displayName.typeText(name)
    let sex = element("tr14.register.sex.female", in: app)
    reveal(sex, scrolling: "tr14.register.root", in: app)
    sex.tap()
    let birthYear = element("tr14.register.birthYear", in: app)
    reveal(birthYear, scrolling: "tr14.register.root", in: app)
    birthYear.tap()
    selectYear(2011, in: app)
    let confirmation = element("tr14.register.age14Confirm", in: app).switches.firstMatch
    reveal(confirmation, scrolling: "tr14.register.root", in: app)
    confirmation.tap()
    let next = app.buttons["tr14.register.next"].firstMatch
    XCTAssertTrue(next.isEnabled)
    next.tap()
    XCTAssertTrue(element("tr14.consent.root", in: app).waitForExistence(timeout: 10))
  }

  /// Large text virtualizes the year menu; its collection can extend beyond the popup's clipping bounds.
  @MainActor
  private func selectYear(_ year: Int, in app: XCUIApplication,
                          file: StaticString = #filePath, line: UInt = #line) {
    let target = app.buttons[String(year)].firstMatch
    let years = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "[0-9]{4}"))
    XCTAssertTrue(years.firstMatch.waitForExistence(timeout: 5), file: file, line: line)
    for _ in 0..<16 {
      let rows = years.allElementsBoundByIndex
      guard let first = rows.first,
            let menu = app.otherElements.containing(.button, identifier: first.label).allElementsBoundByIndex
              .filter({ !$0.frame.isEmpty })
              .min(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }) else {
        XCTFail("The year menu has no visible popup container", file: file, line: line)
        return
      }
      let bounds = menu.frame.insetBy(dx: 8, dy: 8)
      if target.exists && target.isHittable,
         bounds.contains(CGPoint(x: target.frame.midX, y: target.frame.midY)) {
        target.tap()
        return
      }
      let visible = rows.filter {
        bounds.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY))
      }.sorted { $0.frame.minY < $1.frame.minY }
      guard let top = visible.first, let topYear = Int(top.label) else {
        XCTFail("The year menu has no scrollable visible year rows", file: file, line: line)
        return
      }
      let topPoint = menu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
      let bottomPoint = menu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
      if year < topYear {
        bottomPoint.press(forDuration: 0.05, thenDragTo: topPoint)
      } else {
        topPoint.press(forDuration: 0.05, thenDragTo: bottomPoint)
      }
    }
    XCTFail("Could not reveal birth year \(year)", file: file, line: line)
  }

  @MainActor
  private func beginConsent(in app: XCUIApplication) {
    let start = element("tr14.handoff.start", in: app)
    XCTAssertTrue(start.waitForExistence(timeout: 10))
    start.tap()
    XCTAssertTrue(element("tr14.card.required.agree", in: app).waitForExistence(timeout: 5))
  }

  /// Short drags stay inside the visible scroll area and can recover when an input moves above it.
  @MainActor
  private func reveal(_ target: XCUIElement, scrolling root: String, in app: XCUIApplication,
                      file: StaticString = #filePath, line: UInt = #line) {
    for _ in 0..<20 {
      if target.exists && target.isHittable { return }
      let screen = element(root, in: app)
      let collection = screen.descendants(matching: .collectionView).firstMatch
      let scrollView = screen.descendants(matching: .scrollView).firstMatch
      let scroll = collection.exists ? collection : (scrollView.exists ? scrollView : screen)
      var viewport = scroll.frame.intersection(screen.frame).intersection(app.frame)
      let navigationBar = screen.descendants(matching: .navigationBar).firstMatch
      if navigationBar.exists {
        let top = max(viewport.minY, navigationBar.frame.maxY)
        viewport = CGRect(x: viewport.minX, y: top, width: viewport.width, height: max(0, viewport.maxY - top))
      }
      for overlay in [app.keyboards.firstMatch, app.otherElements["SystemInputAssistantView"].firstMatch]
      where overlay.exists && viewport.intersects(overlay.frame) {
        viewport.size.height = max(0, overlay.frame.minY - viewport.minY)
      }
      viewport = viewport.insetBy(dx: 12, dy: 12)
      guard !viewport.isEmpty, viewport.height > 60 else { break }
      let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
      let upper = origin.withOffset(CGVector(dx: viewport.midX - app.frame.minX,
        dy: viewport.minY + viewport.height * 0.4 - app.frame.minY))
      let lower = origin.withOffset(CGVector(dx: viewport.midX - app.frame.minX,
        dy: viewport.minY + viewport.height * 0.7 - app.frame.minY))
      if target.exists && target.frame.midY < viewport.minY {
        upper.press(forDuration: 0.05, thenDragTo: lower)
      } else {
        lower.press(forDuration: 0.05, thenDragTo: upper)
      }
    }
    let hierarchy = XCTAttachment(string: app.debugDescription)
    hierarchy.name = "UI hierarchy when reveal failed"
    hierarchy.lifetime = .keepAlways
    add(hierarchy)
    XCTAssertTrue(target.exists && target.isHittable, "Cannot reveal \(target)", file: file, line: line)
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
