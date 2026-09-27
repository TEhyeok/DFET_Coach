import FirebaseAuth
import FirebaseData
import Foundation
import TrainerDomain
import XCTest
@testable import DFETTrainer

/// DF-018 TC-DF018-03 (AC-DF-018.1, V1-04 §12.2): TR-15 logout through the live services signs Firebase Auth out and
/// leaves no Firestore listener, and the next sign-in works on the fresh Firestore instance with the emulator
/// settings applied again. Synthetic data only; every run uses its own trainer.
final class SessionSignOutEmulatorTests: XCTestCase {
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
  func testLogoutSignsOutAndRemovesEveryListener_TC_DF018_03() async throws {
    let trainer = try await EmulatorAccounts.create(claims: ["trainer": true])
    try await EmulatorDocuments.put("trainers/\(trainer.uid)", [
      "trainerId": trainer.uid, "memberIds": [String](), "approvalStatus": "approved",
    ])
    let session = try await AppBootstrap.liveAuthService().signIn(email: trainer.email, password: trainer.password)
    let services = AppBootstrap.liveServices(session: session)

    // TR-02's subscription stays open while the trainer logs out.
    let members = services.memberDirectory.observeAssignedMembers()
    let subscriber = Task { for try await _ in members {} }
    defer { subscriber.cancel() }
    for _ in 0..<100 where FirestoreListenerRegistry.shared.count == 0 {
      try await Task.sleep(nanoseconds: 50_000_000)
    }
    XCTAssertGreaterThan(FirestoreListenerRegistry.shared.count, 0, "the member list listener never registered")

    try await services.signOut.signOut()
    XCTAssertNil(Auth.auth().currentUser)
    XCTAssertEqual(FirestoreListenerRegistry.shared.count, 0)

    // The same trainer signs in again: a fresh Firestore instance talks to the emulator.
    _ = try await AppBootstrap.liveAuthService().signIn(email: trainer.email, password: trainer.password)
    let again = try await firstValue(of: AppBootstrap.liveMemberDirectory(trainerUid: trainer.uid).observeAssignedMembers())
    XCTAssertEqual(again, [])
  }

  /// Cross-review: when Auth fails to sign out, the trainer stays signed in on a torn-down Firestore. TR-02's stream
  /// ends with its removed listener (`.unavailable`, so the list offers '다시 시도') instead of waiting forever, and
  /// subscribing again works on the fresh instance.
  @MainActor
  func testAFailedLogoutEndsTheMemberStreamAndItSubscribesAgain() async throws {
    let trainer = try await EmulatorAccounts.create(claims: ["trainer": true])
    try await EmulatorDocuments.put("trainers/\(trainer.uid)", [
      "trainerId": trainer.uid, "memberIds": [String](), "approvalStatus": "approved",
    ])
    _ = try await AppBootstrap.liveAuthService().signIn(email: trainer.email, password: trainer.password)
    let members = AppBootstrap.liveMemberDirectory(trainerUid: trainer.uid).observeAssignedMembers()
    let ended = Ending()
    let subscriber = Task {
      do {
        for try await _ in members {}
        ended.set(nil)
      } catch {
        ended.set(error as? MemberDirectoryError)
      }
    }
    defer { subscriber.cancel() }
    for _ in 0..<100 where FirestoreListenerRegistry.shared.count == 0 {
      try await Task.sleep(nanoseconds: 50_000_000)
    }
    XCTAssertGreaterThan(FirestoreListenerRegistry.shared.count, 0, "the member list listener never registered")

    let signOut = LiveSessionSignOut(
      trainerUid: trainer.uid, signOutAuth: { throw AuthError.unknown(code: 1) },
      teardownRemote: { try await FirestoreSessionTeardown.run() })
    do {
      try await signOut.signOut()
      XCTFail("expected the sign-out error")
    } catch {}
    XCTAssertEqual(Auth.auth().currentUser?.uid, trainer.uid, "still signed in")
    for _ in 0..<100 where !ended.isSet {
      try await Task.sleep(nanoseconds: 50_000_000)
    }
    XCTAssertEqual(ended.error, .unavailable, "the stream ended instead of waiting on a removed listener")

    let again = try await firstValue(of: AppBootstrap.liveMemberDirectory(trainerUid: trainer.uid).observeAssignedMembers())
    XCTAssertEqual(again, [])
  }
}

/// How a stream ended: set once, with its error (nil when it finished).
private final class Ending: @unchecked Sendable {
  private let lock = NSLock()
  private var ended = false
  private var _error: MemberDirectoryError?
  var isSet: Bool { lock.withLock { ended } }
  var error: MemberDirectoryError? { lock.withLock { _error } }
  func set(_ error: MemberDirectoryError?) {
    lock.withLock {
      ended = true
      _error = error
    }
  }
}
