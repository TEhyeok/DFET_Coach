import XCTest
@testable import PostureMath

final class PostureMathSmokeTests: XCTestCase {
  func testModuleLoads() {
    XCTAssertEqual(PostureMathModule.name, "PostureMath")
  }
}
