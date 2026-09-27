import Foundation
import TrainerContracts

/// Why a chart is not drawn (F-VIZ-07.2).
public enum SeriesChartRejection: String, Equatable, Sendable {
  /// More than one source grade in one chart's input (C-02, AC-DF-130.2).
  case mixedSource

  /// `chart.rejected.mixedSource` ('출처가 다른 값은 한 차트에 그리지 않아요').
  public var copyKey: String { "chart.rejected.\(rawValue)" }
}

/// One line of a chart: one series identity, its segments in time order.
public struct SeriesLine: Equatable, Sendable {
  public var identity: SeriesIdentity
  public var segments: [SeriesSegment]

  public init(identity: SeriesIdentity, segments: [SeriesSegment]) {
    self.identity = identity
    self.segments = segments
  }

  /// Breaks drawn on this line (the `{breaks}` of `chart.summary`).
  public var breakCount: Int { segments.filter { $0.breakBefore != nil }.count }
  public var pointCount: Int { segments.reduce(0) { $0 + $1.points.count } }
}

/// What a trend chart (DF-130 `SeriesTrendChart`) may draw from one metric's points. The chart view maps this to its
/// model and never segments or filters on its own.
public enum SeriesChartInput: Equatable, Sendable {
  /// No point (the view shows its empty or first-record state).
  case empty
  /// Drawn as the rejection message instead of a chart.
  case rejected(SeriesChartRejection)
  /// One source grade; lines in side order (none, left, right, bilateral), then by identity key.
  case ready(sourceGrade: SourceGrade, lines: [SeriesLine])

  /// Refuses mixed source grades before anything is drawn (F-VIZ-07.2), then segments (`SeriesSegmenter.segment`).
  public static func make(_ points: [SeriesPoint]) -> SeriesChartInput {
    let grades = Set(points.map(\.sourceGrade))
    if grades.count > 1 { return .rejected(.mixedSource) }
    guard let grade = grades.first else { return .empty }
    let lines = SeriesSegmenter.segment(points)
      .map { SeriesLine(identity: $0.key, segments: $0.value) }
      .sorted { (sideOrder($0.identity.side), $0.identity.key) < (sideOrder($1.identity.side), $1.identity.key) }
    return lines.isEmpty ? .empty : .ready(sourceGrade: grade, lines: lines)
  }

  private static func sideOrder(_ side: Side) -> Int {
    switch side {
    case .none: return 0
    case .left: return 1
    case .right: return 2
    case .bilateral: return 3
    }
  }
}
