import Foundation

// Remote I/O boundary of the SyncEngine (DF-015, V1-04 §10). FirebaseData implements these protocols (DF-104);
// SyncEngine tests use fakes. Nothing here imports Firebase.

/// Result of a document write. `serverCommitted` is true when the server confirmed the commit (Firestore write
/// completion), not merely the local cache write.
public struct WriteAck: Equatable, Sendable {
  public let serverCommitted: Bool

  public init(serverCommitted: Bool) {
    self.serverCommitted = serverCommitted
  }
}

/// Result of a Storage upload. `verified` is true when the uploaded size and SHA-256 match the local file.
public struct UploadReceipt: Equatable, Sendable {
  public let path: String
  public let size: Int
  public let sha256: String
  public let verified: Bool

  public init(path: String, size: Int, sha256: String, verified: Bool) {
    self.path = path
    self.size = size
    self.sha256 = sha256
    self.verified = verified
  }
}

public protocol RemoteWriter: Sendable {
  /// Creates the document. If it already exists because an earlier attempt committed before the app lost the reply,
  /// succeeds without writing again (AC-DF-015.5, NFR-04). `serverCommitted: false` means "not known yet, retry".
  func createIfAbsent(path: String, fields: JSONValue) async throws -> WriteAck
  /// Updates only the given fields (`updateData`; never a full `set` or `merge`, V1-04 §10.2 rule 1).
  func update(path: String, fields: JSONValue) async throws -> WriteAck
  /// Deletes the document; a missing document is a success (DF-104, P1a drafts). Enqueue a draft's `deleteBinary`
  /// items before its `deleteDocument`: the Storage rules allow deleting a file only while its parent is a draft.
  func delete(path: String) async throws -> WriteAck
}

public protocol BinaryUploader: Sendable {
  func upload(localURL: URL, path: String, contentType: String, sha256: String) async throws -> UploadReceipt
  /// Deletes the stored file; a missing file is a success (DF-104, replaced ink revisions).
  func delete(path: String) async throws
}

/// Downloads a stored file to a local path (DF-104). Never through a download URL (PRD §9.5 link policy).
public protocol BinaryDownloader: Sendable {
  /// Writes the file to `localURL` and returns it.
  func download(path: String, to localURL: URL) async throws -> URL
}

public protocol CallableClient: Sendable {
  func call<T: Decodable & Sendable>(_ name: String, _ payload: JSONValue) async throws -> T
}

/// Remote failures, already mapped from SDK error codes. The SyncEngine decides retry by case (V1-04 §10.4).
public enum RemoteError: Error, Equatable, Sendable {
  case permissionDenied
  case failedPrecondition
  case invalidArgument
  case notFound
  case alreadyExists
  case unavailable
  case deadlineExceeded
  /// The device is locked and `NSFileProtectionComplete` files cannot be read (ASM-P0-29).
  case protectedDataUnavailable
  case unknown(String)

  /// Stable code stored in `OutboxItem.lastErrorCode` and shown to support. Never contains paths or uids.
  public var code: String {
    switch self {
    case .permissionDenied: return "permission-denied"
    case .failedPrecondition: return "failed-precondition"
    case .invalidArgument: return "invalid-argument"
    case .notFound: return "not-found"
    case .alreadyExists: return "already-exists"
    case .unavailable: return "unavailable"
    case .deadlineExceeded: return "deadline-exceeded"
    case .protectedDataUnavailable: return "protected-data-unavailable"
    case .unknown: return "unknown"
    }
  }
}
