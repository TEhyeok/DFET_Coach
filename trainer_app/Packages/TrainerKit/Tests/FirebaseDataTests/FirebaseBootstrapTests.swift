import FirebaseAppCheck
import XCTest
@testable import FirebaseData

/// AC-DF-008.5: DEBUG builds use the App Check debug provider; Release uses App Attest.
/// These tests never call `FirebaseBootstrap.configure(_:)`, so no Firebase app is created.
final class FirebaseBootstrapTests: XCTestCase {
  func testModuleLoads() {
    XCTAssertEqual(FirebaseDataModule.name, "FirebaseData")
  }

  func testDebugBuildUsesAppCheckDebugProvider() throws {
    #if DEBUG
    XCTAssertEqual(FirebaseBootstrap.appCheckProviderKind, .debug)
    XCTAssertTrue(FirebaseBootstrap.makeAppCheckProviderFactory(for: .production) is AppCheckDebugProviderFactory)
    #else
    throw XCTSkip("tests run in the Debug configuration")
    #endif
  }

  func testAppAttestFactoryIsAnAppCheckProviderFactory() {
    let factory: AppCheckProviderFactory = AppAttestProviderFactory()
    XCTAssertNotNil(factory)
  }

  /// Emulator mode must never use the bundled plist's project (V1-04 ASM-04-09, V1-10 ASM-10-03).
  func testEmulatorOptionsUseDemoProjectWithoutPlist() {
    let options = FirebaseBootstrap.emulatorOptions()
    XCTAssertEqual(FirebaseBootstrap.emulatorProjectID, "demo-dfet")
    XCTAssertEqual(options.projectID, "demo-dfet")
    XCTAssertEqual(options.storageBucket, "demo-dfet.appspot.com")
    XCTAssertEqual(options.googleAppID, "1:000000000000:ios:0000000000000000")
    XCTAssertEqual(options.gcmSenderID, "000000000000")
    XCTAssertFalse(options.apiKey?.hasPrefix("AIza") ?? false, "emulator options must not carry a Google API key")
  }

  /// App Check has no emulator, so emulator mode uses a local provider that makes no network call.
  func testEmulatorUsesLocalAppCheckProvider() {
    let factory = FirebaseBootstrap.makeAppCheckProviderFactory(for: .emulator(host: "127.0.0.1"))
    XCTAssertTrue(factory is EmulatorAppCheckProviderFactory)

    let tokenReturned = expectation(description: "token")
    EmulatorAppCheckProvider().getToken { token, error in
      XCTAssertNil(error)
      XCTAssertEqual(token?.token, "emulator")
      tokenReturned.fulfill()
    }
    wait(for: [tokenReturned], timeout: 1)
  }

  func testEmulatorWiringMatchesFirebaseJson() {
    XCTAssertEqual(FirebaseBootstrap.EmulatorPort.firestore, 18080)
    XCTAssertEqual(FirebaseBootstrap.EmulatorPort.storage, 19199)
    XCTAssertEqual(FirebaseBootstrap.functionsRegion, "asia-northeast3")
    XCTAssertNotEqual(FirebaseEnvironment.production, .emulator(host: "127.0.0.1"))
  }
}
