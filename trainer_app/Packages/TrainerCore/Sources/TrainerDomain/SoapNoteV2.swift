import Foundation
import TrainerContracts

// SOAP schema v2 domain model (DF-009, PRD §9.3, docs/v1/05_DATA_MODEL_AND_RULES.md §5).
// Encoding and decoding live in SoapNoteV2Codec.swift. The Dart twin is lib/models/soap_note_v2.dart (DF-007);
// both read and write the same contracts/fixtures/soap_v2 documents with the same meaning (NFR-07).
//
// Lossless rules shared by every type here:
// - A key the model does not know, or a known key whose value has the wrong type or an unknown enum value,
//   is kept in `extra` under the same key and written back as is. The typed property is then nil, which
//   screens show as 'uninterpretable' (해석 불가).
// - Absent and present-null are different (V1-10 §6.1). Properties that may hold null use `Nullable`:
//   a Swift `nil` means the key is absent, `.null` means the key is present with null.
// - An `objective.metrics` row is `.parsed` or `.unparsed(raw:)` (F-SOAP-06.2). A row is never dropped,
//   and an empty list stays empty: nothing fills it with demo text (F-SOAP-06.3).
// - Enums are the generated contract enums (TrainerContracts, English wire values only). Legacy Korean
//   notations never parse (SoapModels.swift:4-8 counterexample); legacy documents use `LegacySoapView`.

/// A key that is present in the document and may hold null. A property of type `Nullable<T>?` that is
/// itself nil means the key is absent.
public enum Nullable<Wrapped> {
  case null
  case value(Wrapped)

  /// The wrapped value, or nil for `.null`.
  public var value: Wrapped? {
    if case let .value(v) = self { return v }
    return nil
  }
}

extension Nullable: Equatable where Wrapped: Equatable {}
extension Nullable: Hashable where Wrapped: Hashable {}
extension Nullable: Sendable where Wrapped: Sendable {}

/// A Firestore timestamp field: a stored instant, or the server-time placeholder of a write payload.
public enum SoapTimestamp: Equatable, Hashable, Sendable {
  case instant(Date)
  case server
}

/// Whose record this is (V1-05 §3.3: `memberKey = memberUid ?? pendingMemberId`).
///
/// Encoded as `memberUid` and `pendingMemberId` (exactly one holds a value at create). A `.uid` also
/// writes the legacy `memberId` mirror with the same value during the compatibility period (§9.3, P0~P3).
public enum MemberKey: Hashable, Sendable {
  case uid(String)
  case pending(String)

  /// The key value (`memberUid` or `pendingMemberId`).
  public var id: String {
    switch self {
    case let .uid(id), let .pending(id): return id
    }
  }
}

/// `soap_notes/{noteId}` schema v2 (V1-05 §5.1).
public struct SoapNoteV2: Equatable, Sendable {
  /// Always 2. Documents without it are v1 and are read with `LegacySoapView` (V1-05 §5.6).
  public var schemaVersion: Int { 2 }

  public var trainerId: Nullable<String>?
  public var authorUid: String?

  /// Nil when the stored `memberUid`/`pendingMemberId`/`memberId` combination is not a v2 shape; the
  /// stored keys are then kept in `extra` unchanged.
  public var member: MemberKey?
  /// `.uid` only: `pendingMemberId` that a promoted record keeps next to `memberUid` (V1-05 §3.3).
  /// Nil writes `pendingMemberId: null`.
  public var promotedFromPendingMemberId: String?
  /// `.uid` only: whether the legacy `memberId` mirror is written (V1-05 §5.1, optional, P0~P3).
  public var writesLegacyMemberId: Bool

  public var sessionDate: SoapTimestamp?
  /// Nil when the key is absent or the value is unknown (the raw value is then in `extra`).
  public var status: SoapStatus?
  /// The Live one-liner, kept verbatim (F-SOAP-02.1).
  public var quickNote: String?
  public var inkPath: Nullable<String>?
  public var inkRevision: Int64?
  public var subjective: SoapSubjective?
  public var objective: SoapObjective?
  public var exerciseAssessment: ExerciseAssessment?
  public var plan: SoapPlan?
  public var memberNote: String?
  public var legalNature: String?
  /// Legacy flag. v2 writers write false only (D9).
  public var isSharedWithMember: Bool?
  public var finalizedAt: SoapTimestamp?
  public var createdAt: SoapTimestamp?
  public var updatedAt: SoapTimestamp?

  /// Server-only (P2 back reference). Read only; the Firestore target never writes it.
  public var memberSummaryId: Nullable<String>?
  /// Server-only migration marker `{runId, schemaVersion}`. Read only.
  public var migratedFrom: [String: JSONValue]?
  /// Server-only legacy originals `{metricsRaw, diagnosisRaw?, ...}`. Read only, never shown to members (MIG-04).
  public var legacy: [String: JSONValue]?

  /// Unknown top-level keys and known keys whose value could not be read.
  public var extra: [String: JSONValue]

  public init(
    trainerId: Nullable<String>? = nil,
    authorUid: String? = nil,
    member: MemberKey? = nil,
    promotedFromPendingMemberId: String? = nil,
    writesLegacyMemberId: Bool = true,
    sessionDate: SoapTimestamp? = nil,
    status: SoapStatus? = nil,
    quickNote: String? = nil,
    inkPath: Nullable<String>? = nil,
    inkRevision: Int64? = nil,
    subjective: SoapSubjective? = nil,
    objective: SoapObjective? = nil,
    exerciseAssessment: ExerciseAssessment? = nil,
    plan: SoapPlan? = nil,
    memberNote: String? = nil,
    legalNature: String? = nil,
    isSharedWithMember: Bool? = nil,
    finalizedAt: SoapTimestamp? = nil,
    createdAt: SoapTimestamp? = nil,
    updatedAt: SoapTimestamp? = nil,
    memberSummaryId: Nullable<String>? = nil,
    migratedFrom: [String: JSONValue]? = nil,
    legacy: [String: JSONValue]? = nil,
    extra: [String: JSONValue] = [:]
  ) {
    self.trainerId = trainerId
    self.authorUid = authorUid
    self.member = member
    self.promotedFromPendingMemberId = promotedFromPendingMemberId
    self.writesLegacyMemberId = writesLegacyMemberId
    self.sessionDate = sessionDate
    self.status = status
    self.quickNote = quickNote
    self.inkPath = inkPath
    self.inkRevision = inkRevision
    self.subjective = subjective
    self.objective = objective
    self.exerciseAssessment = exerciseAssessment
    self.plan = plan
    self.memberNote = memberNote
    self.legalNature = legalNature
    self.isSharedWithMember = isSharedWithMember
    self.finalizedAt = finalizedAt
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.memberSummaryId = memberSummaryId
    self.migratedFrom = migratedFrom
    self.legacy = legacy
    self.extra = extra
  }

  /// All `objective.metrics` rows, parsed or not, in stored order.
  public var metrics: [SoapMetricV2] { objective?.metrics ?? [] }

  /// Rows shown as 'uninterpretable' (해석 불가).
  public var uninterpretableMetricCount: Int { metrics.filter { !$0.isInterpretable }.count }
}

/// `subjective` (V1-05 §5.2).
public struct SoapSubjective: Equatable, Sendable {
  public var chiefComplaint: String?
  /// 0~10 integer. `.null` means 'not entered', which is different from 0 (AC-SOAP-01.7).
  public var painNrs: Nullable<Int64>?
  /// Wire values as stored. Unknown codes are kept (reading keeps the raw value).
  public var painRegions: [String]?
  public var extra: [String: JSONValue]

  public init(
    chiefComplaint: String? = nil, painNrs: Nullable<Int64>? = nil, painRegions: [String]? = nil,
    extra: [String: JSONValue] = [:]
  ) {
    self.chiefComplaint = chiefComplaint
    self.painNrs = painNrs
    self.painRegions = painRegions
    self.extra = extra
  }

  /// `painRegions` read with the contract vocab. Unknown codes are nil.
  public var painRegionCodes: [RegionCode?] { (painRegions ?? []).map { RegionCode(rawValue: $0) } }
}

/// `objective` (V1-05 §5.2).
public struct SoapObjective: Equatable, Sendable {
  public var metrics: [SoapMetricV2]?
  public var refs: ObjectiveRefs?
  public var snapshots: [ObjectiveSnapshot]?
  public var extra: [String: JSONValue]

  public init(
    metrics: [SoapMetricV2]? = nil, refs: ObjectiveRefs? = nil, snapshots: [ObjectiveSnapshot]? = nil,
    extra: [String: JSONValue] = [:]
  ) {
    self.metrics = metrics
    self.refs = refs
    self.snapshots = snapshots
    self.extra = extra
  }
}

/// One `objective.metrics[]` row (V1-05 §5.2).
///
/// `.parsed` when the metricCode is in the catalog and every enum field is a known wire value;
/// otherwise `.unparsed(raw:)` with the stored element, written back unchanged (F-SOAP-06.2).
public enum SoapMetricV2: Equatable, Sendable {
  case parsed(ParsedMetric)
  case unparsed(raw: JSONValue)

  /// False for rows shown as 'uninterpretable' (해석 불가).
  public var isInterpretable: Bool {
    if case .parsed = self { return true }
    return false
  }

  /// The raw `metricCode` of an unparsed object row whose code is a string.
  public var unparsedMetricCode: String? {
    if case let .unparsed(raw) = self { return raw["metricCode"]?.stringValue }
    return nil
  }
}

/// A metric row whose code and enum fields this version knows.
public struct ParsedMetric: Equatable, Sendable {
  public var metricCode: MetricCode
  /// `mmtGrade` values are integral and are written as integers (fixture tag `$int`); others as doubles.
  public var value: Double
  public var unit: MetricUnit
  public var side: Side
  public var sourceGrade: SourceGrade
  public var joint: Joint?
  public var motion: Motion?
  public var activeOrPassive: ActiveOrPassive?
  public var muscleGroup: MuscleGroup?
  public var note: String?
  /// Row keys this version does not know. Kept and written back.
  public var extra: [String: JSONValue]

  public init(
    metricCode: MetricCode, value: Double, unit: MetricUnit, side: Side, sourceGrade: SourceGrade,
    joint: Joint? = nil, motion: Motion? = nil, activeOrPassive: ActiveOrPassive? = nil,
    muscleGroup: MuscleGroup? = nil, note: String? = nil, extra: [String: JSONValue] = [:]
  ) {
    self.metricCode = metricCode
    self.value = value
    self.unit = unit
    self.side = side
    self.sourceGrade = sourceGrade
    self.joint = joint
    self.motion = motion
    self.activeOrPassive = activeOrPassive
    self.muscleGroup = muscleGroup
    self.note = note
    self.extra = extra
  }

  public var catalogEntry: MetricCatalogEntry { MetricCatalog.entry(for: metricCode) }

  /// Whether the row meets V1-05 §5.2 (catalog unit, sourceGrade, side rule and the romDeg/mmtGrade
  /// condition fields). Incomplete rows are shown as '미완성' and are not saved on finalize (F-SOAP-02.6).
  /// The codec keeps them either way. Same rule as the Dart `ParsedSoapMetric.isComplete`.
  public var isComplete: Bool {
    let entry = catalogEntry
    guard entry.storage.field == "objective.metrics", unit == entry.unit,
      entry.allowedSourceGrades.contains(sourceGrade)
    else { return false }
    switch entry.sideRule {
    case .leftRightBilateral: if side == .none { return false }
    case .leftRight: if side != .left && side != .right { return false }
    case .none: if side != .none { return false }
    case .magnitudeWithLowerSide, .magnitudeWithHigherSide, .undefinedV2: break
    }
    switch metricCode {
    case .romDeg: return joint != nil && motion != nil && activeOrPassive != nil
    case .mmtGrade: return muscleGroup != nil && value == value.rounded() && (0...5).contains(value)
    default: return true
    }
  }
}

/// `objective.refs` (V1-05 §5.2).
public struct ObjectiveRefs: Equatable, Sendable {
  public var postureAssessmentIds: [String]?
  public var bodyCompositionRecordIds: [String]?
  public var circumferenceMeasurementIds: [String]?
  public var bodyScanIds: [String]?
  public var extra: [String: JSONValue]

  public init(
    postureAssessmentIds: [String]? = nil, bodyCompositionRecordIds: [String]? = nil,
    circumferenceMeasurementIds: [String]? = nil, bodyScanIds: [String]? = nil, extra: [String: JSONValue] = [:]
  ) {
    self.postureAssessmentIds = postureAssessmentIds
    self.bodyCompositionRecordIds = bodyCompositionRecordIds
    self.circumferenceMeasurementIds = circumferenceMeasurementIds
    self.bodyScanIds = bodyScanIds
    self.extra = extra
  }

  /// All four lists present and empty: what a new note writes.
  public static let empty = ObjectiveRefs(
    postureAssessmentIds: [], bodyCompositionRecordIds: [], circumferenceMeasurementIds: [], bodyScanIds: [])
}

/// `objective.snapshots[]`: immutable copy of a referenced record value (PRD §7.8).
public struct ObjectiveSnapshot: Equatable, Sendable {
  public var refId: String?
  /// When nil, a stored `value` is kept in `extra` as read.
  public var metricCode: MetricCode?
  public var value: Double?
  public var unit: MetricUnit?
  public var side: Side?
  public var sourceGrade: SourceGrade?
  /// Always `pendingPolicy` before P3 (ADR-009).
  public var changeStatus: ChangeStatus?
  public var reasonCode: Nullable<ReasonCode>?
  public var policyVersion: Nullable<String>?
  public var mdcSource: Nullable<MdcSource>?
  public var measuredAt: SoapTimestamp?
  public var extra: [String: JSONValue]
  /// Set only when the stored element is not an object: the element as stored (possibly `.null`),
  /// written back unchanged. Every other property is then nil.
  public var element: JSONValue?

  public init(
    refId: String? = nil, metricCode: MetricCode? = nil, value: Double? = nil, unit: MetricUnit? = nil,
    side: Side? = nil, sourceGrade: SourceGrade? = nil, changeStatus: ChangeStatus? = nil,
    reasonCode: Nullable<ReasonCode>? = nil, policyVersion: Nullable<String>? = nil,
    mdcSource: Nullable<MdcSource>? = nil, measuredAt: SoapTimestamp? = nil, extra: [String: JSONValue] = [:],
    element: JSONValue? = nil
  ) {
    self.refId = refId
    self.metricCode = metricCode
    self.value = value
    self.unit = unit
    self.side = side
    self.sourceGrade = sourceGrade
    self.changeStatus = changeStatus
    self.reasonCode = reasonCode
    self.policyVersion = policyVersion
    self.mdcSource = mdcSource
    self.measuredAt = measuredAt
    self.extra = extra
    self.element = element
  }

  /// Whether the stored element was an object that could be read field by field.
  public var isReadable: Bool { element == nil }
}

/// `exerciseAssessment` (V1-05 §5.1).
public struct ExerciseAssessment: Equatable, Sendable {
  public var summary: String?
  public var observations: [String]?
  public var extra: [String: JSONValue]

  public init(summary: String? = nil, observations: [String]? = nil, extra: [String: JSONValue] = [:]) {
    self.summary = summary
    self.observations = observations
    self.extra = extra
  }
}

/// `plan` (V1-05 §5.1).
public struct SoapPlan: Equatable, Sendable {
  public var nextSession: String?
  public var homeExercise: String?
  public var extra: [String: JSONValue]

  public init(nextSession: String? = nil, homeExercise: String? = nil, extra: [String: JSONValue] = [:]) {
    self.nextSession = nextSession
    self.homeExercise = homeExercise
    self.extra = extra
  }
}
