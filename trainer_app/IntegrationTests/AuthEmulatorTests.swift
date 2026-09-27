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
  /// The hosted app starts in `--preview-unit-test-host` mode and never configures Firebase; this does, once.
  private static let configureEmulator: Void = {
    AppBootstrap.firebase(bundle: .main).configureLive(.emulator(host: "127.0.0.1"))
  }()

  private var configured = false
  private var service: (any AuthService)!

  override func setUpWithError() throws {
    guard ProcessInfo.processInfo.environment["DFET_AUTH_EMULATOR"] == "1" else {
      throw XCTSkip("set DFET_AUTH_EMULATOR=1 and start the Auth emulator (demo-dfet) to run")
    }
    Self.configureEmulator
    configured = true
    // Never run against anything but the emulator project.
    guard Auth.auth().app?.options.projectID == "demo-dfet" else {
      XCTFail("Firebase is not the demo-dfet emulator app")
      throw XCTSkip("refusing to run outside the emulator")
    }
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

/// Auth emulator REST calls (`Bearer owner` is the emulator's admin credential; it has no meaning in production).
private enum EmulatorAccounts {
  struct Account {
    let uid: String
    let email: String
    let password: String
  }

  /// Auth emulator port 19099 and project `demo-dfet` (FirebaseBootstrap.EmulatorPort.auth, firebase.json).
  private static let base = "http://127.0.0.1:19099/identitytoolkit.googleapis.com/v1/projects/demo-dfet"

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
