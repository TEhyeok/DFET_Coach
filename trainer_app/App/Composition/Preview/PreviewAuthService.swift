#if DEBUG
import Foundation
import TrainerDomain

/// `--preview-login` (DF-012, TC-DF012-04): a scripted `AuthService` with synthetic accounts and no Firebase.
/// The accounts exist only here; `example.invalid` never resolves.
final class PreviewAuthService: AuthService, @unchecked Sendable {
  /// Signs in with `password`.
  static let trainerEmail = "trainer@example.invalid"
  /// Always rejected as `.notTrainer`.
  static let memberEmail = "member@example.invalid"
  /// Always fails as `.network`.
  static let offlineEmail = "offline@example.invalid"
  /// Signs in with `password`; the next `refreshClaims()` (app returns to the foreground) revokes the claim.
  static let revokedEmail = "revoked@example.invalid"
  static let password = "preview-only-password"

  private let lock = NSLock()
  private var current: TrainerSession?
  private var revokeOnRefresh = false
  private var continuations: [UUID: AsyncStream<TrainerSession?>.Continuation] = [:]

  func signIn(email: String, password: String) async throws -> TrainerSession {
    switch email.lowercased() {
    case Self.memberEmail:
      throw AuthError.notTrainer
    case Self.offlineEmail:
      throw AuthError.network
    case Self.trainerEmail where password == Self.password, Self.revokedEmail where password == Self.password:
      let session = TrainerSession(uid: "syn-trainer", displayName: "SYN-TRAINER")
      lock.withLock { revokeOnRefresh = email.lowercased() == Self.revokedEmail }
      publish(session)
      return session
    default:
      throw AuthError.invalidCredentials
    }
  }

  func signOut(discardUnsynced: Bool) async throws {
    publish(nil)
  }

  func sessionStream() -> AsyncStream<TrainerSession?> {
    AsyncStream { continuation in
      let id = UUID()
      lock.withLock {
        continuations[id] = continuation
        continuation.yield(current)
      }
      continuation.onTermination = { [weak self] _ in
        self?.lock.withLock { _ = self?.continuations.removeValue(forKey: id) }
      }
    }
  }

  func refreshClaims() async {
    let revoke = lock.withLock { current != nil && revokeOnRefresh }
    if revoke { publish(nil) }
  }

  private func publish(_ session: TrainerSession?) {
    lock.withLock {
      current = session
      for continuation in continuations.values { continuation.yield(session) }
    }
  }
}
#endif
