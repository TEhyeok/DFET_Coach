import Foundation
import TrainerContracts
import XCTest
@testable import TrainerDomain

/// DF-110 MVP: the TR-14 consent step's pure rules and the `recordConsent` request of an in-person capture, checked
/// against the V1-06 §6.2.1 request schema read from the spec itself. Synthetic values only.
final class ConsentFlowTests: XCTestCase {
  private let published = FixtureTimestamp.parse("2026-11-02T09:00:00+09:00")!
  private let capturedAt = FixtureTimestamp.parse("2026-11-16T10:12:30+09:00")!
  private let captureId = "3f2b8c1e-5d7a-4b1e-9a51-0c8e2d7f1a90"

  private func document(_ type: ConsentType, _ version: String, publishedAt: Date?) -> ConsentDocumentVersion {
    ConsentDocumentVersion(id: "\(type.rawValue)--\(version)", consentType: type, version: version,
                           publishedAt: publishedAt)
  }

  private var coreDocuments: [ConsentType: ConsentDocumentVersion] {
    ConsentFlowRules.latestPublished(ConsentFlowRules.coreTypes.map { document($0, "1.0", publishedAt: published) })
  }

  // MARK: Documents

  /// V1-05 §4.13: only a published document with a known type and a version can be chosen.
  func testDocumentVersionReadsOnlyPublishedDocuments() {
    let fields: [String: JSONValue] = [
      "consentType": .string("healthData"), "version": .string("1.0"), "title": .string("SYN 합성 문서"),
      "status": .string("published"), "publishedAt": .timestamp(published), "schemaVersion": .int(1),
    ]
    XCTAssertEqual(ConsentDocumentVersion(id: "healthData--1.0", document: .object(fields)),
                   document(.healthData, "1.0", publishedAt: published))
    var retired = fields
    retired["status"] = .string("retired")
    XCTAssertNil(ConsentDocumentVersion(id: "healthData--1.0", document: .object(retired)))
    var draft = fields
    draft["status"] = .string("draft")
    XCTAssertNil(ConsentDocumentVersion(id: "healthData--1.0", document: .object(draft)))
    var unknownType = fields
    unknownType["consentType"] = .string("marketing")
    XCTAssertNil(ConsentDocumentVersion(id: "marketing--1.0", document: .object(unknownType)))
    var noVersion = fields
    noVersion["version"] = .string("")
    XCTAssertNil(ConsentDocumentVersion(id: "healthData--", document: .object(noVersion)))
    var noDate = fields
    noDate["publishedAt"] = .null
    XCTAssertNil(ConsentDocumentVersion(id: "healthData--1.0", document: .object(noDate))?.publishedAt)
  }

  /// TC-110-02 (MVP): the newest published version of each type.
  func testLatestPublishedPicksTheNewestVersionPerType() {
    let later = published.addingTimeInterval(86_400)
    let latest = ConsentFlowRules.latestPublished([
      document(.healthData, "1.0", publishedAt: published),
      document(.healthData, "1.1", publishedAt: later),
      document(.healthData, "0.9", publishedAt: nil),
      document(.required, "1.0", publishedAt: published),
    ])
    XCTAssertEqual(latest[.healthData]?.id, "healthData--1.1")
    XCTAssertEqual(latest[.required]?.id, "required--1.0")
    XCTAssertNil(latest[.bodyImaging])
    XCTAssertEqual(ConsentFlowRules.missingCoreTypes(in: latest), [.bodyImaging], "AC-DF-110.3: the step stops")
    XCTAssertEqual(ConsentFlowRules.missingCoreTypes(in: coreDocuments), [])
  }

  // MARK: Choices

  /// TC-110-01 (MVP, no signature): nothing until ①②③ are all answered; grants only, in card order.
  func testSelectionsNeedEveryCoreAnswerAndRecordGrantsOnly() {
    XCTAssertEqual(ConsentFlowRules.coreTypes, [.required, .healthData, .bodyImaging])
    XCTAssertNil(ConsentFlowRules.selections(choices: [:], documents: coreDocuments))
    XCTAssertNil(ConsentFlowRules.selections(choices: [.required: .grant, .healthData: .grant],
                                             documents: coreDocuments), "③ unanswered")
    XCTAssertEqual(
      ConsentFlowRules.selections(choices: [.bodyImaging: .grant, .required: .grant, .healthData: .grant],
                                  documents: coreDocuments),
      [ConsentSelection(consentType: .required, action: .grant, documentVersion: "required--1.0"),
       ConsentSelection(consentType: .healthData, action: .grant, documentVersion: "healthData--1.0"),
       ConsentSelection(consentType: .bodyImaging, action: .grant, documentVersion: "bodyImaging--1.0")])
    XCTAssertEqual(
      ConsentFlowRules.selections(choices: [.required: .grant, .healthData: .refuse, .bodyImaging: .refuse],
                                  documents: coreDocuments),
      [ConsentSelection(consentType: .required, action: .grant, documentVersion: "required--1.0")],
      "a refusal leaves no record (F-PRIV-01.1)")
  }

  /// ① refused: nothing can be granted without it (V1-06 V8), so nothing is recorded.
  func testRequiredRefusedRecordsNothing() {
    let choices: [ConsentType: ConsentChoice] = [.required: .refuse, .healthData: .grant, .bodyImaging: .grant]
    XCTAssertTrue(ConsentFlowRules.requiredRefused(choices))
    XCTAssertNil(ConsentFlowRules.selections(choices: choices, documents: coreDocuments))
    XCTAssertFalse(ConsentFlowRules.requiredRefused([.required: .grant]))
    XCTAssertFalse(ConsentFlowRules.requiredRefused([:]))
  }

  /// Review (re-entry after a partial consent): types the member already holds, confirmed or waiting for the server,
  /// are not asked again. The MVP cannot record a refusal of one (withdrawal is DF-112), so an answer for it is
  /// ignored and only the other cards are recorded; a missing or rejected type is asked.
  func testHeldTypesAreNotAskedAgain() {
    let partial = EffectiveConsent(required: .awaitingConsent, healthData: .granted, bodyImaging: .missing)
    XCTAssertEqual(ConsentFlowRules.heldTypes(in: partial), [.required, .healthData])
    XCTAssertEqual(ConsentFlowRules.heldTypes(in: .none), [])
    XCTAssertEqual(ConsentFlowRules.heldTypes(
      in: EffectiveConsent(required: .granted, healthData: .rejected, bodyImaging: .awaitingConsent)),
      [.required, .bodyImaging], "a capture the server refused is asked again")

    let held = ConsentFlowRules.heldTypes(in: partial)
    XCTAssertNil(ConsentFlowRules.selections(choices: [.healthData: .refuse], documents: coreDocuments, held: held),
                 "③ unanswered")
    XCTAssertEqual(
      ConsentFlowRules.selections(choices: [.required: .refuse, .healthData: .refuse, .bodyImaging: .grant],
                                  documents: coreDocuments, held: held),
      [ConsentSelection(consentType: .bodyImaging, action: .grant, documentVersion: "bodyImaging--1.0")],
      "a refusal of a held type cannot take its grant back, and a held ① is not refused")
    XCTAssertEqual(
      ConsentFlowRules.selections(choices: [.bodyImaging: .refuse], documents: coreDocuments, held: held), [],
      "every asked card refused: nothing to record")
    XCTAssertEqual(
      ConsentFlowRules.selections(choices: [:], documents: coreDocuments, held: [.required, .healthData, .bodyImaging]),
      [])
  }

  func testAGrantWithoutAPublishedVersionRecordsNothing() {
    var documents = coreDocuments
    documents[.bodyImaging] = nil
    XCTAssertNil(ConsentFlowRules.selections(
      choices: [.required: .grant, .healthData: .grant, .bodyImaging: .grant], documents: documents))
  }

  // MARK: recordConsent request (V1-06 §6.2.1)

  func testPayloadOfAPendingMemberCapture() {
    let selections = ConsentFlowRules.selections(
      choices: [.required: .grant, .healthData: .grant, .bodyImaging: .refuse], documents: coreDocuments)!
    let payload = RecordConsentRequest.payload(captureId: captureId, member: .pending("SYNTHpending00000001"),
                                               selections: selections, capturedAt: capturedAt)
    XCTAssertEqual(payload, .object([
      "clientCaptureId": .string(captureId),
      "memberKey": .object(["pendingMemberId": .string("SYNTHpending00000001")]),
      "channel": .string("trainerDeviceInPerson"),
      "selections": .array([
        .object(["consentType": .string("required"), "action": .string("grant"),
                 "documentVersion": .string("required--1.0")]),
        .object(["consentType": .string("healthData"), "action": .string("grant"),
                 "documentVersion": .string("healthData--1.0")]),
      ]),
      "capturedAt": .timestamp(capturedAt),
    ]))
    XCTAssertEqual(RecordConsentRequest.memberKey(.uid("synthMember0001")),
                   .object(["memberUid": .string("synthMember0001")]))
    XCTAssertEqual(RecordConsentRequest.callable, "recordConsent")
  }

  /// The request fits the V1-06 §6.2.1 schema as written in the spec: every required key, no key the schema does not
  /// list (`additionalProperties: false`), selection items with exactly the three required keys, and values that match
  /// the common patterns and enums (§3.12). No signature in the MVP (DF-109, DF-110 MVP).
  func testPayloadMatchesTheV1_06RequestSchema() throws {
    let schema = try Self.requestSchema()
    let common = try Self.specJSON(after: "### 3.12")
    let versionPattern = try XCTUnwrap(
      ((common["$defs"] as? [String: Any])?["ConsentDocumentVersionId"] as? [String: Any])?["pattern"] as? String)
    let required = Set(try XCTUnwrap(schema["required"] as? [String]))
    let properties = try XCTUnwrap(schema["properties"] as? [String: Any])
    let selectionItems = try XCTUnwrap(((properties["selections"] as? [String: Any])?["items"]) as? [String: Any])
    let itemRequired = Set(try XCTUnwrap(selectionItems["required"] as? [String]))
    let itemProperties = Set(try XCTUnwrap(selectionItems["properties"] as? [String: Any]).keys)

    for member in [MemberKey.pending("SYNTHpending00000001"), .uid("synthMember0001")] {
      let selections = ConsentFlowRules.coreTypes.map {
        ConsentSelection(consentType: $0, action: .grant, documentVersion: "\($0.rawValue)--1.0")
      }
      let fields = try XCTUnwrap(RecordConsentRequest.payload(
        captureId: UUID().uuidString.lowercased(), member: member, selections: selections, capturedAt: capturedAt
      ).objectValue)
      let keys = Set(fields.keys)
      XCTAssertEqual(keys, RecordConsentRequest.keys)
      XCTAssertTrue(required.isSubset(of: keys), "missing \(required.subtracting(keys))")
      XCTAssertTrue(keys.isSubset(of: Set(properties.keys)), "not in the schema: \(keys.subtracting(properties.keys))")
      XCTAssertNil(fields["signaturePngBase64"], "MVP: no signature")
      XCTAssertNil(fields["reconfirmOf"], "member app only")

      XCTAssertNotNil(fields["clientCaptureId"]?.stringValue?.range(of: "^[A-Za-z0-9_-]{8,64}$",
                                                                     options: .regularExpression))
      XCTAssertTrue(ConsentChannel.allCases.map(\.rawValue).contains(fields["channel"]?.stringValue ?? ""))
      let memberKey = try XCTUnwrap(fields["memberKey"]?.objectValue)
      XCTAssertEqual(memberKey.count, 1, "V1-06 MemberKey is oneOf with one key")
      XCTAssertTrue(["memberUid", "pendingMemberId"].contains(try XCTUnwrap(memberKey.keys.first)))
      XCTAssertEqual(memberKey.values.first?.stringValue, member.id)
      guard case .timestamp? = fields["capturedAt"] else { return XCTFail("capturedAt is a timestamp (IsoTime)") }

      let items = try XCTUnwrap(fields["selections"]?.arrayValue)
      XCTAssertTrue((1...5).contains(items.count))
      for item in items {
        let object = try XCTUnwrap(item.objectValue)
        XCTAssertEqual(Set(object.keys), itemRequired)
        XCTAssertTrue(Set(object.keys).isSubset(of: itemProperties))
        let type = try XCTUnwrap(ConsentType(rawValue: object["consentType"]?.stringValue ?? ""))
        XCTAssertNotNil(ConsentAction(rawValue: object["action"]?.stringValue ?? ""))
        // The document's own ID, `{consentType}--{version}` (V1-05 §4.13), V1-06 §3.12 `ConsentDocumentVersionId`:
        // the pattern the server's validateRequest uses too (its unit test reads the same definition).
        let version = try XCTUnwrap(object["documentVersion"]?.stringValue)
        XCTAssertEqual(version, "\(type.rawValue)--1.0")
        XCTAssertNotNil(version.range(of: versionPattern, options: .regularExpression), version)
      }
    }
  }

  /// The first JSON block after `#### 6.2.1` in docs/v1/06_API_SPEC.md.
  private static func requestSchema() throws -> [String: Any] {
    try specJSON(after: "#### 6.2.1")
  }

  /// The first JSON block after `heading` in docs/v1/06_API_SPEC.md.
  private static func specJSON(after heading: String) throws -> [String: Any] {
    let spec = try String(
      contentsOf: FixtureLoader.repositoryRoot.appendingPathComponent("docs/v1/06_API_SPEC.md"), encoding: .utf8)
    let section = try XCTUnwrap(spec.range(of: heading))
    let rest = spec[section.upperBound...]
    let open = try XCTUnwrap(rest.range(of: "```json\n"))
    let close = try XCTUnwrap(rest[open.upperBound...].range(of: "```"))
    let json = Data(rest[open.upperBound..<close.lowerBound].utf8)
    return try XCTUnwrap(try JSONSerialization.jsonObject(with: json) as? [String: Any])
  }
}
