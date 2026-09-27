import FirebaseFirestore
import Foundation
import os
import TrainerDomain

/// The Firestore calls behind `FirestoreRemoteWriter`, separated so tests can run without Firebase.
protocol FirestoreDocumentAccess: Sendable {
  /// The document as the server has it now (`source: .server`); nil when it does not exist.
  func serverFields(path: String) async throws -> [String: Any]?
  /// `setData(fields, merge: false)`; returns when the server committed the write.
  func create(path: String, fields: [String: Any]) async throws
  /// `updateData(fields)`; returns when the server committed the write.
  func update(path: String, fields: [String: Any]) async throws
  func delete(path: String) async throws
}

/// Firestore implementation of `RemoteWriter` (DF-104).
///
/// - `createIfAbsent` writes `createdAt` and `updatedAt` as server time. If a server read shows the document already
///   exists and this trainer wrote it (`authorUid`, `enteredBy` or `trainerId`), it succeeds without writing again
///   (AC-DF-015.5, AC-DF-104.3); a document of someone else is `.alreadyExists`.
/// - `update` refuses a payload that touches `createdAt` (`.invalidArgument`, NFR-07) and always sets `updatedAt` to
///   server time.
/// - `WriteAck.serverCommitted` is true only when the Firestore write completed without error (AC-DF-104.5): the
///   SDK calls back after the server commit, and a write that does not complete within the timeout is
///   `.deadlineExceeded` (the SyncEngine only sends while online).
public final class FirestoreRemoteWriter: RemoteWriter, Sendable {
  private static let logger = Logger(subsystem: "kr.co.dfet.trainer", category: "remote")
  static let ownerKeys = ["authorUid", "enteredBy", "trainerId"]

  private let trainerUid: String
  private let access: any FirestoreDocumentAccess
  private let timeout: TimeInterval

  public convenience init(trainerUid: String) {
    self.init(trainerUid: trainerUid, access: LiveFirestoreDocumentAccess(), timeout: 60)
  }

  init(trainerUid: String, access: any FirestoreDocumentAccess, timeout: TimeInterval) {
    self.trainerUid = trainerUid
    self.access = access
    self.timeout = timeout
  }

  public func createIfAbsent(path: String, fields: JSONValue) async throws -> WriteAck {
    try await mapped {
      if let existing = try await access.serverFields(path: path) {
        let mine = Self.ownerKeys.contains { (existing[$0] as? String) == trainerUid }
        guard mine else { throw RemoteError.alreadyExists }
        return WriteAck(serverCommitted: true)  // an earlier attempt committed; nothing to write
      }
      var document = try JSONValueFirestoreMapper.fields(fields)
      document["createdAt"] = FieldValue.serverTimestamp()
      document["updatedAt"] = FieldValue.serverTimestamp()
      try await withTimeout { try await self.access.create(path: path, fields: document) }
      return WriteAck(serverCommitted: true)
    }
  }

  public func update(path: String, fields: JSONValue) async throws -> WriteAck {
    try await mapped {
      guard case let .object(object) = fields, object["createdAt"] == nil else { throw RemoteError.invalidArgument }
      var document = try JSONValueFirestoreMapper.fields(fields)
      document["updatedAt"] = FieldValue.serverTimestamp()
      try await withTimeout { try await self.access.update(path: path, fields: document) }
      return WriteAck(serverCommitted: true)
    }
  }

  public func delete(path: String) async throws -> WriteAck {
    try await mapped {
      try await withTimeout { try await self.access.delete(path: path) }
      return WriteAck(serverCommitted: true)
    }
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

  private func withTimeout(_ operation: @escaping @Sendable () async throws -> Void) async throws {
    let seconds = timeout
    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask { try await operation() }
      group.addTask {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        throw RemoteError.deadlineExceeded
      }
      try await group.next()
      group.cancelAll()
    }
  }
}

struct LiveFirestoreDocumentAccess: FirestoreDocumentAccess {
  func serverFields(path: String) async throws -> [String: Any]? {
    let snapshot = try await Firestore.firestore().document(path).getDocument(source: .server)
    return snapshot.exists ? snapshot.data() : nil
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

/// Whether a document still has writes the server has not confirmed (PRD §9.6 `synced` check).
public enum PendingWritesObserver {
  public static func observe(path: String) -> AsyncStream<Bool> {
    AsyncStream { continuation in
      let registration = Firestore.firestore().document(path)
        .addSnapshotListener(includeMetadataChanges: true) { snapshot, _ in
          guard let snapshot else { return }
          continuation.yield(snapshot.metadata.hasPendingWrites)
        }
      continuation.onTermination = { _ in registration.remove() }
    }
  }
}
