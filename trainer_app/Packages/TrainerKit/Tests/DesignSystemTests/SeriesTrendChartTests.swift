import Accessibility
@testable import DesignSystem
import SwiftUI
import TrainerContracts
import XCTest

/// TC-130-01, 02, 03, 06, 08, 10 (DF-130): what the chart draws, refuses and says. Synthetic values only.
@MainActor
final class SeriesTrendChartTests: XCTestCase {
  private let seoul = TimeZone(identifier: "Asia/Seoul")!

  /// 2026-01-`day` 09:00 KST.
  private func day(_ day: Int) -> Date {
    Date(timeIntervalSince1970: 1_767_225_600 + Double(day - 1) * 86_400)
  }

  private func point(_ day: Int, _ value: Double, _ grade: SourceGrade = .device) -> ChartPoint {
    ChartPoint(measuredAt: self.day(day), value: value, sourceGrade: grade)
  }

  /// AC-DF-130.4's case: device A twice, then device B once.
  private var deviceChange: SeriesChartModel {
    SeriesChartModel(metricCode: .weightKg, deviceModel: "SYN-B", segments: [
      ChartSegment(id: "weightKg#0", points: [point(1, 72.4), point(2, 71.9)]),
      ChartSegment(id: "weightKg#1", breakBefore: .deviceChanged(from: "SYN-A", to: "SYN-B"), points: [point(10, 70.2)]),
    ])
  }

  private func fittingSize(_ view: some View) -> CGSize {
    UIHostingController(rootView: view).sizeThatFits(in: CGSize(width: 600, height: 800))
  }

  /// AC-DF-130.1: a point always has a source grade (no optional to leave out), and every point given is drawn.
  func test_TC_130_01_everyPointHasASourceGrade() {
    let make: (Date, Double, SourceGrade) -> ChartPoint = ChartPoint.init
    XCTAssertEqual(make(day(1), 1, .tape).sourceGrade, .tape)
    XCTAssertEqual(deviceChange.points.count, 3)
    XCTAssertEqual(deviceChange.content, .chart(.device))
  }

  /// AC-DF-130.2 / C-02: two grades in one chart are refused, e.g. tape and observed-section waist.
  func test_TC_130_02_mixedSourceGradesAreRejected() throws {
    let localize = try AppCatalog.localizer()
    let waist = SeriesChartModel(metricCode: .waistCircumference, segments: [
      ChartSegment(id: "tape", points: [point(1, 80.2, .tape), point(5, 80.0, .tape)]),
      ChartSegment(id: "observed", points: [point(3, 81.5, .observedSection)]),
    ])
    XCTAssertEqual(waist.content, .rejectedMixedSource)
    XCTAssertNil(SeriesTrendChart.summary(waist, localize: localize, timeZone: seoul))
    XCTAssertEqual(localize("chart.rejected.mixedSource"), "출처가 다른 값은 한 차트에 그리지 않아요")
    // Mixed inside one segment is refused too.
    let oneSegment = SeriesChartModel(metricCode: .weightKg, segments: [
      ChartSegment(id: "s", points: [point(1, 70, .device), point(2, 70, .selfReport)]),
    ])
    XCTAssertEqual(oneSegment.content, .rejectedMixedSource)
    XCTAssertGreaterThan(fittingSize(SeriesTrendChart(model: waist, localize: localize)).height, 0, "the refusal is shown")
  }

  /// No points: an empty message, never a line at zero (C-04). A v2 metric or a grade v1 never shows: nothing.
  func testEmptyAndHiddenCharts() throws {
    let localize = try AppCatalog.localizer()
    let empty = SeriesChartModel(metricCode: .weightKg, segments: [ChartSegment(id: "s", points: [])])
    XCTAssertEqual(empty.content, .empty)
    XCTAssertEqual(localize("chart.empty"), "아직 추이로 볼 기록이 없어요")
    XCTAssertNil(SeriesTrendChart.summary(empty, localize: localize, timeZone: seoul))
    let v2 = SeriesChartModel(metricCode: .phaseAngleDeg, segments: [ChartSegment(id: "s", points: [point(1, 5)])])
    let hiddenGrade = SeriesChartModel(metricCode: .weightKg, segments: [
      ChartSegment(id: "s", points: [point(1, 70, .modelEstimate)]),
    ])
    for model in [v2, hiddenGrade] {
      XCTAssertEqual(model.content, .hidden)
      XCTAssertEqual(fittingSize(SeriesTrendChart(model: model, localize: localize)), .zero)
    }
  }

  /// AC-DF-130.3 / AC-DF-130.4: segments keep their own ids (one `LineMark` series each, never joined), and the
  /// break sits at the first point of the segment it starts, labelled with the deck's words.
  func test_TC_130_03_breaksSitAtTheFirstPointOfTheirSegment() throws {
    let localize = try AppCatalog.localizer()
    let model = deviceChange
    XCTAssertEqual(Set(model.segments.map(\.id)).count, model.segments.count)
    XCTAssertEqual(model.points.map(\.measuredAt), [day(1), day(2), day(10)], "dates as given, nothing filled in")
    XCTAssertEqual(model.breaks, [ChartBreakMark(at: day(10), reason: .deviceChanged(from: "SYN-A", to: "SYN-B"))])
    XCTAssertEqual(SeriesTrendChart.breakLabel(.deviceChanged(from: "SYN-A", to: "SYN-B"), localize: localize),
                   "기기 변경: SYN-A → SYN-B")
    XCTAssertEqual(SeriesTrendChart.breakLabel(.protocolChanged, localize: localize), "프로토콜 변경")
    XCTAssertEqual(SeriesTrendChart.breakLabel(.conditionMismatch(condition: "fasting"), localize: localize),
                   "조건 불일치: 공복 여부")
    for condition in ["fasting", "timeOfDayBand", "view", "clothing", "station", "side"] {
      _ = SeriesTrendChart.breakLabel(.conditionMismatch(condition: condition), localize: localize)  // in the catalog
    }
    // Left and right broken on the same day by one protocol change: one break, not two.
    let sides = SeriesChartModel(metricCode: .thighCircumference, segments: [
      ChartSegment(id: "L#0", side: .left, points: [point(1, 52.4, .tape)]),
      ChartSegment(id: "L#1", side: .left, breakBefore: .protocolChanged, points: [point(9, 52.0, .tape)]),
      ChartSegment(id: "R#0", side: .right, points: [point(1, 53.1, .tape)]),
      ChartSegment(id: "R#1", side: .right, breakBefore: .protocolChanged, points: [point(9, 52.8, .tape)]),
    ])
    XCTAssertEqual(sides.breaks.count, 1)
  }

  /// Review finding 5: every break has a numbered marker on its rule and a numbered reason under the plot, in date
  /// order; markers of breaks closer than about one marker width take separate rows, so their labels never draw over
  /// each other (a second device change 60 days after the first one used to overwrite the first label).
  func testCloseBreaksGetSeparateMarkerRows() {
    let model = SeriesChartModel(metricCode: .weightKg, deviceModel: "SYN-C", segments: [
      ChartSegment(id: "weightKg#0", points: [point(1, 72.4), point(2, 71.9)]),
      ChartSegment(id: "weightKg#2", breakBefore: .deviceChanged(from: "SYN-B", to: "SYN-C"), points: [point(31, 70.0)]),
      ChartSegment(id: "weightKg#1", breakBefore: .deviceChanged(from: "SYN-A", to: "SYN-B"), points: [point(28, 70.2)]),
    ])
    let breaks = SeriesTrendChart.numberedBreaks(model)
    XCTAssertEqual(breaks.map(\.at), [day(28), day(31)], "numbered in date order, whatever the segment order")
    let period = day(1)...day(31)
    XCTAssertEqual(SeriesTrendChart.markerRows(breaks, period: period), [0, 1], "3 days of 30 apart: two rows")
    let far = [ChartBreakMark(at: day(5), reason: .protocolChanged), ChartBreakMark(at: day(28), reason: .protocolChanged)]
    XCTAssertEqual(SeriesTrendChart.markerRows(far, period: period), [0, 0], "far apart: one row")
    let sameDay = [ChartBreakMark(at: day(9), reason: .protocolChanged),
                   ChartBreakMark(at: day(9), reason: .conditionMismatch(condition: "fasting"))]
    XCTAssertEqual(SeriesTrendChart.markerRows(sameDay, period: day(9)...day(9)), [0, 1], "one day: one row each")
    // A third break far from the second reuses the first row.
    let three = breaks + [ChartBreakMark(at: day(60), reason: .protocolChanged)]
    XCTAssertEqual(SeriesTrendChart.markerRows(three, period: day(1)...day(60)), [0, 1, 0])
  }

  /// Review finding 6: text inside the fixed-height plot stops growing at xxLarge; the period and the reasons are under
  /// the plot. At the largest accessibility size the chart grows to fit them instead of cutting them.
  func testPlotTextIsCappedAndTheReasonsGrowUnderThePlot() throws {
    XCTAssertEqual(SeriesTrendChart.plotTextLimit, .xxLarge)
    let localize = try AppCatalog.localizer()
    func height(_ size: DynamicTypeSize) -> CGFloat {
      fittingSize(SeriesTrendChart(model: deviceChange, localize: localize, timeZone: seoul).dynamicTypeSize(size)).height
    }
    let large = height(.large)
    let accessibility = height(.accessibility5)
    XCTAssertGreaterThan(large, SeriesTrendChart.plotHeight)
    XCTAssertGreaterThan(accessibility, large, "the period and the reason under the plot grow with the text size")
  }

  /// AC-DF-130.9 by rule: the sides differ by dash and point shape, and the break rule by its own dash.
  func test_TC_130_09_sidesDifferWithoutColour() throws {
    XCTAssertNotEqual(SeriesTrendChart.lineStyle(.left), SeriesTrendChart.lineStyle(.right))
    XCTAssertTrue(SeriesTrendChart.lineStyle(.left).dash.isEmpty)
    XCTAssertNotEqual(SeriesTrendChart.breakStyle, SeriesTrendChart.lineStyle(.right))
    let localize = try AppCatalog.localizer()
    XCTAssertEqual([localize("chart.legend.left"), localize("chart.legend.right")], ["왼쪽", "오른쪽"])
  }

  /// AC-DF-130.5 / AC-DF-130.6: v1 shows '산정 준비 중'; an indeterminate badge only exists with its reason.
  func test_TC_130_06_indeterminateNeedsAReason() throws {
    let localize = try AppCatalog.localizer()
    XCTAssertEqual(deviceChange.badge, .pendingPolicy, "no active change policy in v1")
    XCTAssertEqual(ChangeBadge.label(.pendingPolicy, localize: localize), "산정 준비 중")
    // `.indeterminate` is a function of a non-optional ReasonCode: `ChangeBadgeState.indeterminate(nil)` and a bare
    // `.indeterminate` do not compile.
    let make: (ReasonCode) -> ChangeBadgeState = ChangeBadgeState.indeterminate
    XCTAssertEqual(ChangeBadge.label(make(.deviceChanged), localize: localize), "판정 불가 · 기기 변경")
    for reason in ReasonCode.allCases {
      let label = ChangeBadge.label(.indeterminate(reason), localize: localize)
      XCTAssertTrue(label.hasPrefix("판정 불가 · "), label)
      XCTAssertGreaterThan(label.count, "판정 불가 · ".count, "\(reason) has its own words")
    }
  }

  /// AC-DF-130.10: the summary sentence has the period, points, minimum and maximum, breaks, source and change state,
  /// and the audio graph has one series per segment.
  func test_TC_130_10_summaryAndAudioGraph() throws {
    let localize = try AppCatalog.localizer()
    let model = deviceChange
    let summary = try XCTUnwrap(SeriesTrendChart.summary(model, localize: localize, timeZone: seoul))
    XCTAssertEqual(summary, "체중 추이, 2026.01.01~2026.01.10, 기록 3개, 최소 70.2kg, 최대 72.4kg, 끊김 1곳, "
                   + "출처 기기 측정 · SYN-B, 변화 산정 준비 중")
    let single = SeriesChartModel(metricCode: .bodyFatPercent, deviceModel: "SYN-A", segments: [
      ChartSegment(id: "s", points: [point(3, -0.04)]),
    ], badge: .indeterminate(.noComparison))
    XCTAssertEqual(SeriesTrendChart.summary(single, localize: localize, timeZone: seoul),
                   "체지방률 추이, 2026.01.03, 기록 1개, 최소 0.0%, 최대 0.0%, 끊김 0곳, 출처 기기 측정 · SYN-A, "
                   + "변화 판정 불가 · 비교할 측정 없음")

    let descriptor = SeriesChartDescriptor(model: model, localize: localize, timeZone: seoul).makeChartDescriptor()
    XCTAssertEqual(descriptor.title, "체중")
    XCTAssertEqual(descriptor.summary, summary)
    XCTAssertEqual(descriptor.series.map(\.name), ["체중", "기기 변경: SYN-A → SYN-B"])
    XCTAssertEqual(descriptor.series.map(\.dataPoints.count), [2, 1])
    XCTAssertTrue(descriptor.series.allSatisfy(\.isContinuous))
    let xAxis = try XCTUnwrap(descriptor.xAxis as? AXNumericDataAxisDescriptor)
    XCTAssertEqual(xAxis.title, "측정일")
    XCTAssertEqual(xAxis.valueDescriptionProvider(day(10).timeIntervalSince1970), "2026.01.10")
    let yAxis = try XCTUnwrap(descriptor.yAxis)
    XCTAssertEqual(yAxis.range, 70.2...72.4)
    XCTAssertEqual(yAxis.valueDescriptionProvider(70.2), "70.2kg")

    let left = ChartSegment(id: "L#1", side: .left, breakBefore: .protocolChanged, points: [point(1, 52, .tape)])
    XCTAssertEqual(SeriesChartDescriptor(model: model, localize: localize, timeZone: seoul).seriesName(left),
                   "왼쪽 · 프로토콜 변경")
  }

  /// AC-DF-130.8: the chart files name no four-axis colour (V1-07 §3.11) and no green (checked app-wide by
  /// `DesignSystemSourceTests`).
  func test_TC_130_08_noFourAxisColours() throws {
    let charts = AppCatalog.trainerApp.appendingPathComponent("Packages/TrainerKit/Sources/DesignSystem/Charts")
    let files = try FileManager.default.contentsOfDirectory(at: charts, includingPropertiesForKeys: nil)
      .filter { $0.pathExtension == "swift" }
    XCTAssertFalse(files.isEmpty, "the Charts folder moved")
    let forbidden = try NSRegularExpression(pattern: #"DfetAxis|AxisPalette|axisColor|fourAxis|FourAxis"#)
    for file in files {
      let text = try String(contentsOf: file, encoding: .utf8)
      XCTAssertNil(forbidden.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), file.lastPathComponent)
    }
  }
}
