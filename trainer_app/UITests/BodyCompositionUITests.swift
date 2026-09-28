import XCTest

/// DF-127 / DF-130 in preview mode: TR-03 '측정 입력 > 신체조성' opens TR-11; a saved record is on the mini trend at
/// once. `--preview-flags=bodyComposition` is the DEBUG override of the client entry point. SYN-0001 has six synthetic
/// records (64.x~68.x kg, a device change); the preview store is in memory and sends nothing.
final class BodyCompositionUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
    XCUIDevice.shared.orientation = .landscapeLeft
  }

  /// TC-127-12 (AC-DF-127.11), AC-DF-127.1, AC-DF-127.6, AC-DF-130.11: enter weight '62,4' with the meta, save, and the
  /// chart has the new point (seven records, the new minimum 62.4 kg) with its save state; TR-03 keeps every metric's
  /// latest value.
  @MainActor
  func testMeasureMenuOpensTR11AndASavedRecordIsOnTheTrend() throws {
    let app = launch(["--preview-members", "--preview-flags=bodyComposition"])
    openFirstMember(in: app)

    // TR-03 shows the member's trend before anything is entered.
    let section = element("tr03.bodyComposition", in: app)
    XCTAssertTrue(section.waitForExistence(timeout: 10))
    XCTAssertTrue(chartSummary(containing: "기록 6개", in: app).waitForExistence(timeout: 10), "six synthetic records")
    // The device change's reason is text under the plot, numbered like its marker on the rule (review findings 5, 6).
    let deviceChange = element("chart.break.1", in: app)
    XCTAssertTrue(deviceChange.waitForExistence(timeout: 10))
    XCTAssertTrue(deviceChange.label.contains("InBody 570"), deviceChange.label)
    attachScreenshot(app, name: "TR-03 body composition")

    let menu = element("tr03.measureMenu", in: app)
    XCTAssertTrue(menu.exists)
    XCTAssertEqual(menu.label, "측정 입력")
    menu.tap()
    let item = menuItem("tr03.entry.bodyComposition", label: "신체조성", in: app)
    XCTAssertTrue(item.waitForExistence(timeout: 5))
    item.tap()

    XCTAssertTrue(element("tr11.root", in: app).waitForExistence(timeout: 10))
    let save = app.buttons["tr11.save"].firstMatch
    XCTAssertTrue(save.waitForExistence(timeout: 5))
    XCTAssertFalse(save.isEnabled, "fasting has no default and no value is entered (AC-DF-127.1)")
    // The device defaults to the latest record's; the time of day is computed, not a control.
    XCTAssertTrue(element("tr11.timeOfDayBand", in: app).exists)
    XCTAssertFalse(element("tr11.fasting.yes", in: app).isSelected)

    // Top to bottom, as the form reads: fasting, then the value.
    let fasting = element("tr11.fasting.yes", in: app)
    fasting.tap()
    XCTAssertTrue(fasting.isSelected)
    XCTAssertFalse(save.isEnabled, "no value yet")
    let weight = element("tr11.value.weightKg", in: app)
    weight.tap()
    weight.typeText("62,4")
    XCTAssertTrue(save.isEnabled)
    attachScreenshot(app, name: "TR-11 filled")
    save.tap()

    // The sheet shows the saved record and its trend, which already has the new point.
    let record = element("tr11.record", in: app)
    XCTAssertTrue(record.waitForExistence(timeout: 10))
    XCTAssertTrue(element("metric.row.weightKg", in: app).waitForExistence(timeout: 10))
    let summary = chartSummary(containing: "기록 7개", in: app)
    XCTAssertTrue(summary.waitForExistence(timeout: 10), "the new record is a point")
    XCTAssertTrue(summary.label.contains("최소 62.4kg"), summary.label)
    XCTAssertTrue(summary.label.contains("산정 준비 중"), summary.label)
    // The save result (V1-07 §6): the preview sends nothing, so it stays '기기에 저장됨' (review finding 4).
    XCTAssertTrue(element("sync.badge.localSaved", in: app).waitForExistence(timeout: 10))
    attachScreenshot(app, name: "TR-11 record with mini trend")

    element("tr11.close", in: app).tap()
    XCTAssertTrue(section.waitForExistence(timeout: 10))
    XCTAssertTrue(chartSummary(containing: "기록 7개", in: app).waitForExistence(timeout: 10), "TR-03 has it too")
    // Each TR-03 row is its metric's latest record: the weight-only save does not hide body fat % and skeletal muscle
    // mass (review finding 7), and the unsynced weight row carries its state (finding 4).
    let latest = element("tr03.bodyComposition.latest", in: app)
    XCTAssertTrue(latest.waitForExistence(timeout: 10))
    for metric in ["weightKg", "bodyFatPercent", "skeletalMuscleMassKg"] {
      XCTAssertTrue(latest.descendants(matching: .any)["metric.row.\(metric)"].firstMatch.exists, metric)
    }
    XCTAssertTrue(latest.descendants(matching: .any)["sync.badge.localSaved"].firstMatch.exists)
    attachScreenshot(app, name: "TR-03 after saving")
  }

  /// TC-127-12 flag off: no '측정 입력' menu and no body composition section on TR-03.
  @MainActor
  func testFlagOffHasNoMeasureMenu_TC_127_12() throws {
    let app = launch(["--preview-members"])
    openFirstMember(in: app)
    XCTAssertFalse(element("tr03.measureMenu", in: app).exists)
    XCTAssertFalse(element("tr03.bodyComposition", in: app).exists)
  }

  /// DF-127 second review (NFR-12, V1-07 §3.3): narrowing to a compact width while TR-11 is open (1/3 Split View,
  /// Slide Over) and widening again keeps the sheet and what was typed. `preview.toggleWidth` is above the sheet.
  @MainActor
  func testAWidthChangeKeepsTR11AndWhatWasTyped() throws {
    let app = launch(["--preview-members", "--preview-flags=bodyComposition", "--preview-width=375",
                      "--preview-resizable"])
    let toggle = element("preview.toggleWidth", in: app)
    XCTAssertTrue(toggle.waitForExistence(timeout: 10))
    toggle.tap()  // wide: TR-03 in the detail column
    openFirstMember(in: app)
    XCTAssertTrue(element("tr03.measureMenu", in: app).waitForExistence(timeout: 10))
    element("tr03.measureMenu", in: app).tap()
    menuItem("tr03.entry.bodyComposition", label: "신체조성", in: app).tap()
    XCTAssertTrue(element("tr11.root", in: app).waitForExistence(timeout: 10))
    element("tr11.fasting.yes", in: app).tap()
    let weight = element("tr11.value.weightKg", in: app)
    weight.tap()
    weight.typeText("62,4")

    for width in ["narrow", "wide"] {
      toggle.tap()
      XCTAssertTrue(element("tr11.root", in: app).waitForExistence(timeout: 10), "TR-11 closed going \(width)")
      XCTAssertEqual(element("tr11.value.weightKg", in: app).value as? String, "62,4", "the weight going \(width)")
      XCTAssertTrue(element("tr11.fasting.yes", in: app).isSelected, "fasting going \(width)")
      XCTAssertTrue(app.buttons["tr11.save"].firstMatch.isEnabled, width)
      attachScreenshot(app, name: "TR-11 after going \(width)")
    }
  }

  // MARK: Helpers

  private func launch(_ arguments: [String]) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = arguments
    app.launch()
    XCTAssertTrue(element("app.root", in: app).waitForExistence(timeout: 30))
    return app
  }

  private func openFirstMember(in app: XCUIApplication) {
    let row = element("tr02.row.0", in: app)
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    row.tap()
    XCTAssertTrue(element("tr03.root", in: app).waitForExistence(timeout: 10))
  }

  /// A menu item by identifier, or by its label where the system menu does not carry the identifier.
  private func menuItem(_ identifier: String, label: String, in app: XCUIApplication) -> XCUIElement {
    let byID = app.buttons[identifier].firstMatch
    return byID.waitForExistence(timeout: 3) ? byID : app.buttons[label].firstMatch
  }

  /// The chart plot's VoiceOver label is the `chart.summary` sentence.
  private func chartSummary(containing text: String, in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
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
