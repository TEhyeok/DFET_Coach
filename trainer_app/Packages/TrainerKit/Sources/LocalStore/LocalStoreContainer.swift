import CryptoKit
import Foundation
import SwiftData

/// Errors raised while locating or opening the LocalStore.
public enum LocalStoreError: Error, Equatable, Sendable {
  /// A disk-backed container was requested without a store URL.
  case missingStoreURL
  /// The system did not return an Application Support directory.
  case applicationSupportUnavailable
  /// A binary file extension outside `[a-z0-9]{1,10}`.
  case invalidFileExtension(String)
  /// A relative path that is absolute, empty or climbs out of the partition.
  case invalidRelativePath(String)
}

/// Where one trainer's LocalStore partition lives (V1-04 §9.2, V1-05 §12.1):
///
/// ```
/// Application Support/TrainerKit/<trainerKey>/
/// ├─ LocalStore.store (+ -wal, -shm)
/// └─ Binaries/<kind folder>/<binary UUID>.<ext>
/// ```
///
/// Binaries are flat per kind, named by their `LocalBinary.id`, not V1-04 §9.2's per-entity folders
/// (`ink/<noteId>/<inkRevision>.png`, …): the `LocalBinary` row is the one index from entity to file, and a flat
/// name needs no entity id at write time. Recorded as a Deviation with a V1-04 §9.2 doc follow-up (DF-014).
///
/// `trainerKey` is the first 16 hex digits of SHA-256(uid) so the uid itself never appears in a path (NFR-10).
/// Logging out deletes the whole partition.
public struct LocalStoreLocation: Equatable, Sendable {
  public static let directoryName = "TrainerKit"
  public static let storeFileName = "LocalStore.store"
  public static let binariesDirectoryName = "Binaries"

  /// `<Application Support>/TrainerKit`.
  public let rootURL: URL
  public let trainerKey: String

  /// - Parameter applicationSupportURL: the Application Support directory, or a temporary directory in tests.
  public init(trainerUid: String, applicationSupportURL: URL) {
    rootURL = applicationSupportURL.appendingPathComponent(Self.directoryName, isDirectory: true)
    trainerKey = Self.trainerKey(for: trainerUid)
  }

  /// The partition under the app's real Application Support directory.
  public static func inApplicationSupport(trainerUid: String) throws -> LocalStoreLocation {
    guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
      throw LocalStoreError.applicationSupportUnavailable
    }
    return LocalStoreLocation(trainerUid: trainerUid, applicationSupportURL: base)
  }

  /// First 16 lowercase hex digits of SHA-256(uid).
  public static func trainerKey(for trainerUid: String) -> String {
    let digest = SHA256.hash(data: Data(trainerUid.utf8))
    return String(digest.map { String(format: "%02x", $0) }.joined().prefix(16))
  }

  /// `<root>/<trainerKey>`.
  public var partitionURL: URL { rootURL.appendingPathComponent(trainerKey, isDirectory: true) }
  /// `<partition>/LocalStore.store`.
  public var storeURL: URL { partitionURL.appendingPathComponent(Self.storeFileName, isDirectory: false) }
  /// `<partition>/Binaries`.
  public var binariesURL: URL { partitionURL.appendingPathComponent(Self.binariesDirectoryName, isDirectory: true) }

  /// Creates the root, partition and `Binaries` directories with `FileProtectionType.complete` and excludes each
  /// of them from backup (NFR-17). Safe to call repeatedly.
  public func prepareDirectories() throws {
    try prepareDirectories(protection: .system)
  }

  func prepareDirectories(protection: LocalFileProtection) throws {
    for directory in [rootURL, partitionURL, binariesURL] {
      try protection.prepareDirectory(directory)
    }
  }
}

/// Builds the SwiftData container for `LocalStoreSchemaV1` (DF-014, ADR-002).
public enum LocalStoreContainer {
  /// The current versioned schema.
  public static var schema: Schema { Schema(versionedSchema: LocalStoreSchemaV1.self) }

  /// - Parameters:
  ///   - url: the store file (`LocalStoreLocation.storeURL`). Ignored when `inMemory` is true.
  ///   - inMemory: an isolated in-memory store for tests and previews.
  ///
  /// A disk store gets its parent directory created with complete protection and backup exclusion, and after
  /// opening, the store files (`.store`, `-wal`, `-shm`) are set to the same attributes (NFR-17). CloudKit sync is
  /// always off: the store is device-local by design (ADR-002).
  public static func make(url: URL? = nil, inMemory: Bool = false) throws -> ModelContainer {
    try make(url: url, inMemory: inMemory, protection: .system)
  }

  /// Opens the trainer's partition store, preparing the partition directories first.
  public static func make(location: LocalStoreLocation) throws -> ModelContainer {
    try make(location: location, protection: .system)
  }

  static func make(location: LocalStoreLocation, protection: LocalFileProtection) throws -> ModelContainer {
    try location.prepareDirectories(protection: protection)
    return try make(url: location.storeURL, inMemory: false, protection: protection)
  }

  static func make(url: URL?, inMemory: Bool, protection: LocalFileProtection) throws -> ModelContainer {
    let schema = schema
    if inMemory {
      let configuration = ModelConfiguration(
        UUID().uuidString, schema: schema, isStoredInMemoryOnly: true, allowsSave: true, groupContainer: .none,
        cloudKitDatabase: .none
      )
      return try ModelContainer(for: schema, migrationPlan: LocalStoreMigrationPlan.self, configurations: [configuration])
    }
    guard let url else { throw LocalStoreError.missingStoreURL }
    try protection.prepareDirectory(url.deletingLastPathComponent())
    let configuration = ModelConfiguration(schema: schema, url: url, allowsSave: true, cloudKitDatabase: .none)
    let container = try ModelContainer(
      for: schema, migrationPlan: LocalStoreMigrationPlan.self, configurations: [configuration]
    )
    try protectStoreFiles(at: url, protection: protection)
    return container
  }

  /// Re-applies complete protection and backup exclusion to the partition's store files that exist now.
  ///
  /// SwiftData cannot pass `NSPersistentStoreFileProtectionKey`, and SQLite may delete and recreate `-wal`/`-shm`
  /// during a session with Core Data's default class (`completeUntilFirstUserAuthentication`). Whether a recreated
  /// sidecar inherits the directory's `.complete` class is unverified (needs-device-test, ASM-P0-29), so
  /// `LocalRetention.purge(now:)` calls this on every foreground entry. Backup exclusion is also inherited from the
  /// excluded partition directory.
  @discardableResult
  public static func protectStoreFiles(location: LocalStoreLocation) throws -> [URL] {
    try protectStoreFiles(at: location.storeURL, protection: .system)
  }

  /// Applies complete protection and backup exclusion to the SQLite store and its sidecar files that exist.
  /// Returns the files it protected.
  @discardableResult
  static func protectStoreFiles(at storeURL: URL, protection: LocalFileProtection) throws -> [URL] {
    let directory = storeURL.deletingLastPathComponent()
    let name = storeURL.lastPathComponent
    var protected: [URL] = []
    for fileName in [name, name + "-wal", name + "-shm"] {
      let fileURL = directory.appendingPathComponent(fileName, isDirectory: false)
      if FileManager.default.fileExists(atPath: fileURL.path) {
        try protection.protectFile(fileURL)
        protected.append(fileURL)
      }
    }
    return protected
  }
}

/// NSFileProtectionComplete + backup exclusion for every LocalStore directory and file (NFR-17, V1-04 §9.2).
/// While the device is locked these files cannot be read; the SyncEngine then waits with
/// `protectedDataUnavailable` (DF-015, ASM-P0-29).
///
/// Setting the class goes through `setProtection` so tests can record what was requested: the iOS Simulator
/// neither enforces nor reports protection classes (`attributesOfItem` has no `.protectionKey` there), so the
/// simulator test checks the requested class and a device run checks the reported one (TC-DF014-03).
struct LocalFileProtection: Sendable {
  /// The only class LocalStore uses (NFR-17).
  static let protectionClass: FileProtectionType = .complete

  /// Sets `type` on an existing file or directory.
  var setProtection: @Sendable (URL, FileProtectionType) throws -> Void

  /// FileManager. macOS has no data protection classes, so this is a no-op outside iOS.
  static let system = LocalFileProtection { url, type in
    #if os(iOS)
    try FileManager.default.setAttributes([.protectionKey: type], ofItemAtPath: url.path)
    #endif
  }

  func prepareDirectory(_ url: URL) throws {
    try FileManager.default.createDirectory(
      at: url, withIntermediateDirectories: true, attributes: [.protectionKey: Self.protectionClass]
    )
    // Explicit even when the directory already existed.
    try setProtection(url, Self.protectionClass)
    try Self.excludeFromBackup(url)
  }

  func protectFile(_ url: URL) throws {
    try setProtection(url, Self.protectionClass)
    try Self.excludeFromBackup(url)
  }

  static func excludeFromBackup(_ url: URL) throws {
    var target = url
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try target.setResourceValues(values)
  }

  /// The class the file system reports, or nil where it reports none (macOS, the iOS Simulator).
  static func reportedProtection(of url: URL) throws -> FileProtectionType? {
    try FileManager.default.attributesOfItem(atPath: url.path)[.protectionKey] as? FileProtectionType
  }
}
