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
/// - A segment that starts at a break has a dashed vertical rule and its reason ('기기 변경: A → B') at its first
///   point (AC-DF-130.4).
/// - The change slot is `ChangeBadge` ('산정 준비 중' in v1); no band, no judgement (AC-DF-130.5, ADR-009).
/// - Left and right differ by line (solid, dashed), point shape (circle, square) and a legend, not by colour; lines
///   are neutral, never green or four-axis colours (AC-DF-130.8, AC-DF-130.9).
/// - VoiceOver reads the `chart.summary` sentence and gets an audio graph (`SeriesChartDescriptor`, AC-DF-130.10).
public struct SeriesTrendChart: View {
  private let model: SeriesChartModel
  private let localize: Localizer
  private let timeZone: TimeZone
  /// Height of a break label line above the plot; grows with the text size.
  @ScaledMetric(relativeTo: .caption2) private var breakLabelRoom: CGFloat = 20

  /// The plot keeps this height at every text size; the empty and rejected messages take at least the same space.
  static let plotHeight: CGFloat = 220
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
        .frame(height: Self.plotHeight)
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
      ForEach(model.breaks, id: \.self) { mark in
        RuleMark(x: .value(Self.xName, mark.at))
          .lineStyle(Self.breakStyle)
          .foregroundStyle(TrainerColor.neutral500)
          .annotation(
            position: .top, alignment: .leading, spacing: TrainerSpacing.xxs,
            overflowResolution: .init(x: .fit(to: .plot), y: .disabled)
          ) {
            Text(Self.breakLabel(mark.reason, localize: localize))
              .font(.caption2)
              .foregroundStyle(TrainerColor.neutral700)
          }
      }
    }
    // Room at both ends so the first and last points are not on the plot edge; the scale stays proportional.
    .chartXScale(range: .plotDimension(padding: TrainerSpacing.xl))
    .chartXAxis {
      // Only the first and last dates are labelled: the period, and no labels that collide or truncate at large
      // text sizes or in a narrow column. No vertical grid lines, so the only vertical line in the plot is a break.
      AxisMarks(values: periodDates) { value in
        AxisTick()
        AxisValueLabel(anchor: value.count == 1 ? .top : (value.index == 0 ? .topLeading : .topTrailing)) {
          if let date = value.as(Date.self) {
            Text(MetricRow.dateText(date, timeZone: timeZone))
          }
        }
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
    // Room above the plot for the break labels (drawn there, not over the highest points).
    .padding(.top, model.breaks.isEmpty ? 0 : breakLabelRoom)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Self.summary(model, localize: localize, timeZone: timeZone) ?? "")
    .accessibilityChartDescriptor(SeriesChartDescriptor(model: model, localize: localize, timeZone: timeZone))
  }

  /// The first and last measurement dates (one date for a single day).
  private var periodDates: [Date] {
    let dates = model.points.map(\.measuredAt)
    guard let first = dates.min(), let last = dates.max() else { return [] }
    return first == last ? [first] : [first, last]
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
