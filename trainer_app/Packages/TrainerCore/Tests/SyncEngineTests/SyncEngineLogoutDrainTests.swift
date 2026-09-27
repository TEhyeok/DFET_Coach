import Foundation
import SyncEngine
import XCTest

final class SyncEngineLogoutDrainTests: XCTestCase {
  /// P1 regression: the logout task group must return on its timer while the in-flight remote is still held.
  /// An outer polling deadline releases the fake even on regression, so this test cannot hang the suite.
  func testLogoutDrainTimeoutReturnsBeforeRemoteResponse() async {
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote)
    let path = "soap_notes/synth-logout"
    remote.hold(path)
    await engine.enqueue(OutboxFixtures.create(member: "synthMember0001", note: "synth-logout"))
    await engine.start()
    let started = await eventually { remote.isWaiting(on: path) }
    XCTAssertTrue(started)
    await engine.stop()
    let returned = IdleFlag()
    let drain = Task {
      await withTaskGroup(of: Void.self) { group in
        group.addTask { await engine.waitUntilIdle() }
        group.addTask { try? await Task.sleep(for: .milliseconds(20)) }
        await group.next()
        group.cancelAll()
      }
      returned.set()
    }
    let timedOut = await eventually(timeout: 1) { returned.isSet }
    XCTAssertTrue(timedOut, "The cancelled idle waiter must not hold the task-group scope open")
    XCTAssertTrue(remote.isWaiting(on: path), "The timeout must work without cancelling or completing the remote write")
    remote.release(path)
    await drain.value
    await idle(engine)
  }

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
    one.cancel()
    let stopped = await eventually(timeout: 1) { cancelled.isSet }
    XCTAssertTrue(stopped)
    XCTAssertFalse(normal.isSet)
    remote.release(path)
    await one.value
    await two.value
    XCTAssertTrue(normal.isSet)
  }
}
