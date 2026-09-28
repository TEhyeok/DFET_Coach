import Foundation
import SyncEngine
import XCTest

/// Logout's bounded drain (V1-04 §12.2 ②). The drain returning while a call never returns is covered by
/// `SyncEngineCrossReviewTests.testCancellingTheIdleWaitEndsItWhileACallNeverReturns`.
final class SyncEngineLogoutDrainTests: XCTestCase {
  /// Cancelling one `waitUntilIdle()` ends only that wait; another caller keeps waiting until the engine is idle.
  func testCancellingOneIdleWaiterDoesNotFinishOtherWaiters() async {
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote)
    let path = "soap_notes/synth-waiters"
    remote.hold(path)
    await engine.enqueue(OutboxFixtures.create(member: "synthMember0001", note: "synth-waiters"))
    await engine.start()
    let started = await eventually { remote.isWaiting(on: path) }
    XCTAssertTrue(started)
    let cancelled = IdleFlag()
    let normal = IdleFlag()
    let one = Task { await engine.waitUntilIdle(); cancelled.set() }
    let two = Task { await engine.waitUntilIdle(); normal.set() }
    // Let both waits register first. A task cancelled before it reaches the engine returns on its own cancelled
    // check and never exercises the per-waiter removal. If scheduling is slow the test only gets weaker, never red.
    try? await Task.sleep(nanoseconds: 100_000_000)
    one.cancel()
    let stopped = await eventually(timeout: 1) { cancelled.isSet }
    XCTAssertTrue(stopped)
    let leaked = await eventually(timeout: 0.2) { normal.isSet }
    XCTAssertFalse(leaked, "cancelling one waiter must not resume the others")
    remote.release(path)
    let resumed = await eventually { normal.isSet }  // bounded, so a regression fails instead of hanging the suite
    XCTAssertTrue(resumed, "the other waiter still returns once the engine is idle")
    _ = await one.value
  }
}
