import FirebaseFirestore
import Foundation
import TrainerDomain

public struct FirestorePendingMemberDirectory: MemberDirectory {
  private let trainerUid: String
  public init(trainerUid: String) { self.trainerUid = trainerUid }

  public func observeAssignedMembers() -> AsyncThrowingStream<[Member], Error> {
    AsyncThrowingStream { continuation in
      let registration = Firestore.firestore().collection("pendingMembers")
        .whereField("trainerId", isEqualTo: trainerUid).whereField("status", isEqualTo: "pending")
        .addSnapshotListener { snapshot, error in
          if let error { continuation.finish(throwing: MemberDirectoryErrorMapper.map(error)); return }
          guard let snapshot else { return }
          continuation.yield(snapshot.documents.map {
            Member(id: $0.documentID, displayName: $0.get("displayName") as? String ?? "",
                   trainerId: trainerUid, isPending: true)
          })
        }
      let token = FirestoreListenerRegistry.shared.add(registration)
      continuation.onTermination = { _ in FirestoreListenerRegistry.shared.remove(token) }
    }
  }
}

public struct FirestoreMeasurementRecordsSource: MeasurementRecordsSource {
  private let trainerUid: String
  public init(trainerUid: String) { self.trainerUid = trainerUid }

  public func records(member: MemberKey, since: Date) -> AsyncThrowingStream<[BodyCompositionRecord], Error> {
    AsyncThrowingStream { continuation in
      let memberField: String
      switch member { case .pending: memberField = "pendingMemberId"; case .uid: memberField = "memberUid" }
      let registration = Firestore.firestore().collection(BodyCompositionPayload.collection)
        .whereField("trainerId", isEqualTo: trainerUid).whereField(memberField, isEqualTo: member.id)
        .whereField("measuredAt", isGreaterThanOrEqualTo: Timestamp(date: max(since, FirestorePayload.timestampRange.lowerBound)))
        .order(by: "measuredAt", descending: true)
        .addSnapshotListener { snapshot, error in
          if let error { continuation.finish(throwing: MemberDirectoryErrorMapper.map(error)); return }
          guard let snapshot else { return }
          continuation.yield(snapshot.documents.compactMap {
            BodyCompositionRecord(id: $0.documentID, document: JSONValueFirestoreMapper.json($0.data()))
          })
        }
      let token = FirestoreListenerRegistry.shared.add(registration)
      continuation.onTermination = { _ in FirestoreListenerRegistry.shared.remove(token) }
    }
  }
}
