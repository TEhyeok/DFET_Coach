import Foundation
import TrainerContracts
import XCTest

@testable import TrainerDomain

// DF-009 Swift SOAP v2 codec against contracts/fixtures (TC-DF009-01~06, TC-X-XC-01·-04).
// Fixtures are read from the repository root through `#filePath` (FixtureLoader, ASM-P0-32).
//
// Record mode (commit the output, AC-DF-009.5):
//   DFET_RECORD_FIXTURES=1 swift test --package-path trainer_app/Packages/TrainerCore --filter SoapNoteV2CodecTests
//
// This file replaces the field-presence idea of trainer_ios/DFETTrainerTests/SoapNoteFirestoreCompatTests.swift
// (DF-009 implementation note); that file is left unchanged.

/// Hand-written v2 inputs (P0 DF-005 fixture contract, rule 4).
private let v2Inputs = [
  "draft_rom_mmt_pain", "finalized_no_metrics", "forward_compat_unknown_code", "pending_member_draft",
  "refs_snapshots_pending_policy",
]

/// Inputs both codecs write back in record mode (DF-007 flutter_*, DF-009 swift_*).
private let recordedBases = ["finalized_no_metrics", "draft_rom_mmt_pain", "pending_member_draft"]

/// Metric counts of the six legacy inputs (rule 4 table), sorted. The files are not listed by name here: one
/// name carries the legacy native document prefix that static-guards G4 bans anywhere in trainer_app/.
private let legacyMetricCounts = [0, 1, 3, 3, 4, 5]

/// The metric fields AC-DF-009.1 names (same list as AC-DF-007.1).
private let checkedMetricFields = [
  "metricCode", "value", "unit", "side", "sourceGrade", "joint", "motion", "activeOrPassive", "muscleGroup", "note",
]

private let recordHint =
  "Run DFET_RECORD_FIXTURES=1 swift test --package-path trainer_app/Packages/TrainerCore --filter SoapNoteV2CodecTests and commit the output."

final class SoapNoteV2CodecTests: XCTestCase {
  private func v2(_ base: String) throws -> LoadedFixture { try FixtureLoader.fixture("soap_v2/\(base).json") }

  // MARK: TC-DF009-01 AC-DF-009.1 round trip

  func test_TC_DF009_01_AC_DF_009_1_everyV2FixtureRoundTripsIdentically() throws {
    let fixtures = try FixtureLoader.group("soap_v2")
    let names = Set(fixtures.map(\.base))
    XCTAssertTrue(names.isSuperset(of: v2Inputs), "hand-written inputs, found \(names.sorted())")
    // AC-DF-009.1 includes what Dart wrote; AC-DF-009.6 requires both record-mode sets to be committed.
    for base in recordedBases {
      XCTAssertTrue(names.contains("flutter_written_\(base)"), "flutter_written_\(base).json missing")
      XCTAssertTrue(names.contains("swift_written_\(base)"), "swift_written_\(base).json missing. \(recordHint)")
    }
    XCTAssertEqual(fixtures.count, v2Inputs.count + 2 * recordedBases.count, "\(names.sorted())")

    for f in fixtures {
      let note = try SoapNoteV2Codec.decode(f.data)
      let out = note.encode(target: .fixture)
      XCTAssertEqual(structuralDiff(out, f.data), [], f.base)
      XCTAssertEqual(out, f.data, f.base)
      XCTAssertEqual(note.metrics.count, f.meta.expect.metricCount, f.base)
      XCTAssertEqual(note.uninterpretableMetricCount, f.meta.expect.uninterpretable ?? 0, f.base)
      XCTAssertEqual(f.meta.expect.roundTrip, "identical", f.base)
      // Every key of the fixtures is a known v2 field with a readable value.
      XCTAssertEqual(note.extra, [:], f.base)
      XCTAssertNotNil(note.member, f.base)
      // Reading the output again gives the same model.
      XCTAssertEqual(try SoapNoteV2Codec.decode(out), note, f.base)
    }
  }

  func test_AC_DF_009_1_checkedMetricFieldsKeepValueAndNotation() throws {
    var rows = 0
    for f in try FixtureLoader.group("soap_v2") {
      let written = try SoapNoteV2Codec.decode(f.data).encode(target: .fixture)
      let inRows = metricRows(f.data)
      let outRows = metricRows(written)
      XCTAssertEqual(outRows.count, inRows.count, f.base)
      for (i, (inRow, outRow)) in zip(inRows, outRows).enumerated() {
        for field in checkedMetricFields {
          let at = "\(f.base) objective.metrics[\(i)].\(field)"
          XCTAssertEqual(outRow[field], inRow[field], at)
        }
        rows += 1
      }
    }
    XCTAssertGreaterThanOrEqual(rows, 5)
  }

  func test_AC_DF_009_1_mmtGradeIsIntAndRomDegIsNumber() throws {
    let note = try SoapNoteV2Codec.decode(try v2("draft_rom_mmt_pain").data)
    guard case let .parsed(rom) = note.metrics[0], case let .parsed(mmt) = note.metrics[1] else {
      return XCTFail("both rows parse: \(note.metrics)")
    }
    XCTAssertEqual(rom.metricCode, .romDeg)
    XCTAssertEqual(rom.joint, .shoulder)
    XCTAssertEqual(rom.motion, .flexion)
    XCTAssertEqual(rom.activeOrPassive, .active)
    XCTAssertEqual(mmt.muscleGroup, .shoulderAbductors)
    XCTAssertEqual(mmt.note, "가상 관찰 메모")
    XCTAssertTrue(rom.isComplete && mmt.isComplete)

    let rows = metricRows(note.encode(target: .fixture))
    XCTAssertEqual(rows[0]["value"], .number(110))
    XCTAssertEqual(rows[1]["value"], .int(4))
    XCTAssertEqual(note.subjective?.painNrs, .value(4))
    XCTAssertEqual(note.encode(target: .fixture)["subjective"]?["painNrs"], .int(4))
  }

  func test_AC_DF_009_1_pendingDraftKeepsNullMemberUidNoMemberIdAndNullPain() throws {
    let note = try SoapNoteV2Codec.decode(try v2("pending_member_draft").data)
    XCTAssertEqual(note.member, .pending("fx-pending-001"))
    XCTAssertEqual(note.subjective?.painNrs, .null, "not entered is null, not 0 (AC-SOAP-01.7)")
    XCTAssertEqual(note.createdAt, .server)
    XCTAssertEqual(note.inkRevision, 1)
    XCTAssertNil(note.objective)
    let out = try XCTUnwrap(note.encode(target: .fixture).objectValue)
    XCTAssertEqual(out["memberUid"], .null)
    XCTAssertEqual(out["pendingMemberId"], .string("fx-pending-001"))
    XCTAssertNil(out["memberId"])
    XCTAssertNil(out["objective"])
    XCTAssertEqual(out["createdAt"], .serverTimestamp)
    XCTAssertEqual(out["inkRevision"], .int(1))
  }

  func test_AC_DF_009_1_memberKeyWritesMemberUidPendingMemberIdAndLegacyMirror() throws {
    let uid = SoapNoteV2(member: .uid("fx-member-001")).encode(target: .fixture)
    XCTAssertEqual(uid["memberUid"], .string("fx-member-001"))
    XCTAssertEqual(uid["memberId"], .string("fx-member-001"), "legacy mirror during the compatibility period")
    XCTAssertEqual(uid["pendingMemberId"], .null)

    let pending = SoapNoteV2(member: .pending("fx-pending-001")).encode(target: .fixture)
    XCTAssertEqual(pending["memberUid"], .null)
    XCTAssertEqual(pending["pendingMemberId"], .string("fx-pending-001"))
    XCTAssertNil(pending["memberId"])

    // A promoted record keeps pendingMemberId next to memberUid (V1-05 §3.3), with or without the mirror.
    let base = try XCTUnwrap(try v2("finalized_no_metrics").data.objectValue)
    for mirror in [true, false] {
      var data = base
      data["pendingMemberId"] = .string("fx-pending-009")
      if !mirror { data["memberId"] = nil }
      let note = try SoapNoteV2Codec.decode(.object(data))
      XCTAssertEqual(note.member, .uid("fx-member-001"))
      XCTAssertEqual(note.promotedFromPendingMemberId, "fx-pending-009")
      XCTAssertEqual(note.writesLegacyMemberId, mirror)
      XCTAssertEqual(note.extra, [:])
      XCTAssertEqual(note.encode(target: .fixture), .object(data))
    }
  }

  func test_AC_DF_009_1_memberKeysOutsideTheV2ShapesAreKeptAsStored() throws {
    let base = try XCTUnwrap(try v2("finalized_no_metrics").data.objectValue)
    let shapes: [[String: JSONValue?]] = [
      ["memberId": .string("fx-member-other")],  // mirror differs
      ["memberUid": .null, "pendingMemberId": .null],  // neither
      ["memberUid": .int(7)],  // wrong type
      ["pendingMemberId": nil],  // key missing
      ["memberUid": .null, "pendingMemberId": .string("fx-pending-001")],  // pending with a memberId
    ]
    for change in shapes {
      var data = base
      for (key, value) in change { data[key] = value }
      let note = try SoapNoteV2Codec.decode(.object(data))
      XCTAssertNil(note.member, "\(change)")
      let stored = data.filter { ["memberUid", "memberId", "pendingMemberId"].contains($0.key) }
      XCTAssertEqual(note.extra, stored, "\(change)")
      XCTAssertEqual(note.encode(target: .fixture), .object(data), "\(change)")
      let firestore = try XCTUnwrap(note.encode(target: .firestore).objectValue)
      XCTAssertEqual(firestore.filter { stored.keys.contains($0.key) }, stored, "written back unchanged")
    }
  }

  func test_AC_DF_009_1_parsedRowsReportCompletenessByTheCatalog() {
    let incomplete = [
      ParsedMetric(metricCode: .romDeg, value: 90, unit: .deg, side: .left, sourceGrade: .trainerObserved,
        motion: .flexion, activeOrPassive: .active),  // no joint
      ParsedMetric(metricCode: .mmtGrade, value: 6, unit: .grade, side: .right, sourceGrade: .trainerObserved,
        muscleGroup: .hipAbductors),  // out of 0~5
      ParsedMetric(metricCode: .romDeg, value: 90, unit: .deg, side: .none, sourceGrade: .trainerObserved,
        joint: .hip, motion: .flexion, activeOrPassive: .active),  // side rule
      ParsedMetric(metricCode: .weightKg, value: 70, unit: .kg, side: .none, sourceGrade: .trainerObserved),  // not an O row
    ]
    for m in incomplete {
      XCTAssertFalse(m.isComplete, "\(m)")
      XCTAssertTrue(SoapMetricV2.parsed(m).isInterpretable)
    }
  }

  // MARK: TC-DF009-02 AC-DF-009.6 cross-client written fixtures

  func test_TC_DF009_02_AC_DF_009_6_flutterWrittenFixturesDecodeToTheTestBuiltModels() throws {
    for base in recordedBases {
      let expected = try XCTUnwrap(expectedModels[base])
      XCTAssertEqual(try SoapNoteV2Codec.decode(try v2(base).data), expected, "\(base).json")

      // No skip branch: a missing file fails here (AC-DF-009.6).
      let url = FixtureLoader.fixtureURL("soap_v2/flutter_written_\(base).json")
      XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "\(url.path) missing (DF-007 record mode)")
      let dart = try v2("flutter_written_\(base)")
      XCTAssertEqual(dart.meta.writer, "dart")
      XCTAssertEqual(dart.path, try v2(base).path)
      let note = try SoapNoteV2Codec.decode(dart.data)
      XCTAssertEqual(structuralDiff(note.encode(target: .fixture), expected.encode(target: .fixture)), [], base)
      XCTAssertEqual(note, expected, "flutter_written_\(base).json")
    }
  }

  func test_TC_DF009_02_AC_DF_009_6_swiftAndDartWriteTheSameDocument() throws {
    for base in recordedBases {
      let swift = try v2("swift_written_\(base)")
      let dart = try v2("flutter_written_\(base)")
      XCTAssertEqual(swift.meta.writer, "swift")
      XCTAssertEqual(structuralDiff(swift.data, dart.data), [], base)
      XCTAssertEqual(try SoapNoteV2Codec.decode(swift.data), try XCTUnwrap(expectedModels[base]), base)
    }
  }

  // MARK: AC-DF-009.5 record mode

  func test_AC_DF_009_5_swiftWrittenFixturesAreTheCurrentSwiftOutput() throws {
    for base in recordedBases {
      let input = try v2(base)
      let name = "swift_written_\(base)"
      let model = try XCTUnwrap(expectedModels[base])
      var prdRefs = input.meta.prdRefs
      if !prdRefs.contains("NFR-07") { prdRefs.append("NFR-07") }
      let meta = FixtureMeta(
        id: "soap_v2/\(name)",
        description: "DF-009 기록 모드: 테스트가 만든 Swift SoapNoteV2 모델(soap_v2/\(base).json과 같은 의미)을 "
          + "SoapNoteV2Codec.encode(target: .fixture)로 쓴 결과",
        writer: "swift", prdRefs: prdRefs, expect: input.meta.expect)
      let text = JSONValue.encodeFixture(
        meta: meta, path: input.path, data: model.encode(target: .fixture), keyOrder: SoapNoteV2Codec.fixtureKeyOrder)
      let url = FixtureLoader.fixtureURL("soap_v2/\(name).json")
      if FixtureLoader.recordMode { try text.write(to: url) }
      XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "\(url.path) missing. \(recordHint)")
      XCTAssertEqual(try Data(contentsOf: url), text, "\(name).json is stale. \(recordHint)")
      let reread = try JSONValue.decodeFixture(text)
      XCTAssertEqual(reread.meta, meta)
      XCTAssertEqual(try SoapNoteV2Codec.decode(reread.data), model)
    }
  }

  func test_AC_DF_009_5_writerMatchesTheDartFileFormatByteForByte() throws {
    // flutter_written_* were written by Dart as JSON.stringify(doc, null, 2) + "\n" (README §5).
    for base in recordedBases {
      let url = FixtureLoader.fixtureURL("soap_v2/flutter_written_\(base).json")
      let original = try Data(contentsOf: url)
      let decoded = try JSONValue.decodeFixture(original)
      let rewritten = JSONValue.encodeFixture(
        meta: decoded.meta, path: decoded.path, data: decoded.data, keyOrder: SoapNoteV2Codec.fixtureKeyOrder)
      XCTAssertEqual(String(decoding: rewritten, as: UTF8.self), String(decoding: original, as: UTF8.self), base)
    }
  }

  // MARK: TC-DF009-03 AC-DF-009.2 unknown values are kept

  func test_TC_DF009_03_AC_DF_009_2_unknownMetricCodeIsUnparsedAndReencodesAsIs() throws {
    let f = try v2("forward_compat_unknown_code")
    let note = try SoapNoteV2Codec.decode(f.data)
    XCTAssertEqual(note.metrics.count, 2, "no row is dropped")
    let stored = metricRows(f.data)
    XCTAssertEqual(note.metrics[0], .unparsed(raw: .object(stored[0])))
    XCTAssertFalse(note.metrics[0].isInterpretable)
    XCTAssertEqual(note.metrics[0].unparsedMetricCode, "futureMetricX")
    guard case let .parsed(known) = note.metrics[1] else { return XCTFail("mmtGrade row parses") }
    XCTAssertEqual(known.metricCode, .mmtGrade)
    XCTAssertEqual(known.value, 3)
    XCTAssertEqual(note.uninterpretableMetricCount, 1)

    XCTAssertEqual(metricRows(note.encode(target: .fixture))[0], stored[0])
    // The Firestore target writes the stored row unchanged too.
    XCTAssertEqual(metricRows(note.encode(target: .firestore))[0], stored[0])
  }

  func test_TC_DF009_03_AC_DF_009_2_knownCodeWithUnreadableFieldsStaysUnparsed() throws {
    let base = try v2("draft_rom_mmt_pain").data
    let rows: [JSONValue] = [
      row(["metricCode": "romDeg", "unit": "deg", "side": "diagonal", "sourceGrade": "trainerObserved",
        "joint": "hip", "motion": "flexion", "activeOrPassive": "active"], value: .number(90)),  // unknown side
      row(["metricCode": "mmtGrade", "unit": "grade", "side": "left", "sourceGrade": "trainerObserved",
        "muscleGroup": "hipAbductors"], value: .number(4.5)),  // fractional mmtGrade
      row(["metricCode": "mmtGrade", "unit": "grade", "side": "left", "sourceGrade": "trainerObserved"], value: nil),
      row(["metricCode": "romDeg", "unit": "deg", "side": "left", "sourceGrade": "trainerObserved",
        "joint": "wing", "motion": "flexion", "activeOrPassive": "active"], value: .number(90)),  // unknown joint
      row(["metricCode": "romDeg", "unit": "도", "side": "좌", "sourceGrade": "ROM"], value: .number(90)),  // legacy Korean
      .string("가상 문자열 행"),
      .null,
    ]
    let note = try SoapNoteV2Codec.decode(withMetrics(base, rows))
    XCTAssertEqual(note.metrics.count, rows.count)
    XCTAssertTrue(note.metrics.allSatisfy { !$0.isInterpretable })
    XCTAssertEqual(note.metrics, rows.map { SoapMetricV2.unparsed(raw: $0) })
    XCTAssertEqual(note.encode(target: .firestore)["objective"]?["metrics"], .array(rows))
    XCTAssertEqual(try SoapNoteV2Codec.decode(note.encode(target: .fixture)), note)
  }

  func test_TC_DF009_03_unknownTopLevelKeyUnknownStatusAndWrongTypeAreKeptInExtra() throws {
    var data = try XCTUnwrap(try v2("finalized_no_metrics").data.objectValue)
    data["status"] = .string("archived")
    data["quickNote"] = .number(42)
    data["futureField"] = .object(["nested": .bool(true)])
    let note = try SoapNoteV2Codec.decode(.object(data))
    XCTAssertNil(note.status)
    XCTAssertNil(note.quickNote)
    XCTAssertEqual(
      note.extra, ["status": .string("archived"), "quickNote": .number(42), "futureField": .object(["nested": .bool(true)])])
    XCTAssertEqual(note.encode(target: .fixture), .object(data))
    let firestore = note.encode(target: .firestore)
    XCTAssertEqual(firestore["status"], .string("archived"), "known key written back unchanged")
    XCTAssertNil(firestore["futureField"], "unknown top-level key is not a client-writable key")
  }

  func test_TC_DF009_03_unknownKeysInsideRowsSnapshotsAndNestedMapsAreKept() throws {
    var data = try XCTUnwrap(try v2("refs_snapshots_pending_policy").data.objectValue)
    var objective = try XCTUnwrap(data["objective"]?.objectValue)
    var row = try XCTUnwrap(objective["metrics"]?.arrayValue?.first?.objectValue)
    row["futureRowKey"] = .string("x")
    objective["metrics"] = .array([.object(row)])
    var snapshots = try XCTUnwrap(objective["snapshots"]?.arrayValue)
    var first = try XCTUnwrap(snapshots[0].objectValue)
    first["changeStatus"] = .string("futureStatus")
    snapshots[0] = .object(first)
    snapshots.append(contentsOf: [.number(7.5), .null])
    objective["snapshots"] = .array(snapshots)
    data["objective"] = .object(objective)
    var plan = try XCTUnwrap(data["plan"]?.objectValue)
    plan["futurePlanKey"] = .string("x")
    data["plan"] = .object(plan)

    let note = try SoapNoteV2Codec.decode(.object(data))
    guard case let .parsed(parsed) = note.metrics.first else { return XCTFail("row parses") }
    XCTAssertEqual(parsed.extra, ["futureRowKey": .string("x")])
    let read = try XCTUnwrap(note.objective?.snapshots)
    XCTAssertEqual(read.count, 5)
    XCTAssertNil(read[0].changeStatus)
    XCTAssertEqual(read[0].extra, ["changeStatus": .string("futureStatus")])
    XCTAssertEqual(read[3].element, .number(7.5))
    XCTAssertEqual(read[4].element, .null)
    XCTAssertFalse(read[4].isReadable)
    XCTAssertEqual(note.plan?.extra, ["futurePlanKey": .string("x")])

    XCTAssertEqual(note.encode(target: .fixture), .object(data))
    let firestore = note.encode(target: .firestore)
    XCTAssertNil(firestore["plan"]?["futurePlanKey"], "nested unknown keys break the rules' hasOnly")
    XCTAssertEqual(firestore["objective"]?["snapshots"]?.arrayValue?.count, 5, "no snapshot is dropped")
    XCTAssertEqual(firestore["objective"]?["metrics"]?.arrayValue?.first?["futureRowKey"], .string("x"))
  }

  func test_TC_DF009_03_knownNestedKeysWithUnreadableValuesAreWrittenBackUnchanged() throws {
    var data = try XCTUnwrap(try v2("draft_rom_mmt_pain").data.objectValue)
    var subjective = try XCTUnwrap(data["subjective"]?.objectValue)
    subjective["painRegions"] = .array([.string("shoulderRight"), .number(3)])
    data["subjective"] = .object(subjective)
    var objective = try XCTUnwrap(data["objective"]?.objectValue)
    objective["refs"] = .string("not-a-map")
    data["objective"] = .object(objective)
    var plan = try XCTUnwrap(data["plan"]?.objectValue)
    plan["homeExercise"] = .number(12)
    data["plan"] = .object(plan)

    let note = try SoapNoteV2Codec.decode(.object(data))
    XCTAssertNil(note.subjective?.painRegions)
    XCTAssertEqual(note.subjective?.extra["painRegions"], subjective["painRegions"])
    let firestore = note.encode(target: .firestore)
    XCTAssertEqual(firestore["subjective"]?["painRegions"], subjective["painRegions"])
    XCTAssertEqual(firestore["objective"]?["refs"], .string("not-a-map"))
    XCTAssertEqual(firestore["objective"]?["metrics"]?.arrayValue?.count, 2)
    XCTAssertEqual(firestore["plan"]?["homeExercise"], .number(12))
  }

  // MARK: Firestore target (client write whitelist, TC-DF007-04 counterpart)

  func test_firestoreTargetKeepsTheClientWriteWhitelist() throws {
    var data = try XCTUnwrap(try v2("refs_snapshots_pending_policy").data.objectValue)
    data["memberSummaryId"] = .string("fx-summary-001")
    data["migratedFrom"] = .object(["runId": .string("fx-run-001"), "schemaVersion": .int(1)])
    data["legacy"] = .object([
      "metricsRaw": .array([.object(["type": .string("ROM"), "label": .string("가상 항목"), "value": .string("40-45")])]),
      "diagnosisRaw": .string("가상 원문(합성)"),
    ])
    data["diagnosis"] = .string("가상 자동 채움 문구(합성)")
    let note = try SoapNoteV2Codec.decode(.object(data))
    XCTAssertEqual(note.memberSummaryId, .value("fx-summary-001"))
    XCTAssertEqual(note.migratedFrom?["runId"], .string("fx-run-001"))
    XCTAssertEqual(note.legacy?["diagnosisRaw"], .string("가상 원문(합성)"))
    XCTAssertEqual(Array(note.extra.keys), ["diagnosis"])

    // Legacy-only keys (structured, inline ink) are covered by the whitelist check below.
    let blocked = ["memberSummaryId", "legacy", "migratedFrom", "diagnosis"]
    for firestore in [note.encode(target: .firestore), note.encode()] {
      let keys = try XCTUnwrap(firestore.objectValue).keys
      XCTAssertEqual(blocked.filter(keys.contains), [])
      XCTAssertTrue(keys.allSatisfy(SoapNoteV2Codec.clientWritableKeys.contains))
    }
    // Reading is lossless: the fixture target writes them back.
    XCTAssertEqual(note.encode(target: .fixture), .object(data))
  }

  func test_firestoreTargetCarriesTheFieldsRulesAndOtherClientsNeed() throws {
    // Replaces the field-presence checks of trainer_ios SoapNoteFirestoreCompatTests with v2 fields.
    let draft = try SoapNoteV2Codec.decode(try v2("draft_rom_mmt_pain").data).encode(target: .firestore)
    for key in [
      "schemaVersion", "trainerId", "authorUid", "memberUid", "memberId", "pendingMemberId", "sessionDate", "status",
      "quickNote", "legalNature", "createdAt", "updatedAt",
    ] {
      XCTAssertNotNil(draft[key], key)
    }
    XCTAssertEqual(draft["schemaVersion"], .int(2), "Firestore stores schemaVersion as an integer")
    XCTAssertEqual(draft["sessionDate"], .timestamp(utc("2026-09-29T01:00:00Z")))
    XCTAssertEqual(draft["status"], .string("draft"))
    XCTAssertEqual(draft["isSharedWithMember"], .bool(false))
    XCTAssertEqual(metricRows(draft)[0]["value"], .number(110))
    XCTAssertEqual(metricRows(draft)[1]["value"], .int(4))

    let pending = try SoapNoteV2Codec.decode(try v2("pending_member_draft").data).encode(target: .firestore)
    XCTAssertEqual(pending["createdAt"], .serverTimestamp)
    XCTAssertEqual(pending["memberUid"], .null)
    XCTAssertEqual(pending["inkRevision"], .int(1))
  }

  func test_aV1DocumentIsNotDecodedAsV2() throws {
    for f in try FixtureLoader.group("soap_legacy") {
      XCTAssertFalse(SoapNoteV2Codec.isV2(f.data), f.base)
      XCTAssertThrowsError(try SoapNoteV2Codec.decode(f.data), f.base) { error in
        XCTAssertEqual(error as? SoapNoteV2Codec.DecodingError, .notV2(schemaVersion: nil))
      }
    }
    XCTAssertThrowsError(try SoapNoteV2Codec.decode(.array([])))
  }

  // MARK: AC-DF-009.3 no demo text

  func test_AC_DF_009_3_draftFromFinalizedNoMetricsKeepsQuickNoteVerbatim() throws {
    let f = try v2("finalized_no_metrics")
    var draft = try SoapNoteV2Codec.decode(f.data)
    draft.status = .draft
    draft.finalizedAt = nil
    draft.updatedAt = .server

    let out = draft.encode(target: .fixture)
    XCTAssertEqual(out["quickNote"], f.data["quickNote"])
    XCTAssertEqual(out["quickNote"], .string("가상 회원 A, 오른쪽 어깨가 뻐근하다고 말함"))
    XCTAssertEqual(out["objective"]?["metrics"], .array([]), "empty metrics stay empty")
    XCTAssertEqual(out["plan"], f.data["plan"])
    XCTAssertNil(out["subjective"], "nothing is filled in")
    XCTAssertNil(out["exerciseAssessment"])
    XCTAssertNil(out["finalizedAt"])
    XCTAssertEqual(out["status"], .string("draft"))
    let firestore = draft.encode(target: .firestore)
    XCTAssertEqual(firestore["quickNote"], f.data["quickNote"])
    XCTAssertEqual(firestore["objective"]?["metrics"], .array([]))
  }

  // MARK: TC-DF009-05 AC-DF-009.3 demo literals

  func test_TC_DF009_05_AC_DF_009_3_demoLiteralsAppearNowhereInTrainerApp() throws {
    // dfet:trainer_ios/DFETTrainer/Domain/SoapModels.swift:111-119 (F-SOAP-06.3 counterexample). Each literal is
    // split in two here so this file does not match itself.
    let literals = demoLiteralParts.map { $0.joined() }
    let legacy = FixtureLoader.repositoryRoot.appendingPathComponent("trainer_ios/DFETTrainer/Domain/SoapModels.swift")
    if let source = try? String(contentsOf: legacy, encoding: .utf8) {
      // While trainer_ios/ exists (until P3), the list must still match the counterexample lines.
      let lines = source.components(separatedBy: "\n")[110..<119].joined(separator: "\n")
      for literal in literals {
        XCTAssertTrue(lines.contains(literal), "SoapModels.swift:111-119 no longer has \(literal)")
      }
    }

    let root = FixtureLoader.repositoryRoot.appendingPathComponent("trainer_app", isDirectory: true)
    let skipped: Set<String> = [".build", ".spm", ".swiftpm", "DerivedData", "build", "xcuserdata", ".git"]
    let walker = try XCTUnwrap(
      FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey]))
    var scanned: [String] = []
    var hits: [String] = []
    for case let url as URL in walker {
      let values = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
      if values.isDirectory == true {
        if skipped.contains(url.lastPathComponent) { walker.skipDescendants() }
        continue
      }
      guard (values.fileSize ?? 0) < 8_000_000, let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
      scanned.append(url.lastPathComponent)
      for literal in literals where text.contains(literal) {
        hits.append("\(url.path): \(literal)")
      }
    }
    XCTAssertTrue(scanned.contains("SoapNoteV2Codec.swift"), "the walk reaches TrainerCore sources")
    XCTAssertTrue(scanned.contains("SoapNoteV2CodecTests.swift"), "the walk reaches this file")
    XCTAssertGreaterThan(scanned.count, 50)
    XCTAssertEqual(hits, [])
  }

  // MARK: TC-DF009-04 AC-DF-009.4 legacy view

  func test_TC_DF009_04_AC_DF_009_4_legacyMetricCountMatchesAndEveryRowIsUninterpretable() throws {
    let fixtures = try FixtureLoader.group("soap_legacy")
    XCTAssertEqual(fixtures.map { $0.meta.expect.legacyMetricCount ?? -1 }.sorted(), legacyMetricCounts)
    for f in fixtures {
      let view = LegacySoapView(json: f.data)
      XCTAssertEqual(view.metrics.count, f.meta.expect.legacyMetricCount, f.base)
      let rows = stored(f)
      XCTAssertEqual(view.metrics.count, rows.count, f.base)
      for (m, row) in zip(view.metrics, rows) {
        XCTAssertFalse(m.isInterpretable, f.base)
        XCTAssertEqual(m.displayLabel, "해석 불가")
        // The original row is kept as stored; values are never filled with 0.
        XCTAssertEqual(m.source, row, f.base)
        XCTAssertEqual(m.valueText, row["value"]?.stringValue ?? "", f.base)
      }
    }
  }

  func test_TC_DF009_04_AC_DF_009_4_legacyNotationsAreNotContractEnums() throws {
    var types: Set<String> = []
    for f in try FixtureLoader.group("soap_legacy") {
      for m in LegacySoapView(json: f.data).metrics {
        if let type = m.type { types.insert(type) }
        XCTAssertFalse(m.isInterpretable)
      }
    }
    for type in ["rom", "mmt", "test", "general", "ROM", "통증", "MMT", "기능검사", "특수검사", "pain", "functional",
      "specialTest", "exercise"] {
      XCTAssertTrue(types.contains(type), "legacy fixtures cover \(type)")
    }
    // No Korean or legacy rawValue in the contract enums (SoapModels.swift:4-8 counterexample).
    XCTAssertNil(SourceGrade(rawValue: "ROM"))
    for korean in ["통증", "ROM", "MMT", "기능검사", "특수검사"] {
      XCTAssertNil(MetricCode(rawValue: korean), korean)
      XCTAssertNil(SourceGrade(rawValue: korean), korean)
    }
    for side in ["좌", "우", "양측", "해당 없음"] { XCTAssertNil(Side(rawValue: side), side) }
    XCTAssertNil(MetricUnit(rawValue: "도"))
    for status in ["작성 중", "공유됨", "완료", "complete"] { XCTAssertNil(SoapStatus(rawValue: status), status) }
  }

  func test_AC_DF_009_4_legacyStatusCategoriesMemberAndInkReadAsWritten() throws {
    func view(_ base: String) throws -> LegacySoapView {
      LegacySoapView(json: try FixtureLoader.fixture("soap_legacy/\(base).json").data)
    }
    let korean = try view("trainer_ios_korean_enum")
    XCTAssertEqual(korean.legacyStatus, "작성 중")
    XCTAssertEqual(korean.mappedStatus, .draft)
    XCTAssertEqual(korean.completedCategories, ["S"])
    XCTAssertEqual(korean.normalizedCompletedCategories, ["subjective"])
    XCTAssertEqual(Array(korean.metrics.map(\.side).prefix(3)), ["좌", "해당 없음", "우"])
    XCTAssertEqual(korean.metrics[0].valueText, "120.0")

    XCTAssertEqual(try view("flutter_rom_mmt_test_general").legacyStatus, "complete")
    XCTAssertEqual(try view("flutter_rom_mmt_test_general").mappedStatus, .finalized)
    XCTAssertTrue(try view("flutter_rom_mmt_test_general").metrics.map(\.valueText).contains("110-120"))
    XCTAssertTrue(try view("flutter_rom_mmt_test_general").metrics.map(\.valueText).contains("4+"))
    XCTAssertEqual(try view("schema_doc_vocab").mappedStatus, .finalized)
    let shared = try view("status_shared_korean")
    XCTAssertEqual(shared.legacyStatus, "공유됨")
    XCTAssertEqual(shared.mappedStatus, .finalized)
    XCTAssertTrue(shared.wasShared)

    // The native bridge fixture is the one with the bridge vocabulary (rom·mmt·exercise, label only).
    let bridge = try XCTUnwrap(
      try FixtureLoader.group("soap_legacy").map { LegacySoapView(json: $0.data) }
        .first { $0.metrics.contains { $0.type == "exercise" } })
    XCTAssertEqual(bridge.metrics.count, 3)
    XCTAssertEqual(bridge.metrics.map(\.label), ["허리 굴곡", "엉덩이 외전", "힙힌지 드릴"])
    XCTAssertTrue(bridge.metrics.allSatisfy { $0.valueText.isEmpty })
    XCTAssertFalse(bridge.hasLinkedMember, "local member- seed (MIG-07)")
    XCTAssertTrue(bridge.hasInlineInk)
    XCTAssertTrue(try view("drawing_data_bytes").hasInlineInk)
    XCTAssertFalse(try view("schema_doc_vocab").hasInlineInk)
    XCTAssertTrue(try view("schema_doc_vocab").hasLinkedMember)
    XCTAssertEqual(try view("schema_doc_vocab").sessionDate, utc("2026-09-22T01:00:00Z"))
  }

  func test_AC_DF_009_4_aNumericLookingLegacyValueStaysText() {
    let view = LegacySoapView(json: .object([
      "structured": .object(["metrics": .array([
        .object(["type": .string("rom"), "label": .string("가상 항목"), "value": .string("45")]),
        .object(["type": .string("rom"), "label": .string("가상 항목")]),
        .string("가상 문자열 행"),
      ])])
    ]))
    XCTAssertEqual(view.metrics.count, 3)
    XCTAssertEqual(view.metrics.map(\.valueText), ["45", "", ""])
    XCTAssertTrue(view.metrics.allSatisfy { !$0.isInterpretable })
    XCTAssertEqual(view.metrics[2].source, .string("가상 문자열 행"))
  }

  // MARK: TC-DF009-06 fixture tags

  func test_TC_DF009_06_decodeFixtureRoundTripsTheFourTags() throws {
    let text = """
      {"_fixture": {"id": "soap_v2/tags", "description": "합성", "writer": "synthetic", "prdRefs": ["NFR-07"],
        "expect": {"roundTrip": "identical"}},
       "path": "soap_notes/fx-tags",
       "data": {"ts": {"$ts": "2026-09-30T14:00:00.25+09:00"}, "server": {"$serverTimestamp": true},
        "bytes": {"$bytes": "ZngtZHJhd2luZy1ieXRlcw=="}, "int": {"$int": 1790125200000}, "bare": 45, "half": 45.5,
        "list": [{"$int": 0}, null, true, "문자"]}}
      """
    let decoded = try JSONValue.decodeFixture(Data(text.utf8))
    XCTAssertEqual(decoded.path, "soap_notes/fx-tags")
    XCTAssertEqual(decoded.meta.expect, FixtureExpect(roundTrip: "identical"))
    let data = try XCTUnwrap(decoded.data.objectValue)
    XCTAssertEqual(data["ts"], .timestamp(utc("2026-09-30T05:00:00.25Z")))
    XCTAssertEqual(data["server"], .serverTimestamp)
    XCTAssertEqual(data["bytes"], .bytes(Data("fx-drawing-bytes".utf8)))
    XCTAssertEqual(data["int"], .int(1_790_125_200_000))
    XCTAssertEqual(data["bare"], .number(45))
    XCTAssertEqual(data["bare"], .number(45.0), "numbers compare by value")
    XCTAssertNotEqual(data["bare"], .int(45), "int and number are different")
    XCTAssertEqual(data["half"], .number(45.5))
    XCTAssertEqual(data["list"], .array([.int(0), .null, .bool(true), .string("문자")]))

    let written = JSONValue.encodeFixture(meta: decoded.meta, path: decoded.path, data: decoded.data)
    let again = try JSONValue.decodeFixture(written)
    XCTAssertEqual(again.meta, decoded.meta)
    XCTAssertEqual(again.path, decoded.path)
    XCTAssertEqual(again.data, decoded.data)
    let writtenText = String(decoding: written, as: UTF8.self)
    for fragment in [
      #""$ts": "2026-09-30T05:00:00.25Z""#, #""$serverTimestamp": true"#, #""$bytes": "ZngtZHJhd2luZy1ieXRlcw==""#,
      #""$int": 1790125200000"#, #""bare": 45,"#, #""half": 45.5"#,
    ] {
      XCTAssertTrue(writtenText.contains(fragment), fragment)
    }
    XCTAssertTrue(writtenText.hasSuffix("}\n"))
  }

  func test_TC_DF009_06_everyCommittedFixtureSurvivesDecodeEncodeDecode() throws {
    for group in ["soap_v2", "soap_legacy"] {
      for f in try FixtureLoader.group(group) {
        let written = JSONValue.encodeFixture(meta: f.meta, path: f.path, data: f.data)
        let again = try JSONValue.decodeFixture(written)
        XCTAssertEqual(again.meta, f.meta, f.base)
        XCTAssertEqual(again.path, f.path, f.base)
        XCTAssertEqual(again.data, f.data, f.base)
      }
    }
    let bytes = try FixtureLoader.fixture("soap_legacy/drawing_data_bytes.json").data
    XCTAssertTrue(try XCTUnwrap(bytes.objectValue).values.contains(.bytes(Data("fx-drawing-bytes".utf8))), "$bytes")
  }

  func test_TC_DF009_06_unknownOrMalformedTagsAndDollarKeysOutsideDataFail() {
    let envelope = { (fixture: String, data: String) in
      """
      {"_fixture": \(fixture), "path": "soap_notes/fx-bad", "data": \(data)}
      """
    }
    let meta = #"{"id": "soap_v2/bad", "description": "합성", "writer": "synthetic", "prdRefs": [], "expect": {}}"#
    let bad: [(String, String)] = [
      ("unknown tag", envelope(meta, #"{"x": {"$timestamp": "2026-09-28T01:00:00Z"}}"#)),
      ("unknown tag in a list", envelope(meta, #"{"x": [{"$date": 1}]}"#)),
      ("two keys", envelope(meta, #"{"x": {"$int": 1, "$ts": "2026-09-28T01:00:00Z"}}"#)),
      ("tag and plain key", envelope(meta, #"{"x": {"$int": 1, "y": 2}}"#)),
      ("fractional $int", envelope(meta, #"{"x": {"$int": 4.5}}"#)),
      ("string $int", envelope(meta, #"{"x": {"$int": "4"}}"#)),
      ("bool $int", envelope(meta, #"{"x": {"$int": true}}"#)),
      ("$serverTimestamp false", envelope(meta, #"{"x": {"$serverTimestamp": false}}"#)),
      ("$ts without zone", envelope(meta, #"{"x": {"$ts": "2026-09-28T01:00:00"}}"#)),
      ("$ts bad date", envelope(meta, #"{"x": {"$ts": "2026-02-30T01:00:00Z"}}"#)),
      ("$bytes not base64", envelope(meta, #"{"x": {"$bytes": "***"}}"#)),
      ("$ in _fixture", envelope(
        #"{"id": "soap_v2/bad", "description": "합성", "writer": "synthetic", "prdRefs": [], "expect": {"$int": 1}}"#,
        "{}")),
      ("extra _fixture key", envelope(
        #"{"id": "a", "description": "b", "writer": "synthetic", "prdRefs": [], "expect": {}, "note": 1}"#, "{}")),
      ("unknown expect key", envelope(
        #"{"id": "a", "description": "b", "writer": "synthetic", "prdRefs": [], "expect": {"count": 1}}"#, "{}")),
      ("fourth envelope key", #"{"_fixture": \#(meta), "path": "p", "data": {}, "extra": 1}"#),
      ("path not a string", #"{"_fixture": \#(meta), "path": 1, "data": {}}"#),
    ]
    for (name, text) in bad {
      XCTAssertThrowsError(try JSONValue.decodeFixture(Data(text.utf8)), name) { error in
        XCTAssertTrue(error is FixtureFormatError, "\(name): \(error)")
      }
    }
    XCTAssertNoThrow(try JSONValue.decodeFixture(Data(envelope(meta, #"{"x": {"$int": -3}}"#).utf8)))
  }

  func test_TC_DF009_06_timestampNotation() {
    XCTAssertEqual(FixtureTimestamp.parse("2026-09-30T14:00:00+09:00"), utc("2026-09-30T05:00:00Z"))
    XCTAssertEqual(FixtureTimestamp.parse("2026-09-30T00:30:00-01:30"), utc("2026-09-30T02:00:00Z"))
    XCTAssertEqual(FixtureTimestamp.format(utc("2026-09-30T05:00:00Z")), "2026-09-30T05:00:00Z")
    XCTAssertEqual(FixtureTimestamp.format(utc("2026-09-30T05:00:00.5Z")), "2026-09-30T05:00:00.5Z")
    XCTAssertEqual(FixtureTimestamp.format(utc("2026-09-30T05:00:00.123456Z")), "2026-09-30T05:00:00.123456Z")
    for bad in ["2026-09-30", "2026-09-30T05:00Z", "2026-13-01T00:00:00Z", "2026-09-30T05:00:00.Z", "2026-09-30T05:00:00Zx"] {
      XCTAssertNil(FixtureTimestamp.parse(bad), bad)
    }
  }
}

// MARK: - Helpers

/// Demo literals of dfet:trainer_ios/DFETTrainer/Domain/SoapModels.swift:111-119, each split in two.
private let demoLiteralParts: [[String]] = [
  ["스쿼트 하강 구간에서 ", "허리 불편감. 호흡 cue 후 안정."],
  ["Hip hinge 패턴 제한, ", "우측 둔근 활성 저하. ROM/MMT 재측정 필요."],
  ["요추 과신전 보상과 ", "둔근 약화가 동반된 움직임 패턴 문제."],
  ["dead bug 2세트, ", "hip hinge 드릴, 다음 세션에서 ROM/MMT 재확인."],
  ["고관절 굴곡", " ROM"],
  ["흉추 회전", " ROM"],
  ["우측 둔근", " MMT"],
  ["말단 가동", " 범위 제한"],
  ["우측 회전", " 제한"],
  ["초기 수축", " 지연"],
]

/// `data.structured.metrics` of a legacy fixture as stored.
private func stored(_ f: LoadedFixture) -> [JSONValue] {
  f.data["structured"]?["metrics"]?.arrayValue ?? []
}

private func utc(_ text: String) -> Date {
  guard let date = FixtureTimestamp.parse(text) else { fatalError("bad test timestamp \(text)") }
  return date
}

/// Object rows of `objective.metrics` (non-object rows are read directly by the tests that use them).
private func metricRows(_ data: JSONValue) -> [[String: JSONValue]] {
  (data["objective"]?["metrics"]?.arrayValue ?? []).compactMap(\.objectValue)
}

private func withMetrics(_ data: JSONValue, _ rows: [JSONValue]) throws -> JSONValue {
  var object = try XCTUnwrap(data.objectValue)
  var objective = try XCTUnwrap(object["objective"]?.objectValue)
  objective["metrics"] = .array(rows)
  object["objective"] = .object(objective)
  return .object(object)
}

private func row(_ strings: [String: String], value: JSONValue?) -> JSONValue {
  var out = strings.mapValues(JSONValue.string)
  out["value"] = value
  return .object(out)
}

/// Differences between two values, one line per difference (same rules as the Dart `structuralDiff`):
/// key order ignored, a missing key and null are different, numbers by value, `int` never equals `number`,
/// timestamps as instants.
func structuralDiff(_ actual: JSONValue, _ expected: JSONValue, at path: String = "data") -> [String] {
  switch (actual, expected) {
  case let (.object(a), .object(e)):
    var out: [String] = []
    for key in e.keys.sorted() where a[key] == nil { out.append("\(path)/\(key): missing (expected \(e[key]!))") }
    for key in a.keys.sorted() {
      if let ev = e[key] {
        out += structuralDiff(a[key]!, ev, at: "\(path)/\(key)")
      } else {
        out.append("\(path)/\(key): unexpected \(a[key]!)")
      }
    }
    return out
  case let (.array(a), .array(e)):
    guard a.count == e.count else { return ["\(path): length \(a.count) != \(e.count)"] }
    return zip(a, e).enumerated().flatMap { structuralDiff($0.element.0, $0.element.1, at: "\(path)/\($0.offset)") }
  default:
    return actual == expected ? [] : ["\(path): \(actual) != \(expected)"]
  }
}

// MARK: - Test-built models

/// Swift models built by hand with the same meaning as the three record-mode inputs (the Dart twin is
/// `expectedModels` in test/contracts/soap_v2_fixture_test.dart).
private let expectedModels: [String: SoapNoteV2] = [
  "finalized_no_metrics": SoapNoteV2(
    trainerId: .value("fx-trainer-001"),
    authorUid: "fx-trainer-001",
    member: .uid("fx-member-001"),
    sessionDate: .instant(utc("2026-09-28T01:00:00Z")),
    status: .finalized,
    quickNote: "가상 회원 A, 오른쪽 어깨가 뻐근하다고 말함",
    objective: SoapObjective(metrics: [], refs: .empty, snapshots: []),
    plan: SoapPlan(nextSession: "어깨 가동성 운동 이어서 진행", homeExercise: ""),
    legalNature: "coachingRecord",
    isSharedWithMember: false,
    finalizedAt: .instant(utc("2026-09-28T02:00:00Z")),
    createdAt: .instant(utc("2026-09-28T01:00:05Z")),
    updatedAt: .instant(utc("2026-09-28T02:00:00Z"))),
  "draft_rom_mmt_pain": SoapNoteV2(
    trainerId: .value("fx-trainer-001"),
    authorUid: "fx-trainer-001",
    member: .uid("fx-member-001"),
    sessionDate: .instant(utc("2026-09-29T01:00:00Z")),
    status: .draft,
    quickNote: "가상 회원 A, 팔을 옆으로 들 때 오른쪽 어깨가 불편하다고 말함",
    subjective: SoapSubjective(chiefComplaint: "오른쪽 어깨를 들 때 불편하다고 함", painNrs: .value(4), painRegions: ["shoulderRight"]),
    objective: SoapObjective(
      metrics: [
        .parsed(ParsedMetric(
          metricCode: .romDeg, value: 110, unit: .deg, side: .right, sourceGrade: .trainerObserved,
          joint: .shoulder, motion: .flexion, activeOrPassive: .active)),
        .parsed(ParsedMetric(
          metricCode: .mmtGrade, value: 4, unit: .grade, side: .right, sourceGrade: .trainerObserved,
          muscleGroup: .shoulderAbductors, note: "가상 관찰 메모")),
      ],
      refs: .empty, snapshots: []),
    plan: SoapPlan(nextSession: "어깨 외전 가동성 다시 확인", homeExercise: "벽 짚고 팔 올리기 10회"),
    legalNature: "coachingRecord",
    isSharedWithMember: false,
    createdAt: .instant(utc("2026-09-29T01:00:03Z")),
    updatedAt: .instant(utc("2026-09-29T01:40:00Z"))),
  "pending_member_draft": SoapNoteV2(
    trainerId: .value("fx-trainer-001"),
    authorUid: "fx-trainer-001",
    member: .pending("fx-pending-001"),
    sessionDate: .instant(utc("2026-09-30T14:00:00+09:00")),
    status: .draft,
    quickNote: "가상 회원 B, 첫 세션. 허리 숙일 때 뻐근하다고 말함",
    inkPath: .value("soapInk/fx-note-v2-003/1.drawing"),
    inkRevision: 1,
    subjective: SoapSubjective(painNrs: .null, painRegions: []),
    legalNature: "coachingRecord",
    createdAt: .server,
    updatedAt: .server),
]
