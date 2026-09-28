import FirebaseFirestore
import Foundation
import TrainerDomain

/// The DF-130 mini trend query (card implementation note, V1-06 query catalogue):
/// `bodyCompositionRecords where trainerId == uid && <memberUid | pendingMemberId> == m && measuredAt >= since
/// order by measuredAt desc`. Without `since` it is TR-11's latest-record read, a page at a time (DF-127 second review).
///
/// - `trainerId == uid` is what lets the rules prove the list (`isAccessTrainer`, PRD §9.6).
/// - The equality fields and the descending `measuredAt` are exactly the composite indexes
///   `(trainerId, memberUid, measuredAt desc)` and `(trainerId, pendingMemberId, measuredAt desc)` in
///   firestore.indexes.json (checked by FirebaseDataTests), so no index is added.
/// - There is no `status == active` filter: it would need another index. Voided records come back and
///   `BodyCompositionSeries` leaves them out of the trend (AC-DF-130.11); TR-03 lists them (DF-114).
struct BodyCompositionRecordQuery: Equatable, Sendable {
  static let collection = BodyCompositionPayload.collection
  static let orderField = "measuredAt"

  let trainerUid: String
  let memberField: String
  let memberId: String
  /// nil: every date.
  let since: Date?

  init(trainerUid: String, member: MemberKey, since: Date?) {
    self.trainerUid = trainerUid
    switch member {
    case let .uid(id):
      memberField = "memberUid"
      memberId = id
    case let .pending(id):
      memberField = "pendingMemberId"
      memberId = id
    }
    self.since = since
  }

  /// Equality fields in index order.
  var equalityFields: [String] { ["trainerId", memberField] }

  func firestoreQuery(_ db: Firestore) -> Query {
    let ofMember = db.collection(Self.collection)
      .whereField("trainerId", isEqualTo: trainerUid)
      .whereField(memberField, isEqualTo: memberId)
    let dated = since.map { ofMember.whereField(Self.orderField, isGreaterThanOrEqualTo: Timestamp(date: $0)) } ?? ofMember
    return dated.order(by: Self.orderField, descending: true)
  }
}

/// The signed-in trainer's body composition records of one member, from a Firestore listener (DF-130). Offline, the
/// cache answers. Documents that cannot be read as a record (no `measuredAt` timestamp) are skipped; a refused read
/// fails the stream with its `RemoteError`, never an empty list (§9.6).
public final class FirestoreBodyCompositionRecords: BodyCompositionRecordSource, Sendable {
  /// One page of `latestActiveRecord(member:)`.
  static let latestPageSize = 10
  private let trainerUid: String

  public init(trainerUid: String) {
    self.trainerUid = trainerUid
  }

  public func observeRecords(member: MemberKey, since: Date) -> AsyncThrowingStream<[BodyCompositionRecord], Error> {
    let query = BodyCompositionRecordQuery(trainerUid: trainerUid, member: member, since: since)
    return AsyncThrowingStream { continuation in
      let registration = query.firestoreQuery(Firestore.firestore()).addSnapshotListener { snapshot, error in
        if let error {
          continuation.finish(throwing: RemoteErrorMapper.map(error))
          return
        }
        guard let snapshot else { return }
        continuation.yield(snapshot.documents.compactMap { document in
          BodyCompositionRecord(id: document.documentID, document: JSONValueFirestoreMapper.json(document.data()))
        })
      }
      let token = FirestoreListenerRegistry.shared.add(registration)
      continuation.onTermination = { _ in FirestoreListenerRegistry.shared.remove(token) }
    }
  }

  /// Records newest first, `latestPageSize` at a time, until an active one: voided records are skipped here because a
  /// `status == active` filter would need another index.
  public func latestActiveRecord(member: MemberKey) async throws -> BodyCompositionRecord? {
    var page = BodyCompositionRecordQuery(trainerUid: trainerUid, member: member, since: nil)
      .firestoreQuery(Firestore.firestore())
      .limit(to: Self.latestPageSize)
    do {
      while true {
        let snapshot = try await page.getDocuments()
        let records = snapshot.documents.compactMap { document in
          BodyCompositionRecord(id: document.documentID, document: JSONValueFirestoreMapper.json(document.data()))
        }
        if let latest = BodyCompositionSeries.latestActive(records) { return latest }
        guard snapshot.documents.count == Self.latestPageSize, let last = snapshot.documents.last else { return nil }
        page = page.start(afterDocument: last)
      }
    } catch {
      throw RemoteErrorMapper.map(error)
    }
  }
}

/// `memberConsentStates/{memberKey}` from a Firestore listener (DF-111 MVP `ConsentStateSource`; DF-110's
/// `FirestoreConsentService.observeState` takes it over). Only this reads the consent state; screens read
/// `EffectiveConsent` (AC-DF-111.7). A missing document is nil (no consent, the rules' `hasConsent` reading). A read
/// the rules refuse (the member is not this trainer's) is nil too and ends the stream: it fails closed.
public final class FirestoreConsentStates: ConsentStateSource, Sendable {
  static let collection = "memberConsentStates"

  public init() {}

  public func observe(member: MemberKey) -> AsyncStream<ConsentState?> {
    AsyncStream { continuation in
      let registration = Firestore.firestore().collection(Self.collection).document(member.id)
        .addSnapshotListener { snapshot, error in
          if error != nil {
            continuation.yield(nil)
            continuation.finish()
            return
          }
          guard let snapshot else { return }
          continuation.yield(snapshot.exists ? ConsentState(document: JSONValueFirestoreMapper.json(snapshot.data())) : nil)
        }
      let token = FirestoreListenerRegistry.shared.add(registration)
      continuation.onTermination = { _ in FirestoreListenerRegistry.shared.remove(token) }
    }
  }
}
