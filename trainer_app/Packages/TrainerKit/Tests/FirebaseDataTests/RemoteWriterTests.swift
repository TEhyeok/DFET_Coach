import FirebaseFirestore
import FirebaseFunctions
import FirebaseStorage
import Foundation
import TrainerDomain
import XCTest
@testable import FirebaseData

/// DF-104: the Firebase side of the SyncEngine without a network (TC-104-01..05, 07, 09). Synthetic data only.
final class RemoteWriterTests: XCTestCase {
  // MARK: TC-104-01 settings

  func testFirestoreSettingsUsePersistentCacheOf100MB() {
    let settings = FirestoreConfigurator.settings(emulatorHost: nil)
    XCTAssertTrue(settings.cacheSettings is PersistentCacheSettings)
    XCTAssertEqual(FirestoreConfigurator.cacheSizeBytes, 104_857_600)
    XCTAssertTrue(settings.isSSLEnabled)
    let emulator = FirestoreConfigurator.settings(emulatorHost: "127.0.0.1")
    XCTAssertEqual(emulator.host, "127.0.0.1:18080")
    XCTAssertFalse(emulator.isSSLEnabled)
  }

  // MARK: TC-104-02 / 03 create and update

  func testCreateWritesServerTimesAndUpdateRefusesCreatedAt() async throws {
    let access = FakeDocumentAccess()
    let writer = FirestoreRemoteWriter(trainerUid: "t1", access: access, timeout: 5)
    let ack = try await writer.createIfAbsent(path: "soap_notes/n1", fields: .object(["trainerId": .string("t1")]))
    XCTAssertTrue(ack.serverCommitted)
    let created = try XCTUnwrap(access.created["soap_notes/n1"])
    XCTAssertTrue(created["createdAt"] is FieldValue)
    XCTAssertTrue(created["updatedAt"] is FieldValue)

    for _ in 0..<3 {
      _ = try await writer.update(path: "soap_notes/n1", fields: .object(["quickNote": .string("합성 메모")]))
    }
    XCTAssertEqual(access.updates.count, 3)
    XCTAssertTrue(access.updates.allSatisfy { $0["createdAt"] == nil && $0["updatedAt"] is FieldValue })
    do {
      _ = try await writer.update(path: "soap_notes/n1", fields: .object(["createdAt": .serverTimestamp]))
      XCTFail("createdAt in an update must be refused")
    } catch {
      XCTAssertEqual(error as? RemoteError, .invalidArgument)
    }
  }

  func testCreateIfAbsentDoesNotWriteAgainForTheSameTrainer() async throws {
    let access = FakeDocumentAccess(existing: ["soap_notes/n1": ["authorUid": "t1"]])
    let writer = FirestoreRemoteWriter(trainerUid: "t1", access: access, timeout: 5)
    let ack = try await writer.createIfAbsent(path: "soap_notes/n1", fields: .object(["trainerId": .string("t1")]))
    XCTAssertTrue(ack.serverCommitted)
    XCTAssertTrue(access.created.isEmpty, "no second write")
  }

  func testCreateIfAbsentRefusesSomeoneElsesDocument() async {
    let access = FakeDocumentAccess(existing: ["bodyCompositionRecords/r1": ["enteredBy": "t2"]])
    let writer = FirestoreRemoteWriter(trainerUid: "t1", access: access, timeout: 5)
    do {
      _ = try await writer.createIfAbsent(path: "bodyCompositionRecords/r1", fields: .object([:]))
      XCTFail("expected alreadyExists")
    } catch {
      XCTAssertEqual(error as? RemoteError, .alreadyExists)
    }
    XCTAssertTrue(access.created.isEmpty)
  }

  func testAWriteThatNeverCompletesTimesOut() async {
    let access = FakeDocumentAccess(hangWrites: true)
    let writer = FirestoreRemoteWriter(trainerUid: "t1", access: access, timeout: 0.2)
    do {
      _ = try await writer.update(path: "soap_notes/n1", fields: .object(["quickNote": .string("x")]))
      XCTFail("expected deadlineExceeded")
    } catch {
      XCTAssertEqual(error as? RemoteError, .deadlineExceeded)
    }
  }

  // MARK: mapping

  func testJSONValueMapsToFirestoreValuesAndBack() throws {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let fields = try JSONValueFirestoreMapper.fields(.object([
      "n": .number(1.5), "i": .int(7), "b": .bool(true), "s": .string("x"), "t": .timestamp(date),
      "st": .serverTimestamp, "null": .null, "list": .array([.int(1)]), "bytes": .bytes(Data([1, 2])),
    ]))
    XCTAssertEqual((fields["t"] as? Timestamp)?.dateValue(), date)
    XCTAssertTrue(fields["st"] is FieldValue)
    XCTAssertTrue(fields["null"] is NSNull)
    XCTAssertEqual(JSONValueFirestoreMapper.json(NSNumber(value: Int64(7))), .int(7))
    XCTAssertEqual(JSONValueFirestoreMapper.json(NSNumber(value: 1.5)), .number(1.5))
    XCTAssertEqual(JSONValueFirestoreMapper.json(NSNumber(value: true)), .bool(true))
    XCTAssertEqual(JSONValueFirestoreMapper.json(Timestamp(date: date)), .timestamp(date))
    XCTAssertThrowsError(try JSONValueFirestoreMapper.fields(.string("not an object")))
  }

  // MARK: TC-104-05 error table

  func testErrorCodesMapToRemoteErrors() {
    func firestore(_ code: FirestoreErrorCode.Code) -> NSError { NSError(domain: FirestoreErrorDomain, code: code.rawValue) }
    XCTAssertEqual(RemoteErrorMapper.map(firestore(.permissionDenied)), .permissionDenied)
    XCTAssertEqual(RemoteErrorMapper.map(firestore(.unavailable)), .unavailable)
    XCTAssertEqual(RemoteErrorMapper.map(firestore(.deadlineExceeded)), .deadlineExceeded)
    XCTAssertEqual(RemoteErrorMapper.map(firestore(.alreadyExists)), .alreadyExists)
    XCTAssertEqual(RemoteErrorMapper.map(firestore(.failedPrecondition)), .failedPrecondition)
    XCTAssertEqual(RemoteErrorMapper.map(firestore(.invalidArgument)), .invalidArgument)
    XCTAssertEqual(RemoteErrorMapper.map(firestore(.notFound)), .notFound)
    XCTAssertEqual(RemoteErrorMapper.map(firestore(.internal)), .unknown("firestore:\(FirestoreErrorCode.Code.internal.rawValue)"))
    XCTAssertEqual(RemoteErrorMapper.map(NSError(domain: StorageErrorDomain, code: StorageErrorCode.unauthorized.rawValue)), .permissionDenied)
    XCTAssertEqual(RemoteErrorMapper.map(NSError(domain: StorageErrorDomain, code: StorageErrorCode.retryLimitExceeded.rawValue)), .unavailable)
    XCTAssertEqual(RemoteErrorMapper.map(NSError(domain: StorageErrorDomain, code: StorageErrorCode.objectNotFound.rawValue)), .notFound)
    XCTAssertEqual(RemoteErrorMapper.map(NSError(domain: FunctionsErrorDomain, code: FunctionsErrorCode.permissionDenied.rawValue)), .permissionDenied)
    XCTAssertEqual(RemoteErrorMapper.map(NSError(domain: FunctionsErrorDomain, code: FunctionsErrorCode.unavailable.rawValue)), .unavailable)
    XCTAssertEqual(RemoteErrorMapper.map(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)), .unavailable)
    XCTAssertEqual(RemoteErrorMapper.map(NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError)), .protectedDataUnavailable)
  }

  // MARK: TC-104-04 upload integrity

  func testUploadIsVerifiedOnlyWhenSizeAndMD5Match() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("df104-\(UUID().uuidString).bin")
    try Data("synthetic ink".utf8).write(to: file)
    defer { try? FileManager.default.removeItem(at: file) }
    let md5 = try UploadIntegrity.md5Base64(of: file)

    let good = FakeStorageAccess(size: 13, md5: md5)
    let receipt = try await StorageBinaryUploader(access: good)
      .upload(localURL: file, path: "soapInk/n1/1.drawing", contentType: "application/octet-stream", sha256: "fx-sha")
    XCTAssertTrue(receipt.verified)
    XCTAssertEqual(good.lastMetadata, ["sha256": "fx-sha"])

    let wrongHash = try await StorageBinaryUploader(access: FakeStorageAccess(size: 13, md5: "AAAA"))
      .upload(localURL: file, path: "soapInk/n1/1.drawing", contentType: "application/octet-stream", sha256: "fx-sha")
    XCTAssertFalse(wrongHash.verified)
    let wrongSize = try await StorageBinaryUploader(access: FakeStorageAccess(size: 12, md5: md5))
      .upload(localURL: file, path: "soapInk/n1/1.drawing", contentType: "application/octet-stream", sha256: "fx-sha")
    XCTAssertFalse(wrongSize.verified)
  }

  func testDeletingAMissingBinaryIsASuccess() async throws {
    try await StorageBinaryUploader(access: FakeStorageAccess(size: 0, md5: nil, deleteNotFound: true)).delete(path: "soapInk/n1/0.drawing")
  }

  // MARK: TC-104-07 / 09

  func testCallablesUseTheSeoulRegion() {
    XCTAssertEqual(FunctionsCallableClient.region, "asia-northeast3")
  }

  func testCallablePayloadIsPlainJSON() throws {
    let date = Date(timeIntervalSince1970: 0)
    let plain = try FunctionsCallableClient.plain(.object(["at": .timestamp(date), "n": .int(2), "b": .bytes(Data([255]))])) as? [String: Any]
    XCTAssertEqual(plain?["at"] as? String, "1970-01-01T00:00:00Z")
    XCTAssertEqual(plain?["b"] as? String, "/w==")
    XCTAssertThrowsError(try FunctionsCallableClient.plain(.object(["t": .serverTimestamp])))
  }

  func testStorageUsesTheSeoulBucketUnlessTheEmulatorIsConfigured() {
    XCTAssertEqual(StorageBucket.seoul, "dfetmanage-seoul")
    XCTAssertEqual(StorageFactory.bucketURL(emulator: false), "gs://dfetmanage-seoul")
    XCTAssertNil(StorageFactory.bucketURL(emulator: true))
  }
}

/// Scripted Firestore document access.
final class FakeDocumentAccess: FirestoreDocumentAccess, @unchecked Sendable {
  private let lock = NSLock()
  private var existing: [String: [String: Any]]
  private let hangWrites: Bool
  private var _created: [String: [String: Any]] = [:]
  private var _updates: [[String: Any]] = []

  init(existing: [String: [String: Any]] = [:], hangWrites: Bool = false) {
    self.existing = existing
    self.hangWrites = hangWrites
  }

  var created: [String: [String: Any]] { lock.withLock { _created } }
  var updates: [[String: Any]] { lock.withLock { _updates } }

  func serverFields(path: String) async throws -> [String: Any]? { lock.withLock { existing[path] } }

  func create(path: String, fields: [String: Any]) async throws {
    if hangWrites { try await Task.sleep(nanoseconds: 60_000_000_000) }
    lock.withLock { _created[path] = fields }
  }

  func update(path: String, fields: [String: Any]) async throws {
    if hangWrites { try await Task.sleep(nanoseconds: 60_000_000_000) }
    lock.withLock { _updates.append(fields) }
  }

  func delete(path: String) async throws {}
}

/// Scripted Storage access.
final class FakeStorageAccess: StorageFileAccess, @unchecked Sendable {
  private let lock = NSLock()
  private let size: Int64
  private let md5: String?
  private let deleteNotFound: Bool
  private var _metadata: [String: String]?

  init(size: Int64, md5: String?, deleteNotFound: Bool = false) {
    self.size = size
    self.md5 = md5
    self.deleteNotFound = deleteNotFound
  }

  var lastMetadata: [String: String]? { lock.withLock { _metadata } }

  func put(localURL: URL, path: String, contentType: String, customMetadata: [String: String]) async throws
    -> (size: Int64, md5Hash: String?)
  {
    lock.withLock { _metadata = customMetadata }
    return (size, md5)
  }

  func delete(path: String) async throws {
    if deleteNotFound { throw NSError(domain: StorageErrorDomain, code: StorageErrorCode.objectNotFound.rawValue) }
  }

  func write(path: String, to localURL: URL) async throws {}
}
