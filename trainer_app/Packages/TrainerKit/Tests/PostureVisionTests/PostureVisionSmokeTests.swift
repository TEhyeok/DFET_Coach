import XCTest
@testable import PostureVision

final class PostureVisionSmokeTests: XCTestCase {
  func testModuleLoads() {
    XCTAssertEqual(PostureVisionModule.name, "PostureVision")
  }
}
