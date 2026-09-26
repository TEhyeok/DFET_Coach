import Foundation
import SwiftData
import XCTest
@testable import LocalStore

/// TC-DF014-03 (AC-DF-014.3, NFR-17): files and directories get `FileProtectionType.complete` and are excluded from
/// backup. Runs on the iPad simulator. Protection classes exist only on iOS, so those checks are `#if os(iOS)`; the
/// simulator does not report them, so there the requested class is checked instead (`ProtectionRecorder`).
@MainActor
final class LocalFileProtectionTests: XCTestCase {
  private var temp: TemporaryDirectory?
  private let recorder = ProtectionRecorder()

  override func tearDown() {
    temp?.remove()
    temp = nil
    super.tearDown()
  }

  private func makeLocation() throws -> LocalStoreLocation {
    let temp = try TemporaryDirectory()
    self.temp = temp
    // `temp.url` stands in for Application Support; the store directory is `<it>/TrainerKit/`.
    return LocalStoreLocation(trainerUid: Synthetic.trainerA, applicationSupportURL: temp.url)
  }

  func test_TC_DF014_03_AC_DF_014_3_writtenBinaryIsCompleteProtectedAndExcludedFromBackup() throws {
    let location = try makeLocation()
    let store = LocalBinaryStore(location: location, protection: recorder.protection)
    let data = Data("synthetic-signature".utf8)

    let file = try store.write(data: data, ext: "png", kind: .signature)

    let fileURL = try store.url(forRelativePath: file.relativePath)
    XCTAssertEqual(file.relativePath, "Binaries/signatures/\(file.id.uuidString).png")
    XCTAssertEqual(try store.read(relativePath: file.relativePath), data)
    try assertCompleteProtection(fileURL)
    try assertExcludedFromBackup(fileURL)

    // The store directory `Application Support/TrainerKit/` and the partition below it are excluded too.
    XCTAssertEqual(location.rootURL.lastPathComponent, "TrainerKit")
    for directory in [location.rootURL, location.partitionURL, location.binariesURL,
                      location.binariesURL.appendingPathComponent("signatures")] {
      try assertExcludedFromBackup(directory)
      try assertCompleteProtection(directory)
    }
  }

  func test_TC_DF014_03_AC_DF_014_3_writeRecordsSizeAndHashes() throws {
    let store = LocalBinaryStore(location: try makeLocation())
    let file = try store.write(data: Data("abc".utf8), ext: "jpg", kind: .bodycompReport)
    XCTAssertEqual(file.kind, .bodycompReport)
    XCTAssertTrue(file.relativePath.hasPrefix("Binaries/bodycomp/"))
    XCTAssertEqual(file.contentType, "image/jpeg")
    XCTAssertEqual(file.byteSize, 3)
    XCTAssertEqual(file.sha256, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    XCTAssertEqual(file.md5Base64, "kAFQmDzST7DWlj99KOF/cg==")

    let binary = LocalBinary(file: file, trainerUid: Synthetic.trainerA)
    XCTAssertEqual(binary.kind, "bodycompReport")
    XCTAssertEqual(binary.relativePath, file.relativePath)
    XCTAssertNil(binary.purgeAfter)
    binary.markVerified(at: Synthetic.now)
    XCTAssertEqual(binary.purgeAfter, Synthetic.now.addingTimeInterval(LocalRetention.window))
  }

  func test_TC_DF014_03_AC_DF_014_3_diskStoreFilesAreCompleteProtectedAndExcludedFromBackup() throws {
    let location = try makeLocation()
    let container = try LocalStoreContainer.make(location: location, protection: recorder.protection)
    let context = ModelContext(container)
    ModelFactory.insertOneOfEach(into: context, trainerUid: Synthetic.trainerA, tag: "A1")
    try context.save()

    // The SQLite sidecars exist while the container is open and get the same attributes as the store.
    let storeFiles = storeFileURLs(location)
    XCTAssertEqual(storeFiles.map(\.lastPathComponent),
                   ["LocalStore.store", "LocalStore.store-wal", "LocalStore.store-shm"])
    for fileURL in storeFiles {
      try assertCompleteProtection(fileURL)
      try assertExcludedFromBackup(fileURL)
    }
    try assertExcludedFromBackup(location.rootURL)
    withExtendedLifetime(container) {}
  }

  func test_TC_DF014_03_AC_DF_014_3_retentionReappliesProtectionToStoreFilesOnEveryRun() throws {
    let location = try makeLocation()
    let container = try LocalStoreContainer.make(location: location, protection: recorder.protection)
    let context = ModelContext(container)
    ModelFactory.insertOneOfEach(into: context, trainerUid: Synthetic.trainerA, tag: "A1")
    try context.save()
    // As if SQLite recreated the sidecars during the session: nothing requested for them since opening.
    recorder.clear()

    let store = LocalBinaryStore(location: location, protection: recorder.protection)
    let report = try LocalRetention(context: context, binaryStore: store, trainerUid: Synthetic.trainerA)
      .purge(now: Synthetic.now)

    XCTAssertFalse(report.storeProtectionFailed)
    let storeFiles = storeFileURLs(location)
    XCTAssertEqual(storeFiles.count, 3)
    for fileURL in storeFiles {
      try assertCompleteProtection(fileURL)
      try assertExcludedFromBackup(fileURL)
    }
  }

  func test_TC_DF014_03_rejectsUnsafeExtensionsAndRelativePaths() throws {
    let store = LocalBinaryStore(location: try makeLocation())
    for ext in ["", "PNG", "p/ng", ".png", "averyverylongext"] {
      XCTAssertThrowsError(try store.write(data: Data([1]), ext: ext, kind: .ink), ext)
    }
    for path in ["", "/etc/passwd", "../x", "Binaries/../../x", "Binaries//x", "./x"] {
      XCTAssertThrowsError(try store.url(forRelativePath: path), path)
    }
    XCTAssertFalse(try store.delete(relativePath: "Binaries/ink/missing.png"))
  }

  func test_TC_DF014_03_AC_DF_014_3_binariesAreWrittenAtomicallyWithCompleteProtection() {
    XCTAssertTrue(LocalBinaryStore.writeOptions.contains(.completeFileProtection))
    XCTAssertTrue(LocalBinaryStore.writeOptions.contains(.atomic))
    XCTAssertEqual(LocalFileProtection.protectionClass, .complete)
  }

  func test_TC_DF014_03_kindFoldersFollowV1_04() {
    XCTAssertEqual(LocalBinaryKind.allCases.map(\.folderName), ["ink", "posture", "bodycomp", "signatures"])
  }

  // MARK: - Assertions

  private func storeFileURLs(_ location: LocalStoreLocation) -> [URL] {
    let directory = location.storeURL.deletingLastPathComponent()
    return ["", "-wal", "-shm"]
      .map { directory.appendingPathComponent(LocalStoreLocation.storeFileName + $0, isDirectory: false) }
      .filter { FileManager.default.fileExists(atPath: $0.path) }
  }

  private func assertCompleteProtection(_ url: URL, file: StaticString = #filePath, line: UInt = #line) throws {
    #if os(iOS)
    let name = url.lastPathComponent
    XCTAssertEqual(recorder.requestedProtection(of: url), .complete, "requested: \(name)", file: file, line: line)
    if let reported = try LocalFileProtection.reportedProtection(of: url) {
      // A device (and any runtime that reports classes): `attributesOfItem[.protectionKey] == .complete`.
      XCTAssertEqual(reported, .complete, "reported: \(name)", file: file, line: line)
    } else {
      #if !targetEnvironment(simulator)
      XCTFail("a device must report a protection class for \(name)", file: file, line: line)
      #endif
    }
    #endif
  }

  private func assertExcludedFromBackup(_ url: URL, file: StaticString = #filePath, line: UInt = #line) throws {
    let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
    XCTAssertEqual(values.isExcludedFromBackup, true, url.lastPathComponent, file: file, line: line)
  }
}
