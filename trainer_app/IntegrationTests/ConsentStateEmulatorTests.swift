import FirebaseAuth
import Foundation
import TrainerDomain
import XCTest
@testable import DFETTrainer

/// DF-110/DF-111 MVP against the Firestore emulator and firestore.rules: the live shell's consent reads.
/// `memberConsentStates` is server-written (R-20), so the test writes it as the emulator owner, as `recordConsent`
/// would. Synthetic data only; every run uses its own trainer.
final class ConsentStateEmulatorTests: XCTestCase {
  private var configured = false

  override func setUpWithError() throws {
    try IntegrationEmulator.require("DFET_AUTH_EMULATOR", "DFET_FIRESTORE_EMULATOR")
    try IntegrationEmulator.configure()
    configured = true
    try? Auth.auth().signOut()
  }

  override func tearDownWithError() throws {
    guard configured else { return }
    try? Auth.auth().signOut()
  }

  @MainActor
  private func signedInServices() async throws -> (ShellServices, EmulatorAccounts.Account) {
    let trainer = try await EmulatorAccounts.create(claims: ["trainer": true])
    try await EmulatorDocuments.put("trainers/\(trainer.uid)", [
      "trainerId": trainer.uid, "memberIds": [String](), "approvalStatus": "approved",
    ])
    let session = try await AppBootstrap.liveAuthService().signIn(email: trainer.email, password: trainer.password)
    return (AppBootstrap.liveServices(session: session), trainer)
  }

  /// The pending member's `memberConsentStates` listener is refused until `pendingMembers/{id}` is on the server
  /// (the read rule proves ownership through it): no state, and the stream ends. Once the member is there and the
  /// server has written the state, the effective consent reads ①②③ granted. Another trainer reads nothing.
  @MainActor
  func testAPendingMembersStateIsReadOnlyByItsTrainerOnceTheMemberIsOnTheServer() async throws {
    let (services, _) = try await signedInServices()
    let server = try XCTUnwrap(services.consentDocuments as? ConsentStateSource)

    let early = try await Self.collect(server.observe(member: .pending(DocumentID.make())))
    XCTAssertFalse(early.isEmpty)
    XCTAssertTrue(early.allSatisfy { $0 == nil }, "refused listener: no consent, stream ended")

    let draft = PendingMemberDraft(displayName: "가상 대기 회원", sex: .male, birthYear: 1990, ageConfirmed14: true)
    let id = try await services.registrar.register(draft)
    var created: [String: Any]?
    for _ in 0..<150 where created == nil {
      created = try await EmulatorDocuments.get("pendingMembers/\(id)")
      if created == nil { try await Task.sleep(nanoseconds: 100_000_000) }
    }
    XCTAssertNotNil(created, "the Outbox did not create pendingMembers/\(id)")

    let now = Date()
    try await EmulatorDocuments.put("memberConsentStates/\(id)", [
      "required": ["granted": true, "documentVersion": "required--1.0", "recordId": "SYNTHconsentRec00001",
                   "updatedAt": now],
      "healthData": ["granted": true, "documentVersion": "healthData--1.0", "recordId": "SYNTHconsentRec00002",
                     "updatedAt": now],
      "bodyImaging": ["granted": true, "documentVersion": "bodyImaging--1.0", "recordId": "SYNTHconsentRec00003",
                      "updatedAt": now],
      "updatedAt": now, "schemaVersion": 1,
    ])
    let granted = try await Self.first(services.effectiveConsent.observe(member: .pending(id))) {
      $0.chipState == .coreGranted
    }
    XCTAssertEqual(granted?.chipState, .coreGranted)
    XCTAssertEqual(granted?.canCapturePosture, true)

    // The real logout (listeners removed, Firestore cache cleared), then another trainer: the rules refuse the read.
    try await services.signOut.signOut()
    let (other, _) = try await signedInServices()
    let otherServer = try XCTUnwrap(other.consentDocuments as? ConsentStateSource)
    let foreign = try await Self.collect(otherServer.observe(member: .pending(id)))
    XCTAssertFalse(foreign.isEmpty)
    XCTAssertTrue(foreign.allSatisfy { $0 == nil }, "another trainer cannot read the state")
  }

  /// `consentDocumentVersions where status == 'published'` is allowed for a trainer and returns published versions
  /// only (V1-05 §4.13).
  @MainActor
  func testPublishedDocumentsAreReadable() async throws {
    let (services, _) = try await signedInServices()
    let published = Date(timeIntervalSince1970: 1_793_577_600)
    for type in ["required", "healthData", "bodyImaging"] {
      try await EmulatorDocuments.put("consentDocumentVersions/\(type)--1.0", [
        "consentType": type, "version": "1.0", "title": "SYN 합성 문서", "status": "published",
        "publishedAt": published, "schemaVersion": 1,
      ])
    }
    try await EmulatorDocuments.put("consentDocumentVersions/healthData--0.9", [
      "consentType": "healthData", "version": "0.9", "title": "SYN 합성 문서", "status": "retired",
      "publishedAt": published, "schemaVersion": 1,
    ])
    let documents = try await services.consentDocuments.publishedDocuments()
    XCTAssertTrue(Set(["required--1.0", "healthData--1.0", "bodyImaging--1.0"]).isSubset(of: Set(documents.map(\.id))))
    XCTAssertFalse(documents.map(\.id).contains("healthData--0.9"))
    XCTAssertEqual(ConsentFlowRules.missingCoreTypes(in: ConsentFlowRules.latestPublished(documents)), [])
  }

  // MARK: Helpers

  /// Every value until the stream ends; fails after `seconds`.
  private static func collect<T: Sendable>(_ stream: AsyncStream<T>, timeout seconds: Double = 20) async throws -> [T] {
    try await withThrowingTaskGroup(of: [T].self) { group in
      group.addTask {
        var values: [T] = []
        for await value in stream { values.append(value) }
        return values
      }
      group.addTask {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        throw NSError(domain: "IntegrationTimeout", code: 1)
      }
      let values = try await group.next() ?? []
      group.cancelAll()
      return values
    }
  }

  /// The first value that satisfies `condition`, or nil after `seconds`.
  private static func first<T: Sendable>(
    _ stream: AsyncStream<T>, timeout seconds: Double = 20, where condition: @escaping @Sendable (T) -> Bool
  ) async throws -> T? {
    try await withThrowingTaskGroup(of: T?.self) { group in
      group.addTask {
        for await value in stream where condition(value) { return value }
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
}
