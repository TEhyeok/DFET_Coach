import Foundation

/// `pendingMembers.sex` (V1-05 §4.3). The contracts vocab has no `sex` enum, so it lives here.
public enum Sex: String, CaseIterable, Sendable {
  case female
  case male
  case unspecified
}

/// What TR-14 registration collects (F-LINK-01.1): nothing else. No contact details (F-LINK-01.4), no height before
/// consent ② (R-30).
public struct PendingMemberDraft: Equatable, Sendable {
  public var displayName: String
  /// No default choice (AC-DF-108.1).
  public var sex: Sex?
  public var birthYear: Int?
  public var ageConfirmed14: Bool

  public init(displayName: String = "", sex: Sex? = nil, birthYear: Int? = nil, ageConfirmed14: Bool = false) {
    self.displayName = displayName
    self.sex = sex
    self.birthYear = birthYear
    self.ageConfirmed14 = ageConfirmed14
  }

  /// `displayName` trimmed and in NFC, as it is stored.
  public var trimmedName: String {
    displayName.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
  }

  /// 1-40, counted as the rules count (`strRange(displayName, 1, 40)`, V1-05 §4.3): UTF-16 code units. A Hangul
  /// syllable is one unit, most emoji are two or more, so a name the rules would refuse is never saved.
  public static let nameLimit = 1...40
}

/// Whether a birth year may be registered (F-LINK-01.8, AC-DF-108.2).
///
/// The rules allow `birthYear <= year - 14` (R-31). The app is stricter by one year, `birthYear <= year - 15`, so a
/// member who may still be 13 this year is never registered (ASM-P1a-02). The year is the Asia/Seoul calendar year.
public enum AgeGate {
  public static let minimumBirthYear = 1900
  public static let seoul = TimeZone(identifier: "Asia/Seoul")!

  public static func currentYear(now: Date) -> Int {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = seoul
    return calendar.component(.year, from: now)
  }

  public static func isEligible(birthYear: Int, now: Date) -> Bool {
    birthYear >= minimumBirthYear && birthYear <= currentYear(now: now) - 15
  }
}

/// Why a draft cannot be saved yet.
public enum PendingMemberDraftProblem: Equatable, Sendable {
  case nameMissingOrTooLong
  case sexNotChosen
  case birthYearMissing
  case under14
  case ageNotConfirmed
}

public extension PendingMemberDraft {
  func problems(now: Date) -> [PendingMemberDraftProblem] {
    var problems: [PendingMemberDraftProblem] = []
    if !Self.nameLimit.contains(trimmedName.utf16.count) { problems.append(.nameMissingOrTooLong) }
    if sex == nil { problems.append(.sexNotChosen) }
    if let birthYear {
      if !AgeGate.isEligible(birthYear: birthYear, now: now) { problems.append(.under14) }
    } else {
      problems.append(.birthYearMissing)
    }
    if !ageConfirmed14 { problems.append(.ageNotConfirmed) }
    return problems
  }
}

/// The `pendingMembers/{id}` create payload (V1-05 §4.3, AC-DF-108.1). Exactly the rules' nine keys: the writer adds
/// `createdAt` and `updatedAt` as server time, so they are not here.
public enum PendingMemberPayload {
  public static let collection = "pendingMembers"
  /// Keys of the stored document, `createdAt` and `updatedAt` included (the rules' `pendingCreateKeys()`).
  public static let documentKeys: Set<String> = [
    "trainerId", "displayName", "sex", "birthYear", "ageConfirmed14", "status", "schemaVersion", "createdAt",
    "updatedAt",
  ]

  public static func path(id: String) -> String {
    "\(collection)/\(id)"
  }

  /// The cancel update (F-LINK-01.5, AC-DF-113.6, V1-05 §4.3): `status` only. The writer adds `updatedAt` as server
  /// time; `cancelledAt` is a server field, so the app never writes it.
  public static let cancelFields: JSONValue = .object(["status": .string("cancelled")])

  /// nil when the draft has a problem.
  public static func fields(_ draft: PendingMemberDraft, trainerUid: String, now: Date) -> JSONValue? {
    guard draft.problems(now: now).isEmpty, let sex = draft.sex, let birthYear = draft.birthYear else { return nil }
    return .object([
      "trainerId": .string(trainerUid),
      "displayName": .string(draft.trimmedName),
      "sex": .string(sex.rawValue),
      "birthYear": .int(Int64(birthYear)),
      "ageConfirmed14": .bool(true),
      "status": .string("pending"),
      "schemaVersion": .int(1),
    ])
  }
}

/// Registers a pending member (TR-14, DF-108). The member exists on the device at once, offline too; the server
/// document is created through the Outbox (stage 0), before any record or consent capture of that member.
public protocol PendingMemberRegistrar: Sendable {
  /// Returns the new `pendingMemberId`. Throws `PendingMemberRegistrationError.invalidDraft` for a draft with
  /// problems, or the local store's error when the member could not be saved on the device.
  func register(_ draft: PendingMemberDraft) async throws -> String
}

public enum PendingMemberRegistrationError: Error, Equatable, Sendable {
  case invalidDraft
}

/// Cancels a pending member's registration (F-LINK-01.5): TR-02's row menu '등록 취소' (AC-DF-113.6) and a refused ①
/// in TR-14 (AC-DF-110.5). The cancel is saved on the device at once, offline too, and TR-02 no longer lists the
/// member; `pendingMembers/{id}` becomes `status: 'cancelled'` through the Outbox (stage 0, after the member's create
/// and before anything else of that member that is still unsent).
public protocol PendingMemberCanceller: Sendable {
  /// Throws the local store's error when the cancel could not be saved on the device.
  func cancel(pendingMemberId: String) async throws
}
