import FirebaseAuth
import Foundation
import TrainerDomain
import XCTest
@testable import DFETTrainer

/// DF-108 TC-108-04 (AC-DF-108.3): a TR-14 registration saved on the device reaches the Firestore emulator through the
/// live session runtime (LocalStore Outbox + SyncEngine + FirebaseData) and the repository rules accept it. DF-113: the
/// TR-02 pending-member query against the same rules.
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

  /// AC-DF-113.6 / AC-DF-110.5 against the rules: a registration cancelled on the device reaches the server after its
  /// create as `status: 'cancelled'` (server-time `updatedAt`, no client `cancelledAt`), and TR-02's query no longer
  /// lists it; the device stops hiding it once the cancel is acked.
  @MainActor
  func testACancelledRegistrationIsCancelledOnTheServer_AC_DF_113_6() async throws {
    let trainer = try await EmulatorAccounts.create(claims: ["trainer": true])
    try await EmulatorDocuments.put("trainers/\(trainer.uid)", [
      "trainerId": trainer.uid, "memberIds": [String](), "approvalStatus": "approved",
    ])
    let session = try await AppBootstrap.liveAuthService().signIn(email: trainer.email, password: trainer.password)
    let services = AppBootstrap.liveServices(session: session)
    let draft = PendingMemberDraft(displayName: "가상 취소 회원", sex: .unspecified, birthYear: 1990, ageConfirmed14: true)
    let id = try await services.registrar.register(draft)
    try await services.canceller.cancel(pendingMemberId: id)

    var stored: [String: Any]?
    func status() -> String? { (stored?["status"] as? [String: Any])?["stringValue"] as? String }
    for _ in 0..<150 where status() != "cancelled" {
      stored = try await EmulatorDocuments.get("pendingMembers/\(id)")
      if status() != "cancelled" { try await Task.sleep(nanoseconds: 100_000_000) }
    }
    XCTAssertEqual(status(), "cancelled", "the Outbox did not cancel pendingMembers/\(id)")
    XCTAssertEqual(Set(stored?.keys.map { $0 } ?? []), PendingMemberPayload.documentKeys, "no cancelledAt")

    let members = try await firstValue(of: AppBootstrap.liveMemberDirectory(trainerUid: trainer.uid).observePendingMembers())
    XCTAssertEqual(members?.contains { $0.id == id }, false)
    var device = DevicePendingMembers(cancelled: [id])
    for _ in 0..<100 where !device.cancelled.isEmpty {
      for await value in services.localPendingMembers.observeLocalPendingMembers() {
        device = value
        break
      }
      if !device.cancelled.isEmpty { try await Task.sleep(nanoseconds: 100_000_000) }
    }
    XCTAssertEqual(device, DevicePendingMembers(), "acked: the device neither lists nor hides the member")
  }

  /// DF-113 (AC-DF-113.1, F-LINK-03.2) against the rules: TR-02's query lists this trainer's pending members only. A
  /// cancelled one and another trainer's pending member are not listed; the rules allow the query (R-05).
  func testTheListHasOnlyThisTrainersPendingMembers_DF_113() async throws {
    let trainer = try await EmulatorAccounts.create(claims: ["trainer": true])
    let other = try await EmulatorAccounts.create(claims: ["trainer": true])
    let (listed, cancelled, othersPending) = (DocumentID.make(), DocumentID.make(), DocumentID.make())
    try await EmulatorDocuments.put("pendingMembers/\(listed)", pendingDocument(trainer.uid, "가상 대기 회원", "pending"))
    try await EmulatorDocuments.put("pendingMembers/\(cancelled)", pendingDocument(trainer.uid, "가상 취소 회원", "cancelled"))
    try await EmulatorDocuments.put("pendingMembers/\(othersPending)", pendingDocument(other.uid, "가상 남의 회원", "pending"))
    _ = try await AppBootstrap.liveAuthService().signIn(email: trainer.email, password: trainer.password)

    let members = try await firstValue(of: AppBootstrap.liveMemberDirectory(trainerUid: trainer.uid).observePendingMembers())
    XCTAssertEqual(members, [PendingMember(id: listed, displayName: "가상 대기 회원")])
  }

  private func pendingDocument(_ trainerUid: String, _ name: String, _ status: String) -> [String: Any] {
    [
      "trainerId": trainerUid, "displayName": name, "sex": "unspecified", "birthYear": 1990, "ageConfirmed14": true,
      "status": status, "schemaVersion": 1, "createdAt": Date(), "updatedAt": Date(),
    ]
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
