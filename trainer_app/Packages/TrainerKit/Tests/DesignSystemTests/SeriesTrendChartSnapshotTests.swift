import DesignSystem
import SnapshotTesting
import SwiftUI
import TrainerContracts
import XCTest

/// TC-130-02, 03, 04, 05, 09 (DF-130): the refused mixed-source chart; irregular dates (1, 2 and 10 January) with a
/// device change drawn as two unjoined segments, a dashed rule with its numbered marker and '기기 변경' under the plot,
/// and '산정 준비 중' without a band, light, dark, at xxxLarge and at the largest accessibility size; two close device
/// changes whose markers take two rows (DF-127 review findings 5, 6); twelve crowded breaks under three marker rows
/// above a full-height plot (DF-127 second review); left and right with a protocol break in greyscale (AC-A11Y-03); no
/// points and one point.
///
/// References follow `SyncStateBadgeSnapshotTests`: recorded on the CI runtime only (locally they skip, on CI a
/// missing reference is recorded and fails the run, and CI uploads it as the `snapshot-references` artifact).
@MainActor
final class SeriesTrendChartSnapshotTests: XCTestCase {
  private var recording = false
  private let seoul = TimeZone(identifier: "Asia/Seoul")!

  override func setUpWithError() throws {
    let environment = ProcessInfo.processInfo.environment
    recording = environment["SNAPSHOT_RECORD"] == "1"
    let version = ProcessInfo.processInfo.operatingSystemVersion
    let running = "\(version.majorVersion).\(version.minorVersion)"
    let reference = SyncStateBadgeSnapshotTests.referenceRuntime
    guard recording || running == reference else {
      let message = "snapshot references are for iOS \(reference); this runtime is iOS \(running)"
      if environment["CI"] == "1" { XCTFail(message + " (pin DFET_SIM_RUNTIME)") }
      throw XCTSkip(message)
    }
  }

  /// 2026-01-`day` 09:00 KST.
  private func day(_ day: Int) -> Date {
    Date(timeIntervalSince1970: 1_767_225_600 + Double(day - 1) * 86_400)
  }

  private func point(_ day: Int, _ value: Double, _ grade: SourceGrade) -> ChartPoint {
    ChartPoint(measuredAt: self.day(day), value: value, sourceGrade: grade)
  }

  private func snapshot(
    _ model: SeriesChartModel, named name: String, style: UIUserInterfaceStyle = .light,
    size: UIContentSizeCategory = .large, height: CGFloat = 380, greyscale: Bool = false,
    file: StaticString = #file, testName: String = #function, line: UInt = #line
  ) throws {
    let localize = try AppCatalog.localizer()
    let view = SeriesTrendChart(model: model, localize: localize, timeZone: seoul)
      .padding(TrainerSpacing.l)
      .frame(width: 560, height: height, alignment: .topLeading)
      .background(Color(uiColor: .systemBackground))
      .grayscale(greyscale ? 1 : 0)
    let traits = UITraitCollection(mutations: { traits in
      traits.userInterfaceStyle = style
      traits.preferredContentSizeCategory = size
    })
    assertSnapshot(
      of: view, as: .image(perceptualPrecision: 0.98, layout: .fixed(width: 560, height: height), traits: traits),
      named: name, record: recording, file: file, testName: testName, line: line)
  }

  func test_TC_130_02_mixedSourceIsRefused() throws {
    let waist = SeriesChartModel(metricCode: .waistCircumference, segments: [
      ChartSegment(id: "tape", points: [point(1, 80.2, .tape), point(5, 80.0, .tape)]),
      ChartSegment(id: "observed", points: [point(3, 81.5, .observedSection)]),
    ])
    try snapshot(waist, named: "mixedSource")
  }

  func test_TC_130_03_04_05_irregularDatesDeviceChangeAndPendingPolicy() throws {
    let weight = SeriesChartModel(metricCode: .weightKg, deviceModel: "SYN-B", segments: [
      ChartSegment(id: "weightKg#0", points: [point(1, 72.4, .device), point(2, 71.9, .device)]),
      ChartSegment(id: "weightKg#1", breakBefore: .deviceChanged(from: "SYN-A", to: "SYN-B"),
                   points: [point(10, 70.2, .device)]),
    ])
    try snapshot(weight, named: "deviceChange-light", height: 440)
    try snapshot(weight, named: "deviceChange-dark", style: .dark, height: 440)
    try snapshot(weight, named: "deviceChange-xxxl", size: .extraExtraExtraLarge, height: 520)
    try snapshot(weight, named: "deviceChange-ax5", size: .accessibilityExtraExtraExtraLarge, height: 760)
  }

  /// Review finding 5: a second device change three days after the first; both reasons stay readable.
  func testCloseDeviceChangesKeepBothReasonsReadable() throws {
    let weight = SeriesChartModel(metricCode: .weightKg, deviceModel: "SYN-C", segments: [
      ChartSegment(id: "weightKg#0", points: [point(1, 72.4, .device), point(2, 71.9, .device)]),
      ChartSegment(id: "weightKg#1", breakBefore: .deviceChanged(from: "SYN-A", to: "SYN-B"),
                   points: [point(28, 70.2, .device)]),
      ChartSegment(id: "weightKg#2", breakBefore: .deviceChanged(from: "SYN-B", to: "SYN-C"),
                   points: [point(31, 70.0, .device)]),
    ])
    try snapshot(weight, named: "closeBreaks", height: 500)
  }

  /// DF-127 second review: one record 350 days before twelve daily ones with fasting '모름', each a condition break.
  /// The plot keeps its full height; the markers take three rows, the last one numbering the run ('3~12').
  func testCrowdedBreaksKeepThePlot() throws {
    var segments = [ChartSegment(id: "weightKg#0", points: [point(1, 72.4, .device)])]
    for (index, day) in (340...351).enumerated() {
      segments.append(ChartSegment(id: "weightKg#\(index + 1)", breakBefore: .conditionMismatch(condition: "fasting"),
                                   points: [point(day, 71.8 - Double(index % 4) / 5, .device)]))
    }
    try snapshot(SeriesChartModel(metricCode: .weightKg, deviceModel: "SYN-A", segments: segments), named: "crowdedBreaks",
                 height: 1_000)
  }

  func test_TC_130_09_leftAndRightInGreyscale() throws {
    let thigh = SeriesChartModel(metricCode: .thighCircumference, segments: [
      ChartSegment(id: "L#0", side: .left, points: [point(1, 52.4, .tape), point(4, 52.1, .tape)]),
      ChartSegment(id: "L#1", side: .left, breakBefore: .protocolChanged, points: [point(9, 51.6, .tape),
                                                                                 point(12, 51.4, .tape)]),
      ChartSegment(id: "R#0", side: .right, points: [point(1, 53.3, .tape), point(4, 53.0, .tape)]),
      ChartSegment(id: "R#1", side: .right, breakBefore: .protocolChanged, points: [point(9, 52.7, .tape),
                                                                                  point(12, 52.9, .tape)]),
    ])
    try snapshot(thigh, named: "leftRight-greyscale", height: 440, greyscale: true)
  }

  /// No points: the empty message. One point: the point and '비교할 측정이 없습니다 · 판정 불가' (F-VIZ-03.10).
  func testEmptyAndSinglePoint() throws {
    try snapshot(SeriesChartModel(metricCode: .skeletalMuscleMassKg, segments: []), named: "empty")
    let single = SeriesChartModel(metricCode: .bodyFatPercent, deviceModel: "SYN-A", segments: [
      ChartSegment(id: "bodyFatPercent#0", points: [point(3, 21.4, .device)]),
    ])
    try snapshot(single, named: "singlePoint")
  }
}
