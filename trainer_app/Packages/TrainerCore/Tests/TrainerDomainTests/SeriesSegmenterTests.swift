import Foundation
import TrainerContracts
import XCTest
@testable import TrainerDomain

/// DF-128 (AC-DF-128.6, TC-128-06) with the DF-216 API, and the DF-130 chart input rules (AC-DF-130.1, .2, .3).
/// V1-09 §8. Synthetic values only.
final class SeriesSegmenterTests: XCTestCase {
  private func at(_ text: String) -> Date { FixtureTimestamp.parse(text)! }

  private func bc(
    _ refId: String, _ date: String, value: Double = 25, metric: MetricCode = .bodyFatPercent, grade: SourceGrade = .device,
    device: String? = "InBody 570", fasting: String? = "yes", band: String? = "morning", source: String? = "manualEntry"
  ) -> SeriesPoint {
    SeriesPoint(
      refId: refId, metricCode: metric, sourceGrade: grade, side: .none, value: value, unit: "percent",
      measuredAt: at(date), family: .bodyComposition,
      conditions: ConditionSnapshot(deviceKey: device, fasting: fasting, timeOfDayBand: band, source: source))
  }

  private func tape(
    _ refId: String, _ date: String, metric: MetricCode = .waistCircumference, side: Side = .none,
    grade: SourceGrade = .tape, protocolId: String? = "waistMidpoint", protocolVersion: String? = "circ-v1"
  ) -> SeriesPoint {
    SeriesPoint(
      refId: refId, metricCode: metric, sourceGrade: grade, side: side, value: 78.4, unit: "cm", measuredAt: at(date),
      family: grade == .observedSection ? .lidar : .tape,
      conditions: ConditionSnapshot(protocolVersion: protocolVersion, protocolId: protocolId))
  }

  private func refIds(_ segments: [SeriesSegment]) -> [[String]] { segments.map { $0.points.map(\.refId) } }

  private func onlySeries(_ result: [SeriesIdentity: [SeriesSegment]], file: StaticString = #filePath, line: UInt = #line)
    throws -> [SeriesSegment]
  {
    XCTAssertEqual(result.count, 1, file: file, line: line)
    return try XCTUnwrap(result.values.first, file: file, line: line)
  }

  // MARK: Body composition

  /// AC-DF-216.1 / SB-01, AC-DF-128.6.
  func testDeviceChangeStartsANewSegment() throws {
    let segments = try onlySeries(SeriesSegmenter.segment([
      bc("SYNTHbc01", "2027-01-04T07:30:00+09:00", value: 25.0),
      bc("SYNTHbc02", "2027-02-03T07:40:00+09:00", value: 24.6),
      bc("SYNTHbc03", "2027-02-05T07:35:00+09:00", value: 22.0, device: "InBody 270"),
    ]))
    XCTAssertEqual(refIds(segments), [["SYNTHbc01", "SYNTHbc02"], ["SYNTHbc03"]])
    XCTAssertNil(segments[0].breakBefore)
    XCTAssertEqual(segments[1].breakBefore, SeriesBreak(reason: .deviceChanged,
                                                         detail: .device(from: "InBody 570", to: "InBody 270")))
    XCTAssertEqual(segments[1].breakBefore?.copyKey, "series.break.device")
  }

  /// SB-16: the comparison is with the point just before.
  func testDeviceABAMakesThreeSegments() throws {
    let segments = try onlySeries(SeriesSegmenter.segment([
      bc("a", "2027-01-01T08:00:00+09:00"), bc("b", "2027-01-08T08:00:00+09:00", device: "InBody 270"),
      bc("c", "2027-01-15T08:00:00+09:00"),
    ]))
    XCTAssertEqual(refIds(segments), [["a"], ["b"], ["c"]])
    XCTAssertEqual(segments.compactMap(\.breakBefore?.reason), [.deviceChanged, .deviceChanged])
  }

  /// AC-DF-216.2 / SB-02: `unknown` never matches, even itself. A missing value counts as unknown.
  func testConditionMismatches() throws {
    let cases: [([SeriesPoint], [[String]], SeriesBreak?, UInt)] = [
      ([bc("a", "2027-01-01T08:00:00+09:00", fasting: "unknown"), bc("b", "2027-01-08T08:00:00+09:00", fasting: "unknown")],
       [["a"], ["b"]], SeriesBreak(reason: .conditionMismatch, detail: .condition(key: "fasting")), #line),
      ([bc("a", "2027-01-01T08:00:00+09:00", fasting: "yes"), bc("b", "2027-01-08T08:00:00+09:00", fasting: "no")],
       [["a"], ["b"]], SeriesBreak(reason: .conditionMismatch, detail: .condition(key: "fasting")), #line),
      ([bc("a", "2027-01-01T08:00:00+09:00", fasting: nil), bc("b", "2027-01-08T08:00:00+09:00", fasting: nil)],
       [["a"], ["b"]], SeriesBreak(reason: .conditionMismatch, detail: .condition(key: "fasting")), #line),
      // SB-13
      ([bc("a", "2027-01-01T08:00:00+09:00", band: "morning"), bc("b", "2027-01-08T12:00:00+09:00", band: "midday")],
       [["a"], ["b"]], SeriesBreak(reason: .conditionMismatch, detail: .condition(key: "timeOfDayBand")), #line),
      // device wins over the condition (§7.5 order)
      ([bc("a", "2027-01-01T08:00:00+09:00"), bc("b", "2027-01-08T12:00:00+09:00", device: "X", fasting: "no")],
       [["a"], ["b"]], SeriesBreak(reason: .deviceChanged, detail: .device(from: "InBody 570", to: "X")), #line),
      ([bc("a", "2027-01-01T08:00:00+09:00"), bc("b", "2027-01-08T08:00:00+09:00")], [["a", "b"]], nil, #line),
    ]
    for (points, expected, br, line) in cases {
      let segments = try onlySeries(SeriesSegmenter.segment(points), line: line)
      XCTAssertEqual(refIds(segments), expected, line: line)
      XCTAssertEqual(segments.last?.breakBefore, br, line: line)
    }
    XCTAssertEqual(SeriesBreak(reason: .conditionMismatch, detail: .condition(key: "fasting")).copyKey, "series.break.condition")
    XCTAssertEqual(BreakDetail.condition(key: "fasting").conditionCopyKey, "condition.fasting")
    XCTAssertEqual(BreakDetail.condition(key: "timeOfDayBand").conditionCopyKey, "condition.timeOfDayBand")
    XCTAssertEqual(BreakDetail.condition(key: "stationProfile").conditionCopyKey, "condition.station")
    XCTAssertNil(BreakDetail.device(from: "a", to: "b").conditionCopyKey)
  }

  /// SB-14: input order does not matter; ties on measuredAt are ordered by refId.
  func testInputOrderDoesNotMatter() throws {
    let points = [
      bc("c", "2027-01-15T08:00:00+09:00"), bc("a", "2027-01-01T08:00:00+09:00"), bc("b2", "2027-01-08T08:00:00+09:00"),
      bc("b1", "2027-01-08T08:00:00+09:00"),
    ]
    let forward = try onlySeries(SeriesSegmenter.segment(points))
    let backward = try onlySeries(SeriesSegmenter.segment(points.reversed()))
    XCTAssertEqual(refIds(forward), [["a", "b1", "b2", "c"]])
    XCTAssertEqual(forward, backward)
  }

  /// AC-DF-216.6 / C-04: nothing is added. Every output point is an input point with the same date and value.
  func testNoInterpolation() throws {
    let points = [
      bc("d1", "2027-01-01T08:00:00+09:00", value: 25), bc("d2", "2027-01-02T08:00:00+09:00", value: 24),
      bc("d10", "2027-01-10T08:00:00+09:00", value: 20),
    ]
    let segments = try onlySeries(SeriesSegmenter.segment(points))
    XCTAssertEqual(segments.flatMap(\.points), points)
    XCTAssertEqual(SeriesSegmenter.segment([]), [:])
  }

  func testSegmentIDsAreUniqueAndStable() throws {
    let points = [
      bc("a", "2027-01-01T08:00:00+09:00"), bc("b", "2027-01-08T08:00:00+09:00", device: "X"),
      bc("c", "2027-01-15T08:00:00+09:00"),
    ]
    let ids = try onlySeries(SeriesSegmenter.segment(points)).map(\.id)
    XCTAssertEqual(Set(ids).count, 3)
    XCTAssertEqual(ids, try onlySeries(SeriesSegmenter.segment(points)).map(\.id))
    XCTAssertEqual(ids.first, "bodyFatPercent|device|none|manualEntry#0")
  }

  /// `source` separates body composition series (V1-09 §8.3).
  func testSourceIsPartOfTheBodyCompositionIdentity() {
    let result = SeriesSegmenter.segment([
      bc("a", "2027-01-01T08:00:00+09:00"), bc("b", "2027-01-08T08:00:00+09:00", source: "inbodyApi"),
    ])
    XCTAssertEqual(result.count, 2)
    XCTAssertEqual(SeriesSegmenter.identity(of: bc("a", "2027-01-01T08:00:00+09:00")),
                   SeriesIdentity(metricCode: .bodyFatPercent, sourceGrade: .device, side: .none, source: "manualEntry"))
  }

  // MARK: Tape, observed section, pain

  /// SB-08: a tape protocol change breaks with `protocolChanged`.
  func testTapeProtocolChange() throws {
    let segments = try onlySeries(SeriesSegmenter.segment([
      tape("a", "2027-01-01T08:00:00+09:00"), tape("b", "2027-01-08T08:00:00+09:00", protocolId: "custom"),
    ]))
    XCTAssertEqual(refIds(segments), [["a"], ["b"]])
    XCTAssertEqual(segments[1].breakBefore,
                   SeriesBreak(reason: .protocolChanged, detail: .protocolVersion(from: "waistMidpoint", to: "custom")))
    XCTAssertEqual(segments[1].breakBefore?.copyKey, "series.break.protocol")
  }

  /// SB-09 / AC-C-02.1: tape and observed section never share a series. SB-10: left and right are separate series.
  func testGradesAndSidesAreSeparateSeries() {
    let result = SeriesSegmenter.segment([
      tape("t1", "2027-01-01T08:00:00+09:00", metric: .thighCircumference, side: .left, protocolId: "custom"),
      tape("t2", "2027-01-01T08:00:00+09:00", metric: .thighCircumference, side: .right, protocolId: "custom"),
      tape("t3", "2027-01-08T08:00:00+09:00", metric: .thighCircumference, side: .left, protocolId: "custom"),
      tape("w1", "2027-01-01T08:00:00+09:00"),
    ])
    XCTAssertEqual(result.count, 3)
    let left = SeriesIdentity(metricCode: .thighCircumference, sourceGrade: .tape, side: .left, source: nil)
    XCTAssertEqual(result[left].map(refIds), [["t1", "t3"]])
    XCTAssertEqual(SeriesSegmenter.identity(of: tape("w", "2027-01-01T08:00:00+09:00", side: .left)).side, .none,
                   "waist has no side series")
  }

  /// SB-11: pain has no condition keys, so nothing breaks it.
  func testPainNeverBreaks() throws {
    func pain(_ id: String, _ date: String, device: String) -> SeriesPoint {
      SeriesPoint(refId: id, metricCode: .painNrs, sourceGrade: .selfReport, side: .none, value: 3, unit: "point",
                  measuredAt: at(date), family: .pain, conditions: ConditionSnapshot(deviceKey: device, fasting: "unknown"))
    }
    let segments = try onlySeries(SeriesSegmenter.segment([
      pain("a", "2027-01-01T08:00:00+09:00", device: "x"), pain("b", "2027-01-08T08:00:00+09:00", device: "y"),
    ]))
    XCTAssertEqual(refIds(segments), [["a", "b"]])
  }

  /// DF-128: posture and LiDAR series arrive with DF-216; until then their points give no series.
  func testPostureAndLidarPointsAreNotSegmentedYet() {
    let posture = SeriesPoint(
      refId: "p", metricCode: .craniovertebralAngle, sourceGrade: .photoManual, side: .none, value: 50, unit: "deg",
      measuredAt: at("2027-01-01T08:00:00+09:00"), family: .posture, conditions: ConditionSnapshot())
    let lidar = tape("l", "2027-01-01T08:00:00+09:00", grade: .observedSection)
    XCTAssertEqual(SeriesSegmenter.segment([posture, lidar]), [:])
    XCTAssertEqual(SeriesSegmenter.segment([posture, bc("a", "2027-01-01T08:00:00+09:00")]).count, 1)
  }

  // MARK: compare (V1-09 §8.2)

  func testCompareOrderAndStationTolerance() {
    // AC-DF-216.3: protocol and device change together → protocol only.
    let a = ConditionSnapshot(protocolVersion: "posture-v2", view: "front", clothing: "fitted", cameraHeightCm: 100,
                              cameraDistanceM: 3, deviceKey: "iPad B")
    let b = ConditionSnapshot(protocolVersion: "posture-v1", view: "front", clothing: "fitted", cameraHeightCm: 100,
                              cameraDistanceM: 3, deviceKey: "iPad A")
    XCTAssertEqual(SeriesSegmenter.compare(a, b, family: .posture),
                   SeriesBreak(reason: .protocolChanged, detail: .protocolVersion(from: "posture-v1", to: "posture-v2")))
    var same = b
    same.cameraHeightCm = 98
    var moved = b
    moved.cameraHeightCm = 104
    XCTAssertNil(SeriesSegmenter.compare(moved, same, family: .posture), "AC-DF-216.4: both inside 90~110")
    moved.cameraHeightCm = 115
    XCTAssertEqual(SeriesSegmenter.compare(moved, same, family: .posture),
                   SeriesBreak(reason: .conditionMismatch, detail: .condition(key: "stationProfile")))
    var side = b
    side.view = "sagittalRight"
    var sideBefore = b
    sideBefore.view = "sagittalLeft"
    XCTAssertEqual(SeriesSegmenter.compare(side, sideBefore, family: .posture),
                   SeriesBreak(reason: .conditionMismatch, detail: .condition(key: "view")))
    var clothing = b
    clothing.clothing = "regular"
    XCTAssertEqual(SeriesSegmenter.compare(clothing, b, family: .posture),
                   SeriesBreak(reason: .conditionMismatch, detail: .condition(key: "clothing")))
    // Only one side null is still different; both null for a protocol key are equal.
    XCTAssertEqual(SeriesSegmenter.compare(ConditionSnapshot(protocolVersion: "circ-v1", protocolId: "custom"),
                                           ConditionSnapshot(protocolVersion: nil, protocolId: "custom"), family: .tape),
                   SeriesBreak(reason: .protocolChanged, detail: .protocolVersion(from: "", to: "circ-v1")))
    XCTAssertNil(SeriesSegmenter.compare(ConditionSnapshot(), ConditionSnapshot(), family: .tape))
    // LiDAR: algorithm version is a protocol key; the device is compared too.
    XCTAssertEqual(SeriesSegmenter.compare(ConditionSnapshot(algorithmVersion: "2", deviceKey: "x"),
                                           ConditionSnapshot(algorithmVersion: "1", deviceKey: "y"), family: .lidar)?.reason,
                   .protocolChanged)
    XCTAssertEqual(SeriesSegmenter.compare(ConditionSnapshot(deviceKey: "x"), ConditionSnapshot(deviceKey: "y"),
                                           family: .lidar)?.reason, .deviceChanged)
  }

  /// SB-15: a tilt metric's side says which side is higher, so it is not a separate series.
  func testTiltSideIsNotASeries() {
    func tilt(_ side: Side) -> SeriesPoint {
      SeriesPoint(refId: "t", metricCode: .shoulderTiltAngle, sourceGrade: .photoManual, side: side, value: 1, unit: "deg",
                  measuredAt: at("2027-01-01T08:00:00+09:00"), family: .posture, conditions: ConditionSnapshot())
    }
    XCTAssertEqual(SeriesSegmenter.identity(of: tilt(.left)), SeriesSegmenter.identity(of: tilt(.right)))
    XCTAssertEqual(SeriesSegmenter.identity(of: tilt(.left)).side, .none)
  }

  // MARK: Body composition records → points (AC-DF-130.1, AC-DF-130.11)

  private func record(
    _ id: String, _ date: String, status: MeasurementStatus? = .active, grade: SourceGrade? = .device,
    values: [BodyCompositionKey: Double] = [.weightKg: 62.4, .bodyFatPercent: 24.1], device: String = "InBody 570",
    derived: DerivedBMI? = nil
  ) -> BodyCompositionRecord {
    BodyCompositionRecord(
      id: id, member: .uid("u"), deviceModel: device, measuredAt: at(date), fasting: .yes, timeOfDayBand: .morning,
      source: "manualEntry", sourceGrade: grade, values: values, derived: derived, status: status)
  }

  func testRecordsBecomePointsWithoutVoidedOrGradelessRecords() {
    let records = [
      record("r1", "2027-01-01T08:00:00+09:00"),
      record("r2", "2027-01-08T08:00:00+09:00", status: .voided),
      record("r3", "2027-01-15T08:00:00+09:00", grade: nil),
      record("r4", "2027-01-22T08:00:00+09:00", values: [.bodyFatPercent: 23]),
      record("r5", "2027-01-29T08:00:00+09:00", status: nil),
      record("r6", "2027-02-05T08:00:00+09:00", device: "  InBody   570 "),
    ]
    let points = BodyCompositionSeries.points(from: records, metricCode: .weightKg)
    XCTAssertEqual(points.map(\.refId), ["r1", "r6"])
    let first = points[0]
    XCTAssertEqual(first.value, 62.4)
    XCTAssertEqual(first.unit, "kg")
    XCTAssertEqual(first.sourceGrade, .device)
    XCTAssertEqual(first.family, .bodyComposition)
    XCTAssertEqual(first.side, .none)
    XCTAssertEqual(first.conditions, ConditionSnapshot(deviceKey: "InBody 570", fasting: "yes", timeOfDayBand: "morning",
                                                       source: "manualEntry"))
    XCTAssertEqual(points[1].conditions.deviceKey, "InBody 570", "normalized, so no false device break")
    XCTAssertEqual(BodyCompositionSeries.points(from: records, metricCode: .bodyFatPercent).map(\.refId), ["r1", "r4", "r6"])
    XCTAssertEqual(BodyCompositionSeries.points(from: records, metricCode: .waistCircumference), [])
  }

  func testBMIPointsComeFromDerived() {
    let derived = DerivedBMI(bmi: 22.9, heightCmUsed: 165, heightMeasuredAt: at("2027-01-01T08:00:00+09:00"))
    let points = BodyCompositionSeries.points(
      from: [record("r1", "2027-01-01T08:00:00+09:00", derived: derived), record("r2", "2027-01-08T08:00:00+09:00")],
      metricCode: .bmi)
    XCTAssertEqual(points.map(\.refId), ["r1"])
    XCTAssertEqual(points.first?.sourceGrade, .derived)
    XCTAssertEqual(points.first?.unit, "kgPerM2")
  }

  /// Form defaults and the device-change notice (V1-09 §10.3, §10.6).
  func testLatestActiveAndDeviceChange() {
    let records = [
      record("a", "2027-01-01T08:00:00+09:00"),
      record("b", "2027-01-05T08:00:00+09:00", status: .voided, device: "InBody 270"),
      record("c", "2027-01-10T08:00:00+09:00"),
    ]
    XCTAssertEqual(BodyCompositionSeries.latestActive(records)?.id, "c")
    XCTAssertEqual(BodyCompositionSeries.latestActive(records, before: at("2027-01-10T08:00:00+09:00"))?.id, "a")
    XCTAssertNil(BodyCompositionSeries.latestActive(records, before: at("2027-01-01T08:00:00+09:00")))
    func changed(_ device: String?, _ date: String) -> Bool {
      BodyCompositionSeries.deviceChanged(records, deviceModel: device, measuredAt: at(date))
    }
    XCTAssertTrue(changed("InBody 270", "2027-01-12T08:00:00+09:00"))
    XCTAssertFalse(changed(" InBody  570 ", "2027-01-12T08:00:00+09:00"))
    XCTAssertTrue(changed("InBody 270", "2027-01-03T08:00:00+09:00"), "compares with the record just before")
    XCTAssertFalse(changed("InBody 270", "2026-12-31T08:00:00+09:00"), "no earlier record")
    XCTAssertFalse(changed(nil, "2027-01-12T08:00:00+09:00"))
    XCTAssertFalse(changed("InBody 570", "2027-01-07T08:00:00+09:00"), "the voided InBody 270 record does not count")
  }

  // MARK: Chart input (AC-DF-130.2)

  func testMixedGradesAreRejected() {
    let input = SeriesChartInput.make([
      tape("t", "2027-01-01T08:00:00+09:00"), tape("o", "2027-01-08T08:00:00+09:00", grade: .observedSection),
    ])
    XCTAssertEqual(input, .rejected(.mixedSource))
    XCTAssertEqual(SeriesChartRejection.mixedSource.copyKey, "chart.rejected.mixedSource")
    XCTAssertEqual(SeriesChartInput.make([]), .empty)
  }

  func testSingleGradeIsReadyWithLinesInSideOrder() throws {
    let input = SeriesChartInput.make([
      tape("r", "2027-01-01T08:00:00+09:00", metric: .thighCircumference, side: .right, protocolId: "custom"),
      tape("l", "2027-01-01T08:00:00+09:00", metric: .thighCircumference, side: .left, protocolId: "custom"),
    ])
    guard case let .ready(grade, lines) = input else { return XCTFail("ready expected, got \(input)") }
    XCTAssertEqual(grade, .tape)
    XCTAssertEqual(lines.map(\.identity.side), [.left, .right])
    XCTAssertEqual(lines.map { $0.segments.flatMap(\.points).map(\.refId) }, [["l"], ["r"]])
    XCTAssertEqual(lines.map(\.breakCount), [0, 0])
  }

  func testReadyChartCountsBreaks() throws {
    let input = SeriesChartInput.make([
      bc("a", "2027-01-01T08:00:00+09:00"), bc("b", "2027-01-08T08:00:00+09:00", device: "X"),
      bc("c", "2027-01-15T08:00:00+09:00", device: "X"),
    ])
    guard case let .ready(grade, lines) = input else { return XCTFail("ready expected") }
    XCTAssertEqual(grade, .device)
    XCTAssertEqual(lines.count, 1)
    XCTAssertEqual(lines[0].breakCount, 1)
    XCTAssertEqual(lines[0].pointCount, 3)
  }

  /// AC-DF-216.8: the display rule module holds no change-judgement vocabulary (ADR-009).
  func testSeriesSourcesHoldNoJudgementTerms() throws {
    let dir = FixtureLoader.repositoryRoot
      .appendingPathComponent("trainer_app/Packages/TrainerCore/Sources/TrainerDomain/Series", isDirectory: true)
    let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
      .filter { $0.pathExtension == "swift" }
    XCTAssertFalse(files.isEmpty)
    for file in files {
      let text = try String(contentsOf: file, encoding: .utf8)
      for term in ["mdc", "meaningfulImprovement", "meaningfulDecline", "withinError"] {
        XCTAssertNil(text.range(of: term, options: .caseInsensitive), "\(file.lastPathComponent): \(term)")
      }
    }
  }
}
