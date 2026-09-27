import FirebaseFirestore
import Foundation
import TrainerDomain
import XCTest
@testable import FirebaseData

/// DF-113: the trainer's pending members through `FirestoreMemberDirectory.observePendingMembers()`. The query itself
/// (trainerId, status == 'pending', the rules) runs in `PendingMemberEmulatorTests`. Synthetic data only.
final class FirestorePendingMembersTests: XCTestCase {
  private let first = PendingMember(id: "SynPendingList000001", displayName: "가상 대기 1")
  private let second = PendingMember(id: "SynPendingList000002", displayName: "가상 대기 2")

  private func collect(_ directory: FirestoreMemberDirectory) async -> (emissions: [[PendingMember]], error: Error?) {
    var emissions: [[PendingMember]] = []
    do {
      for try await members in directory.observePendingMembers() { emissions.append(members) }
      return (emissions, nil)
    } catch {
      return (emissions, error)
    }
  }

  func testEveryChangeOfTheTrainersPendingMembersIsEmitted() async {
    let gateway = FakeMemberGateway(snapshots: [])
    gateway.pendingLists = [[first], [first, second], [second]]
    let result = await collect(FirestoreMemberDirectory(trainerUid: "synthTrainerA", gateway: gateway))
    XCTAssertNil(result.error)
    XCTAssertEqual(result.emissions, [[first], [first, second], [second]])
    XCTAssertEqual(gateway.pendingQueriedFor, ["synthTrainerA"])
  }

  /// Like the assigned list: a query error is a `MemberDirectoryError`, so TR-02 shows '불러오기 실패', never empty.
  func testAQueryErrorEndsTheStreamAsAMemberDirectoryError() async {
    let gateway = FakeMemberGateway(snapshots: [])
    gateway.pendingLists = [[first]]
    gateway.pendingError = NSError(domain: FirestoreErrorDomain, code: FirestoreErrorCode.Code.permissionDenied.rawValue)
    let result = await collect(FirestoreMemberDirectory(trainerUid: "synthTrainerA", gateway: gateway))
    XCTAssertEqual(result.emissions, [[first]])
    XCTAssertEqual(result.error as? MemberDirectoryError, .permissionDenied)
  }
}
