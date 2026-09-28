import XCTest
@testable import TrainerDomain

/// DF-113: TR-02 list merge (AC-DF-113.1) and search (AC-DF-113.5, TC-113-04). Synthetic names only.
final class MemberListTests: XCTestCase {
  private let assignedB = Member(id: "u2", displayName: "나회원", trainerId: "t")
  private let assignedA = Member(id: "u1", displayName: "가회원", trainerId: "t")
  private let pendingC = PendingMember(id: "SynPendingList000003", displayName: "다회원")

  func test_AC_DF_113_1_assignedAndPendingInOneListInNameOrder() {
    let entries = MemberList.merge(assigned: [assignedB, assignedA], pending: [pendingC])
    XCTAssertEqual(entries.map(\.displayName), ["가회원", "나회원", "다회원"])
    XCTAssertEqual(entries.map(\.key), [.uid("u1"), .uid("u2"), .pending("SynPendingList000003")])
    XCTAssertEqual(entries.map(\.isPending), [false, false, true])
  }

  func testAPendingMemberFromTheServerAndTheDeviceIsListedOnceWithTheFirstName() {
    let local = PendingMember(id: pendingC.id, displayName: "다회원 (기기)")
    let entries = MemberList.merge(assigned: [], pending: [pendingC, local])
    XCTAssertEqual(entries, [MemberListEntry(key: .pending(pendingC.id), displayName: "다회원")])
  }

  /// A uid and a pending ID never collide in the rules (R-05), but the key keeps them apart anyway.
  func testTheSameIdAsUidAndPendingAreTwoRows() {
    let entries = MemberList.merge(
      assigned: [Member(id: "same", displayName: "가", trainerId: nil)],
      pending: [PendingMember(id: "same", displayName: "가")])
    XCTAssertEqual(entries.map(\.key), [.uid("same"), .pending("same")], "equal names: assigned first")
  }

  func testEqualNamesOrderByKey() {
    let entries = MemberList.merge(
      assigned: [],
      pending: [PendingMember(id: "b", displayName: "가"), PendingMember(id: "a", displayName: "가")])
    XCTAssertEqual(entries.map(\.key), [.pending("a"), .pending("b")])
  }

  /// AC-DF-113.6: a member cancelled on this device leaves the list at once, from the server's list and from the
  /// device's registrations alike, before the cancel is sent. Assigned members are never hidden by it.
  func test_AC_DF_113_6_aCancelledPendingMemberIsNotListed() {
    let registeredHere = PendingMember(id: "SynPendingList000004", displayName: "라회원")
    let entries = MemberList.merge(
      assigned: [assignedA, Member(id: pendingC.id, displayName: "마회원", trainerId: "t")],
      pending: [pendingC, registeredHere], cancelled: [pendingC.id, registeredHere.id])
    XCTAssertEqual(entries.map(\.key), [.uid("u1"), .uid(pendingC.id)])
  }

  func testNothingToMergeIsEmpty() {
    XCTAssertEqual(MemberList.merge(assigned: [], pending: []), [])
  }

  // MARK: TC-113-04 search

  private let rows = [
    MemberListEntry(key: .uid("u1"), displayName: "Jane Doe"),
    MemberListEntry(key: .pending("p1"), displayName: "가상 회원"),
    MemberListEntry(key: .uid("u2"), displayName: "SYN-0002"),
  ]

  func test_TC_113_04_partialMatchIgnoresCase() {
    XCTAssertEqual(MemberList.search(rows, query: "jane").map(\.key), [.uid("u1")])
    XCTAssertEqual(MemberList.search(rows, query: "DOE").map(\.key), [.uid("u1")])
    XCTAssertEqual(MemberList.search(rows, query: "syn-000").map(\.key), [.uid("u2")])
  }

  func test_TC_113_04_whitespaceIsIgnoredInTheQueryAndTheName() {
    XCTAssertEqual(MemberList.search(rows, query: "가상회원").map(\.key), [.pending("p1")])
    XCTAssertEqual(MemberList.search(rows, query: " 상 회 ").map(\.key), [.pending("p1")])
    XCTAssertEqual(MemberList.search(rows, query: "janedoe").map(\.key), [.uid("u1")])
  }

  func test_TC_113_04_blankQueryKeepsEveryRowInOrder() {
    XCTAssertEqual(MemberList.search(rows, query: ""), rows)
    XCTAssertEqual(MemberList.search(rows, query: "  \n"), rows)
  }

  func test_TC_113_04_noMatchIsEmpty() {
    XCTAssertEqual(MemberList.search(rows, query: "없는 이름"), [])
  }

  func testEntryInitialsAreLocal() {
    XCTAssertEqual(rows[0].initials, "JD")
    XCTAssertEqual(rows[1].initials, "가")
  }
}
