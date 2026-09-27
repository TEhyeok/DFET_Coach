import Foundation
import SyncEngine
import TrainerContracts
import TrainerDomain
import XCTest

/// Regression tests from the second PR #168 review: consent order and supersession, retention, gate persistence,
/// pause and save edge cases. All data is synthetic.
final class SyncEngineRound2Tests: XCTestCase {
  private func capture(_ name: String, member: String = "m1", sequence: Int64) -> OutboxItem {
    OutboxItem(memberKey: .uid(member), entityRef: .consent(captureId: name), sequence: sequence, stage: .consent,
               kind: .callConsent, target: .callable(name: name), payload: .object([:]),
               createdAt: OutboxFixtures.createdAt)
  }

  // MARK: N4 / R2 consent order: every capture is sent, in order

  func testAnOlderCaptureWaitingForRetryStillGoesBeforeTheRetake() async {
    let clock = TestClock()
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote, clock: clock)
    remote.fail("c1", with: [.unavailable])
    await engine.enqueue(capture("c1", sequence: 1))
    await engine.start()
    await idle(engine)
    await engine.enqueue(capture("c2", sequence: 2))  // the retake arrives during c1's backoff
    await idle(engine)
    XCTAssertEqual(remote.calls.map(\.target), ["c1"], "c2 waits for c1")
    clock.advance(by: 60)
    await idle(engine)
    XCTAssertEqual(remote.calls.map(\.target), ["c1", "c1", "c2"])
  }

  /// R2: captures are per-type changes. A grant followed by a withdrawal of one type must both reach the server, in
  /// that order, before the member's records go.
  func testAGrantAndALaterWithdrawalAreBothSentInOrder() async {
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote)
    await engine.networkDidChange(isReachable: false)
    await engine.enqueue(contentsOf: [
      capture("recordConsent-grant", sequence: 1),
      OutboxFixtures.create(member: "m1", note: "n1", sequence: 2),
      capture("recordConsent-withdraw-imaging", sequence: 3),
    ])
    await engine.start()
    await engine.networkDidChange(isReachable: true)
    await idle(engine)
    XCTAssertEqual(remote.calls.map(\.target), ["recordConsent-grant", "recordConsent-withdraw-imaging", "soap_notes/n1"])
  }

  func testExhaustedCapturesAreResentOldestFirst() async {
    let remote = FakeRemote()
    let onceOnly = RetryPolicy(maxAttempts: 1, maxDelay: 900, jitterFraction: 0.2)
    let engine = makeTestEngine(remote: remote, policy: onceOnly)
    remote.fail("c1", with: [.unavailable])
    await engine.enqueue(capture("c1", sequence: 1))
    await engine.start()
    await idle(engine)
    await engine.enqueue(capture("c2", sequence: 2))
    await idle(engine)
    XCTAssertEqual(remote.calls.map(\.target), ["c1"], "an exhausted older capture still holds the retake")
    await engine.networkDidChange(isReachable: true)
    await idle(engine)
    XCTAssertEqual(remote.calls.map(\.target), ["c1", "c1", "c2"])
  }

  func testARejectedCaptureIsSupersededOnceANewerOneIsAcked() async {
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote)
    remote.fail("c1", with: [.permissionDenied])
    let c1 = capture("c1", sequence: 1)
    await engine.enqueue(c1)
    await engine.start()
    await idle(engine)
    await engine.enqueue(capture("c2", sequence: 2))  // "다시 받기" after the rejection
    await idle(engine)
    let old = await engine.item(c1.id)
    XCTAssertEqual(old?.state, .superseded)
    await engine.retryAll()
    await engine.retryExhausted()
    await idle(engine)
    XCTAssertEqual(remote.calls.map(\.target), ["c1", "c2"], "never resent after the newer capture")
    let pending = await firstValue(of: await engine.pendingCount())
    XCTAssertEqual(pending, 0)
    let state = await firstValue(of: await engine.syncState(for: .consent(captureId: "c1")))
    XCTAssertEqual(state, .syncFailed, "a replaced capture does not read 기기에 저장됨")
  }

  func testAFailedCaptureThatIsNotTheLatestDoesNotBlockRecords() async {
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote)
    remote.fail("c1", with: [.permissionDenied])
    remote.hold("c1")
    await engine.enqueue(capture("c1", sequence: 1))
    await engine.start()
    let waiting = await eventually { remote.isWaiting(on: "c1") }
    XCTAssertTrue(waiting)
    await engine.enqueue(contentsOf: [capture("c2", sequence: 2), OutboxFixtures.create(member: "m1", note: "n1", sequence: 3)])
    remote.release("c1")
    await idle(engine)
    XCTAssertEqual(remote.calls.map(\.target), ["c1", "c2", "soap_notes/n1"])
  }

  // MARK: N3 retention and gate persistence

  func testRecordsAreStoredBlockedWhileTheCaptureIsPending() async {
    let remote = FakeRemote()
    let store = ControllableStore()
    let engine = makeTestEngine(store: store, remote: remote)
    remote.hold("recordConsent-m1")
    let steps = OutboxFixtures.soapSteps(member: "m1", note: "n1")
    await engine.enqueue(contentsOf: steps)
    for step in steps.dropFirst() {
      let stored = await store.item(step.id)
      XCTAssertEqual(stored?.state, .blocked(.awaitingConsent), "V1-05 §12.3: retention matches these rows")
    }
    await engine.start()
    remote.release("recordConsent-m1")
    await idle(engine)
    let last = await store.item(steps[4].id)
    XCTAssertEqual(last?.state, .acked)
  }

  func testDiscardedRowsAreNeitherSentNorSaved() async {
    let remote = FakeRemote()
    let store = ControllableStore()
    let engine = makeTestEngine(store: store, remote: remote)
    let steps = OutboxFixtures.soapSteps(member: "m1", note: "n1")
    await engine.enqueue(contentsOf: steps)
    let savesBefore = await store.savedIds.count
    await engine.discard(ids: steps.map(\.id))  // retention deleted the expired capture and its records
    await engine.start()
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 0)
    let savesAfter = await store.savedIds.count
    XCTAssertEqual(savesAfter, savesBefore, "no save of a deleted row")
  }

  func testStartDropsRowsThatRetentionDeletedWhileAway() async {
    let remote = FakeRemote()
    let store = ControllableStore()
    let engine = makeTestEngine(store: store, remote: remote)
    await engine.networkDidChange(isReachable: false)
    let steps = OutboxFixtures.soapSteps(member: "m1", note: "n1")
    await engine.enqueue(contentsOf: steps)
    await engine.start()
    await store.remove(steps.map(\.id))
    await engine.start()  // foreground after the purge
    await engine.networkDidChange(isReachable: true)
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 0)
  }

  func testLoadRederivesBlockedRecordsAfterAPartialFlush() async {
    let remote = FakeRemote()
    var steps = OutboxFixtures.soapSteps(member: "m1", note: "n1")
    steps[0].state = .inFlight
    for index in 1..<steps.count { steps[index].state = .blocked(.awaitingConsent) }
    let store = ControllableStore(steps)
    let engine = makeTestEngine(store: store, remote: remote)
    await engine.start()
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 5, "the consent is resent and acked, then the records go")
    let soap = await firstValue(of: await engine.syncState(for: .soap(noteId: "n1")))
    XCTAssertEqual(soap, .synced)
  }

  func testLoadReleasesRecordsLeftBlockedAfterTheConsentWasAcked() async {
    let remote = FakeRemote()
    var steps = OutboxFixtures.soapSteps(member: "m1", note: "n1")
    steps[0].state = .acked  // the consent ack was saved, the records' release was not (kill during a flush)
    steps[0].ack = .call
    for index in 1..<steps.count { steps[index].state = .blocked(.awaitingConsent) }
    let engine = makeTestEngine(store: ControllableStore(steps), remote: remote)
    await engine.start()
    await idle(engine)
    XCTAssertEqual(remote.calls.map(\.kind), ["create", "upload", "update", "update"])
  }

  func testAMissingConsentOutranksAFailedRecord() async {
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote)
    remote.fail("soap_notes/n1", with: [.permissionDenied])
    await engine.enqueue(OutboxFixtures.create(member: "m1", note: "n1", sequence: 1))
    await engine.start()
    await idle(engine)
    remote.hold("c-new")
    await engine.enqueue(capture("c-new", sequence: 2))
    let state = await firstValue(of: await engine.syncState(for: .soap(noteId: "n1")))
    XCTAssertEqual(state, .awaitingConsent, "AC-DF-015.6: an unconfirmed consent comes first")
    remote.release("c-new")
    await idle(engine)
  }

  // MARK: m2, m3, m5 and test gaps

  func testNoCallWhenTheInFlightStateCannotBeSaved() async {
    let remote = FakeRemote()
    let store = ControllableStore()
    let engine = makeTestEngine(store: store, remote: remote)
    await store.failSaves { $0.state == .inFlight }
    let item = OutboxFixtures.create(member: "m1", note: "n1")
    await engine.enqueue(item)
    await engine.start()
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 0)
    let reverted = await engine.item(item.id)
    XCTAssertEqual(reverted?.state, .queued)
    XCTAssertEqual(reverted?.attempts, 0)
  }

  func testAForegroundStartAlsoProtectsAgainstALateLockReply() async {
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote)
    remote.fail("soap_notes/n1", with: [.protectedDataUnavailable])
    remote.hold("soap_notes/n1")
    let item = OutboxFixtures.create(member: "m1", note: "n1")
    await engine.enqueue(item)
    await engine.start()
    let waiting = await eventually { remote.isWaiting(on: "soap_notes/n1") }
    XCTAssertTrue(waiting)
    await engine.start()  // back in the foreground: the device is unlocked
    remote.release("soap_notes/n1")
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 2)
  }

  func testARecordWaitingOnAFailedDependencyReadsSyncFailed() async {
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote)
    remote.fail("soap_notes/a", with: [.permissionDenied])
    let a = OutboxFixtures.create(member: "m1", note: "a")
    var b = OutboxFixtures.create(member: "m2", note: "b")
    b.dependsOn = [a.id]
    await engine.enqueue(contentsOf: [a, b])
    await engine.start()
    await idle(engine)
    let state = await firstValue(of: await engine.syncState(for: .soap(noteId: "b")))
    XCTAssertEqual(state, .syncFailed)
  }

  func testAnAckReleasesAnotherMembersDependentWhileTheFirstMemberIsStillBusy() async {
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote)
    remote.hold("soap_notes/x")
    let a = OutboxFixtures.create(member: "m1", note: "a", sequence: 1)
    let x = OutboxFixtures.create(member: "m1", note: "x", sequence: 2)
    var b = OutboxFixtures.create(member: "m2", note: "b", sequence: 1)
    b.dependsOn = [a.id]
    await engine.enqueue(contentsOf: [a, x, b])
    await engine.start()
    let released = await eventually { remote.calls(to: "soap_notes/b").count == 1 }
    XCTAssertTrue(released, "b starts as soon as a is acked, while m1 is still busy with x")
    remote.release("soap_notes/x")
    await idle(engine)
  }

  func testEnqueueResetsCallerSuppliedState() async {
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote)
    var item = OutboxFixtures.create(member: "m1", note: "n1")
    item.state = .inFlight
    item.attempts = 3
    await engine.enqueue(item)
    let stored = await engine.item(item.id)
    XCTAssertEqual(stored?.state, .queued)
    XCTAssertEqual(stored?.attempts, 0)
    await engine.start()
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 1)
  }
}
