import Foundation
import LocalStore
import Network
import os
import SwiftData
import SyncEngine
import TrainerDomain
import UIKit

/// The remote side of the SyncEngine for one trainer (FirebaseData, built in `FirebaseAppBootstrap`).
struct SyncRemote {
  let writer: any RemoteWriter
  let uploader: any BinaryUploader
  let callable: any CallableClient
  /// The signed-in user's uid at this moment; every send checks it (`SessionBoundRemote`).
  let currentUid: @Sendable () -> String?
  /// The auth session, current value first; the runtime sends only while it is this trainer's.
  let sessions: () -> AsyncStream<TrainerSession?>
  /// Asks Firebase Auth for a fresh ID token after an `unauthenticated` reply; true when the same user still has the
  /// trainer claim afterwards (V1-06 §8.7).
  var refreshSession: @Sendable () async -> Bool = { false }
}

/// After an `unauthenticated` reply for the signed-in trainer: one token refresh at a time and at most one a minute, so a
/// server that keeps refusing the token cannot drive a refresh-and-resend loop. A request inside the minute is kept
/// (one at most) and runs when the minute is over, so sending never waits for the next foreground. A successful refresh
/// restarts sending itself, because Firebase Auth publishes no new session when the refreshed token is unchanged.
final class SessionRefresher: @unchecked Sendable {
  static let defaultInterval: TimeInterval = 60

  private let refresh: @Sendable () async -> Bool
  private let now: @Sendable () -> Date
  private let minimumInterval: TimeInterval
  private let lock = NSLock()
  private var inFlight = false
  private var lastStarted: Date?
  /// The kept request; the id lets its timer clear only itself.
  private var deferred: (id: UUID, task: Task<Void, Never>)?
  private var refreshed: (@Sendable () async -> Void)?

  init(
    refresh: @escaping @Sendable () async -> Bool, now: @escaping @Sendable () -> Date = Date.init,
    minimumInterval: TimeInterval = SessionRefresher.defaultInterval
  ) {
    self.refresh = refresh
    self.now = now
    self.minimumInterval = minimumInterval
  }

  /// Drops a kept request (the runtime stopped sending).
  func cancel() {
    lock.withLock {
      deferred?.task.cancel()
      deferred = nil
    }
  }

  /// Deciding and storing happen under one lock, and the timer needs that lock to run its request, so it can never
  /// finish before it is stored and leave a stale entry that drops later requests.
  private func keep(for wait: TimeInterval) {
    lock.withLock {
      guard deferred == nil else { return }
      let id = UUID()
      let task = Task { [weak self] in
        try? await Task.sleep(nanoseconds: UInt64(max(wait, 0) * 1_000_000_000))
        guard !Task.isCancelled, let self else { return }
        let mine = self.lock.withLock { () -> Bool in
          guard self.deferred?.id == id else { return false }
          self.deferred = nil
          return true
        }
        if mine { self.unauthenticated() }
      }
      deferred = (id, task)
    }
  }

  /// What to run after a successful refresh (the runtime starts its engine).
  func onRefreshed(_ action: @escaping @Sendable () async -> Void) {
    lock.withLock { refreshed = action }
  }

  func unauthenticated() {
    let decision = lock.withLock { () -> (start: Bool, wait: TimeInterval?) in
      if inFlight { return (false, nil) }
      if let lastStarted {
        let elapsed = now().timeIntervalSince(lastStarted)
        if elapsed < minimumInterval { return (false, deferred == nil ? minimumInterval - elapsed : nil) }
      }
      inFlight = true
      lastStarted = now()
      return (true, nil)
    }
    if let wait = decision.wait { keep(for: wait) }
    guard decision.start else { return }
    Task {
      let ok = await refresh()
      let action = lock.withLock { () -> (@Sendable () async -> Void)? in
        inFlight = false
        return refreshed
      }
      if ok { await action?() }
    }
  }
}

/// Sends only while `trainerUid` is the signed-in user. Otherwise nothing is sent and `RemoteError.signedOut` makes the
/// SyncEngine wait for that trainer's next session, instead of the rules rejecting the item for good (review H1:
/// sign-out, claim loss, or another trainer on the same iPad).
struct SessionBoundRemote: RemoteWriter, BinaryUploader, CallableClient {
  let trainerUid: String
  let remote: SyncRemote
  var onUnauthenticated: @Sendable () -> Void = {}

  private func requireSession() throws {
    guard remote.currentUid() == trainerUid else { throw RemoteError.signedOut }
  }

  /// A call cut off by a sign-out fails with the SDK's auth error; that is the session ending, not a rule rejection,
  /// so it waits for the next session too (#177 review M3).
  private func send<T>(_ call: () async throws -> T) async throws -> T {
    try requireSession()
    do {
      return try await call()
    } catch {
      if remote.currentUid() != trainerUid { throw RemoteError.signedOut }
      if case RemoteError.unauthenticated = error { onUnauthenticated() }
      throw error
    }
  }

  func createIfAbsent(path: String, fields: JSONValue) async throws -> WriteAck {
    try await send { try await remote.writer.createIfAbsent(path: path, fields: fields) }
  }

  func update(path: String, fields: JSONValue) async throws -> WriteAck {
    try await send { try await remote.writer.update(path: path, fields: fields) }
  }

  func delete(path: String) async throws -> WriteAck {
    try await send { try await remote.writer.delete(path: path) }
  }

  func upload(localURL: URL, path: String, contentType: String, sha256: String) async throws -> UploadReceipt {
    try await send {
      try await remote.uploader.upload(localURL: localURL, path: path, contentType: contentType, sha256: sha256)
    }
  }

  func delete(path: String) async throws {
    try await send { try await remote.uploader.delete(path: path) }
  }

  func call<T: Decodable & Sendable>(_ name: String, _ payload: JSONValue) async throws -> T {
    try await send { try await remote.callable.call(name, payload) }
  }
}

/// One signed-in trainer's local-first runtime (DF-108, V1-04 §9-§10): the LocalStore partition, the Outbox and the
/// SyncEngine. While the auth session is this trainer's, it runs as the SyncEngine's wiring asks: `start()` on resume
/// and on every return to the foreground, `retryExhausted()` on foreground and on a one-minute foreground tick,
/// `networkDidChange` from a path monitor (in order) and `protectedDataDidBecomeAvailable()` on unlock. When the
/// session ends (sign-out, claim loss) or belongs to someone else, it stops sending; the same trainer's next session
/// resumes it (review H1).
@MainActor
final class SessionRuntime {
  private static let logger = Logger(subsystem: "kr.co.dfet.trainer", category: "session")

  let trainerUid: String
  let engine: SyncEngine
  let outbox: LocalOutboxStore
  let registrar: any PendingMemberRegistrar
  private let refresher: SessionRefresher
  /// The trainer's LocalStore partition; logout purges what is synced from it (DF-018).
  let container: ModelContainer
  let location: LocalStoreLocation
  private let sessions: () -> AsyncStream<TrainerSession?>
  private var sessionTask: Task<Void, Never>?
  /// Set while sending runs: a new path monitor, its ordered consumer and the app lifecycle observers.
  private var triggers: Triggers?
  private var tick: Timer?

  private struct Triggers {
    let monitor: NWPathMonitor
    let paths: AsyncStream<Bool>.Continuation
    let consumer: Task<Void, Never>
    let observers: [NSObjectProtocol]
  }

  init(trainerUid: String, remote: SyncRemote) throws {
    self.trainerUid = trainerUid
    let location = try LocalStoreLocation.inApplicationSupport(trainerUid: trainerUid)
    let container = try LocalStoreContainer.make(location: location)
    self.container = container
    self.location = location
    let outbox = LocalOutboxStore(container: container, trainerUid: trainerUid, binaries: LocalBinaryStore(location: location))
    self.outbox = outbox
    let refresher = SessionRefresher(refresh: remote.refreshSession)
    self.refresher = refresher
    let bound = SessionBoundRemote(trainerUid: trainerUid, remote: remote, onUnauthenticated: refresher.unauthenticated)
    let engine = SyncEngine(store: outbox, writer: bound, uploader: bound, callable: bound)
    self.engine = engine
    sessions = remote.sessions
    registrar = LocalPendingMemberRegistrar(outbox: outbox, trainerUid: trainerUid, enqueue: { await engine.enqueue($0) })
    // Weak: the engine holds the remote, which holds the refresher; a strong runtime here would never be released.
    refresher.onRefreshed { [weak self] in await self?.restartAfterRefresh() }
  }

  /// A token refresh after `unauthenticated` worked. Sending restarts only while this runtime still sends: a logout
  /// that stopped it in the meantime wins.
  private func restartAfterRefresh() async {
    guard triggers != nil else { return }
    await engine.start()
  }

  /// Created for a signed-in session, so sending starts now; then it follows the session.
  func activate() {
    resume()
    guard sessionTask == nil else { return }
    let stream = sessions()
    let uid = trainerUid
    sessionTask = Task { [weak self] in
      for await session in stream {
        guard let self else { return }
        if session?.uid == uid { self.resumeOrRestart() } else { self.suspend() }
      }
    }
  }

  func deactivate() {
    sessionTask?.cancel()
    sessionTask = nil
    suspend()
  }

  /// The same trainer's session again (sign-in, or a refreshed token): start sending if stopped, otherwise restart the
  /// engine so a pause for an `unauthenticated` reply ends as soon as the token works again.
  private func resumeOrRestart() {
    if triggers == nil {
      resume()
    } else {
      let engine = engine
      Task { await engine.start() }
    }
  }

  private func resume() {
    guard triggers == nil else { return }
    let engine = engine
    let monitor = NWPathMonitor()
    let (paths, continuation) = AsyncStream.makeStream(of: Bool.self, bufferingPolicy: .bufferingNewest(1))
    // One consumer, so an offline/online flap is applied in the order it happened (review L2).
    let consumer = Task {
      for await reachable in paths { await engine.networkDidChange(isReachable: reachable) }
    }
    monitor.pathUpdateHandler = { path in continuation.yield(path.status == .satisfied) }
    monitor.start(queue: DispatchQueue(label: "kr.co.dfet.trainer.network"))
    let center = NotificationCenter.default
    let observers = [
      center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
        continuation.yield(monitor.currentPath.status == .satisfied)
        Task {
          await engine.start()
          await engine.retryExhausted()
        }
      },
      center.addObserver(forName: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil, queue: .main) { _ in
        Task { await engine.protectedDataDidBecomeAvailable() }
      },
      center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.stopTick() }
      },
      center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.startTick() }
      },
    ]
    triggers = Triggers(monitor: monitor, paths: continuation, consumer: consumer, observers: observers)
    startTick()
    Task { await engine.start() }
  }

  /// Logout step ② (V1-04 §12.2): the runtime stops following the session and sending, and an item already being
  /// sent gets up to `drainTimeout` to finish before Firestore is terminated under it. One cut off stays unsynced on
  /// the device. `waitUntilIdle()` ends when the group cancels it, so the bound holds even for a call that never
  /// returns (an offline Firestore write has no client timeout). `activate()` undoes this when the logout fails.
  func stopSending(drainTimeout: Duration) async {
    sessionTask?.cancel()
    sessionTask = nil
    suspend()
    let engine = engine
    await engine.stop()
    await withTaskGroup(of: Void.self) { group in
      group.addTask { await engine.waitUntilIdle() }
      group.addTask { try? await Task.sleep(for: drainTimeout) }
      await group.next()
      group.cancelAll()
    }
  }

  private func suspend() {
    refresher.cancel()
    guard let triggers else { return }
    triggers.monitor.cancel()
    triggers.paths.finish()
    triggers.observers.forEach(NotificationCenter.default.removeObserver)
    self.triggers = nil
    stopTick()
    let engine = engine
    Task { await engine.stop() }
  }

  private func startTick() {
    guard tick == nil, triggers != nil else { return }
    let engine = engine
    tick = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
      Task { await engine.retryExhausted() }
    }
  }

  private func stopTick() {
    tick?.invalidate()
    tick = nil
  }

  /// A registrar for a trainer whose LocalStore could not be opened: every save fails and says so on screen.
  struct UnavailableRegistrar: PendingMemberRegistrar {
    func register(_ draft: PendingMemberDraft) async throws -> String {
      throw LocalStoreUnavailable()
    }
  }

  struct LocalStoreUnavailable: Error {}

  /// The TR-15 queue when the LocalStore could not be opened: nothing is pending, nothing to retry.
  struct UnavailableSyncQueue: SyncQueueService {
    func pendingCount() async -> AsyncStream<Int> { AsyncStream { $0.yield(0) } }
    func failedItems() async -> AsyncStream<[OutboxItem]> { AsyncStream { $0.yield([]) } }
    func retry(_ id: UUID) async {}
    func retryAll() async {}
  }

  /// One runtime at a time: the current trainer's, created on first use and kept across view updates. Another
  /// trainer's sign-in replaces it; logout retires it (DF-018).
  @MainActor
  final class Cache {
    static let shared = Cache()
    private var current: SessionRuntime?
    /// The runtime whose logout is running. A view update in that time gets it back, stopped, instead of a new one
    /// that would start sending while Firestore is torn down (#177 review M2).
    private var retiring: SessionRuntime?

    /// Logout ②: takes `trainerUid`'s runtime out of use (V1-04 §12.2).
    func retire(trainerUid: String) -> SessionRuntime? {
      guard let current, current.trainerUid == trainerUid else { return nil }
      self.current = nil
      retiring = current
      return current
    }

    /// Logout ⑦, once Auth has signed out: the next sign-in gets a fresh runtime.
    func finishRetiring(_ runtime: SessionRuntime) {
      if retiring === runtime { retiring = nil }
    }

    /// Puts back a runtime whose logout failed; the trainer is still signed in, so it sends again.
    func reinstate(_ runtime: SessionRuntime) {
      if retiring === runtime { retiring = nil }
      guard current == nil else { return }
      current = runtime
      runtime.activate()
    }

    func runtime(trainerUid: String, remote: () -> SyncRemote) -> SessionRuntime? {
      if let current, current.trainerUid == trainerUid { return current }
      if let retiring, retiring.trainerUid == trainerUid { return retiring }
      current?.deactivate()
      current = nil
      do {
        let runtime = try SessionRuntime(trainerUid: trainerUid, remote: remote())
        runtime.activate()
        current = runtime
        return runtime
      } catch {
        logger.error("local store unavailable: \(String(describing: type(of: error)), privacy: .public)")
        return nil
      }
    }
  }
}
