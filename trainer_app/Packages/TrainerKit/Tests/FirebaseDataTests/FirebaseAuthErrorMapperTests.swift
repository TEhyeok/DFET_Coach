import FirebaseAuth
import Foundation
import TrainerDomain
import XCTest
@testable import FirebaseData

/// AC-DF-012.4: Firebase Auth errors map to the login screen's error cases by code, never by message text.
final class FirebaseAuthErrorMapperTests: XCTestCase {
  private func authError(_ code: AuthErrorCode) -> NSError {
    NSError(domain: AuthErrorDomain, code: code.rawValue, userInfo: [NSLocalizedDescriptionKey: "user@example.invalid"])
  }

  func testCredentialErrorsMapToInvalidCredentials() {
    for code in [AuthErrorCode.wrongPassword, .invalidCredential, .userNotFound, .invalidEmail, .userDisabled] {
      XCTAssertEqual(FirebaseAuthErrorMapper.map(authError(code)), .invalidCredentials, "\(code)")
    }
  }

  func testNetworkErrorsMapToNetwork() {
    XCTAssertEqual(FirebaseAuthErrorMapper.map(authError(.networkError)), .network)
    XCTAssertEqual(FirebaseAuthErrorMapper.map(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)), .network)
  }

  func testOtherErrorsKeepOnlyTheCode() {
    let tooMany = authError(.tooManyRequests)
    XCTAssertEqual(FirebaseAuthErrorMapper.map(tooMany), .unknown(code: tooMany.code))
    XCTAssertEqual(FirebaseAuthErrorMapper.map(NSError(domain: "other", code: 7)), .unknown(code: 7))
  }

  func testAuthErrorPassesThrough() {
    XCTAssertEqual(FirebaseAuthErrorMapper.map(AuthError.notTrainer), .notTrainer)
  }
}
