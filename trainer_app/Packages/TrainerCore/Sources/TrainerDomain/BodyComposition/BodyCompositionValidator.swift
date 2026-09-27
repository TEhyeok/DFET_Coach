import Foundation
import TrainerContracts

public enum ValidationSeverity: String, Sendable {
  /// Blocks saving.
  case error
  /// Shown under the form; saving stays enabled (F-BC-03.3).
  case warning
}

/// A TR-11 input field an issue points at.
public enum BodyCompositionField: Hashable, Sendable {
  case value(BodyCompositionKey)
  case height
}

/// The closed range and unit of a numeric field, for `tr11.range.generic` ('{min}~{max}{unit} 사이로 입력하세요').
public struct InputRange: Hashable, Sendable {
  public let min: Double
  public let max: Double
  public let unit: MetricUnit

  public init(min: Double, max: Double, unit: MetricUnit) {
    self.min = min
    self.max = max
    self.unit = unit
  }

  /// `{min}` argument, e.g. "0.1".
  public var minText: String { NumberParser.displayText(min) }
  /// `{max}` argument, e.g. "600".
  public var maxText: String { NumberParser.displayText(max) }
  /// Deck key of the `{unit}` argument, e.g. `unit.kg` ('kg'), `unit.percent` ('%').
  public var unitCopyKey: String { "unit.\(unit.rawValue)" }
}

/// One TR-11 validation result, with the deck key its message uses.
public enum BodyCompositionIssue: Equatable, Hashable, Sendable {
  // Errors (AC-DF-127.1, .7)
  case deviceModelMissing
  /// Longer than 64 UTF-16 units after normalizing: the rules would refuse it (R-17).
  case deviceModelTooLong
  /// `measuredAt` more than 5 minutes after now (the rules' `measuredAtOk`, PRD §9.1).
  case measuredAtInFuture
  case fastingMissing
  /// Every value field is blank (F-BC-01.1).
  case noValue
  /// Not a plain number, or more than one decimal (V1-09 §10.1).
  case notANumber(BodyCompositionField)
  case outOfRange(BodyCompositionField, InputRange)
  // Warnings (AC-DF-127.8)
  case fatMassOverWeight
  case muscleOverWeight
  case fatPercentMismatch

  public var severity: ValidationSeverity {
    switch self {
    case .fatMassOverWeight, .muscleOverWeight, .fatPercentMismatch: return .warning
    default: return .error
    }
  }

  /// The field the message belongs under; nil for form-level messages.
  public var field: BodyCompositionField? {
    switch self {
    case let .notANumber(field), let .outOfRange(field, _): return field
    default: return nil
    }
  }

  /// `{min}`, `{max}`, `{unit}` of `tr11.range.generic`.
  public var range: InputRange? {
    if case let .outOfRange(_, range) = self { return range }
    return nil
  }

  /// Deck key (docs/v1/data/copy_ko.json) of the message.
  public var copyKey: String {
    switch self {
    case .deviceModelMissing: return "tr11.deviceModel.required"
    case .deviceModelTooLong: return "tr11.deviceModel.tooLong"
    case .measuredAtInFuture: return "tr11.measuredAt.future"
    case .fastingMissing: return "tr11.fasting.required"
    case .noValue: return "tr11.atLeastOne"
    case .notANumber: return "tr11.number.invalid"
    case .outOfRange: return "tr11.range.generic"
    case .fatMassOverWeight: return "tr11.cross.fatMassOverWeight"
    case .muscleOverWeight: return "tr11.cross.muscleOverWeight"
    case .fatPercentMismatch: return "tr11.cross.fatPercentMismatch"
    }
  }
}

/// A draft that passed validation: exactly what the record stores (V1-05 §4.7).
public struct BodyCompositionEntry: Equatable, Sendable {
  /// Only the measured keys; never an empty map (F-BC-03.1).
  public let values: [BodyCompositionKey: Double]
  /// Normalized (`DeviceModelName.normalize`).
  public let deviceModel: String
  public let measuredAt: Date
  public let fasting: Fasting
  public let timeOfDayBand: TimeOfDayBand
  /// Only with a trainer-entered height and a weight (AC-DF-127.5).
  public let derived: DerivedBMI?
  /// Cross-consistency warnings the trainer saw; they do not block saving.
  public let warnings: [BodyCompositionIssue]
}

/// The result of validating a draft. Everything the form shows while typing is here, even when saving is blocked.
public struct BodyCompositionValidation: Equatable, Sendable {
  /// Errors first (meta, then value fields in key order, then height, then 'no value'), then warnings.
  public let issues: [BodyCompositionIssue]
  /// Values that parsed and are in range, for live display.
  public let parsedValues: [BodyCompositionKey: Double]
  /// The BMI the read-only field shows; nil shows '미측정'.
  public let bmi: Double?
  /// Always computed from `measuredAt` (read-only field).
  public let timeOfDayBand: TimeOfDayBand
  /// Non-nil exactly when there is no error.
  public let entry: BodyCompositionEntry?

  public var errors: [BodyCompositionIssue] { issues.filter { $0.severity == .error } }
  public var warnings: [BodyCompositionIssue] { issues.filter { $0.severity == .warning } }
  /// The save button's enabled state as far as the input goes. Consent ② is checked separately
  /// (`EffectiveConsent.healthRecordSave`, AC-DF-127.4).
  public var canSave: Bool { entry != nil }
}

/// TR-11 validation (DF-127, V1-09 §10). Pure; `now` is injected.
public enum BodyCompositionValidator {
  /// `|bodyFatPercent − 100 × bodyFatMassKg / weightKg|` above this is a warning (ASM-P1a-13, TR-11 spec
  /// ASM-07-24). V1-09 §10.5 still says 2.0 (ASM-09-23); the P1a card decides for DF-127.
  public static let fatPercentMismatchThreshold = 5.0
  /// `measuredAt` may be at most this far after now (the rules' `measuredAtOk`, ASM-P0-19).
  public static let futureTolerance: TimeInterval = 5 * 60

  public static func validate(_ draft: BodyCompositionDraft, now: Date) -> BodyCompositionValidation {
    var errors: [BodyCompositionIssue] = []

    let device = DeviceModelName.normalize(draft.deviceModel ?? "")
    if device.isEmpty {
      errors.append(.deviceModelMissing)
    } else if !DeviceModelName.limit.contains(device.utf16.count) {
      errors.append(.deviceModelTooLong)
    }
    if draft.fasting == nil { errors.append(.fastingMissing) }
    if draft.measuredAt > now.addingTimeInterval(futureTolerance) { errors.append(.measuredAtInFuture) }

    var values: [BodyCompositionKey: Double] = [:]
    var anyValueText = false
    for key in BodyCompositionKey.allCases {
      let text = draft.values[key] ?? ""
      switch NumberParser.parse(text, maxFractionDigits: key.decimals) {
      case .empty:
        continue
      case .invalid:
        anyValueText = true
        errors.append(.notANumber(.value(key)))
      case let .value(value):
        anyValueText = true
        if key.appRange.contains(value) {
          values[key] = value
        } else {
          errors.append(.outOfRange(.value(key), InputRange(min: key.appRange.lowerBound, max: key.appRange.upperBound,
                                                            unit: key.unit)))
        }
      }
    }

    var heightCm: Double?
    switch NumberParser.parse(draft.heightCmInput ?? "", maxFractionDigits: BodyCompositionHeight.decimals) {
    case .empty:
      break
    case .invalid:
      errors.append(.notANumber(.height))
    case let .value(value):
      if BodyCompositionHeight.rangeCm.contains(value) {
        heightCm = value
      } else {
        let range = BodyCompositionHeight.rangeCm
        errors.append(.outOfRange(.height, InputRange(min: range.lowerBound, max: range.upperBound, unit: .cm)))
      }
    }

    if !anyValueText { errors.append(.noValue) }

    let warnings = crossWarnings(values)
    let bmi = BMICalculator.bmi(weightKg: values[.weightKg], heightCm: heightCm)
    let band = TimeOfDayBand(measuredAt: draft.measuredAt)

    var entry: BodyCompositionEntry?
    if errors.isEmpty, let fasting = draft.fasting {
      let derived = bmi.flatMap { bmi in
        heightCm.map { DerivedBMI(bmi: bmi, heightCmUsed: $0, heightMeasuredAt: draft.heightMeasuredAt ?? draft.measuredAt) }
      }
      entry = BodyCompositionEntry(values: values, deviceModel: device, measuredAt: draft.measuredAt, fasting: fasting,
                                   timeOfDayBand: band, derived: derived, warnings: warnings)
    }
    return BodyCompositionValidation(issues: errors + warnings, parsedValues: values, bmi: bmi, timeOfDayBand: band,
                                     entry: entry)
  }

  /// W-BC-01~03 (V1-09 §10.5), each only when its keys are present and valid.
  static func crossWarnings(_ values: [BodyCompositionKey: Double]) -> [BodyCompositionIssue] {
    var warnings: [BodyCompositionIssue] = []
    guard let weight = values[.weightKg] else { return warnings }
    if let fatMass = values[.bodyFatMassKg], fatMass > weight { warnings.append(.fatMassOverWeight) }
    if let muscle = values[.skeletalMuscleMassKg], muscle >= weight { warnings.append(.muscleOverWeight) }
    if let fatMass = values[.bodyFatMassKg], let percent = values[.bodyFatPercent],
      abs(percent - 100 * fatMass / weight) > fatPercentMismatchThreshold
    {
      warnings.append(.fatPercentMismatch)
    }
    return warnings
  }
}
