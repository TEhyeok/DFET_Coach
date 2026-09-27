import Foundation
import LocalStore
import TrainerDomain
import XCTest
@testable import DFETTrainer

/// DF-018 TC-DF018-01 (V1-04 §12.2 ②-⑦, ASM-P0-17) without Firebase: the live logout tears Firestore down before it
/// signs out, purges only what the server has, keeps unsynced records, and retires the runtime; a failed sign-out
/// puts the runtime back. Fakes for Auth and Firestore; a synthetic trainer partition in the test host.
@MainActor
final class SessionSignOutOrderTests: XCTestCase {
  private let uid = "syn-signout-" + UUID().uuidString.prefix(8)

  private final class Steps: @unchecked Sendable {
    private let lock = NSLock()
    private var _all: [String] = []
    var all: [String] { lock.withLock { _all } }
    func add(_ step: String) { lock.withLock { _all.append(step) } }
  }

  private final class FakeAuth: AuthService, @unchecked Sendable {
    let steps: Steps
    let fails: Bool
    init(steps: Steps, fails: Bool) {
      self.steps = steps
      self.fails = fails
    }
    func signIn(email: String, password: String) async throws -> TrainerSession { throw AuthError.network }
    func signOut(discardUnsynced: Bool) async throws {
      XCTAssertFalse(discardUnsynced, "logout never discards unsynced records")
      steps.add("auth")
      if fails { throw AuthError.unknown(code: 1) }
    }
    func sessionStream() -> AsyncStream<TrainerSession?> { AsyncStream { _ in } }
    func refreshClaims() async {}
  }

  /// Never reached while signed out (`currentUid` is nil), so nothing leaves the test.
  private struct NoRemote: RemoteWriter, BinaryUploader, CallableClient {
    func createIfAbsent(path: String, fields: JSONValue) async throws -> WriteAck { throw RemoteError.unavailable }
    func update(path: String, fields: JSONValue) async throws -> WriteAck { throw RemoteError.unavailable }
    func delete(path: String) async throws -> WriteAck { throw RemoteError.unavailable }
    func upload(localURL: URL, path: String, contentType: String, sha256: String) async throws -> UploadReceipt {
      throw RemoteError.unavailable
    }
    func delete(path: String) async throws { throw RemoteError.unavailable }
    func call<T: Decodable & Sendable>(_ name: String, _ payload: JSONValue) async throws -> T {
      throw RemoteError.unavailable
    }
  }

  private var remote: SyncRemote {
    SyncRemote(writer: NoRemote(), uploader: NoRemote(), callable: NoRemote(), currentUid: { nil },
               sessions: { AsyncStream { _ in } })
  }

  override func tearDown() async throws {
    SessionRuntime.Cache.shared.retire(trainerUid: uid)?.deactivate()
    if let location = try? LocalStoreLocation.inApplicationSupport(trainerUid: uid) {
      try? FileManager.default.removeItem(at: location.partitionURL)
    }
  }

  private func item(_ note: String, state: OutboxItemState) -> OutboxItem {
    OutboxItem(memberKey: .uid("syn-0001"), entityRef: .soap(noteId: note), sequence: 1, stage: .document,
               kind: .createDocument, target: .document(path: "soap_notes/\(note)"), payload: .object([:]),
               state: state, ack: state == .acked ? .write(WriteAck(serverCommitted: true)) : nil,
               createdAt: Date(timeIntervalSince1970: 1_780_000_000))
  }

  func testLogoutOrderPurgesSyncedAndKeepsUnsynced_TC_DF018_01() async throws {
    let runtime = try XCTUnwrap(SessionRuntime.Cache.shared.runtime(trainerUid: uid) { remote })
    let store = LocalOutboxStore(container: runtime.container, trainerUid: uid, binaries: nil)
    let synced = item("SynNote0000000000001", state: .acked)
    let unsynced = item("SynNote0000000000002", state: .queued)
    try await store.insert(synced)
    try await store.insert(unsynced)

    let steps = Steps()
    let auth = FakeAuth(steps: steps, fails: false)
    let signOut = LiveSessionSignOut(
      trainerUid: uid, signOutAuth: { try await auth.signOut(discardUnsynced: false) },
      teardownRemote: { steps.add("teardown") })
    try await signOut.signOut()

    XCTAssertEqual(steps.all, ["teardown", "auth"])
    let left = try await LocalOutboxStore(container: runtime.container, trainerUid: uid, binaries: nil).loadAll()
    XCTAssertEqual(left.map(\.id), [unsynced.id], "only what the server has is purged")
    let next = SessionRuntime.Cache.shared.runtime(trainerUid: uid) { remote }
    XCTAssertFalse(next === runtime, "the next sign-in gets a fresh runtime")
  }

  func testAFailedSignOutPutsTheRuntimeBack() async throws {
    let runtime = try XCTUnwrap(SessionRuntime.Cache.shared.runtime(trainerUid: uid) { remote })
    let store = LocalOutboxStore(container: runtime.container, trainerUid: uid, binaries: nil)
    let synced = item("SynNote0000000000003", state: .acked)
    try await store.insert(synced)

    let steps = Steps()
    let auth = FakeAuth(steps: steps, fails: true)
    let signOut = LiveSessionSignOut(
      trainerUid: uid, signOutAuth: { try await auth.signOut(discardUnsynced: false) },
      teardownRemote: { steps.add("teardown") })
    do {
      try await signOut.signOut()
      XCTFail("expected the sign-out error")
    } catch {}

    XCTAssertEqual(steps.all, ["teardown", "auth"])
    let same = SessionRuntime.Cache.shared.runtime(trainerUid: uid) { remote }
    XCTAssertTrue(same === runtime, "still signed in: the runtime is back")
    let rows = try await store.loadAll()
    XCTAssertEqual(rows.map(\.id), [synced.id], "nothing purged while still signed in")
  }
}
