import Foundation
import XCTest
@testable import TrainerDomain

/// DF-108: TR-14 minimal registration rules. Synthetic data only.
final class PendingMemberTests: XCTestCase {
  /// 2026-06-01 12:00 KST.
  private let now2026 = Date(timeIntervalSince1970: 1_780_282_800)

  func test_TC_108_01_ageGateBoundaries() {
    XCTAssertEqual(AgeGate.currentYear(now: now2026), 2026)
    XCTAssertTrue(AgeGate.isEligible(birthYear: 2011, now: now2026))
    XCTAssertFalse(AgeGate.isEligible(birthYear: 2012, now: now2026), "one year stricter than the rules (ASM-P1a-02)")
    XCTAssertFalse(AgeGate.isEligible(birthYear: 2013, now: now2026))
    XCTAssertTrue(AgeGate.isEligible(birthYear: 1900, now: now2026))
    XCTAssertFalse(AgeGate.isEligible(birthYear: 1899, now: now2026))
    XCTAssertEqual(AgeGate.selectableYears(now: now2026).first, 2011)
    XCTAssertEqual(AgeGate.selectableYears(now: now2026).last, 1900)
  }

  /// The Seoul year decides: 2026-12-31 20:00 UTC is already 2027 in Seoul.
  func testTheYearIsTheSeoulYear() {
    let newYearInSeoul = Date(timeIntervalSince1970: 1_798_747_200)  // 2026-12-31T20:00:00Z
    XCTAssertEqual(AgeGate.currentYear(now: newYearInSeoul), 2027)
    XCTAssertTrue(AgeGate.isEligible(birthYear: 2012, now: newYearInSeoul))
  }

  func test_TC_108_02_payloadHasExactlyTheRulesKeys() throws {
    let draft = PendingMemberDraft(displayName: "  가상회원 가 ", sex: .female, birthYear: 1990, ageConfirmed14: true)
    let fields = try XCTUnwrap(PendingMemberPayload.fields(draft, trainerUid: "synthTrainerA", now: now2026))
    guard case let .object(object) = fields else { return XCTFail("object expected") }
    XCTAssertEqual(Set(object.keys).union(["createdAt", "updatedAt"]), PendingMemberPayload.documentKeys)
    XCTAssertEqual(object["displayName"], .string("가상회원 가"))
    XCTAssertEqual(object["sex"], .string("female"))
    XCTAssertEqual(object["birthYear"], .int(1990))
    XCTAssertEqual(object["ageConfirmed14"], .bool(true))
    XCTAssertEqual(object["status"], .string("pending"))
    XCTAssertEqual(object["schemaVersion"], .int(1))
    for forbidden in ["heightCm", "phone", "email", "address"] { XCTAssertNil(object[forbidden], forbidden) }
  }

  /// The payload keys are the rules' `pendingCreateKeys()` list (read from firestore.rules).
  func testDocumentKeysAreTheRulesCreateKeys() throws {
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0..<6 { root.deleteLastPathComponent() }
    let rules = try String(contentsOf: root.appendingPathComponent("firestore.rules"), encoding: .utf8)
    let marker = "function pendingCreateKeys() {"
    let start = try XCTUnwrap(rules.range(of: marker))
    let open = try XCTUnwrap(rules[start.upperBound...].range(of: "["))
    let close = try XCTUnwrap(rules[open.upperBound...].range(of: "]"))
    let keys = rules[open.upperBound..<close.lowerBound].split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(["'"])) }
    XCTAssertEqual(Set(keys), PendingMemberPayload.documentKeys)
  }

  func testEveryProblemBlocksThePayload() {
    let complete = PendingMemberDraft(displayName: "가상회원 나", sex: .unspecified, birthYear: 2011, ageConfirmed14: true)
    XCTAssertEqual(complete.problems(now: now2026), [])
    XCTAssertNotNil(PendingMemberPayload.fields(complete, trainerUid: "t", now: now2026))
    let cases: [(PendingMemberDraft, PendingMemberDraftProblem)] = [
      (PendingMemberDraft(displayName: "   ", sex: .male, birthYear: 1990, ageConfirmed14: true), .nameMissingOrTooLong),
      (PendingMemberDraft(displayName: String(repeating: "가", count: 41), sex: .male, birthYear: 1990, ageConfirmed14: true),
       .nameMissingOrTooLong),
      (PendingMemberDraft(displayName: "가상", sex: nil, birthYear: 1990, ageConfirmed14: true), .sexNotChosen),
      (PendingMemberDraft(displayName: "가상", sex: .male, birthYear: nil, ageConfirmed14: true), .birthYearMissing),
      (PendingMemberDraft(displayName: "가상", sex: .male, birthYear: 2012, ageConfirmed14: true), .under14),
      (PendingMemberDraft(displayName: "가상", sex: .male, birthYear: 1990, ageConfirmed14: false), .ageNotConfirmed),
    ]
    for (draft, problem) in cases {
      XCTAssertEqual(draft.problems(now: now2026), [problem])
      XCTAssertNil(PendingMemberPayload.fields(draft, trainerUid: "t", now: now2026), "\(problem)")
    }
  }

  func testDocumentIDsHaveTheAutoIDShape() {
    var ids = Set<String>()
    for _ in 0..<200 {
      let id = DocumentID.make()
      XCTAssertTrue(DocumentID.isValid(id), id)
      XCTAssertNotNil(id.range(of: "^[A-Za-z0-9]{20}$", options: .regularExpression))
      ids.insert(id)
    }
    XCTAssertEqual(ids.count, 200)
    XCTAssertFalse(DocumentID.isValid("short"))
    XCTAssertFalse(DocumentID.isValid("가나다라마바사아자차카타파하가나다라마바"))
  }
}
