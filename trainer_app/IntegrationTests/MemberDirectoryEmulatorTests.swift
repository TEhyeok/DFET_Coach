import FirebaseAuth
import Foundation
import TrainerDomain
import XCTest
@testable import DFETTrainer

/// TC-DF013-05 (AC-DF-013.1-.3) against the Auth and Firestore emulators with the repository's firestore.rules:
/// a signed-in trainer loads its assigned members through the `trainers/{uid}` listener and chunked `users` reads.
/// Runs only with `DFET_AUTH_EMULATOR=1` and `DFET_FIRESTORE_EMULATOR=1` (trainer_app/scripts/test_auth_emulator.sh).
/// Every run creates its own synthetic trainer and members, so the DF-042 seed is never changed.
final class MemberDirectoryEmulatorTests: XCTestCase {
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

  /// 23 assigned members arrive in one emission, in `memberIds` order (three `in` chunks: 10, 10, 3).
  func testSignedInTrainerSeesItsTwentyThreeMembers_TC_DF013_05() async throws {
    let trainer = try await EmulatorAccounts.create(claims: ["trainer": true])
    let memberIds = try await seedMembers(count: 23, trainerUid: trainer.uid)
    _ = try await AppBootstrap.liveAuthService().signIn(email: trainer.email, password: trainer.password)

    let directory = AppBootstrap.liveMemberDirectory(trainerUid: trainer.uid)
    let members = try await firstValue(of: directory.observeAssignedMembers())
    XCTAssertEqual(members?.map(\.id), memberIds)
    XCTAssertTrue(members?.allSatisfy { $0.trainerId == trainer.uid } ?? false)
  }

  /// A trainer without a `trainers/{uid}` document has no members: an empty list, not an error.
  func testTrainerWithoutAssignmentsGetsAnEmptyList() async throws {
    let trainer = try await EmulatorAccounts.create(claims: ["trainer": true])
    _ = try await AppBootstrap.liveAuthService().signIn(email: trainer.email, password: trainer.password)
    let members = try await firstValue(of: AppBootstrap.liveMemberDirectory(trainerUid: trainer.uid)
      .observeAssignedMembers())
    XCTAssertEqual(members, [])
  }

  /// Without the trainer claim the `users` read is denied by the rules: the stream fails with permissionDenied and
  /// emits no partial list (AC-DF-013.2 against real rules).
  func testWithoutTheTrainerClaimTheListFailsInsteadOfBeingPartial() async throws {
    let account = try await EmulatorAccounts.create(claims: [:])
    _ = try await seedMembers(count: 3, trainerUid: account.uid)
    _ = try await Auth.auth().signIn(withEmail: account.email, password: account.password)  // bypasses the app's claim check
    do {
      let members = try await firstValue(of: AppBootstrap.liveMemberDirectory(trainerUid: account.uid)
        .observeAssignedMembers())
      XCTFail("expected permissionDenied, got \(members?.count ?? -1) members")
    } catch {
      XCTAssertEqual(error as? MemberDirectoryError, .permissionDenied)
    }
  }

  private func seedMembers(count: Int, trainerUid: String) async throws -> [String] {
    let prefix = "it-\(trainerUid.prefix(8))"
    let ids = (1...count).map { String(format: "\(prefix)-m%02d", $0) }
    for id in ids {
      try await EmulatorDocuments.put("users/\(id)", [
        "displayName": "가상 회원 \(id.suffix(3))", "trainerId": trainerUid, "role": "member",
      ])
    }
    try await EmulatorDocuments.put("trainers/\(trainerUid)", [
      "trainerId": trainerUid, "memberIds": ids, "approvalStatus": "approved",
    ])
    return ids
  }
}
