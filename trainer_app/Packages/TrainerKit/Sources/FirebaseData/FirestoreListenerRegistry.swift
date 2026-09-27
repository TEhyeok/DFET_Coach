import FirebaseFirestore
import Foundation
import os

/// Every live Firestore snapshot listener of this app (DF-018, AC-DF-018.1). Logout removes them all before it
/// terminates Firestore, and `count` lets tests see that none is left.
public final class FirestoreListenerRegistry: @unchecked Sendable {
  public static let shared = FirestoreListenerRegistry()

  private let lock = NSLock()
  private var registrations: [UUID: Registration] = [:]

  private struct Registration {
    let listener: any ListenerRegistration
    let onRemoved: @Sendable () -> Void
  }

  /// Keeps `registration` until `remove(_:)` or `removeAll()`. `onRemoved` ends the stream the listener feeds when
  /// `removeAll()` takes it away: a removed listener never calls back, so a screen kept after a failed logout would
  /// otherwise wait on it forever instead of offering '다시 시도' and subscribing again.
  func add(_ registration: any ListenerRegistration, onRemoved: @escaping @Sendable () -> Void) -> UUID {
    let token = UUID()
    lock.withLock { registrations[token] = Registration(listener: registration, onRemoved: onRemoved) }
    return token
  }

  /// Removes one listener (its stream ended).
  func remove(_ token: UUID) {
    let registration = lock.withLock { registrations.removeValue(forKey: token) }
    registration?.listener.remove()
  }

  /// Removes every listener and ends its stream (logout).
  public func removeAll() {
    let all = lock.withLock { () -> [Registration] in
      defer { registrations.removeAll() }
      return Array(registrations.values)
    }
    for registration in all {
      registration.listener.remove()
      registration.onRemoved()
    }
  }

  public var count: Int { lock.withLock { registrations.count } }
}

/// The Firestore half of logout (DF-018, V1-04 §12.2, ASM-P0-17): every listener removed, the instance terminated and
/// its local cache cleared. A new instance, configured with the same settings, serves the next sign-in.
public enum FirestoreSessionTeardown {
  private static let logger = Logger(subsystem: "kr.co.dfet.trainer", category: "session")

  public static func run() async throws {
    FirestoreListenerRegistry.shared.removeAll()
    let firestore = Firestore.firestore()
    try await firestore.terminate()
    // Settings first, then the first use of the next instance (AC-DF-104.1), even when clearing fails: otherwise an
    // emulator build's next instance would point at the production host.
    defer {
      Firestore.firestore().settings = FirestoreConfigurator.settings(emulatorHost: FirebaseBootstrap.emulatorHost)
    }
    try await firestore.clearPersistence()
    logger.info("firestore cache cleared")
  }
}
