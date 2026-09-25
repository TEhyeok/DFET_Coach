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
    XCTAssertTrue(FirebaseBootstrap.makeAppCheckProviderFactory() is AppCheckDebugProviderFactory)
    #else
    throw XCTSkip("tests run in the Debug configuration")
    #endif
  }

  func testAppAttestFactoryIsAnAppCheckProviderFactory() {
    let factory: AppCheckProviderFactory = AppAttestProviderFactory()
    XCTAssertNotNil(factory)
  }

  func testEmulatorWiringMatchesFirebaseJson() {
    XCTAssertEqual(FirebaseBootstrap.EmulatorPort.firestore, 18080)
    XCTAssertEqual(FirebaseBootstrap.EmulatorPort.storage, 19199)
    XCTAssertEqual(FirebaseBootstrap.functionsRegion, "asia-northeast3")
    XCTAssertNotEqual(FirebaseEnvironment.production, .emulator(host: "127.0.0.1"))
  }
}
