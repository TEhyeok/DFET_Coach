import Foundation
import SyncEngine
import TrainerContracts
import TrainerDomain
import XCTest

/// TC-DF015-01..05, 07: the actor engine against a fake remote (AC-DF-015.1-.5, .7). All data is synthetic.
final class SyncEngineTests: XCTestCase {
  private func makeEngine(
    store: InMemoryOutboxStore = InMemoryOutboxStore(), remote: FakeRemote, clock: TestClock = TestClock(),
    jitter: Double = 0
  ) -> SyncEngine {
    SyncEngine(store: store, writer: remote, uploader: remote, callable: remote, clock: clock, jitter: { jitter })
  }

  // MARK: TC-DF015-01

  func testFiveStepsRunInOrderWhateverTheEnqueueOrder_TC_DF015_01() async {
    let remote = FakeRemote()
    let engine = makeEngine(remote: remote)
    for item in OutboxFixtures.soapSteps(member: "m1", note: "n1").reversed() {
      await engine.enqueue(item)
    }
    await engine.start()
    await idle(engine)

    XCTAssertEqual(remote.calls, [
      .init(kind: "call", target: "recordConsent-m1"),
      .init(kind: "create", target: "soap_notes/n1"),
      .init(kind: "upload", target: "soapInk/n1/1.drawing"),
      .init(kind: "update", target: "soap_notes/n1"),
      .init(kind: "update", target: "soap_notes/n1"),
    ])
  }

  func testOtherMembersAreNotBlocked_TC_DF015_01() async {
    let remote = FakeRemote()
    let engine = makeEngine(remote: remote)
    remote.hold("recordConsent-m2")
    for member in ["m1", "m2", "m3"] {
      await engine.enqueue(contentsOf: OutboxFixtures.soapSteps(member: member, note: "n-\(member)"))
    }
    await engine.start()

    // m2 is stuck on its consent call; m1 and then m3 still finish. The two-member cap has its own test
    // (SyncEngineReviewTests.testAtMostTwoMembersRunAndTheThirdStartsWhenOneFinishes).
    let othersDone = await eventually { remote.calls(to: "soap_notes/n-m1").count == 3 && remote.calls(to: "soap_notes/n-m3").count == 3 }
    XCTAssertTrue(othersDone, "m1 and m3 must not wait for m2")
    XCTAssertEqual(remote.calls(to: "soap_notes/n-m2").count, 0)
    XCTAssertTrue(remote.isWaiting(on: "recordConsent-m2"))

    remote.release("recordConsent-m2")
    await idle(engine)
    XCTAssertEqual(remote.calls(to: "soap_notes/n-m2").count, 3)
    for member in ["m1", "m2", "m3"] {
      let order = remote.calls.filter { $0.target.contains(member) }.map(\.kind)
      XCTAssertEqual(order, ["call", "create", "upload", "update", "update"], member)
    }
  }

  // MARK: TC-DF015-02

  func testConsentRejectionBlocksTheMemberWithoutRemoteCalls_TC_DF015_02() async {
    let remote = FakeRemote()
    let engine = makeEngine(remote: remote)
    remote.fail("recordConsent-m1", with: [.permissionDenied])
    let steps = OutboxFixtures.soapSteps(member: "m1", note: "n1")
    for item in steps { await engine.enqueue(item) }
    await engine.start()
    await idle(engine)

    XCTAssertEqual(remote.calls.map(\.kind), ["call"], "no call after the consent rejection")
    let consent = await engine.item(steps[0].id)
    XCTAssertEqual(consent?.state, .failed)
    XCTAssertEqual(consent?.lastErrorCode, "permission-denied")
    for step in steps.dropFirst() {
      let item = await engine.item(step.id)
      XCTAssertEqual(item?.state, .blocked(.awaitingConsent))
    }
    let soapState = await firstValue(of: await engine.syncState(for: .soap(noteId: "n1")))
    XCTAssertEqual(soapState, .awaitingConsent)

    // A record added later for the same member waits too.
    let late = OutboxFixtures.create(member: "m1", note: "n1-late", sequence: 10)
    await engine.enqueue(late)
    let lateItem = await engine.item(late.id)
    XCTAssertEqual(lateItem?.state, .blocked(.awaitingConsent))
  }

  func testRetryingTheConsentReleasesTheBlockedItems() async {
    let remote = FakeRemote()
    let engine = makeEngine(remote: remote)
    remote.fail("recordConsent-m1", with: [.permissionDenied])
    let steps = OutboxFixtures.soapSteps(member: "m1", note: "n1")
    for item in steps { await engine.enqueue(item) }
    await engine.start()
    await idle(engine)

    await engine.retry(steps[0].id)
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 6)
    let soapState = await firstValue(of: await engine.syncState(for: .soap(noteId: "n1")))
    XCTAssertEqual(soapState, .synced)
  }

  // MARK: TC-DF015-03

  func testRuleRejectionFailsAtOnceKeepsTheLocalItemAndNeverShowsSynced_TC_DF015_03() async {
    let clock = TestClock()
    let remote = FakeRemote()
    let store = InMemoryOutboxStore()
    let engine = makeEngine(store: store, remote: remote, clock: clock)
    remote.fail("soap_notes/n1", with: [.permissionDenied])
    let steps = OutboxFixtures.soapSteps(member: "m1", note: "n1")
    for item in steps { await engine.enqueue(item) }
    let states = Recorder(await engine.syncState(for: .soap(noteId: "n1")))
    await engine.start()
    await idle(engine)

    let create = await engine.item(steps[1].id)
    XCTAssertEqual(create?.state, .failed)
    XCTAssertEqual(create?.lastErrorCode, "permission-denied")
    let reachedFailed = await eventually { states.values.last == .syncFailed }
    XCTAssertTrue(reachedFailed, "states: \(states.values)")

    clock.advance(by: 3600)
    await idle(engine)
    XCTAssertEqual(remote.calls(to: "soap_notes/n1").count, 1, "no automatic retry")
    XCTAssertFalse(states.values.contains(.synced))
    let stored = await store.item(steps[1].id)
    XCTAssertEqual(stored?.payload, steps[1].payload, "the local original stays")
    states.stop()
  }

  // MARK: TC-DF015-04

  func testBackoffLimitAndRetryReset_TC_DF015_04() async {
    let clock = TestClock()
    let remote = FakeRemote(clock: clock)
    let engine = makeEngine(remote: remote, clock: clock)
    remote.fail("soap_notes/n1", with: Array(repeating: .unavailable, count: 6))
    let item = OutboxFixtures.create(member: "m1", note: "n1")
    await engine.enqueue(item)
    await engine.start()
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 1)

    for (index, delay) in [2.0, 4, 8, 16].enumerated() {
      clock.advance(by: delay - 0.5)
      await idle(engine)
      XCTAssertEqual(remote.calls.count, index + 1, "not before \(delay) s")
      clock.advance(by: 0.5)
      await idle(engine)
      XCTAssertEqual(remote.calls.count, index + 2, "after \(delay) s")
    }
    let gaps = zip(remote.callTimes.dropFirst(), remote.callTimes).map { $0.timeIntervalSince($1) }
    XCTAssertEqual(gaps, [2, 4, 8, 16])

    let exhausted = await engine.item(item.id)
    XCTAssertEqual(exhausted?.state, .failed, "five consecutive failures")
    XCTAssertEqual(exhausted?.attempts, 5)
    XCTAssertEqual(exhausted?.lastErrorCode, "unavailable")
    clock.advance(by: 3600)
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 5)

    await engine.retry(item.id)
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 6, "retry sends at once")
    let restarted = await engine.item(item.id)
    XCTAssertEqual(restarted?.attempts, 1, "attempts restarted from zero")
    XCTAssertEqual(restarted?.state, .queued)
    XCTAssertEqual(restarted?.nextAttemptAt, clock.now().addingTimeInterval(2))
  }

  func testJitterWidensTheDelay() async {
    let clock = TestClock()
    let remote = FakeRemote()
    let engine = makeEngine(remote: remote, clock: clock, jitter: 1)
    remote.fail("soap_notes/n1", with: [.deadlineExceeded])
    let item = OutboxFixtures.create(member: "m1", note: "n1")
    await engine.enqueue(item)
    await engine.start()
    await idle(engine)
    let queued = await engine.item(item.id)
    XCTAssertEqual(queued?.nextAttemptAt.timeIntervalSince(clock.now()) ?? 0, 2.4, accuracy: 1e-6)
  }

  func testLockedDeviceDefersWithoutCountingTheAttempt() async {
    let clock = TestClock()
    let remote = FakeRemote()
    let engine = makeEngine(remote: remote, clock: clock)
    remote.fail("soap_notes/n1", with: [.protectedDataUnavailable])
    let item = OutboxFixtures.create(member: "m1", note: "n1")
    await engine.enqueue(item)
    await engine.start()
    await idle(engine)

    let waiting = await engine.item(item.id)
    XCTAssertEqual(waiting?.state, .queued)
    XCTAssertEqual(waiting?.attempts, 0, "not counted toward the limit (ASM-P0-29)")
    clock.advance(by: 3600)
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 1, "paused until unlock")

    await engine.protectedDataDidBecomeAvailable()
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 2)
    let done = await engine.item(item.id)
    XCTAssertEqual(done?.state, .acked)
  }

  /// DF-108 H1: a reply that the Outbox's trainer is not signed in never fails an item or spends an attempt; sending
  /// waits for `start()` (the session is back), even across the one-minute `retryExhausted()` tick.
  func testSignedOutPausesWithoutFailingUntilTheNextStart() async {
    let clock = TestClock()
    let remote = FakeRemote()
    let engine = makeEngine(remote: remote, clock: clock)
    remote.fail("soap_notes/n1", with: [.signedOut])
    let first = OutboxFixtures.create(member: "m1", note: "n1")
    let other = OutboxFixtures.create(member: "m2", note: "n2")
    await engine.enqueue(first)
    await engine.start()
    await idle(engine)

    let waiting = await engine.item(first.id)
    XCTAssertEqual(waiting?.state, .queued)
    XCTAssertEqual(waiting?.attempts, 0)
    await engine.enqueue(other)
    clock.advance(by: 3600)
    await engine.retryExhausted()
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 1, "nothing is sent while signed out")

    await engine.start()
    await idle(engine)
    let done = await engine.item(first.id)
    let otherDone = await engine.item(other.id)
    XCTAssertEqual(done?.state, .acked)
    XCTAssertEqual(otherDone?.state, .acked)
  }

  func testUnverifiedUploadIsRetried() async {
    let remote = FakeRemote()
    let engine = makeEngine(remote: remote)
    remote.markUploadUnverified("soapInk/n1/1.drawing")
    let steps = OutboxFixtures.soapSteps(member: "m1", note: "n1")
    for item in steps { await engine.enqueue(item) }
    await engine.start()
    await idle(engine)
    let upload = await engine.item(steps[2].id)
    XCTAssertEqual(upload?.state, .queued)
    XCTAssertEqual(upload?.lastErrorCode, "upload-unverified")
    XCTAssertEqual(upload?.attempts, 1)
    XCTAssertEqual(remote.calls(to: "soap_notes/n1").count, 1, "the path record waits for a verified upload")
  }

  // MARK: TC-DF015-05

  func testRestartRequeuesInFlightWithoutADuplicateCreate_TC_DF015_05() async {
    let remote = FakeRemote()
    remote.seedDocument("soap_notes/n1")  // the create committed; the reply was lost when the app was killed
    var item = OutboxFixtures.create(member: "m1", note: "n1")
    item.state = .inFlight
    item.attempts = 1
    let store = InMemoryOutboxStore([item])
    let engine = makeEngine(store: store, remote: remote)

    let reloaded = await engine.item(item.id)
    XCTAssertEqual(reloaded?.state, .queued, "inFlight goes back to queued on load")
    let persisted = await store.item(item.id)
    XCTAssertEqual(persisted?.state, .queued)

    await engine.start()
    await idle(engine)
    XCTAssertEqual(remote.createWrites, 0, "no second document write")
    XCTAssertEqual(remote.calls(to: "soap_notes/n1").count, 1)
    let acked = await engine.item(item.id)
    XCTAssertEqual(acked?.state, .acked)
  }

  // MARK: TC-DF015-07

  func testPendingCountDropsByOnePerAckedItem_TC_DF015_07() async {
    let remote = FakeRemote()
    let engine = makeEngine(remote: remote)
    for item in OutboxFixtures.soapSteps(member: "m1", note: "n1") { await engine.enqueue(item) }
    let counts = Recorder(await engine.pendingCount())
    await engine.start()
    await idle(engine)
    let done = await eventually { counts.values.last == 0 }
    XCTAssertTrue(done)
    XCTAssertEqual(counts.values, [5, 4, 3, 2, 1, 0])
    counts.stop()
  }

  func testSyncStateGoesLocalSavedSyncingSynced() async {
    let remote = FakeRemote()
    let engine = makeEngine(remote: remote)
    let item = OutboxFixtures.create(member: "m1", note: "n1")
    await engine.enqueue(item)
    let states = Recorder(await engine.syncState(for: .soap(noteId: "n1")))
    await engine.start()
    await idle(engine)
    let done = await eventually { states.values.last == .synced }
    XCTAssertTrue(done)
    XCTAssertEqual(states.values, [.localSaved, .syncing, .synced], "each value once")
    states.stop()
  }

  // MARK: helpers

  private func eventually(timeout: TimeInterval = 5, _ condition: () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if condition() { return true }
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
    return condition()
  }

  private func firstValue<T: Sendable>(of stream: AsyncStream<T>) async -> T? {
    for await value in stream { return value }
    return nil
  }
}

/// Collects a stream's values on a background task.
final class Recorder<T: Sendable>: @unchecked Sendable {
  private let lock = NSLock()
  private var _values: [T] = []
  private var task: Task<Void, Never>?

  init(_ stream: AsyncStream<T>) {
    task = Task { [weak self] in
      for await value in stream {
        self?.lock.withLock { self?._values.append(value) }
      }
    }
  }

  var values: [T] { lock.withLock { _values } }

  func stop() {
    task?.cancel()
  }
}
