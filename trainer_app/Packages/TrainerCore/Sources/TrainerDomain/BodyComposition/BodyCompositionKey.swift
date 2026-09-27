import Foundation
import TrainerContracts

/// A `bodyCompositionRecords.values` key (V1-05 §4.7, PRD appendix A.1). The raw value is the stored key and the
/// metric code. `bmi` is not here: it is derived and lives in `derived` (V1-09 §10.4).
public enum BodyCompositionKey: String, CaseIterable, Hashable, Sendable {
  case weightKg
  case bodyFatPercent
  case skeletalMuscleMassKg
  case bodyFatMassKg
  case visceralFatLevel
  case totalBodyWaterL

  public init?(metricCode: MetricCode) {
    self.init(rawValue: metricCode.rawValue)
  }

  public var metricCode: MetricCode { MetricCode(rawValue: rawValue)! }

  public var unit: MetricUnit { MetricCatalog.entry(for: metricCode).unit }

  /// Stored precision: one decimal for every key (V1-09 §1.3, the catalog's `decimals`).
  public var decimals: Int { MetricCatalog.entry(for: metricCode).decimals }

  /// The app's closed input range (V1-09 §10.2): the catalog's `appMin`…`max`. Inside the rules' range, so a value the
  /// app accepts is never refused by R-17/R-27.
  public var appRange: ClosedRange<Double> {
    let range = MetricCatalog.entry(for: metricCode).range!
    return range.appMin...range.max
  }

  /// Shown by default; the others open under `tr11.more` (F-BC-01.1).
  public var isPrimary: Bool {
    switch self {
    case .weightKg, .bodyFatPercent, .skeletalMuscleMassKg, .bodyFatMassKg: return true
    case .visceralFatLevel, .totalBodyWaterL: return false
    }
  }

  /// Deck key of the field label, e.g. `metric.weightKg.name`.
  public var nameCopyKey: String { "metric.\(rawValue).name" }
}

/// The trainer-entered height used for BMI (F-BC-01.3). Never `users.height` (AC-DF-127.3).
public enum BodyCompositionHeight {
  /// V1-05 §4.7 `derived.heightCmUsed` (rules `numIn(100, 250)`), V1-09 §10.2.
  public static let rangeCm: ClosedRange<Double> = 100...250
  public static let decimals = 1
}

/// Deck keys TR-11 needs that no domain value returns on its own.
public enum BodyCompositionCopy {
  /// '건강정보 동의 필요' next to the disabled save button (AC-DF-127.4).
  public static let consentNeeded = "tr11.consentNeeded"
  /// '미측정': BMI without a height, and empty values (AC-DF-127.5).
  public static let unmeasured = "common.unmeasured"
  public static let bmiName = "metric.bmi.name"
  /// '기기가 바뀌어 이전 기록과 비교할 수 없습니다' (`BodyCompositionSeries.deviceChanged`, DF-128).
  public static let deviceChanged = "tr11.deviceChanged"
}
