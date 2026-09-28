import Foundation
import SwiftData
import SyncEngine
import TrainerContracts
import TrainerDomain
import XCTest
@testable import LocalStore

/// DF-127 (TC-127-01, -05, -07 without the emulator) and DF-130 (AC-DF-130.11 data part): body composition saves on
/// the device with its Outbox create in one save, consent ② gates the save, and reads merge the server's records with
/// this device's unsynced ones. Synthetic data only.
final class LocalMeasurementStoreTests: XCTestCase {
  private let member = MemberKey.uid("syn-member-0001")
  private let fixedID = "SynRecord00000000001"
  private let measuredAt = FixtureTimestamp.parse("2026-09-21T08:30:00+09:00")!
  private let since = FixtureTimestamp.parse("2025-09-21T00:00:00+09:00")!

  private final class Recorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _items: [TrainerDomain.OutboxItem] = []
    var items: [TrainerDomain.OutboxItem] { lock.withLock { _items } }
    func add(_ item: TrainerDomain.OutboxItem) { lock.withLock { _items.append(item) } }
  }

  /// A server whose records the test sets; every change is sent to the open listeners.
  private final class FakeServer: BodyCompositionRecordSource, @unchecked Sendable {
    private let lock = NSLock()
    private var records: [BodyCompositionRecord]
    private var continuations: [UUID: AsyncThrowingStream<[BodyCompositionRecord], Error>.Continuation] = [:]

    init(_ records: [BodyCompositionRecord] = []) { self.records = records }

    func observeRecords(member: MemberKey, since: Date) -> AsyncThrowingStream<[BodyCompositionRecord], Error> {
      AsyncThrowingStream { continuation in
        let id = UUID()
        lock.withLock {
          continuations[id] = continuation
          continuation.yield(records)
        }
        continuation.onTermination = { [weak self] _ in self?.lock.withLock { _ = self?.continuations.removeValue(forKey: id) } }
      }
    }

    func latestActiveRecord(member: MemberKey) async throws -> BodyCompositionRecord? {
      BodyCompositionSeries.latestActive(lock.withLock { records })
    }

    func set(_ records: [BodyCompositionRecord]) {
      lock.withLock {
        self.records = records
        continuations.values.forEach { $0.yield(records) }
      }
    }
  }

  private func draft(weight: String = "62,4", device: String? = " InBody  570 ") -> BodyCompositionDraft {
    BodyCompositionDraft(values: [.weightKg: weight], deviceModel: device, measuredAt: measuredAt, fasting: .yes)
  }

  private func makeStore(
    container: ModelContainer, consent: EffectiveConsent = .init(required: .granted, healthData: .granted, bodyImaging: .granted),
    server: FakeServer? = nil, recorder: Recorder = Recorder(), ids: [String]? = nil
  ) -> (LocalMeasurementStore, LocalOutboxStore) {
    let outbox = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerA, binaries: nil)
    let idSource = IDSource(ids ?? [fixedID])
    let store = LocalMeasurementStore(
      outbox: outbox, trainerUid: Synthetic.trainerA, enqueue: { recorder.add($0) }, server: server,
      consent: { _ in consent }, now: { [measuredAt] in measuredAt.addingTimeInterval(60) }, makeID: { idSource.next() })
    return (store, outbox)
  }

  private final class IDSource: @unchecked Sendable {
    private let lock = NSLock()
    private var ids: [String]
    init(_ ids: [String]) { self.ids = ids }
    func next() -> String { lock.withLock { ids.removeFirst() } }
  }

  // MARK: - Save

  /// One save: the draft, the Outbox create whose fields equal `BodyCompositionPayload.fields`, and the device use.
  @MainActor
  func testSaveWritesTheDraftAndItsCreateInOneSaveThenEnqueues() async throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let recorder = Recorder()
    let (store, outbox) = makeStore(container: container, recorder: recorder)

    let id = try await store.saveBodyComposition(member: member, draft: draft())
    XCTAssertEqual(id, fixedID)

    let item = try XCTUnwrap(recorder.items.first)
    XCTAssertEqual(recorder.items.count, 1)
    XCTAssertEqual(item.memberKey, member)
    XCTAssertEqual(item.entityRef, .measurement(kind: "bodyComposition", recordId: fixedID))
    XCTAssertEqual(item.stage, .document)
    XCTAssertEqual(item.kind, .createDocument)
    XCTAssertEqual(item.target, .document(path: "bodyCompositionRecords/\(fixedID)"))
    let entry = try XCTUnwrap(BodyCompositionValidator.validate(draft(), now: measuredAt).entry)
    XCTAssertEqual(item.payload, BodyCompositionPayload.fields(entry, member: member, trainerUid: Synthetic.trainerA))
    guard case let .object(fields)? = item.payload else { return XCTFail("object payload expected") }
    XCTAssertEqual(fields["values"], .object(["weightKg": .number(62.4)]), "'62,4' is 62.4, the only key (AC-DF-127.6)")
    XCTAssertEqual(fields["deviceModel"], .string("InBody 570"))
    XCTAssertEqual(Set(fields.keys).union(BodyCompositionPayload.serverTimestampKeys).subtracting(["derived"]),
                   BodyCompositionPayload.documentKeys.subtracting(["derived"]))

    let loaded = try await outbox.loadAll()
    XCTAssertEqual(loaded, [item], "the engine gets exactly the stored item")
    let drafts = try ModelContext(container).fetchOwned(LocalMeasurementDraft.self, by: Synthetic.trainerA)
    XCTAssertEqual(drafts.map(\.recordId), [fixedID])
    XCTAssertEqual(drafts.first?.kind, "bodyComposition")
    XCTAssertEqual(drafts.first.flatMap { try? JSONValue(storageData: $0.payloadJSON) }, item.payload)
    let devices = try await store.recentDeviceModels()
    XCTAssertEqual(devices, ["InBody 570"], "saving marks the device used")
  }

  /// Review M4 of DF-108 for records: killed before the engine heard of it, the item is still there on the next launch.
  @MainActor
  func testTheItemSurvivesARestartBeforeTheEngineSawIt() async throws {
    let temp = try TemporaryDirectory()
    defer { temp.remove() }
    let url = temp.url.appendingPathComponent("store.sqlite")
    do {
      let (store, _) = makeStore(container: try LocalStoreContainer.make(url: url))
      _ = try await store.saveBodyComposition(member: member, draft: draft())
    }
    let container = try LocalStoreContainer.make(url: url)
    let items = try await LocalOutboxStore(container: container, trainerUid: Synthetic.trainerA, binaries: nil).loadAll()
    XCTAssertEqual(items.map(\.target), [.document(path: "bodyCompositionRecords/\(fixedID)")])
    XCTAssertEqual(try ModelContext(container).fetchOwned(LocalMeasurementDraft.self, by: Synthetic.trainerA).count, 1)
  }

  /// AC-DF-127.4: without ② nothing is saved or queued; with ② waiting for the server (awaitingConsent) the record is
  /// saved on the device and queued for the engine to hold.
  @MainActor
  func testConsentTwoGatesTheSave_AC_DF_127_4() async throws {
    for (healthData, saves) in [(EffectiveConsentValue.missing, false), (.rejected, false), (.awaitingConsent, true),
                                (.granted, true)] {
      let container = try LocalStoreContainer.make(inMemory: true)
      let recorder = Recorder()
      let consent = EffectiveConsent(required: .granted, healthData: healthData, bodyImaging: .missing)
      let (store, _) = makeStore(container: container, consent: consent, recorder: recorder)
      do {
        _ = try await store.saveBodyComposition(member: member, draft: draft())
        XCTAssertTrue(saves, "\(healthData) must not save")
      } catch {
        XCTAssertFalse(saves, "\(healthData) must save")
        XCTAssertEqual(error as? MeasurementStoreError, .consentRequired(.healthData))
      }
      let drafts = try ModelContext(container).fetchOwned(LocalMeasurementDraft.self, by: Synthetic.trainerA)
      XCTAssertEqual(drafts.count, saves ? 1 : 0, "\(healthData)")
      XCTAssertEqual(recorder.items.count, saves ? 1 : 0, "\(healthData)")
    }
  }

  @MainActor
  func testAnInvalidDraftSavesNothing_AC_DF_127_1() async throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let recorder = Recorder()
    let (store, _) = makeStore(container: container, recorder: recorder)
    var noFasting = draft()
    noFasting.fasting = nil
    do {
      _ = try await store.saveBodyComposition(member: member, draft: noFasting)
      XCTFail("expected invalidDraft")
    } catch {
      XCTAssertEqual(error as? MeasurementStoreError, .invalidDraft([.fastingMissing]))
    }
    XCTAssertEqual(try ModelContext(container).fetchOwned(LocalMeasurementDraft.self, by: Synthetic.trainerA).count, 0)
    XCTAssertTrue(recorder.items.isEmpty)
  }

  // MARK: - Read

  private func serverRecord(_ id: String, _ date: String, weight: Double, device: String = "InBody 570",
                            status: MeasurementStatus = .active) -> BodyCompositionRecord {
    BodyCompositionRecord(
      id: id, member: member, deviceModel: device, measuredAt: FixtureTimestamp.parse(date)!, fasting: .yes,
      timeOfDayBand: .morning, source: "manualEntry", sourceGrade: .device, values: [.weightKg: weight], derived: nil,
      status: status)
  }

  private func next(_ iterator: inout AsyncThrowingStream<[BodyCompositionRecord], Error>.AsyncIterator)
    async throws -> [String]
  {
    try await iterator.next()?.map(\.id) ?? []
  }

  /// DF-130: the trend reads the server's records plus this device's unsynced draft, one per id; once the server has
  /// the record (and the item is acked) only the server's copy is left.
  @MainActor
  func testRecordsMergeServerAndUnsyncedLocalDrafts() async throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let server = FakeServer([serverRecord("SynServer00000000001", "2026-08-01T08:30:00+09:00", weight: 65)])
    let (store, outbox) = makeStore(container: container, server: server)
    var records = store.observeBodyCompositionRecords(member: member, since: since).makeAsyncIterator()
    let first = try await next(&records)
    XCTAssertEqual(first, ["SynServer00000000001"])

    _ = try await store.saveBodyComposition(member: member, draft: draft())
    let afterSave = try await next(&records)
    XCTAssertEqual(afterSave, ["SynServer00000000001", fixedID], "the new record is there at once, offline too")

    // The engine sends it: acked, and the server now has it (voided there, to see whose copy wins).
    let stored = try await outbox.loadAll()
    var item = try XCTUnwrap(stored.first)
    item.state = .acked
    item.ack = .write(WriteAck(serverCommitted: true))
    try await outbox.update(item)
    server.set([serverRecord("SynServer00000000001", "2026-08-01T08:30:00+09:00", weight: 65),
                serverRecord(fixedID, "2026-09-21T08:30:00+09:00", weight: 62.4, status: .voided)])
    let afterAck = try await records.next()
    XCTAssertEqual(afterAck?.map(\.id), ["SynServer00000000001", fixedID])
    XCTAssertEqual(afterAck?.last?.status, .voided, "the server's copy wins")

    let unsynced = try await outbox.unsyncedBodyCompositionRecords(member: member)
    XCTAssertEqual(unsynced, [], "an acked draft is not read locally any more")
  }

  /// Review (DF-127 finding 4): each unsynced draft carries its SyncEngine state into the merged records. Without an
  /// engine it is `localSaved`; a create the rules refuse for good (permission-denied, e.g. consent withdrawn while
  /// this iPad was offline) reads `syncFailed`, never like the synced server records, which have no state.
  @MainActor
  func testDraftsCarryTheirSyncStateAndARefusedOneReadsFailed() async throws {
    // No engine: saved on the device.
    let plain = try LocalStoreContainer.make(inMemory: true)
    let (offline, _) = makeStore(container: plain, server: FakeServer())
    var offlineRecords = offline.observeBodyCompositionRecords(member: member, since: since).makeAsyncIterator()
    _ = try await offlineRecords.next()
    _ = try await offline.saveBodyComposition(member: member, draft: draft())
    let saved = try await offlineRecords.next()
    XCTAssertEqual(saved?.map(\.syncState), [.localSaved])

    // A SyncEngine whose server refuses the create.
    let container = try LocalStoreContainer.make(inMemory: true)
    let outbox = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerA, binaries: nil)
    let remote = RefusingRemote()
    let engine = SyncEngine(store: outbox, writer: remote, uploader: remote, callable: remote)
    await engine.start()
    let server = FakeServer([serverRecord("SynServer00000000001", "2026-08-01T08:30:00+09:00", weight: 65)])
    let store = LocalMeasurementStore(
      outbox: outbox, trainerUid: Synthetic.trainerA, enqueue: { await engine.enqueue($0) }, server: server,
      consent: { _ in .init(required: .granted, healthData: .granted, bodyImaging: .granted) },
      syncStates: { await engine.syncState(for: $0) }, now: { [measuredAt] in measuredAt.addingTimeInterval(60) },
      makeID: { [fixedID] in fixedID })
    let stream = store.observeBodyCompositionRecords(member: member, since: since)
    _ = try await store.saveBodyComposition(member: member, draft: draft())
    let refused = try await firstList(of: stream) { $0.first { $0.id == self.fixedID }?.syncState == .syncFailed }
    XCTAssertEqual(refused?.map(\.id), ["SynServer00000000001", fixedID])
    XCTAssertEqual(refused?.map(\.syncState), [nil, .syncFailed], "the refused draft is not shown as synced")
    XCTAssertEqual(remote.attempts, 1, "a permanent rejection is not retried on its own")
    await engine.stop()
  }

  /// DF-127 second review: the SyncEngine reports `synced` before it saves the ack, so the drafts read on that signal
  /// may still have the item in flight. The draft must not outlive the send: when the server later removes the record
  /// (consent withdrawal, DF-133), the list is empty, not the leftover draft.
  @MainActor
  func testASyncedDraftDoesNotComeBackWhenTheServerRemovesTheRecord() async throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let outbox = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerA, binaries: nil)
    let server = FakeServer()
    let engine = StateFeed()
    let store = LocalMeasurementStore(
      outbox: outbox, trainerUid: Synthetic.trainerA, enqueue: { _ in }, server: server,
      consent: { _ in .init(required: .granted, healthData: .granted, bodyImaging: .granted) },
      syncStates: { _ in engine.stream() }, now: { [measuredAt] in measuredAt.addingTimeInterval(60) },
      makeID: { [fixedID] in fixedID })
    let lists = ListRecorder(store.observeBodyCompositionRecords(member: member, since: since))
    defer { lists.cancel() }
    _ = try await store.saveBodyComposition(member: member, draft: draft())
    let saved = await lists.latest { $0.map(\.id) == [fixedID] }
    XCTAssertTrue(saved, "the draft is there at once")

    // The engine sends it: the item is in flight, the server has the record, and `synced` comes before the ack is saved.
    let stored = try await outbox.loadAll()
    var item = try XCTUnwrap(stored.first)
    item.state = .inFlight
    try await outbox.update(item)
    server.set([serverRecord(fixedID, "2026-09-21T08:30:00+09:00", weight: 62.4)])
    engine.send(.synced)
    let synced = await lists.latest { $0.map(\.id) == [fixedID] && ($0.first?.syncState ?? .synced) == .synced }
    XCTAssertTrue(synced, "the record reads synced")

    // Then the ack is saved, and later the server removes the record.
    item.state = .acked
    item.ack = .write(WriteAck(serverCommitted: true))
    try await outbox.update(item)
    server.set([])
    let removed = await lists.latest { $0.isEmpty }
    XCTAssertTrue(removed, "the synced draft came back: \(lists.last?.map(\.id) ?? [])")
  }

  /// A SyncEngine stand-in whose state the test sends; a new subscriber gets the current state first, as from the engine.
  private final class StateFeed: @unchecked Sendable {
    private let lock = NSLock()
    private var state = SyncState.localSaved
    private var continuations: [AsyncStream<SyncState>.Continuation] = []

    func stream() -> AsyncStream<SyncState> {
      AsyncStream { continuation in
        lock.withLock {
          continuations.append(continuation)
          continuation.yield(state)
        }
      }
    }

    func send(_ state: SyncState) {
      lock.withLock {
        self.state = state
        continuations.forEach { $0.yield(state) }
      }
    }
  }

  /// Keeps the newest list of a record stream; `latest(where:)` waits until it matches.
  private final class ListRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _last: [BodyCompositionRecord]?
    private var task: Task<Void, Never>?
    var last: [BodyCompositionRecord]? { lock.withLock { _last } }

    init(_ stream: AsyncThrowingStream<[BodyCompositionRecord], Error>) {
      task = Task { [weak self] in
        do {
          for try await list in stream { self?.keep(list) }
        } catch {}
      }
    }

    private func keep(_ list: [BodyCompositionRecord]) {
      lock.withLock { _last = list }
    }

    func cancel() {
      task?.cancel()
    }

    /// Whether the newest list matches `accept` within `seconds`.
    func latest(within seconds: Double = 10, where accept: ([BodyCompositionRecord]) -> Bool) async -> Bool {
      let deadline = Date().addingTimeInterval(seconds)
      while Date() < deadline {
        if let last, accept(last) { return true }
        try? await Task.sleep(nanoseconds: 10_000_000)
      }
      return last.map(accept) ?? false
    }
  }

  /// The first list `accept` takes, or nil after `seconds`.
  private func firstList(
    of stream: AsyncThrowingStream<[BodyCompositionRecord], Error>, seconds: Double = 10,
    where accept: @escaping @Sendable ([BodyCompositionRecord]) -> Bool
  ) async throws -> [BodyCompositionRecord]? {
    try await withThrowingTaskGroup(of: [BodyCompositionRecord]?.self) { group in
      group.addTask {
        for try await list in stream where accept(list) { return list }
        return nil
      }
      group.addTask {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        return nil
      }
      let first = try await group.next() ?? nil
      group.cancelAll()
      return first
    }
  }

  /// DF-127 second review: TR-11's defaults read the member's latest active record at any date, before the 12-month
  /// window too, skipping voided records; this device's unsynced draft counts when it is the latest.
  @MainActor
  func testTheLatestActiveRecordIsReadAtAnyDate() async throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let server = FakeServer([
      serverRecord("SynServer00000000001", "2025-01-10T08:30:00+09:00", weight: 66, device: "InBody 570"),
      serverRecord("SynServer00000000002", "2025-02-10T08:30:00+09:00", weight: 99, status: .voided),
    ])
    let (store, _) = makeStore(container: container, server: server)
    let old = try await store.latestActiveBodyComposition(member: member)
    XCTAssertEqual(old?.id, "SynServer00000000001", "20 months ago, the voided one after it skipped")
    _ = try await store.saveBodyComposition(member: member, draft: draft())
    let saved = try await store.latestActiveBodyComposition(member: member)
    XCTAssertEqual(saved?.id, fixedID)
    XCTAssertEqual(saved?.deviceModel, "InBody 570")
  }

  /// AC-DF-130.11: the mini trend's points skip voided records; `observeSeries` is the points of the merged records.
  @MainActor
  func testSeriesSkipsVoidedRecords() async throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let server = FakeServer([
      serverRecord("SynServer00000000001", "2026-07-01T08:30:00+09:00", weight: 66),
      serverRecord("SynServer00000000002", "2026-08-01T08:30:00+09:00", weight: 99, status: .voided),
      serverRecord("SynServer00000000003", "2026-09-01T08:30:00+09:00", weight: 64, device: "InBody 970"),
    ])
    let (store, _) = makeStore(container: container, server: server)
    var series = store.observeSeries(member: member, metricCode: .weightKg, since: since).makeAsyncIterator()
    let points = try await series.next() ?? []
    XCTAssertEqual(points.map(\.value), [66, 64])
    XCTAssertEqual(points.map(\.conditions.deviceKey), ["InBody 570", "InBody 970"])
  }

  @MainActor
  func testAServerFailureFailsTheStream() async throws {
    struct Refused: Error {}
    struct FailingServer: BodyCompositionRecordSource {
      func observeRecords(member: MemberKey, since: Date) -> AsyncThrowingStream<[BodyCompositionRecord], Error> {
        AsyncThrowingStream { $0.finish(throwing: Refused()) }
      }
      func latestActiveRecord(member: MemberKey) async throws -> BodyCompositionRecord? { throw Refused() }
    }
    let outbox = LocalOutboxStore(container: try LocalStoreContainer.make(inMemory: true), trainerUid: Synthetic.trainerA,
                                  binaries: nil)
    let store = LocalMeasurementStore(outbox: outbox, trainerUid: Synthetic.trainerA, enqueue: { _ in },
                                      server: FailingServer(), consent: { _ in .none })
    var records = store.observeBodyCompositionRecords(member: member, since: since).makeAsyncIterator()
    do {
      _ = try await records.next()
      XCTFail("expected the server's error, never an empty list")
    } catch {
      XCTAssertTrue(error is Refused)
    }
  }

  // MARK: - Device list

  @MainActor
  func testDeviceListIsNewestFirstAndRefusesBadNames() async throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let (store, _) = makeStore(container: container)
    let first = try await store.addDeviceModel("InBody 570")
    XCTAssertEqual(first, "InBody 570")
    let second = try await store.addDeviceModel("  Tanita   MC-780 ")
    XCTAssertEqual(second, "Tanita MC-780", "stored normalized")
    _ = try await store.addDeviceModel("InBody 570")
    let names = try await store.recentDeviceModels()
    XCTAssertEqual(Set(names), ["InBody 570", "Tanita MC-780"])
    for bad in ["   ", String(repeating: "x", count: 65)] {
      do {
        _ = try await store.addDeviceModel(bad)
        XCTFail("expected invalidName for \(bad.count) characters")
      } catch {
        XCTAssertEqual(error as? DeviceModelCatalogError, .invalidName)
      }
    }
    let rows = try ModelContext(container).fetchOwned(DeviceModelEntry.self, by: Synthetic.trainerA)
    XCTAssertEqual(rows.count, 2, "adding the same name again does not duplicate it")
  }

  @MainActor
  func testDeviceOrderFollowsLastUse() async throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let outbox = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerA, binaries: nil)
    try await outbox.useDeviceModel("A", at: measuredAt)
    try await outbox.useDeviceModel("B", at: measuredAt.addingTimeInterval(10))
    let byUse = try await outbox.deviceModelNames()
    XCTAssertEqual(byUse, ["B", "A"])
    try await outbox.useDeviceModel("A", at: measuredAt.addingTimeInterval(20))
    let reordered = try await outbox.deviceModelNames()
    XCTAssertEqual(reordered, ["A", "B"])
  }

  // MARK: - Schema

  /// A V1_1 store (DF-108) opens with V1_2: its rows survive and the device list starts empty.
  @MainActor
  func testAV1_1StoreMigratesToV1_2() throws {
    let temp = try TemporaryDirectory()
    defer { temp.remove() }
    let url = temp.url.appendingPathComponent("v1_1.sqlite")
    do {
      let v11 = try ModelContainer(for: Schema(versionedSchema: LocalStoreSchemaV1_1.self),
                                   configurations: [ModelConfiguration(url: url)])
      let context = ModelContext(v11)
      context.insert(LocalStoreSchemaV1_1.LocalPendingMemberDraft(
        pendingMemberId: "SynthPending00000001", trainerUid: Synthetic.trainerA, displayName: "SYN", sex: "female",
        birthYear: 1990, ageConfirmed14: true, createdLocallyAt: Synthetic.now, outboxItemId: UUID()))
      try context.save()
    }
    let current = ModelContext(try LocalStoreContainer.make(url: url))
    XCTAssertEqual(try current.fetchOwned(LocalPendingMemberDraft.self, by: Synthetic.trainerA).count, 1)
    XCTAssertEqual(try current.fetchOwned(DeviceModelEntry.self, by: Synthetic.trainerA).count, 0)
  }
}

/// A server that refuses every create for good (the rules' permission-denied) and counts the attempts.
private final class RefusingRemote: RemoteWriter, BinaryUploader, CallableClient, @unchecked Sendable {
  private let lock = NSLock()
  private var _attempts = 0
  var attempts: Int { lock.withLock { _attempts } }

  func createIfAbsent(path: String, fields: JSONValue) async throws -> WriteAck {
    lock.withLock { _attempts += 1 }
    throw RemoteError.permissionDenied
  }
  func update(path: String, fields: JSONValue) async throws -> WriteAck { throw RemoteError.permissionDenied }
  func delete(path: String) async throws -> WriteAck { throw RemoteError.permissionDenied }
  func upload(localURL: URL, path: String, contentType: String, sha256: String) async throws -> UploadReceipt {
    throw RemoteError.permissionDenied
  }
  func delete(path: String) async throws { throw RemoteError.permissionDenied }
  func call<T: Decodable & Sendable>(_ name: String, _ payload: JSONValue) async throws -> T {
    throw RemoteError.permissionDenied
  }
}
