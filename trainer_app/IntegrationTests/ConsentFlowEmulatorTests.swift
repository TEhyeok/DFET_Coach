import FirebaseAuth
import Foundation
import TrainerContracts
import TrainerDomain
import XCTest
@testable import DFETTrainer

/// End to end (DF-109, DF-110, DF-111, DF-113 MVP) against the Auth, Firestore and Functions emulators, firestore.rules
/// and the real `recordConsent`, through the live shell services: a synthetic trainer registers a pending member
/// (TR-14 registrar), TR-02's pending stream lists it, ①②③ are captured through the Outbox `callConsent` item (it
/// depends on the member's create), the SyncEngine sends the create and then `recordConsent`, the server derives
/// `memberConsentStates`, and the effective consent every chip reads goes '동의 필요' → '동의 확인 대기' →
/// '동의 ①②③'. The published test documents are the ones functions/scripts/publish-test-consent-documents.js writes;
/// test_auth_emulator.sh applies it to the emulator before the tests. Synthetic data only; every run uses its own
/// trainer and LocalStore partition.
final class ConsentFlowEmulatorTests: XCTestCase {
  private var configured = false
  private static let testDocuments = ["required--test-1", "healthData--test-1", "bodyImaging--test-1"]

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
  func testARegisteredPendingMembersCoreConsentsAreRecordedByTheServer() async throws {
    let trainer = try await EmulatorAccounts.create(claims: ["trainer": true])
    try await EmulatorDocuments.put("trainers/\(trainer.uid)", [
      "trainerId": trainer.uid, "memberIds": [String](), "approvalStatus": "approved",
    ])
    let session = try await AppBootstrap.liveAuthService().signIn(email: trainer.email, password: trainer.password)
    let services = AppBootstrap.liveServices(session: session)

    // The consent step's documents: the publish script's test documents read as published versions of ①②③.
    let documents = try await services.consentDocuments.publishedDocuments()
    XCTAssertTrue(Set(Self.testDocuments).isSubset(of: Set(documents.map(\.id))),
                  "publish the test consent documents to the emulator (test_auth_emulator.sh does)")
    let latest = ConsentFlowRules.latestPublished(documents)
    XCTAssertEqual(ConsentFlowRules.missingCoreTypes(in: latest), [])

    // TR-14 registration: saved on the device, its create queued.
    let draft = PendingMemberDraft(displayName: "가상 동의 회원", sex: .unspecified, birthYear: 1990, ageConfirmed14: true)
    let id = try await services.registrar.register(draft)
    let member = MemberKey.pending(id)

    // The chips' source, followed from before the capture.
    let chips = ValueLog<ConsentChipState>()
    let watcher = Task {
      for await value in services.effectiveConsent.observe(member: member) { await chips.append(value.chipState) }
    }
    defer { watcher.cancel() }
    try await Self.waitUntil("the first effective consent") { await !chips.values.isEmpty }
    let first = await chips.values.first
    XCTAssertEqual(first, .needed, "nothing is recorded yet")

    // TR-14 consent step: ①②③ granted, one capture with its `callConsent` item (the step's own rules build it).
    let choices = Dictionary(uniqueKeysWithValues: ConsentFlowRules.coreTypes.map { ($0, ConsentChoice.grant) })
    let selections = try XCTUnwrap(ConsentFlowRules.selections(choices: choices, documents: latest))
    let captureId = try await services.consentRecorder.capture(member: member, selections: selections)

    try await Self.waitUntil("'동의 ①②③' from the server's state", timeout: 120) {
      await chips.values.last == .coreGranted
    }
    let seen = await chips.values
    XCTAssertEqual(seen, [.needed, .awaiting, .coreGranted], "the capture waits for the server, then the server grants")

    // What recordConsent derived: memberConsentStates/{id} with ①②③ granted at the sent versions.
    let stateFields = try await EmulatorDocuments.get("memberConsentStates/\(id)")
    let state = try XCTUnwrap(stateFields)
    for type in ConsentFlowRules.coreTypes {
      let entry = try XCTUnwrap(Self.map(state[type.rawValue]), type.rawValue)
      XCTAssertEqual(Self.bool(entry["granted"]), true, type.rawValue)
      XCTAssertEqual(Self.string(entry["documentVersion"]), latest[type]?.id, type.rawValue)
    }
    let healthData = try XCTUnwrap(Self.map(state["healthData"]))
    let recordId = try XCTUnwrap(Self.string(healthData["recordId"]))

    // One of the three records: the capture ID is the idempotency key, the trainer recorded it in person, no signature.
    let recordFields = try await EmulatorDocuments.get("consentRecords/\(recordId)")
    let record = try XCTUnwrap(recordFields)
    XCTAssertEqual(Self.string(record["clientCaptureId"]), captureId)
    XCTAssertEqual(Self.string(record["pendingMemberId"]), id)
    XCTAssertEqual(Self.string(record["consentType"]), "healthData")
    XCTAssertEqual(Self.string(record["action"]), "grant")
    XCTAssertEqual(Self.string(record["channel"]), "trainerDeviceInPerson")
    XCTAssertEqual(Self.string(record["recordedBy"]), trainer.uid)
    XCTAssertTrue(Self.isNull(record["signaturePath"]), "MVP: no signature")
    XCTAssertTrue(Self.isNull(record["subjectUid"]), "a pending member has no uid")

    // TR-02: the member is in the server's pending list (the create reached the server before the consent).
    let listed = try await Self.first(services.memberDirectory.observePendingMembers()) { list in
      list.contains { $0.id == id }
    }
    XCTAssertEqual(listed?.first { $0.id == id }?.displayName, "가상 동의 회원")

    // Nothing is left in the Outbox, and nothing failed.
    let pending = try await Self.first(await services.syncQueue.pendingCount()) { $0 == 0 }
    XCTAssertEqual(pending, 0)
    let failed = try await Self.first(await services.syncQueue.failedItems()) { _ in true }
    XCTAssertEqual(failed?.count, 0)

    try await services.signOut.signOut()
  }

  // MARK: Helpers

  /// Values a stream produced, in order, without repeats.
  private actor ValueLog<T: Equatable & Sendable> {
    private(set) var values: [T] = []

    func append(_ value: T) {
      if values.last != value { values.append(value) }
    }
  }

  private static func waitUntil(
    _ what: String, timeout seconds: Double = 30, _ condition: @escaping @Sendable () async -> Bool
  ) async throws {
    let deadline = Date().addingTimeInterval(seconds)
    while !(await condition()) {
      guard Date() < deadline else {
        XCTFail("timed out waiting for \(what)")
        throw NSError(domain: "IntegrationTimeout", code: 1)
      }
      try await Task.sleep(nanoseconds: 100_000_000)
    }
  }

  /// The first value that satisfies `condition`, or nil after `seconds`.
  private static func first<S: AsyncSequence & Sendable>(
    _ stream: S, timeout seconds: Double = 30, where condition: @escaping @Sendable (S.Element) -> Bool
  ) async throws -> S.Element? where S.Element: Sendable {
    try await withThrowingTaskGroup(of: S.Element?.self) { group in
      group.addTask {
        for try await value in stream where condition(value) { return value }
        return nil
      }
      group.addTask {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        return nil
      }
      let value = try await group.next() ?? nil
      group.cancelAll()
      return value
    }
  }

  // Firestore REST values.
  private static func map(_ value: Any?) -> [String: Any]? {
    ((value as? [String: Any])?["mapValue"] as? [String: Any])?["fields"] as? [String: Any]
  }

  private static func string(_ value: Any?) -> String? {
    (value as? [String: Any])?["stringValue"] as? String
  }

  private static func bool(_ value: Any?) -> Bool? {
    (value as? [String: Any])?["booleanValue"] as? Bool
  }

  private static func isNull(_ value: Any?) -> Bool {
    (value as? [String: Any])?["nullValue"] != nil
  }
}
