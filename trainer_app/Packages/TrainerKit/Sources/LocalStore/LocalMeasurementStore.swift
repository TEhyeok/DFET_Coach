import Foundation
import TrainerContracts
import TrainerDomain

/// `MeasurementStore` and the TR-11 device list on one trainer's LocalStore partition (DF-127, DF-130).
///
/// Saving works like the DF-108 registration: validate, check consent ②, then store `LocalMeasurementDraft`, the
/// `bodyCompositionRecords/{id}` create (stage 2, `createDocument`) and the use of the device in one save, and only
/// then hand the item to the SyncEngine. Nothing waits for the server, so a save works offline; a member whose ② only
/// waits for the server is saved on the device and the engine holds the item (`awaitingConsent`, DF-015).
///
/// Reading merges the server's records (`BodyCompositionRecordSource`, FirebaseData) with this device's drafts the
/// server does not have yet, one per record id (`BodyCompositionRecordMerge`), so a new record is on the trend at once,
/// online or not. Each draft carries its `syncState` from the SyncEngine, so a draft the server refused reads
/// `syncFailed`, never like a synced record (V1-04 §11, V1-07 §6).
public final class LocalMeasurementStore: MeasurementStore, DeviceModelCatalog {
  /// The SyncEngine's `syncState(for:)`: the entity's state now and after every change.
  public typealias SyncStates = @Sendable (TrainerDomain.LocalEntityRef) async -> AsyncStream<SyncState>

  private let outbox: LocalOutboxStore
  private let trainerUid: String
  private let enqueue: @Sendable (TrainerDomain.OutboxItem) async -> Void
  private let server: (any BodyCompositionRecordSource)?
  private let consent: @Sendable (MemberKey) async -> EffectiveConsent
  private let syncStates: SyncStates?
  private let now: @Sendable () -> Date
  private let makeID: @Sendable () -> String
  private let changes = MemberChangeSignal()

  /// - Parameters:
  ///   - server: the server's records; nil reads this device's drafts only.
  ///   - consent: the member's effective consent now (`EffectiveConsent.current(from:member:)`); ② decides.
  ///   - syncStates: the SyncEngine's state of a draft; nil (no engine, the preview) reads every draft `localSaved`.
  public init(
    outbox: LocalOutboxStore, trainerUid: String,
    enqueue: @escaping @Sendable (TrainerDomain.OutboxItem) async -> Void,
    server: (any BodyCompositionRecordSource)?,
    consent: @escaping @Sendable (MemberKey) async -> EffectiveConsent,
    syncStates: SyncStates? = nil,
    now: @escaping @Sendable () -> Date = { Date() }, makeID: @escaping @Sendable () -> String = { DocumentID.make() }
  ) {
    self.outbox = outbox
    self.trainerUid = trainerUid
    self.enqueue = enqueue
    self.server = server
    self.consent = consent
    self.syncStates = syncStates
    self.now = now
    self.makeID = makeID
  }

  // MARK: - MeasurementStore

  public func saveBodyComposition(member: MemberKey, draft: BodyCompositionDraft) async throws -> String {
    let date = now()
    let validation = BodyCompositionValidator.validate(draft, now: date)
    guard let entry = validation.entry else { throw MeasurementStoreError.invalidDraft(validation.errors) }
    guard await consent(member).healthRecordSave != .blocked else {
      throw MeasurementStoreError.consentRequired(.healthData)  // R-14: the rules would refuse the create
    }
    let id = makeID()
    let fields = BodyCompositionPayload.fields(entry, member: member, trainerUid: trainerUid)
    let item = TrainerDomain.OutboxItem(
      memberKey: member, entityRef: BodyCompositionPayload.entityRef(recordId: id),
      sequence: try await outbox.nextSequence(for: member), stage: .document, kind: .createDocument,
      target: .document(path: BodyCompositionPayload.path(id: id)), payload: fields, createdAt: date)
    try await outbox.insertMeasurement(
      MeasurementDraftRecord(recordId: id, member: member, kind: .bodyComposition, payload: fields, createdLocallyAt: date),
      createItem: item, deviceModel: entry.deviceModel, usedAt: date)
    changes.notify(member)
    await enqueue(item)
    return id
  }

  public func observeBodyCompositionRecords(member: MemberKey, since: Date)
    -> AsyncThrowingStream<[BodyCompositionRecord], Error>
  {
    let outbox = outbox
    let server = server
    let changes = changes
    let syncStates = syncStates
    return AsyncThrowingStream { continuation in
      let task = Task {
        await RecordsMerge(member: member, since: since, outbox: outbox, server: server, changes: changes,
                           syncStates: syncStates, output: continuation).run()
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  /// The server's latest active record and this device's unsynced drafts, whichever was measured last.
  public func latestActiveBodyComposition(member: MemberKey) async throws -> BodyCompositionRecord? {
    let drafts = try await outbox.unsyncedBodyCompositionRecords(member: member)
    let stored = try await server?.latestActiveRecord(member: member)
    return BodyCompositionSeries.latestActive(drafts + [stored].compactMap { $0 })
  }

  public func observeSeries(member: MemberKey, metricCode: MetricCode, since: Date)
    -> AsyncThrowingStream<[SeriesPoint], Error>
  {
    let records = observeBodyCompositionRecords(member: member, since: since)
    return AsyncThrowingStream { continuation in
      let task = Task {
        do {
          for try await list in records {
            continuation.yield(BodyCompositionSeries.points(from: list, metricCode: metricCode))
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  // MARK: - DeviceModelCatalog

  public func recentDeviceModels() async throws -> [String] {
    try await outbox.deviceModelNames()
  }

  public func addDeviceModel(_ name: String) async throws -> String {
    guard let stored = DeviceModelName.storable(name) else { throw DeviceModelCatalogError.invalidName }
    try await outbox.useDeviceModel(stored, at: now())
    return stored
  }
}

/// Wakes the readers of one member after a local save.
final class MemberChangeSignal: @unchecked Sendable {
  private let lock = NSLock()
  private var handlers: [UUID: (member: MemberKey, wake: @Sendable () -> Void)] = [:]

  func subscribe(_ member: MemberKey, wake: @escaping @Sendable () -> Void) -> UUID {
    let token = UUID()
    lock.withLock { handlers[token] = (member, wake) }
    return token
  }

  func unsubscribe(_ token: UUID) {
    _ = lock.withLock { handlers.removeValue(forKey: token) }
  }

  func notify(_ member: MemberKey) {
    let wakes = lock.withLock { handlers.values.filter { $0.member == member }.map(\.wake) }
    wakes.forEach { $0() }
  }
}

/// One `observeBodyCompositionRecords` subscription as an event loop: the server listener, local saves and the
/// drafts' sync states only post events; this loop alone reads the local drafts and writes the output, so answers stay
/// in order. Before the server's first answer (Firestore gives its cache at once, offline too) nothing is emitted, so
/// the list never flashes the local records alone. A server failure fails the stream (TR-03 shows `common.loadFailed`,
/// never an empty trend).
///
/// Every local draft has a `syncState`: `localSaved` until the engine's first value, then the engine's (a permanent
/// rejection is `syncFailed`). A state change also re-reads the drafts, so one the engine acked leaves the local list.
/// The engine reports `synced` before it saves the ack, so that read may still find the item in flight: a draft the
/// engine calls `synced` is left out either way, and every server answer re-reads the drafts too, so a record the
/// server later removes (DF-133) never comes back as a leftover draft (DF-127 second review).
private struct RecordsMerge {
  private enum Event: Sendable {
    case server([BodyCompositionRecord])
    case serverFailed(Error)
    case local
    case syncState(recordId: String, SyncState)
  }

  let member: MemberKey
  let since: Date
  let outbox: LocalOutboxStore
  let server: (any BodyCompositionRecordSource)?
  let changes: MemberChangeSignal
  let syncStates: LocalMeasurementStore.SyncStates?
  let output: AsyncThrowingStream<[BodyCompositionRecord], Error>.Continuation

  func run() async {
    let (events, post) = AsyncStream.makeStream(of: Event.self)
    let token = changes.subscribe(member) { post.yield(.local) }
    var listener: Task<Void, Never>?
    if let server {
      let records = server.observeRecords(member: member, since: since)
      listener = Task {
        do {
          for try await list in records { post.yield(.server(list)) }
        } catch {
          post.yield(.serverFailed(error))
        }
      }
    }
    /// One engine subscription per local draft, while the draft is unsynced.
    var watchers: [String: Task<Void, Never>] = [:]
    var states: [String: SyncState] = [:]
    defer {
      changes.unsubscribe(token)
      listener?.cancel()
      watchers.values.forEach { $0.cancel() }
      post.finish()
    }
    func watch(_ drafts: [BodyCompositionRecord]) {
      let ids = Set(drafts.map(\.id))
      for id in watchers.keys where !ids.contains(id) {
        watchers.removeValue(forKey: id)?.cancel()
        states.removeValue(forKey: id)
      }
      guard let syncStates else { return }
      for id in ids where watchers[id] == nil {
        watchers[id] = Task {
          for await state in await syncStates(BodyCompositionPayload.entityRef(recordId: id)) {
            post.yield(.syncState(recordId: id, state))
          }
        }
      }
    }
    func merged(server: [BodyCompositionRecord], local: [BodyCompositionRecord]) -> [BodyCompositionRecord] {
      let local = local.filter { states[$0.id] != .synced }.map { draft -> BodyCompositionRecord in
        var record = draft
        record.syncState = states[draft.id] ?? .localSaved
        return record
      }
      return BodyCompositionRecordMerge.merge(server: server, local: local)
    }
    var serverRecords: [BodyCompositionRecord]? = server == nil ? [] : nil
    var localRecords: [BodyCompositionRecord] = []
    do {
      localRecords = try await local()
    } catch {
      return output.finish(throwing: error)
    }
    watch(localRecords)
    if let serverRecords { output.yield(merged(server: serverRecords, local: localRecords)) }
    for await event in events {
      switch event {
      case let .server(list):
        serverRecords = list
      case let .serverFailed(error):
        return output.finish(throwing: error)
      case let .syncState(id, state):
        guard watchers[id] != nil, states[id] != state else { continue }
        states[id] = state
      case .local:
        break
      }
      do {
        localRecords = try await local()
      } catch {
        return output.finish(throwing: error)
      }
      watch(localRecords)
      if let serverRecords { output.yield(merged(server: serverRecords, local: localRecords)) }
    }
  }

  private func local() async throws -> [BodyCompositionRecord] {
    try await outbox.unsyncedBodyCompositionRecords(member: member).filter { $0.measuredAt >= since }
  }
}
