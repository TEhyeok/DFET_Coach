import Foundation
import SwiftData
import SyncEngine
import TrainerContracts
import TrainerDomain
import XCTest
@testable import LocalStore

/// DF-110 MVP / DF-111 MVP on LocalStore: an in-person capture and its `callConsent` item in one save, the item's
/// dependency on the pending-member create, the capture state following the item, and the capture observation the
/// effective consent reads. Synthetic data only.
final class LocalConsentCapturesTests: XCTestCase {
  private let pendingID = "SynthPending00000001"
  private let captureUUID = UUID(uuidString: "3F2B8C1E-5D7A-4B1E-9A51-0C8E2D7F1A90")!
  private var captureId: String { captureUUID.uuidString.lowercased() }
  private let draft = PendingMemberDraft(displayName: "가상회원 가", sex: .female, birthYear: 1990, ageConfirmed14: true)
  private let grants = ConsentFlowRules.coreTypes.map {
    ConsentSelection(consentType: $0, action: .grant, documentVersion: "\($0.rawValue)--1.0")
  }

  private final class Items: @unchecked Sendable {
    private let lock = NSLock()
    private var _items: [TrainerDomain.OutboxItem] = []
    private var _rowsAtEnqueue: [(captures: Int, items: Int)] = []
    var items: [TrainerDomain.OutboxItem] { lock.withLock { _items } }
    var rowsAtEnqueue: [(captures: Int, items: Int)] { lock.withLock { _rowsAtEnqueue } }
    func add(_ item: TrainerDomain.OutboxItem, rows: (Int, Int)) {
      lock.withLock {
        _items.append(item)
        _rowsAtEnqueue.append(rows)
      }
    }
  }

  private func counts(_ container: ModelContainer) -> (Int, Int) {
    let context = ModelContext(container)
    return ((try? context.fetchOwned(LocalConsentCapture.self, by: Synthetic.trainerA).count) ?? -1,
            (try? context.fetchOwned(OutboxItem.self, by: Synthetic.trainerA).count) ?? -1)
  }

  // MARK: Capture

  /// The capture and its `callConsent` item are both on disk before the SyncEngine is told (one save), with
  /// `requestId == captureId`, stage 1, the V1-06 payload and `dependsOn` the pending member's create item.
  func test_AC_DF_110_captureAndItsCallItemAreSavedTogetherAndDependOnTheCreate() async throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let outbox = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerA, binaries: nil)
    let registered = Items()
    let registrar = LocalPendingMemberRegistrar(
      outbox: outbox, trainerUid: Synthetic.trainerA, enqueue: { [self] in registered.add($0, rows: counts(container)) },
      now: { Synthetic.now }, makeID: { [pendingID] in pendingID })
    _ = try await registrar.register(draft)
    let create = try XCTUnwrap(registered.items.first)

    let enqueued = Items()
    let recorder = LocalConsentRecorder(
      outbox: outbox, enqueue: { [self] in enqueued.add($0, rows: counts(container)) },
      now: { Synthetic.now.addingTimeInterval(60) }, makeID: { [captureUUID] in captureUUID })
    let member = MemberKey.pending(pendingID)
    let returned = try await recorder.capture(member: member, selections: grants)
    XCTAssertEqual(returned, captureId)

    let item = try XCTUnwrap(enqueued.items.first)
    XCTAssertEqual(enqueued.items.count, 1)
    XCTAssertEqual(enqueued.rowsAtEnqueue.first?.captures, 1, "the capture was saved before the engine was told")
    XCTAssertEqual(enqueued.rowsAtEnqueue.first?.items, 2, "with its item (the create is the other row)")
    XCTAssertEqual(item.requestId, captureUUID, "V1-06 §6.2.5: the idempotency key is the capture ID")
    XCTAssertEqual(item.memberKey, member)
    XCTAssertEqual(item.entityRef, .consent(captureId: captureId))
    XCTAssertEqual(item.stage, .consent)
    XCTAssertEqual(item.kind, .callConsent)
    XCTAssertEqual(item.target, .callable(name: "recordConsent"))
    XCTAssertEqual(item.dependsOn, [create.id], "ASM-P1a-01: the create goes first")
    XCTAssertGreaterThan(item.sequence, create.sequence)
    XCTAssertEqual(item.payload, RecordConsentRequest.payload(
      captureId: captureId, member: member, selections: grants, capturedAt: Synthetic.now.addingTimeInterval(60)))

    let row = try XCTUnwrap(ModelContext(container).fetchOwned(LocalConsentCapture.self, by: Synthetic.trainerA).first)
    XCTAssertEqual(row.captureId, captureId)
    XCTAssertEqual(row.memberKey, "pending:\(pendingID)")
    XCTAssertEqual(try JSONDecoder().decode([ConsentSelection].self, from: row.selectionsJSON), grants)
    XCTAssertNil(row.signatureBinaryId, "MVP: no signature")
    XCTAssertEqual(row.captureState, "pending")
    XCTAssertNil(row.serverConfirmedAt)
    XCTAssertEqual(row.expiresAt, Synthetic.now.addingTimeInterval(60 + LocalRetention.window))
    let stored = try await outbox.loadAll().first { $0.id == item.id }
    XCTAssertEqual(stored, item, "the stored item is the one the engine gets")
  }

  func testAUidMemberCaptureDependsOnNothing() async throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let outbox = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerA, binaries: nil)
    let enqueued = Items()
    let recorder = LocalConsentRecorder(outbox: outbox, enqueue: { enqueued.add($0, rows: (0, 0)) })
    _ = try await recorder.capture(member: Synthetic.memberA, selections: [grants[1]])
    XCTAssertEqual(enqueued.items.first?.dependsOn, [])
    XCTAssertEqual(enqueued.items.first?.sequence, 1)
  }

  func testInvalidSelectionsSaveNothing() async throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let outbox = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerA, binaries: nil)
    let enqueued = Items()
    let recorder = LocalConsentRecorder(outbox: outbox, enqueue: { enqueued.add($0, rows: (0, 0)) })
    for selections in [[], [grants[0], grants[0]]] {
      do {
        _ = try await recorder.capture(member: Synthetic.memberA, selections: selections)
        XCTFail("expected invalidSelections")
      } catch {
        XCTAssertEqual(error as? ConsentCaptureError, .invalidSelections)
      }
    }
    let (captures, items) = counts(container)
    XCTAssertEqual(captures, 0)
    XCTAssertEqual(items, 0)
    XCTAssertTrue(enqueued.items.isEmpty)
  }

  // MARK: Through the SyncEngine

  /// Offline registration and capture, then online: the create goes first, then `recordConsent` with the stored
  /// payload; the capture is then confirmed, stamped with the time the device learned it.
  func testTheEngineSendsTheCreateThenTheCaptureWhichBecomesConfirmed() async throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let confirmedAt = Synthetic.now.addingTimeInterval(3600)
    let outbox = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerA, binaries: nil,
                                  now: { confirmedAt })
    let remote = OrderedRemote()
    let engine = SyncEngine(store: outbox, writer: remote, uploader: remote, callable: remote)
    await engine.networkDidChange(isReachable: false)
    await engine.start()
    let registrar = LocalPendingMemberRegistrar(
      outbox: outbox, trainerUid: Synthetic.trainerA, enqueue: { await engine.enqueue($0) },
      now: { Synthetic.now }, makeID: { [pendingID] in pendingID })
    _ = try await registrar.register(draft)
    let recorder = LocalConsentRecorder(outbox: outbox, enqueue: { await engine.enqueue($0) },
                                        now: { Synthetic.now }, makeID: { [captureUUID] in captureUUID })
    let captures = LocalConsentCaptureStore(container: container, trainerUid: Synthetic.trainerA)
    let states = StateLog(captures.observeCaptures(member: .pending(pendingID)))
    _ = try await recorder.capture(member: .pending(pendingID), selections: grants)
    XCTAssertEqual(remote.log, [], "offline: nothing sent")
    let pending = await eventually { states.last?.first?.state == .pending }
    XCTAssertTrue(pending)

    await engine.networkDidChange(isReachable: true)
    let confirmed = await eventually { states.last?.first?.state == .confirmed }
    XCTAssertTrue(confirmed)
    XCTAssertEqual(remote.log, ["create pendingMembers/\(pendingID)", "call recordConsent"])
    let payload = try XCTUnwrap(remote.payloads.first?.objectValue)
    XCTAssertEqual(payload["clientCaptureId"], .string(captureId))
    XCTAssertEqual(Set(payload.keys), RecordConsentRequest.keys)
    XCTAssertEqual(states.last?.first?.confirmedAt, confirmedAt)
    let row = try XCTUnwrap(ModelContext(container).fetchOwned(LocalConsentCapture.self, by: Synthetic.trainerA).first)
    XCTAssertEqual(row.captureState, "confirmed")
    XCTAssertEqual(row.syncState, "synced")
    XCTAssertEqual(row.serverConfirmedAt, confirmedAt)
    await engine.stop()
    states.cancel()
  }

  /// A rejected capture (a retired document version: `failed-precondition`) is failed with the item's code, and the
  /// effective consent reads it as rejected ('동의 필요' in the MVP chip).
  func testARejectedCaptureIsFailedAndReadsAsRejected() async throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let outbox = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerA, binaries: nil)
    let remote = OrderedRemote(callError: .failedPrecondition)
    let engine = SyncEngine(store: outbox, writer: remote, uploader: remote, callable: remote)
    await engine.start()
    let recorder = LocalConsentRecorder(outbox: outbox, enqueue: { await engine.enqueue($0) })
    let captures = LocalConsentCaptureStore(container: container, trainerUid: Synthetic.trainerA)
    let resolver = EffectiveConsentResolver(server: NoServerState(), captures: captures)
    let values = StateLog(resolver.observe(member: Synthetic.memberA))
    _ = try await recorder.capture(member: Synthetic.memberA, selections: grants)

    let rejected = await eventually { values.last?.healthData == .rejected }
    XCTAssertTrue(rejected)
    XCTAssertEqual(values.last?.chipState, .needed)
    let row = try XCTUnwrap(ModelContext(container).fetchOwned(LocalConsentCapture.self, by: Synthetic.trainerA).first)
    XCTAssertEqual(row.captureState, "failed")
    XCTAssertEqual(row.syncState, "syncFailed")
    XCTAssertEqual(row.lastErrorCode, "failed-precondition")
    XCTAssertNil(row.serverConfirmedAt)
    await engine.stop()
    values.cancel()
  }

  /// Captures of another member or another trainer are not observed.
  func testObservationIsScopedToTheMemberAndTheTrainer() async throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let outboxA = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerA, binaries: nil)
    let outboxB = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerB, binaries: nil)
    let store = LocalConsentCaptureStore(container: container, trainerUid: Synthetic.trainerA)
    let log = StateLog(store.observeCaptures(member: Synthetic.memberA))
    let first = await eventually { log.all.count == 1 }
    XCTAssertTrue(first)
    XCTAssertEqual(log.all, [[]])
    _ = try await LocalConsentRecorder(outbox: outboxB, enqueue: { _ in }).capture(member: Synthetic.memberA,
                                                                                    selections: grants)
    _ = try await LocalConsentRecorder(outbox: outboxA, enqueue: { _ in }).capture(member: Synthetic.memberB,
                                                                                    selections: grants)
    _ = try await LocalConsentRecorder(outbox: outboxA, enqueue: { _ in }).capture(member: Synthetic.memberA,
                                                                                    selections: [grants[0]])
    let second = await eventually { log.all.count == 2 }
    XCTAssertTrue(second)
    XCTAssertEqual(log.last?.map(\.selections), [[grants[0]]])
    XCTAssertEqual(log.all.count, 2, "changes of other members and trainers were not emitted")
    log.cancel()
  }
}

// MARK: - Support

private func eventually(timeout: TimeInterval = 5, _ condition: () -> Bool) async -> Bool {
  let deadline = Date().addingTimeInterval(timeout)
  while Date() < deadline {
    if condition() { return true }
    try? await Task.sleep(nanoseconds: 10_000_000)
  }
  return condition()
}

private struct NoServerState: ConsentStateSource {
  func observe(member: MemberKey) -> AsyncStream<ConsentState?> { AsyncStream { $0.yield(nil) } }
}

/// Collects a stream's values in the background.
private final class StateLog<T: Sendable>: @unchecked Sendable {
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
  var last: T? { all.last }
  func cancel() { task?.cancel() }
}

/// Accepts writes, answers callables with `{ok: true}` (or `callError`), and logs the order of what was sent.
private final class OrderedRemote: RemoteWriter, BinaryUploader, CallableClient, @unchecked Sendable {
  private let lock = NSLock()
  private var _log: [String] = []
  private var _payloads: [JSONValue] = []
  private let callError: RemoteError?

  init(callError: RemoteError? = nil) {
    self.callError = callError
  }

  var log: [String] { lock.withLock { _log } }
  var payloads: [JSONValue] { lock.withLock { _payloads } }

  func createIfAbsent(path: String, fields: JSONValue) async throws -> WriteAck {
    lock.withLock { _log.append("create \(path)") }
    return WriteAck(serverCommitted: true)
  }
  func update(path: String, fields: JSONValue) async throws -> WriteAck {
    lock.withLock { _log.append("update \(path)") }
    return WriteAck(serverCommitted: true)
  }
  func delete(path: String) async throws -> WriteAck { WriteAck(serverCommitted: true) }
  func upload(localURL: URL, path: String, contentType: String, sha256: String) async throws -> UploadReceipt {
    UploadReceipt(path: path, size: 0, sha256: sha256, verified: true)
  }
  func delete(path: String) async throws {}
  func call<T: Decodable & Sendable>(_ name: String, _ payload: JSONValue) async throws -> T {
    lock.withLock {
      _log.append("call \(name)")
      _payloads.append(payload)
    }
    if let callError { throw callError }
    return try JSONDecoder().decode(T.self, from: Data(#"{"ok":true,"replayed":false}"#.utf8))
  }
}
