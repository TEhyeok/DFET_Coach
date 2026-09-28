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

  /// The consent/body-composition workflow's three listeners (pending members, body-composition records, consent
  /// state) end with a failed logout too. Pending members and records end with `.unavailable`, so TR-02 and
  /// TR-03/TR-11 offer '다시 시도'. The consent state gives nil and ends: a kept screen never keeps a grant nobody
  /// reads any more.
  @MainActor
  func testAFailedLogoutEndsTheWorkflowStreams() async throws {
    let trainer = try await EmulatorAccounts.create(claims: ["trainer": true])
    try await EmulatorDocuments.put("trainers/\(trainer.uid)", [
      "trainerId": trainer.uid, "memberIds": [String](), "approvalStatus": "approved",
    ])
    let pendingID = DocumentID.make()
    try await EmulatorDocuments.put("pendingMembers/\(pendingID)", [
      "trainerId": trainer.uid, "displayName": "합성 로그아웃 회원", "sex": "unspecified", "birthYear": 1990,
      "ageConfirmed14": true, "status": "pending", "schemaVersion": 1,
    ])
    try await EmulatorDocuments.put("memberConsentStates/\(pendingID)", [
      "required": ["granted": true, "documentVersion": "synthetic-required-v1"],
    ])
    _ = try await AppBootstrap.liveAuthService().signIn(email: trainer.email, password: trainer.password)
    let member = MemberKey.pending(pendingID)

    let members = Observed<[Member]>()
    let records = Observed<[BodyCompositionRecord]>()
    let consent = Observed<ConsentState?>()
    let tasks = [
      observe(FirestorePendingMemberDirectory(trainerUid: trainer.uid).observeAssignedMembers(), into: members),
      observe(FirestoreMeasurementRecordsSource(trainerUid: trainer.uid).records(member: member, since: .distantPast),
              into: records),
      observe(FirestoreConsentService().observeState(member: member), into: consent),
    ]
    defer { tasks.forEach { $0.cancel() } }
    try await waitUntil(members.values.last?.contains { $0.id == pendingID } == true,
                        "the pending member never arrived")
    try await waitUntil(!records.values.isEmpty, "the records listener never answered")
    try await waitUntil(consent.values.last??.isGranted(.required) == true, "the consent grant never arrived")
    XCTAssertFalse(members.isEnded || records.isEnded || consent.isEnded)
    let seen = consent.values.count

    let signOut = LiveSessionSignOut(
      trainerUid: trainer.uid, signOutAuth: { throw AuthError.unknown(code: 1) },
      teardownRemote: { try await FirestoreSessionTeardown.run() })
    do {
      try await signOut.signOut()
      XCTFail("expected the sign-out error")
    } catch {}
    XCTAssertEqual(Auth.auth().currentUser?.uid, trainer.uid, "still signed in")
    try await waitUntil(members.isEnded && records.isEnded && consent.isEnded,
                        "a workflow stream kept waiting on a removed listener")
    XCTAssertEqual(members.error as? MemberDirectoryError, .unavailable)
    XCTAssertEqual(records.error as? MemberDirectoryError, .unavailable)
    XCTAssertGreaterThan(consent.values.count, seen, "the consent stream ends with a last value")
    XCTAssertEqual(consent.values.last, .some(nil), "a lost read drops the last grant")
    XCTAssertEqual(FirestoreListenerRegistry.shared.count, 0)
  }

  private func observe<T: Sendable>(_ stream: AsyncThrowingStream<T, Error>,
                                    into observed: Observed<T>) -> Task<Void, Never> {
    Task {
      do {
        for try await value in stream { observed.append(value) }
        observed.end(nil)
      } catch {
        observed.end(error)
      }
    }
  }

  private func observe<T: Sendable>(_ stream: AsyncStream<T>, into observed: Observed<T>) -> Task<Void, Never> {
    Task {
      for await value in stream { observed.append(value) }
      observed.end(nil)
    }
  }

  private func waitUntil(_ condition: @autoclosure () -> Bool, _ message: String) async throws {
    for _ in 0..<200 where !condition() {
      try await Task.sleep(nanoseconds: 50_000_000)
    }
    XCTAssertTrue(condition(), message)
  }
}

/// A stream's values and how it ended (error nil when it finished).
private final class Observed<Value: Sendable>: @unchecked Sendable {
  private let lock = NSLock()
  private var _values: [Value] = []
  private var _ended = false
  private var _error: Error?
  var values: [Value] { lock.withLock { _values } }
  var isEnded: Bool { lock.withLock { _ended } }
  var error: Error? { lock.withLock { _error } }
  func append(_ value: Value) { lock.withLock { _values.append(value) } }
  func end(_ error: Error?) {
    lock.withLock {
      _ended = true
      _error = error
    }
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
