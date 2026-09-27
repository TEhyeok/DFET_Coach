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
}

/// One signed-in trainer's local-first runtime (DF-108, V1-04 §9-§10): the LocalStore partition, the Outbox and the
/// SyncEngine, kept running as the SyncEngine's wiring asks: `start()` now and on every return to the foreground,
/// `retryExhausted()` on foreground and on a one-minute foreground tick, `networkDidChange` from a path monitor and
/// `protectedDataDidBecomeAvailable()` on unlock.
@MainActor
final class SessionRuntime {
  private static let logger = Logger(subsystem: "kr.co.dfet.trainer", category: "session")

  let trainerUid: String
  let engine: SyncEngine
  let registrar: any PendingMemberRegistrar
  private let monitor = NWPathMonitor()
  private var observers: [NSObjectProtocol] = []
  private var tick: Timer?

  init(trainerUid: String, remote: SyncRemote) throws {
    self.trainerUid = trainerUid
    let location = try LocalStoreLocation.inApplicationSupport(trainerUid: trainerUid)
    let container = try LocalStoreContainer.make(location: location)
    let outbox = LocalOutboxStore(container: container, trainerUid: trainerUid, binaries: LocalBinaryStore(location: location))
    let engine = SyncEngine(store: outbox, writer: remote.writer, uploader: remote.uploader, callable: remote.callable)
    self.engine = engine
    registrar = LocalPendingMemberRegistrar(
      container: container, outbox: outbox, trainerUid: trainerUid, enqueue: { await engine.enqueue($0) })
  }

  func activate() {
    let engine = engine
    monitor.pathUpdateHandler = { path in
      let reachable = path.status == .satisfied
      Task { await engine.networkDidChange(isReachable: reachable) }
    }
    monitor.start(queue: DispatchQueue(label: "kr.co.dfet.trainer.network"))
    let center = NotificationCenter.default
    observers = [
      center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
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
    startTick()
    Task { await engine.start() }
  }

  func deactivate() {
    monitor.cancel()
    observers.forEach(NotificationCenter.default.removeObserver)
    observers = []
    stopTick()
    let engine = engine
    Task { await engine.stop() }
  }

  private func startTick() {
    guard tick == nil else { return }
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
