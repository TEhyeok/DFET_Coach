import Foundation
import TrainerDomain
import XCTest
@testable import FirebaseData

/// DF-130 mini trend query: the fields it filters and orders on, and the composite index that serves it. The query is
/// never sent here (no Firebase app in unit tests); the emulator runs it in the integration suite.
final class FirestoreBodyCompositionReadsTests: XCTestCase {
  private let since = Date(timeIntervalSince1970: 1_760_000_000)

  func testTheQueryUsesTheTrainerAndTheMembersKeyField() {
    let uid = BodyCompositionRecordQuery(trainerUid: "synthTrainerA", member: .uid("synthMember0001"), since: since)
    XCTAssertEqual(uid.equalityFields, ["trainerId", "memberUid"])
    XCTAssertEqual(uid.memberId, "synthMember0001")
    let pending = BodyCompositionRecordQuery(trainerUid: "synthTrainerA", member: .pending("SynthPending00000001"),
                                             since: since)
    XCTAssertEqual(pending.equalityFields, ["trainerId", "pendingMemberId"])
    XCTAssertEqual(BodyCompositionRecordQuery.collection, "bodyCompositionRecords")
    XCTAssertEqual(BodyCompositionRecordQuery.orderField, "measuredAt")
  }

  /// The query needs no new index: `(trainerId, <member key>, measuredAt desc)` exists for both member keys.
  func testAnExistingCompositeIndexServesTheQuery() throws {
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0..<6 { root.deleteLastPathComponent() }  // file, FirebaseDataTests, Tests, TrainerKit, Packages, trainer_app
    let data = try Data(contentsOf: root.appendingPathComponent("firestore.indexes.json"))
    let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    let indexes = try XCTUnwrap(json["indexes"] as? [[String: Any]])
    let shapes: [[String]] = indexes.compactMap { index in
      guard index["collectionGroup"] as? String == "bodyCompositionRecords",
        index["queryScope"] as? String ?? "COLLECTION" == "COLLECTION",
        let fields = index["fields"] as? [[String: Any]]
      else { return nil }
      return fields.map { "\($0["fieldPath"] ?? "")/\($0["order"] ?? "")" }
    }
    for member in [MemberKey.uid("m"), .pending("p")] {
      let query = BodyCompositionRecordQuery(trainerUid: "t", member: member, since: since)
      let needed = query.equalityFields.map { "\($0)/ASCENDING" } + ["measuredAt/DESCENDING"]
      XCTAssertTrue(shapes.contains(needed), "no index \(needed) in firestore.indexes.json")
    }
  }
}
