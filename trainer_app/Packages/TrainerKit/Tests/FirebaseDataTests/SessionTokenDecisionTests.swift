import XCTest
@testable import FirebaseData

/// AC-DF-012.3 and the offline rule of `FirebaseAuthService.sessionStream()`, without Firebase.
final class SessionTokenDecisionTests: XCTestCase {
  func testTrainerClaimEmitsAndMissingClaimSignsOut() {
    XCTAssertEqual(SessionTokenDecision.decide(.claims(["trainer": true]), listenerUid: "u1", currentUid: "u1"), .emit)
    XCTAssertEqual(SessionTokenDecision.decide(.claims([:]), listenerUid: "u1", currentUid: "u1"), .signOut)
    XCTAssertEqual(SessionTokenDecision.decide(.claims(["trainer": 1]), listenerUid: "u1", currentUid: "u1"), .signOut)
  }

  func testOfflineKeepsTheSessionButOtherTokenErrorsSignOut() {
    XCTAssertEqual(SessionTokenDecision.decide(.networkError, listenerUid: "u1", currentUid: "u1"), .emit)
    XCTAssertEqual(SessionTokenDecision.decide(.otherError, listenerUid: "u1", currentUid: "u1"), .signOut)
  }

  /// Firebase signs a disabled or revoked user out before the token completion runs; that late completion must not
  /// publish the session again.
  func testStaleCompletionIsDropped() {
    for outcome in [SessionTokenDecision.Outcome.claims(["trainer": true]), .networkError, .otherError] {
      XCTAssertEqual(SessionTokenDecision.decide(outcome, listenerUid: "u1", currentUid: nil), .drop)
      XCTAssertEqual(SessionTokenDecision.decide(outcome, listenerUid: "u1", currentUid: "u2"), .drop)
    }
  }
}
