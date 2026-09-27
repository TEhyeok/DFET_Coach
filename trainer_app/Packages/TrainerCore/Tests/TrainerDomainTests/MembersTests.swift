import XCTest
@testable import TrainerDomain

/// DF-013: chunking for the `in` query (AC-DF-013.1) and local avatar initials (AC-DF-013.6).
final class MembersTests: XCTestCase {
  func testTwentyThreeIdsMakeChunksOfTenTenThree() {
    let ids = (1...23).map { String(format: "synthMember%04d", $0) }
    let chunks = MemberChunks.chunk(ids)
    XCTAssertEqual(chunks.map(\.count), [10, 10, 3])
    XCTAssertEqual(chunks.flatMap { $0 }, ids)
  }

  func testChunkingDropsDuplicatesAndHandlesEmpty() {
    XCTAssertEqual(MemberChunks.chunk([]), [])
    XCTAssertEqual(MemberChunks.chunk(["a", "b", "a"]), [["a", "b"]])
  }

  func testInitials() {
    XCTAssertEqual(Member(id: "1", displayName: "Jane Doe", trainerId: nil).initials, "JD")
    XCTAssertEqual(Member(id: "2", displayName: "가상회원 에이", trainerId: nil).initials, "가")
    XCTAssertEqual(Member(id: "3", displayName: "syn", trainerId: nil).initials, "S")
    XCTAssertEqual(Member(id: "4", displayName: "  ", trainerId: nil).initials, "?")
  }
}
