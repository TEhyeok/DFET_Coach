import Foundation
import os
import TrainerContracts
import TrainerDomain

/// Module marker for SyncEngine (DF-008 skeleton).
public enum SyncEngineModule {
  public static let name = "SyncEngine"
}

/// Applies Outbox items to the server in member order (DF-015, V1-04 §10, NFR-05, NFR-06).
///
/// - Each member's items run one at a time in `sequence` order; at most two members run at once (ASM-04-18).
/// - A consent item that fails blocks the member's other items as `awaitingConsent`; they make no remote call.
/// - Rule rejections and bad requests fail at once with no automatic retry. Transient errors back off
///   (`RetryPolicy`) and fail after five consecutive attempts. `retry(_:)` starts an item again from zero.
/// - `protectedDataUnavailable` pauses the engine until `protectedDataDidBecomeAvailable()`, without counting
///   the attempt (ASM-P0-29).
/// - `start()` puts items left `inFlight` by a killed process back in the queue; `RemoteWriter.createIfAbsent`
///   then avoids a second create (AC-DF-015.5).
/// - Local items are never deleted here: a failed item keeps its payload (NFR-06).
///
/// Network reachability, foreground and one-minute tick triggers are wired by the app (DF-104); they call `start()`,
/// `retryAll()` or `protectedDataDidBecomeAvailable()`.
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
  private var loadTask: Task<Void, Never>?
  private var running = false
  private var protectedDataAvailable = true
  private var activeMembers: Set<MemberKey> = []
  private var wakeup: (at: Date, task: Task<Void, Never>)?
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
    case unsupportedKind
    case malformedItem

    var code: String {
      switch self {
      case .uploadUnverified: return "upload-unverified"
      case .unsupportedKind: return "unsupported-kind"
      case .malformedItem: return "malformed-item"
      }
    }
  }

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

  /// Loads the Outbox (turning leftover `inFlight` items back into `queued`) and starts sending.
  public func start() async {
    await ensureLoaded()
    running = true
    pump()
  }

  /// Stops starting new items. A call already in flight finishes and its result is recorded.
  public func stop() {
    running = false
    wakeup?.task.cancel()
    wakeup = nil
    signalIdleIfNeeded()
  }

  public func enqueue(_ item: OutboxItem) async {
    await ensureLoaded()
    var item = item
    if item.stage != .consent, item.state == .queued, consentFailed(for: item.memberKey) {
      item.state = .blocked(.awaitingConsent)
    }
    await commit(item)
    pump()
  }

  /// Starts a failed item again with `attempts = 0`. Retrying a consent item releases the member's blocked items.
  public func retry(_ id: UUID) async {
    await ensureLoaded()
    guard var item = items[id], item.state == .failed else { return }
    item.attempts = 0
    item.state = .queued
    item.nextAttemptAt = clock.now()
    item.lastErrorCode = nil
    await commit(item)
    if item.stage == .consent {
      for var blocked in items.values where blocked.memberKey == item.memberKey && blocked.state == .blocked(.awaitingConsent) {
        blocked.state = .queued
        await commit(blocked)
      }
    }
    pump()
  }

  public func retryAll() async {
    await ensureLoaded()
    let failed = items.values.filter { $0.state == .failed }.sorted { $0.sequence < $1.sequence }
    for item in failed {
      await retry(item.id)
    }
  }

  /// Device unlocked: resume after `protectedDataUnavailable`.
  public func protectedDataDidBecomeAvailable() {
    protectedDataAvailable = true
    pump()
  }

  /// The entity's `syncState` now and after every change; a value is emitted only when it differs (AC-DF-015.6).
  public func syncState(for ref: LocalEntityRef) async -> AsyncStream<SyncState> {
    await ensureLoaded()
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

  /// Number of items that are not acked, now and after every change (AC-DF-015.7, M-G3).
  public func pendingCount() async -> AsyncStream<Int> {
    await ensureLoaded()
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
    await ensureLoaded()
    return items[id]
  }

  /// Returns when nothing can be sent right now: no member is running and no queued item is due, or the engine is
  /// stopped or paused. For tests and diagnostics.
  public func waitUntilIdle() async {
    if isIdle { return }
    if activeMembers.isEmpty { pump() }
    if isIdle { return }
    await withCheckedContinuation { idleWaiters.append($0) }
  }

  // MARK: - Loading and persistence

  private func ensureLoaded() async {
    if let loadTask {
      await loadTask.value
      return
    }
    let task = Task { await self.load() }
    loadTask = task
    await task.value
  }

  private func load() async {
    let stored: [OutboxItem]
    do {
      stored = try await store.loadAll()
    } catch {
      logger.error("outbox load failed")
      return
    }
    for var item in stored where items[item.id] == nil {
      if item.state == .inFlight {
        // The process ended before the reply: send again; createIfAbsent/update make this idempotent.
        item.state = .queued
        item.nextAttemptAt = clock.now()
        items[item.id] = item
        await persist(item)
      } else {
        items[item.id] = item
      }
    }
  }

  private func commit(_ item: OutboxItem) async {
    items[item.id] = item
    await persist(item)
    publishChanges()
  }

  private func persist(_ item: OutboxItem) async {
    do {
      try await store.save(item)
    } catch {
      logger.error("outbox save failed: stage=\(item.stage.rawValue, privacy: .public)")
    }
  }

  // MARK: - Scheduling

  private func pump() {
    guard running, protectedDataAvailable else {
      signalIdleIfNeeded()
      return
    }
    let now = clock.now()
    let candidates = Set(items.values.filter { $0.state != .acked }.map(\.memberKey))
      .filter { !activeMembers.contains($0) }
      .compactMap { member -> OutboxItem? in
        guard let head = head(of: member), isRunnable(head, now: now) else { return nil }
        return head
      }
      .sorted { ($0.createdAt, $0.sequence) < ($1.createdAt, $1.sequence) }
    for head in candidates where activeMembers.count < Self.maxParallelMembers {
      let member = head.memberKey
      activeMembers.insert(member)
      Task { await self.runMember(member) }
    }
    scheduleWakeup(now: now)
    signalIdleIfNeeded()
  }

  private func runMember(_ member: MemberKey) async {
    while running, protectedDataAvailable, let head = head(of: member), isRunnable(head, now: clock.now()) {
      await execute(head)
    }
    activeMembers.remove(member)
    pump()
  }

  /// The member's first item that is not acked. Later items wait behind it, whatever its state.
  private func head(of member: MemberKey) -> OutboxItem? {
    items.values
      .filter { $0.memberKey == member && $0.state != .acked }
      .min { $0.sequence < $1.sequence }
  }

  private func isRunnable(_ item: OutboxItem, now: Date) -> Bool {
    item.state == .queued
      && item.nextAttemptAt <= now
      && item.dependsOn.allSatisfy { items[$0].map { $0.state == .acked } ?? true }
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
    guard running, protectedDataAvailable else { return activeMembers.isEmpty }
    guard activeMembers.isEmpty else { return false }
    let now = clock.now()
    let members = Set(items.values.filter { $0.state != .acked }.map(\.memberKey))
    return !members.contains { member in head(of: member).map { isRunnable($0, now: now) } ?? false }
  }

  private func signalIdleIfNeeded() {
    guard !idleWaiters.isEmpty, isIdle else { return }
    let waiters = idleWaiters
    idleWaiters = []
    waiters.forEach { $0.resume() }
  }

  // MARK: - Execution

  private func execute(_ original: OutboxItem) async {
    var item = original
    item.attempts += 1
    item.state = .inFlight
    await commit(item)

    let result: Result<OutboxAck, Error>
    do {
      result = .success(try await perform(item))
    } catch {
      result = .failure(error)
    }

    guard var current = items[item.id] else { return }
    switch result {
    case let .success(ack):
      current.state = .acked
      current.ack = ack
      current.lastErrorCode = nil
      await commit(current)
    case let .failure(error):
      await handle(error, for: current)
    }
  }

  private func perform(_ item: OutboxItem) async throws -> OutboxAck {
    switch (item.kind, item.target) {
    case let (.createDocument, .document(path)):
      guard let fields = item.payload else { throw LocalFailure.malformedItem }
      return .write(try await writer.createIfAbsent(path: path, fields: fields))
    case let (.updateDocument, .document(path)), let (.recordBinaryPath, .document(path)),
         let (.finalize, .document(path)):
      guard let fields = item.payload else { throw LocalFailure.malformedItem }
      return .write(try await writer.update(path: path, fields: fields))
    case let (.uploadBinary, .storage(path)):
      guard let binary = item.binary else { throw LocalFailure.malformedItem }
      let receipt = try await uploader.upload(
        localURL: binary.localURL, path: path, contentType: binary.contentType, sha256: binary.sha256)
      guard receipt.verified else { throw LocalFailure.uploadUnverified }
      return .upload(receipt)
    case let (.callConsent, .callable(name)), let (.callFunction, .callable(name)):
      let _: CallableAck = try await callable.call(name, item.payload ?? .object([:]))
      return .call
    case (.deleteDocument, _), (.deleteBinary, _):
      throw LocalFailure.unsupportedKind  // no delete in the P0 RemoteWriter contract
    default:
      throw LocalFailure.malformedItem  // kind and target do not match
    }
  }

  private func handle(_ error: Error, for original: OutboxItem) async {
    var item = original
    let code: String
    let disposition: RetryPolicy.Disposition
    switch error {
    case let remote as RemoteError:
      code = remote.code
      disposition = RetryPolicy.disposition(for: remote)
    case let local as LocalFailure:
      code = local.code
      disposition = local == .uploadUnverified ? .retry : .permanent
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
      protectedDataAvailable = false
    }
    logger.notice(
      "item \(item.state == .failed ? "failed" : "deferred", privacy: .public): stage=\(item.stage.rawValue, privacy: .public) code=\(code, privacy: .public) attempts=\(item.attempts, privacy: .public)")
    await commit(item)

    if item.state == .failed, item.stage == .consent {
      await blockMember(item.memberKey)
    }
  }

  /// The consent capture failed: the member's other items wait for consent and make no remote call (AC-DF-015.2).
  private func blockMember(_ member: MemberKey) async {
    for var other in items.values where other.memberKey == member && other.stage != .consent && other.state == .queued {
      other.state = .blocked(.awaitingConsent)
      await commit(other)
    }
  }

  private func consentFailed(for member: MemberKey) -> Bool {
    items.values.contains { $0.memberKey == member && $0.stage == .consent && $0.state == .failed }
  }

  // MARK: - State streams

  private func computeState(for ref: LocalEntityRef) -> SyncState {
    let entityItems = items.values.filter { $0.entityRef == ref }
    guard let member = entityItems.first?.memberKey else {
      return SyncStateCalculator.state(consentConfirmed: true, items: [])
    }
    let isConsentEntity = entityItems.allSatisfy { $0.stage == .consent }
    let consentConfirmed = isConsentEntity
      || !items.values.contains { $0.memberKey == member && $0.stage == .consent && $0.state != .acked }
    return SyncStateCalculator.state(
      consentConfirmed: consentConfirmed, items: entityItems.map(SyncStateCalculator.Item.init))
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
