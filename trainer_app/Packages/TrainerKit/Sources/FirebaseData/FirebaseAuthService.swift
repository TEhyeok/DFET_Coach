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
///   works local-first, and Firestore/Storage rules enforce the claim on every server request anyway. Any other
///   token error (disabled account, revoked or invalid token) signs out (`SessionTokenDecision`).
/// - Errors are logged as codes only; the provider message (which can contain the email) is never logged
///   (AC-DF-012.4, NFR-10).
public final class FirebaseAuthService: AuthService, Sendable {
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
      claims = try await Self.freshClaims(of: user)
    } catch {
      let mapped = FirebaseAuthErrorMapper.map(error)
      logger.error("claim check failed: \(String(describing: mapped), privacy: .public)")
      try signOutOrThrow()
      throw mapped
    }
    guard TrainerClaims.isTrainer(claims) else {
      logger.notice("sign-in rejected: no trainer claim")
      try signOutOrThrow()
      throw AuthError.notTrainer
    }
    return Self.session(for: user)
  }

  public func signOut(discardUnsynced: Bool) async throws {
    // DF-018 adds the unsynced-work check before this call; DF-012 guarantees the real Firebase sign-out.
    try signOutOrThrow()
  }

  /// Claims of a token refreshed from the server. If only the network failed, the token minted by this sign-in a
  /// moment ago is used instead, so a brief drop does not sign out a trainer whose session the listener may already
  /// have published.
  private static func freshClaims(of user: User) async throws -> [String: Any] {
    do {
      return try await user.getIDTokenResult(forcingRefresh: true).claims
    } catch where FirebaseAuthErrorMapper.map(error) == .network {
      return try await user.getIDTokenResult(forcingRefresh: false).claims
    }
  }

  /// Signs out, or throws when Firebase keeps the user (for example a keychain failure), so a rejected account is
  /// never reported as signed out while it is still signed in (AC-DF-012.2).
  private func signOutOrThrow() throws {
    do {
      try Auth.auth().signOut()
    } catch {
      let code = (error as NSError).code
      logger.fault("sign-out failed: code=\(code, privacy: .public)")
      throw AuthError.unknown(code: code)
    }
  }

  private func signOutLogged() {
    do {
      try Auth.auth().signOut()
    } catch {
      logger.fault("sign-out failed: code=\((error as NSError).code, privacy: .public)")
    }
  }

  public func sessionStream() -> AsyncStream<TrainerSession?> {
    AsyncStream { continuation in
      let handle = Auth.auth().addIDTokenDidChangeListener { [self] _, user in
        guard let user else {
          continuation.yield(nil)
          return
        }
        user.getIDTokenResult(forcingRefresh: false) { [self] result, error in
          let outcome: SessionTokenDecision.Outcome = result.map { .claims($0.claims) }
            ?? (error.map(FirebaseAuthErrorMapper.map) == .network ? .networkError : .otherError)
          switch SessionTokenDecision.decide(outcome, listenerUid: user.uid, currentUid: Auth.auth().currentUser?.uid) {
          case .emit:
            continuation.yield(FirebaseAuthService.session(for: user))
          case .signOut:
            // The listener fires again with `nil` after the sign-out.
            logger.notice("session ended: trainer claim missing or token invalid")
            signOutLogged()
          case .drop:
            break  // a stale completion for a user that is no longer current
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
        signOutLogged()
      }
    } catch where FirebaseAuthErrorMapper.map(error) == .network {
      // Offline: keep the session; the next foreground refresh tries again.
      logger.notice("claim refresh deferred: offline")
    } catch {
      logger.notice("claim refresh failed: code=\((error as NSError).code, privacy: .public), signing out")
      signOutLogged()
    }
  }

  private static func session(for user: User) -> TrainerSession {
    TrainerSession(uid: user.uid, displayName: user.displayName ?? "")
  }
}

/// What the ID-token listener does with a token check (pure, unit-tested).
enum SessionTokenDecision: Equatable {
  enum Outcome {
    case claims([String: Any])
    case networkError
    case otherError
  }

  /// Publish the session.
  case emit
  /// Sign out; the listener then publishes `nil`.
  case signOut
  /// Ignore: the completion belongs to a user that is no longer signed in (Firebase may have signed out already).
  case drop

  static func decide(_ outcome: Outcome, listenerUid: String, currentUid: String?) -> SessionTokenDecision {
    guard currentUid == listenerUid else { return .drop }
    switch outcome {
    case let .claims(claims):
      return TrainerClaims.isTrainer(claims) ? .emit : .signOut
    case .networkError:
      return .emit  // offline: keep the cached sign-in (type comment of FirebaseAuthService)
    case .otherError:
      return .signOut  // disabled account, revoked or invalid token: fail closed
    }
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
