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
  /// Base64 of the raw MD5 digest, as Storage reports `md5Hash`. Read in 1 MiB chunks so large scans (P2) are
  /// never held in memory whole.
  static func md5Base64(of url: URL) throws -> String {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var md5 = Insecure.MD5()
    while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
      md5.update(data: chunk)
    }
    return Data(md5.finalize()).base64EncodedString()
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
      let size = (try FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? NSNumber)?.int64Value ?? 0
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
/// rules: complete protection and no backup (DF-014 `LocalBinaryStore`). It lands in a staging directory created with
/// complete protection and is then moved into place. (The SDK itself writes to its own temporary file first, which this
/// code does not control.) Staging directories left by a download that never finished are removed after an hour.
public final class StorageBinaryDownloader: BinaryDownloader, Sendable {
  private let access: any StorageFileAccess

  public convenience init() {
    self.init(access: LiveStorageFileAccess())
  }

  init(access: any StorageFileAccess) {
    self.access = access
  }

  public func download(path: String, to localURL: URL) async throws -> URL {
    let files = FileManager.default
    let folder = localURL.deletingLastPathComponent()
    Self.removeStaleStaging(in: folder)
    let staging = folder.appendingPathComponent(".download-\(UUID().uuidString)", isDirectory: true)
    defer { try? files.removeItem(at: staging) }
    do {
      try files.createDirectory(
        at: staging, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
      let staged = staging.appendingPathComponent(localURL.lastPathComponent)
      try await access.write(path: path, to: staged)
      try Self.protect(staged)
      if files.fileExists(atPath: localURL.path) {
        _ = try files.replaceItemAt(localURL, withItemAt: staged, options: .usingNewMetadataOnly)
      } else {
        try files.moveItem(at: staged, to: localURL)
      }
      try Self.protect(localURL)  // a replaced item may keep the old item's metadata
      return localURL
    } catch {
      throw RemoteErrorMapper.map(error)
    }
  }
}

extension StorageBinaryDownloader {
  /// `.download-*` directories older than `age` (a download killed with the app).
  static func removeStaleStaging(in folder: URL, olderThan age: TimeInterval = 3_600, now: Date = Date()) {
    let files = FileManager.default
    let entries = (try? files.contentsOfDirectory(
      at: folder, includingPropertiesForKeys: [.contentModificationDateKey], options: [])) ?? []
    for entry in entries where entry.lastPathComponent.hasPrefix(".download-") {
      let modified = (try? entry.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
      if let modified, now.timeIntervalSince(modified) > age { try? files.removeItem(at: entry) }
    }
  }

  static func protect(_ url: URL) throws {
    try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    var url = url
    try url.setResourceValues(values)
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
