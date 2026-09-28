import Foundation
import TrainerContracts

/// BMI from the record's weight and the height the trainer entered (F-BC-01.3, V1-09 §10.4). The member-edited
/// `users.height`/`users.weight` are never an input (AC-DF-127.3).
public enum BMICalculator {
  /// `weightKg / (heightCm / 100)^2`, rounded half away from zero to one decimal. nil when either input is missing,
  /// the weight is not positive, or the height is outside 100~250 cm: then there is no `derived` map and the BMI
  /// field shows '미측정' (AC-DF-127.5).
  ///
  /// Also nil when the rounded result is outside the catalog's `bmi` range, the rules' `numPosMax(derived.bmi, 200)`:
  /// above 200 (e.g. 600 kg at 100 cm), or 0.0 after rounding (e.g. 0.1 kg at 250 cm, 0.016). Such a `derived` map
  /// would make the server refuse the whole record, while the values themselves are valid.
  public static func bmi(weightKg: Double?, heightCm: Double?) -> Double? {
    guard let weightKg, let heightCm, weightKg.isFinite, weightKg > 0, heightCm.isFinite,
      BodyCompositionHeight.rangeCm.contains(heightCm)
    else { return nil }
    // The V1-09 operation order, so Swift, Dart and JS give the same bits.
    let bmi = DomainRounding.roundHalfAway(weightKg / pow(heightCm / 100, 2), digits: 1)
    return isInRange(bmi) ? bmi : nil
  }

  /// The catalog's `bmi` range maximum (the rules' limit).
  public static let maximum: Double = MetricCatalog.entry(for: .bmi).range?.max ?? 200
  /// The catalog's `bmi` range minimum, exclusive: the rules' `v > 0`.
  public static let minimum: Double = MetricCatalog.entry(for: .bmi).range?.min ?? 0

  /// Inside the catalog's `bmi` range (`minimum` exclusive or inclusive as the catalog says, `maximum` inclusive).
  static func isInRange(_ bmi: Double) -> Bool {
    let aboveMinimum = (MetricCatalog.entry(for: .bmi).range?.minExclusive ?? true) ? bmi > minimum : bmi >= minimum
    return aboveMinimum && bmi <= maximum
  }
}

/// `bodyCompositionRecords.derived` (V1-05 §4.7): written only when the trainer entered a height and a weight.
/// `sourceGrade` is always `derived`.
public struct DerivedBMI: Equatable, Sendable {
  public let bmi: Double
  public let heightCmUsed: Double
  public let heightMeasuredAt: Date

  public init(bmi: Double, heightCmUsed: Double, heightMeasuredAt: Date) {
    self.bmi = bmi
    self.heightCmUsed = heightCmUsed
    self.heightMeasuredAt = heightMeasuredAt
  }
}
