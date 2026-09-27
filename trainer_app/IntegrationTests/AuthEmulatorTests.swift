import FirebaseAuth
import Foundation
import TrainerDomain
import XCTest
@testable import DFETTrainer

/// TC-DF012-02, TC-DF012-03 against the Auth emulator (project `demo-dfet`), hosted in the app so Firebase Auth has
/// the app's keychain (a host-less bundle fails with keychain error 17995). Firebase is the app's own copy: this
/// bundle configures it through `AppBootstrap` and links no Firebase product (one Firebase instance per process).
///
/// Runs only when the test process gets `DFET_AUTH_EMULATOR=1` (xcodebuild environment
/// `TEST_RUNNER_DFET_AUTH_EMULATOR=1`), otherwise skips. Local run: `trainer_app/scripts/test_auth_emulator.sh`.
/// CI automation is DF-107. Each test creates its own `@example.invalid` account through the emulator REST API, so the
/// DF-042 seed is not needed and seeded accounts are never changed.
final class AuthEmulatorTests: XCTestCase {
  private var configured = false
  private var service: (any AuthService)!

  override func setUpWithError() throws {
    try IntegrationEmulator.require("DFET_AUTH_EMULATOR")
    try IntegrationEmulator.configure()
    configured = true
    try? Auth.auth().signOut()
    service = AppBootstrap.liveAuthService()
  }

  override func tearDownWithError() throws {
    // tearDown also runs after the XCTSkip in setUp; Auth.auth() without a configured app is a fatal error.
    guard configured else { return }
    try? Auth.auth().signOut()
  }

  /// TC-DF012-02 (AC-DF-012.1): a trainer-claim account signs in and the stream emits its session.
  func testTrainerAccountSignsIn() async throws {
    let account = try await EmulatorAccounts.create(claims: ["trainer": true])
    let session = try await service.signIn(email: account.email, password: account.password)
    XCTAssertEqual(session.uid, account.uid)
    let recorder = SessionRecorder(service.sessionStream())
    defer { recorder.stop() }
    await recorder.wait { $0.last??.uid == account.uid }
  }

  /// TC-DF012-02 (AC-DF-012.2): an account without a boolean `true` claim is rejected and signed out.
  func testAccountWithoutClaimIsSignedOut() async throws {
    let recorder = SessionRecorder(service.sessionStream())
    defer { recorder.stop() }
    for claims in [[:], ["trainer": "true"], ["trainer": 1, "admin": true]] as [[String: Any]] {
      let account = try await EmulatorAccounts.create(claims: claims)
      do {
        _ = try await service.signIn(email: account.email, password: account.password)
        XCTFail("signed in without a boolean trainer claim: \(claims)")
      } catch let error as AuthError {
        XCTAssertEqual(error, .notTrainer)
      }
      XCTAssertNil(Auth.auth().currentUser)
    }
    // The stream never reported a session for these accounts (AC-DF-012.2).
    await recorder.wait { $0.count >= 1 }
    XCTAssertTrue(recorder.values.allSatisfy { $0 == nil }, "stream: \(recorder.values.map { $0?.uid ?? "nil" })")
  }

  /// AC-DF-012.4: a wrong password maps to `.invalidCredentials`.
  func testWrongPasswordIsInvalidCredentials() async throws {
    let account = try await EmulatorAccounts.create(claims: ["trainer": true])
    do {
      _ = try await service.signIn(email: account.email, password: "not-the-password")
      XCTFail("signed in with a wrong password")
    } catch let error as AuthError {
      XCTAssertEqual(error, .invalidCredentials)
    }
  }

  /// TC-DF012-03 (AC-DF-012.3): removing the claim, then `refreshClaims()`, signs out and the stream emits nil.
  func testClaimRemovalSignsOutOnRefresh() async throws {
    let account = try await EmulatorAccounts.create(claims: ["trainer": true])
    _ = try await service.signIn(email: account.email, password: account.password)
    let recorder = SessionRecorder(service.sessionStream())
    defer { recorder.stop() }
    await recorder.wait { $0.last??.uid == account.uid }

    try await EmulatorAccounts.setClaims([:], uid: account.uid)
    await service.refreshClaims()

    await recorder.wait { values in values.last.map { $0 == nil } ?? false }
    XCTAssertNil(Auth.auth().currentUser)
  }
}

/// Records every value of a session stream on a background task.
private final class SessionRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var _values: [TrainerSession?] = []
  private var task: Task<Void, Never>?

  init(_ stream: AsyncStream<TrainerSession?>) {
    task = Task { [weak self] in
      for await value in stream {
        self?.lock.withLock { self?._values.append(value) }
      }
    }
  }

  var values: [TrainerSession?] {
    lock.withLock { _values }
  }

  func stop() {
    task?.cancel()
  }

  /// Polls for up to 10 s.
  func wait(
    file: StaticString = #filePath, line: UInt = #line, _ condition: ([TrainerSession?]) -> Bool
  ) async {
    for _ in 0..<200 {
      if lock.withLock({ condition(_values) }) { return }
      try? await Task.sleep(nanoseconds: 50_000_000)
    }
    XCTFail("stream never reached the expected state: \(lock.withLock { _values.map { $0?.uid ?? "nil" } })",
            file: file, line: line)
  }
}
