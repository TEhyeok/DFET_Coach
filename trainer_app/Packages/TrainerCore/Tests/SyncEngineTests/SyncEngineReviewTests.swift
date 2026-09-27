import Foundation
import SyncEngine
import TrainerContracts
import TrainerDomain
import XCTest

/// Regression tests from the PR #168 adversarial review: re-entrancy, member gates, pauses, load and enqueue rules.
/// All data is synthetic.
final class SyncEngineReviewTests: XCTestCase {
  // MARK: re-entrancy (M1)

  func testRetryWhileTheFailedConsentIsBeingSavedDoesNotStrandRecords() async {
    let remote = FakeRemote()
    let store = ControllableStore()
    let engine = makeTestEngine(store: store, remote: remote)
    remote.fail("recordConsent-m1", with: [.permissionDenied])
    let steps = OutboxFixtures.soapSteps(member: "m1", note: "n1")
    await engine.enqueue(contentsOf: steps)
    await store.holdSaves { $0.state == .failed }
    await engine.start()

    let heldFailure = await eventually { await store.heldCount > 0 }
    XCTAssertTrue(heldFailure)
    let retry = Task { await engine.retry(steps[0].id) }  // the trainer taps retry while the save is pending
    let retryApplied = await eventually { await engine.item(steps[0].id)?.state != .failed }
    XCTAssertTrue(retryApplied)
    await store.releaseSaves()
    await retry.value
    await idle(engine)

    for step in steps {
      let item = await engine.item(step.id)
      XCTAssertEqual(item?.state, .acked, "\(step.kind)")
    }
    XCTAssertEqual(remote.calls.map(\.kind), ["call", "call", "create", "upload", "update", "update"])
  }

  // MARK: member gates (M2, M3)

  func testAFailedRecordDoesNotHoldBackTheMembersOtherRecords() async {
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote)
    remote.fail("soap_notes/nA", with: [.invalidArgument])
    await engine.enqueue(contentsOf: [
      OutboxFixtures.create(member: "m1", note: "nA", sequence: 1),
      OutboxFixtures.create(member: "m1", note: "nB", sequence: 2),
    ])
    await engine.start()
    await idle(engine)

    let stateA = await firstValue(of: await engine.syncState(for: .soap(noteId: "nA")))
    let stateB = await firstValue(of: await engine.syncState(for: .soap(noteId: "nB")))
    XCTAssertEqual(stateA, .syncFailed)
    XCTAssertEqual(stateB, .synced)
  }

  func testANewConsentCaptureReleasesRecordsAfterAFailedCapture() async {
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote)
    remote.fail("recordConsent-m1", with: [.invalidArgument])
    let steps = OutboxFixtures.soapSteps(member: "m1", note: "n1")
    await engine.enqueue(contentsOf: steps)
    await engine.start()
    await idle(engine)
    let blocked = await engine.item(steps[1].id)
    XCTAssertEqual(blocked?.state, .blocked(.awaitingConsent))

    let retake = OutboxItem(
      memberKey: .uid("m1"), entityRef: .consent(captureId: "cap-m1-retake"), sequence: 10, stage: .consent,
      kind: .callConsent, target: .callable(name: "recordConsent-m1-retake"), payload: .object([:]),
      createdAt: OutboxFixtures.createdAt)
    await engine.enqueue(retake)
    await idle(engine)

    XCTAssertEqual(remote.calls.map(\.target), [
      "recordConsent-m1", "recordConsent-m1-retake", "soap_notes/n1", "soapInk/n1/1.drawing", "soap_notes/n1",
      "soap_notes/n1",
    ])
    let soap = await firstValue(of: await engine.syncState(for: .soap(noteId: "n1")))
    XCTAssertEqual(soap, .synced)
  }

  func testARecordWithALowerSequenceStillWaitsForTheConsent() async {
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote)
    let record = OutboxFixtures.create(member: "m1", note: "n1", sequence: 1)
    var consent = OutboxFixtures.soapSteps(member: "m1", note: "unused")[0]
    consent = OutboxItem(
      id: consent.id, memberKey: consent.memberKey, entityRef: consent.entityRef, sequence: 2, stage: .consent,
      kind: .callConsent, target: consent.target, payload: consent.payload, createdAt: consent.createdAt)
    await engine.enqueue(contentsOf: [record, consent])
    await engine.start()
    await idle(engine)
    XCTAssertEqual(remote.calls.map(\.kind), ["call", "create"])
  }

  func testRecordsShowAwaitingConsentWhileTheCaptureIsInFlight() async {
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote)
    remote.hold("recordConsent-m1")
    await engine.enqueue(contentsOf: OutboxFixtures.soapSteps(member: "m1", note: "n1"))
    await engine.start()
    let waiting = await eventually { remote.isWaiting(on: "recordConsent-m1") }
    XCTAssertTrue(waiting)
    let soap = await firstValue(of: await engine.syncState(for: .soap(noteId: "n1")))
    XCTAssertEqual(soap, .awaitingConsent)
    remote.release("recordConsent-m1")
    await idle(engine)
  }

  func testASyncedRecordStaysSyncedWhenANewCaptureStarts() async {
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote)
    await engine.enqueue(contentsOf: OutboxFixtures.soapSteps(member: "m1", note: "n1"))
    await engine.start()
    await idle(engine)
    remote.hold("recordConsent-m1-new")
    await engine.enqueue(OutboxItem(
      memberKey: .uid("m1"), entityRef: .consent(captureId: "cap-new"), sequence: 20, stage: .consent,
      kind: .callConsent, target: .callable(name: "recordConsent-m1-new"), payload: .object([:]),
      createdAt: OutboxFixtures.createdAt))
    let soap = await firstValue(of: await engine.syncState(for: .soap(noteId: "n1")))
    XCTAssertEqual(soap, .synced)
    remote.release("recordConsent-m1-new")
    await idle(engine)
  }

  // MARK: pauses and loading (M4, M5, m7)

  func testALockReplyThatArrivesAfterTheUnlockDoesNotPause() async {
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote)
    remote.fail("soap_notes/n1", with: [.protectedDataUnavailable])
    remote.hold("soap_notes/n1")
    let item = OutboxFixtures.create(member: "m1", note: "n1")
    await engine.enqueue(item)
    await engine.start()
    let waiting = await eventually { remote.isWaiting(on: "soap_notes/n1") }
    XCTAssertTrue(waiting)
    await engine.protectedDataDidBecomeAvailable()  // unlock is processed before the late reply
    remote.release("soap_notes/n1")
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 2)
    let done = await engine.item(item.id)
    XCTAssertEqual(done?.state, .acked)
  }

  func testNothingIsSentUntilALoadSucceedsAndMemberOrderHolds() async {
    let remote = FakeRemote()
    let old = OutboxFixtures.create(member: "m1", note: "old", sequence: 1)
    let store = ControllableStore([old], failingLoads: 1)
    let engine = makeTestEngine(store: store, remote: remote)
    await engine.start()  // load fails (device locked)
    await engine.enqueue(OutboxFixtures.create(member: "m1", note: "new", sequence: 2))
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 0, "not started while the Outbox could not be loaded")

    await engine.start()
    await idle(engine)
    XCTAssertEqual(remote.calls.map(\.target), ["soap_notes/old", "soap_notes/new"])
  }

  func testAFailedLocalSavePausesUntilUnlock() async {
    let remote = FakeRemote()
    let store = ControllableStore()
    let engine = makeTestEngine(store: store, remote: remote)
    await engine.start()
    await store.setFailSaves(true)
    let item = OutboxFixtures.create(member: "m1", note: "n1")
    await engine.enqueue(item)
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 0, "nothing is sent while its state cannot be saved")

    await store.setFailSaves(false)
    await engine.protectedDataDidBecomeAvailable()
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 1)
    let saved = await store.item(item.id)
    XCTAssertEqual(saved?.state, .acked)
  }

  // MARK: enqueue, writes, retries (M6, M7, M8)

  func testReenqueueingAKnownIdIsIgnored() async {
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote)
    let item = OutboxFixtures.create(member: "m1", note: "n1")
    await engine.enqueue(item)
    await engine.start()
    await idle(engine)
    var changed = item
    changed.payload = .object(["status": .string("changed")])
    await engine.enqueue(changed)
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 1)
    let kept = await engine.item(item.id)
    XCTAssertEqual(kept?.payload, item.payload)
    XCTAssertEqual(kept?.state, .acked)
  }

  func testAnUncommittedWriteIsRetriedAndHoldsTheNextStep() async {
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote)
    remote.markWriteUncommitted("soap_notes/n1")
    let steps = OutboxFixtures.soapSteps(member: "m1", note: "n1")
    await engine.enqueue(contentsOf: steps)
    await engine.start()
    await idle(engine)
    let create = await engine.item(steps[1].id)
    XCTAssertEqual(create?.state, .queued)
    XCTAssertEqual(create?.lastErrorCode, "write-uncommitted")
    XCTAssertTrue(remote.calls(to: "soapInk/n1/1.drawing").isEmpty, "no upload on an unconfirmed parent")
  }

  func testAutomaticRetryResendsOnlyTransientFailures() async {
    let remote = FakeRemote()
    let onceOnly = RetryPolicy(maxAttempts: 1, maxDelay: 900, jitterFraction: 0.2)
    let engine = makeTestEngine(remote: remote, policy: onceOnly)
    remote.fail("soap_notes/denied", with: [.permissionDenied])
    remote.fail("soap_notes/flaky", with: [.unavailable])
    await engine.enqueue(contentsOf: [
      OutboxFixtures.create(member: "m1", note: "denied"),
      OutboxFixtures.create(member: "m2", note: "flaky"),
    ])
    await engine.start()
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 2)

    await engine.retryExhausted()
    await idle(engine)
    XCTAssertEqual(remote.calls(to: "soap_notes/flaky").count, 2)
    XCTAssertEqual(remote.calls(to: "soap_notes/denied").count, 1, "a rule rejection waits for the trainer")

    await engine.retryAll()
    await idle(engine)
    XCTAssertEqual(remote.calls(to: "soap_notes/denied").count, 2, "the trainer's retry resends it")
  }

  func testOfflineHoldsCallsAndReconnectResumes() async {
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote)
    await engine.start()
    await engine.networkDidChange(isReachable: false)
    await engine.enqueue(OutboxFixtures.create(member: "m1", note: "n1"))
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 0)
    await engine.networkDidChange(isReachable: true)
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 1)
  }

  // MARK: scheduling (m1, m2, m3)

  func testAtMostTwoMembersRunAndTheThirdStartsWhenOneFinishes() async {
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote)
    for member in ["m1", "m2", "m3"] {
      remote.hold("recordConsent-\(member)")
      await engine.enqueue(contentsOf: OutboxFixtures.soapSteps(member: member, note: "n-\(member)"))
    }
    await engine.start()
    let two = await eventually { remote.waitingCount == 2 }
    XCTAssertTrue(two)
    try? await Task.sleep(nanoseconds: 100_000_000)
    XCTAssertEqual(remote.waitingCount, 2, "a third member must not start")
    XCTAssertEqual(remote.calls.count, 2)

    let first = remote.calls[0].target
    remote.release(first)
    let third = await eventually { remote.calls.filter { $0.kind == "call" }.count == 3 }
    XCTAssertTrue(third, "the third member starts when a slot frees")
    for member in ["m1", "m2", "m3"] { remote.release("recordConsent-\(member)") }
    await idle(engine)
    XCTAssertEqual(remote.maxConcurrent, 2)
  }

  func testTheBackoffWakeupSendsWithoutAnyOtherTrigger() async {
    let clock = TestClock()
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote, clock: clock)
    remote.fail("soap_notes/n1", with: [.unavailable])
    await engine.enqueue(OutboxFixtures.create(member: "m1", note: "n1"))
    await engine.start()
    await idle(engine)
    XCTAssertEqual(remote.calls.count, 1)
    clock.advance(by: 2)
    let resent = await eventually { remote.calls.count == 2 }
    XCTAssertTrue(resent, "only the scheduled wakeup can send this")
  }

  func testPendingCountIncludesFailedItems() async {
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote)
    remote.fail("soap_notes/n1", with: [.permissionDenied])
    await engine.enqueue(OutboxFixtures.create(member: "m1", note: "n1"))
    await engine.start()
    await idle(engine)
    let count = await firstValue(of: await engine.pendingCount())
    XCTAssertEqual(count, 1)
  }

  func testABatchOnARunningEngineKeepsSequenceOrder() async {
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote)
    await engine.start()
    await engine.enqueue(contentsOf: OutboxFixtures.soapSteps(member: "m1", note: "n1").reversed())
    await idle(engine)
    XCTAssertEqual(remote.calls.map(\.kind), ["call", "create", "upload", "update", "update"])
  }

  func testCallablesCarryTheIdempotencyKey() async {
    let remote = FakeRemote()
    let engine = makeTestEngine(remote: remote)
    let steps = OutboxFixtures.soapSteps(member: "m1", note: "n1")
    await engine.enqueue(contentsOf: steps)
    await engine.start()
    await idle(engine)
    XCTAssertEqual(
      remote.payloads(to: "recordConsent-m1").first,
      .object(["clientCaptureId": .string(steps[0].requestId.uuidString.lowercased())]))
  }
}
