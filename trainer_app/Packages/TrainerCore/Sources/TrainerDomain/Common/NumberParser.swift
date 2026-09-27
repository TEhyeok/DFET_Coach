import Foundation

/// Trainer number input (V1-09 §10.1; the BodyPath rule of WellnessModels.swift:65-77). Shared by TR-11 body
/// composition (DF-127) and, when DF-121 lands, the TR-05 objective rows.
///
/// - Leading and trailing white space is ignored (full-width U+3000 too). Blank text is `.empty`: unmeasured, never 0.
/// - A comma is a decimal point, never a thousands separator: "62,4" is 62.4 and "1,234.5" is refused.
/// - Only ASCII digits with at most one decimal point are accepted. Signs, exponents, units ("62kg", "45도"), a leading
///   or trailing point and non-ASCII digits are `.invalid`: the parser never guesses.
/// - Extra decimals are refused, not rounded (ASM-09-21): with `maxFractionDigits: 1`, "62.45" is `.invalid`.
/// - Range checks belong to the caller (`BodyCompositionValidator`), because the message names the range.
public enum NumberParser {
  public enum Result: Equatable, Sendable {
    /// Blank input: the field was not measured.
    case empty
    case value(Double)
    /// Not a plain decimal number, or more decimals than allowed.
    case invalid
  }

  /// - Parameter maxFractionDigits: the most digits allowed after the point; nil for no limit, 0 for integers only.
  public static func parse(_ text: String, maxFractionDigits: Int? = nil) -> Result {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return .empty }
    let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
    let parts = normalized.split(separator: ".", maxSplits: 2, omittingEmptySubsequences: false)
    guard parts.count <= 2, let whole = parts.first, isASCIIDigits(whole) else { return .invalid }
    if parts.count == 2 {
      let fraction = parts[1]
      guard isASCIIDigits(fraction) else { return .invalid }
      if let maxFractionDigits, fraction.count > maxFractionDigits { return .invalid }
    }
    guard let value = Double(normalized), value.isFinite else { return .invalid }
    return .value(value)
  }

  /// The value, or nil for blank and invalid text. Use `parse` when the two must be told apart.
  public static func double(_ text: String, maxFractionDigits: Int? = nil) -> Double? {
    if case let .value(value) = parse(text, maxFractionDigits: maxFractionDigits) { return value }
    return nil
  }

  /// Locale-free short text for a range bound or a stored value: 600 → "600", 0.1 → "0.1", 22.9 → "22.9". Used for
  /// the `{min}`/`{max}` arguments of `tr11.range.generic`.
  public static func displayText(_ value: Double) -> String {
    guard value.isFinite else { return "" }
    if value == value.rounded(), abs(value) < 1e15 { return String(Int64(value)) }
    return "\(value)"
  }

  private static func isASCIIDigits(_ text: Substring) -> Bool {
    !text.isEmpty && text.utf8.allSatisfy { $0 >= 0x30 && $0 <= 0x39 }
  }
}

/// Half away from zero on IEEE 754 doubles, no epsilon (V1-09 §1.3, ASM-P1b-03); `-0.0` becomes `0.0`. The same rule
/// as PostureMath's `Rounding`, kept internal here so the two public names never clash for a module importing both.
enum DomainRounding {
  static func roundHalfAway(_ value: Double, digits: Int) -> Double {
    let factor = pow(10.0, Double(digits))
    let rounded = (abs(value) * factor).rounded(.toNearestOrAwayFromZero) / factor * (value < 0 ? -1 : 1)
    return rounded == 0 ? 0 : rounded
  }
}
