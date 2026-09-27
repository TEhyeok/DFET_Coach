import Foundation
import SyncEngine
import TrainerContracts
import TrainerDomain
import XCTest

/// Regression tests from the third PR #168 review: store reconciliation races, supersession on load, and saves that
/// must not resurrect deleted rows. All data is synthetic.
final class SyncEngineRound3Tests: XCTestCase {
  private func capture(_ name: String, member: String = "m1", sequence: Int64) -> OutboxItem {
    OutboxItem(memberKey: .uid(member), entityRef: .consent(captureId: name), sequence: sequence, stage: .consent,
               kind: .callConsent, target: .callable(name: name), payload: .object([:]),
               createdAt: OutboxFixtures.createdAt)
  }

  /// R7: a capture enqueued while start()'s store read is outstanding is never dropped, so the record behind it
  /// cannot go without a consent reaching the server.
  func testACaptureEnqueuedDuringTheStoreReadIsKept() async {
    let remote = FakeRemote()
    let store = ControllableStore()
    let engine = makeTestEngine(store: store, remote: remote)
    await engine.networkDidChange(isReachable: false)
    await engine.enqueue(contentsOf: [capture("c1", sequence: 1), OutboxFixtures.create(member: "m1", note: "n1", sequence: 2)])
    await engine.start()

    await store.holdLoads()
    let foreground = Task { await engine.start() }
    let holding = await eventually { await store.heldLoadCount > 0 }
    XCTAssertTrue(holding)
    await engine.enqueue(capture("c2", sequence: 3))  // re-captured on site while the read is out
    await store.releaseLoads()
    await foreground.value

    await engine.networkDidChange(isReachable: true)
    await idle(engine)
    XCTAssertEqual(remote.calls.map(\.target), ["c1", "c2", "soap_notes/n1"])
  }

  func testARecordEnqueuedDuringTheStoreReadIsKept() async {
    let remote = FakeRemote()
    let store = ControllableStore()
    let engine = makeTestEngine(store: store, remote: remote)
    await engine.start()
    await store.holdLoads()
    let foreground = Task { await engine.start() }
    let holding = await eventually { await store.heldLoadCount > 0 }
    XCTAssertTrue(holding)
    let item = OutboxFixtures.create(member: "m1", note: "n1")
    await engine.enqueue(item)
    await store.releaseLoads()
    await foreground.value
    await idle(engine)
    XCTAssertEqual(remote.calls.map(\.target), ["soap_notes/n1"])
    let pending = await firstValue(of: await engine.pendingCount())
    XCTAssertEqual(pending, 0)
  }

  /// R3: a kill after the newer capture was acked but before the older rejected one was marked superseded.
  func testLoadSupersedesARejectedCaptureOlderThanAnAckedOne() async {
    let remote = FakeRemote()
    var c1 = capture("c1", sequence: 1)
    c1.state = .failed
    c1.attempts = 1
    c1.lastErrorCode = "permission-denied"
    var c2 = capture("c2", sequence: 2)
    c2.state = .acked
    c2.ack = .call
    let engine = makeTestEngine(store: ControllableStore([c1, c2]), remote: remote)
    await engine.start()
    let old = await engine.item(c1.id)
    XCTAssertEqual(old?.state, .superseded)
    await engine.retryAll()
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 0)
  }

  /// Only captures older than the newest acked one are superseded: a newer rejected capture stays retryable when the
  /// trainer later gets an older one through.
  func testANewerRejectedCaptureIsNotSupersededByAnOlderAck() async {
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote)
    remote.fail("c1", with: [.permissionDenied])
    remote.fail("c2", with: [.permissionDenied])
    let c1 = capture("c1", sequence: 1)
    let c2 = capture("c2", sequence: 2)
    await engine.enqueue(contentsOf: [c1, c2])
    await engine.start()
    await idle(engine)
    await engine.retry(c1.id)  // the trainer fixes the first capture
    await idle(engine)
    let newer = await engine.item(c2.id)
    XCTAssertEqual(newer?.state, .failed, "still the trainer's to retry")
    await engine.retry(c2.id)
    await idle(engine)
    XCTAssertEqual(remote.calls.map(\.target), ["c1", "c2", "c1", "c2"])
  }

  /// Review round 4 (m1): retrying a rejected capture while a newer one is in flight does not send it after the newer
  /// one; it is superseded when the newer one is acked.
  func testARetriedRejectionWaitsBehindANewerCaptureInFlight() async {
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote)
    remote.fail("c1", with: [.permissionDenied])
    let c1 = capture("c1", sequence: 1)
    await engine.enqueue(c1)
    await engine.start()
    await idle(engine)
    remote.hold("c2")
    await engine.enqueue(capture("c2", sequence: 2))
    let waiting = await eventually { remote.isWaiting(on: "c2") }
    XCTAssertTrue(waiting)
    await engine.retry(c1.id)  // the trainer taps retry on the old rejection
    remote.release("c2")
    await idle(engine)
    XCTAssertEqual(remote.calls.map(\.target), ["c1", "c2"])
    let old = await engine.item(c1.id)
    XCTAssertEqual(old?.state, .superseded)
    await engine.retry(c1.id)
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 2, "a superseded capture is never resent")
  }

  /// m4: a record put back to queued because its inFlight state could not be saved is stored blocked again while the
  /// member's latest capture is pending.
  func testARevertedRecordIsGatedAgainWhileANewerCaptureIsPending() async {
    let remote = FakeRemote()
    let store = ControllableStore()
    let engine = makeTestEngine(store: store, remote: remote)
    let record = OutboxFixtures.create(member: "m1", note: "n1", sequence: 1)
    await engine.enqueue(record)
    await store.failSaves { $0.id == record.id && $0.state == .inFlight }
    remote.hold("c-late")
    await engine.start()
    await engine.enqueue(capture("c-late", sequence: 2))  // arrives while the record's save fails
    await idle(engine)
    let reverted = await engine.item(record.id)
    XCTAssertEqual(reverted?.state, .blocked(.awaitingConsent))
    remote.release("c-late")
    await store.failSaves(where: nil)
    await engine.protectedDataDidBecomeAvailable()
    await idle(engine)
  }

  /// R5: retention deletes a row while the engine's save of it is running; the save must not bring it back, and the
  /// call it was about to make does not happen.
  func testAnUpdateInProgressDoesNotResurrectADeletedRow() async {
    let remote = FakeRemote()
    let store = ControllableStore()
    let engine = makeTestEngine(store: store, remote: remote)
    let item = OutboxFixtures.create(member: "m1", note: "n1")
    await engine.enqueue(item)  // inserted
    await store.holdSaves { $0.state == .inFlight }  // the update that records inFlight before the call
    await engine.start()
    let holding = await eventually { await store.heldCount > 0 }
    XCTAssertTrue(holding, "an update of the stored row is in progress")
    await store.remove([item.id])  // retention
    await engine.discard(ids: [item.id])
    await store.releaseSaves()
    await idle(engine)
    let resurrected = await store.item(item.id)
    XCTAssertNil(resurrected, "an update never re-inserts a deleted row")
    XCTAssertEqual(remote.calls.count, 0, "a discarded item is not sent")
  }
}

/// DF-104: the delete kinds reach the remote (document delete, and a stored binary's delete).
final class SyncEngineDeleteTests: XCTestCase {
  func testDeleteKindsAreSent() async {
    let remote = FakeRemote()
    remote.seedDocument("soap_notes/n1")
    let engine = makeTestEngine(remote: remote)
    await engine.enqueue(contentsOf: [
      OutboxItem(memberKey: .uid("m1"), entityRef: .soap(noteId: "n1"), sequence: 1, stage: .document,
                 kind: .deleteDocument, target: .document(path: "soap_notes/n1"), createdAt: OutboxFixtures.createdAt),
      OutboxItem(memberKey: .uid("m1"), entityRef: .soap(noteId: "n1"), sequence: 2, stage: .upload,
                 kind: .deleteBinary, target: .storage(path: "soapInk/n1/1.drawing"), createdAt: OutboxFixtures.createdAt),
    ])
    await engine.start()
    await idle(engine)
    XCTAssertEqual(remote.calls.map(\.kind), ["delete", "deleteBinary"])
    XCTAssertFalse(remote.hasDocument("soap_notes/n1"))
  }
}
