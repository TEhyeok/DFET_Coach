import Foundation
import TrainerContracts
import XCTest
@testable import TrainerDomain

/// DF-127: TR-11 body composition entry rules (V1-05 §4.7, V1-09 §10). Synthetic values only.
final class BodyCompositionTests: XCTestCase {
  private func seoul(_ text: String) -> Date { FixtureTimestamp.parse(text)! }

  /// 2026-12-07 09:00 KST.
  private lazy var now = seoul("2026-12-07T09:00:00+09:00")

  private func draft(
    _ values: [BodyCompositionKey: String], device: String? = "InBody 570", measuredAt: Date? = nil,
    fasting: Fasting? = .yes, height: String? = nil, heightMeasuredAt: Date? = nil
  ) -> BodyCompositionDraft {
    BodyCompositionDraft(
      values: values, deviceModel: device, measuredAt: measuredAt ?? seoul("2026-12-07T08:40:00+09:00"),
      fasting: fasting, heightCmInput: height, heightMeasuredAt: heightMeasuredAt)
  }

  // MARK: Keys and ranges

  func testKeysMatchTheCatalogAndTheCardRanges() {
    let expected: [(BodyCompositionKey, ClosedRange<Double>, MetricUnit, Bool)] = [
      (.weightKg, 0.1...600, .kg, true),
      (.bodyFatPercent, 0...100, .percent, true),
      (.skeletalMuscleMassKg, 0.1...300, .kg, true),
      (.bodyFatMassKg, 0.1...600, .kg, true),
      (.visceralFatLevel, 1...100, .level, false),
      (.totalBodyWaterL, 0.1...300, .liter, false),
    ]
    XCTAssertEqual(BodyCompositionKey.allCases, expected.map(\.0))
    for (key, range, unit, primary) in expected {
      XCTAssertEqual(key.appRange, range, "\(key)")
      XCTAssertEqual(key.unit, unit, "\(key)")
      XCTAssertEqual(key.isPrimary, primary, "\(key)")
      XCTAssertEqual(key.metricCode.rawValue, key.rawValue)
      XCTAssertEqual(MetricCatalog.entry(for: key.metricCode).storage.field, "values.\(key.rawValue)")
      XCTAssertEqual(key.nameCopyKey, "metric.\(key.rawValue).name")
    }
    XCTAssertEqual(BodyCompositionKey(metricCode: .bmi), nil, "bmi is derived, never a value key")
    XCTAssertEqual(BodyCompositionKey(metricCode: .weightKg), .weightKg)
    XCTAssertEqual(BodyCompositionHeight.rangeCm, 100...250)
  }

  // MARK: timeOfDayBand (TC-127-10, V1-09 §10.3 TB-01~06)

  func testTimeOfDayBandBoundariesInSeoul() {
    let cases: [(String, TimeOfDayBand, UInt)] = [
      ("2027-01-04T10:59:59+09:00", .morning, #line),
      ("2027-01-04T10:59:00+09:00", .morning, #line),
      ("2027-01-04T11:00:00+09:00", .midday, #line),
      ("2027-01-04T16:59:00+09:00", .midday, #line),
      ("2027-01-04T16:59:59+09:00", .midday, #line),
      ("2027-01-04T17:00:00+09:00", .evening, #line),
      ("2027-01-04T23:59:59+09:00", .evening, #line),
      ("2027-01-04T00:30:00+09:00", .morning, #line),
      ("2027-01-04T01:30:00Z", .morning, #line),  // 10:30 KST whatever the device zone
      ("2027-01-04T02:00:00Z", .midday, #line),  // 11:00 KST
      ("2027-01-04T08:00:00Z", .evening, #line),  // 17:00 KST
      ("2027-01-03T15:30:00Z", .morning, #line),  // 00:30 KST the next day
    ]
    for (text, band, line) in cases {
      XCTAssertEqual(TimeOfDayBand(measuredAt: seoul(text)), band, text, line: line)
    }
    XCTAssertEqual(TimeOfDayBand.morning.copyKey, "timeOfDay.morning")
    XCTAssertEqual(TimeOfDayBand.midday.copyKey, "timeOfDay.midday")
    XCTAssertEqual(TimeOfDayBand.evening.copyKey, "timeOfDay.evening")
  }

  func testFastingHasNoDefaultAndUnknownIsSecondary() {
    XCTAssertNil(BodyCompositionDraft(measuredAt: now).fasting)
    XCTAssertEqual(Fasting.primaryChoices, [.yes, .no])
    XCTAssertEqual(Fasting.yes.copyKey, "tr11.fasting.yes")
    XCTAssertEqual(Fasting.no.copyKey, "tr11.fasting.no")
    XCTAssertEqual(Fasting.unknown.copyKey, "tr11.fasting.unknown")
  }

  // MARK: BMI (TC-127-06)

  func testBMI() {
    let cases: [(Double?, Double?, Double?, UInt)] = [
      (62.4, 165.0, 22.9, #line),  // 22.920… (V1-09 BC-09)
      (22.25, 100, 22.3, #line),  // half away from zero, not to even
      (70, 175, 22.9, #line),  // 22.857…
      (62.4, 99.9, nil, #line),
      (62.4, 100, 62.4, #line),
      (62.4, 250, 10.0, #line),  // 9.984
      (62.4, 250.1, nil, #line),
      (nil, 165, nil, #line),
      (62.4, nil, nil, #line),
      (0, 165, nil, #line),
      (-1, 165, nil, #line),
      (.nan, 165, nil, #line),
      (62.4, .infinity, nil, #line),
      (200, 100, 200, #line),
      (250, 110, nil, #line),  // 206.6: above the rules' 200, so no derived map
      (600, 100, nil, #line),
      // Review (GPT): 0.0 after rounding is below the rules' `bmi > 0`, so no derived map either.
      (0.1, 250, nil, #line),  // 0.016
      (0.3, 250, nil, #line),  // 0.048
      (0.31, 250, nil, #line),  // 0.0496
      (0.32, 250, 0.1, #line),  // 0.0512: the smallest weight at 250 cm with a BMI
      (0.4, 250, 0.1, #line),  // 0.064
    ]
    for (weight, height, bmi, line) in cases {
      XCTAssertEqual(BMICalculator.bmi(weightKg: weight, heightCm: height), bmi, line: line)
    }
    XCTAssertEqual(BMICalculator.maximum, 200)
    XCTAssertEqual(BMICalculator.minimum, 0)
    XCTAssertFalse(BMICalculator.isInRange(0))
    XCTAssertTrue(BMICalculator.isInRange(0.1))
    XCTAssertTrue(BMICalculator.isInRange(200))
    XCTAssertFalse(BMICalculator.isInRange(200.1))
  }

  /// Review (GPT): weight 0.1 kg (the app's minimum) at 250 cm passes validation, but its BMI rounds to 0.0, which the
  /// rules refuse (`numPosMax(derived.bmi, 200)`). The record saves without `derived`, so the server accepts it.
  func testABMIThatRoundsToZeroIsNotDerived() throws {
    for weight in ["0.1", "0.3"] {
      let result = BodyCompositionValidator.validate(draft([.weightKg: weight], height: "250"), now: now)
      XCTAssertTrue(result.canSave, weight)
      XCTAssertNil(result.bmi, weight)
      let entry = try XCTUnwrap(result.entry, weight)
      XCTAssertNil(entry.derived, weight)
      guard case let .object(fields) = BodyCompositionPayload.fields(entry, member: .uid("syn-0001"), trainerUid: "syn-t")
      else { return XCTFail("object payload expected") }
      XCTAssertNil(fields["derived"], "\(weight): no derived map for the rules to refuse")
    }
    let smallest = BodyCompositionValidator.validate(draft([.weightKg: "0.4"], height: "250"), now: now)
    XCTAssertEqual(smallest.entry?.derived?.bmi, 0.1)
  }

  // MARK: Validator: required meta (TC-127-01)

  func testCompleteWeightOnlyDraftSaves() throws {
    let result = BodyCompositionValidator.validate(draft([.weightKg: "62,4", .bodyFatPercent: "  "]), now: now)
    XCTAssertEqual(result.issues, [])
    XCTAssertTrue(result.canSave)
    let entry = try XCTUnwrap(result.entry)
    XCTAssertEqual(entry.values, [.weightKg: 62.4])
    XCTAssertEqual(entry.deviceModel, "InBody 570")
    XCTAssertEqual(entry.fasting, .yes)
    XCTAssertEqual(entry.timeOfDayBand, .morning)
    XCTAssertNil(entry.derived)
    XCTAssertNil(result.bmi)
  }

  func testMissingMetaBlocksSaving() {
    let cases: [(BodyCompositionDraft, [BodyCompositionIssue], UInt)] = [
      (draft([.weightKg: "62.4"], device: nil), [.deviceModelMissing], #line),
      (draft([.weightKg: "62.4"], device: ""), [.deviceModelMissing], #line),
      (draft([.weightKg: "62.4"], device: " \u{3000} "), [.deviceModelMissing], #line),
      (draft([.weightKg: "62.4"], fasting: nil), [.fastingMissing], #line),
      (draft([.weightKg: "62.4"], device: nil, fasting: nil), [.deviceModelMissing, .fastingMissing], #line),
      (draft([.weightKg: "62.4"], measuredAt: now.addingTimeInterval(6 * 60)), [.measuredAtInFuture], #line),
      (draft([:]), [.noValue], #line),
      (draft([.weightKg: "", .bodyFatPercent: " "]), [.noValue], #line),
      (draft([:], device: nil, fasting: nil), [.deviceModelMissing, .fastingMissing, .noValue], #line),
    ]
    for (input, issues, line) in cases {
      let result = BodyCompositionValidator.validate(input, now: now)
      XCTAssertEqual(result.issues, issues, line: line)
      XCTAssertFalse(result.canSave, line: line)
      XCTAssertNil(result.entry, line: line)
    }
  }

  func testMeasuredAtUpToFiveMinutesAheadIsAccepted() {
    let edge = BodyCompositionValidator.validate(draft([.weightKg: "62.4"], measuredAt: now.addingTimeInterval(300)), now: now)
    XCTAssertTrue(edge.canSave)
    let yesterday = seoul("2026-12-06T19:30:00+09:00")
    let past = BodyCompositionValidator.validate(draft([.weightKg: "62.4"], measuredAt: yesterday), now: now)
    XCTAssertEqual(past.entry?.measuredAt, yesterday, "measuredAt is the measurement time, not the save time")
    XCTAssertEqual(past.entry?.timeOfDayBand, .evening)
  }

  func testUnknownFastingIsSavable() {
    XCTAssertEqual(BodyCompositionValidator.validate(draft([.weightKg: "62.4"], fasting: .unknown), now: now).entry?.fasting,
                   .unknown)
  }

  func testDeviceModelIsNormalizedAndLimitedAsTheRulesCount() {
    XCTAssertEqual(DeviceModelName.normalize("  InBody\t 570  "), "InBody 570")
    XCTAssertEqual(DeviceModelName.normalize("inbody 570"), "inbody 570", "case is kept (ASM-09-13)")
    XCTAssertEqual(BodyCompositionValidator.validate(draft([.weightKg: "62"], device: " InBody   570 "), now: now)
      .entry?.deviceModel, "InBody 570")
    XCTAssertTrue(BodyCompositionValidator.validate(draft([.weightKg: "62"], device: String(repeating: "a", count: 64)), now: now)
      .canSave)
    XCTAssertEqual(BodyCompositionValidator.validate(draft([.weightKg: "62"], device: String(repeating: "a", count: 65)), now: now)
      .issues, [.deviceModelTooLong])
    // 33 emoji are 66 UTF-16 units: the rules' size() would refuse it.
    XCTAssertEqual(BodyCompositionValidator.validate(draft([.weightKg: "62"], device: String(repeating: "😀", count: 33)), now: now)
      .issues, [.deviceModelTooLong])
    XCTAssertTrue(BodyCompositionValidator.validate(draft([.weightKg: "62"], device: String(repeating: "가", count: 64)), now: now)
      .canSave)
  }

  // MARK: Validator: values (TC-127-07, TC-127-08)

  func testRangesAndNumbers() {
    func issue(_ key: BodyCompositionKey, _ min: Double, _ max: Double, _ unit: MetricUnit) -> BodyCompositionIssue {
      .outOfRange(.value(key), InputRange(min: min, max: max, unit: unit))
    }
    let cases: [(BodyCompositionKey, String, BodyCompositionIssue?, UInt)] = [
      (.bodyFatPercent, "120", issue(.bodyFatPercent, 0, 100, .percent), #line),
      (.bodyFatPercent, "0", nil, #line),  // R-27
      (.bodyFatPercent, "100", nil, #line),
      (.bodyFatPercent, "100.1", issue(.bodyFatPercent, 0, 100, .percent), #line),
      (.weightKg, "0", issue(.weightKg, 0.1, 600, .kg), #line),
      (.weightKg, "0.1", nil, #line),
      (.weightKg, "600", nil, #line),
      (.weightKg, "600.1", issue(.weightKg, 0.1, 600, .kg), #line),
      (.skeletalMuscleMassKg, "300.1", issue(.skeletalMuscleMassKg, 0.1, 300, .kg), #line),
      (.bodyFatMassKg, "0", issue(.bodyFatMassKg, 0.1, 600, .kg), #line),
      (.visceralFatLevel, "0.5", issue(.visceralFatLevel, 1, 100, .level), #line),
      (.visceralFatLevel, "1", nil, #line),
      (.visceralFatLevel, "12,5", nil, #line),
      (.totalBodyWaterL, "0", issue(.totalBodyWaterL, 0.1, 300, .liter), #line),
      (.totalBodyWaterL, "35.2", nil, #line),
      (.weightKg, "62.45", .notANumber(.value(.weightKg)), #line),
      (.weightKg, "-3", .notANumber(.value(.weightKg)), #line),
      (.weightKg, "6e1", .notANumber(.value(.weightKg)), #line),
      (.weightKg, "1,234.5", .notANumber(.value(.weightKg)), #line),
      (.weightKg, "62kg", .notANumber(.value(.weightKg)), #line),
    ]
    for (key, text, expected, line) in cases {
      let result = BodyCompositionValidator.validate(draft([key: text]), now: now)
      XCTAssertEqual(result.issues, expected.map { [$0] } ?? [], "\(key) \(text)", line: line)
      XCTAssertEqual(result.canSave, expected == nil, line: line)
      if expected == nil { XCTAssertNotNil(result.entry?.values[key], line: line) }
    }
  }

  func testAnInvalidFieldIsNotReportedAsNoValue() {
    let result = BodyCompositionValidator.validate(draft([.weightKg: "abc"]), now: now)
    XCTAssertEqual(result.issues, [.notANumber(.value(.weightKg))])
  }

  func testOnlyEnteredKeysAreKept() throws {
    let result = BodyCompositionValidator.validate(
      draft([.weightKg: "62,4", .bodyFatPercent: "24.1", .skeletalMuscleMassKg: "", .visceralFatLevel: "  "]), now: now)
    XCTAssertEqual(try XCTUnwrap(result.entry).values, [.weightKg: 62.4, .bodyFatPercent: 24.1])
    XCTAssertEqual(result.parsedValues, [.weightKg: 62.4, .bodyFatPercent: 24.1])
  }

  func testRangeIssueCarriesTheCopyArguments() {
    let issue = BodyCompositionIssue.outOfRange(.value(.bodyFatPercent), InputRange(min: 0, max: 100, unit: .percent))
    XCTAssertEqual(issue.copyKey, "tr11.range.generic")
    XCTAssertEqual(issue.severity, .error)
    XCTAssertEqual(issue.field, .value(.bodyFatPercent))
    XCTAssertEqual(issue.range?.minText, "0")
    XCTAssertEqual(issue.range?.maxText, "100")
    XCTAssertEqual(issue.range?.unitCopyKey, "unit.percent")
    XCTAssertEqual(InputRange(min: 0.1, max: 600, unit: .kg).minText, "0.1")
  }

  // MARK: Validator: height and BMI (AC-DF-127.5)

  func testHeightDerivesBMIOnlyWithWeight() throws {
    let measured = seoul("2026-12-07T08:40:00+09:00")
    let withHeight = BodyCompositionValidator.validate(draft([.weightKg: "62.4"], height: "165"), now: now)
    XCTAssertEqual(try XCTUnwrap(withHeight.entry).derived,
                   DerivedBMI(bmi: 22.9, heightCmUsed: 165, heightMeasuredAt: measured))
    XCTAssertEqual(withHeight.bmi, 22.9)

    let earlier = seoul("2026-11-23T10:00:00+09:00")
    let carried = BodyCompositionValidator.validate(draft([.weightKg: "62.4"], height: "165,0", heightMeasuredAt: earlier),
                                                    now: now)
    XCTAssertEqual(carried.entry?.derived?.heightMeasuredAt, earlier)

    let noWeight = BodyCompositionValidator.validate(draft([.bodyFatPercent: "24.1"], height: "165"), now: now)
    XCTAssertTrue(noWeight.canSave)
    XCTAssertNil(noWeight.entry?.derived)
    XCTAssertNil(noWeight.bmi)

    for blank in [nil, "", "  "] as [String?] {
      let result = BodyCompositionValidator.validate(draft([.weightKg: "62.4"], height: blank), now: now)
      XCTAssertTrue(result.canSave)
      XCTAssertNil(result.entry?.derived)
    }
  }

  func testBadHeightBlocksSaving() {
    XCTAssertEqual(BodyCompositionValidator.validate(draft([.weightKg: "62.4"], height: "99.9"), now: now).issues,
                   [.outOfRange(.height, InputRange(min: 100, max: 250, unit: .cm))])
    XCTAssertEqual(BodyCompositionValidator.validate(draft([.weightKg: "62.4"], height: "165.25"), now: now).issues,
                   [.notANumber(.height)])
    XCTAssertEqual(BodyCompositionValidator.validate(draft([.weightKg: "62.4"], height: "키"), now: now).issues,
                   [.notANumber(.height)])
  }

  func testBMIIsShownWhileOtherFieldsAreIncomplete() {
    let result = BodyCompositionValidator.validate(draft([.weightKg: "62.4"], fasting: nil, height: "165"), now: now)
    XCTAssertFalse(result.canSave)
    XCTAssertEqual(result.bmi, 22.9)
    XCTAssertEqual(result.timeOfDayBand, .morning)
  }

  // MARK: Validator: cross warnings (TC-127-09)

  func testCrossWarningsDoNotBlockSaving() {
    let cases: [([BodyCompositionKey: String], [BodyCompositionIssue], UInt)] = [
      ([.weightKg: "60", .bodyFatMassKg: "61"], [.fatMassOverWeight], #line),  // BC-11
      ([.weightKg: "60", .bodyFatMassKg: "60"], [], #line),
      ([.weightKg: "60", .skeletalMuscleMassKg: "60"], [.muscleOverWeight], #line),
      ([.weightKg: "60", .skeletalMuscleMassKg: "59.9"], [], #line),
      ([.weightKg: "80", .bodyFatMassKg: "20", .bodyFatPercent: "30"], [], #line),  // |30 - 25| = 5.0, not > 5.0
      ([.weightKg: "80", .bodyFatMassKg: "20", .bodyFatPercent: "30.1"], [.fatPercentMismatch], #line),
      ([.weightKg: "80", .bodyFatMassKg: "20", .bodyFatPercent: "19.9"], [.fatPercentMismatch], #line),
      ([.weightKg: "70", .bodyFatMassKg: "20", .bodyFatPercent: "25"], [], #line),  // 3.57%p (ASM-P1a-13: 5.0)
      ([.weightKg: "70", .bodyFatMassKg: "17.6", .bodyFatPercent: "25"], [], #line),  // BC-13
      ([.bodyFatMassKg: "20", .bodyFatPercent: "80"], [], #line),  // no weight: nothing to compare
      ([.weightKg: "50", .bodyFatMassKg: "55", .skeletalMuscleMassKg: "50", .bodyFatPercent: "10"],
       [.fatMassOverWeight, .muscleOverWeight, .fatPercentMismatch], #line),
    ]
    for (values, warnings, line) in cases {
      let result = BodyCompositionValidator.validate(draft(values), now: now)
      XCTAssertEqual(result.issues, warnings, line: line)
      XCTAssertEqual(result.warnings, warnings, line: line)
      XCTAssertEqual(result.errors, [], line: line)
      XCTAssertTrue(result.canSave, line: line)
      XCTAssertEqual(result.entry?.warnings, warnings, line: line)
    }
    XCTAssertEqual(BodyCompositionValidator.fatPercentMismatchThreshold, 5.0)
  }

  func testOutOfRangeValuesDoNotFeedWarnings() {
    let result = BodyCompositionValidator.validate(draft([.weightKg: "60", .bodyFatMassKg: "601"]), now: now)
    XCTAssertEqual(result.issues, [.outOfRange(.value(.bodyFatMassKg), InputRange(min: 0.1, max: 600, unit: .kg))])
  }

  func testIssueOrderIsStable() {
    let result = BodyCompositionValidator.validate(
      draft([.weightKg: "50", .bodyFatPercent: "abc", .bodyFatMassKg: "55"], device: nil, fasting: nil, height: "300"),
      now: now)
    XCTAssertEqual(result.issues, [
      .deviceModelMissing, .fastingMissing, .notANumber(.value(.bodyFatPercent)),
      .outOfRange(.height, InputRange(min: 100, max: 250, unit: .cm)), .fatMassOverWeight,
    ])
    XCTAssertEqual(result.errors.count, 4)
    XCTAssertEqual(result.warnings, [.fatMassOverWeight])
  }

  // MARK: Copy keys

  /// Every key an issue, a band or a fasting choice returns is in the Korean copy deck (the canonical copy).
  func testEveryCopyKeyIsInTheDeck() throws {
    let url = FixtureLoader.repositoryRoot.appendingPathComponent("docs/v1/data/copy_ko.json")
    let deck = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    let strings = try XCTUnwrap(deck["strings"] as? [String: Any])
    let range = InputRange(min: 0, max: 1, unit: .kg)
    var keys: [String] = [
      BodyCompositionIssue.deviceModelMissing, .deviceModelTooLong, .measuredAtInFuture, .fastingMissing, .noValue,
      .notANumber(.height), .outOfRange(.height, range), .fatMassOverWeight, .muscleOverWeight, .fatPercentMismatch,
    ].map(\.copyKey)
    keys += BodyCompositionKey.allCases.map(\.nameCopyKey)
    keys += TimeOfDayBand.allCases.map(\.copyKey) + Fasting.allCases.map(\.copyKey)
    keys += MetricUnit.allCases.filter { $0 != .deg && $0 != .point && $0 != .grade }
      .map { InputRange(min: 0, max: 1, unit: $0).unitCopyKey }
    keys += [BodyCompositionCopy.consentNeeded, BodyCompositionCopy.unmeasured, BodyCompositionCopy.bmiName,
             BodyCompositionCopy.deviceChanged]
    keys += BreakReason.allCases.map { SeriesBreak(reason: $0, detail: .condition(key: "fasting")).copyKey }
    keys += ["fasting", "timeOfDayBand", "view", "clothing", "stationProfile"]
      .compactMap { BreakDetail.condition(key: $0).conditionCopyKey }
    keys += [SeriesChartRejection.mixedSource.copyKey]
    keys += [ConsentChipState.coreGranted, .needed, .awaiting].map(\.copyKey)
    for key in keys { XCTAssertNotNil(strings[key], key) }
  }
}
