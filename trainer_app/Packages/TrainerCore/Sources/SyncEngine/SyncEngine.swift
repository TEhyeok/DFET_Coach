import Foundation
import os
import TrainerContracts
import TrainerDomain

/// Module marker for SyncEngine (DF-008 skeleton).
public enum SyncEngineModule {
  public static let name = "SyncEngine"
}

/// Applies Outbox items to the server in NFR-05 order (DF-015, V1-04 §10, NFR-05, NFR-06).
///
/// Ordering
/// - One call at a time per member; at most two members at once (ASM-04-18).
/// - Inside an entity, items run in `sequence` order; a failed item holds back only the rest of its own entity, whose
///   `syncState` then reads `syncFailed` (a failure never hides another record behind "기기에 저장됨").
/// - Member gates by stage: every item after ⓪ waits for the member's pending-member create; every item after ① waits
///   until the member's latest consent capture is acked. When that capture fails, the member's records become
///   `blocked(awaitingConsent)` and make no remote call (AC-DF-015.2); a new capture or a retry releases them.
///
/// Failures
/// - Rule rejections and bad requests fail at once (AC-DF-015.3). Transient errors, unverified uploads and writes that
///   the server did not commit back off (`RetryPolicy`) and fail after five consecutive attempts (AC-DF-015.4).
/// - `retry(_:)` and `retryAll()` are the trainer's "다시 시도". Automatic triggers use `retryExhausted()`, which never
///   resends a rule rejection.
/// - `protectedDataUnavailable` (device locked, ASM-P0-29) and a failed local save pause sending until
///   `protectedDataDidBecomeAvailable()` or `start()`; the attempt is not counted.
///
/// State
/// - Every in-memory transition happens without a suspension point, then `flush()` writes the changed items to the
///   `OutboxStore` in order. So an actor re-entry never sees a half-applied change.
/// - `start()` puts items left `inFlight` by a killed process back in the queue; `RemoteWriter.createIfAbsent` then
///   avoids a second create (AC-DF-015.5). If loading fails, nothing is sent until a later `start()` loads.
/// - Local items are never deleted here: a failed item keeps its payload (NFR-06).
///
/// Wiring (DF-104): the app calls `start()` on launch and foreground, `networkDidChange(isReachable:)` from its
/// network monitor, `protectedDataDidBecomeAvailable()` on unlock, and `retry(_:)`/`retryAll()` from the UI.
public actor SyncEngine {
  public static let maxParallelMembers = 2

  private let store: any OutboxStore
  private let writer: any RemoteWriter
  private let uploader: any BinaryUploader
  private let callable: any CallableClient
  private let clock: any SyncClock
  private let policy: RetryPolicy
  private let jitter: @Sendable () -> Double
  private let logger = Logger(subsystem: "kr.co.dfet.trainer", category: "sync")

  private var items: [UUID: OutboxItem] = [:]
  private var loaded = false
  private var loadTask: Task<Bool, Never>?
  private var startRequested = false
  private var running = false
  private var pausedForLock = false
  private var pausedForStorage = false
  private var networkReachable = true
  /// Increments on every unlock, so a `protectedDataUnavailable` reply from before the unlock does not pause again.
  private var unlockEpoch = 0
  private var activeMembers: Set<MemberKey> = []
  private var wakeup: (at: Date, task: Task<Void, Never>)?
  private var dirty: Set<UUID> = []
  private var flushing = false
  private var flushWaiters: [CheckedContinuation<Void, Never>] = []
  private var stateSubscribers: [LocalEntityRef: [UUID: StateSubscriber]] = [:]
  private var countSubscribers: [UUID: CountSubscriber] = [:]
  private var idleWaiters: [CheckedContinuation<Void, Never>] = []

  private struct StateSubscriber {
    let continuation: AsyncStream<SyncState>.Continuation
    var last: SyncState
  }

  private struct CountSubscriber {
    let continuation: AsyncStream<Int>.Continuation
    var last: Int
  }

  /// Failures that come from the item or the device, not from the server.
  private enum LocalFailure: Error {
    case uploadUnverified
    case writeUncommitted
    case unsupportedKind
    case malformedItem

    var code: String {
      switch self {
      case .uploadUnverified: return "upload-unverified"
      case .writeUncommitted: return "write-uncommitted"
      case .unsupportedKind: return "unsupported-kind"
      case .malformedItem: return "malformed-item"
      }
    }
  }

  /// Error codes that `retryExhausted()` may resend: transient failures only.
  private static let transientCodes: Set<String> = [
    RemoteError.unavailable.code, RemoteError.deadlineExceeded.code, RemoteError.unknown("").code,
    LocalFailure.uploadUnverified.code, LocalFailure.writeUncommitted.code,
  ]

  /// `jitter` returns a value in -1...1; the default is uniform random.
  public init(
    store: any OutboxStore, writer: any RemoteWriter, uploader: any BinaryUploader, callable: any CallableClient,
    clock: any SyncClock = SystemSyncClock(), policy: RetryPolicy = .standard,
    jitter: @escaping @Sendable () -> Double = { Double.random(in: -1...1) }
  ) {
    self.store = store
    self.writer = writer
    self.uploader = uploader
    self.callable = callable
    self.clock = clock
    self.policy = policy
    self.jitter = jitter
  }

  // MARK: - Public API

  /// Loads the Outbox (turning leftover `inFlight` items back into `queued`) and starts sending. Called on launch and
  /// on every return to the foreground, which also clears a lock or storage pause (the device is unlocked then).
  public func start() async {
    startRequested = true
    guard await ensureLoaded() else {
      logger.error("sync not started: outbox load failed")
      return
    }
    running = true
    pausedForLock = false
    pausedForStorage = false
    pump()
    await flush()
  }

  /// Stops starting new calls. A call already in flight finishes and its result is recorded.
  public func stop() {
    startRequested = false
    running = false
    wakeup?.task.cancel()
    wakeup = nil
    signalIdleIfNeeded()
  }

  /// Adds new items. An id that is already known is ignored; states from the caller are reset to `queued`.
  public func enqueue(_ item: OutboxItem) async {
    await enqueue(contentsOf: [item])
  }

  /// Adds several items, then schedules once, so a batch is ordered by `sequence` even on a running engine.
  public func enqueue(contentsOf newItems: [OutboxItem]) async {
    _ = await ensureLoaded()
    for original in newItems.sorted(by: { $0.sequence < $1.sequence }) {
      guard items[original.id] == nil else {
        logger.notice("enqueue ignored: item already known")
        continue
      }
      var item = original
      item.state = .queued
      item.attempts = 0
      item.lastErrorCode = nil
      item.ack = nil
      item.nextAttemptAt = min(item.nextAttemptAt, clock.now())
      items[item.id] = item
      markDirty(item.id)
      if item.stage == .consent {
        unblockMember(item.memberKey)  // a new capture: records wait for it instead of the failed one
      } else if item.stage > .consent, latestConsentFailed(for: item.memberKey) {
        items[item.id]?.state = .blocked(.awaitingConsent)
      }
    }
    publishChanges()
    await flush()
    pump()
  }

  /// "다시 시도" for one failed item: starts it again with `attempts = 0`. Retrying the member's latest consent capture
  /// releases its blocked records.
  public func retry(_ id: UUID) async {
    _ = await ensureLoaded()
    guard resetFailed(id) else { return }
    publishChanges()
    pump()
    await flush()
  }

  /// "다시 시도" for every failed item, including rule rejections (the trainer asked).
  public func retryAll() async {
    _ = await ensureLoaded()
    for id in failedIds(where: { _ in true }) {
      _ = resetFailed(id)
    }
    publishChanges()
    pump()
    await flush()
  }

  /// Automatic trigger (network back, foreground tick): resends only items that ran out of transient attempts. A rule
  /// rejection stays failed until the trainer retries it (AC-DF-015.3).
  public func retryExhausted() async {
    _ = await ensureLoaded()
    for id in failedIds(where: { Self.transientCodes.contains($0.lastErrorCode ?? "") }) {
      _ = resetFailed(id)
    }
    publishChanges()
    pump()
    await flush()
  }

  /// Network monitor: no call starts while offline (V1-04 §10.1); coming back online resends exhausted items.
  public func networkDidChange(isReachable: Bool) async {
    networkReachable = isReachable
    if isReachable {
      await retryExhausted()
    } else {
      signalIdleIfNeeded()
    }
  }

  /// Device unlocked: resume after `protectedDataUnavailable` or a failed local save, and retry a failed load.
  public func protectedDataDidBecomeAvailable() async {
    unlockEpoch += 1
    pausedForLock = false
    pausedForStorage = false
    if startRequested, !running {
      await start()  // the earlier start could not load the Outbox
      return
    }
    pump()
    await flush()
  }

  /// The entity's `syncState` now and after every change; a value is emitted only when it differs (AC-DF-015.6).
  public func syncState(for ref: LocalEntityRef) async -> AsyncStream<SyncState> {
    _ = await ensureLoaded()
    let (stream, continuation) = AsyncStream.makeStream(of: SyncState.self)
    let id = UUID()
    let current = computeState(for: ref)
    stateSubscribers[ref, default: [:]][id] = StateSubscriber(continuation: continuation, last: current)
    continuation.yield(current)
    continuation.onTermination = { [weak self] _ in
      Task { await self?.removeStateSubscriber(ref: ref, id: id) }
    }
    return stream
  }

  /// Number of items that are not acked (failed and blocked included), now and after every change
  /// (AC-DF-015.7, M-G3).
  public func pendingCount() async -> AsyncStream<Int> {
    _ = await ensureLoaded()
    let (stream, continuation) = AsyncStream.makeStream(of: Int.self)
    let id = UUID()
    let current = computePendingCount()
    countSubscribers[id] = CountSubscriber(continuation: continuation, last: current)
    continuation.yield(current)
    continuation.onTermination = { [weak self] _ in
      Task { await self?.removeCountSubscriber(id: id) }
    }
    return stream
  }

  public func item(_ id: UUID) async -> OutboxItem? {
    _ = await ensureLoaded()
    return items[id]
  }

  /// Returns when nothing can be sent right now: no member is running and no queued item is due, or sending is
  /// stopped or paused. It never schedules work itself, so tests of the backoff wakeup stay honest.
  public func waitUntilIdle() async {
    if isIdle { return }
    await withCheckedContinuation { idleWaiters.append($0) }
  }

  // MARK: - Loading and persistence

  /// Loads once; a failed load is retried by the next call instead of being remembered.
  private func ensureLoaded() async -> Bool {
    if loaded { return true }
    if let loadTask { return await loadTask.value }
    let task = Task { await self.load() }
    loadTask = task
    let ok = await task.value
    loadTask = nil
    if ok { await flush() }  // persist the inFlight → queued resets now
    return ok
  }

  private func load() async -> Bool {
    let stored: [OutboxItem]
    do {
      stored = try await store.loadAll()
    } catch {
      logger.error("outbox load failed")
      return false
    }
    for var item in stored where items[item.id] == nil {
      if item.state == .inFlight {
        // The process ended before the reply: send again; createIfAbsent and update keep this idempotent.
        item.state = .queued
        item.nextAttemptAt = clock.now()
        markDirty(item.id)
      }
      items[item.id] = item
    }
    loaded = true
    publishChanges()
    return true
  }

  private func markDirty(_ id: UUID) {
    dirty.insert(id)
  }

  /// Writes every changed item, latest value first come first served. Concurrent callers wait for the same flush.
  /// A failed save keeps the item dirty and pauses sending until unlock or `start()`.
  private func flush() async {
    if flushing {
      await withCheckedContinuation { flushWaiters.append($0) }
      return
    }
    flushing = true
    while !pausedForStorage, let id = dirty.first {
      dirty.remove(id)
      guard let item = items[id] else { continue }
      do {
        try await store.save(item)
      } catch {
        dirty.insert(id)
        pausedForStorage = true
        logger.error("outbox save failed: stage=\(item.stage.rawValue, privacy: .public); sending paused")
      }
    }
    flushing = false
    let waiters = flushWaiters
    flushWaiters = []
    waiters.forEach { $0.resume() }
    signalIdleIfNeeded()
  }

  // MARK: - Scheduling

  private var canSend: Bool {
    running && !pausedForLock && !pausedForStorage && networkReachable
  }

  private func pump() {
    guard canSend else {
      signalIdleIfNeeded()
      return
    }
    let now = clock.now()
    let candidates = Set(items.values.filter { $0.state == .queued }.map(\.memberKey))
      .subtracting(activeMembers)
      .compactMap { nextRunnable(for: $0, now: now) }
      .sorted { ($0.createdAt, $0.sequence) < ($1.createdAt, $1.sequence) }
    for next in candidates where activeMembers.count < Self.maxParallelMembers {
      let member = next.memberKey
      activeMembers.insert(member)
      Task { await self.runMember(member) }
    }
    scheduleWakeup(now: now)
    signalIdleIfNeeded()
  }

  private func runMember(_ member: MemberKey) async {
    while canSend, let next = nextRunnable(for: member, now: clock.now()) {
      await execute(next.id)
    }
    activeMembers.remove(member)
    pump()
  }

  /// The member's lowest-sequence item that may run now.
  private func nextRunnable(for member: MemberKey, now: Date) -> OutboxItem? {
    items.values
      .filter { $0.memberKey == member && $0.state == .queued }
      .sorted { $0.sequence < $1.sequence }
      .first { isRunnable($0, now: now) }
  }

  private func isRunnable(_ item: OutboxItem, now: Date) -> Bool {
    guard item.state == .queued, item.nextAttemptAt <= now else { return false }
    // Explicit dependencies. A dependency that is not in the Outbox counts as done: Outbox rows of synced work may be
    // purged by LocalStore retention, and a dependent must not wait forever for a row that no longer exists.
    guard item.dependsOn.allSatisfy({ items[$0].map { $0.state == .acked } ?? true }) else { return false }
    // Entity order: earlier steps of the same record first (create → upload → path → finalize).
    guard !items.values.contains(where: {
      $0.entityRef == item.entityRef && $0.sequence < item.sequence && $0.state != .acked
    }) else { return false }
    // Member gates: ⓪ pending-member create before anything else; ① latest consent capture before records.
    if item.stage > .memberKey, items.values.contains(where: {
      $0.memberKey == item.memberKey && $0.stage == .memberKey && $0.state != .acked
    }) {
      return false
    }
    if item.stage > .consent, let consent = latestConsent(for: item.memberKey), consent.state != .acked {
      return false
    }
    return true
  }

  private func scheduleWakeup(now: Date) {
    let next = items.values
      .filter { $0.state == .queued && $0.nextAttemptAt > now }
      .map(\.nextAttemptAt)
      .min()
    guard let next else {
      wakeup?.task.cancel()
      wakeup = nil
      return
    }
    if let wakeup, wakeup.at <= next { return }
    wakeup?.task.cancel()
    let clock = clock
    let task = Task { [weak self] in
      do {
        try await clock.sleep(until: next)
      } catch {
        return
      }
      await self?.wakeupFired(at: next)
    }
    wakeup = (next, task)
  }

  private func wakeupFired(at date: Date) {
    if wakeup?.at == date { wakeup = nil }
    pump()
  }

  private var isIdle: Bool {
    guard activeMembers.isEmpty, !flushing else { return false }
    guard canSend else { return true }
    let now = clock.now()
    let members = Set(items.values.filter { $0.state == .queued }.map(\.memberKey))
    return !members.contains { nextRunnable(for: $0, now: now) != nil }
  }

  private func signalIdleIfNeeded() {
    guard !idleWaiters.isEmpty, isIdle else { return }
    let waiters = idleWaiters
    idleWaiters = []
    waiters.forEach { $0.resume() }
  }

  // MARK: - Execution

  private func execute(_ id: UUID) async {
    guard var item = items[id], item.state == .queued else { return }
    item.attempts += 1
    item.state = .inFlight
    items[id] = item
    markDirty(id)
    publishChanges()
    await flush()  // record inFlight before the call, so a restart re-checks it (AC-DF-015.5)

    let epoch = unlockEpoch
    let result: Result<OutboxAck, Error>
    do {
      result = .success(try await perform(item))
    } catch {
      result = .failure(error)
    }

    // Re-read after the suspension; only this task changes an inFlight item.
    guard var current = items[id], current.state == .inFlight else { return }
    switch result {
    case let .success(ack):
      current.state = .acked
      current.ack = ack
      current.lastErrorCode = nil
      items[id] = current
    case let .failure(error):
      apply(error, to: &current, unlockEpochAtStart: epoch)
      items[id] = current
      if current.state == .failed, current.stage == .consent, isLatestConsent(current) {
        blockMember(current.memberKey)
      }
    }
    markDirty(id)
    publishChanges()
    pump()  // an ack can release another member's dependent item
    await flush()
  }

  private func perform(_ item: OutboxItem) async throws -> OutboxAck {
    switch (item.kind, item.target) {
    case let (.createDocument, .document(path)):
      guard let fields = item.payload else { throw LocalFailure.malformedItem }
      return try committed(await writer.createIfAbsent(path: path, fields: fields))
    case let (.updateDocument, .document(path)), let (.recordBinaryPath, .document(path)),
         let (.finalize, .document(path)):
      guard let fields = item.payload else { throw LocalFailure.malformedItem }
      return try committed(await writer.update(path: path, fields: fields))
    case let (.uploadBinary, .storage(path)):
      guard let binary = item.binary else { throw LocalFailure.malformedItem }
      let receipt = try await uploader.upload(
        localURL: binary.localURL, path: path, contentType: binary.contentType, sha256: binary.sha256)
      guard receipt.verified else { throw LocalFailure.uploadUnverified }
      return .upload(receipt)
    case let (.callConsent, .callable(name)):
      // recordConsent's idempotency key is the capture ID (V1-06 §6.2.5); requestId equals it for consent items.
      let payload = Self.adding("clientCaptureId", item.requestId, to: item.payload)
      let _: CallableAck = try await callable.call(name, payload)
      return .call
    case let (.callFunction, .callable(name)):
      let payload = Self.adding("requestId", item.requestId, to: item.payload)
      let _: CallableAck = try await callable.call(name, payload)
      return .call
    case (.deleteDocument, _), (.deleteBinary, _):
      throw LocalFailure.unsupportedKind  // no delete in the P0 RemoteWriter contract (DF-104 adds it)
    default:
      throw LocalFailure.malformedItem  // kind and target do not match
    }
  }

  /// A write the server did not confirm is not a success: later steps must not build on it (NFR-05 ②).
  private func committed(_ ack: WriteAck) throws -> OutboxAck {
    guard ack.serverCommitted else { throw LocalFailure.writeUncommitted }
    return .write(ack)
  }

  private static func adding(_ key: String, _ id: UUID, to payload: JSONValue?) -> JSONValue {
    var fields: [String: JSONValue] = [:]
    if case let .object(existing)? = payload { fields = existing }
    if fields[key] == nil { fields[key] = .string(id.uuidString.lowercased()) }
    return .object(fields)
  }

  /// Applies a failed attempt to `item` synchronously.
  private func apply(_ error: Error, to item: inout OutboxItem, unlockEpochAtStart epoch: Int) {
    let code: String
    let disposition: RetryPolicy.Disposition
    switch error {
    case let remote as RemoteError:
      code = remote.code
      disposition = RetryPolicy.disposition(for: remote)
    case let local as LocalFailure:
      code = local.code
      disposition = (local == .uploadUnverified || local == .writeUncommitted) ? .retry : .permanent
    default:
      code = "unknown"
      disposition = .retry
    }
    item.lastErrorCode = code

    switch disposition {
    case .permanent:
      item.state = .failed
    case .retry where policy.isExhausted(attempts: item.attempts):
      item.state = .failed
    case .retry:
      item.state = .queued
      item.nextAttemptAt = clock.now().addingTimeInterval(policy.delay(afterAttempts: item.attempts, jitterUnit: jitter()))
    case .waitForUnlock:
      item.attempts -= 1
      item.state = .queued
      item.nextAttemptAt = clock.now()
      if unlockEpoch == epoch {
        pausedForLock = true  // no unlock arrived while the call was out
      }
    }
    let outcome = item.state == .failed ? "failed" : "deferred"
    let stage = item.stage.rawValue
    let attempts = item.attempts
    logger.notice(
      "item \(outcome, privacy: .public): stage=\(stage, privacy: .public) code=\(code, privacy: .public) attempts=\(attempts, privacy: .public)")
  }

  // MARK: - Consent gate and retries (all synchronous)

  private func latestConsent(for member: MemberKey) -> OutboxItem? {
    items.values
      .filter { $0.memberKey == member && $0.stage == .consent }
      .max { $0.sequence < $1.sequence }
  }

  private func isLatestConsent(_ item: OutboxItem) -> Bool {
    latestConsent(for: item.memberKey)?.id == item.id
  }

  private func latestConsentFailed(for member: MemberKey) -> Bool {
    latestConsent(for: member)?.state == .failed
  }

  /// The latest consent capture failed: the member's waiting records make no remote call (AC-DF-015.2).
  private func blockMember(_ member: MemberKey) {
    for (id, item) in items where item.memberKey == member && item.stage > .consent && item.state == .queued {
      items[id]?.state = .blocked(.awaitingConsent)
      markDirty(id)
    }
  }

  private func unblockMember(_ member: MemberKey) {
    for (id, item) in items where item.memberKey == member && item.state == .blocked(.awaitingConsent) {
      items[id]?.state = .queued
      markDirty(id)
    }
  }

  private func failedIds(where include: (OutboxItem) -> Bool) -> [UUID] {
    items.values.filter { $0.state == .failed && include($0) }.sorted { $0.sequence < $1.sequence }.map(\.id)
  }

  /// Resets one failed item synchronously. Returns false when the item is not failed.
  private func resetFailed(_ id: UUID) -> Bool {
    guard var item = items[id], item.state == .failed else { return false }
    item.attempts = 0
    item.state = .queued
    item.nextAttemptAt = clock.now()
    item.lastErrorCode = nil
    items[id] = item
    markDirty(id)
    if item.stage == .consent, isLatestConsent(item) {
      unblockMember(item.memberKey)
    }
    return true
  }

  // MARK: - State streams

  private func computeState(for ref: LocalEntityRef) -> SyncState {
    let entityItems = items.values.filter { $0.entityRef == ref }
    guard let member = entityItems.first?.memberKey else {
      return SyncStateCalculator.state(consentConfirmed: true, items: [])
    }
    var consentConfirmed = true
    var upstreamFailed = false
    // Member gates apply only while the entity still has work: a synced record stays synced when a new capture starts.
    if entityItems.contains(where: { $0.state != .acked }) {
      let ownStage = entityItems.map(\.stage).min() ?? .document
      if ownStage > .consent, let consent = latestConsent(for: member) {
        consentConfirmed = consent.state == .acked
      }
      if ownStage > .memberKey {
        upstreamFailed = items.values.contains { $0.memberKey == member && $0.stage == .memberKey && $0.state == .failed }
      }
    }
    return SyncStateCalculator.state(
      consentConfirmed: consentConfirmed, upstreamFailed: upstreamFailed,
      items: entityItems.map(SyncStateCalculator.Item.init))
  }

  private func computePendingCount() -> Int {
    items.values.filter { $0.state != .acked }.count
  }

  private func publishChanges() {
    for (ref, subscribers) in stateSubscribers {
      let state = computeState(for: ref)
      for (id, subscriber) in subscribers where subscriber.last != state {
        subscriber.continuation.yield(state)
        stateSubscribers[ref]?[id]?.last = state
      }
    }
    let count = computePendingCount()
    for (id, subscriber) in countSubscribers where subscriber.last != count {
      subscriber.continuation.yield(count)
      countSubscribers[id]?.last = count
    }
  }

  private func removeStateSubscriber(ref: LocalEntityRef, id: UUID) {
    stateSubscribers[ref]?[id] = nil
    if stateSubscribers[ref]?.isEmpty == true { stateSubscribers[ref] = nil }
  }

  private func removeCountSubscriber(id: UUID) {
    countSubscribers[id] = nil
  }
}

/// Callable results are not needed by the engine; any JSON object decodes.
private struct CallableAck: Decodable, Sendable {
  init(from decoder: Decoder) throws {}
}
