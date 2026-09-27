import Foundation
import Observation
import TrainerDomain

/// Login screen state (DF-012, TC-DF012-01). Uses only the `AuthService` protocol (AC-DF-012.5).
@MainActor
@Observable
public final class LoginViewModel {
  public enum Phase: Equatable {
    case idle
    case signingIn
    case failed(AuthError)
  }

  public var email = ""
  public var password = ""
  public private(set) var phase: Phase = .idle

  private let auth: any AuthService

  public init(auth: any AuthService) {
    self.auth = auth
  }

  public var canSubmit: Bool {
    phase != .signingIn
      && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !password.isEmpty
  }

  /// String-catalog key of the error shown under the form, if any.
  public var errorKey: String? {
    if case let .failed(error) = phase { return error.messageKey }
    return nil
  }

  /// Signs in. On success the password is cleared and `AuthGate` switches to the shell through the session
  /// stream; the returned session is not needed here.
  public func submit() async {
    guard canSubmit else { return }
    phase = .signingIn
    do {
      _ = try await auth.signIn(
        email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
      password = ""
      phase = .idle
    } catch let error as AuthError {
      phase = .failed(error)
    } catch {
      phase = .failed(.unknown(code: (error as NSError).code))
    }
  }
}

/// What the app shows above everything else: nothing yet, the login screen, or the signed-in shell.
@MainActor
@Observable
public final class AuthGateModel {
  public enum State: Equatable {
    /// Waiting for the first session value (a cached sign-in usually arrives immediately).
    case checking
    case signedOut(lock: AuthLockReason?)
    case signedIn(TrainerSession)
  }

  public private(set) var state: State = .checking

  public let auth: any AuthService
  /// Set while a sign-out the trainer asked for is in progress, so the resulting `nil` is not a lock.
  private var userSignOutInProgress = false

  public init(auth: any AuthService) {
    self.auth = auth
  }

  /// Follows the session stream until the task is cancelled. A `nil` after a signed-in state that the trainer
  /// did not ask for means the claim was revoked (AC-DF-012.3). A disabled account or revoked token ends the session
  /// the same way and shows the same notice, which also tells the trainer to contact the administrator. At a cold
  /// start whose cached token already expired without the claim, the first value is `nil` and the plain login screen
  /// shows without the notice.
  public func observe() async {
    for await session in auth.sessionStream() {
      apply(session)
    }
  }

  func apply(_ session: TrainerSession?) {
    if let session {
      state = .signedIn(session)
      return
    }
    let wasSignedIn: Bool
    if case .signedIn = state { wasSignedIn = true } else { wasSignedIn = false }
    let lock: AuthLockReason? = (wasSignedIn && !userSignOutInProgress) ? .claimRevoked : nil
    userSignOutInProgress = false
    if case let .signedOut(existing) = state, lock == nil {
      state = .signedOut(lock: existing)  // keep a lock notice already on screen
    } else {
      state = .signedOut(lock: lock)
    }
  }

  /// Sign-out requested by the trainer (settings, DF-018). Never shows the claim-revoked notice.
  public func signOut(discardUnsynced: Bool = false) async throws {
    // Only a signed-in state produces the `nil` that clears the flag; otherwise the flag would hide a later lock.
    guard case .signedIn = state else {
      try await auth.signOut(discardUnsynced: discardUnsynced)
      return
    }
    userSignOutInProgress = true
    do {
      try await auth.signOut(discardUnsynced: discardUnsynced)
    } catch {
      userSignOutInProgress = false
      throw error
    }
  }

  /// Foreground return (AppShell `scenePhase`) and tests: re-check the claim.
  public func refreshClaims() async {
    await auth.refreshClaims()
  }
}
