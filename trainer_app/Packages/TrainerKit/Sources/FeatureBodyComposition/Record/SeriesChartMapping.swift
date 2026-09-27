import DesignSystem
import TrainerContracts
import TrainerDomain

/// TrainerDomain series points → the DesignSystem chart model (DF-130). The segmenting is `SeriesSegmenter`'s
/// (DF-128); this only renames: one chart segment per series segment (its id is the Swift Charts `series:` value, so
/// two segments are never joined), the break reason with the deck's `series.break.*` wording, and the latest point's
/// device for the source chip. The badge is '산정 준비 중': there is no active change policy in v1 (AC-DF-130.5).
enum SeriesChartMapping {
  static func model(metricCode: MetricCode, points: [SeriesPoint], badge: ChangeBadgeState = .pendingPolicy)
    -> SeriesChartModel
  {
    let lines = SeriesSegmenter.segment(points).sorted { $0.key.key < $1.key.key }
    let segments = lines.flatMap { identity, segments in
      segments.map { segment in
        ChartSegment(
          id: segment.id, side: identity.side, breakBefore: segment.breakBefore.map(reason),
          points: segment.points.map { ChartPoint(measuredAt: $0.measuredAt, value: $0.value, sourceGrade: $0.sourceGrade) })
      }
    }
    let latest = points.max { ($0.measuredAt, $0.refId) < ($1.measuredAt, $1.refId) }
    return SeriesChartModel(metricCode: metricCode, deviceModel: latest?.conditions.deviceKey, segments: segments,
                            badge: badge)
  }

  static func reason(_ seriesBreak: SeriesBreak) -> ChartBreakReason {
    switch seriesBreak.detail {
    case let .device(from, to):
      return .deviceChanged(from: from, to: to)
    case .protocolVersion:
      return .protocolChanged
    case let .condition(key):
      // `condition.*` key suffix (`BreakDetail.conditionCopyKey`): `stationProfile` is `condition.station`.
      let suffix = seriesBreak.detail.conditionCopyKey.map { String($0.dropFirst("condition.".count)) }
      return .conditionMismatch(condition: suffix ?? key)
    }
  }
}
