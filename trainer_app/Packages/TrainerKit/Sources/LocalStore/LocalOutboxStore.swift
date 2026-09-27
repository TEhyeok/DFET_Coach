import Foundation
import os
import SwiftData
import SyncEngine
import TrainerDomain

/// The SyncEngine's `OutboxStore` on one trainer's LocalStore partition (DF-108, V1-04 §10.2, ADR-002).
///
/// A model actor: every read and write runs on its own serial executor and saves before returning, so the engine's
/// ordered flushes reach disk in order. Following the `OutboxStore` contract, `insert` of a known id and `update` of a
/// missing row do nothing; only an unusable store throws. Rows are always scoped to `trainerUid` (AC-DF-014.1).
public actor LocalOutboxStore: OutboxStore, ModelActor {
  public nonisolated let modelContainer: ModelContainer
  public nonisolated let modelExecutor: any ModelExecutor
  private let trainerUid: String
  private let binaries: LocalBinaryStore?
  private static let logger = Logger(subsystem: "kr.co.dfet.trainer", category: "outbox")

  /// `binaries` resolves `LocalBinaryRef`s of upload items; nil when the caller has no binary items.
  public init(container: ModelContainer, trainerUid: String, binaries: LocalBinaryStore?) {
    modelContainer = container
    modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(container))
    self.trainerUid = trainerUid
    self.binaries = binaries
  }

  public func loadAll() async throws -> [TrainerDomain.OutboxItem] {
    let rows = try modelContext.fetchOwned(OutboxItem.self, by: trainerUid)
    var items: [TrainerDomain.OutboxItem] = []
    var unreadable = 0
    for row in rows {
      if let item = OutboxRowMapping.value(of: row, binary: try binaryRef(row.binaryId)) {
        items.append(item)
      } else {
        unreadable += 1
      }
    }
    if unreadable > 0 { Self.logger.error("outbox rows skipped as unreadable: \(unreadable, privacy: .public)") }
    return items.sorted { $0.sequence < $1.sequence }
  }

  public func insert(_ item: TrainerDomain.OutboxItem) async throws {
    guard try row(item.id) == nil else { return }  // idempotent
    let binaryRow = try item.binary.map { try binaryId(for: $0) }
    modelContext.insert(OutboxRowMapping.row(from: item, trainerUid: trainerUid, binaryId: binaryRow))
    try modelContext.save()
  }

  public func update(_ item: TrainerDomain.OutboxItem) async throws {
    guard let row = try row(item.id) else { return }  // deleted outside the engine (retention)
    OutboxRowMapping.apply(item, to: row)
    if item.state == .acked, item.kind == .createDocument, case let .pending(id) = item.memberKey,
      item.entityRef == .pendingMember(id: id) {
      try deletePendingMemberDraft(id)  // the server has it now (ASM-05-38)
    }
    try modelContext.save()
  }

  private func deletePendingMemberDraft(_ id: String) throws {
    let uid = trainerUid
    let drafts = try modelContext.fetch(FetchDescriptor<LocalPendingMemberDraft>(
      predicate: #Predicate { $0.pendingMemberId == id && $0.trainerUid == uid }))
    drafts.forEach(modelContext.delete)
  }

  /// The next per-member sequence (V1-05 §12.2 `sequence` is monotonic per `memberKey`).
  public func nextSequence(for member: MemberKey) throws -> Int64 {
    let key = member.storageValue
    let uid = trainerUid
    var descriptor = FetchDescriptor<OutboxItem>(
      predicate: #Predicate { $0.trainerUid == uid && $0.memberKey == key },
      sortBy: [SortDescriptor(\.sequence, order: .reverse)])
    descriptor.fetchLimit = 1
    return (try modelContext.fetch(descriptor).first?.sequence ?? 0) + 1
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

  private func binaryId(for ref: LocalBinaryRef) throws -> UUID {
    let uid = trainerUid
    let sha = ref.sha256
    guard let row = try modelContext.fetch(FetchDescriptor<LocalBinary>(
      predicate: #Predicate { $0.sha256 == sha && $0.trainerUid == uid })).first
    else { throw LocalOutboxStoreError.binaryNotFound }
    return row.id
  }
}

public enum LocalOutboxStoreError: Error, Equatable, Sendable {
  /// An upload item names a file that has no `LocalBinary` row.
  case binaryNotFound
}

/// Row ↔ value mapping of `OutboxItem`. The row keeps the target path only; the target kind follows from `kind`.
enum OutboxRowMapping {
  static func row(from item: TrainerDomain.OutboxItem, trainerUid: String, binaryId: UUID?) -> OutboxItem {
    let (state, blocked) = storage(item.state)
    return OutboxItem(
      id: item.id, requestId: item.requestId, trainerUid: trainerUid, memberKey: item.memberKey,
      entityRef: item.entityRef.rawValue, sequence: item.sequence,
      stage: LocalOutboxStage(rawValue: item.stage.rawValue) ?? .document,
      kind: LocalOutboxKind(rawValue: item.kind.rawValue) ?? .updateDocument,
      targetPath: path(item.target), payloadJSON: item.payload?.storageData(), binaryId: binaryId,
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
    row.payloadJSON = item.payload?.storageData()
  }

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
