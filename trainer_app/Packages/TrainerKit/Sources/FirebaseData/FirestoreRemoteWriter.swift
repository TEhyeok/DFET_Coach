import FirebaseFirestore
import Foundation
import os
import TrainerDomain

/// One server read of a document with the metadata that says whether it is the server's settled state.
struct ServerDocument: @unchecked Sendable {
  /// nil when the document does not exist.
  let fields: [String: Any]?
  /// This device still has unconfirmed writes on the document (the snapshot shows them).
  let hasPendingWrites: Bool
  let isFromCache: Bool
}

/// The Firestore calls behind `FirestoreRemoteWriter`, separated so tests can run without Firebase.
protocol FirestoreDocumentAccess: Sendable {
  /// `getDocument(source: .server)`. The rules let a trainer read only their own documents and check
  /// `resource.data`, so a missing document is usually `permission-denied` too.
  func serverDocument(path: String) async throws -> ServerDocument
  /// `Firestore.waitForPendingWrites()`, given up after `seconds`. True when every pending write was confirmed.
  func waitForPendingWrites(seconds: TimeInterval) async -> Bool
  /// `setData(fields, merge: false)`; returns when the server committed the write.
  func create(path: String, fields: [String: Any]) async throws
  /// `updateData(fields)`; returns when the server committed the write.
  func update(path: String, fields: [String: Any]) async throws
  func delete(path: String) async throws
}

/// Firestore implementation of `RemoteWriter` (DF-104).
///
/// Every write goes out first. A create or update is reconciled only when the server denies it (V1-04 §10.5): a write
/// whose earlier attempt committed before the app lost the reply is denied the second time (a second create counts as
/// an update; finalized and voided documents are frozen). On `permission-denied` the writer waits for this device's
/// pending writes (at most 30 s), reads the document from the server once and decides:
/// - create: the document exists and this trainer wrote it (`authorUid`, `enteredBy` or `trainerId`) → committed
///   (AC-DF-015.5, AC-DF-104.3).
/// - update (and finalize, void): the server already has every non-server-time field of the payload → committed.
/// - the read shows unconfirmed local writes, or this device's writes did not drain → `serverCommitted: false`, so
///   the SyncEngine retries later instead of failing for good.
/// Otherwise the denial stands. A delete needs no reconciliation: the rules let a trainer delete a missing draft
/// (idempotent), so a delete sent again succeeds and a denial is real (never taken as done, NFR-06). There is no client timeout: the SDK's completion is the only proof of a commit, and
/// its writes cannot be cancelled (AC-DF-104.5).
///
/// `createIfAbsent` adds `createdAt` and `updatedAt` as server time (only `createdAt` on append-only `addenda`, whose
/// rules allow no `updatedAt`). `update` refuses a payload that touches `createdAt` (NFR-07) and sets `updatedAt`.
/// Paths and payloads are checked first, because the SDK raises uncatchable exceptions for malformed ones.
public final class FirestoreRemoteWriter: RemoteWriter, Sendable {
  private static let logger = Logger(subsystem: "kr.co.dfet.trainer", category: "remote")
  static let ownerKeys = ["authorUid", "enteredBy", "trainerId"]
  /// V1-04 §10.5.1.
  static let pendingWritesBound: TimeInterval = 30

  private let trainerUid: String
  private let access: any FirestoreDocumentAccess

  public convenience init(trainerUid: String) {
    self.init(trainerUid: trainerUid, access: LiveFirestoreDocumentAccess())
  }

  init(trainerUid: String, access: any FirestoreDocumentAccess) {
    self.trainerUid = trainerUid
    self.access = access
  }

  public func createIfAbsent(path: String, fields: JSONValue) async throws -> WriteAck {
    try await mapped {
      try FirestorePayload.validateDocumentPath(path)
      var document = try JSONValueFirestoreMapper.fields(fields)
      for key in Self.createTimestampKeys(path: path) { document[key] = FieldValue.serverTimestamp() }
      return try await write(path) {
        try await self.access.create(path: path, fields: document)
      } committed: { server in
        server.map { self.isMine($0) } ?? false
      }
    }
  }

  public func update(path: String, fields: JSONValue) async throws -> WriteAck {
    try await mapped {
      try FirestorePayload.validateDocumentPath(path)
      guard case let .object(object) = fields, object["createdAt"] == nil else { throw RemoteError.invalidArgument }
      try FirestorePayload.validateUpdateKeys(object.keys)
      var document = try JSONValueFirestoreMapper.fields(fields)
      document["updatedAt"] = FieldValue.serverTimestamp()
      return try await write(path) {
        try await self.access.update(path: path, fields: document)
      } committed: { server in
        guard let server, self.isMine(server) else { return false }
        return FirestorePayload.serverHas(object, in: server)
      }
    }
  }

  public func delete(path: String) async throws -> WriteAck {
    try await mapped {
      try FirestorePayload.validateDocumentPath(path)
      try await access.delete(path: path)
      return WriteAck(serverCommitted: true)
    }
  }

  /// Sends `operation`; on `permission-denied`, reconciles once against the server (V1-04 §10.5.6). `committed`
  /// gets the server's fields, or nil when the document is missing or not readable by this trainer.
  private func write(
    _ path: String, _ operation: () async throws -> Void, committed: ([String: Any]?) -> Bool
  ) async throws -> WriteAck {
    do {
      try await operation()
      return WriteAck(serverCommitted: true)
    } catch {
      guard RemoteErrorMapper.map(error) == .permissionDenied else { throw error }
    }
    let drained = await access.waitForPendingWrites(seconds: Self.pendingWritesBound)
    let server: [String: Any]?
    do {
      let document = try await access.serverDocument(path: path)
      guard drained, !document.hasPendingWrites, !document.isFromCache else { return WriteAck(serverCommitted: false) }
      server = document.fields
    } catch where RemoteErrorMapper.map(error) == .permissionDenied {
      guard drained else { return WriteAck(serverCommitted: false) }  // this device's write may still be queued
      server = nil
    }
    if committed(server) {
      Self.logger.info("write reconciled after permission-denied")
      return WriteAck(serverCommitted: true)
    }
    throw RemoteError.permissionDenied
  }

  private func isMine(_ fields: [String: Any]) -> Bool {
    Self.ownerKeys.contains { (fields[$0] as? String) == trainerUid }
  }

  /// `addenda` are append-only; their create rules allow `createdAt` only (V1-05 §4.2, DF-123).
  static func createTimestampKeys(path: String) -> [String] {
    let segments = path.split(separator: "/")
    let collection = segments.count >= 2 ? segments[segments.count - 2] : ""
    return collection == "addenda" ? ["createdAt"] : ["createdAt", "updatedAt"]
  }

  private func mapped<T>(_ body: () async throws -> T) async throws -> T {
    do {
      return try await body()
    } catch {
      let remote = RemoteErrorMapper.map(error)
      Self.logger.error("firestore write failed: \(remote.code, privacy: .public)")
      throw remote
    }
  }
}

struct LiveFirestoreDocumentAccess: FirestoreDocumentAccess {
  func serverDocument(path: String) async throws -> ServerDocument {
    let snapshot = try await Firestore.firestore().document(path).getDocument(source: .server)
    return ServerDocument(
      fields: snapshot.exists ? snapshot.data() : nil, hasPendingWrites: snapshot.metadata.hasPendingWrites,
      isFromCache: snapshot.metadata.isFromCache)
  }

  func waitForPendingWrites(seconds: TimeInterval) async -> Bool {
    // The SDK call cannot be cancelled, so the bound races it and the later answer is dropped.
    await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
      let once = OSAllocatedUnfairLock(initialState: false)
      let finish: @Sendable (Bool) -> Void = { drained in
        let first = once.withLock { done -> Bool in
          defer { done = true }
          return !done
        }
        if first { continuation.resume(returning: drained) }
      }
      Firestore.firestore().waitForPendingWrites { error in finish(error == nil) }
      DispatchQueue.global().asyncAfter(deadline: .now() + seconds) { finish(false) }
    }
  }

  func create(path: String, fields: [String: Any]) async throws {
    try await Firestore.firestore().document(path).setData(fields, merge: false)
  }

  func update(path: String, fields: [String: Any]) async throws {
    try await Firestore.firestore().document(path).updateData(fields)
  }

  func delete(path: String) async throws {
    try await Firestore.firestore().document(path).delete()
  }
}

/// Whether a document still has writes the server has not confirmed (PRD §9.6 `synced` check). Ends when the
/// listener fails (for example the document is not readable).
public enum PendingWritesObserver {
  public static func observe(path: String) -> AsyncStream<Bool> {
    AsyncStream { continuation in
      let registration = Firestore.firestore().document(path)
        .addSnapshotListener(includeMetadataChanges: true) { snapshot, error in
          if error != nil {
            continuation.finish()
            return
          }
          guard let snapshot else { return }
          continuation.yield(snapshot.metadata.hasPendingWrites)
        }
      let token = FirestoreListenerRegistry.shared.add(registration)
      continuation.onTermination = { _ in FirestoreListenerRegistry.shared.remove(token) }
    }
  }
}
