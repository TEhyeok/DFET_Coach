import Charts
import SwiftUI
import TrainerContracts

/// The trend chart of the trainer app (DF-130, F-VIZ-07, V1-07 §4.10 추이): TR-10 추이 and the TR-11 미니 추이.
///
/// - One metric, one source grade: points of two or more grades are not drawn, `chart.rejected.mixedSource` is
///   (F-VIZ-07.2, AC-DF-130.2). No points: `chart.empty`.
/// - The x axis is the measurement date, so irregular intervals keep their spacing; a missing date has no point and
///   nothing is filled in; lines are straight (`.linear`) and each segment is its own `LineMark` series, so two
///   segments are never joined (C-04, AC-DF-130.3).
/// - A segment that starts at a break has a dashed vertical rule at its first point with a numbered marker, and the
///   numbered reason ('기기 변경: A → B') and date are listed under the plot (AC-DF-130.4). Markers of close breaks
///   take separate rows, so no two draw over each other (DF-127 review finding 5). There are at most
///   `maxMarkerRows` rows: past them a break joins the marker before it, which then numbers the run ('4~12'). The rows
///   are above the plot's own height, so crowded breaks never take room from the plot (DF-127 second review).
/// - Text inside the plot (axis values, markers) stops growing at `plotTextLimit`; the period and the break reasons
///   are ordinary text under the plot that grows and wraps, so nothing is cut or overlaps at accessibility text
///   sizes (AC-A11Y-02, review finding 6).
/// - The change slot is `ChangeBadge` ('산정 준비 중' in v1); no band, no judgement (AC-DF-130.5, ADR-009).
/// - Left and right differ by line (solid, dashed), point shape (circle, square) and a legend, not by colour; lines
///   are neutral, never green or four-axis colours (AC-DF-130.8, AC-DF-130.9).
/// - VoiceOver reads the `chart.summary` sentence and gets an audio graph (`SeriesChartDescriptor`, AC-DF-130.10).
public struct SeriesTrendChart: View {
  private let model: SeriesChartModel
  private let localize: Localizer
  private let timeZone: TimeZone

  /// The plot keeps this height at every text size; the empty and rejected messages take at least the same space.
  static let plotHeight: CGFloat = 220
  /// The largest text size inside the plot. The plot has a fixed height and a column's width, so its labels cannot
  /// grow without colliding; what must stay readable at every size is under the plot.
  static let plotTextLimit = DynamicTypeSize.xxLarge
  /// A break marker's diameter above the plot, and one marker row there.
  static let markerSize: CGFloat = 18
  static let markerRowHeight: CGFloat = markerSize + TrainerSpacing.xs
  /// Two markers closer than this share of the period (about one marker in a narrow column's plot) take separate rows.
  static let markerSeparation = 0.12
  /// The most marker rows above the plot.
  static let maxMarkerRows = 3
  // Chart value names: identifiers, not UI text (the accessible names come from `SeriesChartDescriptor`).
  private static let xName: String = "measuredAt"
  private static let yName: String = "value"
  private static let seriesName: String = "segment"

  public init(model: SeriesChartModel, localize: Localizer = .main, timeZone: TimeZone = .current) {
    self.model = model
    self.localize = localize
    self.timeZone = timeZone
  }

  public var body: some View {
    let content = model.content
    if content != .hidden {
      VStack(alignment: .leading, spacing: TrainerSpacing.s) {
        header(showsBadge: content != .empty && content != .rejectedMixedSource)
        switch content {
        case .chart(let grade):
          chart(grade)
        case .rejectedMixedSource:
          message("chart.rejected.mixedSource")
        case .empty, .hidden:
          message("chart.empty")
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("chart.\(model.metricCode.rawValue)")
    }
  }

  // MARK: - Parts

  private func header(showsBadge: Bool) -> some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .firstTextBaseline, spacing: TrainerSpacing.m) {
        title
        Spacer(minLength: TrainerSpacing.s)
        if showsBadge { ChangeBadge(state: model.badge, localize: localize) }
      }
      VStack(alignment: .leading, spacing: TrainerSpacing.xs) {
        title
        if showsBadge { ChangeBadge(state: model.badge, localize: localize) }
      }
    }
  }

  private var title: some View {
    HStack(alignment: .firstTextBaseline, spacing: TrainerSpacing.xs) {
      Text(localize("metric.\(model.metricCode.rawValue).name"))
        .font(.headline)
      Text(Self.unitText(model.metricCode, localize: localize))
        .font(.subheadline)
        .foregroundStyle(TrainerColor.neutral600)
    }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isHeader)
  }

  private func chart(_ grade: SourceGrade) -> some View {
    VStack(alignment: .leading, spacing: TrainerSpacing.s) {
      SourceGradeChip(grade: grade, deviceModel: model.deviceModel, localize: localize)
      plot
        .frame(height: Self.plotHeight + Self.markerAreaHeight(markers))
      periodRow
      let breaks = Self.numberedBreaks(model)
      if !breaks.isEmpty {
        breakList(breaks)
      }
      let sides = [Side.left, .right].filter { side in model.segments.contains { $0.side == side } }
      if !sides.isEmpty {
        HStack(spacing: TrainerSpacing.l) {
          ForEach(sides, id: \.self) { side in
            HStack(spacing: TrainerSpacing.xs) {
              LegendSwatch(side: side)
              Text(localize("chart.legend.\(side.rawValue)"))
                .font(.footnote)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("chart.legend.\(side.rawValue)")
          }
        }
      }
      if model.points.count == 1 {
        // F-VIZ-03.10: one point has nothing to compare with.
        Text(localize("chart.singlePoint"))
          .font(.footnote)
          .foregroundStyle(TrainerColor.neutral600)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("chart.singlePoint")
      }
    }
  }

  @ViewBuilder
  private var plot: some View {
    let values = model.points.map(\.value)
    if let low = values.min(), let high = values.max(), low == high {
      // One value (or all equal): the automatic domain has no extent and draws an upside-down axis.
      marks.chartYScale(domain: (low - 1)...(high + 1))
    } else {
      marks.chartYScale(domain: .automatic(includesZero: false))
    }
  }

  private var marks: some View {
    let code = model.metricCode
    let breaks = Self.numberedBreaks(model)
    let slots = markers
    return Chart {
      ForEach(model.segments) { segment in
        ForEach(segment.points.indices, id: \.self) { index in
          let point = segment.points[index]
          LineMark(
            x: .value(Self.xName, point.measuredAt), y: .value(Self.yName, point.value),
            series: .value(Self.seriesName, segment.id))
            .interpolationMethod(.linear)
            .lineStyle(Self.lineStyle(segment.side))
            .foregroundStyle(TrainerColor.neutral800)
          PointMark(x: .value(Self.xName, point.measuredAt), y: .value(Self.yName, point.value))
            .symbol(Self.symbol(segment.side))
            .symbolSize(40)
            .foregroundStyle(TrainerColor.neutral800)
        }
      }
      ForEach(Array(breaks.enumerated()), id: \.offset) { index, mark in
        if let marker = slots.first(where: { $0.breaks.lowerBound == index }) {
          RuleMark(x: .value(Self.xName, mark.at))
            .lineStyle(Self.breakStyle)
            .foregroundStyle(TrainerColor.neutral500)
            .annotation(
              position: .top, alignment: .center,
              spacing: TrainerSpacing.xxs + CGFloat(marker.row) * Self.markerRowHeight,
              overflowResolution: .init(x: .fit(to: .plot), y: .disabled)
            ) {
              BreakMarker(numbers: (marker.breaks.lowerBound + 1)...(marker.breaks.upperBound + 1))
            }
        } else {
          // Numbered by the run's marker before it.
          RuleMark(x: .value(Self.xName, mark.at))
            .lineStyle(Self.breakStyle)
            .foregroundStyle(TrainerColor.neutral500)
        }
      }
    }
    // Room at both ends so the first and last points are not on the plot edge; the scale stays proportional.
    .chartXScale(range: .plotDimension(padding: TrainerSpacing.xl))
    .chartXAxis {
      // Ticks at the first and last dates only; the dates themselves are under the plot (`periodRow`), where they can
      // grow. No vertical grid lines, so the only vertical line in the plot is a break.
      AxisMarks(values: periodDates) { _ in
        AxisTick()
      }
    }
    .chartYAxis {
      AxisMarks(values: .automatic(desiredCount: 4)) { value in
        AxisGridLine()
        AxisValueLabel {
          if let number = value.as(Double.self) {
            Text(MetricRow.valueText(number, code: code))
          }
        }
      }
    }
    .chartLegend(.hidden)
    .dynamicTypeSize(...Self.plotTextLimit)
    // Room above the plot for the marker rows (drawn there, not over the highest points).
    .padding(.top, Self.markerAreaHeight(slots))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Self.summary(model, localize: localize, timeZone: timeZone) ?? "")
    .accessibilityChartDescriptor(SeriesChartDescriptor(model: model, localize: localize, timeZone: timeZone))
  }

  /// The markers above the plot (`markers(_:period:)`).
  private var markers: [BreakMarkerSlot] {
    guard let first = periodDates.first else { return [] }
    return Self.markers(Self.numberedBreaks(model), period: first...(periodDates.last ?? first))
  }

  /// The first and last measurement dates (one date for a single day).
  private var periodDates: [Date] {
    let dates = model.points.map(\.measuredAt)
    guard let first = dates.min(), let last = dates.max() else { return [] }
    return first == last ? [first] : [first, last]
  }

  /// The first and last dates under the plot, at its two ends, or as one range ('2026.05.01~2026.09.18', V1-12 §2.6)
  /// that wraps when they do not fit side by side. VoiceOver reads the period in the summary.
  @ViewBuilder
  private var periodRow: some View {
    let dates = periodDates.map { MetricRow.dateText($0, timeZone: timeZone) }
    if let first = dates.first {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: TrainerSpacing.s) {
          Text(verbatim: first)
          if let last = dates.dropFirst().first {
            Spacer(minLength: TrainerSpacing.s)
            Text(verbatim: last)
          }
        }
        Text(verbatim: dates.joined(separator: "~"))
          .fixedSize(horizontal: false, vertical: true)
      }
      .font(.footnote.monospacedDigit())
      .foregroundStyle(TrainerColor.neutral600)
      .accessibilityHidden(true)
    }
  }

  /// One entry per break, numbered like its marker: the reason ('기기 변경: A → B') and the date its segment starts.
  /// Text that grows and wraps, so a reason is never cut or drawn over another one.
  private func breakList(_ breaks: [ChartBreakMark]) -> some View {
    VStack(alignment: .leading, spacing: TrainerSpacing.xs) {
      ForEach(Array(breaks.enumerated()), id: \.offset) { index, mark in
        HStack(alignment: .firstTextBaseline, spacing: TrainerSpacing.s) {
          BreakMarker(number: index + 1, scales: true)
          VStack(alignment: .leading, spacing: TrainerSpacing.xxs) {
            Text(Self.breakLabel(mark.reason, localize: localize))
              .foregroundStyle(TrainerColor.neutral800)
            Text(verbatim: MetricRow.dateText(mark.at, timeZone: timeZone))
              .foregroundStyle(TrainerColor.neutral600)
          }
          .font(.footnote)
          .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("chart.break.\(index + 1)")
      }
    }
  }

  private func message(_ key: String) -> some View {
    Text(localize(key))
      .font(.subheadline)
      .foregroundStyle(TrainerColor.neutral700)
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)
      .padding(TrainerSpacing.l)
      .frame(maxWidth: .infinity, minHeight: Self.plotHeight)
      .background(TrainerColor.neutral100, in: RoundedRectangle(cornerRadius: TrainerSpacing.cornerRadius))
      .accessibilityIdentifier(key)
  }

  // MARK: - Rules

  /// Solid for one side and a plain series, dashed for the right side (AC-DF-130.9).
  static func lineStyle(_ side: Side) -> StrokeStyle {
    side == .right ? StrokeStyle(lineWidth: 2, dash: [6, 4]) : StrokeStyle(lineWidth: 2)
  }

  static func symbol(_ side: Side) -> BasicChartSymbolShape {
    side == .right ? .square : .circle
  }

  /// Thinner and more finely dashed than the right side's line, and always vertical.
  static let breakStyle = StrokeStyle(lineWidth: 1, dash: [2, 3])

  /// The breaks in date order; a break's number (its marker and its entry under the plot) is its place here, from 1.
  static func numberedBreaks(_ model: SeriesChartModel) -> [ChartBreakMark] {
    model.breaks.enumerated().sorted { ($0.element.at, $0.offset) < ($1.element.at, $1.offset) }.map(\.element)
  }

  /// The markers above the plot, for breaks in date order, each with its row (0 = just above the plot): a marker
  /// closer than `markerSeparation` of the period to the last marker of a row goes to the next row, so close breaks
  /// never draw over each other; breaks on one day (or a one-day period) each get their own row. When all
  /// `maxMarkerRows` rows are taken there, a break joins the marker before it, which then numbers the run.
  static func markers(_ breaks: [ChartBreakMark], period: ClosedRange<Date>) -> [BreakMarkerSlot] {
    let span = period.upperBound.timeIntervalSince(period.lowerBound)
    var lastInRow: [Double] = []
    var markers: [BreakMarkerSlot] = []
    for (index, mark) in breaks.enumerated() {
      let x = span > 0 ? mark.at.timeIntervalSince(period.lowerBound) / span : 0
      if let row = lastInRow.firstIndex(where: { x - $0 >= markerSeparation }) {
        lastInRow[row] = x
        markers.append(BreakMarkerSlot(breaks: index...index, row: row))
      } else if lastInRow.count < maxMarkerRows {
        lastInRow.append(x)
        markers.append(BreakMarkerSlot(breaks: index...index, row: lastInRow.count - 1))
      } else if let run = markers.popLast() {
        markers.append(BreakMarkerSlot(breaks: run.breaks.lowerBound...index, row: run.row))
      }
    }
    return markers
  }

  /// The room above the plot for the marker rows: none without breaks, at most `maxMarkerRows` rows.
  static func markerAreaHeight(_ markers: [BreakMarkerSlot]) -> CGFloat {
    CGFloat(markers.map(\.row).max().map { $0 + 1 } ?? 0) * markerRowHeight
  }

  static func unitText(_ code: MetricCode, localize: Localizer) -> String {
    localize("unit.\(MetricCatalog.entry(for: code).unit.rawValue)")
  }

  /// The deck's `series.break.*` label of a break (F-VIZ-03.3).
  public static func breakLabel(_ reason: ChartBreakReason, localize: Localizer) -> String {
    switch reason {
    case .deviceChanged(let from, let to):
      return localize.format("series.break.device", from, to)
    case .protocolChanged:
      return localize("series.break.protocol")
    case .conditionMismatch(let condition):
      return localize.format("series.break.condition", localize("condition.\(condition)"))
    }
  }

  /// `chart.summary`: "{metricName} 추이, {period}, 기록 {count}개, 최소 {min}, 최대 {max}, 끊김 {breaks}곳,
  /// 출처 {source}, 변화 {status}" (A-03, AC-DF-130.10). nil when no chart is drawn.
  public static func summary(_ model: SeriesChartModel, localize: Localizer, timeZone: TimeZone) -> String? {
    guard case .chart(let grade) = model.content else { return nil }
    let points = model.points
    let values = points.map(\.value)
    let dates = points.map(\.measuredAt)
    guard let low = values.min(), let high = values.max(), let first = dates.min(), let last = dates.max() else {
      return nil
    }
    let code = model.metricCode
    let unit = unitText(code, localize: localize)
    let start = MetricRow.dateText(first, timeZone: timeZone)
    let end = MetricRow.dateText(last, timeZone: timeZone)
    let arguments: [CVarArg] = [
      localize("metric.\(code.rawValue).name"),
      start == end ? start : start + "~" + end,  // V1-12 §2.6 range
      points.count,  // `{count}` is %lld (V1-12 §4.3)
      MetricRow.valueText(low, code: code) + unit,
      MetricRow.valueText(high, code: code) + unit,
      String(model.breaks.count),
      SourceGradeChip.label(grade, deviceModel: model.deviceModel, localize: localize) ?? "",
      ChangeBadge.label(model.badge, localize: localize),
    ]
    return String(format: localize("chart.summary"), arguments: arguments)
  }
}

/// A marker above the plot: the breaks it numbers (indices in date order: one, or a run of close ones) and its row.
struct BreakMarkerSlot: Equatable {
  let breaks: ClosedRange<Int>
  let row: Int
}

/// A break's number in a circle, on its rule above the plot and next to its reason under the plot: which dashed line a
/// reason belongs to. Above the plot it keeps `SeriesTrendChart.markerSize` (its rows have a fixed height, and the
/// plot's text stops growing at `plotTextLimit`); under the plot it grows with the reason's text. A run of crowded
/// breaks has one marker with the first and last numbers ('4~12', V1-12 §2.6 range) in a capsule.
struct BreakMarker: View {
  let numbers: ClosedRange<Int>
  var scales = false
  @ScaledMetric(relativeTo: .caption2) private var scaledSize: CGFloat = SeriesTrendChart.markerSize

  init(number: Int, scales: Bool = false) {
    self.init(numbers: number...number, scales: scales)
  }

  init(numbers: ClosedRange<Int>, scales: Bool = false) {
    self.numbers = numbers
    self.scales = scales
  }

  var body: some View {
    let size = scales ? scaledSize : SeriesTrendChart.markerSize
    Group {
      if numbers.count == 1 {
        label(String(numbers.lowerBound))
          .frame(width: size, height: size)
          .overlay(Circle().strokeBorder(TrainerColor.neutral500, lineWidth: 1))
      } else {
        label("\(numbers.lowerBound)~\(numbers.upperBound)")
          .fixedSize()
          .padding(.horizontal, TrainerSpacing.xs)
          .frame(minWidth: size, minHeight: size, maxHeight: size)
          .overlay(Capsule().strokeBorder(TrainerColor.neutral500, lineWidth: 1))
      }
    }
    .accessibilityHidden(true)
  }

  private func label(_ text: String) -> some View {
    Text(verbatim: text)
      .font(.caption2.weight(.semibold).monospacedDigit())
      .lineLimit(1)
      .minimumScaleFactor(0.5)  // two digits still fit the circle
      .foregroundStyle(TrainerColor.neutral800)
  }
}

/// A short line in a side's style with its point shape, for the legend.
private struct LegendSwatch: View {
  let side: Side

  var body: some View {
    ZStack {
      Path { path in
        path.move(to: CGPoint(x: 0, y: 6))
        path.addLine(to: CGPoint(x: 28, y: 6))
      }
      .stroke(TrainerColor.neutral800, style: SeriesTrendChart.lineStyle(side))
      if side == .right {
        Rectangle().frame(width: 7, height: 7)
      } else {
        Circle().frame(width: 8, height: 8)
      }
    }
    .foregroundStyle(TrainerColor.neutral800)
    .frame(width: 28, height: 12)
    .accessibilityHidden(true)
  }
}
