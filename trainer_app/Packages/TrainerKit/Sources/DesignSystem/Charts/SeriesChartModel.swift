import Foundation
import TrainerContracts

/// One drawn value (F-VIZ-07.1). The source grade is not optional: a record without one never becomes a point
/// (AC-DF-130.1, C-01), so there is nothing for the chart to leave out.
public struct ChartPoint: Equatable, Sendable {
  public let measuredAt: Date
  public let value: Double
  public let sourceGrade: SourceGrade

  public init(measuredAt: Date, value: Double, sourceGrade: SourceGrade) {
    self.measuredAt = measuredAt
    self.value = value
    self.sourceGrade = sourceGrade
  }
}

/// Why a segment starts: the V1-09 §8.2 break reasons, drawn with the deck's `series.break.*` labels (F-VIZ-03.3).
public enum ChartBreakReason: Hashable, Sendable {
  /// '기기 변경: {from} → {to}'.
  case deviceChanged(from: String, to: String)
  /// '프로토콜 변경'.
  case protocolChanged
  /// '조건 불일치: {condition}'. `condition` is the `condition.*` key suffix: `fasting`, `timeOfDayBand`, `view`,
  /// `clothing`, `station` or `side`.
  case conditionMismatch(condition: String)
}

/// Points that may be joined by a line (a V1-09 §8.4 segment). Two segments are never joined (AC-DF-130.3).
public struct ChartSegment: Identifiable, Equatable, Sendable {
  public let id: String
  /// `.left` or `.right` for one side of a left/right metric: a solid or dashed line, a circle or square point and a
  /// legend, so the sides differ without colour (AC-DF-130.9). `.none` otherwise.
  public let side: Side
  /// Set when the segment starts at a series break: a dashed vertical rule and the reason at its first point.
  public let breakBefore: ChartBreakReason?
  public let points: [ChartPoint]

  public init(id: String, side: Side = .none, breakBefore: ChartBreakReason? = nil, points: [ChartPoint]) {
    self.id = id
    self.side = side
    self.breakBefore = breakBefore
    self.points = points
  }
}

/// A break as drawn: at the first point of the segment it starts.
public struct ChartBreakMark: Hashable, Sendable {
  public let at: Date
  public let reason: ChartBreakReason
}

/// Everything `SeriesTrendChart` draws for one metric (DF-130). The chart never computes a change, a band or an MDC
/// (ADR-009); `badge` says what the change slot shows.
public struct SeriesChartModel: Equatable, Sendable {
  public enum Content: Equatable, Sendable {
    /// A v2 metric, or a source grade v1 never shows: nothing is drawn (like `MetricRow`, AC-DF-016.3).
    case hidden
    /// No points: `chart.empty`, never a line at zero (C-04).
    case empty
    /// Points of two or more source grades: `chart.rejected.mixedSource` instead of a chart (F-VIZ-07.2, C-02).
    case rejectedMixedSource
    /// The chart, with the one source grade of all its points.
    case chart(SourceGrade)
  }

  public let metricCode: MetricCode
  /// The device in the source chip, '기기 측정 · {deviceModel}', for a `.device` series: the latest segment's device.
  public let deviceModel: String?
  public let segments: [ChartSegment]
  public let badge: ChangeBadgeState

  public init(
    metricCode: MetricCode, deviceModel: String? = nil, segments: [ChartSegment],
    badge: ChangeBadgeState = .pendingPolicy
  ) {
    self.metricCode = metricCode
    self.deviceModel = deviceModel
    self.segments = segments
    self.badge = badge
  }

  public var points: [ChartPoint] {
    segments.flatMap(\.points)
  }

  public var content: Content {
    guard MetricCatalog.entry(for: metricCode).availability != .v2 else { return .hidden }
    let grades = Set(points.map(\.sourceGrade))
    guard let grade = grades.first else { return .empty }
    guard grades.count == 1 else { return .rejectedMixedSource }
    return SourceGradeChip.label(grade, deviceModel: nil, localize: Localizer { $0 }) == nil ? .hidden : .chart(grade)
  }

  /// One mark per break date and reason: a break that starts both sides' segments on the same day is one break.
  public var breaks: [ChartBreakMark] {
    var marks: [ChartBreakMark] = []
    for segment in segments {
      guard let reason = segment.breakBefore, let first = segment.points.first else { continue }
      let mark = ChartBreakMark(at: first.measuredAt, reason: reason)
      if !marks.contains(mark) { marks.append(mark) }
    }
    return marks
  }
}
