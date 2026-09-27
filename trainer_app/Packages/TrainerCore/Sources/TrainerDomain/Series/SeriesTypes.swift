import Foundation
import TrainerContracts

// Trend series types (V1-09 §8). The declarations are the P1b DF-216 card's, built early by DF-128 (ASM-P1a-32,
// CF-07); DF-216 extends them. This is a display rule: nothing here judges a change (ADR-009, AC-DF-216.8).

/// The record family a point comes from (V1-09 §8.1).
public enum SeriesFamily: String, Codable, CaseIterable, Sendable {
  case posture
  case bodyComposition
  case tape
  case lidar
  case pain
}

/// The condition values two points must share to be joined (V1-09 §8.1). A nil value counts as `unknown`.
public struct ConditionSnapshot: Codable, Equatable, Hashable, Sendable {
  public var protocolVersion: String?
  public var protocolId: String?
  public var algorithmVersion: String?
  public var view: String?
  public var clothing: String?
  public var cameraHeightCm: Double?
  public var cameraDistanceM: Double?
  /// `normalizeDevice(deviceModel)` for body composition, `device.model` for posture and LiDAR.
  public var deviceKey: String?
  public var fasting: String?
  public var timeOfDayBand: String?
  /// Body composition only: part of the series identity, not a condition (V1-09 §8.3).
  public var source: String?

  public init(
    protocolVersion: String? = nil, protocolId: String? = nil, algorithmVersion: String? = nil, view: String? = nil,
    clothing: String? = nil, cameraHeightCm: Double? = nil, cameraDistanceM: Double? = nil, deviceKey: String? = nil,
    fasting: String? = nil, timeOfDayBand: String? = nil, source: String? = nil
  ) {
    self.protocolVersion = protocolVersion
    self.protocolId = protocolId
    self.algorithmVersion = algorithmVersion
    self.view = view
    self.clothing = clothing
    self.cameraHeightCm = cameraHeightCm
    self.cameraDistanceM = cameraDistanceM
    self.deviceKey = deviceKey
    self.fasting = fasting
    self.timeOfDayBand = timeOfDayBand
    self.source = source
  }
}

/// One measured value on a trend. `sourceGrade` is not optional: a record without a grade never becomes a point
/// (C-01, AC-DF-130.1). A missing measurement is no point at all, never a 0 or a filled-in value (C-04).
public struct SeriesPoint: Equatable, Sendable {
  /// The source record's ID.
  public var refId: String
  public var metricCode: MetricCode
  public var sourceGrade: SourceGrade
  public var side: Side
  public var value: Double
  /// ASCII unit code (`kg`, `percent`, `cm`, …; `MetricUnit.rawValue`).
  public var unit: String
  public var measuredAt: Date
  public var family: SeriesFamily
  public var conditions: ConditionSnapshot

  public init(
    refId: String, metricCode: MetricCode, sourceGrade: SourceGrade, side: Side, value: Double, unit: String,
    measuredAt: Date, family: SeriesFamily, conditions: ConditionSnapshot
  ) {
    self.refId = refId
    self.metricCode = metricCode
    self.sourceGrade = sourceGrade
    self.side = side
    self.value = value
    self.unit = unit
    self.measuredAt = measuredAt
    self.family = family
    self.conditions = conditions
  }
}

/// Points of different identities are never on one line (V1-09 §8.3): different grades (tape vs observed section,
/// C-02), left vs right for side-series metrics, and different body composition sources.
public struct SeriesIdentity: Hashable, Sendable {
  public var metricCode: MetricCode
  public var sourceGrade: SourceGrade
  /// `sideSeries`: the point's side only for metrics whose side rule makes left and right separate series.
  public var side: Side
  /// Body composition only.
  public var source: String?

  public init(metricCode: MetricCode, sourceGrade: SourceGrade, side: Side, source: String?) {
    self.metricCode = metricCode
    self.sourceGrade = sourceGrade
    self.side = side
    self.source = source
  }

  /// Stable text for segment IDs, e.g. `bodyFatPercent|device|none|manualEntry`.
  public var key: String {
    "\(metricCode.rawValue)|\(sourceGrade.rawValue)|\(side.rawValue)|\(source ?? "")"
  }
}

/// Why the line breaks before a point, in the fixed order protocol → device → condition (§7.5, AC-DF-216.3).
public enum BreakReason: String, Codable, CaseIterable, Sendable {
  case protocolChanged
  case deviceChanged
  case conditionMismatch
}

/// What changed. `from` is the earlier point's value, `to` the later one's; a missing value is "".
public enum BreakDetail: Equatable, Hashable, Sendable {
  case device(from: String, to: String)
  /// Any protocol key: `protocolVersion`, `protocolId` or `algorithmVersion`.
  case protocolVersion(from: String, to: String)
  /// `fasting`, `timeOfDayBand`, `view`, `clothing` or `stationProfile`.
  case condition(key: String)

  /// Deck key of the `{condition}` name in `series.break.condition`, e.g. `condition.fasting`; nil for other cases.
  public var conditionCopyKey: String? {
    guard case let .condition(key) = self else { return nil }
    return key == "stationProfile" ? "condition.station" : "condition.\(key)"
  }
}

/// The DF-216 `breakBefore` tuple as a struct, so segments stay Equatable (DF-216 implementation note).
public struct SeriesBreak: Equatable, Hashable, Sendable {
  public var reason: BreakReason
  public var detail: BreakDetail

  public init(reason: BreakReason, detail: BreakDetail) {
    self.reason = reason
    self.detail = detail
  }

  /// Deck key of the break label: `series.break.device` ('기기 변경: {from} → {to}'), `series.break.protocol`,
  /// `series.break.condition` ('조건 불일치: {condition}').
  public var copyKey: String {
    switch reason {
    case .protocolChanged: return "series.break.protocol"
    case .deviceChanged: return "series.break.device"
    case .conditionMismatch: return "series.break.condition"
    }
  }
}

/// Points joined by a line. No line is drawn between two segments (F-VIZ-03.3).
public struct SeriesSegment: Equatable, Sendable, Identifiable {
  /// Unique within one `segment` result and stable for the same input (`<identity key>#<index>`); use it as the
  /// Swift Charts `series:` value (AC-DF-130.3).
  public var id: String
  /// Sorted by (`measuredAt`, `refId`).
  public var points: [SeriesPoint]
  /// nil for the first segment of a series.
  public var breakBefore: SeriesBreak?

  public init(id: String, points: [SeriesPoint], breakBefore: SeriesBreak?) {
    self.id = id
    self.points = points
    self.breakBefore = breakBefore
  }
}
