import CryptoKit
import Foundation

/// A file `LocalBinaryStore` wrote, with the values `LocalBinary` stores and the upload check compares.
public struct LocalBinaryFile: Equatable, Sendable {
  public let id: UUID
  public let kind: LocalBinaryKind
  /// Relative to the partition directory, e.g. `Binaries/ink/<id>.png`.
  public let relativePath: String
  public let contentType: String
  public let byteSize: Int64
  /// Lowercase hex SHA-256 (Storage `customMetadata.sha256`, ASM-05-22).
  public let sha256: String
  /// Base64 MD5, compared with Storage `md5Hash`.
  public let md5Base64: String
}

/// Writes and removes local binaries (ink, posture photos, report photos, signatures) inside the trainer partition
/// (V1-04 §9.2). Every file is written with `NSFileProtectionComplete` and excluded from backup (NFR-17).
/// Binaries are never stored inside documents or UserDefaults (PRD §9.5).
public struct LocalBinaryStore: Sendable {
  /// `Data.write` options for every binary (NFR-17).
  static let writeOptions: Data.WritingOptions = [.completeFileProtection, .atomic]

  public let location: LocalStoreLocation
  let protection: LocalFileProtection

  public init(location: LocalStoreLocation) {
    self.init(location: location, protection: .system)
  }

  init(location: LocalStoreLocation, protection: LocalFileProtection) {
    self.location = location
    self.protection = protection
  }

  /// Writes `data` to `Binaries/<kind folder>/<id>.<ext>`.
  ///
  /// The write is atomic with complete file protection, and the file is excluded from backup right after.
  /// - Parameter ext: lowercase `[a-z0-9]{1,10}` without the dot (`png`, `jpg`, `drawing`).
  @discardableResult
  public func write(data: Data, ext: String, kind: LocalBinaryKind, id: UUID = UUID()) throws -> LocalBinaryFile {
    guard Self.isValidExtension(ext) else { throw LocalStoreError.invalidFileExtension(ext) }
    try location.prepareDirectories(protection: protection)
    let folder = location.binariesURL.appendingPathComponent(kind.folderName, isDirectory: true)
    try protection.prepareDirectory(folder)

    let relativePath = [LocalStoreLocation.binariesDirectoryName, kind.folderName, "\(id.uuidString).\(ext)"]
      .joined(separator: "/")
    let fileURL = location.partitionURL.appendingPathComponent(relativePath, isDirectory: false)
    try data.write(to: fileURL, options: Self.writeOptions)
    var backupValues = URLResourceValues()
    backupValues.isExcludedFromBackup = true
    var target = fileURL
    try target.setResourceValues(backupValues)
    // Re-applied explicitly so the class never depends on the write option alone.
    try protection.setProtection(fileURL, LocalFileProtection.protectionClass)

    return LocalBinaryFile(
      id: id,
      kind: kind,
      relativePath: relativePath,
      contentType: Self.contentType(forExtension: ext),
      byteSize: Int64(data.count),
      sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
      md5Base64: Data(Insecure.MD5.hash(data: data)).base64EncodedString()
    )
  }

  /// Absolute URL of a partition-relative path. Rejects absolute paths and `..` segments.
  public func url(forRelativePath relativePath: String) throws -> URL {
    let segments = relativePath.split(separator: "/", omittingEmptySubsequences: false)
    guard !relativePath.isEmpty, !relativePath.hasPrefix("/"),
          !segments.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
      throw LocalStoreError.invalidRelativePath(relativePath)
    }
    return location.partitionURL.appendingPathComponent(relativePath, isDirectory: false)
  }

  /// Reads a file. Fails while the device is locked (complete protection, ASM-P0-29).
  public func read(relativePath: String) throws -> Data {
    try Data(contentsOf: url(forRelativePath: relativePath))
  }

  public func fileExists(relativePath: String) -> Bool {
    guard let fileURL = try? url(forRelativePath: relativePath) else { return false }
    return FileManager.default.fileExists(atPath: fileURL.path)
  }

  /// Removes the file. Returns false when it was already gone.
  @discardableResult
  public func delete(relativePath: String) throws -> Bool {
    let fileURL = try url(forRelativePath: relativePath)
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return false }
    try FileManager.default.removeItem(at: fileURL)
    return true
  }

  /// Partition-relative paths of the regular files under `Binaries/` last modified before `cutoff`, sorted.
  /// Used by the retention orphan sweep. Returns an empty list when the directory does not exist yet.
  func storedRelativePaths(modifiedBefore cutoff: Date) -> [String] {
    guard let enumerator = FileManager.default.enumerator(atPath: location.binariesURL.path) else { return [] }
    var paths: [String] = []
    while let subpath = enumerator.nextObject() as? String {
      let attributes = enumerator.fileAttributes ?? [:]
      guard attributes[.type] as? FileAttributeType == .typeRegular,
            let modified = attributes[.modificationDate] as? Date, modified < cutoff else { continue }
      paths.append(LocalStoreLocation.binariesDirectoryName + "/" + subpath)
    }
    return paths.sorted()
  }

  static func isValidExtension(_ ext: String) -> Bool {
    (1...10).contains(ext.count) && ext.unicodeScalars.allSatisfy { ("a"..."z").contains($0) || ("0"..."9").contains($0) }
  }

  static func contentType(forExtension ext: String) -> String {
    switch ext {
    case "png": return "image/png"
    case "jpg", "jpeg": return "image/jpeg"
    case "heic": return "image/heic"
    default: return "application/octet-stream"
    }
  }
}
