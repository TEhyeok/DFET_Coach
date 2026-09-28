import Foundation
import LocalStore
import TrainerDomain
import XCTest
@testable import DFETTrainer

/// GPT cross-review (V1-06 §8.7): an `unauthenticated` reply while the same trainer stays signed in pauses sending
/// without failing the item, asks Auth for a fresh token, and the session published again restarts sending. No
/// Firebase: a scripted remote and session stream in the test host.
@MainActor
final class SessionResumeTests: XCTestCase {
  private let uid = "syn-resume-" + UUID().uuidString.prefix(8)

  /// Fails the first create with `unauthenticated`, then accepts every call.
  private final class FlakyAuthRemote: RemoteWriter, BinaryUploader, CallableClient, @unchecked Sendable {
    private let lock = NSLock()
    private var _creates = 0
    var creates: Int { lock.withLock { _creates } }

    func createIfAbsent(path: String, fields: JSONValue) async throws -> WriteAck {
      let attempt = lock.withLock { () -> Int in
        _creates += 1
        return _creates
      }
      if attempt == 1 { throw RemoteError.unauthenticated }
      return WriteAck(serverCommitted: true)
    }
    func update(path: String, fields: JSONValue) async throws -> WriteAck { WriteAck(serverCommitted: true) }
    func delete(path: String) async throws -> WriteAck { WriteAck(serverCommitted: true) }
    func upload(localURL: URL, path: String, contentType: String, sha256: String) async throws -> UploadReceipt {
      UploadReceipt(path: path, size: 0, sha256: sha256, verified: true)
    }
    func delete(path: String) async throws {}
    func call<T: Decodable & Sendable>(_ name: String, _ payload: JSONValue) async throws -> T {
      try JSONDecoder().decode(T.self, from: Data("{}".utf8))
    }
  }

  private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0
    var value: Int { lock.withLock { _value } }
    func increment() { lock.withLock { _value += 1 } }
  }

  override func tearDown() async throws {
    SessionRuntime.Cache.shared.retire(trainerUid: uid)?.deactivate()
    if let location = try? LocalStoreLocation.inApplicationSupport(trainerUid: uid) {
      try? FileManager.default.removeItem(at: location.partitionURL)
    }
  }

  func testATokenRefreshAfterUnauthenticatedResumesSending() async throws {
    let remote = FlakyAuthRemote()
    let refreshes = Counter()
    let trainerUid = uid
    let session = TrainerSession(uid: trainerUid, displayName: "SYN-TRAINER")
    let (sessions, continuation) = AsyncStream.makeStream(of: TrainerSession?.self)
    continuation.yield(session)
    let runtime = try XCTUnwrap(SessionRuntime.Cache.shared.runtime(trainerUid: trainerUid) {
      SyncRemote(
        writer: remote, uploader: remote, callable: remote, currentUid: { trainerUid }, sessions: { sessions },
        refreshSession: {
          // Firebase's token listener publishes the session again after a forced refresh.
          refreshes.increment()
          continuation.yield(session)
        })
    })
    let item = OutboxItem(
      memberKey: .uid("syn-0001"), entityRef: .soap(noteId: "SynNote0000000000009"), sequence: 1, stage: .document,
      kind: .createDocument, target: .document(path: "soap_notes/SynNote0000000000009"), payload: .object([:]),
      createdAt: Date(timeIntervalSince1970: 1_780_000_000))
    await runtime.engine.enqueue(item)

    for _ in 0..<300 where remote.creates < 2 {
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTAssertEqual(refreshes.value, 1, "one token refresh was asked for")
    XCTAssertEqual(remote.creates, 2, "sending resumed after the session came back")
    await runtime.engine.waitUntilIdle()
    let stored = try await LocalOutboxStore(container: runtime.container, trainerUid: trainerUid, binaries: nil)
      .loadAll()
    XCTAssertEqual(stored.map(\.state), [.acked], "never failed on the way")
  }
}
