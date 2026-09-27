import Foundation
import SwiftData
import SyncEngine
import TrainerDomain
import XCTest
@testable import LocalStore

/// DF-108: the SyncEngine's Outbox on LocalStore. Synthetic data only.
final class LocalOutboxStoreTests: XCTestCase {
  private typealias Item = TrainerDomain.OutboxItem
  private var temp: TemporaryDirectory?

  override func tearDown() {
    temp?.remove()
    temp = nil
    super.tearDown()
  }

  private func item(
    _ kind: OutboxKind, _ target: RemoteTarget, member: MemberKey = Synthetic.memberA, sequence: Int64 = 1,
    stage: OutboxStage = .document, payload: JSONValue? = nil, binary: LocalBinaryRef? = nil
  ) -> Item {
    Item(memberKey: member, entityRef: .soap(noteId: "n\(sequence)"), sequence: sequence, stage: stage, kind: kind,
         target: target, payload: payload, binary: binary, createdAt: Synthetic.now)
  }

  func testEveryKindRoundTripsWithItsTargetAndPayload() async throws {
    let store = LocalOutboxStore(container: try LocalStoreContainer.make(inMemory: true), trainerUid: Synthetic.trainerA,
                                 binaries: nil)
    let payload = JSONValue.object([
      "n": .number(1.5), "i": .int(7), "t": .timestamp(Date(timeIntervalSince1970: 1_790_000_000.123456)),
      "st": .serverTimestamp, "b": .bytes(Data([1, 2])), "list": .array([.string("a"), .null]),
      "map": .object(["flag": .bool(true)]),
    ])
    let items = [
      item(.createDocument, .document(path: "soap_notes/n1"), sequence: 1, payload: payload),
      item(.updateDocument, .document(path: "soap_notes/n1"), sequence: 2, payload: .object(["q": .string("합성")])),
      item(.deleteDocument, .document(path: "soap_notes/n1"), sequence: 3),
      item(.finalize, .document(path: "soap_notes/n1"), sequence: 4, stage: .finalize, payload: .object([:])),
      item(.callConsent, .callable(name: "recordConsent"), sequence: 5, stage: .consent, payload: .object([:])),
      item(.callFunction, .callable(name: "registerPending"), sequence: 6, stage: .memberKey),
      item(.deleteBinary, .storage(path: "soapInk/n1/1.drawing"), sequence: 7, stage: .upload),
    ]
    for item in items { try await store.insert(item) }
    let loaded = try await store.loadAll()
    XCTAssertEqual(loaded, items)
  }

  func testUpdateKeepsStateAttemptsAndTheAckConfirmationAcrossARestart() async throws {
    let temp = try TemporaryDirectory()
    self.temp = temp
    let url = temp.url.appendingPathComponent("store.sqlite")
    var original = item(.createDocument, .document(path: "soap_notes/n1"), payload: .object([:]))
    do {
      let store = LocalOutboxStore(container: try LocalStoreContainer.make(url: url), trainerUid: Synthetic.trainerA,
                                   binaries: nil)
      try await store.insert(original)
      original.state = .acked
      original.attempts = 2
      original.lastErrorCode = "unavailable"
      original.ack = .write(WriteAck(serverCommitted: true))
      try await store.update(original)
    }
    let reopened = LocalOutboxStore(container: try LocalStoreContainer.make(url: url), trainerUid: Synthetic.trainerA,
                                    binaries: nil)
    let loaded = try await reopened.loadAll()
    XCTAssertEqual(loaded, [original])
    XCTAssertEqual(SyncStateCalculator.state(consentConfirmed: true, items: loaded.map(SyncStateCalculator.Item.init)), .synced)
  }

  func testBlockedAndSupersededStatesRoundTrip() async throws {
    let store = LocalOutboxStore(container: try LocalStoreContainer.make(inMemory: true), trainerUid: Synthetic.trainerA,
                                 binaries: nil)
    var blocked = item(.createDocument, .document(path: "soap_notes/n1"), sequence: 1)
    blocked.state = .blocked(.awaitingConsent)
    var superseded = item(.callConsent, .callable(name: "recordConsent"), sequence: 2, stage: .consent)
    superseded.state = .superseded
    try await store.insert(blocked)
    try await store.insert(superseded)
    let loaded = try await store.loadAll()
    XCTAssertEqual(loaded.map(\.state), [.blocked(.awaitingConsent), .superseded])
  }

  func testInsertIsIdempotentAndUpdateOfAMissingRowDoesNothing() async throws {
    let store = LocalOutboxStore(container: try LocalStoreContainer.make(inMemory: true), trainerUid: Synthetic.trainerA,
                                 binaries: nil)
    var first = item(.createDocument, .document(path: "soap_notes/n1"))
    try await store.insert(first)
    first.attempts = 9
    try await store.insert(first)  // same id: ignored
    let loaded = try await store.loadAll()
    XCTAssertEqual(loaded.map(\.attempts), [0])
    try await store.update(item(.updateDocument, .document(path: "soap_notes/n2")))  // never inserted
    let count = try await store.loadAll().count
    XCTAssertEqual(count, 1)
  }

  func testRowsAreScopedToTheTrainerAndSequencesArePerMember() async throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let storeA = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerA, binaries: nil)
    let storeB = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerB, binaries: nil)
    try await storeA.insert(item(.createDocument, .document(path: "soap_notes/n1"), sequence: 1))
    try await storeA.insert(item(.updateDocument, .document(path: "soap_notes/n1"), sequence: 4))
    let loadedB = try await storeB.loadAll()
    XCTAssertEqual(loadedB, [])
    let nextA = try await storeA.nextSequence(for: Synthetic.memberA)
    let nextOther = try await storeA.nextSequence(for: Synthetic.memberB)
    let nextB = try await storeB.nextSequence(for: Synthetic.memberA)
    XCTAssertEqual(nextA, 5)
    XCTAssertEqual(nextOther, 1)
    XCTAssertEqual(nextB, 1)
  }

  func testUploadItemsResolveTheirLocalBinary() async throws {
    let temp = try TemporaryDirectory()
    self.temp = temp
    let location = LocalStoreLocation(trainerUid: Synthetic.trainerA, applicationSupportURL: temp.url)
    let container = try LocalStoreContainer.make(location: location)
    let binaries = LocalBinaryStore(location: location)
    let file = try binaries.write(data: Data("synthetic ink".utf8), ext: "drawing", kind: .ink)
    let context = ModelContext(container)
    context.insert(LocalBinary(
      id: file.id, trainerUid: Synthetic.trainerA, kind: .ink, relativePath: file.relativePath,
      contentType: file.contentType, byteSize: file.byteSize, sha256: file.sha256, md5Base64: file.md5Base64))
    try context.save()

    let store = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerA, binaries: binaries)
    let ref = LocalBinaryRef(localURL: try binaries.url(forRelativePath: file.relativePath),
                             contentType: file.contentType, sha256: file.sha256)
    let upload = item(.uploadBinary, .storage(path: "soapInk/n1/1.drawing"), stage: .upload, binary: ref)
    try await store.insert(upload)
    let loaded = try await store.loadAll()
    XCTAssertEqual(loaded, [upload])

    let unknown = LocalBinaryRef(localURL: ref.localURL, contentType: "x", sha256: "0000")
    do {
      try await store.insert(item(.uploadBinary, .storage(path: "soapInk/n1/2.drawing"), sequence: 2, stage: .upload,
                                  binary: unknown))
      XCTFail("expected binaryNotFound")
    } catch {
      XCTAssertEqual(error as? LocalOutboxStoreError, .binaryNotFound)
    }
  }

  /// A V1 store (DF-014) opens with the current schema; its Outbox rows survive and have no ack confirmation yet.
  @MainActor
  func testAV1StoreMigratesToV1_1() throws {
    let temp = try TemporaryDirectory()
    self.temp = temp
    let url = temp.url.appendingPathComponent("v1.sqlite")
    do {
      let v1 = try ModelContainer(for: Schema(versionedSchema: LocalStoreSchemaV1.self),
                                  configurations: [ModelConfiguration(url: url)])
      let context = ModelContext(v1)
      context.insert(LocalStoreSchemaV1.OutboxItem(
        trainerUid: Synthetic.trainerA, memberKey: Synthetic.memberA, entityRef: "soap:n1", sequence: 1,
        stage: .document, kind: .createDocument, targetPath: "soap_notes/n1", createdAt: Synthetic.now))
      try context.save()
    }
    let current = ModelContext(try LocalStoreContainer.make(url: url))
    let rows = try current.fetchOwned(OutboxItem.self, by: Synthetic.trainerA)
    XCTAssertEqual(rows.map(\.targetPath), ["soap_notes/n1"])
    XCTAssertNil(rows.first?.ackConfirmed)
    XCTAssertEqual(try current.fetchOwned(LocalPendingMemberDraft.self, by: Synthetic.trainerA).count, 0)
  }
}
