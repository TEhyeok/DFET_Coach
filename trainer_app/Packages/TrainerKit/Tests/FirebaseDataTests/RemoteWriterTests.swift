import CryptoKit
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
    let access = RulesLikeDocumentAccess(trainerUid: "t1")
    let writer = FirestoreRemoteWriter(trainerUid: "t1", access: access)
    let ack = try await writer.createIfAbsent(path: "soap_notes/n1", fields: .object(["trainerId": .string("t1")]))
    XCTAssertTrue(ack.serverCommitted)
    let created = try XCTUnwrap(access.createPayloads["soap_notes/n1"])
    XCTAssertTrue(created["createdAt"] is FieldValue)
    XCTAssertTrue(created["updatedAt"] is FieldValue)

    for _ in 0..<3 {
      _ = try await writer.update(path: "soap_notes/n1", fields: .object(["quickNote": .string("합성 메모")]))
    }
    XCTAssertEqual(access.updatePayloads.count, 3)
    XCTAssertTrue(access.updatePayloads.allSatisfy { $0["createdAt"] == nil && $0["updatedAt"] is FieldValue })
    await assertThrows(.invalidArgument) {
      _ = try await writer.update(path: "soap_notes/n1", fields: .object(["createdAt": .serverTimestamp]))
    }
  }

  /// P8: the addenda create rules allow `createdAt` only.
  func testAnAddendumCreateHasNoUpdatedAt() async throws {
    let access = RulesLikeDocumentAccess(trainerUid: "t1")
    let writer = FirestoreRemoteWriter(trainerUid: "t1", access: access)
    _ = try await writer.createIfAbsent(path: "soap_notes/n1/addenda/a1", fields: .object(["authorUid": .string("t1")]))
    let created = try XCTUnwrap(access.createPayloads["soap_notes/n1/addenda/a1"])
    XCTAssertTrue(created["createdAt"] is FieldValue)
    XCTAssertNil(created["updatedAt"])
  }

  // MARK: reconciliation after permission-denied (V1-04 §10.5)

  /// Finding 1/P1-P3: the rules deny reading a missing document and deny a second create. A create whose reply was
  /// lost is sent again, denied, and reconciled into a commit without a third write.
  func testACreateSentAgainAfterALostReplyIsReconciled() async throws {
    let access = RulesLikeDocumentAccess(trainerUid: "t1")
    access.loseNextReply()
    let writer = FirestoreRemoteWriter(trainerUid: "t1", access: access)
    let fields = JSONValue.object(["trainerId": .string("t1"), "authorUid": .string("t1")])
    await assertThrows(.unavailable) { _ = try await writer.createIfAbsent(path: "soap_notes/n1", fields: fields) }
    let ack = try await writer.createIfAbsent(path: "soap_notes/n1", fields: fields)
    XCTAssertTrue(ack.serverCommitted)
    XCTAssertEqual(access.createAttempts, 2)
    XCTAssertEqual(access.serverReads, 1, "one reconciliation read")
  }

  /// A first create is never preceded by a read (the rules would deny it).
  func testAFirstCreateDoesNotReadFirst() async throws {
    let access = RulesLikeDocumentAccess(trainerUid: "t1")
    _ = try await FirestoreRemoteWriter(trainerUid: "t1", access: access)
      .createIfAbsent(path: "bodyCompositionRecords/r1", fields: .object(["enteredBy": .string("t1")]))
    XCTAssertEqual(access.serverReads, 0)
  }

  /// P2: another trainer's document is not readable, so the denial stands.
  func testACreateOverSomeoneElsesDocumentStaysDenied() async {
    let access = RulesLikeDocumentAccess(trainerUid: "t1", documents: ["bodyCompositionRecords/r1": ["enteredBy": "t2"]])
    let writer = FirestoreRemoteWriter(trainerUid: "t1", access: access)
    await assertThrows(.permissionDenied) {
      _ = try await writer.createIfAbsent(path: "bodyCompositionRecords/r1", fields: .object(["enteredBy": .string("t1")]))
    }
  }

  /// Defence in depth: where a rule lets this trainer read someone else's document, the reconciliation still does not
  /// take that document as its own create.
  func testAReadableDocumentOfSomeoneElseIsNotACommit() async {
    let access = RulesLikeDocumentAccess(trainerUid: "t1", documents: ["pendingMembers/p1": ["trainerId": "t2"]])
    access.readableByAnyone = ["pendingMembers/p1"]
    await assertThrows(.permissionDenied) {
      _ = try await FirestoreRemoteWriter(trainerUid: "t1", access: access)
        .createIfAbsent(path: "pendingMembers/p1", fields: .object(["trainerId": .string("t1")]))
    }
    XCTAssertEqual(access.serverReads, 1)
  }

  /// A create the rules reject for its payload stays denied (the document is not there afterwards).
  func testACreateTheRulesRejectStaysDenied() async {
    let access = RulesLikeDocumentAccess(trainerUid: "t1")
    access.rejectCreates = true
    await assertThrows(.permissionDenied) {
      _ = try await FirestoreRemoteWriter(trainerUid: "t1", access: access)
        .createIfAbsent(path: "soap_notes/n1", fields: .object(["trainerId": .string("t1")]))
    }
  }

  /// Finding 2: the reconciliation read shows this device's unconfirmed write, or the device's writes did not
  /// drain: not committed yet, so the engine retries instead of failing or acknowledging.
  func testUnconfirmedLocalWritesAreNotACommit() async throws {
    let access = RulesLikeDocumentAccess(trainerUid: "t1", documents: ["soap_notes/n1": ["trainerId": "t1"]])
    access.readShowsPendingWrites = true
    let writer = FirestoreRemoteWriter(trainerUid: "t1", access: access)
    let fields = JSONValue.object(["trainerId": .string("t1")])
    let pending = try await writer.createIfAbsent(path: "soap_notes/n1", fields: fields)
    XCTAssertFalse(pending.serverCommitted)

    access.readShowsPendingWrites = false
    access.pendingWritesDrain = false
    let undrained = try await writer.createIfAbsent(path: "soap_notes/n1", fields: fields)
    XCTAssertFalse(undrained.serverCommitted)
    let missing = try await writer.delete(path: "soap_notes/gone")
    XCTAssertFalse(missing.serverCommitted, "an unreadable document is not taken as deleted while writes are queued")
  }

  /// Finding 3/P5: a finalize whose reply was lost is denied when sent again (finalized documents are frozen) and
  /// reconciled: the server already has the payload.
  func testAFinalizeSentAgainIsReconciled() async throws {
    let access = RulesLikeDocumentAccess(trainerUid: "t1", documents: ["soap_notes/n1": ["trainerId": "t1", "status": "draft"]])
    access.loseNextReply()
    let writer = FirestoreRemoteWriter(trainerUid: "t1", access: access)
    let finalize = JSONValue.object(["status": .string("finalized"), "finalizedAt": .serverTimestamp, "revision": .int(2)])
    await assertThrows(.unavailable) { _ = try await writer.update(path: "soap_notes/n1", fields: finalize) }
    let ack = try await writer.update(path: "soap_notes/n1", fields: finalize)
    XCTAssertTrue(ack.serverCommitted)
  }

  /// An update the server does not have stays denied.
  func testADeniedUpdateWithOtherValuesStaysDenied() async {
    let access = RulesLikeDocumentAccess(trainerUid: "t1", documents: ["soap_notes/n1": ["trainerId": "t1", "status": "finalized"]])
    access.frozen = ["soap_notes/n1"]
    await assertThrows(.permissionDenied) {
      _ = try await FirestoreRemoteWriter(trainerUid: "t1", access: access)
        .update(path: "soap_notes/n1", fields: .object(["quickNote": .string("합성")]))
    }
  }

  /// Finding 4/P4: deleting a missing document is denied by the rules and reconciled into a success.
  func testDeletingAMissingDocumentIsASuccess() async throws {
    let access = RulesLikeDocumentAccess(trainerUid: "t1")
    let ack = try await FirestoreRemoteWriter(trainerUid: "t1", access: access).delete(path: "soap_notes/gone")
    XCTAssertTrue(ack.serverCommitted)
  }

  func testDeletingAFrozenDocumentStaysDenied() async {
    let access = RulesLikeDocumentAccess(trainerUid: "t1", documents: ["soap_notes/n1": ["trainerId": "t1", "status": "finalized"]])
    access.frozen = ["soap_notes/n1"]
    await assertThrows(.permissionDenied) {
      _ = try await FirestoreRemoteWriter(trainerUid: "t1", access: access).delete(path: "soap_notes/n1")
    }
  }

  func testOtherErrorsAreNotReconciled() async {
    let access = RulesLikeDocumentAccess(trainerUid: "t1")
    access.nextError = NSError(domain: FirestoreErrorDomain, code: FirestoreErrorCode.Code.unavailable.rawValue)
    await assertThrows(.unavailable) {
      _ = try await FirestoreRemoteWriter(trainerUid: "t1", access: access)
        .createIfAbsent(path: "soap_notes/n1", fields: .object([:]))
    }
    XCTAssertEqual(access.serverReads, 0)
  }

  // MARK: finding 6: nothing malformed reaches the SDK

  func testMalformedPathsAndPayloadsAreRefusedBeforeTheSDK() async {
    let access = RulesLikeDocumentAccess(trainerUid: "t1")
    let writer = FirestoreRemoteWriter(trainerUid: "t1", access: access)
    for path in ["", "soap_notes", "soap_notes/", "/soap_notes/n1", "soap_notes//n1", "a/b/c", "soap_notes/__x__", "soap_notes/.."] {
      await assertThrows(.invalidArgument, path) { _ = try await writer.createIfAbsent(path: path, fields: .object([:])) }
      await assertThrows(.invalidArgument, path) { _ = try await writer.delete(path: path) }
    }
    let badPayloads: [JSONValue] = [
      .object(["list": .array([.array([.int(1)])])]),
      .object(["list": .array([.serverTimestamp])]),
      .object(["": .int(1)]),
      .object(["__name__": .int(1)]),
      .object(["nested": .object(["": .int(1)])]),
      .object(["at": .timestamp(Date(timeIntervalSince1970: 300_000_000_000))]),
    ]
    for payload in badPayloads {
      await assertThrows(.invalidArgument, "\(payload)") {
        _ = try await writer.createIfAbsent(path: "soap_notes/n1", fields: payload)
      }
    }
    for key in ["a..b", "a[0]", "a*", "a/b", ".a"] {
      await assertThrows(.invalidArgument, key) {
        _ = try await writer.update(path: "soap_notes/n1", fields: .object([key: .int(1)]))
      }
    }
    XCTAssertEqual(access.createAttempts + access.updatePayloads.count, 0)
  }

  func testServerHasComparesByValue() {
    let date = Date(timeIntervalSince1970: 1_800_000_000.123_456)
    let server: [String: Any] = [
      "n": NSNumber(value: 2.0), "i": NSNumber(value: Int64(3)), "plan": ["next": "합성"], "at": Timestamp(date: date),
    ]
    XCTAssertTrue(FirestorePayload.serverHas(
      ["n": .int(2), "i": .number(3), "plan.next": .string("합성"), "at": .timestamp(date.addingTimeInterval(0.000_000_4)),
       "updatedAt": .serverTimestamp], in: server))
    XCTAssertFalse(FirestorePayload.serverHas(["plan.next": .string("다른 값")], in: server))
    XCTAssertFalse(FirestorePayload.serverHas(["missing": .string("x")], in: server))
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
    XCTAssertEqual(RemoteErrorMapper.map(NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError)), .notFound)
    for code in [StorageErrorCode.invalidArgument, .pathError, .bucketMismatch, .downloadSizeExceeded] {
      XCTAssertEqual(RemoteErrorMapper.map(NSError(domain: StorageErrorDomain, code: code.rawValue)), .invalidArgument, "\(code)")
    }
    XCTAssertEqual(RemoteErrorMapper.map(StorageError.pathError(message: "synthetic")), .invalidArgument, "Swift StorageError bridges")
    XCTAssertEqual(RemoteErrorMapper.map(StorageError.objectNotFound(object: "fx", serverError: [:])), .notFound)
    XCTAssertEqual(RemoteErrorMapper.map(NSError(domain: FunctionsErrorDomain, code: FunctionsErrorCode.invalidArgument.rawValue)), .invalidArgument)
    XCTAssertEqual(RemoteErrorMapper.map(NSError(domain: FunctionsErrorDomain, code: FunctionsErrorCode.internal.rawValue)),
                   .unknown("functions:\(FunctionsErrorCode.internal.rawValue)"))
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

  /// Finding 10: the MD5 is read in chunks and equals the one-shot digest (3 MiB crosses two chunk borders).
  func testChunkedMD5EqualsTheWholeFileDigest() throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("df104-\(UUID().uuidString).bin")
    let data = Data((0..<(3 << 20)).map { UInt8(truncatingIfNeeded: $0 &* 31) })
    try data.write(to: file)
    defer { try? FileManager.default.removeItem(at: file) }
    XCTAssertEqual(try UploadIntegrity.md5Base64(of: file), Data(Insecure.MD5.hash(data: data)).base64EncodedString())
  }

  /// TC-104-08: a download lands at the target, excluded from backup, replacing an older copy, and leaves no
  /// staging directory behind.
  func testDownloadWritesTheFileInPlace() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("df104-dl-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let target = folder.appendingPathComponent("ink.drawing")
    try Data("old".utf8).write(to: target)
    let access = FakeStorageAccess(size: 0, md5: nil, download: Data("synthetic ink".utf8))
    let url = try await StorageBinaryDownloader(access: access).download(path: "soapInk/n1/2.drawing", to: target)
    XCTAssertEqual(url, target)
    XCTAssertEqual(try Data(contentsOf: target), Data("synthetic ink".utf8))
    XCTAssertEqual(try target.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), ["ink.drawing"])
  }

  func testAFailedDownloadLeavesNothingBehind() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("df104-dl-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let access = FakeStorageAccess(size: 0, md5: nil, download: nil)
    do {
      _ = try await StorageBinaryDownloader(access: access).download(path: "soapInk/n1/9.drawing", to: folder.appendingPathComponent("x"))
      XCTFail("expected notFound")
    } catch {
      XCTAssertEqual(error as? RemoteError, .notFound)
    }
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), [])
  }

  // MARK: TC-104-07 / 09

  func testCallablesUseTheSeoulRegion() {
    XCTAssertEqual(FunctionsCallableClient.region, "asia-northeast3")
  }

  func testCallablePayloadIsPlainJSON() throws {
    let date = Date(timeIntervalSince1970: 0)
    let plain = try FunctionsCallableClient.plain(.object(["at": .timestamp(date), "n": .int(2), "b": .bytes(Data([255]))])) as? [String: Any]
    XCTAssertEqual(plain?["at"] as? String, "1970-01-01T00:00:00.000Z", "V1-06 §3 milliseconds")
    XCTAssertEqual(plain?["b"] as? String, "/w==")
    XCTAssertThrowsError(try FunctionsCallableClient.plain(.object(["t": .serverTimestamp])))
  }

  func testStorageUsesTheSeoulBucketUnlessTheEmulatorIsConfigured() {
    XCTAssertEqual(StorageBucket.seoul, "dfetmanage-seoul")
    XCTAssertEqual(StorageFactory.bucketURL(emulator: false), "gs://dfetmanage-seoul")
    XCTAssertNil(StorageFactory.bucketURL(emulator: true))
    XCTAssertEqual(StorageFactory.maxUploadRetrySeconds, 120)
  }

  private func assertThrows(
    _ expected: RemoteError, _ message: String = "", file: StaticString = #filePath, line: UInt = #line,
    _ body: () async throws -> Void
  ) async {
    do {
      try await body()
      XCTFail("expected \(expected) \(message)", file: file, line: line)
    } catch {
      XCTAssertEqual(error as? RemoteError, expected, message, file: file, line: line)
    }
  }
}

/// Firestore document access that behaves like the repository's rules for one trainer (probes P1-P8 of the PR #173
/// review): a missing or someone else's document cannot be read, a second create is denied, a missing document can be
/// neither updated nor deleted, and frozen (finalized) documents take no update or delete.
final class RulesLikeDocumentAccess: FirestoreDocumentAccess, @unchecked Sendable {
  private let lock = NSLock()
  private let trainerUid: String
  private var documents: [String: [String: Any]]
  private var _createPayloads: [String: [String: Any]] = [:]
  private var _updatePayloads: [[String: Any]] = []
  private var _createAttempts = 0
  private var _serverReads = 0
  private var _loseNextReply = false
  private var _frozen: Set<String> = []
  private var _rejectCreates = false
  private var _readShowsPendingWrites = false
  private var _pendingWritesDrain = true
  private var _nextError: Error?
  private var _readableByAnyone: Set<String> = []

  init(trainerUid: String, documents: [String: [String: Any]] = [:]) {
    self.trainerUid = trainerUid
    self.documents = documents
  }

  var createPayloads: [String: [String: Any]] { lock.withLock { _createPayloads } }
  var updatePayloads: [[String: Any]] { lock.withLock { _updatePayloads } }
  var createAttempts: Int { lock.withLock { _createAttempts } }
  var serverReads: Int { lock.withLock { _serverReads } }
  var frozen: Set<String> {
    get { lock.withLock { _frozen } }
    set { lock.withLock { _frozen = newValue } }
  }
  var rejectCreates: Bool {
    get { lock.withLock { _rejectCreates } }
    set { lock.withLock { _rejectCreates = newValue } }
  }
  var readShowsPendingWrites: Bool {
    get { lock.withLock { _readShowsPendingWrites } }
    set { lock.withLock { _readShowsPendingWrites = newValue } }
  }
  var pendingWritesDrain: Bool {
    get { lock.withLock { _pendingWritesDrain } }
    set { lock.withLock { _pendingWritesDrain = newValue } }
  }
  /// Paths whose rules let any trainer read them.
  var readableByAnyone: Set<String> {
    get { lock.withLock { _readableByAnyone } }
    set { lock.withLock { _readableByAnyone = newValue } }
  }
  var nextError: Error? {
    get { lock.withLock { _nextError } }
    set { lock.withLock { _nextError = newValue } }
  }

  /// The next write commits on the server, but its reply is lost (`unavailable`).
  func loseNextReply() {
    lock.withLock { _loseNextReply = true }
  }

  private static let denied = NSError(domain: FirestoreErrorDomain, code: FirestoreErrorCode.Code.permissionDenied.rawValue)
  private static let lost = NSError(domain: FirestoreErrorDomain, code: FirestoreErrorCode.Code.unavailable.rawValue)

  private func isMine(_ fields: [String: Any]) -> Bool {
    FirestoreRemoteWriter.ownerKeys.contains { (fields[$0] as? String) == trainerUid }
  }

  /// Runs a write under the rules; `apply` returns false when the rules deny it.
  private func write(_ apply: () -> Bool) throws {
    try lock.withLock {
      if let error = _nextError {
        _nextError = nil
        throw error
      }
      guard apply() else { throw Self.denied }
      if _loseNextReply {
        _loseNextReply = false
        throw Self.lost
      }
    }
  }

  func serverDocument(path: String) async throws -> ServerDocument {
    try lock.withLock {
      _serverReads += 1
      guard let fields = documents[path], isMine(fields) || _readableByAnyone.contains(path) else { throw Self.denied }
      return ServerDocument(fields: fields, hasPendingWrites: _readShowsPendingWrites, isFromCache: false)
    }
  }

  func waitForPendingWrites(seconds: TimeInterval) async -> Bool { pendingWritesDrain }

  func create(path: String, fields: [String: Any]) async throws {
    try write {
      _createAttempts += 1
      guard documents[path] == nil, !_rejectCreates else { return false }
      _createPayloads[path] = fields
      documents[path] = fields.filter { !($0.value is FieldValue) }
      return true
    }
  }

  func update(path: String, fields: [String: Any]) async throws {
    try write {
      guard var document = documents[path], !_frozen.contains(path) else { return false }
      _updatePayloads.append(fields)
      for (key, value) in fields where !(value is FieldValue) { document[key] = value }
      documents[path] = document
      if (fields["status"] as? String) == "finalized" { _frozen.insert(path) }
      return true
    }
  }

  func delete(path: String) async throws {
    try write {
      guard documents[path] != nil, !_frozen.contains(path) else { return false }
      documents[path] = nil
      return true
    }
  }
}

/// Scripted Storage access.
final class FakeStorageAccess: StorageFileAccess, @unchecked Sendable {
  private let lock = NSLock()
  private let size: Int64
  private let md5: String?
  private let deleteNotFound: Bool
  private let download: Data?
  private var _metadata: [String: String]?

  /// `download` is the stored file's content; nil means the object does not exist.
  init(size: Int64, md5: String?, deleteNotFound: Bool = false, download: Data? = nil) {
    self.size = size
    self.md5 = md5
    self.deleteNotFound = deleteNotFound
    self.download = download
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

  func write(path: String, to localURL: URL) async throws {
    guard let download else { throw NSError(domain: StorageErrorDomain, code: StorageErrorCode.objectNotFound.rawValue) }
    try download.write(to: localURL)
  }
}
