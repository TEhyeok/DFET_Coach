import Foundation
import LocalStore
import SyncEngine
import TrainerDomain
import XCTest
@testable import DFETTrainer

/// GPT cross-review (V1-06 §8.7): an `unauthenticated` reply while the same trainer stays signed in pauses sending
/// without failing the item, asks Auth for a fresh token, and the session published again restarts sending. No
/// Firebase: a scripted remote and session stream in the test host.
@MainActor
final class SessionResumeTests: XCTestCase {
  private let uid = "syn-resume-" + UUID().uuidString.prefix(8)

  /// Fails the first `failures` creates with `unauthenticated`, then accepts every call.
  private final class FlakyAuthRemote: RemoteWriter, BinaryUploader, CallableClient, @unchecked Sendable {
    private let lock = NSLock()
    private let failures: Int
    private var _creates = 0
    var creates: Int { lock.withLock { _creates } }

    init(failures: Int = 1) {
      self.failures = failures
    }

    func createIfAbsent(path: String, fields: JSONValue) async throws -> WriteAck {
      let attempt = lock.withLock { () -> Int in
        _creates += 1
        return _creates
      }
      if attempt <= failures { throw RemoteError.unauthenticated }
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

  private func item(_ note: String) -> OutboxItem {
    OutboxItem(
      memberKey: .uid("syn-0001"), entityRef: .soap(noteId: note), sequence: 1, stage: .document,
      kind: .createDocument, target: .document(path: "soap_notes/\(note)"), payload: .object([:]),
      createdAt: Date(timeIntervalSince1970: 1_780_000_000))
  }

  private func runtime(
    remote: FlakyAuthRemote, sessions: AsyncStream<TrainerSession?>, refresh: @escaping @Sendable () async -> Bool
  ) throws -> SessionRuntime {
    let trainerUid = uid
    return try XCTUnwrap(SessionRuntime.Cache.shared.runtime(trainerUid: trainerUid) {
      SyncRemote(writer: remote, uploader: remote, callable: remote, currentUid: { trainerUid }, sessions: { sessions },
                 refreshSession: refresh)
    })
  }

  func testATokenRefreshAfterUnauthenticatedResumesSending() async throws {
    let remote = FlakyAuthRemote()
    let refreshes = Counter()
    let session = TrainerSession(uid: uid, displayName: "SYN-TRAINER")
    let (sessions, continuation) = AsyncStream.makeStream(of: TrainerSession?.self)
    continuation.yield(session)
    let runtime = try runtime(remote: remote, sessions: sessions) {
      // Firebase's token listener publishes the session again after a forced refresh that changed the token.
      refreshes.increment()
      continuation.yield(session)
      return true
    }
    await runtime.engine.enqueue(item("SynNote0000000000009"))

    for _ in 0..<300 where remote.creates < 2 {
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTAssertEqual(refreshes.value, 1, "one token refresh was asked for")
    XCTAssertEqual(remote.creates, 2, "sending resumed after the session came back")
    await runtime.engine.waitUntilIdle()
    let stored = try await LocalOutboxStore(container: runtime.container, trainerUid: uid, binaries: nil).loadAll()
    XCTAssertEqual(stored.map(\.state), [.acked], "never failed on the way")
  }

  /// GPT final review: the SDK publishes nothing when the refreshed token is unchanged; a successful refresh must
  /// restart sending by itself.
  func testASuccessfulRefreshResumesWithoutANewSessionEvent() async throws {
    let remote = FlakyAuthRemote()
    let (sessions, continuation) = AsyncStream.makeStream(of: TrainerSession?.self)
    continuation.yield(TrainerSession(uid: uid, displayName: "SYN-TRAINER"))
    let runtime = try runtime(remote: remote, sessions: sessions) { true }
    await runtime.engine.enqueue(item("SynNote0000000000010"))

    for _ in 0..<300 where remote.creates < 2 {
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTAssertEqual(remote.creates, 2, "the refresh itself restarted sending")
  }

  /// GPT final review: a server that keeps refusing the token gets one refresh a minute, not a tight loop.
  func testAServerThatKeepsRefusingGetsOneRefreshAMinute() async throws {
    let remote = FlakyAuthRemote(failures: .max)
    let refreshes = Counter()
    let session = TrainerSession(uid: uid, displayName: "SYN-TRAINER")
    let (sessions, continuation) = AsyncStream.makeStream(of: TrainerSession?.self)
    continuation.yield(session)
    let runtime = try runtime(remote: remote, sessions: sessions) {
      refreshes.increment()
      continuation.yield(session)
      return true
    }
    await runtime.engine.enqueue(item("SynNote0000000000011"))

    try await Task.sleep(nanoseconds: 1_500_000_000)
    XCTAssertEqual(refreshes.value, 1)
    XCTAssertLessThanOrEqual(remote.creates, 3, "no refresh-and-resend loop")
  }

  /// GPT final review: a refresh that succeeds after logout stopped the runtime must not start sending again.
  func testARefreshThatSucceedsAfterLogoutStoppedTheRuntimeSendsNothing() async throws {
    let remote = FlakyAuthRemote(failures: 1)
    let gate = AsyncStream.makeStream(of: Void.self)
    let refreshes = Counter()
    let (sessions, continuation) = AsyncStream.makeStream(of: TrainerSession?.self)
    continuation.yield(TrainerSession(uid: uid, displayName: "SYN-TRAINER"))
    let runtime = try runtime(remote: remote, sessions: sessions) {
      refreshes.increment()
      for await _ in gate.stream { break }
      return true
    }
    await runtime.engine.enqueue(item("SynNote0000000000012"))
    for _ in 0..<300 where refreshes.value == 0 {
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTAssertEqual(remote.creates, 1)

    await runtime.stopSending(drainTimeout: .milliseconds(100))
    gate.continuation.yield()  // the refresh succeeds only now
    try await Task.sleep(nanoseconds: 500_000_000)
    XCTAssertEqual(remote.creates, 1, "logout wins over a late refresh")
  }

  /// GPT final review: engine → remote → refresher → callback must not hold the runtime or the engine alive.
  func testTheRuntimeAndItsEngineAreReleased() throws {
    weak var weakRuntime: SessionRuntime?
    weak var weakEngine: SyncEngine?
    do {
      let trainerUid = uid
      let remote = FlakyAuthRemote()
      let runtime = try SessionRuntime(trainerUid: trainerUid, remote: SyncRemote(
        writer: remote, uploader: remote, callable: remote, currentUid: { trainerUid },
        sessions: { AsyncStream { _ in } }, refreshSession: { true }))
      weakRuntime = runtime
      weakEngine = runtime.engine
    }
    XCTAssertNil(weakRuntime)
    XCTAssertNil(weakEngine)
  }

  /// GPT review: a request inside the minute is kept and runs when the minute is over; cancel() drops it.
  func testARequestInsideTheIntervalRunsWhenItIsOver() async throws {
    let refreshes = Counter()
    let restarts = Counter()
    let refresher = SessionRefresher(refresh: {
      refreshes.increment()
      return true
    }, minimumInterval: 0.3)
    refresher.onRefreshed { restarts.increment() }
    refresher.unauthenticated()
    for _ in 0..<100 where restarts.value == 0 { try await Task.sleep(nanoseconds: 10_000_000) }
    refresher.unauthenticated()  // inside the interval: kept, not dropped
    refresher.unauthenticated()  // still one kept request
    XCTAssertEqual(refreshes.value, 1)
    for _ in 0..<200 where refreshes.value < 2 { try await Task.sleep(nanoseconds: 10_000_000) }
    XCTAssertEqual(refreshes.value, 2, "the kept request ran after the interval")

    refresher.unauthenticated()  // inside the new interval: kept again
    refresher.cancel()
    try await Task.sleep(nanoseconds: 600_000_000)
    XCTAssertEqual(refreshes.value, 2, "one request was kept each time, and cancel dropped the last one")
  }

  func testTheRefresherCoalescesAndWaitsAMinute() async throws {
    let refreshes = Counter()
    let clock = Counter()  // seconds
    let gate = AsyncStream.makeStream(of: Void.self)
    let refresher = SessionRefresher(refresh: {
      refreshes.increment()
      for await _ in gate.stream { break }
      return true
    }, now: { Date(timeIntervalSince1970: TimeInterval(clock.value)) })
    let restarts = Counter()
    refresher.onRefreshed { restarts.increment() }

    refresher.unauthenticated()
    refresher.unauthenticated()  // coalesced while the first is out
    for _ in 0..<100 where refreshes.value == 0 { try await Task.sleep(nanoseconds: 10_000_000) }
    gate.continuation.yield()
    for _ in 0..<100 where restarts.value == 0 { try await Task.sleep(nanoseconds: 10_000_000) }
    XCTAssertEqual(refreshes.value, 1)
    XCTAssertEqual(restarts.value, 1)

    refresher.unauthenticated()  // within the minute
    try await Task.sleep(nanoseconds: 100_000_000)
    XCTAssertEqual(refreshes.value, 1)
    for _ in 0..<60 { clock.increment() }
    gate.continuation.yield()
    refresher.unauthenticated()  // a minute later
    for _ in 0..<100 where refreshes.value < 2 { try await Task.sleep(nanoseconds: 10_000_000) }
    XCTAssertEqual(refreshes.value, 2)
  }
}
