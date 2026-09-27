import FirebaseAuth
import Foundation
import TrainerDomain
import XCTest
@testable import DFETTrainer

/// The live Apple composition: SwiftData LocalStore → SyncEngine → Firestore / recordConsent, with no fake writer.
/// All fixtures are synthetic and run only in demo-dfet with Auth, Firestore and Functions explicitly enabled.
final class ConsentBodyWorkflowEmulatorTests: XCTestCase {
  private var configured = false

  override func setUpWithError() throws {
    try IntegrationEmulator.require("DFET_AUTH_EMULATOR", "DFET_FIRESTORE_EMULATOR", "DFET_FUNCTIONS_EMULATOR")
    try IntegrationEmulator.configure()
    configured = true
    try? Auth.auth().signOut()
  }

  override func tearDownWithError() throws {
    guard configured else { return }
    try? Auth.auth().signOut()
  }

  @MainActor
  func testRegistrationConsentAndBodyCompositionReachTheServer() async throws {
    let trainer = try await seedTrainer()
    let documentIDs = try await seedPublishedDocuments()
    let session = try await AppBootstrap.liveAuthService().signIn(email: trainer.email, password: trainer.password)
    let services = AppBootstrap.liveServices(session: session)
    let consent = try XCTUnwrap(services.consent)
    let measurements = try XCTUnwrap(services.measurements)
    let published = try await consent.publishedDocuments()
    let selected = ConsentFlowRules.latestPublished(published.filter { documentIDs.contains($0.id) })
    XCTAssertEqual(Set(selected.keys), Set(ConsentFlowRules.coreTypes))
    XCTAssertTrue(selected.values.allSatisfy(\.isCompletePublished))

    let memberID = try await services.registrar.register(PendingMemberDraft(
      displayName: "합성 동의·신체조성 회원", sex: .unspecified, birthYear: 1990, ageConfirmed14: true))
    let member = MemberKey.pending(memberID)
    XCTAssertTrue(DocumentID.isValid(memberID))
    let pending = try await waitForDocument("pendingMembers/\(memberID)")
    XCTAssertEqual(string(pending["trainerId"]), trainer.uid)
    XCTAssertEqual(string(pending["status"]), "pending")

    // This synthetic tripwire is seeded only AFTER registration: the rules correctly prohibit creating a pending
    // member whose ID already exists in users. Neither users.height nor users.weight may supply trainer inputs.
    try await EmulatorDocuments.put("users/\(memberID)", [
      "displayName": "합성 원시값 대조 문서", "trainerId": trainer.uid, "role": "member",
      "height": 1.99, "weight": 120.0,
    ])
    let measuredAt = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970) - 3_600)
    let withoutHeight = BodyCompositionDraft(values: [.weightKg: "70,5", .bodyFatPercent: "22,4"],
      deviceModel: "  합성   체성분 기기  ", measuredAt: measuredAt, fasting: .yes)
    do {
      _ = try await measurements.saveBodyComposition(member: member, draft: withoutHeight)
      XCTFail("a member without healthData consent must not save a measurement")
    } catch {
      XCTAssertEqual(error as? MeasurementStoreError, .consentRequired(.healthData))
    }

    try await consent.captureInPerson(member: member,
      selections: ConsentFlowRules.coreTypes.map { ConsentSelection(type: $0, granted: true) },
      documentVersions: selected.mapValues(\.id))
    // Do not wait for the callable: the local capture permits saving and the engine orders the server writes.
    let firstID = try await measurements.saveBodyComposition(member: member, draft: withoutHeight)
    let localRecords = try await firstValue(of: measurements.observeBodyCompositionRecords(
      member: member, since: .distantPast))
    let localRecord = try XCTUnwrap(localRecords?.first { $0.id == firstID })
    XCTAssertEqual(localRecord.values[.weightKg], 70.5)
    XCTAssertNil(localRecord.derived, "raw users.height must not become a trainer height or BMI")

    let firstStored = try await waitForDocument(BodyCompositionPayload.path(id: firstID))
    XCTAssertEqual(string(firstStored["pendingMemberId"]), memberID)
    XCTAssertEqual(string(firstStored["enteredBy"]), trainer.uid)
    XCTAssertEqual(string(firstStored["sourceGrade"]), "device")
    XCTAssertEqual(string(firstStored["deviceModel"]), "합성 체성분 기기")
    XCTAssertEqual(number(map(firstStored["values"])["weightKg"]), 70.5)
    XCTAssertEqual(number(map(firstStored["values"])["bodyFatPercent"]), 22.4)
    XCTAssertNil(firstStored["derived"])

    let effective = try await firstMatching(of: consent.observe(member: member)) { $0.coreGranted }
    XCTAssertEqual(effective.healthRecordSave, .allowed)
    XCTAssertTrue(effective.canAttachPhoto)
    let serverState = try await waitForDocument("memberConsentStates/\(memberID)")
    for type in ConsentFlowRules.coreTypes {
      let state = map(serverState[type.rawValue])
      XCTAssertEqual((state["granted"] as? [String: Any])?["booleanValue"] as? Bool, true)
      XCTAssertEqual(string(state["documentVersion"]), selected[type]?.id)
      let recordID = try XCTUnwrap(string(state["recordId"]))
      let record = try await waitForDocument("consentRecords/\(recordID)")
      XCTAssertEqual(string(record["pendingMemberId"]), memberID)
      XCTAssertEqual(string(record["recordedBy"]), trainer.uid)
      XCTAssertEqual(string(record["consentType"]), type.rawValue)
      XCTAssertEqual(string(record["action"]), "grant")
      XCTAssertEqual(string(record["channel"]), "trainerDeviceInPerson")
    }

    let heightMeasuredAt = measuredAt.addingTimeInterval(-86_400)
    var withHeight = withoutHeight
    withHeight.measuredAt = measuredAt.addingTimeInterval(60)
    withHeight.heightCmInput = "175"
    withHeight.heightMeasuredAt = heightMeasuredAt
    let secondID = try await measurements.saveBodyComposition(member: member, draft: withHeight)
    let secondStored = try await waitForDocument(BodyCompositionPayload.path(id: secondID))
    let derived = map(secondStored["derived"])
    XCTAssertEqual(number(derived["heightCmUsed"]), 175)
    XCTAssertEqual(number(derived["bmi"]), 23.0)
    XCTAssertEqual(string(derived["sourceGrade"]), "derived")
    XCTAssertEqual(timestamp(derived["heightMeasuredAt"]), heightMeasuredAt)
    let updatedPending = try await waitForDocument("pendingMembers/\(memberID)") {
      self.number($0["heightCm"]) == 175
    }
    XCTAssertEqual(timestamp(updatedPending["heightMeasuredAt"]), heightMeasuredAt)
    let rawUserFields = try await EmulatorDocuments.get("users/\(memberID)")
    let rawUser = try XCTUnwrap(rawUserFields)
    XCTAssertEqual(number(rawUser["height"]), 1.99)
    XCTAssertEqual(number(rawUser["weight"]), 120)
    let synced = try await firstMatching(of: await measurements.observeBodyCompositionSyncState(recordID: secondID)) {
      $0 == .synced
    }
    XCTAssertEqual(synced, .synced)
  }

  @MainActor
  func testRequiredRefusalCancelsPendingWithoutGrantingHealthConsent() async throws {
    let trainer = try await seedTrainer()
    let session = try await AppBootstrap.liveAuthService().signIn(email: trainer.email, password: trainer.password)
    let services = AppBootstrap.liveServices(session: session)
    let consent = try XCTUnwrap(services.consent)
    let measurements = try XCTUnwrap(services.measurements)
    let memberID = try await services.registrar.register(PendingMemberDraft(
      displayName: "합성 등록 취소 회원", sex: .unspecified, birthYear: 1990, ageConfirmed14: true))
    let member = MemberKey.pending(memberID)
    // The refusal path uses cancelPending, never a grant/refusal call to recordConsent.
    try await consent.cancelPending(member: member)
    let pending = try await waitForDocument("pendingMembers/\(memberID)") { self.string($0["status"]) == "cancelled" }
    XCTAssertEqual(string(pending["trainerId"]), trainer.uid)
    let state = try await EmulatorDocuments.get("memberConsentStates/\(memberID)")
    XCTAssertNil(state)
    let effective = try await firstMatching(of: consent.observe(member: member)) { $0 == .none }
    XCTAssertEqual(effective.healthRecordSave, .blocked)
    do {
      _ = try await measurements.saveBodyComposition(member: member, draft: BodyCompositionDraft(
        values: [.weightKg: "70"], deviceModel: "합성 기기", measuredAt: Date(), fasting: .no))
      XCTFail("a cancelled registration must not allow a health record")
    } catch {
      XCTAssertEqual(error as? MeasurementStoreError, .consentRequired(.healthData))
    }
  }

  private func seedTrainer() async throws -> EmulatorAccounts.Account {
    let trainer = try await EmulatorAccounts.create(claims: ["trainer": true])
    try await EmulatorDocuments.put("trainers/\(trainer.uid)", [
      "trainerId": trainer.uid, "memberIds": [String](), "approvalStatus": "approved",
    ])
    try await EmulatorDocuments.put("appConfig/features", [
      "gut": false, "blood": false, "insights": false, "soapV2": true, "bodyComposition": true,
      "bodyAssessment": true, "memberShare": true, "lidarBeta": false,
    ])
    return trainer
  }

  private func seedPublishedDocuments() async throws -> Set<String> {
    let version = "workflow-\(UUID().uuidString.lowercased())"
    var ids = Set<String>()
    for type in ConsentFlowRules.coreTypes {
      let id = "\(type.rawValue)--\(version)"
      try await EmulatorDocuments.put("consentDocumentVersions/\(id)", [
        "consentType": type.rawValue, "version": version, "title": "[테스트 전용] \(type.rawValue)",
        "purpose": "합성 회원 동의·신체조성 통합 테스트", "items": ["합성 테스트 정보"],
        "retention": "에뮬레이터 테스트 종료 시 삭제", "refusalNotice": "동의를 거부할 수 있습니다.",
        "privacyPolicyVersion": "workflow-test-only", "status": "published", "schemaVersion": 1,
        "publishedAt": Date().addingTimeInterval(-60),
      ])
      ids.insert(id)
    }
    return ids
  }

  private func waitForDocument(_ path: String, matching predicate: ([String: Any]) -> Bool = { _ in true })
    async throws -> [String: Any] {
    for _ in 0..<450 {
      if let fields = try await EmulatorDocuments.get(path), predicate(fields) { return fields }
      try await Task.sleep(nanoseconds: 100_000_000)
    }
    throw NSError(domain: "ConsentBodyWorkflowTimeout", code: 1,
      userInfo: [NSLocalizedDescriptionKey: "server document did not reach the expected state: \(path)"])
  }

  private func firstMatching<T: Sendable>(of stream: AsyncStream<T>, matching predicate: @escaping @Sendable (T) -> Bool)
    async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
      group.addTask {
        for await value in stream where predicate(value) { return value }
        throw NSError(domain: "ConsentBodyWorkflowStreamEnded", code: 1)
      }
      group.addTask {
        try await Task.sleep(nanoseconds: 45_000_000_000)
        throw NSError(domain: "ConsentBodyWorkflowTimeout", code: 2)
      }
      defer { group.cancelAll() }
      let value = try await group.next()
      return try XCTUnwrap(value)
    }
  }

  private func map(_ field: Any?) -> [String: Any] {
    ((field as? [String: Any])?["mapValue"] as? [String: Any])?["fields"] as? [String: Any] ?? [:]
  }

  private func string(_ field: Any?) -> String? { (field as? [String: Any])?["stringValue"] as? String }

  private func number(_ field: Any?) -> Double? {
    guard let value = field as? [String: Any] else { return nil }
    return (value["doubleValue"] as? Double) ?? (value["integerValue"] as? String).flatMap(Double.init)
  }

  private func timestamp(_ field: Any?) -> Date? {
    guard let text = (field as? [String: Any])?["timestampValue"] as? String else { return nil }
    let formatter = ISO8601DateFormatter()
    if let date = formatter.date(from: text) { return date }
    formatter.formatOptions.insert(.withFractionalSeconds)
    return formatter.date(from: text)
  }
}
