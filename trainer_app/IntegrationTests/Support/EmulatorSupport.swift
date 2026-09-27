import FirebaseAuth
import Foundation
import XCTest
@testable import DFETTrainer

/// Shared setup of the emulator-backed integration tests (project `demo-dfet`, ports from firebase.json).
///
/// The hosted app starts in `--preview-unit-test-host` mode and never configures Firebase. `configure()` does it once
/// per process through the app's own `AppBootstrap`, so this bundle uses the app's single Firebase copy and links no
/// Firebase product. It refuses to run against anything but the emulator project.
enum IntegrationEmulator {
  private static let configureOnce: Void = {
    AppBootstrap.firebase(bundle: .main).configureLive(.emulator(host: "127.0.0.1"))
  }()

  static func configure() throws {
    configureOnce
    guard Auth.auth().app?.options.projectID == "demo-dfet" else {
      XCTFail("Firebase is not the demo-dfet emulator app")
      throw XCTSkip("refusing to run outside the emulator")
    }
  }

  /// Skips unless every flag is `1` in the test process environment (xcodebuild: `TEST_RUNNER_<FLAG>=1`).
  static func require(_ flags: String...) throws {
    let environment = ProcessInfo.processInfo.environment
    for flag in flags where environment[flag] != "1" {
      throw XCTSkip("set \(flag)=1 and start the emulators (trainer_app/scripts/test_auth_emulator.sh)")
    }
  }
}

/// Auth emulator REST calls. `Bearer owner` is the emulator's admin credential; it has no meaning in production.
enum EmulatorAccounts {
  struct Account {
    let uid: String
    let email: String
    let password: String
  }

  /// Auth emulator port 19099 (FirebaseBootstrap.EmulatorPort.auth, firebase.json).
  private static let base = "http://127.0.0.1:19099/identitytoolkit.googleapis.com/v1/projects/demo-dfet"

  static func create(claims: [String: Any]) async throws -> Account {
    let email = "it-\(UUID().uuidString.lowercased())@example.invalid"
    let password = "emulator-only-password"
    let created = try await EmulatorREST.send("POST", "\(base)/accounts", ["email": email, "password": password])
    let uid = try XCTUnwrap(created["localId"] as? String)
    try await setClaims(claims, uid: uid)
    return Account(uid: uid, email: email, password: password)
  }

  static func setClaims(_ claims: [String: Any], uid: String) async throws {
    let json = String(decoding: try JSONSerialization.data(withJSONObject: claims), as: UTF8.self)
    _ = try await EmulatorREST.send("POST", "\(base)/accounts:update", ["localId": uid, "customAttributes": json])
  }
}

/// Firestore emulator REST writes as the owner, which bypasses security rules (test setup only).
enum EmulatorDocuments {
  /// Firestore emulator port 18080 (FirebaseBootstrap.EmulatorPort.firestore, firebase.json).
  private static let base = "http://127.0.0.1:18080/v1/projects/demo-dfet/databases/(default)/documents"

  /// Creates or replaces `path`. Fields may be strings, booleans, integers, doubles, dates, string lists and maps
  /// of these.
  static func put(_ path: String, _ fields: [String: Any]) async throws {
    _ = try await EmulatorREST.send("PATCH", "\(base)/\(path)", ["fields": try fields.mapValues(encode)])
  }

  /// Firestore REST value encoding.
  private static func encode(_ value: Any) throws -> [String: Any] {
    switch value {
    case let text as String: return ["stringValue": text]
    case let flag as Bool: return ["booleanValue": flag]
    case let number as Int: return ["integerValue": String(number)]
    case let number as Double: return ["doubleValue": number]
    case let date as Date: return ["timestampValue": ISO8601DateFormatter().string(from: date)]
    case let list as [String]: return ["arrayValue": ["values": list.map { ["stringValue": $0] }]]
    case let map as [String: Any]: return ["mapValue": ["fields": try map.mapValues(encode)]]
    default: throw NSError(domain: "EmulatorDocuments", code: 1, userInfo: [NSLocalizedDescriptionKey: "unsupported value"])
    }
  }
}

enum EmulatorREST {
  static func send(_ method: String, _ url: String, _ body: [String: Any]) async throws -> [String: Any] {
    var request = URLRequest(url: try XCTUnwrap(URL(string: url)))
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer owner", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    let (data, response) = try await URLSession.shared.data(for: request)
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard status == 200 else {
      throw NSError(domain: "EmulatorREST", code: status, userInfo: [NSLocalizedDescriptionKey: "\(method) → \(status)"])
    }
    return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
  }
}

/// The first value of a stream, or a failure after `seconds`.
func firstValue<T: Sendable>(
  of stream: AsyncThrowingStream<T, Error>, timeout seconds: Double = 15
) async throws -> T? {
  try await withThrowingTaskGroup(of: T?.self) { group in
    group.addTask {
      var iterator = stream.makeAsyncIterator()
      return try await iterator.next()
    }
    group.addTask {
      try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
      throw NSError(domain: "IntegrationTimeout", code: 1)
    }
    let first = try await group.next() ?? nil
    group.cancelAll()
    return first
  }
}
