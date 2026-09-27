import Foundation
import TrainerContracts
import XCTest
@testable import TrainerDomain

/// DF-127: the `bodyCompositionRecords/{id}` create payload is exactly what `firestore.rules` accepts (V1-05 §4.7,
/// R-14, R-17, R-27) and reads back into the read model. Synthetic values only.
final class BodyCompositionPayloadTests: XCTestCase {
  private let measuredAt = FixtureTimestamp.parse("2026-12-07T08:40:00+09:00")!
  private let now = FixtureTimestamp.parse("2026-12-07T09:00:00+09:00")!

  private func entry(height: String? = nil, values: [BodyCompositionKey: String] = [.weightKg: "62,4"]) throws
    -> BodyCompositionEntry
  {
    let draft = BodyCompositionDraft(values: values, deviceModel: "InBody 570", measuredAt: measuredAt, fasting: .yes,
                                     heightCmInput: height)
    return try XCTUnwrap(BodyCompositionValidator.validate(draft, now: now).entry)
  }

  private func object(_ value: JSONValue) throws -> [String: JSONValue] {
    try XCTUnwrap(value.objectValue)
  }

  // MARK: Fields

  func testWeightOnlyPendingMemberPayload() throws {
    let fields = try object(BodyCompositionPayload.fields(try entry(), member: .pending("SYNTHpending00000001"),
                                                          trainerUid: "synthTrainerA"))
    XCTAssertEqual(fields, [
      "memberUid": .null,
      "pendingMemberId": .string("SYNTHpending00000001"),
      "trainerId": .string("synthTrainerA"),
      "enteredBy": .string("synthTrainerA"),
      "source": .string("manualEntry"),
      "sourceGrade": .string("device"),
      "deviceModel": .string("InBody 570"),
      "measuredAt": .timestamp(measuredAt),
      "fasting": .string("yes"),
      "timeOfDayBand": .string("morning"),
      "values": .object(["weightKg": .number(62.4)]),
      "reportPhotoPath": .null,
      "status": .string("active"),
      "legalNature": .string("coachingRecord"),
      "schemaVersion": .int(1),
    ])
  }

  func testUidMemberWithHeightPayload() throws {
    let fields = try object(BodyCompositionPayload.fields(
      try entry(height: "165", values: [.weightKg: "62.4", .bodyFatPercent: "0", .skeletalMuscleMassKg: "25.3"]),
      member: .uid("synthMemberUid0001"), trainerUid: "synthTrainerA"))
    XCTAssertEqual(fields["memberUid"], .string("synthMemberUid0001"))
    XCTAssertEqual(fields["pendingMemberId"], .null)
    XCTAssertEqual(fields["values"], .object([
      "weightKg": .number(62.4), "bodyFatPercent": .number(0), "skeletalMuscleMassKg": .number(25.3),
    ]))
    XCTAssertEqual(fields["derived"], .object([
      "bmi": .number(22.9), "heightCmUsed": .number(165), "heightMeasuredAt": .timestamp(measuredAt),
      "sourceGrade": .string("derived"),
    ]))
  }

  func testNoDerivedKeyWithoutHeight() throws {
    let fields = try object(BodyCompositionPayload.fields(try entry(), member: .uid("u"), trainerUid: "t"))
    XCTAssertNil(fields["derived"], "no height: the key is absent, not null (AC-DF-127.5)")
  }

  func testDraftShortcutRefusesDraftsWithErrors() throws {
    let bad = BodyCompositionDraft(values: [.bodyFatPercent: "120"], deviceModel: "InBody 570", measuredAt: measuredAt,
                                   fasting: .yes)
    XCTAssertNil(BodyCompositionPayload.fields(bad, member: .uid("u"), trainerUid: "t", now: now))
    let warned = BodyCompositionDraft(values: [.weightKg: "60", .bodyFatMassKg: "61"], deviceModel: "InBody 570",
                                      measuredAt: measuredAt, fasting: .no)
    XCTAssertNotNil(BodyCompositionPayload.fields(warned, member: .uid("u"), trainerUid: "t", now: now),
                    "warnings do not block the payload")
  }

  func testPath() {
    XCTAssertEqual(BodyCompositionPayload.path(id: "SYNTHbc00000000000001"), "bodyCompositionRecords/SYNTHbc00000000000001")
    XCTAssertEqual(BodyCompositionPayload.entityRef(recordId: "abc").rawValue, "bodyComposition:abc")
  }

  // MARK: Keys against firestore.rules

  /// The stored document keys are the rules' `bcKeys()` list, and a payload with height has all of them except the
  /// two server timestamps the writer adds (`FirestoreRemoteWriter.createIfAbsent`).
  func testDocumentKeysAreTheRulesCreateKeys() throws {
    let block = try Self.rulesBlock()
    XCTAssertEqual(Set(try Self.list(in: block, after: "function bcKeys() {")), BodyCompositionPayload.documentKeys)

    let full = try object(BodyCompositionPayload.fields(try entry(height: "170"), member: .pending("p"), trainerUid: "t"))
    XCTAssertEqual(Set(full.keys).union(BodyCompositionPayload.serverTimestampKeys), BodyCompositionPayload.documentKeys)
    let minimal = try object(BodyCompositionPayload.fields(try entry(), member: .pending("p"), trainerUid: "t"))
    XCTAssertEqual(Set(minimal.keys).union(BodyCompositionPayload.serverTimestampKeys).union(["derived"]),
                   BodyCompositionPayload.documentKeys)
    XCTAssertEqual(BodyCompositionPayload.serverTimestampKeys, ["createdAt", "updatedAt"])
  }

  func testPayloadHasEveryKeyTheRulesRequire() throws {
    let block = try Self.rulesBlock()
    let required = Set(try Self.list(in: block, after: "incoming().keys().hasAll("))
    let minimal = try object(BodyCompositionPayload.fields(try entry(), member: .uid("u"), trainerUid: "t"))
    XCTAssertTrue(required.isSubset(of: Set(minimal.keys)), "\(required.subtracting(minimal.keys))")
  }

  func testValueAndDerivedKeysAreTheRulesKeys() throws {
    let block = try Self.rulesBlock()
    XCTAssertEqual(Set(try Self.list(in: block, after: "v.keys().hasOnly(")),
                   Set(BodyCompositionKey.allCases.map(\.rawValue)))
    let full = try object(BodyCompositionPayload.fields(try entry(height: "170"), member: .uid("u"), trainerUid: "t"))
    XCTAssertEqual(Set(try Self.list(in: block, after: "d.derived.keys().hasOnly(")),
                   Set(try XCTUnwrap(full["derived"]?.objectValue).keys))
  }

  /// `match /bodyCompositionRecords/{recordId} { … }` up to the next top-level `match`.
  static func rulesBlock() throws -> String {
    let url = FixtureLoader.repositoryRoot.appendingPathComponent("firestore.rules")
    let rules = try String(contentsOf: url, encoding: .utf8)
    let start = try XCTUnwrap(rules.range(of: "match /bodyCompositionRecords/{recordId} {"))
    let rest = rules[start.upperBound...]
    let end = rest.range(of: "\n    match /")?.lowerBound ?? rest.endIndex
    return String(rest[..<end])
  }

  /// The quoted strings of the first `[...]` after `marker`.
  static func list(in text: String, after marker: String) throws -> [String] {
    let start = try XCTUnwrap(text.range(of: marker), marker)
    let open = try XCTUnwrap(text[start.upperBound...].range(of: "["))
    let close = try XCTUnwrap(text[open.upperBound...].range(of: "]"))
    return text[open.upperBound..<close.lowerBound].split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(["'"])) }
  }

  // MARK: Read model

  func testReadModelParsesTheDataModelExample() throws {
    let document: JSONValue = .object([
      "memberUid": .null,
      "pendingMemberId": .string("SYNTHpending00000001"),
      "trainerId": .string("synthTrainerA"),
      "enteredBy": .string("synthTrainerA"),
      "source": .string("manualEntry"),
      "sourceGrade": .string("device"),
      "deviceModel": .string("InBody 570"),
      "measuredAt": .timestamp(measuredAt),
      "fasting": .string("yes"),
      "timeOfDayBand": .string("morning"),
      "values": .object(["weightKg": .number(62.4), "bodyFatPercent": .number(24.1), "skeletalMuscleMassKg": .int(25)]),
      "derived": .object([
        "bmi": .number(22.9), "heightCmUsed": .number(165.0),
        "heightMeasuredAt": .timestamp(FixtureTimestamp.parse("2026-11-23T10:00:00+09:00")!),
        "sourceGrade": .string("derived"),
      ]),
      "reportPhotoPath": .null,
      "status": .string("active"),
      "legalNature": .string("coachingRecord"),
      "schemaVersion": .int(1),
      "createdAt": .timestamp(now),
      "updatedAt": .timestamp(now),
    ])
    let record = try XCTUnwrap(BodyCompositionRecord(id: "SYNTHbc01", document: document))
    XCTAssertEqual(record.id, "SYNTHbc01")
    XCTAssertEqual(record.member, .pending("SYNTHpending00000001"))
    XCTAssertEqual(record.deviceModel, "InBody 570")
    XCTAssertEqual(record.measuredAt, measuredAt)
    XCTAssertEqual(record.fasting, .yes)
    XCTAssertEqual(record.timeOfDayBand, .morning)
    XCTAssertEqual(record.source, "manualEntry")
    XCTAssertEqual(record.sourceGrade, .device)
    XCTAssertEqual(record.values, [.weightKg: 62.4, .bodyFatPercent: 24.1, .skeletalMuscleMassKg: 25])
    XCTAssertEqual(record.derived?.bmi, 22.9)
    XCTAssertEqual(record.derived?.heightCmUsed, 165)
    XCTAssertEqual(record.status, .active)
    XCTAssertNil(record.reportPhotoPath)
    XCTAssertEqual(record.createdAt, now)
  }

  func testPayloadReadsBackAsTheSameEntry() throws {
    let saved = try entry(height: "165", values: [.weightKg: "62.4", .bodyFatMassKg: "15.1"])
    guard case var .object(document) = BodyCompositionPayload.fields(saved, member: .uid("u"), trainerUid: "t") else {
      return XCTFail("object expected")
    }
    document["createdAt"] = .timestamp(now)
    document["updatedAt"] = .timestamp(now)
    let record = try XCTUnwrap(BodyCompositionRecord(id: "r", document: .object(document)))
    XCTAssertEqual(record.member, .uid("u"))
    XCTAssertEqual(record.values, saved.values)
    XCTAssertEqual(record.derived, saved.derived)
    XCTAssertEqual(record.deviceModel, saved.deviceModel)
    XCTAssertEqual(record.fasting, saved.fasting)
    XCTAssertEqual(record.timeOfDayBand, saved.timeOfDayBand)
    XCTAssertEqual(record.status, .active)
  }

  func testReadModelKeepsWhatItCannotReadOutOfTheTypedFields() throws {
    let document: JSONValue = .object([
      "memberUid": .string("u"),
      "deviceModel": .string("InBody 570"),
      "measuredAt": .timestamp(measuredAt),
      "fasting": .string("sometimes"),
      "timeOfDayBand": .string("night"),
      "sourceGrade": .string("guess"),
      "values": .object(["weightKg": .string("62.4"), "bodyFatPercent": .number(24.1), "phaseAngleDeg": .number(5)]),
      "derived": .object(["bmi": .number(22.9), "heightCmUsed": .number(165), "sourceGrade": .string("derived")]),
      "status": .string("voided"),
    ])
    let record = try XCTUnwrap(BodyCompositionRecord(id: "r", document: document))
    XCTAssertNil(record.fasting)
    XCTAssertNil(record.timeOfDayBand)
    XCTAssertNil(record.sourceGrade)
    XCTAssertEqual(record.values, [.bodyFatPercent: 24.1])
    XCTAssertNil(record.derived, "derived without heightMeasuredAt is not a valid derived map")
    XCTAssertEqual(record.status, .voided)
    XCTAssertNil(BodyCompositionRecord(id: "r", document: .object(["deviceModel": .string("x")])), "no measuredAt")
    XCTAssertNil(BodyCompositionRecord(id: "r", document: .string("x")))
  }
}
