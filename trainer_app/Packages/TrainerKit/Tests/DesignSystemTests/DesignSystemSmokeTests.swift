import XCTest
@testable import DesignSystem

final class DesignSystemSmokeTests: XCTestCase {
  func testModuleLoads() {
    XCTAssertEqual(DesignSystemModule.name, "DesignSystem")
  }
}
