import Foundation

/// The signed-in trainer as the app sees it (DF-012, NFR-02). It carries no token and no claim values.
public struct TrainerSession: Equatable, Sendable {
  public let uid: String
  public let displayName: String

  public init(uid: String, displayName: String) {
    self.uid = uid
    self.displayName = displayName
  }
}

/// Sign-in failures shown to the trainer. Raw provider messages never reach the UI or the log (NFR-10).
public enum AuthError: Error, Equatable, Sendable {
  /// The account has no `trainer` custom claim (AC-DF-012.2).
  case notTrainer
  case invalidCredentials
  case network
  case unknown(code: Int)

  /// V1-12 deck key shown on the login screen (`App/Resources/Localizable.xcstrings`).
  public var messageKey: String {
    switch self {
    case .notTrainer: return "auth.notTrainer"
    case .invalidCredentials: return "login.error.invalidCredentials"
    case .network: return "common.unavailable"
    case .unknown: return "common.internal"
    }
  }
}

/// Why the app returned to the login screen without the trainer asking for it.
public enum AuthLockReason: Equatable, Sendable {
  /// The `trainer` claim disappeared while signed in (AC-DF-012.3, NFR-08).
  case claimRevoked

  public var messageKey: String {
    switch self {
    case .claimRevoked: return "auth.sessionLocked"
    }
  }
}

/// Authentication boundary. Feature modules depend on this protocol only; `FirebaseData` implements it
/// (AC-DF-012.5, NFR-03).
public protocol AuthService: Sendable {
  /// Signs in and verifies the `trainer` claim with a forced token refresh. Throws `AuthError`.
  /// An account without the claim is signed out before `.notTrainer` is thrown.
  func signIn(email: String, password: String) async throws -> TrainerSession
  /// Signs out of the backend. `discardUnsynced` is completed by DF-018 (unsynced-work warning).
  func signOut(discardUnsynced: Bool) async throws
  /// Current session, then every change. `nil` means signed out (or locked).
  func sessionStream() -> AsyncStream<TrainerSession?>
  /// Re-reads the claim with a forced token refresh; signs out when it is gone. Called when the app
  /// returns to the foreground and by tests.
  func refreshClaims() async
}

/// The single rule for "is this token a trainer token" (ported from
/// dfet:trainer_ios/DFETTrainer/Features/Login/LoginView.swift:236-241).
public enum TrainerClaims {
  public static let key = "trainer"

  /// `true` only for a boolean `true` claim. A string "true", the number 1, or a missing claim is not a
  /// trainer. Token claims arrive as Foundation objects, where `1 as? Bool` would succeed, so the boolean
  /// type is checked explicitly.
  public static func isTrainer(_ claims: [String: Any]) -> Bool {
    guard let raw = claims[key] else { return false }
    if let number = raw as? NSNumber {
      return CFGetTypeID(number) == CFBooleanGetTypeID() && number.boolValue
    }
    return false
  }
}
