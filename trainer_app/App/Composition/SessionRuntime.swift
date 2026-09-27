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
}

/// Sends only while `trainerUid` is the signed-in user. Otherwise nothing is sent and `RemoteError.signedOut` makes the
/// SyncEngine wait for that trainer's next session, instead of the rules rejecting the item for good (review H1:
/// sign-out, claim loss, or another trainer on the same iPad).
struct SessionBoundRemote: RemoteWriter, BinaryUploader, CallableClient {
  let trainerUid: String
  let remote: SyncRemote

  private func requireSession() throws {
    guard remote.currentUid() == trainerUid else { throw RemoteError.signedOut }
  }

  func createIfAbsent(path: String, fields: JSONValue) async throws -> WriteAck {
    try requireSession()
    return try await remote.writer.createIfAbsent(path: path, fields: fields)
  }

  func update(path: String, fields: JSONValue) async throws -> WriteAck {
    try requireSession()
    return try await remote.writer.update(path: path, fields: fields)
  }

  func delete(path: String) async throws -> WriteAck {
    try requireSession()
    return try await remote.writer.delete(path: path)
  }

  func upload(localURL: URL, path: String, contentType: String, sha256: String) async throws -> UploadReceipt {
    try requireSession()
    return try await remote.uploader.upload(localURL: localURL, path: path, contentType: contentType, sha256: sha256)
  }

  func delete(path: String) async throws {
    try requireSession()
    try await remote.uploader.delete(path: path)
  }

  func call<T: Decodable & Sendable>(_ name: String, _ payload: JSONValue) async throws -> T {
    try requireSession()
    return try await remote.callable.call(name, payload)
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
  let registrar: any PendingMemberRegistrar
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
    let outbox = LocalOutboxStore(container: container, trainerUid: trainerUid, binaries: LocalBinaryStore(location: location))
    let bound = SessionBoundRemote(trainerUid: trainerUid, remote: remote)
    let engine = SyncEngine(store: outbox, writer: bound, uploader: bound, callable: bound)
    self.engine = engine
    sessions = remote.sessions
    registrar = LocalPendingMemberRegistrar(outbox: outbox, trainerUid: trainerUid, enqueue: { await engine.enqueue($0) })
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
        if session?.uid == uid { self.resume() } else { self.suspend() }
      }
    }
  }

  func deactivate() {
    sessionTask?.cancel()
    sessionTask = nil
    suspend()
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

  private func suspend() {
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

  /// One runtime at a time: the current trainer's, created on first use and kept across view updates. Another
  /// trainer's sign-in replaces it (DF-018 adds the full sign-out teardown).
  @MainActor
  final class Cache {
    static let shared = Cache()
    private var current: SessionRuntime?

    func runtime(trainerUid: String, remote: () -> SyncRemote) -> SessionRuntime? {
      if let current, current.trainerUid == trainerUid { return current }
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
