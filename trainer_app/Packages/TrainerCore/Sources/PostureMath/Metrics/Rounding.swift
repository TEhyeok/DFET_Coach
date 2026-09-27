import Foundation

/// Rounding shared by the three platforms (V1-09 §1.3, ASM-P1b-03): half away from zero on IEEE 754 doubles, the same
/// operation order everywhere, no epsilon. `-0.0` becomes `0.0`.
public enum Rounding {
  public static func roundHalfAway(_ value: Double, digits: Int) -> Double {
    let factor = pow(10.0, Double(digits))
    let rounded = (abs(value) * factor).rounded(.toNearestOrAwayFromZero) / factor * (value < 0 ? -1 : 1)
    return rounded == 0 ? 0 : rounded
  }

  /// One decimal place: the stored precision of every posture metric (F-ASM-03.6).
  public static func roundTenth(_ value: Double) -> Double {
    roundHalfAway(value, digits: 1)
  }
}
