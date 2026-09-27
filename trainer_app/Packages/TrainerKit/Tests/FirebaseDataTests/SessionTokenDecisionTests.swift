import FirebaseAuth
import Foundation
import TrainerDomain
import XCTest
@testable import FirebaseData

/// AC-DF-012.3 and the offline rule of `FirebaseAuthService.sessionStream()` and `refreshClaims()`, without Firebase.
final class SessionTokenDecisionTests: XCTestCase {
  private func decide(_ outcome: SessionTokenDecision.Outcome, _ tokenUid: String = "u1", current: String? = "u1",
                      locked: String? = nil) -> SessionTokenDecision {
    SessionTokenDecision.decide(outcome, tokenUid: tokenUid, currentUid: current, lockedUid: locked)
  }

  func testTrainerClaimEmitsAndMissingClaimSignsOut() {
    XCTAssertEqual(decide(.claims(["trainer": true])), .emit)
    XCTAssertEqual(decide(.claims([:])), .signOut)
    XCTAssertEqual(decide(.claims(["trainer": 1])), .signOut)
  }

  func testOfflineKeepsTheSessionButOtherTokenErrorsSignOut() {
    XCTAssertEqual(decide(.networkError), .emit)
    XCTAssertEqual(decide(.otherError), .signOut)
  }

  /// Firebase signs a disabled or revoked user out before the token completion runs; that late completion must not
  /// publish the session again. A claim refresh that answers after its trainer signed out and another signed in must
  /// not end the new trainer's session either.
  func testStaleCompletionIsDropped() {
    for outcome in [SessionTokenDecision.Outcome.claims(["trainer": true]), .claims([:]), .networkError, .otherError] {
      XCTAssertEqual(decide(outcome, current: nil), .drop)
      XCTAssertEqual(decide(outcome, current: "u2"), .drop)
      XCTAssertEqual(decide(outcome, current: "u2", locked: "u1"), .drop)
    }
  }

  /// A user whose claim was found missing stays locked while offline (and the sign-out is tried again), until a token
  /// shows the claim again. Other users keep the offline rule.
  func testALockedUserIsNotPublishedAgainOffline() {
    XCTAssertEqual(decide(.networkError, locked: "u1"), .signOut)
    XCTAssertEqual(decide(.claims(["trainer": true]), locked: "u1"), .emit)
    XCTAssertEqual(decide(.networkError, locked: "u2"), .emit)
  }

  // MARK: SessionChannel

  /// The lock never depends on the Firebase sign-out: every stream gets `nil` before it runs, also when it fails
  /// (for example a keychain error), and the user stays locked.
  func testEndingASessionPublishesNilBeforeTheSignOut() async throws {
    let channel = SessionChannel()
    let first = AsyncStream.makeStream(of: TrainerSession?.self)
    let second = AsyncStream.makeStream(of: TrainerSession?.self)
    let removed = AsyncStream.makeStream(of: TrainerSession?.self)
    _ = channel.add(first.continuation)
    _ = channel.add(second.continuation)
    channel.remove(channel.add(removed.continuation))

    struct KeychainError: Error {}
    var signOutCalls = 0
    XCTAssertThrowsError(try channel.end("u1") {
      signOutCalls += 1
      throw KeychainError()
    })
    XCTAssertEqual(signOutCalls, 1)
    XCTAssertEqual(channel.lockedUid, "u1")
    for pair in [first, second] {
      pair.continuation.finish()
      var values: [TrainerSession?] = []
      for await value in pair.stream { values.append(value) }
      XCTAssertEqual(values, [nil])
    }
    removed.continuation.finish()
    var removedValues = 0
    for await _ in removed.stream { removedValues += 1 }
    XCTAssertEqual(removedValues, 0, "a finished stream is no longer published to")
  }

  func testOnlyATokenOfTheLockedUserUnlocksIt() {
    let channel = SessionChannel()
    channel.end("u1") {}
    channel.unlock("u2")
    XCTAssertEqual(channel.lockedUid, "u1")
    channel.unlock("u1")
    XCTAssertNil(channel.lockedUid)
  }

  // MARK: Sign-in claim check

  /// The sign-in claim check follows the same transient rule as the listener and the refresh: a backend hiccup falls
  /// back to the token this sign-in just minted instead of signing the trainer out.
  func testSignInClaimCheckFallsBackOnTransientErrorsOnly() async throws {
    for code in [AuthErrorCode.networkError, .internalError, .tooManyRequests] {
      var reads: [Bool] = []
      let claims = try await FirebaseAuthService.freshClaims { forcingRefresh in
        reads.append(forcingRefresh)
        if forcingRefresh { throw NSError(domain: AuthErrorDomain, code: code.rawValue) }
        return ["trainer": true]
      }
      XCTAssertTrue(TrainerClaims.isTrainer(claims), "\(code)")
      XCTAssertEqual(reads, [true, false], "\(code)")
    }
    var reads: [Bool] = []
    do {
      _ = try await FirebaseAuthService.freshClaims { forcingRefresh in
        reads.append(forcingRefresh)
        throw NSError(domain: AuthErrorDomain, code: AuthErrorCode.keychainError.rawValue)
      }
      XCTFail("a keychain error is not transient")
    } catch {
      XCTAssertEqual((error as NSError).code, AuthErrorCode.keychainError.rawValue)
    }
    XCTAssertEqual(reads, [true])
  }
}
