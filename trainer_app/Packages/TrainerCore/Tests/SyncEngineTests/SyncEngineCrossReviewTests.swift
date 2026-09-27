import Foundation
import SyncEngine
import TrainerContracts
import TrainerDomain
import XCTest

/// Regression tests from the GPT cross-review of main: the bounded logout drain, a failed store re-read, a save failure
/// from before an unlock, local failures of consent captures, and `unauthenticated`. All data is synthetic.
final class SyncEngineCrossReviewTests: XCTestCase {
  private func capture(_ name: String, member: String = "m1", sequence: Int64) -> OutboxItem {
    OutboxItem(memberKey: .uid(member), entityRef: .consent(captureId: name), sequence: sequence, stage: .consent,
               kind: .callConsent, target: .callable(name: name), payload: .object([:]),
               createdAt: OutboxFixtures.createdAt)
  }

  /// A capture this build could not read (`LocalOutboxStore` loads it failed, without its payload).
  private func unreadable(_ name: String, sequence: Int64) -> OutboxItem {
    var item = capture(name, sequence: sequence)
    item.payload = nil
    item.state = .failed
    item.lastErrorCode = "local-unreadable"
    return item
  }

  /// Logout's drain (V1-04 §12.2 ②): a call that never returns (a Firestore write offline) must not hold the bounded
  /// wait. Cancelling the waiter ends `waitUntilIdle()` at once; the item stays unsynced.
  func testCancellingTheIdleWaitEndsItWhileACallNeverReturns() async {
    let remote = FakeRemote()
    remote.hold("soap_notes/n1")
    let engine = makeTestEngine(remote: remote)
    let item = OutboxFixtures.create(member: "m1", note: "n1")
    await engine.enqueue(item)
    await engine.start()
    let calling = await eventually { remote.isWaiting(on: "soap_notes/n1") }
    XCTAssertTrue(calling)
    await engine.stop()

    let drained = IdleFlag()
    Task {
      await withTaskGroup(of: Void.self) { group in  // SessionRuntime.stopSending's bound
        group.addTask { await engine.waitUntilIdle() }
        group.addTask { try? await Task.sleep(nanoseconds: 50_000_000) }
        await group.next()
        group.cancelAll()
      }
      drained.set()
    }
    let returned = await eventually(timeout: 2) { drained.isSet }
    XCTAssertTrue(returned, "the bound returns although the call is still out")
    let cutOff = await engine.item(item.id)
    XCTAssertEqual(cutOff?.state, .inFlight, "cut off, it stays unsynced")
    remote.release("soap_notes/n1")
    await idle(engine)
  }

  /// A foreground `start()` whose re-read of the store fails sends nothing: rows retention deleted meanwhile are still
  /// in memory (AS-32). The next `start()` reads the store and drops them.
  func testAFailedStoreReadAtStartSendsNothing() async {
    let remote = FakeRemote()
    let store = ControllableStore()
    let engine = makeTestEngine(store: store, remote: remote)
    await engine.networkDidChange(isReachable: false)
    let steps = OutboxFixtures.soapSteps(member: "m1", note: "n1")
    await engine.enqueue(contentsOf: steps)
    await engine.start()
    await store.remove(steps.map(\.id))  // retention purged the expired capture and its records
    await store.failNextLoads(1)
    await engine.start()  // foreground: the re-read fails
    await engine.networkDidChange(isReachable: true)
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 0, "nothing retention destroyed is sent")

    await engine.start()  // the next foreground reads the store
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 0)
    let pending = await firstValue(of: await engine.pendingCount())
    XCTAssertEqual(pending, 0)
  }

  /// A save that was out when the device unlocked and fails afterwards does not pause sending again: the unlock came
  /// after it started, so the row is saved again at once and sent.
  func testASaveThatFailsAfterTheUnlockDoesNotPauseAgain() async {
    let remote = FakeRemote()
    let store = ControllableStore()
    let engine = makeTestEngine(store: store, remote: remote)
    await engine.start()
    let item = OutboxFixtures.create(member: "m1", note: "n1")
    await store.holdSaves { $0.id == item.id }
    let enqueueing = Task { await engine.enqueue(item) }
    let holding = await eventually { await store.heldCount > 0 }
    XCTAssertTrue(holding)
    let unlocking = Task { await engine.protectedDataDidBecomeAvailable() }
    let unlocked = await eventually { await engine.item(item.id)?.state == .inFlight }  // its pump ran
    XCTAssertTrue(unlocked)
    await store.releaseSaves(failing: true)
    await enqueueing.value
    await unlocking.value
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 1, "not paused by a failure from before the unlock")
    let saved = await store.item(item.id)
    XCTAssertEqual(saved?.state, .acked)
  }

  /// A save that fails with no unlock or `start()` since it began still pauses (AC-DF-015, V1-04 §10).
  func testASaveThatFailsWithoutAnUnlockStillPauses() async {
    let remote = FakeRemote()
    let store = ControllableStore()
    let engine = makeTestEngine(store: store, remote: remote)
    await engine.start()
    let item = OutboxFixtures.create(member: "m1", note: "n1")
    await store.holdSaves { $0.id == item.id }
    let enqueueing = Task { await engine.enqueue(item) }
    let holding = await eventually { await store.heldCount > 0 }
    XCTAssertTrue(holding)
    await store.releaseSaves(failing: true)
    await enqueueing.value
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 0, "paused until unlock")

    await engine.protectedDataDidBecomeAvailable()
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 1)
  }

  /// An older capture this build cannot read failed on the device, not on the server: the newer capture still waits
  /// behind it (V1-05 §12.3), even across the automatic retry.
  func testAnUnreadableOlderCaptureHoldsTheNewerOne() async {
    let remote = FakeRemote()
    let c2 = capture("c2", sequence: 2)
    let engine = makeTestEngine(store: ControllableStore([unreadable("c1", sequence: 1), c2]), remote: remote)
    await engine.start()
    await engine.retryExhausted()
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 0, "the newer capture waits for the older one")
    let newer = await engine.item(c2.id)
    XCTAssertEqual(newer?.state, .queued)
  }

  /// A local failure is never superseded, so a build that can read the capture again can still send it; a server
  /// rejection older than the acked capture still is.
  func testOnlyARejectedCaptureOlderThanAnAckedOneIsSuperseded() async {
    let old = unreadable("c1", sequence: 1)
    var rejected = capture("c2", sequence: 2)
    rejected.state = .failed
    rejected.lastErrorCode = "permission-denied"
    var acked = capture("c3", sequence: 3)
    acked.state = .acked
    acked.ack = .call
    let engine = makeTestEngine(store: ControllableStore([old, rejected, acked]), remote: FakeRemote())
    await engine.start()
    let kept = await engine.item(old.id)
    XCTAssertEqual(kept?.state, .failed, "a capture that failed on the device was not rejected")
    let superseded = await engine.item(rejected.id)
    XCTAssertEqual(superseded?.state, .superseded)
  }

  /// V1-06 §8.7: `unauthenticated` changes no state and spends no attempt; sending waits for the session (`start()`).
  func testUnauthenticatedWaitsForTheSessionWithoutFailing() async {
    let clock = TestClock()
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote, clock: clock)
    remote.fail("soap_notes/n1", with: [.unauthenticated])
    let item = OutboxFixtures.create(member: "m1", note: "n1")
    await engine.enqueue(item)
    await engine.start()
    await idle(engine)

    let waiting = await engine.item(item.id)
    XCTAssertEqual(waiting?.state, .queued)
    XCTAssertEqual(waiting?.attempts, 0)
    clock.advance(by: 3600)
    await engine.retryExhausted()
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 1, "nothing is sent until the session is back")

    await engine.start()
    await idle(engine)
    let done = await engine.item(item.id)
    XCTAssertEqual(done?.state, .acked)
  }
}
