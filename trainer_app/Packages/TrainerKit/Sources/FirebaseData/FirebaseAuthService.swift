import FirebaseAuth
import Foundation
import os
import TrainerDomain

/// Firebase implementation of `AuthService` (DF-012). The only place that talks to Firebase Auth.
///
/// - Sign-in forces a token refresh and requires the boolean `trainer` claim; otherwise it signs out and
///   throws `.notTrainer` (AC-DF-012.2).
/// - `sessionStream()` follows `addIDTokenDidChangeListener`. A token without the claim ends the session: every stream
///   emits `nil` first, then Firebase signs out, so the lock never depends on the sign-out succeeding (AC-DF-012.3,
///   NFR-08, `SessionChannel`).
/// - When the token cannot be checked because the device is offline, the cached sign-in is kept (unless its claim was
///   already found missing): the trainer works local-first, and Firestore/Storage rules enforce the claim on every
///   server request anyway. Backend hiccups (internal error, too many requests) are treated the same way, at sign-in
///   too. Firebase itself signs out on a disabled account or an invalid or revoked token; any other token error signs
///   out here (`SessionTokenDecision`).
/// - `refreshClaims()` acts only on the user it checked: a late answer for a trainer who has signed out since is
///   dropped.
/// - Errors are logged as codes only; the provider message (which can contain the email) is never logged
///   (AC-DF-012.4, NFR-10).
public final class FirebaseAuthService: AuthService, Sendable {
  private let logger = Logger(subsystem: "kr.co.dfet.trainer", category: "auth")
  private let sessions = SessionChannel()

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
      claims = try await Self.freshClaims { try await user.getIDTokenResult(forcingRefresh: $0).claims }
    } catch {
      let mapped = FirebaseAuthErrorMapper.map(error)
      logger.error("claim check failed: \(String(describing: mapped), privacy: .public)")
      try reject(user)
      throw mapped
    }
    guard TrainerClaims.isTrainer(claims) else {
      logger.notice("sign-in rejected: no trainer claim")
      try reject(user)
      throw AuthError.notTrainer
    }
    sessions.unlock(user.uid)  // a fresh token shows the claim
    return Self.session(for: user)
  }

  public func signOut(discardUnsynced: Bool) async throws {
    // DF-018 adds the unsynced-work check before this call; DF-012 guarantees the real Firebase sign-out.
    try signOutOrThrow()
  }

  /// Claims of a token refreshed from the server, read through `token(forcingRefresh)`. If the refresh fails for a
  /// transient reason (offline or a backend hiccup, the same rule as the listener and `refreshClaims()`), the token
  /// minted by this sign-in a moment ago is used instead, so a brief failure does not sign out a trainer whose session
  /// the listener may already have published.
  static func freshClaims(
    _ token: (_ forcingRefresh: Bool) async throws -> [String: Any]
  ) async throws -> [String: Any] {
    do {
      return try await token(true)
    } catch where FirebaseAuthErrorMapper.isTransient(error) {
      return try await token(false)
    }
  }

  /// Ends a rejected sign-in: a session the listener may already have published ends in the app first (as a claim
  /// loss does), then Firebase signs out, or this throws when Firebase keeps the user.
  private func reject(_ user: User) throws {
    try sessions.end(user.uid, signOut: signOutOrThrow)
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

  /// Ends `uid`'s session in the app, then signs out of Firebase. When Firebase keeps the user, the app stays locked
  /// and the next token event or foreground refresh tries the sign-out again (the local partition is kept either way).
  private func endSession(of uid: String) {
    sessions.end(uid, signOut: signOutLogged)
  }

  /// The signed-in user's uid right now, whatever the claims (the SyncEngine's per-send session check).
  /// Forces a new ID token for the signed-in user; the token listener publishes the session again. Failures are
  /// ignored: the next foreground start or token change retries.
  public static func refreshToken() async {
    _ = try? await Auth.auth().currentUser?.getIDTokenResult(forcingRefresh: true)
  }

  public static func currentUid() -> String? {
    Auth.auth().currentUser?.uid
  }

  public func sessionStream() -> AsyncStream<TrainerSession?> {
    AsyncStream { continuation in
      let stream = sessions.add(continuation)
      // Firebase calls the listener and the token completion on the main thread.
      let handle = Auth.auth().addIDTokenDidChangeListener { [self] _, user in
        guard let user else {
          continuation.yield(nil)
          return
        }
        user.getIDTokenResult(forcingRefresh: false) { [self] result, error in
          let outcome: SessionTokenDecision.Outcome = result.map { .claims($0.claims) }
            ?? (error.map(FirebaseAuthErrorMapper.isTransient) == true ? .networkError : .otherError)
          let decision = SessionTokenDecision.decide(
            outcome, tokenUid: user.uid, currentUid: Auth.auth().currentUser?.uid, lockedUid: sessions.lockedUid)
          switch decision {
          case .emit:
            sessions.unlock(user.uid)  // a locked user gets here only with a token that shows the claim
            continuation.yield(FirebaseAuthService.session(for: user))
          case .signOut:
            logger.notice("session ended: trainer claim missing or token invalid")
            endSession(of: user.uid)
          case .drop:
            break  // a stale completion for a user that is no longer current
          }
        }
      }
      continuation.onTermination = { [self] _ in
        sessions.remove(stream)
        Auth.auth().removeIDTokenDidChangeListener(handle)
      }
    }
  }

  public func refreshClaims() async {
    guard let user = Auth.auth().currentUser else { return }
    let uid = user.uid
    let outcome: SessionTokenDecision.Outcome
    do {
      outcome = .claims(try await user.getIDTokenResult(forcingRefresh: true).claims)
    } catch where FirebaseAuthErrorMapper.isTransient(error) {
      // Offline or a backend hiccup: the session stays as it is; the next foreground refresh tries again.
      logger.notice("claim refresh deferred: code=\((error as NSError).code, privacy: .public)")
      outcome = .networkError
    } catch {
      logger.notice("claim refresh failed: code=\((error as NSError).code, privacy: .public)")
      outcome = .otherError
    }
    // Decided on the main actor, like the listener, against the user signed in now: a late answer for a trainer who
    // has signed out since must not end the next trainer's session.
    await MainActor.run {
      let decision = SessionTokenDecision.decide(
        outcome, tokenUid: uid, currentUid: Auth.auth().currentUser?.uid, lockedUid: sessions.lockedUid)
      switch decision {
      case .emit:
        break  // the claim is there, or the check waits; the listener publishes the refreshed token
      case .signOut:
        logger.notice("claim refresh: trainer claim missing or token invalid, signing out")
        endSession(of: uid)
      case .drop:
        logger.notice("claim refresh dropped: the signed-in user changed")
      }
    }
  }

  private static func session(for user: User) -> TrainerSession {
    TrainerSession(uid: user.uid, displayName: user.displayName ?? "")
  }
}

/// What the ID-token listener and `refreshClaims()` do with a token check of `tokenUid` (pure, unit-tested).
enum SessionTokenDecision: Equatable {
  enum Outcome {
    case claims([String: Any])
    case networkError
    case otherError
  }

  /// Publish the session (the listener) or keep it (the refresh).
  case emit
  /// End the session: every stream gets `nil`, then Firebase signs out (`SessionChannel.end`).
  case signOut
  /// Ignore: the check belongs to a user that is no longer signed in (Firebase may have signed out already, or
  /// another trainer signed in since).
  case drop

  /// `lockedUid` is the user whose claim was already found missing (`SessionChannel`).
  static func decide(
    _ outcome: Outcome, tokenUid: String, currentUid: String?, lockedUid: String?
  ) -> SessionTokenDecision {
    guard currentUid == tokenUid else { return .drop }
    switch outcome {
    case let .claims(claims):
      return TrainerClaims.isTrainer(claims) ? .emit : .signOut
    case .networkError:
      // Offline or transient: keep the cached sign-in (type comment of FirebaseAuthService). A user whose claim is
      // already gone stays locked, and the sign-out Firebase refused is tried again.
      return lockedUid == tokenUid ? .signOut : .emit
    case .otherError:
      return .signOut  // any other token failure (for example the keychain): fail closed
    }
  }
}

/// The open session streams, and the user whose trainer claim was found missing (AC-DF-012.3). Ending a session
/// publishes `nil` to every stream before Firebase signs out, so a sign-out that fails (for example a keychain error)
/// cannot leave the shell open, and the user stays locked until a token shows the claim again: an offline token check
/// cannot publish the session again either.
final class SessionChannel: Sendable {
  private struct State {
    var streams: [UUID: AsyncStream<TrainerSession?>.Continuation] = [:]
    var lockedUid: String?
  }

  private let state = OSAllocatedUnfairLock(initialState: State())

  func add(_ continuation: AsyncStream<TrainerSession?>.Continuation) -> UUID {
    let id = UUID()
    state.withLock { $0.streams[id] = continuation }
    return id
  }

  func remove(_ id: UUID) {
    state.withLock { _ = $0.streams.removeValue(forKey: id) }
  }

  var lockedUid: String? {
    state.withLock { $0.lockedUid }
  }

  /// Locks `uid` and publishes `nil` to every stream, then calls `signOut`, whose outcome the lock does not depend on.
  func end(_ uid: String, signOut: () throws -> Void) rethrows {
    let streams = state.withLock { current -> [AsyncStream<TrainerSession?>.Continuation] in
      current.lockedUid = uid
      return Array(current.streams.values)
    }
    streams.forEach { $0.yield(nil) }
    try signOut()
  }

  /// A token of `uid` shows the trainer claim again.
  func unlock(_ uid: String) {
    state.withLock { if $0.lockedUid == uid { $0.lockedUid = nil } }
  }
}

/// Maps Firebase Auth errors to `AuthError` without looking at the message text.
enum FirebaseAuthErrorMapper {
  /// Errors after which a token check should simply be tried again later: no network, a Firebase internal error
  /// (for example a 5xx without a JSON body) or rate limiting.
  static func isTransient(_ error: Error) -> Bool {
    if map(error) == .network { return true }
    let ns = error as NSError
    return ns.domain == AuthErrorDomain
      && (ns.code == AuthErrorCode.internalError.rawValue || ns.code == AuthErrorCode.tooManyRequests.rawValue)
  }

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
