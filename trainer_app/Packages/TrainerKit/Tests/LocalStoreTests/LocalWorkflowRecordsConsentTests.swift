import Foundation
import SwiftData
import SyncEngine
import TrainerContracts
import TrainerDomain
import XCTest
@testable import LocalStore

/// TR-03/TR-11 history reads one stream; it shows health records only while consent ② allows it.
@MainActor
final class LocalWorkflowRecordsConsentTests: XCTestCase {
  private let member = MemberKey.pending("SYNTHpending00000001")
  private let otherMember = MemberKey.pending("SYNTHpending00000002")
  private let versions: [ConsentType: String] = [
    .required: "required--test-1", .healthData: "healthData--test-1", .bodyImaging: "bodyImaging--test-1",
  ]
  private var selections: [ConsentSelection] {
    ConsentFlowRules.coreTypes.map { ConsentSelection(type: $0, granted: true) }
  }
  private var draft: BodyCompositionDraft {
    BodyCompositionDraft(values: [.weightKg: "65"], deviceModel: "Synthetic device", measuredAt: Synthetic.now,
                         fasting: .yes, heightCmInput: "170")
  }
  private var serverRecord: BodyCompositionRecord {
    BodyCompositionRecord(id: "SYNTHserverRecord0001", member: member, deviceModel: "Synthetic device",
      measuredAt: Synthetic.now.addingTimeInterval(-86_400), fasting: nil, timeOfDayBand: nil,
      source: "manualEntry", sourceGrade: nil, values: [.weightKg: 64], derived: nil, status: nil)
  }

  func testRejectedConsentHidesARetainedLocalDraft() async throws {
    let store = try makeStore()
    let records = ServerRecordsFeed(snapshot: [serverRecord])
    let workflow = service(store: store, states: ServerConsentFeed(initial: nil), measurements: records)
    try await workflow.captureInPerson(member: member, selections: selections, documentVersions: versions)
    let draftID = try await workflow.saveBodyComposition(member: member, draft: draft)
    let probe = RecordsProbe()
    let shown = probe.expect("the draft is visible while ② waits for the server") { $0 == [draftID] }
    let observer = observe(workflow, into: probe)
    defer { observer.cancel() }
    await fulfillment(of: [shown], timeout: 2)

    let hidden = probe.expect("recordConsent rejection hides the retained draft") { $0.isEmpty }
    let queued = try await store.loadAll()
    var capture = try XCTUnwrap(queued.first { $0.kind == .callConsent })
    capture.state = .failed
    capture.lastErrorCode = "failed-precondition"
    try await store.update(capture)
    await fulfillment(of: [hidden], timeout: 2)

    let restored = probe.expect("a later local change must not restore records") { !$0.isEmpty }
    restored.isInverted = true
    // Bypasses the service's save gate: even a new local draft for the member stays hidden.
    _ = try await store.saveMeasurement(member: member, draft: draft, now: Synthetic.now)
    await fulfillment(of: [restored], timeout: 0.3)
    XCTAssertEqual(records.started, 0, "No server listener without a server grant of ②")
    XCTAssertNil(probe.failure)
  }

  func testWithdrawalAfterGrantClearsServerRecords() async throws {
    let store = try makeStore()
    let consent = ServerConsentFeed(initial: serverState(healthData: true))
    let records = ServerRecordsFeed(snapshot: [serverRecord])
    let workflow = service(store: store, states: consent, measurements: records)
    let probe = RecordsProbe()
    let shown = probe.expect("server record shown under a server grant") { $0 == [self.serverRecord.id] }
    let observer = observe(workflow, into: probe)
    defer { observer.cancel() }
    await fulfillment(of: [shown], timeout: 2)
    XCTAssertEqual(records.started, 1)

    let cleared = probe.expect("withdrawal clears the server records") { $0.isEmpty }
    consent.send(serverState(healthData: false))
    await fulfillment(of: [cleared], timeout: 2)

    let restored = probe.expect("a local change must not bring back cached server records") { !$0.isEmpty }
    restored.isInverted = true
    _ = try await store.saveConsent(member: otherMember, selections: selections, versions: versions, now: Synthetic.now)
    await fulfillment(of: [restored], timeout: 0.3)
    XCTAssertEqual(records.started, 1, "Withdrawal must not start another listener")
    XCTAssertEqual(records.cancelled, 1, "Withdrawal cancels the server listener")
    XCTAssertNil(probe.failure, "The cancelled listener's CancellationError is not a load failure")
  }

  func testAwaitingConsentShowsLocalDraftsOnly() async throws {
    let store = try makeStore()
    let records = ServerRecordsFeed(snapshot: [serverRecord])
    let workflow = service(store: store, states: ServerConsentFeed(initial: nil), measurements: records)
    try await workflow.captureInPerson(member: member, selections: selections, documentVersions: versions)
    let draftID = try await workflow.saveBodyComposition(member: member, draft: draft)
    let probe = RecordsProbe()
    let shown = probe.expect("the local draft is shown") { $0 == [draftID] }
    let leaked = probe.expect("server records stay hidden while ② waits for the server") {
      $0.contains(self.serverRecord.id)
    }
    leaked.isInverted = true
    let observer = observe(workflow, into: probe)
    defer { observer.cancel() }
    await fulfillment(of: [shown], timeout: 2)
    _ = try await store.saveConsent(member: otherMember, selections: selections, versions: versions, now: Synthetic.now)
    await fulfillment(of: [leaked], timeout: 0.3)
    XCTAssertEqual(records.started, 0, "No server listener while ② only waits for the server")
    XCTAssertNil(probe.failure)
  }

  func testRegrantRestoresServerAndLocalRecords() async throws {
    let store = try makeStore()
    let consent = ServerConsentFeed(initial: serverState(healthData: true))
    let records = ServerRecordsFeed(snapshot: [serverRecord])
    let workflow = service(store: store, states: consent, measurements: records)
    let draftID = try await workflow.saveBodyComposition(member: member, draft: draft)
    let both = Set([draftID, serverRecord.id])
    let probe = RecordsProbe()
    let shown = probe.expect("server and local records under a grant") { Set($0) == both }
    let observer = observe(workflow, into: probe)
    defer { observer.cancel() }
    await fulfillment(of: [shown], timeout: 2)

    let cleared = probe.expect("withdrawal hides both") { $0.isEmpty }
    consent.send(serverState(healthData: false))
    await fulfillment(of: [cleared], timeout: 2)

    let restored = probe.expect("a new grant restores both") { Set($0) == both }
    consent.send(serverState(healthData: true))
    await fulfillment(of: [restored], timeout: 2)
    XCTAssertEqual(records.started, 2, "The new grant starts a new server listener")
    XCTAssertNil(probe.failure)
  }

  func testServerListenerFailureUnderGrantStillFailsTheStream() async throws {
    let store = try makeStore()
    let records = ServerRecordsFeed(snapshot: [], failure: SyntheticListenerError())
    let workflow = service(store: store, states: ServerConsentFeed(initial: serverState(healthData: true)),
                           measurements: records)
    let probe = RecordsProbe()
    let failed = probe.expectFailure()
    let observer = observe(workflow, into: probe)
    defer { observer.cancel() }
    await fulfillment(of: [failed], timeout: 2)
    XCTAssertTrue(probe.failure is SyntheticListenerError)
  }

  private func serverState(healthData: Bool) -> ConsentState {
    ConsentState(entries: Dictionary(uniqueKeysWithValues: versions.map {
      ($0.key, ConsentStateEntry(granted: $0.key != .healthData || healthData, documentVersion: $0.value))
    }))
  }

  private func observe(_ workflow: LocalWorkflowService, into probe: RecordsProbe) -> Task<Void, Never> {
    let member = member
    return Task { @MainActor in
      do {
        for try await records in workflow.observeBodyCompositionRecords(member: member, since: .distantPast) {
          probe.receive(records.map(\.id))
        }
      } catch { probe.fail(error) }
    }
  }

  private func makeStore() throws -> LocalOutboxStore {
    LocalOutboxStore(container: try LocalStoreContainer.make(inMemory: true), trainerUid: Synthetic.trainerA, binaries: nil)
  }

  private func service(store: LocalOutboxStore, states: any ConsentStateSource,
                       measurements: any MeasurementRecordsSource) -> LocalWorkflowService {
    let remote = RecordsNoopRemote()
    let engine = SyncEngine(store: store, writer: remote, uploader: remote, callable: remote)
    let empty = RecordsEmptySources()
    return LocalWorkflowService(outbox: store, engine: engine, documents: empty, states: states,
      measurements: measurements, assigned: empty, pending: empty, now: { Synthetic.now })
  }
}

/// Collects what the records stream yields; each expectation waits for the next matching yield.
@MainActor
private final class RecordsProbe {
  private var waiters: [(matches: ([String]) -> Bool, expectation: XCTestExpectation)] = []
  private var failureWaiter: XCTestExpectation?
  private(set) var failure: Error?

  func expect(_ description: String, _ matches: @escaping ([String]) -> Bool) -> XCTestExpectation {
    let expectation = XCTestExpectation(description: description)
    waiters.append((matches, expectation))
    return expectation
  }

  func expectFailure() -> XCTestExpectation {
    let expectation = XCTestExpectation(description: "stream failed")
    failureWaiter = expectation
    return expectation
  }

  func receive(_ ids: [String]) {
    waiters.removeAll { waiter in
      guard waiter.matches(ids) else { return false }
      waiter.expectation.fulfill()
      return true
    }
  }

  func fail(_ error: Error) {
    failure = error
    failureWaiter?.fulfill()
  }
}

private struct SyntheticListenerError: Error {}

/// Server consent state like a Firestore listener: every reader first gets the latest state, then every change.
private final class ServerConsentFeed: ConsentStateSource, @unchecked Sendable {
  private let lock = NSLock()
  private var latest: ConsentState?
  private var readers: [UUID: AsyncStream<ConsentState?>.Continuation] = [:]

  init(initial: ConsentState?) { latest = initial }

  func observe(member: MemberKey) -> AsyncStream<ConsentState?> {
    AsyncStream { continuation in
      let id = UUID()
      lock.withLock {
        readers[id] = continuation
        continuation.yield(latest)
      }
      continuation.onTermination = { [weak self] _ in
        guard let self else { return }
        self.lock.withLock { _ = self.readers.removeValue(forKey: id) }
      }
    }
  }

  func send(_ state: ConsentState?) {
    lock.withLock {
      latest = state
      readers.values.forEach { $0.yield(state) }
    }
  }
}

/// Server records like a live listener: one snapshot, then waiting until the reader is cancelled, which throws
/// `CancellationError` (or `failure` on the first read).
private final class ServerRecordsFeed: MeasurementRecordsSource, @unchecked Sendable {
  private let lock = NSLock()
  private let snapshot: [BodyCompositionRecord]
  private let failure: Error?
  private var starts = 0
  private var cancels = 0
  var started: Int { lock.withLock { starts } }
  var cancelled: Int { lock.withLock { cancels } }

  init(snapshot: [BodyCompositionRecord], failure: Error? = nil) {
    self.snapshot = snapshot
    self.failure = failure
  }

  func records(member: MemberKey, since: Date) -> AsyncThrowingStream<[BodyCompositionRecord], Error> {
    lock.withLock { starts += 1 }
    let listener = Listener(feed: self)
    return AsyncThrowingStream(unfolding: { try await listener.next() })
  }

  private final class Listener: @unchecked Sendable {
    private let feed: ServerRecordsFeed
    private var delivered = false
    init(feed: ServerRecordsFeed) { self.feed = feed }

    func next() async throws -> [BodyCompositionRecord]? {
      if let failure = feed.failure { throw failure }
      if !delivered {
        delivered = true
        return feed.snapshot
      }
      do { try await Task.sleep(nanoseconds: 60_000_000_000) } catch {
        feed.lock.withLock { feed.cancels += 1 }
        throw error
      }
      return nil
    }
  }
}

private struct RecordsEmptySources: ConsentDocumentsSource, MemberDirectory {
  func publishedDocuments() async throws -> [ConsentDocumentVersion] { [] }
  func observeAssignedMembers() -> AsyncThrowingStream<[Member], Error> {
    AsyncThrowingStream { $0.yield([]); $0.finish() }
  }
}

private struct RecordsNoopRemote: RemoteWriter, BinaryUploader, CallableClient {
  func createIfAbsent(path: String, fields: JSONValue) async throws -> WriteAck { WriteAck(serverCommitted: true) }
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
