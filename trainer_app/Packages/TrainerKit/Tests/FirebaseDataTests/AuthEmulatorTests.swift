import FirebaseAuth
import FirebaseCore
import Foundation
import TrainerDomain
import XCTest
@testable import FirebaseData

/// TC-DF012-02, TC-DF012-03 against the Auth emulator (project `demo-dfet`). Runs only when the test process
/// gets `DFET_AUTH_EMULATOR=1` (xcodebuild: `TEST_RUNNER_DFET_AUTH_EMULATOR=1`), otherwise skips, so CI without
/// an emulator stays green. Local run: `trainer_app/scripts/test_auth_emulator.sh`. CI automation is DF-107.
///
/// Each test creates its own `@example.invalid` account through the emulator REST API, so the DF-042 seed is not
/// needed and seeded accounts are never changed.
final class AuthEmulatorTests: XCTestCase {
  private static let host = "127.0.0.1"
  private var service: FirebaseAuthService!

  override func setUpWithError() throws {
    guard ProcessInfo.processInfo.environment["DFET_AUTH_EMULATOR"] == "1" else {
      throw XCTSkip("set DFET_AUTH_EMULATOR=1 and start the Auth emulator (demo-dfet) to run")
    }
    if FirebaseApp.app() == nil {
      FirebaseBootstrap.configure(.emulator(host: Self.host))
    }
    try? Auth.auth().signOut()
    service = FirebaseAuthService()
  }

  override func tearDownWithError() throws {
    // tearDown also runs after the XCTSkip in setUp; Auth.auth() without a configured app is a fatal error.
    guard FirebaseApp.app() != nil else { return }
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
  private var values: [TrainerSession?] = []
  private var task: Task<Void, Never>?

  init(_ stream: AsyncStream<TrainerSession?>) {
    task = Task { [weak self] in
      for await value in stream {
        self?.lock.withLock { self?.values.append(value) }
      }
    }
  }

  func stop() {
    task?.cancel()
  }

  /// Polls for up to 10 s.
  func wait(
    file: StaticString = #filePath, line: UInt = #line, _ condition: ([TrainerSession?]) -> Bool
  ) async {
    for _ in 0..<200 {
      if lock.withLock({ condition(values) }) { return }
      try? await Task.sleep(nanoseconds: 50_000_000)
    }
    XCTFail("stream never reached the expected state: \(lock.withLock { values.map { $0?.uid ?? "nil" } })",
            file: file, line: line)
  }
}

/// Auth emulator REST calls (`Bearer owner` is the emulator's admin credential; it has no meaning in production).
private enum EmulatorAccounts {
  struct Account {
    let uid: String
    let email: String
    let password: String
  }

  private static let base =
    "http://127.0.0.1:\(FirebaseBootstrap.EmulatorPort.auth)/identitytoolkit.googleapis.com/v1/projects/\(FirebaseBootstrap.emulatorProjectID)"

  static func create(claims: [String: Any]) async throws -> Account {
    let email = "df012-\(UUID().uuidString.lowercased())@example.invalid"
    let password = "emulator-only-password"
    let created = try await post("accounts", ["email": email, "password": password])
    let uid = try XCTUnwrap(created["localId"] as? String)
    try await setClaims(claims, uid: uid)
    return Account(uid: uid, email: email, password: password)
  }

  static func setClaims(_ claims: [String: Any], uid: String) async throws {
    let json = String(decoding: try JSONSerialization.data(withJSONObject: claims), as: UTF8.self)
    _ = try await post("accounts:update", ["localId": uid, "customAttributes": json])
  }

  private static func post(_ path: String, _ body: [String: Any]) async throws -> [String: Any] {
    var request = URLRequest(url: try XCTUnwrap(URL(string: "\(base)/\(path)")))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer owner", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    let (data, response) = try await URLSession.shared.data(for: request)
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard status == 200 else {
      throw NSError(domain: "AuthEmulator", code: status, userInfo: [NSLocalizedDescriptionKey: "\(path) → \(status)"])
    }
    return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
  }
}
