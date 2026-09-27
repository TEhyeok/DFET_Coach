import Foundation
import SwiftData
import SyncEngine
import TrainerDomain

/// `PendingMemberRegistrar` on LocalStore (DF-108, AC-DF-108.3/.5): saves `LocalPendingMemberDraft`, then hands the
/// `pendingMembers/{id}` create to the SyncEngine as a stage 0 (`memberKey`) Outbox item. Nothing waits for the
/// server. Later items of this member (consent captures, records) come after it: the engine sends a member's stage 0
/// item before anything else of that member.
public final class LocalPendingMemberRegistrar: PendingMemberRegistrar {
  private let container: ModelContainer
  private let outbox: LocalOutboxStore
  private let trainerUid: String
  private let enqueue: @Sendable (TrainerDomain.OutboxItem) async -> Void
  private let now: @Sendable () -> Date
  private let makeID: @Sendable () -> String

  public init(
    container: ModelContainer, outbox: LocalOutboxStore, trainerUid: String,
    enqueue: @escaping @Sendable (TrainerDomain.OutboxItem) async -> Void,
    now: @escaping @Sendable () -> Date = Date.init, makeID: @escaping @Sendable () -> String = DocumentID.make
  ) {
    self.container = container
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
    try await MainActor.run { [container, trainerUid] in
      let context = ModelContext(container)
      context.insert(LocalPendingMemberDraft(
        pendingMemberId: id, trainerUid: trainerUid, displayName: draft.trimmedName, sex: sex.rawValue,
        birthYear: birthYear, ageConfirmed14: true, createdLocallyAt: date, outboxItemId: item.id))
      try context.save()
    }
    await enqueue(item)
    return id
  }
}
