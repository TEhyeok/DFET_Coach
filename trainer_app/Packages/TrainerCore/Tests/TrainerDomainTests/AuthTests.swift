import Foundation
import XCTest
@testable import TrainerDomain

/// DF-012: the trainer-claim rule and the login copy keys (AC-DF-012.2, .4).
final class AuthTests: XCTestCase {
  func testBooleanTrueClaimIsTrainer() {
    XCTAssertTrue(TrainerClaims.isTrainer(["trainer": true]))
    // As decoded from a token payload: Foundation boolean.
    XCTAssertTrue(TrainerClaims.isTrainer(["trainer": NSNumber(value: true), "admin": NSNumber(value: false)]))
  }

  func testNonBooleanOrFalseClaimIsNotTrainer() {
    XCTAssertFalse(TrainerClaims.isTrainer([:]))
    XCTAssertFalse(TrainerClaims.isTrainer(["trainer": false]))
    XCTAssertFalse(TrainerClaims.isTrainer(["trainer": NSNumber(value: 1)]), "numeric 1 is not a boolean claim")
    XCTAssertFalse(TrainerClaims.isTrainer(["trainer": 1]))
    XCTAssertFalse(TrainerClaims.isTrainer(["trainer": "true"]))
    XCTAssertFalse(TrainerClaims.isTrainer(["admin": true]), "admin alone is not a trainer (ADR-018)")
  }

  func testErrorAndLockMessageKeys() {
    XCTAssertEqual(AuthError.notTrainer.messageKey, "auth.notTrainer")
    XCTAssertEqual(AuthError.invalidCredentials.messageKey, "login.error.invalidCredentials")
    XCTAssertEqual(AuthError.network.messageKey, "login.error.network")
    XCTAssertEqual(AuthError.unknown(code: 17999).messageKey, "common.internal")
    XCTAssertEqual(AuthLockReason.claimRevoked.messageKey, "auth.sessionLocked")
  }

  func testSessionEquality() {
    XCTAssertEqual(TrainerSession(uid: "synthTrainerA", displayName: "A"), TrainerSession(uid: "synthTrainerA", displayName: "A"))
    XCTAssertNotEqual(TrainerSession(uid: "synthTrainerA", displayName: "A"), TrainerSession(uid: "synthTrainerB", displayName: "A"))
  }
}
