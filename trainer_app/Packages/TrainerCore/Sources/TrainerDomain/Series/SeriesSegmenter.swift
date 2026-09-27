import Foundation
import TrainerContracts

/// Splits trend points into series and line segments (V1-09 §8.2~8.4, DF-128 with the DF-216 API).
///
/// P1a scope (DF-128): `bodyComposition`, `tape` and `pain` points are segmented. `posture` and `lidar` points give
/// no series until DF-216 adds them, so `segment` leaves them out. `compare` already follows the full §8.2 table.
public enum SeriesSegmenter {
  /// Families `segment` handles in P1a.
  public static let segmentedFamilies: Set<SeriesFamily> = [.bodyComposition, .tape, .pain]

  /// V1-09 §8.3: `(metricCode, sourceGrade, sideSeries, source for body composition)`.
  public static func identity(of p: SeriesPoint) -> SeriesIdentity {
    let sideRule = MetricCatalog.entry(for: p.metricCode).sideRule
    let sideSeries: Side = (sideRule == .leftRight || sideRule == .leftRightBilateral) ? p.side : .none
    return SeriesIdentity(metricCode: p.metricCode, sourceGrade: p.sourceGrade, side: sideSeries,
                          source: p.family == .bodyComposition ? p.conditions.source : nil)
  }

  /// Why `a` (the later point) cannot be joined to `b` (the point just before it), or nil when it can (§8.2).
  /// The first difference in the order protocol → device → condition decides. `unknown` or a missing condition value
  /// never matches, not even itself (§7.4). Camera height and distance match while both are inside the station range.
  public static func compare(_ a: ConditionSnapshot, _ b: ConditionSnapshot, family: SeriesFamily) -> SeriesBreak? {
    for key in protocolKeys(family) where a[keyPath: key] != b[keyPath: key] {
      return SeriesBreak(reason: .protocolChanged,
                         detail: .protocolVersion(from: b[keyPath: key] ?? "", to: a[keyPath: key] ?? ""))
    }
    if devicedFamilies.contains(family), a.deviceKey != b.deviceKey {
      return SeriesBreak(reason: .deviceChanged, detail: .device(from: b.deviceKey ?? "", to: a.deviceKey ?? ""))
    }
    for check in conditionChecks(family) {
      switch check {
      case let .value(name, key):
        let later = a[keyPath: key]
        let earlier = b[keyPath: key]
        if later == nil || earlier == nil || later == "unknown" || earlier == "unknown" || later != earlier {
          return SeriesBreak(reason: .conditionMismatch, detail: .condition(key: name))
        }
      case .station:
        if !(inStation(a) && inStation(b)) {
          return SeriesBreak(reason: .conditionMismatch, detail: .condition(key: "stationProfile"))
        }
      }
    }
    return nil
  }

  /// Groups points by identity and splits each group where `compare` finds a break with the point just before
  /// (§8.4). Points are ordered by (`measuredAt`, `refId`) whatever the input order (SB-14). Every output point is
  /// an input point: nothing is interpolated or filled (C-04).
  public static func segment(_ points: [SeriesPoint]) -> [SeriesIdentity: [SeriesSegment]] {
    let groups = Dictionary(grouping: points.filter { segmentedFamilies.contains($0.family) }, by: identity(of:))
    return groups.mapValues { group in
      let sorted = group.sorted { ($0.measuredAt, $0.refId) < ($1.measuredAt, $1.refId) }
      let key = identity(of: sorted[0]).key
      var segments = [SeriesSegment(id: "\(key)#0", points: [sorted[0]], breakBefore: nil)]
      for (previous, point) in zip(sorted, sorted.dropFirst()) {
        if let br = compare(point.conditions, previous.conditions, family: point.family) {
          segments.append(SeriesSegment(id: "\(key)#\(segments.count)", points: [point], breakBefore: br))
        } else {
          segments[segments.count - 1].points.append(point)
        }
      }
      return segments
    }
  }

  // MARK: Family tables (V1-09 §8.1, §8.2)

  private static let devicedFamilies: Set<SeriesFamily> = [.posture, .bodyComposition, .lidar]

  private static func protocolKeys(_ family: SeriesFamily) -> [KeyPath<ConditionSnapshot, String?>] {
    switch family {
    case .posture: return [\.protocolVersion]
    case .tape: return [\.protocolVersion, \.protocolId]
    case .lidar: return [\.protocolVersion, \.protocolId, \.algorithmVersion]
    case .bodyComposition, .pain: return []
    }
  }

  private enum ConditionCheck {
    /// Equal and known on both sides.
    case value(String, KeyPath<ConditionSnapshot, String?>)
    /// Camera height and distance both inside the station ranges (`stationProfileId` itself is not compared).
    case station
  }

  private static func conditionChecks(_ family: SeriesFamily) -> [ConditionCheck] {
    switch family {
    case .posture: return [.value("view", \.view), .value("clothing", \.clothing), .station]
    case .bodyComposition: return [.value("fasting", \.fasting), .value("timeOfDayBand", \.timeOfDayBand)]
    case .tape, .lidar, .pain: return []
    }
  }

  /// Camera height and distance inside the protocol's station ranges (closed, ASM-P1b-18). Missing is outside.
  private static func inStation(_ c: ConditionSnapshot) -> Bool {
    guard let height = c.cameraHeightCm, let distance = c.cameraDistanceM else { return false }
    return PostureProtocolV1.cameraHeightCm.contains(height) && PostureProtocolV1.cameraDistanceM.contains(distance)
  }
}
