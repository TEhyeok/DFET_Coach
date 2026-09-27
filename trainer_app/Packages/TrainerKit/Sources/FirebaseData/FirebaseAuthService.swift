import FirebaseAuth
import Foundation
import os
import TrainerDomain

/// Firebase implementation of `AuthService` (DF-012). The only place that talks to Firebase Auth.
///
/// - Sign-in forces a token refresh and requires the boolean `trainer` claim; otherwise it signs out and
///   throws `.notTrainer` (AC-DF-012.2).
/// - `sessionStream()` follows `addIDTokenDidChangeListener`; a token without the claim signs out, so the
///   stream emits `nil` (AC-DF-012.3, NFR-08).
/// - When the token cannot be checked because the device is offline, the cached sign-in is kept: the trainer
///   works local-first, and Firestore/Storage rules enforce the claim on every server request anyway.
/// - Errors are logged as codes only; the provider message (which can contain the email) is never logged
///   (AC-DF-012.4, NFR-10).
public final class FirebaseAuthService: AuthService, @unchecked Sendable {
  private let logger = Logger(subsystem: "kr.co.dfet.trainer", category: "auth")

  public init() {}

  public func signIn(email: String, password: String) async throws -> TrainerSession {
    let user: User
    do {
      user = try await Auth.auth().signIn(withEmail: email, password: password).user
    } catch {
      let mapped = FirebaseAuthErrorMapper.map(error)
      logger.error("sign-in failed: \(String(describing: mapped), privacy: .public) code=\((error as NSError).code, privacy: .public)")
      throw mapped
    }
    let claims: [String: Any]
    do {
      claims = try await user.getIDTokenResult(forcingRefresh: true).claims
    } catch {
      try? Auth.auth().signOut()
      let mapped = FirebaseAuthErrorMapper.map(error)
      logger.error("claim check failed: \(String(describing: mapped), privacy: .public)")
      throw mapped
    }
    guard TrainerClaims.isTrainer(claims) else {
      try? Auth.auth().signOut()
      logger.notice("sign-in rejected: no trainer claim")
      throw AuthError.notTrainer
    }
    return Self.session(for: user)
  }

  public func signOut(discardUnsynced: Bool) async throws {
    // DF-018 adds the unsynced-work check before this call; DF-012 guarantees the real Firebase sign-out.
    try Auth.auth().signOut()
  }

  public func sessionStream() -> AsyncStream<TrainerSession?> {
    AsyncStream { continuation in
      let handle = Auth.auth().addIDTokenDidChangeListener { _, user in
        guard let user else {
          continuation.yield(nil)
          return
        }
        user.getIDTokenResult(forcingRefresh: false) { [logger] result, error in
          if let result {
            if TrainerClaims.isTrainer(result.claims) {
              continuation.yield(Self.session(for: user))
            } else {
              // Claim gone: sign out. The listener fires again with `nil`.
              logger.notice("session locked: trainer claim missing")
              try? Auth.auth().signOut()
            }
          } else {
            // Offline or token service unavailable: keep the cached sign-in (see type comment).
            logger.notice("token check deferred: code=\(((error as NSError?)?.code ?? 0), privacy: .public)")
            continuation.yield(Self.session(for: user))
          }
        }
      }
      continuation.onTermination = { _ in
        Auth.auth().removeIDTokenDidChangeListener(handle)
      }
    }
  }

  public func refreshClaims() async {
    guard let user = Auth.auth().currentUser else { return }
    do {
      let result = try await user.getIDTokenResult(forcingRefresh: true)
      if !TrainerClaims.isTrainer(result.claims) {
        logger.notice("claim refresh: trainer claim missing, signing out")
        try? Auth.auth().signOut()
      }
    } catch {
      // Offline: keep the session; the next foreground refresh tries again.
      logger.notice("claim refresh deferred: code=\((error as NSError).code, privacy: .public)")
    }
  }

  private static func session(for user: User) -> TrainerSession {
    TrainerSession(uid: user.uid, displayName: user.displayName ?? "")
  }
}

/// Maps Firebase Auth errors to `AuthError` without looking at the message text.
enum FirebaseAuthErrorMapper {
  static func map(_ error: Error) -> AuthError {
    if let authError = error as? AuthError { return authError }
    let ns = error as NSError
    guard ns.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: ns.code) else {
      return ns.domain == NSURLErrorDomain ? .network : .unknown(code: ns.code)
    }
    switch code {
    case .wrongPassword, .invalidCredential, .userNotFound, .invalidEmail, .userDisabled:
      return .invalidCredentials
    case .networkError:
      return .network
    default:
      return .unknown(code: ns.code)
    }
  }
}
