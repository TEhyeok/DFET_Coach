import Foundation
import SwiftData
import TrainerDomain

/// What `insertMeasurement` stores in `LocalMeasurementDraft` (a value, so it can cross into the actor).
struct MeasurementDraftRecord: Sendable {
  let recordId: String
  let member: MemberKey
  let kind: LocalMeasurementKind
  /// The create fields (V1-05 §4.7 shape, without the server timestamps).
  let payload: JSONValue
  let createdLocallyAt: Date
}

/// Measurement rows on the partition's model actor (DF-127). They live here, not in their own actor, because a
/// record and its Outbox create must be one save (the DF-108 `insertPendingMember` rule).
extension LocalOutboxStore {
  /// A measurement draft, its `createDocument` item and the use of its device, in one save: the record never exists on
  /// the device without the item that creates it on the server. The engine is told afterwards (`enqueue`).
  func insertMeasurement(_ draft: MeasurementDraftRecord, createItem item: TrainerDomain.OutboxItem,
                         deviceModel: String?, usedAt: Date) throws {
    modelContext.insert(LocalMeasurementDraft(
      recordId: draft.recordId, trainerUid: trainerUid, memberKey: draft.member, kind: draft.kind,
      payloadJSON: draft.payload.storageData(), createdLocallyAt: draft.createdLocallyAt))
    if let deviceModel { try markDeviceModelUsed(deviceModel, at: usedAt) }
    try put(item)
    try saveOrRollback()
  }

  /// The member's body composition drafts the server does not have yet: a draft with an Outbox item that is neither
  /// acked nor superseded (queued, in flight, blocked or failed). Synced drafts are left out, so a record the server
  /// later removes (consent withdrawal, DF-133) does not live on in this device's trends. Unreadable rows are skipped.
  func unsyncedBodyCompositionRecords(member: MemberKey) throws -> [BodyCompositionRecord] {
    let uid = trainerUid
    let key = member.storageValue
    let kind = LocalMeasurementKind.bodyComposition.rawValue
    let drafts = try modelContext.fetch(FetchDescriptor<LocalMeasurementDraft>(
      predicate: #Predicate { $0.trainerUid == uid && $0.memberKey == key && $0.kind == kind }))
    guard !drafts.isEmpty else { return [] }
    let finished: Set<String> = [LocalOutboxState.acked.rawValue, LocalOutboxState.superseded.rawValue]
    let items = try modelContext.fetch(FetchDescriptor<OutboxItem>(
      predicate: #Predicate { $0.trainerUid == uid && $0.memberKey == key }))
    let waiting = Set(items.filter { !finished.contains($0.state) }.map(\.entityRef))
    return drafts.compactMap { draft in
      guard waiting.contains(draft.entityRef), let payload = try? JSONValue(storageData: draft.payloadJSON) else {
        return nil
      }
      return BodyCompositionRecord(id: draft.recordId, document: payload)
    }
  }

  /// Stored device names, most recently used first (ties by name).
  func deviceModelNames() throws -> [String] {
    try modelContext.fetchOwned(DeviceModelEntry.self, by: trainerUid)
      .sorted { ($0.lastUsedAt, $1.name) > ($1.lastUsedAt, $0.name) }
      .map(\.name)
  }

  /// Adds `name` (already normalized) or moves it to the top of the list, and saves.
  func useDeviceModel(_ name: String, at date: Date) throws {
    try markDeviceModelUsed(name, at: date)
    try saveOrRollback()
  }

  private func markDeviceModelUsed(_ name: String, at date: Date) throws {
    let id = DeviceModelEntry.key(trainerUid: trainerUid, name: name)
    var descriptor = FetchDescriptor<DeviceModelEntry>(predicate: #Predicate { $0.id == id })
    descriptor.fetchLimit = 1
    if let existing = try modelContext.fetch(descriptor).first {
      existing.lastUsedAt = max(existing.lastUsedAt, date)
    } else {
      modelContext.insert(DeviceModelEntry(trainerUid: trainerUid, name: name, lastUsedAt: date))
    }
  }
}
