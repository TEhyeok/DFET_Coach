import FirebaseAuth
import Foundation
import TrainerDomain
import XCTest
@testable import DFETTrainer

/// DF-108 TC-108-04 (AC-DF-108.3): a TR-14 registration saved on the device reaches the Firestore emulator through the
/// live session runtime (LocalStore Outbox + SyncEngine + FirebaseData) and the repository rules accept it.
/// Synthetic data only; every run uses its own trainer and LocalStore partition.
final class PendingMemberEmulatorTests: XCTestCase {
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
  func testARegistrationIsCreatedOnTheServer_TC_108_04() async throws {
    let trainer = try await EmulatorAccounts.create(claims: ["trainer": true])
    try await EmulatorDocuments.put("trainers/\(trainer.uid)", [
      "trainerId": trainer.uid, "memberIds": [String](), "approvalStatus": "approved",
    ])
    let session = try await AppBootstrap.liveAuthService().signIn(email: trainer.email, password: trainer.password)

    let services = AppBootstrap.liveServices(session: session)
    let draft = PendingMemberDraft(displayName: "가상 대기 회원", sex: .unspecified, birthYear: 1990, ageConfirmed14: true)
    let id = try await services.registrar.register(draft)
    XCTAssertTrue(DocumentID.isValid(id))

    var fields: [String: Any]?
    for _ in 0..<150 where fields == nil {
      fields = try await EmulatorDocuments.get("pendingMembers/\(id)")
      if fields == nil { try await Task.sleep(nanoseconds: 100_000_000) }
    }
    let stored = try XCTUnwrap(fields, "the Outbox did not create pendingMembers/\(id)")
    XCTAssertEqual(Set(stored.keys), PendingMemberPayload.documentKeys)
    XCTAssertEqual((stored["trainerId"] as? [String: Any])?["stringValue"] as? String, trainer.uid)
    XCTAssertEqual((stored["status"] as? [String: Any])?["stringValue"] as? String, "pending")
    XCTAssertEqual((stored["ageConfirmed14"] as? [String: Any])?["booleanValue"] as? Bool, true)
    XCTAssertEqual((stored["schemaVersion"] as? [String: Any])?["integerValue"] as? String, "1")
    XCTAssertEqual((stored["birthYear"] as? [String: Any])?["integerValue"] as? String, "1990")
  }

  /// Review H1: a registration made while signed out is not sent under no session and never fails for good; it goes
  /// out once the same trainer signs in again.
  @MainActor
  func testARegistrationWhileSignedOutIsSentAfterTheSameTrainerSignsIn() async throws {
    let trainer = try await EmulatorAccounts.create(claims: ["trainer": true])
    try await EmulatorDocuments.put("trainers/\(trainer.uid)", [
      "trainerId": trainer.uid, "memberIds": [String](), "approvalStatus": "approved",
    ])
    let session = try await AppBootstrap.liveAuthService().signIn(email: trainer.email, password: trainer.password)
    let services = AppBootstrap.liveServices(session: session)
    try Auth.auth().signOut()

    let draft = PendingMemberDraft(displayName: "가상 대기 회원", sex: .female, birthYear: 1991, ageConfirmed14: true)
    let id = try await services.registrar.register(draft)
    try await Task.sleep(nanoseconds: 1_500_000_000)
    let whileSignedOut = try await EmulatorDocuments.get("pendingMembers/\(id)")
    XCTAssertNil(whileSignedOut, "nothing is sent without the trainer's session")

    _ = try await AppBootstrap.liveAuthService().signIn(email: trainer.email, password: trainer.password)
    var fields: [String: Any]?
    for _ in 0..<150 where fields == nil {
      fields = try await EmulatorDocuments.get("pendingMembers/\(id)")
      if fields == nil { try await Task.sleep(nanoseconds: 100_000_000) }
    }
    XCTAssertNotNil(fields, "the item waited for the session instead of failing for good")
  }
}
