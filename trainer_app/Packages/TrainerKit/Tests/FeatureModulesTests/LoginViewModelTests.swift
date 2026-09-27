import Foundation
import TrainerDomain
import XCTest
@testable import FeatureAuth

/// TC-DF012-01: login and gate state transitions against a scripted `AuthService` (AC-DF-012.1-.3, .5).
@MainActor
final class LoginViewModelTests: XCTestCase {
  private let session = TrainerSession(uid: "syn-trainer", displayName: "SYN-TRAINER")

  func testSubmitGoesIdleSigningInFailedNotTrainer() async {
    let auth = FakeAuthService(result: .failure(.notTrainer))
    let model = LoginViewModel(auth: auth)
    model.email = "  member@example.invalid "
    model.password = "pw"
    XCTAssertEqual(model.phase, .idle)
    XCTAssertTrue(model.canSubmit)

    auth.onSignIn = { @Sendable in await MainActor.run { auth.phasesSeen.append(model.phase) } }
    await model.submit()

    XCTAssertEqual(auth.phasesSeen, [.signingIn])
    XCTAssertEqual(model.phase, .failed(.notTrainer))
    XCTAssertEqual(model.errorKey, "auth.error.notTrainer")
    XCTAssertEqual(auth.signInEmails, ["member@example.invalid"], "email is trimmed")
    XCTAssertEqual(model.password, "pw", "a failed attempt keeps the password for a retry")
  }

  func testSubmitSuccessClearsPasswordAndError() async {
    let auth = FakeAuthService(result: .failure(.invalidCredentials))
    let model = LoginViewModel(auth: auth)
    model.email = "trainer@example.invalid"
    model.password = "wrong"
    await model.submit()
    XCTAssertEqual(model.errorKey, "auth.error.invalidCredentials")

    auth.result = .success(session)
    model.password = "right"
    await model.submit()
    XCTAssertEqual(model.phase, .idle)
    XCTAssertNil(model.errorKey)
    XCTAssertEqual(model.password, "")
  }

  func testErrorKeysForNetworkAndUnknown() async {
    let auth = FakeAuthService(result: .failure(.network))
    let model = LoginViewModel(auth: auth)
    model.email = "a@example.invalid"
    model.password = "pw"
    await model.submit()
    XCTAssertEqual(model.errorKey, "auth.error.network")

    auth.result = .failure(.unknown(code: 17999))
    await model.submit()
    XCTAssertEqual(model.errorKey, "auth.error.unknown")
  }

  func testCannotSubmitWithoutEmailOrPassword() async {
    let auth = FakeAuthService(result: .success(session))
    let model = LoginViewModel(auth: auth)
    XCTAssertFalse(model.canSubmit)
    model.email = "   "
    model.password = "pw"
    XCTAssertFalse(model.canSubmit)
    model.email = "trainer@example.invalid"
    model.password = ""
    XCTAssertFalse(model.canSubmit)
    await model.submit()
    XCTAssertTrue(auth.signInEmails.isEmpty)
  }

  // MARK: AuthGateModel

  func testGateFollowsStreamAndLocksWhenClaimIsRevoked() async {
    let auth = FakeAuthService(result: .success(session))
    let gate = AuthGateModel(auth: auth)
    XCTAssertEqual(gate.state, .checking)

    let observing = Task { await gate.observe() }
    defer { observing.cancel() }

    auth.emit(nil)
    await waitFor { gate.state == .signedOut(lock: nil) }
    auth.emit(session)
    await waitFor { gate.state == .signedIn(self.session) }
    // Claim removed while signed in: the service signs out and the stream emits nil (AC-DF-012.3).
    auth.emit(nil)
    await waitFor { gate.state == .signedOut(lock: .claimRevoked) }
  }

  func testUserSignOutDoesNotShowLockNotice() async throws {
    let auth = FakeAuthService(result: .success(session))
    let gate = AuthGateModel(auth: auth)
    gate.apply(session)
    auth.onSignOut = { gate.apply(nil) }
    try await gate.signOut()
    XCTAssertEqual(gate.state, .signedOut(lock: nil))
    XCTAssertEqual(auth.signOutCalls, 1)
  }

  func testLockNoticeStaysUntilNextSignIn() {
    let gate = AuthGateModel(auth: FakeAuthService(result: .success(session)))
    gate.apply(session)
    gate.apply(nil)
    XCTAssertEqual(gate.state, .signedOut(lock: .claimRevoked))
    gate.apply(nil)  // e.g. a later listener callback
    XCTAssertEqual(gate.state, .signedOut(lock: .claimRevoked))
    gate.apply(session)
    XCTAssertEqual(gate.state, .signedIn(session))
  }

  func testSignOutWhileSignedOutDoesNotHideALaterLock() async throws {
    let gate = AuthGateModel(auth: FakeAuthService(result: .success(session)))
    gate.apply(nil)
    try await gate.signOut()  // no session: no nil follows, so no flag may be left behind
    gate.apply(session)
    gate.apply(nil)
    XCTAssertEqual(gate.state, .signedOut(lock: .claimRevoked))
  }

  func testFirstNilIsPlainSignedOut() {
    let gate = AuthGateModel(auth: FakeAuthService(result: .success(session)))
    gate.apply(nil)
    XCTAssertEqual(gate.state, .signedOut(lock: nil))
  }

  func testRefreshClaimsForwardsToService() async {
    let auth = FakeAuthService(result: .success(session))
    await AuthGateModel(auth: auth).refreshClaims()
    XCTAssertEqual(auth.refreshCalls, 1)
  }

  private func waitFor(_ condition: @escaping @MainActor () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
    for _ in 0..<200 where !condition() {
      try? await Task.sleep(nanoseconds: 25_000_000)
    }
    XCTAssertTrue(condition(), "condition not reached", file: file, line: line)
  }
}

/// Scripted `AuthService`. Test-only; the app's DEBUG preview has its own (`PreviewAuthService`).
final class FakeAuthService: AuthService, @unchecked Sendable {
  var result: Result<TrainerSession, AuthError>
  var onSignIn: (@Sendable () async -> Void)?
  var onSignOut: (@MainActor () -> Void)?
  var phasesSeen: [LoginViewModel.Phase] = []
  private(set) var signInEmails: [String] = []
  private(set) var signOutCalls = 0
  private(set) var refreshCalls = 0

  private let stream: AsyncStream<TrainerSession?>
  private let continuation: AsyncStream<TrainerSession?>.Continuation

  init(result: Result<TrainerSession, AuthError>) {
    self.result = result
    let pair = AsyncStream.makeStream(of: TrainerSession?.self)
    stream = pair.stream
    continuation = pair.continuation
  }

  func emit(_ session: TrainerSession?) {
    continuation.yield(session)
  }

  func signIn(email: String, password: String) async throws -> TrainerSession {
    signInEmails.append(email)
    await onSignIn?()
    return try result.get()
  }

  func signOut(discardUnsynced: Bool) async throws {
    signOutCalls += 1
    if let onSignOut { await onSignOut() }
  }

  func sessionStream() -> AsyncStream<TrainerSession?> {
    stream
  }

  func refreshClaims() async {
    refreshCalls += 1
  }
}
