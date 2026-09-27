import Foundation
import TrainerContracts

/// What the TR-11 form holds while the trainer types (DF-127 implementation note). Values stay text until
/// `BodyCompositionValidator` reads them, so a half-typed "62," is never turned into a number early.
public struct BodyCompositionDraft: Equatable, Sendable {
  /// Input text per key. A missing or blank entry is unmeasured and never becomes 0 (F-BC-03.1).
  public var values: [BodyCompositionKey: String]
  /// From the device list; the form preselects the member's latest active record's device, else the trainer's most
  /// recently used one (V1-09 §10.3). nil or blank means none chosen yet.
  public var deviceModel: String?
  /// When the member was measured; defaults to now in the form and stays editable. Not the save time (AC-DF-127.2).
  public var measuredAt: Date
  /// No default: yes or no must be chosen; `unknown` is only in the secondary menu (AC-DF-127.9).
  public var fasting: Fasting?
  /// The trainer-entered height in cm (F-BC-01.3). Shown only with consent ② (ASM-P1a-41); never `users.height`.
  public var heightCmInput: String?
  /// When that height was measured. nil means with this record, so `measuredAt` is used. A height carried over from
  /// an earlier record keeps that record's date (V1-09 §10.4, ASM-09-22).
  public var heightMeasuredAt: Date?

  public init(
    values: [BodyCompositionKey: String] = [:], deviceModel: String? = nil, measuredAt: Date, fasting: Fasting? = nil,
    heightCmInput: String? = nil, heightMeasuredAt: Date? = nil
  ) {
    self.values = values
    self.deviceModel = deviceModel
    self.measuredAt = measuredAt
    self.fasting = fasting
    self.heightCmInput = heightCmInput
    self.heightMeasuredAt = heightMeasuredAt
  }
}

/// `deviceModel` as it is stored and compared (V1-09 §8.1 `normalizeDevice`).
public enum DeviceModelName {
  /// 1~64, counted as the rules' `strRange(deviceModel, 1, 64)` counts: UTF-16 code units (R-17).
  public static let limit = 1...64

  /// Trimmed, runs of white space collapsed to one space, NFC. Case is kept (ASM-09-13).
  public static func normalize(_ text: String) -> String {
    text.precomposedStringWithCanonicalMapping
      .split(whereSeparator: { $0.isWhitespace })
      .joined(separator: " ")
  }
}
