import Foundation
import SwiftData
import SyncEngine
import TrainerContracts
import TrainerDomain
import XCTest
@testable import LocalStore

@MainActor
final class LocalWorkflowConsentObservationTests: XCTestCase {
  private let member = MemberKey.pending("SYNTHpending00000001")
  private let versions: [ConsentType: String] = [
    .required: "required--test-1", .healthData: "healthData--test-1", .bodyImaging: "bodyImaging--test-1",
  ]
  private var selections: [ConsentSelection] {
    ConsentFlowRules.coreTypes.map { ConsentSelection(type: $0, granted: true) }
  }
  private var granted: ConsentState {
    ConsentState(entries: Dictionary(uniqueKeysWithValues: versions.map {
      ($0.key, ConsentStateEntry(granted: true, documentVersion: $0.value))
    }))
  }

  func testConsentAckBeforeReaderEndStillRestartsAndReceivesServerGrant() async throws {
    let store = try makeStore()
    var capture = try await store.saveConsent(member: member, selections: selections,
      versions: versions, now: Synthetic.now)
    capture.state = .failed
    capture.lastErrorCode = "failed-precondition"
    try await store.update(capture)

    let firstRead = expectation(description: "initial reader")
    let restarted = expectation(description: "reader restarted after ack-before-end race")
    let rejected = expectation(description: "failed capture visible")
    let awaiting = expectation(description: "ack local event processed before reader ends")
    let confirmed = expectation(description: "new server reader grants consent")
    let source = RestartControlledConsentState { count in
      if count == 1 { firstRead.fulfill() }
      if count == 2 { restarted.fulfill() }
    }
    let workflow = service(store: store, states: source)
    let observer = Task {
      var seen: Set<String> = []
      for await consent in workflow.observe(member: member) {
        guard seen.insert(consent.healthData.rawValue).inserted else { continue }
        switch consent.healthData {
        case .rejected: rejected.fulfill()
        case .awaitingConsent: awaiting.fulfill()
        case .granted: confirmed.fulfill()
        case .missing: break
        }
      }
    }
    defer { observer.cancel(); source.finishAll() }
    await fulfillment(of: [firstRead, rejected], timeout: 2)
    source.yield(nil, read: 1)
    capture.state = .acked
    capture.ack = .call
    capture.lastErrorCode = nil
    try await store.update(capture)
    await fulfillment(of: [awaiting], timeout: 2)
    source.finish(read: 1)
    await fulfillment(of: [restarted], timeout: 2)
    source.yield(granted, read: 2)
    await fulfillment(of: [confirmed], timeout: 2)
  }

  func testLocalChangeAfterReaderEndedStartsANewReader() async throws {
    let store = try makeStore()
    let firstRead = expectation(description: "first reader")
    let secondRead = expectation(description: "initial local snapshot consumes one restart")
    let thirdRead = expectation(description: "later local save restarts ended reader")
    let confirmed = expectation(description: "server grant arrives after later local save")
    let source = RestartControlledConsentState { count in
      if count == 1 { firstRead.fulfill() }
      if count == 2 { secondRead.fulfill() }
      if count == 3 { thirdRead.fulfill() }
    }
    let workflow = service(store: store, states: source)
    let observer = Task {
      for await consent in workflow.observe(member: member) {
        if consent.coreGranted { confirmed.fulfill(); break }
      }
    }
    defer { observer.cancel(); source.finishAll() }
    await fulfillment(of: [firstRead], timeout: 2)
    source.finish(read: 1)
    // Whether the initial local event preceded or followed the end event, it starts exactly one more read.
    await fulfillment(of: [secondRead], timeout: 2)
    source.finish(read: 2)
    _ = try await store.saveConsent(member: member, selections: selections, versions: versions, now: Synthetic.now)
    await fulfillment(of: [thirdRead], timeout: 2)
    source.yield(granted, read: 3)
    await fulfillment(of: [confirmed], timeout: 2)
  }

  func testFiniteSuccessfulSourceDoesNotRestartWithoutAnotherLocalRevision() async throws {
    let store = try makeStore()
    let received = expectation(description: "finite server grant")
    let runaway = expectation(description: "unchanged finite reader must not spin")
    runaway.isInverted = true
    let source = RestartFiniteConsentState(state: granted) { count in
      if count > 2 { runaway.fulfill() }
    }
    let workflow = service(store: store, states: source)
    let observer = Task {
      var delivered = false
      for await consent in workflow.observe(member: member) {
        if consent.coreGranted && !delivered { delivered = true; received.fulfill() }
      }
    }
    defer { observer.cancel() }
    await fulfillment(of: [received], timeout: 2)
    await fulfillment(of: [runaway], timeout: 0.1)
  }

  private func makeStore() throws -> LocalOutboxStore {
    LocalOutboxStore(container: try LocalStoreContainer.make(inMemory: true), trainerUid: Synthetic.trainerA, binaries: nil)
  }

  private func service(store: LocalOutboxStore, states: any ConsentStateSource) -> LocalWorkflowService {
    let remote = RestartNoopRemote()
    let engine = SyncEngine(store: store, writer: remote, uploader: remote, callable: remote)
    let empty = RestartEmptySources()
    return LocalWorkflowService(outbox: store, engine: engine, documents: empty, states: states,
      measurements: empty, assigned: empty, pending: empty, now: { Synthetic.now })
  }
}

private final class RestartControlledConsentState: ConsentStateSource, @unchecked Sendable {
  private let lock = NSLock()
  private var reads = 0
  private var continuations: [Int: AsyncStream<ConsentState?>.Continuation] = [:]
  private let onRead: @Sendable (Int) -> Void
  init(onRead: @escaping @Sendable (Int) -> Void) { self.onRead = onRead }
  func observe(member: MemberKey) -> AsyncStream<ConsentState?> {
    AsyncStream { continuation in
      let read = lock.withLock {
        reads += 1
        continuations[reads] = continuation
        return reads
      }
      onRead(read)
    }
  }
  func yield(_ state: ConsentState?, read: Int) { lock.withLock { continuations[read] }?.yield(state) }
  func finish(read: Int) { lock.withLock { continuations.removeValue(forKey: read) }?.finish() }
  func finishAll() {
    let values = lock.withLock { let values = Array(continuations.values); continuations = [:]; return values }
    values.forEach { $0.finish() }
  }
}

private final class RestartFiniteConsentState: ConsentStateSource, @unchecked Sendable {
  private let lock = NSLock()
  private var reads = 0
  private let state: ConsentState
  private let onRead: @Sendable (Int) -> Void
  init(state: ConsentState, onRead: @escaping @Sendable (Int) -> Void) { self.state = state; self.onRead = onRead }
  func observe(member: MemberKey) -> AsyncStream<ConsentState?> {
    let count = lock.withLock { reads += 1; return reads }
    onRead(count)
    return AsyncStream { $0.yield(state); $0.finish() }
  }
}

private struct RestartEmptySources: ConsentDocumentsSource, MeasurementRecordsSource, MemberDirectory {
  func publishedDocuments() async throws -> [ConsentDocumentVersion] { [] }
  func records(member: MemberKey, since: Date) -> AsyncThrowingStream<[BodyCompositionRecord], Error> {
    AsyncThrowingStream { $0.yield([]); $0.finish() }
  }
  func observeAssignedMembers() -> AsyncThrowingStream<[Member], Error> {
    AsyncThrowingStream { $0.yield([]); $0.finish() }
  }
}

private struct RestartNoopRemote: RemoteWriter, BinaryUploader, CallableClient {
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
