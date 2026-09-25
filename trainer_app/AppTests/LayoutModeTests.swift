import XCTest

/// TC-DF017-04 (AC-DF-017.4, NFR-12, ASM-P0-22): the compact/regular boundary is 1120pt of detail width.
final class LayoutModeTests: XCTestCase {
  func testBoundary_TC_DF017_04() {
    XCTAssertEqual(LayoutMode.for(width: 1119), .compact)
    XCTAssertEqual(LayoutMode.for(width: 1119.5), .compact)
    XCTAssertEqual(LayoutMode.for(width: 1120), .regular)
  }

  func testRepresentativeWindows() {
    XCTAssertEqual(LayoutMode.for(width: 375), .compact)   // 1/3 Split View
    XCTAssertEqual(LayoutMode.for(width: 1024), .compact)  // 13-inch portrait
    XCTAssertEqual(LayoutMode.for(width: 1366), .regular)  // 13-inch landscape, full width
    XCTAssertEqual(LayoutMode.for(width: 0), .compact)     // before the first layout pass
  }
}
