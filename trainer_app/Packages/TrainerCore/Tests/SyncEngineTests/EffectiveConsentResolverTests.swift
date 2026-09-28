import Foundation
import SyncEngine
import TrainerContracts
import TrainerDomain
import XCTest

/// DF-111 MVP: `EffectiveConsentResolver` (TC-111-06 table, the confirmed-capture window, the per-member stream).
/// Synthetic values only.
final class EffectiveConsentResolverTests: XCTestCase {
  private typealias V = EffectiveConsentValue
  private let member = MemberKey.pending("SYNTHpending00000001")
  private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

  private func server(_ granted: [ConsentType]) -> ConsentState {
    ConsentState(entries: Dictionary(uniqueKeysWithValues: ConsentType.allCases.map {
      ($0, ConsentStateEntry(granted: granted.contains($0), documentVersion: "\($0.rawValue)--1.0"))
    }))
  }

  private func capture(
    _ types: [ConsentType], _ state: ConsentCaptureState, action: ConsentAction = .grant, at offset: TimeInterval = 0,
    confirmedAt: Date? = nil, id: String = UUID().uuidString.lowercased(), errorCode: String? = nil
  ) -> ConsentCapture {
    ConsentCapture(
      captureId: id, member: member,
      selections: types.map { ConsentSelection(consentType: $0, action: action, documentVersion: "\($0.rawValue)--1.0") },
      capturedAt: t0.addingTimeInterval(offset), state: state, confirmedAt: confirmedAt, lastErrorCode: errorCode)
  }

  // MARK: TC-111-06

  /// Server granted/not granted × local capture none/pending/failed, for each of ①②③ alone.
  func test_TC_111_06_serverTimesLocalCaptureTable() {
    enum Local { case none, pending, failed }
    let rows: [(serverGranted: Bool, local: Local, expected: V, UInt)] = [
      (true, .none, .granted, #line),
      (true, .pending, .granted, #line),
      (true, .failed, .granted, #line),
      (false, .none, .missing, #line),
      (false, .pending, .awaitingConsent, #line),
      (false, .failed, .rejected, #line),
    ]
    for type in ConsentFlowRules.coreTypes {
      for row in rows {
        let state = server(row.serverGranted ? [type] : [])
        let captures: [ConsentCapture]
        switch row.local {
        case .none: captures = []
        case .pending: captures = [capture([type], .pending)]
        case .failed: captures = [capture([type], .failed)]
        }
        let resolved = EffectiveConsentResolver.resolve(server: state, captures: captures, serverObservedAt: t0)
        XCTAssertEqual(resolved[type], row.expected, "\(type)", line: row.3)
        for other in ConsentFlowRules.coreTypes where other != type {
          XCTAssertEqual(resolved[other], .missing, "\(other) is untouched", line: row.3)
        }
      }
    }
  }

  /// Review: a capture that ran out of attempts on a transient error (a Functions outage, timeouts) is sent again by
  /// the engine (`retryExhausted()`, `holdsLaterCaptures`), so it still waits: '동의 확인 대기' and a local save, not a
  /// refusal. Only a code the engine never resends on its own is `rejected`.
  func testATransientFailureStillWaitsAndOnlyARefusalIsRejected() {
    let core = ConsentFlowRules.coreTypes
    for code in ["unavailable", "deadline-exceeded", "unknown"] {
      XCTAssertTrue(SyncEngine.transientErrorCodes.contains(code), code)
      let resolved = EffectiveConsentResolver.resolve(
        server: nil, captures: [capture(core, .failed, errorCode: code)], serverObservedAt: t0)
      XCTAssertEqual(resolved, EffectiveConsent(required: .awaitingConsent, healthData: .awaitingConsent,
                                                bodyImaging: .awaitingConsent), code)
      XCTAssertEqual(resolved.chipState, .awaiting, code)
      XCTAssertEqual(resolved.healthRecordSave, .localOnly, code)
    }
    for code in ["failed-precondition", "permission-denied", "not-found", "invalid-argument", "local-unreadable", nil] {
      let resolved = EffectiveConsentResolver.resolve(
        server: nil, captures: [capture(core, .failed, errorCode: code)], serverObservedAt: t0)
      XCTAssertEqual(resolved.healthData, .rejected, code ?? "nil")
      XCTAssertEqual(resolved.chipState, .needed, code ?? "nil")
      XCTAssertEqual(resolved.healthRecordSave, .blocked, code ?? "nil")
    }
    let granted = EffectiveConsentResolver.resolve(
      server: server(core), captures: [capture(core, .failed, errorCode: "unavailable")], serverObservedAt: t0)
    XCTAssertTrue(granted.coreGranted, "the server still decides once it granted")
  }

  /// No document at all reads like a document with nothing granted (the rules' `hasConsent`).
  func testNoServerDocumentIsNotGranted() {
    XCTAssertEqual(EffectiveConsentResolver.resolve(server: nil, captures: [], serverObservedAt: t0), .none)
    let resolved = EffectiveConsentResolver.resolve(
      server: nil, captures: [capture([.required, .healthData, .bodyImaging], .pending)], serverObservedAt: t0)
    XCTAssertEqual(resolved, EffectiveConsent(required: .awaitingConsent, healthData: .awaitingConsent,
                                              bodyImaging: .awaitingConsent))
    XCTAssertEqual(resolved.chipState, .awaiting, "AC-DF-111.6: '동의 확인 대기'")
  }

  /// ④⑤ are never resolved in the MVP, whatever the server or the captures say.
  func testSharingAndResearchStayMissing() {
    let resolved = EffectiveConsentResolver.resolve(
      server: server(ConsentType.allCases), captures: [capture([.sharing, .research], .pending)], serverObservedAt: t0)
    XCTAssertEqual(resolved[.sharing], .missing)
    XCTAssertEqual(resolved[.research], .missing)
    XCTAssertTrue(resolved.coreGranted)
  }

  /// The newest capture that selects a type decides it: a retake after a rejection waits again, a rejection after an
  /// older pending capture shows the rejection.
  func testTheNewestCaptureOfATypeDecides() {
    let retake = EffectiveConsentResolver.resolve(
      server: nil, captures: [capture([.healthData], .failed, at: 0), capture([.healthData], .pending, at: 60)],
      serverObservedAt: t0)
    XCTAssertEqual(retake.healthData, .awaitingConsent)
    let rejected = EffectiveConsentResolver.resolve(
      server: nil, captures: [capture([.healthData], .pending, at: 60), capture([.healthData], .failed, at: 120)],
      serverObservedAt: t0)
    XCTAssertEqual(rejected.healthData, .rejected)
    let otherType = EffectiveConsentResolver.resolve(
      server: nil, captures: [capture([.healthData], .failed, at: 0), capture([.bodyImaging], .pending, at: 60)],
      serverObservedAt: t0)
    XCTAssertEqual(otherType.healthData, .rejected, "a capture of another type does not replace it")
    XCTAssertEqual(otherType.bodyImaging, .awaitingConsent)
  }

  /// A withdrawal counts on the device at once (DF-112 reads the same value); a failed one leaves the server value.
  func testWithdrawals() {
    let granted = server([.required, .healthData, .bodyImaging])
    let pending = EffectiveConsentResolver.resolve(
      server: granted, captures: [capture([.bodyImaging], .pending, action: .withdraw)], serverObservedAt: t0)
    XCTAssertEqual(pending.bodyImaging, .missing)
    XCTAssertEqual(pending.healthData, .granted)
    let failed = EffectiveConsentResolver.resolve(
      server: granted, captures: [capture([.bodyImaging], .failed, action: .withdraw)], serverObservedAt: t0)
    XCTAssertEqual(failed.bodyImaging, .granted)
  }

  /// A confirmed capture defers to the server, but only once the server has been heard from after the confirmation:
  /// until then it still waits (the listener update may arrive after the callable's reply).
  func testAConfirmedCaptureWaitsForTheServerToCatchUp() {
    let confirmedAt = t0.addingTimeInterval(10)
    let confirmed = capture([.required, .healthData, .bodyImaging], .confirmed, confirmedAt: confirmedAt)
    let before = EffectiveConsentResolver.resolve(server: nil, captures: [confirmed], serverObservedAt: t0)
    XCTAssertEqual(before.chipState, .awaiting)
    let notHeard = EffectiveConsentResolver.resolve(server: nil, captures: [confirmed], serverObservedAt: nil)
    XCTAssertEqual(notHeard.chipState, .awaiting)
    let caughtUp = EffectiveConsentResolver.resolve(
      server: server([.required, .healthData, .bodyImaging]), captures: [confirmed],
      serverObservedAt: confirmedAt.addingTimeInterval(1))
    XCTAssertEqual(caughtUp.chipState, .coreGranted)
    let serverSaysOtherwise = EffectiveConsentResolver.resolve(
      server: server([.required]), captures: [confirmed], serverObservedAt: confirmedAt.addingTimeInterval(1))
    XCTAssertEqual(serverSaysOtherwise, EffectiveConsent(required: .granted, healthData: .missing, bodyImaging: .missing),
                   "the server is the truth once it has answered (e.g. a later withdrawal elsewhere)")
  }

  // MARK: Stream

  func testTheStreamWaitsForBothSourcesThenFollowsChanges() async {
    let states = FakeStates()
    let captures = FakeCaptures()
    let clock = MutableClock(t0)
    let resolver = EffectiveConsentResolver(server: states, captures: captures, now: { clock.now })
    let values = Collector(resolver.observe(member: member))

    captures.send([])
    try? await Task.sleep(nanoseconds: 50_000_000)
    XCTAssertEqual(values.all, [], "the server has not answered yet")

    states.send(.absent)
    let first = await eventually { values.all.count == 1 }
    XCTAssertTrue(first)
    XCTAssertEqual(values.all.last, EffectiveConsent.none)

    captures.send([capture([.required, .healthData, .bodyImaging], .pending)])
    let awaiting = await eventually { values.all.last?.chipState == .awaiting }
    XCTAssertTrue(awaiting)

    captures.send([capture([.required, .healthData, .bodyImaging], .pending)])  // resolves the same: not repeated
    clock.now = t0.addingTimeInterval(5)
    states.send(.present(server([.required, .healthData, .bodyImaging])))
    let granted = await eventually { values.all.last?.chipState == .coreGranted }
    XCTAssertTrue(granted)
    XCTAssertEqual(values.all.map(\.chipState), [.needed, .awaiting, .coreGranted])
    values.cancel()
  }

  /// A pending member's listener fails until the member's document is on the server (the rules cannot read it yet).
  /// The next change of the local captures (the capture is confirmed) subscribes again.
  func testAnEndedServerStreamIsSubscribedAgainAfterTheCapturesChange() async {
    let states = FakeStates()
    let captures = FakeCaptures()
    let clock = MutableClock(t0)
    let resolver = EffectiveConsentResolver(server: states, captures: captures, now: { clock.now },
                                            retryDelay: { _ in 3600 })
    let values = Collector(resolver.observe(member: member))
    let id = "3f2b8c1e-5d7a-4b1e-9a51-0c8e2d7f1a90"

    captures.send([capture([.required, .healthData, .bodyImaging], .pending, id: id)])
    states.fail()  // permission denied before the pendingMembers create is acked
    let awaiting = await eventually { values.all.last?.chipState == .awaiting }
    XCTAssertTrue(awaiting)
    XCTAssertEqual(states.subscriptions, 1)

    clock.now = t0.addingTimeInterval(10)
    captures.send([capture([.required, .healthData, .bodyImaging], .confirmed, confirmedAt: clock.now, id: id)])
    let resubscribed = await eventually { states.subscriptions == 2 }
    XCTAssertTrue(resubscribed)
    XCTAssertEqual(values.all.last?.chipState, .awaiting, "confirmed, but the server has not answered since")

    clock.now = t0.addingTimeInterval(11)
    states.send(.present(server([.required, .healthData, .bodyImaging])))
    let granted = await eventually { values.all.last?.chipState == .coreGranted }
    XCTAssertTrue(granted)
    values.cancel()
  }

  /// Review (V1-06 §8.10, P1a DF-110): a listener refused before the member's `pendingMembers` create reached the
  /// server is `unavailable`, not "no document". Nothing counts as granted, but a capture the device already knows is
  /// confirmed still waits instead of reading '동의 필요', and the server is read again after the retry delay, without
  /// any capture change: once the create is acked the state arrives.
  func testARefusedListenerIsUnknownAndIsSubscribedAgainAfterTheRetryDelay() async {
    let states = FakeStates()
    let captures = FakeCaptures()
    let clock = MutableClock(t0)
    let resolver = EffectiveConsentResolver(server: states, captures: captures, now: { clock.now },
                                            retryDelay: { _ in 0.05 })
    let values = Collector(resolver.observe(member: member))
    let core = ConsentFlowRules.coreTypes

    captures.send([capture(core, .confirmed, confirmedAt: t0.addingTimeInterval(-60))])
    states.fail()
    let awaiting = await eventually { values.all.last?.chipState == .awaiting }
    XCTAssertTrue(awaiting, "a confirmed capture is not '동의 필요' while the server is unknown")
    XCTAssertFalse(values.all.contains { $0.chipState == .needed })
    XCTAssertEqual(values.all.last?.canAttachPhoto, false)

    states.fail()  // the retry is refused too: it keeps retrying
    let retried = await eventually { states.subscriptions >= 3 }
    XCTAssertTrue(retried)
    states.send(.present(server(core)))
    let granted = await eventually { values.all.last?.chipState == .coreGranted }
    XCTAssertTrue(granted)
    values.cancel()
  }

  /// A listener that fails after it answered keeps its last reading (it is not "no document") and is read again.
  func testAListenerThatFailsAfterAnsweringKeepsItsLastReading() async {
    let states = FakeStates()
    let captures = FakeCaptures()
    let resolver = EffectiveConsentResolver(server: states, captures: captures, now: { Date() },
                                            retryDelay: { _ in 0.05 })
    let values = Collector(resolver.observe(member: member))
    captures.send([])
    states.send(.present(server(ConsentFlowRules.coreTypes)))
    let granted = await eventually { values.all.last?.coreGranted == true }
    XCTAssertTrue(granted)

    states.fail()
    let resubscribed = await eventually { states.subscriptions == 2 }
    XCTAssertTrue(resubscribed)
    XCTAssertEqual(values.all.map(\.chipState), [.coreGranted], "never '동의 필요' on a listener failure")
    values.cancel()
  }
}

// MARK: - Fakes

/// A `ConsentStateSource` driven by the test. Each `observe` is a new subscription; `fail()` ends the current one with
/// `.unavailable`, as a failed Firestore listener does.
private final class FakeStates: ConsentStateSource, @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: AsyncStream<ConsentStateReading>.Continuation?
  private var buffered: [ConsentStateReading] = []
  private var failBuffered = false
  private var _subscriptions = 0
  var subscriptions: Int { lock.withLock { _subscriptions } }

  func observe(member: MemberKey) -> AsyncStream<ConsentStateReading> {
    AsyncStream { continuation in
      lock.withLock {
        _subscriptions += 1
        buffered.forEach { continuation.yield($0) }
        buffered = []
        if failBuffered {
          failBuffered = false
          continuation.yield(.unavailable)
          continuation.finish()
        } else {
          self.continuation = continuation
        }
      }
    }
  }

  func send(_ reading: ConsentStateReading) {
    lock.withLock {
      if let continuation { continuation.yield(reading) } else { buffered.append(reading) }
    }
  }

  /// Ends the current subscription, or the next one when none is open yet.
  func fail() {
    lock.withLock {
      if let continuation {
        continuation.yield(.unavailable)
        continuation.finish()
        self.continuation = nil
      } else {
        failBuffered = true
      }
    }
  }
}

private final class FakeCaptures: ConsentCaptureSource, @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: AsyncStream<[ConsentCapture]>.Continuation?
  private var buffered: [[ConsentCapture]] = []

  func observeCaptures(member: MemberKey) -> AsyncStream<[ConsentCapture]> {
    AsyncStream { continuation in
      lock.withLock {
        self.continuation = continuation
        buffered.forEach { continuation.yield($0) }
        buffered = []
      }
    }
  }

  func send(_ captures: [ConsentCapture]) {
    lock.withLock {
      if let continuation { continuation.yield(captures) } else { buffered.append(captures) }
    }
  }
}

private final class MutableClock: @unchecked Sendable {
  private let lock = NSLock()
  private var current: Date
  init(_ start: Date) { current = start }
  var now: Date {
    get { lock.withLock { current } }
    set { lock.withLock { current = newValue } }
  }
}

/// Collects a stream's values in the background.
private final class Collector<T: Sendable>: @unchecked Sendable {
  private let lock = NSLock()
  private var values: [T] = []
  private var task: Task<Void, Never>?

  init(_ stream: AsyncStream<T>) {
    task = Task { [weak self] in
      for await value in stream { self?.append(value) }
    }
  }

  private func append(_ value: T) { lock.withLock { values.append(value) } }
  var all: [T] { lock.withLock { values } }
  func cancel() { task?.cancel() }
}
