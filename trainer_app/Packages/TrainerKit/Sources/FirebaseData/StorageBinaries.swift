import CryptoKit
import FirebaseStorage
import Foundation
import os
import TrainerDomain

/// The Storage calls behind the uploader and downloader, separated so tests can run without Firebase.
protocol StorageFileAccess: Sendable {
  /// `putFileAsync(from:metadata:)`; returns the stored size and base64 MD5.
  func put(localURL: URL, path: String, contentType: String, customMetadata: [String: String]) async throws
    -> (size: Int64, md5Hash: String?)
  func delete(path: String) async throws
  /// `write(toFile:)`: the only download path (no download URL, PRD §9.5).
  func write(path: String, to localURL: URL) async throws
}

/// Upload integrity (AC-DF-104.4, ASM-P1a-07): the server's size and MD5 must equal the local file's.
enum UploadIntegrity {
  static func md5Base64(of url: URL) throws -> String {
    let data = try Data(contentsOf: url)
    return Data(Insecure.MD5.hash(data: data)).base64EncodedString()
  }

  static func verified(localSize: Int64, localMD5: String, remoteSize: Int64, remoteMD5: String?) -> Bool {
    localSize == remoteSize && remoteMD5 == localMD5
  }
}

/// Firebase Storage implementation of `BinaryUploader` (DF-104). Records the local SHA-256 in
/// `customMetadata.sha256` and reports `verified` only when size and MD5 match (NFR-05).
public final class StorageBinaryUploader: BinaryUploader, Sendable {
  private static let logger = Logger(subsystem: "kr.co.dfet.trainer", category: "remote")
  private let access: any StorageFileAccess

  public convenience init() {
    self.init(access: LiveStorageFileAccess())
  }

  init(access: any StorageFileAccess) {
    self.access = access
  }

  public func upload(localURL: URL, path: String, contentType: String, sha256: String) async throws -> UploadReceipt {
    do {
      let size = try Int64(FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? NSNumber ?? 0)
      let md5 = try UploadIntegrity.md5Base64(of: localURL)
      let stored = try await access.put(
        localURL: localURL, path: path, contentType: contentType, customMetadata: ["sha256": sha256])
      let verified = UploadIntegrity.verified(localSize: size, localMD5: md5, remoteSize: stored.size, remoteMD5: stored.md5Hash)
      return UploadReceipt(path: path, size: Int(stored.size), sha256: sha256, verified: verified)
    } catch {
      let remote = RemoteErrorMapper.map(error)
      Self.logger.error("upload failed: \(remote.code, privacy: .public)")
      throw remote
    }
  }

  public func delete(path: String) async throws {
    do {
      try await access.delete(path: path)
    } catch {
      let remote = RemoteErrorMapper.map(error)
      if remote == .notFound { return }  // already gone
      throw remote
    }
  }
}

/// Firebase Storage implementation of `BinaryDownloader` (DF-104). The downloaded file gets the LocalStore file
/// rules: complete protection and no backup (DF-014 `LocalBinaryStore`).
public final class StorageBinaryDownloader: BinaryDownloader, Sendable {
  private let access: any StorageFileAccess

  public convenience init() {
    self.init(access: LiveStorageFileAccess())
  }

  init(access: any StorageFileAccess) {
    self.access = access
  }

  public func download(path: String, to localURL: URL) async throws -> URL {
    do {
      try await access.write(path: path, to: localURL)
      try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: localURL.path)
      var url = localURL
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try url.setResourceValues(values)
      return localURL
    } catch {
      throw RemoteErrorMapper.map(error)
    }
  }
}

struct LiveStorageFileAccess: StorageFileAccess {
  func put(localURL: URL, path: String, contentType: String, customMetadata: [String: String]) async throws
    -> (size: Int64, md5Hash: String?)
  {
    let metadata = StorageMetadata()
    metadata.contentType = contentType
    metadata.customMetadata = customMetadata
    let stored = try await StorageFactory.make().reference(withPath: path).putFileAsync(from: localURL, metadata: metadata)
    return (stored.size, stored.md5Hash)
  }

  func delete(path: String) async throws {
    try await StorageFactory.make().reference(withPath: path).delete()
  }

  func write(path: String, to localURL: URL) async throws {
    _ = try await StorageFactory.make().reference(withPath: path).writeAsync(toFile: localURL)
  }
}
