import XCTest
@testable import SyncEngine

final class SyncEngineSmokeTests: XCTestCase {
  func testModuleLoads() {
    XCTAssertEqual(SyncEngineModule.name, "SyncEngine")
  }
}
