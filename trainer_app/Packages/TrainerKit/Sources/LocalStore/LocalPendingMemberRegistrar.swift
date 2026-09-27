import Foundation
import SyncEngine
import TrainerDomain

/// `PendingMemberRegistrar` on LocalStore (DF-108, AC-DF-108.3/.5): saves `LocalPendingMemberDraft` and the
/// `pendingMembers/{id}` create, a stage 0 (`memberKey`) Outbox item, in one save, then hands the item to the
/// SyncEngine. Nothing waits for the server. Later items of this member (consent captures, records) come after it: the engine sends a member's stage 0
/// item before anything else of that member.
public final class LocalPendingMemberRegistrar: PendingMemberRegistrar {
  private let outbox: LocalOutboxStore
  private let trainerUid: String
  private let enqueue: @Sendable (TrainerDomain.OutboxItem) async -> Void
  private let now: @Sendable () -> Date
  private let makeID: @Sendable () -> String

  public init(
    outbox: LocalOutboxStore, trainerUid: String,
    enqueue: @escaping @Sendable (TrainerDomain.OutboxItem) async -> Void,
    now: @escaping @Sendable () -> Date = Date.init, makeID: @escaping @Sendable () -> String = DocumentID.make
  ) {
    self.outbox = outbox
    self.trainerUid = trainerUid
    self.enqueue = enqueue
    self.now = now
    self.makeID = makeID
  }

  public func register(_ draft: PendingMemberDraft) async throws -> String {
    let date = now()
    guard let fields = PendingMemberPayload.fields(draft, trainerUid: trainerUid, now: date),
      let sex = draft.sex, let birthYear = draft.birthYear
    else { throw PendingMemberRegistrationError.invalidDraft }
    let id = makeID()
    let member = MemberKey.pending(id)
    let item = TrainerDomain.OutboxItem(
      memberKey: member, entityRef: .pendingMember(id: id), sequence: try await outbox.nextSequence(for: member),
      stage: .memberKey, kind: .createDocument, target: .document(path: PendingMemberPayload.path(id: id)),
      payload: fields, createdAt: date)
    try await outbox.insertPendingMember(
      PendingMemberDraftRecord(
        pendingMemberId: id, displayName: draft.trimmedName, sex: sex.rawValue, birthYear: birthYear,
        ageConfirmed14: true, createdLocallyAt: date),
      createItem: item)
    await enqueue(item)
    return id
  }
}
