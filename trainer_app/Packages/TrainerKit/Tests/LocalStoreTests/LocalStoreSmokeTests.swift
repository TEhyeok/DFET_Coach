import XCTest
@testable import LocalStore

final class LocalStoreSmokeTests: XCTestCase {
  func testModuleLoads() {
    XCTAssertEqual(LocalStoreModule.name, "LocalStore")
  }
}
