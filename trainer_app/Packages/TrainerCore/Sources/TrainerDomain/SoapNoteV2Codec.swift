import Foundation
import TrainerContracts

// SoapNoteV2 <-> JSONValue codec (DF-009, PRD §9.3, docs/v1/05_DATA_MODEL_AND_RULES.md §5).
// Same rules as the Dart codec (lib/models/soap_note_v2_codec.dart, DF-007), so both clients read and
// write a document with the same meaning (NFR-07). Firestore SDK types are mapped to JSONValue by
// FirebaseData (DF-104); this file only sees JSONValue.
//
// Encoding has two targets:
// - `.firestore`: a client write payload. Limited to the client write whitelist (V1-05 §7.3
//   soapCreateKeys + finalizedAt, nested hasOnly maps). Server-only fields (memberSummaryId, migratedFrom,
//   legacy), unknown top-level keys and unknown nested keys are left out. A known key whose value could
//   not be read is written back unchanged, and list elements (metrics rows, snapshots) are never dropped.
// - `.fixture`: the cross-client fixture notation. Everything that was read is written back, so
//   decode -> encode is identical (AC-DF-009.1).

/// Where an encoded document goes.
public enum SoapCodecTarget: Sendable {
  /// A Firestore write payload (client whitelist).
  case firestore
  /// The cross-client fixture notation (contracts/fixtures/**): everything is written back.
  case fixture
}

/// Decodes and encodes `soap_notes` schema v2 documents.
public enum SoapNoteV2Codec {
  public enum DecodingError: Error, Equatable, Sendable {
    /// The document has no `schemaVersion: 2`. Read v1 documents with `LegacySoapView`.
    case notV2(schemaVersion: JSONValue?)
    case notAnObject
  }

  /// Top-level keys a client may write (V1-05 §7.3 `soapCreateKeys()` + `finalizedAt`).
  public static let clientWritableKeys: Set<String> = [
    "schemaVersion", "trainerId", "authorUid", "memberUid", "pendingMemberId", "memberId", "isSharedWithMember",
    "sessionDate", "status", "quickNote", "inkPath", "inkRevision", "subjective", "objective",
    "exerciseAssessment", "plan", "memberNote", "legalNature", "finalizedAt", "createdAt", "updatedAt",
  ]

  /// Fields only the server writes. Read, never written by the `.firestore` target.
  public static let serverOnlyKeys: Set<String> = ["memberSummaryId", "migratedFrom", "legacy"]

  // Nested key allowlists: the rules' `keys().hasOnly(...)` lists (V1-05 §7.3).
  static let subjectiveKeys: Set<String> = ["chiefComplaint", "painNrs", "painRegions"]
  static let objectiveKeys: Set<String> = ["metrics", "refs", "snapshots"]
  static let refsKeys: Set<String> = [
    "postureAssessmentIds", "bodyCompositionRecordIds", "circumferenceMeasurementIds", "bodyScanIds",
  ]
  static let exerciseAssessmentKeys: Set<String> = ["summary", "observations"]
  static let planKeys: Set<String> = ["nextSession", "homeExercise"]
  static let metricKeys: Set<String> = [
    "metricCode", "value", "unit", "side", "sourceGrade", "joint", "motion", "activeOrPassive", "muscleGroup", "note",
  ]

  /// Field order for written fixtures (V1-05 §5.1/§5.2 order, the order the Dart codec writes).
  /// Keys never share a map with an earlier-ranked key of another map, so one list serves every level.
  public static let fixtureKeyOrder: [String] = [
    "schemaVersion", "trainerId", "authorUid", "memberUid", "memberId", "pendingMemberId", "sessionDate", "status",
    "quickNote", "inkPath", "inkRevision",
    "subjective", "chiefComplaint", "painNrs", "painRegions",
    "objective", "metrics", "refId", "metricCode", "value", "unit", "side", "sourceGrade", "joint", "motion",
    "activeOrPassive", "muscleGroup", "note", "changeStatus", "reasonCode", "policyVersion", "mdcSource",
    "measuredAt", "refs", "postureAssessmentIds", "bodyCompositionRecordIds", "circumferenceMeasurementIds",
    "bodyScanIds", "snapshots",
    "exerciseAssessment", "summary", "observations", "plan", "nextSession", "homeExercise", "memberNote",
    "legalNature", "isSharedWithMember", "finalizedAt", "createdAt", "updatedAt", "memberSummaryId",
    "migratedFrom", "legacy",
  ]

  /// Whether `value` is a schema v2 document (`schemaVersion` == 2).
  public static func isV2(_ value: JSONValue) -> Bool {
    value["schemaVersion"]?.doubleValue == 2
  }

  /// Decodes a v2 document. Throws when `value` is not an object with `schemaVersion: 2`.
  public static func decode(_ value: JSONValue) throws -> SoapNoteV2 {
    guard let object = value.objectValue else { throw DecodingError.notAnObject }
    guard isV2(value) else { throw DecodingError.notV2(schemaVersion: object["schemaVersion"]) }
    var r = ObjectReader(object)
    _ = r.take("schemaVersion")
    var note = SoapNoteV2(
      trainerId: r.nullableString("trainerId"),
      authorUid: r.string("authorUid"))
    decodeMember(&r, into: &note)
    note.sessionDate = r.timestamp("sessionDate")
    note.status = r.enumValue("status", SoapStatus.self)
    note.quickNote = r.string("quickNote")
    note.inkPath = r.nullableString("inkPath")
    note.inkRevision = r.integer("inkRevision")
    note.subjective = r.object("subjective", subjective)
    note.objective = r.object("objective", objective)
    note.exerciseAssessment = r.object("exerciseAssessment", exerciseAssessment)
    note.plan = r.object("plan", plan)
    note.memberNote = r.string("memberNote")
    note.legalNature = r.string("legalNature")
    note.isSharedWithMember = r.bool("isSharedWithMember")
    note.finalizedAt = r.timestamp("finalizedAt")
    note.createdAt = r.timestamp("createdAt")
    note.updatedAt = r.timestamp("updatedAt")
    note.memberSummaryId = r.nullableString("memberSummaryId")
    note.migratedFrom = r.rawObject("migratedFrom")
    note.legacy = r.rawObject("legacy")
    note.extra = r.finish()
    return note
  }

  /// Encodes `note` for `target`.
  ///
  /// The `.firestore` output is a create payload, or an `update()` / `setData(merge: true)` payload. It is
  /// not a full-document replace: it leaves out server-only and unknown top-level keys, so a replace of a
  /// stored document that has `memberSummaryId`, `migratedFrom` or `legacy` would delete them. The rules
  /// reject such a write (V1-05 §7.3), so the mistake fails safely, but do not rely on it.
  public static func encode(_ note: SoapNoteV2, target: SoapCodecTarget = .firestore) -> JSONValue {
    let w = Writer(target: target)
    var out: [String: JSONValue] = [
      // Firestore stores schemaVersion as an integer; the fixture notation writes it as a bare number.
      "schemaVersion": target == .fixture ? .number(Double(note.schemaVersion)) : .int(Int64(note.schemaVersion))
    ]
    out["trainerId"] = note.trainerId.map(nullableString)
    out["authorUid"] = note.authorUid.map(JSONValue.string)
    encodeMember(note, into: &out)
    out["sessionDate"] = note.sessionDate.map(timestamp)
    out["status"] = note.status.map { .string($0.rawValue) }
    out["quickNote"] = note.quickNote.map(JSONValue.string)
    out["inkPath"] = note.inkPath.map(nullableString)
    out["inkRevision"] = note.inkRevision.map(JSONValue.int)
    out["subjective"] = note.subjective.map { encodeSubjective($0, w) }
    out["objective"] = note.objective.map { encodeObjective($0, w) }
    out["exerciseAssessment"] = note.exerciseAssessment.map { encodeExerciseAssessment($0, w) }
    out["plan"] = note.plan.map { encodePlan($0, w) }
    out["memberNote"] = note.memberNote.map(JSONValue.string)
    out["legalNature"] = note.legalNature.map(JSONValue.string)
    out["isSharedWithMember"] = note.isSharedWithMember.map(JSONValue.bool)
    out["finalizedAt"] = note.finalizedAt.map(timestamp)
    out["createdAt"] = note.createdAt.map(timestamp)
    out["updatedAt"] = note.updatedAt.map(timestamp)
    out["memberSummaryId"] = note.memberSummaryId.map(nullableString)
    out["migratedFrom"] = note.migratedFrom.map(JSONValue.object)
    out["legacy"] = note.legacy.map(JSONValue.object)
    out.merge(note.extra) { _, extra in extra }
    if target == .firestore {
      out = out.filter { clientWritableKeys.contains($0.key) }
    }
    return .object(out)
  }

  // MARK: Member keys

  /// v2 shapes (V1-05 §3.3, §5.1): `memberUid` string with `pendingMemberId` null (or the promoted
  /// pending ID) and `memberId` absent or equal; or `memberUid` null, `pendingMemberId` string and no
  /// `memberId`. Anything else keeps all three stored keys in `extra` and leaves `member` nil.
  private static func decodeMember(_ r: inout ObjectReader, into note: inout SoapNoteV2) {
    let uid = r.take("memberUid")
    let mirror = r.take("memberId")
    let pending = r.take("pendingMemberId")
    switch (uid, pending, mirror) {
    case let (.string(u)?, .null?, nil):
      note.member = .uid(u)
      note.writesLegacyMemberId = false
    case let (.string(u)?, .null?, .string(m)?) where m == u:
      note.member = .uid(u)
    case let (.string(u)?, .string(p)?, nil):
      note.member = .uid(u)
      note.promotedFromPendingMemberId = p
      note.writesLegacyMemberId = false
    case let (.string(u)?, .string(p)?, .string(m)?) where m == u:
      note.member = .uid(u)
      note.promotedFromPendingMemberId = p
    case let (.null?, .string(p)?, nil):
      note.member = .pending(p)
    default:
      for (key, value) in [("memberUid", uid), ("memberId", mirror), ("pendingMemberId", pending)] where value != nil {
        r.keep(key)
      }
    }
  }

  private static func encodeMember(_ note: SoapNoteV2, into out: inout [String: JSONValue]) {
    switch note.member {
    case let .uid(u)?:
      out["memberUid"] = .string(u)
      if note.writesLegacyMemberId { out["memberId"] = .string(u) }
      out["pendingMemberId"] = note.promotedFromPendingMemberId.map(JSONValue.string) ?? .null
    case let .pending(p)?:
      out["memberUid"] = .null
      out["pendingMemberId"] = .string(p)
    case nil:
      break
    }
  }

  // MARK: Nested maps

  private static func subjective(_ r: inout ObjectReader) -> SoapSubjective {
    SoapSubjective(
      chiefComplaint: r.string("chiefComplaint"),
      painNrs: r.nullableInteger("painNrs"),
      painRegions: r.stringList("painRegions"),
      extra: r.finish())
  }

  private static func encodeSubjective(_ s: SoapSubjective, _ w: Writer) -> JSONValue {
    var out: [String: JSONValue] = [:]
    out["chiefComplaint"] = s.chiefComplaint.map(JSONValue.string)
    out["painNrs"] = s.painNrs.map { $0.value.map(JSONValue.int) ?? .null }
    out["painRegions"] = s.painRegions.map { .array($0.map(JSONValue.string)) }
    return w.nested(out, extra: s.extra, allowed: subjectiveKeys)
  }

  private static func objective(_ r: inout ObjectReader) -> SoapObjective {
    SoapObjective(
      metrics: r.list("metrics", metric),
      refs: r.object("refs", refs),
      snapshots: r.list("snapshots", snapshot),
      extra: r.finish())
  }

  private static func encodeObjective(_ o: SoapObjective, _ w: Writer) -> JSONValue {
    var out: [String: JSONValue] = [:]
    out["metrics"] = o.metrics.map { .array($0.map(encodeMetric)) }
    out["refs"] = o.refs.map { encodeRefs($0, w) }
    out["snapshots"] = o.snapshots.map { .array($0.map(encodeSnapshot)) }
    return w.nested(out, extra: o.extra, allowed: objectiveKeys)
  }

  /// A row is parsed only when every known key reads cleanly; otherwise the whole row is kept as
  /// `.unparsed(raw:)` (F-SOAP-06.2). An element that is not an object is unparsed as well.
  static func metric(_ element: JSONValue) -> SoapMetricV2 {
    guard let raw = element.objectValue else { return .unparsed(raw: element) }
    let code = raw["metricCode"]?.stringValue.flatMap(MetricCode.init(rawValue:))
    guard let code,
      let unit = raw["unit"]?.stringValue.flatMap(MetricUnit.init(rawValue:)),
      let side = raw["side"]?.stringValue.flatMap(Side.init(rawValue:)),
      let sourceGrade = raw["sourceGrade"]?.stringValue.flatMap(SourceGrade.init(rawValue:)),
      let value = metricValue(code, raw["value"]),
      let joint = optionalEnum(raw["joint"], Joint.self),
      let motion = optionalEnum(raw["motion"], Motion.self),
      let activeOrPassive = optionalEnum(raw["activeOrPassive"], ActiveOrPassive.self),
      let muscleGroup = optionalEnum(raw["muscleGroup"], MuscleGroup.self),
      let note = optionalString(raw["note"])
    else { return .unparsed(raw: element) }
    return .parsed(
      ParsedMetric(
        metricCode: code, value: value, unit: unit, side: side, sourceGrade: sourceGrade,
        joint: joint, motion: motion, activeOrPassive: activeOrPassive, muscleGroup: muscleGroup, note: note,
        extra: raw.filter { !metricKeys.contains($0.key) }))
  }

  /// Integer metrics (fixture rule 2 `$int` list: the `mmtGrade` value). A non-integral value there cannot
  /// be written back as an integer, so the row stays unparsed.
  private static func metricValue(_ code: MetricCode, _ value: JSONValue?) -> Double? {
    guard let value else { return nil }
    if isIntegerMetric(code) { return value.integerValue.map(Double.init) }
    return value.doubleValue
  }

  static func isIntegerMetric(_ code: MetricCode?) -> Bool { code == .mmtGrade }

  /// `.some(nil)` when the key is absent, `.some(value)` when it parses, nil when it is present but unreadable.
  private static func optionalEnum<E: RawRepresentable>(_ value: JSONValue?, _: E.Type) -> E?? where E.RawValue == String {
    guard let value else { return .some(nil) }
    guard let parsed = value.stringValue.flatMap(E.init(rawValue:)) else { return nil }
    return .some(parsed)
  }

  private static func optionalString(_ value: JSONValue?) -> String?? {
    guard let value else { return .some(nil) }
    guard let text = value.stringValue else { return nil }
    return .some(text)
  }

  private static func encodeMetric(_ metric: SoapMetricV2) -> JSONValue {
    switch metric {
    case let .unparsed(raw):
      return raw
    case let .parsed(m):
      var out: [String: JSONValue] = [
        "metricCode": .string(m.metricCode.rawValue),
        "value": number(m.value, integer: isIntegerMetric(m.metricCode)),
        "unit": .string(m.unit.rawValue),
        "side": .string(m.side.rawValue),
        "sourceGrade": .string(m.sourceGrade.rawValue),
      ]
      out["joint"] = m.joint.map { .string($0.rawValue) }
      out["motion"] = m.motion.map { .string($0.rawValue) }
      out["activeOrPassive"] = m.activeOrPassive.map { .string($0.rawValue) }
      out["muscleGroup"] = m.muscleGroup.map { .string($0.rawValue) }
      out["note"] = m.note.map(JSONValue.string)
      // Array elements are not checked by the rules, so row extras are kept for both targets (V1-05 §5.2).
      out.merge(m.extra) { _, extra in extra }
      return .object(out)
    }
  }

  private static func refs(_ r: inout ObjectReader) -> ObjectiveRefs {
    ObjectiveRefs(
      postureAssessmentIds: r.stringList("postureAssessmentIds"),
      bodyCompositionRecordIds: r.stringList("bodyCompositionRecordIds"),
      circumferenceMeasurementIds: r.stringList("circumferenceMeasurementIds"),
      bodyScanIds: r.stringList("bodyScanIds"),
      extra: r.finish())
  }

  private static func encodeRefs(_ refs: ObjectiveRefs, _ w: Writer) -> JSONValue {
    var out: [String: JSONValue] = [:]
    out["postureAssessmentIds"] = refs.postureAssessmentIds.map { .array($0.map(JSONValue.string)) }
    out["bodyCompositionRecordIds"] = refs.bodyCompositionRecordIds.map { .array($0.map(JSONValue.string)) }
    out["circumferenceMeasurementIds"] = refs.circumferenceMeasurementIds.map { .array($0.map(JSONValue.string)) }
    out["bodyScanIds"] = refs.bodyScanIds.map { .array($0.map(JSONValue.string)) }
    return w.nested(out, extra: refs.extra, allowed: refsKeys)
  }

  /// A snapshot element that is not an object is kept in place as `ObjectiveSnapshot.element`.
  private static func snapshot(_ element: JSONValue) -> ObjectiveSnapshot {
    guard let object = element.objectValue else { return ObjectiveSnapshot(element: element) }
    var r = ObjectReader(object)
    var s = ObjectiveSnapshot(refId: r.string("refId"), metricCode: r.enumValue("metricCode", MetricCode.self))
    // Without a known code the value's notation is unknown, so it stays in extra as read.
    if let code = s.metricCode { s.value = r.number("value", integer: isIntegerMetric(code)) }
    s.unit = r.enumValue("unit", MetricUnit.self)
    s.side = r.enumValue("side", Side.self)
    s.sourceGrade = r.enumValue("sourceGrade", SourceGrade.self)
    s.changeStatus = r.enumValue("changeStatus", ChangeStatus.self)
    s.reasonCode = r.nullableEnum("reasonCode", ReasonCode.self)
    s.policyVersion = r.nullableString("policyVersion")
    s.mdcSource = r.nullableEnum("mdcSource", MdcSource.self)
    s.measuredAt = r.timestamp("measuredAt")
    s.extra = r.finish()
    return s
  }

  private static func encodeSnapshot(_ s: ObjectiveSnapshot) -> JSONValue {
    if let element = s.element { return element }
    var out: [String: JSONValue] = [:]
    out["refId"] = s.refId.map(JSONValue.string)
    out["metricCode"] = s.metricCode.map { .string($0.rawValue) }
    if let value = s.value, let code = s.metricCode {
      out["value"] = number(value, integer: isIntegerMetric(code))
    }
    out["unit"] = s.unit.map { .string($0.rawValue) }
    out["side"] = s.side.map { .string($0.rawValue) }
    out["sourceGrade"] = s.sourceGrade.map { .string($0.rawValue) }
    out["changeStatus"] = s.changeStatus.map { .string($0.rawValue) }
    out["reasonCode"] = s.reasonCode.map { $0.value.map { .string($0.rawValue) } ?? .null }
    out["policyVersion"] = s.policyVersion.map(nullableString)
    out["mdcSource"] = s.mdcSource.map { $0.value.map { .string($0.rawValue) } ?? .null }
    out["measuredAt"] = s.measuredAt.map(timestamp)
    out.merge(s.extra) { _, extra in extra }
    return .object(out)
  }

  private static func exerciseAssessment(_ r: inout ObjectReader) -> ExerciseAssessment {
    ExerciseAssessment(summary: r.string("summary"), observations: r.stringList("observations"), extra: r.finish())
  }

  private static func encodeExerciseAssessment(_ a: ExerciseAssessment, _ w: Writer) -> JSONValue {
    var out: [String: JSONValue] = [:]
    out["summary"] = a.summary.map(JSONValue.string)
    out["observations"] = a.observations.map { .array($0.map(JSONValue.string)) }
    return w.nested(out, extra: a.extra, allowed: exerciseAssessmentKeys)
  }

  private static func plan(_ r: inout ObjectReader) -> SoapPlan {
    SoapPlan(nextSession: r.string("nextSession"), homeExercise: r.string("homeExercise"), extra: r.finish())
  }

  private static func encodePlan(_ p: SoapPlan, _ w: Writer) -> JSONValue {
    var out: [String: JSONValue] = [:]
    out["nextSession"] = p.nextSession.map(JSONValue.string)
    out["homeExercise"] = p.homeExercise.map(JSONValue.string)
    return w.nested(out, extra: p.extra, allowed: planKeys)
  }

  // MARK: Scalars

  private static func nullableString(_ value: Nullable<String>) -> JSONValue {
    value.value.map(JSONValue.string) ?? .null
  }

  private static func timestamp(_ value: SoapTimestamp) -> JSONValue {
    switch value {
    case let .instant(date): return .timestamp(date)
    case .server: return .serverTimestamp
    }
  }

  /// Integer fields become `.int` (fixture `$int`, Firestore integer); others `.number` (bare number, double).
  private static func number(_ value: Double, integer: Bool) -> JSONValue {
    integer ? .int(Int64(value)) : .number(value)
  }

  private struct Writer {
    let target: SoapCodecTarget

    /// Nested maps in the rules use `keys().hasOnly([allowed])`. The Firestore target leaves out extras
    /// outside `allowed` (unknown nested keys) and writes back known keys whose value could not be read,
    /// unchanged: Firestore replaces a nested map as a whole, so dropping them would delete stored data.
    /// Fixtures get every extra.
    func nested(_ known: [String: JSONValue], extra: [String: JSONValue], allowed: Set<String>) -> JSONValue {
      var out = known
      for (key, value) in extra where target == .fixture || allowed.contains(key) {
        out[key] = value
      }
      return .object(out)
    }
  }
}

extension SoapNoteV2 {
  /// `SoapNoteV2Codec.encode(self, target:)`.
  public func encode(target: SoapCodecTarget = .firestore) -> JSONValue {
    SoapNoteV2Codec.encode(self, target: target)
  }
}

// MARK: - Reading

/// Reads known keys from one object. A known key whose value cannot be read goes to `extra` unchanged,
/// and so does every key that is never read.
struct ObjectReader {
  private let source: [String: JSONValue]
  private var read: Set<String> = []
  private var kept: Set<String> = []

  init(_ source: [String: JSONValue]) {
    self.source = source
  }

  /// The stored value, or nil when the key is absent. Marks the key as read.
  mutating func take(_ key: String) -> JSONValue? {
    read.insert(key)
    return source[key]
  }

  /// Sends a read key back to `extra` (with its stored value).
  mutating func keep(_ key: String) {
    kept.insert(key)
  }

  private mutating func typed<T>(_ key: String, _ parse: (JSONValue) -> T?) -> T? {
    guard let value = take(key) else { return nil }
    if let parsed = parse(value) { return parsed }
    kept.insert(key)
    return nil
  }

  mutating func string(_ key: String) -> String? { typed(key) { $0.stringValue } }
  mutating func bool(_ key: String) -> Bool? { typed(key) { $0.boolValue } }
  mutating func integer(_ key: String) -> Int64? { typed(key) { $0.integerValue } }

  mutating func number(_ key: String, integer: Bool) -> Double? {
    typed(key) { integer ? $0.integerValue.map(Double.init) : $0.doubleValue }
  }

  mutating func nullableString(_ key: String) -> Nullable<String>? {
    typed(key) { value in
      if case .null = value { return .null }
      return value.stringValue.map(Nullable.value)
    }
  }

  mutating func nullableInteger(_ key: String) -> Nullable<Int64>? {
    typed(key) { value in
      if case .null = value { return .null }
      return value.integerValue.map(Nullable.value)
    }
  }

  mutating func enumValue<E: RawRepresentable>(_ key: String, _: E.Type) -> E? where E.RawValue == String {
    typed(key) { $0.stringValue.flatMap(E.init(rawValue:)) }
  }

  mutating func nullableEnum<E: RawRepresentable>(_ key: String, _: E.Type) -> Nullable<E>? where E.RawValue == String {
    typed(key) { value in
      if case .null = value { return .null }
      return value.stringValue.flatMap(E.init(rawValue:)).map(Nullable.value)
    }
  }

  mutating func timestamp(_ key: String) -> SoapTimestamp? {
    typed(key) { value in
      switch value {
      case let .timestamp(date): return .instant(date)
      case .serverTimestamp: return .server
      default: return nil
      }
    }
  }

  mutating func stringList(_ key: String) -> [String]? {
    typed(key) { value in
      guard let items = value.arrayValue else { return nil }
      let strings = items.compactMap(\.stringValue)
      return strings.count == items.count ? strings : nil
    }
  }

  /// A list read element by element. `parse` keeps every element (unreadable ones in raw form), so the
  /// list keeps its length. A value that is not a list goes to extra.
  mutating func list<T>(_ key: String, _ parse: (JSONValue) -> T) -> [T]? {
    typed(key) { $0.arrayValue?.map(parse) }
  }

  mutating func object<T>(_ key: String, _ parse: (inout ObjectReader) -> T) -> T? {
    typed(key) { value in
      guard let object = value.objectValue else { return nil }
      var reader = ObjectReader(object)
      return parse(&reader)
    }
  }

  mutating func rawObject(_ key: String) -> [String: JSONValue]? {
    typed(key) { $0.objectValue }
  }

  /// Keys never read and keys sent back with `keep`, with their stored values.
  func finish() -> [String: JSONValue] {
    source.filter { !read.contains($0.key) || kept.contains($0.key) }
  }
}
