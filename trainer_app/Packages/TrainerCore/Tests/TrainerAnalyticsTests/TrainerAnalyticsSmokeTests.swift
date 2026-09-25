import XCTest
@testable import TrainerAnalytics

final class TrainerAnalyticsSmokeTests: XCTestCase {
  func testModuleLoads() {
    XCTAssertEqual(TrainerAnalyticsModule.name, "TrainerAnalytics")
  }
}
