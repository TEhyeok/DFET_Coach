import SyncEngine
import TrainerDomain
import XCTest

/// TC-DF015-04 (pure part): backoff `min(2^n s, 15 min) ± 20%`, five-attempt limit, error classes (ASM-P0-16).
final class RetryPolicyTests: XCTestCase {
  private let policy = RetryPolicy.standard

  func testDelayDoublesAndCapsAtFifteenMinutes() {
    let delays = (1...11).map { policy.delay(afterAttempts: $0, jitterUnit: 0) }
    XCTAssertEqual(delays, [2, 4, 8, 16, 32, 64, 128, 256, 512, 900, 900])
  }

  func testJitterIsPlusMinusTwentyPercentAndClamped() {
    XCTAssertEqual(policy.delay(afterAttempts: 1, jitterUnit: 1), 2.4, accuracy: 1e-9)
    XCTAssertEqual(policy.delay(afterAttempts: 1, jitterUnit: -1), 1.6, accuracy: 1e-9)
    XCTAssertEqual(policy.delay(afterAttempts: 20, jitterUnit: 1), 1080, accuracy: 1e-9)
    XCTAssertEqual(policy.delay(afterAttempts: 3, jitterUnit: 7), policy.delay(afterAttempts: 3, jitterUnit: 1))
  }

  func testFiveConsecutiveFailuresExhaust() {
    XCTAssertFalse(policy.isExhausted(attempts: 4))
    XCTAssertTrue(policy.isExhausted(attempts: 5))
  }

  func testErrorClasses() {
    for error in [RemoteError.permissionDenied, .failedPrecondition, .invalidArgument, .notFound, .alreadyExists] {
      XCTAssertEqual(RetryPolicy.disposition(for: error), .permanent, "\(error)")
    }
    for error in [RemoteError.unavailable, .deadlineExceeded, .unknown("x")] {
      XCTAssertEqual(RetryPolicy.disposition(for: error), .retry, "\(error)")
    }
    XCTAssertEqual(RetryPolicy.disposition(for: .protectedDataUnavailable), .waitForUnlock)
  }

  func testErrorCodesNeverCarryDetails() {
    XCTAssertEqual(RemoteError.permissionDenied.code, "permission-denied")
    XCTAssertEqual(RemoteError.unknown("soap_notes/fx-note uid=fx").code, "unknown")
  }
}
