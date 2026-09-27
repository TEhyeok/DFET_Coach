import FirebaseFirestore
import Foundation
import TrainerDomain
import XCTest
@testable import FirebaseData

/// TC-DF013-01, TC-DF013-02: chunked reads, one emission, no partial list on a chunk failure. Synthetic data only.
final class FirestoreMemberDirectoryTests: XCTestCase {
  private let ids = (1...23).map { String(format: "synthMember%04d", $0) }

  func testTwentyThreeMembersReadInThreeChunksAndEmittedOnce_TC_DF013_01() async throws {
    let gateway = FakeMemberGateway(memberIdUpdates: [ids])
    let directory = FirestoreMemberDirectory(trainerUid: "synthTrainerA", gateway: gateway)
    var emissions: [[Member]] = []
    for try await members in directory.observeAssignedMembers() {
      emissions.append(members)
    }
    XCTAssertEqual(emissions.count, 1)
    XCTAssertEqual(emissions.first?.map(\.id), ids, "memberIds order")
    XCTAssertEqual(gateway.chunkSizes.sorted(), [3, 10, 10])
  }

  func testAFailedChunkFailsTheStreamWithoutAPartialList_TC_DF013_02() async {
    let gateway = FakeMemberGateway(memberIdUpdates: [ids], failingChunk: 1)
    let directory = FirestoreMemberDirectory(trainerUid: "synthTrainerA", gateway: gateway)
    var emissions = 0
    do {
      for try await _ in directory.observeAssignedMembers() { emissions += 1 }
      XCTFail("expected permissionDenied")
    } catch {
      XCTAssertEqual(error as? MemberDirectoryError, .permissionDenied)
    }
    XCTAssertEqual(emissions, 0)
  }

  func testEmptyMemberIdsEmitAnEmptyListWithoutReads() async throws {
    let gateway = FakeMemberGateway(memberIdUpdates: [[]])
    let directory = FirestoreMemberDirectory(trainerUid: "synthTrainerA", gateway: gateway)
    var emissions: [[Member]] = []
    for try await members in directory.observeAssignedMembers() { emissions.append(members) }
    XCTAssertEqual(emissions, [[]])
    XCTAssertEqual(gateway.chunkSizes, [])
  }

  func testEveryMemberIdsChangeEmitsTheNewList() async throws {
    let gateway = FakeMemberGateway(memberIdUpdates: [Array(ids.prefix(2)), Array(ids.prefix(3))])
    let directory = FirestoreMemberDirectory(trainerUid: "synthTrainerA", gateway: gateway)
    var last: [Member] = []
    for try await members in directory.observeAssignedMembers() { last = members }
    XCTAssertEqual(last.map(\.id), Array(ids.prefix(3)))
  }

  func testFirestoreErrorCodesMap() {
    func firestore(_ code: FirestoreErrorCode.Code) -> NSError {
      NSError(domain: FirestoreErrorDomain, code: code.rawValue)
    }
    XCTAssertEqual(MemberDirectoryErrorMapper.map(firestore(.permissionDenied)), .permissionDenied)
    XCTAssertEqual(MemberDirectoryErrorMapper.map(firestore(.failedPrecondition)), .indexMissing)
    XCTAssertEqual(MemberDirectoryErrorMapper.map(firestore(.unavailable)), .unavailable)
    XCTAssertEqual(MemberDirectoryErrorMapper.map(firestore(.internal)), .unknown(code: FirestoreErrorCode.Code.internal.rawValue))
    XCTAssertEqual(MemberDirectoryErrorMapper.map(NSError(domain: "other", code: 5)), .unknown(code: 5))
  }
}

/// Scripted gateway: yields each memberIds update after the previous list was read, fails one chunk on request.
final class FakeMemberGateway: MemberDirectoryGateway, @unchecked Sendable {
  private let lock = NSLock()
  private let updates: [[String]]
  private let failingChunk: Int?
  private var _chunkSizes: [Int] = []
  private var chunkCalls = 0

  init(memberIdUpdates: [[String]], failingChunk: Int? = nil) {
    updates = memberIdUpdates
    self.failingChunk = failingChunk
  }

  var chunkSizes: [Int] { lock.withLock { _chunkSizes } }

  func memberIds(trainerUid: String) -> AsyncThrowingStream<[String], Error> {
    let updates = updates
    return AsyncThrowingStream { continuation in
      Task {
        for ids in updates {
          continuation.yield(ids)
          try? await Task.sleep(nanoseconds: 50_000_000)  // let the reads for this value finish
        }
        continuation.finish()
      }
    }
  }

  func users(ids: [String]) async throws -> [Member] {
    let index: Int = lock.withLock {
      _chunkSizes.append(ids.count)
      defer { chunkCalls += 1 }
      return chunkCalls
    }
    if index == failingChunk {
      throw NSError(domain: FirestoreErrorDomain, code: FirestoreErrorCode.Code.permissionDenied.rawValue)
    }
    return ids.map { Member(id: $0, displayName: "가상 \($0.suffix(4))", trainerId: "synthTrainerA") }
  }
}
