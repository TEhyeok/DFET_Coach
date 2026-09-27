import Foundation
import os
import SwiftData
import SyncEngine
import TrainerDomain

/// The SyncEngine's `OutboxStore` on one trainer's LocalStore partition (DF-108, V1-04 §10.2, ADR-002).
///
/// A model actor: every read and write runs on its own serial executor and saves before returning, so the engine's
/// ordered flushes reach disk in order. Following the `OutboxStore` contract, `insert` of a known id replaces the row,
/// `update` of a missing row does nothing, and only an unusable store throws: a problem with one item (a missing file
/// row, a payload or value this build cannot read) fails that item only. A failed save is rolled back, so nothing
/// unsaved stays pending in the context. Rows are always scoped to `trainerUid` (AC-DF-014.1).
public actor LocalOutboxStore: OutboxStore, ModelActor {
  public nonisolated let modelContainer: ModelContainer
  public nonisolated let modelExecutor: any ModelExecutor
  private let trainerUid: String
  private let binaries: LocalBinaryStore?
  /// The last sequence handed out per member key, so two callers never get the same one (V1-05 §12.2).
  private var reservedSequences: [String: Int64] = [:]
  private static let logger = Logger(subsystem: "kr.co.dfet.trainer", category: "outbox")

  /// `binaries` resolves `LocalBinaryRef`s of upload items; nil when the caller has no binary items.
  public init(container: ModelContainer, trainerUid: String, binaries: LocalBinaryStore?) {
    modelContainer = container
    modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(container))
    self.trainerUid = trainerUid
    self.binaries = binaries
  }

  /// Every row. One this build cannot read is loaded as a failed item (`local-unreadable`, no payload), so it still
  /// holds the later items of its record and member instead of letting them run first (NFR-05).
  public func loadAll() async throws -> [TrainerDomain.OutboxItem] {
    let rows = try modelContext.fetchOwned(OutboxItem.self, by: trainerUid)
    var items: [TrainerDomain.OutboxItem] = []
    var unreadable = 0
    for row in rows {
      if let item = OutboxRowMapping.value(of: row, binary: try binaryRef(row.binaryId)) {
        items.append(item)
      } else {
        unreadable += 1
        items.append(OutboxRowMapping.unreadable(row))
      }
    }
    if unreadable > 0 { Self.logger.error("outbox rows unreadable, held as failed: \(unreadable, privacy: .public)") }
    return items.sorted { $0.sequence < $1.sequence }
  }

  public func insert(_ item: TrainerDomain.OutboxItem) async throws {
    try put(item)
    try saveOrRollback()
  }

  public func update(_ item: TrainerDomain.OutboxItem) async throws {
    guard let row = try row(item.id) else { return }  // deleted outside the engine (retention)
    apply(item, to: row)
    try saveOrRollback()
  }

  /// A pending member's draft and its stage 0 create, in one save (AC-DF-108.3): the member never exists on the
  /// device without the item that creates it on the server. The engine is told afterwards (`enqueue`); its own
  /// insert of the same id then only rewrites the row.
  public func insertPendingMember(_ draft: PendingMemberDraftRecord, createItem item: TrainerDomain.OutboxItem) throws {
    modelContext.insert(LocalPendingMemberDraft(
      pendingMemberId: draft.pendingMemberId, trainerUid: trainerUid, displayName: draft.displayName, sex: draft.sex,
      birthYear: draft.birthYear, ageConfirmed14: draft.ageConfirmed14, createdLocallyAt: draft.createdLocallyAt,
      outboxItemId: item.id))
    try put(item)
    try saveOrRollback()
  }

  /// The next per-member sequence (V1-05 §12.2 `sequence` is monotonic per `memberKey`): above every stored row and
  /// every sequence already handed out, so concurrent callers and items not yet saved never share one.
  public func nextSequence(for member: MemberKey) throws -> Int64 {
    let key = member.storageValue
    let uid = trainerUid
    var descriptor = FetchDescriptor<OutboxItem>(
      predicate: #Predicate { $0.trainerUid == uid && $0.memberKey == key },
      sortBy: [SortDescriptor(\.sequence, order: .reverse)])
    descriptor.fetchLimit = 1
    let next = max(try modelContext.fetch(descriptor).first?.sequence ?? 0, reservedSequences[key] ?? 0) + 1
    reservedSequences[key] = next
    return next
  }

  /// Inserts the row, or rewrites it when the id is already there (a retried insert after a save that committed).
  private func put(_ item: TrainerDomain.OutboxItem) throws {
    if let existing = try row(item.id) {
      apply(item, to: existing)
      return
    }
    let binaryRow = try item.binary.flatMap { try binaryId(for: $0) }
    if item.binary != nil, binaryRow == nil {
      // Stored without it: after a reload the item fails as malformed, alone (review M2).
      Self.logger.error("upload item without a LocalBinary row: stage=\(item.stage.rawValue, privacy: .public)")
    }
    modelContext.insert(OutboxRowMapping.row(from: item, trainerUid: trainerUid, binaryId: binaryRow))
  }

  private func apply(_ item: TrainerDomain.OutboxItem, to row: OutboxItem) {
    OutboxRowMapping.apply(item, to: row)
    if item.state == .acked, item.kind == .createDocument, case let .pending(id) = item.memberKey,
      item.entityRef == .pendingMember(id: id) {
      deletePendingMemberDraft(id)  // the server has it now (ASM-05-38)
    }
  }

  private func saveOrRollback() throws {
    do {
      try modelContext.save()
    } catch {
      modelContext.rollback()
      throw error
    }
  }

  private func deletePendingMemberDraft(_ id: String) {
    let uid = trainerUid
    let drafts = (try? modelContext.fetch(FetchDescriptor<LocalPendingMemberDraft>(
      predicate: #Predicate { $0.pendingMemberId == id && $0.trainerUid == uid }))) ?? []
    drafts.forEach(modelContext.delete)
  }

  private func row(_ id: UUID) throws -> OutboxItem? {
    let uid = trainerUid
    var descriptor = FetchDescriptor<OutboxItem>(predicate: #Predicate { $0.id == id && $0.trainerUid == uid })
    descriptor.fetchLimit = 1
    return try modelContext.fetch(descriptor).first
  }

  private func binaryRef(_ id: UUID?) throws -> LocalBinaryRef?? {
    guard let id else { return .some(nil) }
    let uid = trainerUid
    guard let row = try modelContext.fetch(FetchDescriptor<LocalBinary>(
      predicate: #Predicate { $0.id == id && $0.trainerUid == uid })).first,
      let url = try? binaries?.url(forRelativePath: row.relativePath)
    else { return nil }  // the item needs a file that is gone: unreadable
    return .some(LocalBinaryRef(localURL: url, contentType: row.contentType, sha256: row.sha256))
  }

  /// The `LocalBinary` row of this very file (its partition-relative path), not of another file with the same bytes.
  private func binaryId(for ref: LocalBinaryRef) throws -> UUID? {
    guard let root = binaries?.location.partitionURL.standardizedFileURL.path else { return nil }
    let path = ref.localURL.standardizedFileURL.path
    guard path.hasPrefix(root + "/") else { return nil }
    let relative = String(path.dropFirst(root.count + 1))
    let uid = trainerUid
    return try modelContext.fetch(FetchDescriptor<LocalBinary>(
      predicate: #Predicate { $0.relativePath == relative && $0.trainerUid == uid })).first?.id
  }
}

/// What `insertPendingMember` stores in `LocalPendingMemberDraft` (a value, so it can cross into the actor).
public struct PendingMemberDraftRecord: Sendable {
  public let pendingMemberId: String
  public let displayName: String
  public let sex: String
  public let birthYear: Int
  public let ageConfirmed14: Bool
  public let createdLocallyAt: Date

  public init(
    pendingMemberId: String, displayName: String, sex: String, birthYear: Int, ageConfirmed14: Bool,
    createdLocallyAt: Date
  ) {
    self.pendingMemberId = pendingMemberId
    self.displayName = displayName
    self.sex = sex
    self.birthYear = birthYear
    self.ageConfirmed14 = ageConfirmed14
    self.createdLocallyAt = createdLocallyAt
  }
}

/// Row ↔ value mapping of `OutboxItem`. The row keeps the target path only; the target kind follows from `kind`.
enum OutboxRowMapping {
  static func row(from item: TrainerDomain.OutboxItem, trainerUid: String, binaryId: UUID?) -> OutboxItem {
    let (state, blocked) = storage(item.state)
    // The local enums have the domain's raw values (LocalOutboxStoreTests), so these never fail.
    return OutboxItem(
      id: item.id, requestId: item.requestId, trainerUid: trainerUid, memberKey: item.memberKey,
      entityRef: item.entityRef.rawValue, sequence: item.sequence,
      stage: LocalOutboxStage(rawValue: item.stage.rawValue)!, kind: LocalOutboxKind(rawValue: item.kind.rawValue)!,
      targetPath: path(item.target), payloadJSON: storedPayload(item), binaryId: binaryId,
      dependsOn: item.dependsOn, attempts: item.attempts, nextAttemptAt: item.nextAttemptAt, state: state,
      blockedReason: blocked, lastErrorCode: item.lastErrorCode, ackConfirmed: item.ack?.isConfirmed,
      createdAt: item.createdAt)
  }

  /// Copies what the engine may change.
  static func apply(_ item: TrainerDomain.OutboxItem, to row: OutboxItem) {
    let (state, blocked) = storage(item.state)
    row.state = state.rawValue
    row.blockedReason = blocked?.rawValue
    row.attempts = item.attempts
    row.nextAttemptAt = item.nextAttemptAt
    row.lastErrorCode = item.lastErrorCode
    row.ackConfirmed = item.ack?.isConfirmed
    row.dependsOn = item.dependsOn
    row.payloadJSON = storedPayload(item)
  }

  /// An acked item's payload is never read again, so it is not kept: a pending member's name, sex and birth year
  /// leave the device with the draft once the server has them (ASM-05-38, review M1).
  static func storedPayload(_ item: TrainerDomain.OutboxItem) -> Data? {
    item.state == .acked ? nil : item.payload?.storageData()
  }

  /// A row `value(of:binary:)` cannot read, as a failed item that is never sent as it is: no payload and no file, so
  /// a retry fails as malformed again. Its record and member order still hold (sequence, entity, member key).
  static func unreadable(_ row: OutboxItem) -> TrainerDomain.OutboxItem {
    let kind = OutboxKind(rawValue: row.kind) ?? .updateDocument
    return TrainerDomain.OutboxItem(
      id: row.id, requestId: row.requestId, memberKey: MemberKey(storageValue: row.memberKey) ?? .uid(row.memberKey),
      entityRef: TrainerDomain.LocalEntityRef(rawValue: row.entityRef), sequence: row.sequence,
      stage: OutboxStage(rawValue: row.stage) ?? .document, kind: kind, target: target(kind, path: row.targetPath),
      payload: nil, binary: nil, dependsOn: row.dependsOn, attempts: row.attempts, nextAttemptAt: row.nextAttemptAt,
      state: .failed, lastErrorCode: unreadableCode, createdAt: row.createdAt)
  }

  static let unreadableCode = "local-unreadable"

  /// nil for a row the engine cannot use (unknown kind, stage, state or member key, or an unreadable payload).
  static func value(of row: OutboxItem, binary: LocalBinaryRef??) -> TrainerDomain.OutboxItem? {
    guard let binary,
      let member = MemberKey(storageValue: row.memberKey),
      let stage = OutboxStage(rawValue: row.stage),
      let kind = OutboxKind(rawValue: row.kind),
      let state = state(row.state, blockedReason: row.blockedReason)
    else { return nil }
    let payload: JSONValue?
    if let data = row.payloadJSON {
      guard let decoded = try? JSONValue(storageData: data) else { return nil }
      payload = decoded
    } else {
      payload = nil
    }
    return TrainerDomain.OutboxItem(
      id: row.id, requestId: row.requestId, memberKey: member, entityRef: TrainerDomain.LocalEntityRef(rawValue: row.entityRef),
      sequence: row.sequence, stage: stage, kind: kind, target: target(kind, path: row.targetPath), payload: payload,
      binary: binary, dependsOn: row.dependsOn, attempts: row.attempts, nextAttemptAt: row.nextAttemptAt,
      state: state, lastErrorCode: row.lastErrorCode,
      ack: row.ackConfirmed.map { ack(kind, confirmed: $0, path: row.targetPath, sha256: binary?.sha256) },
      createdAt: row.createdAt)
  }

  static func path(_ target: RemoteTarget) -> String {
    switch target {
    case let .document(path), let .storage(path): return path
    case let .callable(name): return name
    }
  }

  static func target(_ kind: OutboxKind, path: String) -> RemoteTarget {
    switch kind {
    case .createDocument, .updateDocument, .deleteDocument, .recordBinaryPath, .finalize: return .document(path: path)
    case .uploadBinary, .deleteBinary: return .storage(path: path)
    case .callConsent, .callFunction: return .callable(name: path)
    }
  }

  /// The ack as the engine made it for this kind (`SyncEngine.perform`), with only its confirmation kept.
  static func ack(_ kind: OutboxKind, confirmed: Bool, path: String, sha256: String?) -> OutboxAck {
    switch kind {
    case .createDocument, .updateDocument, .deleteDocument, .recordBinaryPath, .finalize:
      return .write(WriteAck(serverCommitted: confirmed))
    case .uploadBinary:
      return .upload(UploadReceipt(path: path, size: 0, sha256: sha256 ?? "", verified: confirmed))
    case .deleteBinary, .callConsent, .callFunction:
      return .call
    }
  }

  static func storage(_ state: OutboxItemState) -> (LocalOutboxState, LocalOutboxBlockedReason?) {
    switch state {
    case .queued: return (.queued, nil)
    case .inFlight: return (.inFlight, nil)
    case .acked: return (.acked, nil)
    case .failed: return (.failed, nil)
    case let .blocked(reason): return (.blocked, LocalOutboxBlockedReason(rawValue: reason.rawValue))
    case .superseded: return (.superseded, nil)
    }
  }

  static func state(_ raw: String, blockedReason: String?) -> OutboxItemState? {
    switch LocalOutboxState(rawValue: raw) {
    case .queued?: return .queued
    case .inFlight?: return .inFlight
    case .acked?: return .acked
    case .failed?: return .failed
    case .superseded?: return .superseded
    case .blocked?:
      guard let reason = blockedReason.flatMap(OutboxBlockedReason.init(rawValue:)) else { return nil }
      return .blocked(reason)
    case nil: return nil
    }
  }
}
