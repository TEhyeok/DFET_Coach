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
    var expected = original
    expected.payload = nil  // an acked payload is not kept (review M1)
    XCTAssertEqual(loaded, [expected])
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

  /// The contract: an insert retried after a save that committed replaces the row (review L4).
  func testInsertOfAKnownIdReplacesTheRowAndUpdateOfAMissingRowDoesNothing() async throws {
    let store = LocalOutboxStore(container: try LocalStoreContainer.make(inMemory: true), trainerUid: Synthetic.trainerA,
                                 binaries: nil)
    var first = item(.createDocument, .document(path: "soap_notes/n1"))
    try await store.insert(first)
    first.attempts = 9
    try await store.insert(first)
    let loaded = try await store.loadAll()
    XCTAssertEqual(loaded.map(\.attempts), [9])
    XCTAssertEqual(loaded.count, 1)
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

  /// Review M5: a sequence is reserved when handed out, so concurrent callers never share one, even before any row
  /// with it is saved.
  func testConcurrentCallersGetDistinctSequences() async throws {
    let store = LocalOutboxStore(container: try LocalStoreContainer.make(inMemory: true), trainerUid: Synthetic.trainerA,
                                 binaries: nil)
    let sequences = try await withThrowingTaskGroup(of: Int64.self) { group in
      for _ in 0..<20 { group.addTask { try await store.nextSequence(for: Synthetic.memberA) } }
      return try await group.reduce(into: [Int64]()) { $0.append($1) }
    }
    XCTAssertEqual(sequences.sorted(), Array(1...20))
    try await store.insert(item(.createDocument, .document(path: "soap_notes/n1"), sequence: 3))
    let next = try await store.nextSequence(for: Synthetic.memberA)
    XCTAssertEqual(next, 21)
  }

  /// The local stage and kind enums carry the domain's raw values, so a row can always be written.
  func testLocalStageAndKindMatchTheDomain() {
    XCTAssertEqual(LocalOutboxStage.allCases.map(\.rawValue), OutboxStage.allCases.map(\.rawValue))
    XCTAssertEqual(LocalOutboxKind.allCases.map(\.rawValue), OutboxKind.allCases.map(\.rawValue))
  }

  /// Review M1: once the pending-member create is acked, neither the draft nor the Outbox row keeps the name.
  func testAnAckedCreateKeepsNoPersonalData() async throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let store = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerA, binaries: nil)
    let id = "SynthPending00000009"
    var create = Item(
      memberKey: .pending(id), entityRef: .pendingMember(id: id), sequence: 1, stage: .memberKey,
      kind: .createDocument, target: .document(path: "pendingMembers/\(id)"),
      payload: .object(["displayName": .string("가상회원 프로브"), "birthYear": .int(1990)]), createdAt: Synthetic.now)
    try await store.insertPendingMember(
      PendingMemberDraftRecord(pendingMemberId: id, displayName: "가상회원 프로브", sex: "female", birthYear: 1990,
                               ageConfirmed14: true, createdLocallyAt: Synthetic.now),
      createItem: create)
    create.state = .acked
    create.ack = .write(WriteAck(serverCommitted: true))
    try await store.update(create)

    let context = ModelContext(container)
    XCTAssertEqual(try context.fetchOwned(LocalPendingMemberDraft.self, by: Synthetic.trainerA).count, 0)
    let rows = try context.fetchOwned(OutboxItem.self, by: Synthetic.trainerA)
    XCTAssertEqual(rows.count, 1)
    XCTAssertNil(rows.first?.payloadJSON)
  }

  /// Review M3: a row this build cannot read is held as a failed item, so the later steps of its record wait instead
  /// of running without it.
  func testAnUnreadableRowHoldsTheLaterStepsOfItsRecord() async throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let store = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerA, binaries: nil)
    let create = item(.createDocument, .document(path: "soap_notes/n1"), sequence: 1, payload: .object([:]))
    var update = item(.updateDocument, .document(path: "soap_notes/n1"), sequence: 2, payload: .object(["a": .int(1)]))
    update = Item(id: update.id, memberKey: update.memberKey, entityRef: create.entityRef, sequence: 2,
                  stage: .document, kind: .updateDocument, target: update.target, payload: update.payload,
                  createdAt: Synthetic.now)
    try await store.insert(create)
    try await store.insert(update)
    let context = ModelContext(container)
    let createRow = try XCTUnwrap(context.fetchOwned(OutboxItem.self, by: Synthetic.trainerA).first { $0.id == create.id })
    createRow.state = "stateFromANewerBuild"
    try context.save()

    let loaded = try await store.loadAll()
    XCTAssertEqual(loaded.map(\.id), [create.id, update.id])
    XCTAssertEqual(loaded.first?.state, .failed)
    XCTAssertEqual(loaded.first?.lastErrorCode, "local-unreadable")
    XCTAssertNil(loaded.first?.payload)

    let remote = RecordingRemote()
    let engine = SyncEngine(store: store, writer: remote, uploader: remote, callable: remote)
    await engine.start()
    await engine.waitUntilIdle()
    XCTAssertEqual(remote.creates, [])
    XCTAssertEqual(remote.updates, [], "the update waits for its create")
    await engine.stop()
  }

  /// Review M4: the draft and its create are one save, so a process killed before the engine hears of it still has
  /// the item on the next launch.
  @MainActor
  func testTheDraftAndItsCreateAreSavedTogether() async throws {
    let temp = try TemporaryDirectory()
    self.temp = temp
    let url = temp.url.appendingPathComponent("store.sqlite")
    do {
      let store = LocalOutboxStore(container: try LocalStoreContainer.make(url: url), trainerUid: Synthetic.trainerA,
                                   binaries: nil)
      let registrar = LocalPendingMemberRegistrar(
        outbox: store, trainerUid: Synthetic.trainerA, enqueue: { _ in },  // killed before the engine saw it
        now: { Synthetic.now }, makeID: { "SynthPending00000010" })
      _ = try await registrar.register(
        PendingMemberDraft(displayName: "가상회원", sex: .male, birthYear: 1990, ageConfirmed14: true))
    }
    let container = try LocalStoreContainer.make(url: url)
    let items = try await LocalOutboxStore(container: container, trainerUid: Synthetic.trainerA, binaries: nil).loadAll()
    XCTAssertEqual(items.map(\.target), [.document(path: "pendingMembers/SynthPending00000010")])
    let drafts = try ModelContext(container).fetchOwned(LocalPendingMemberDraft.self, by: Synthetic.trainerA)
    XCTAssertEqual(drafts.map(\.outboxItemId), items.map(\.id))
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

    // Same bytes, another file: each item keeps its own file (review L1).
    let twin = try binaries.write(data: Data("synthetic ink".utf8), ext: "drawing", kind: .ink)
    context.insert(LocalBinary(
      id: twin.id, trainerUid: Synthetic.trainerA, kind: .ink, relativePath: twin.relativePath,
      contentType: twin.contentType, byteSize: twin.byteSize, sha256: twin.sha256, md5Base64: twin.md5Base64))
    try context.save()
    let twinRef = LocalBinaryRef(localURL: try binaries.url(forRelativePath: twin.relativePath),
                                 contentType: twin.contentType, sha256: twin.sha256)
    let twinUpload = item(.uploadBinary, .storage(path: "soapInk/n2/1.drawing"), sequence: 2, stage: .upload,
                          binary: twinRef)
    try await store.insert(twinUpload)
    let both = try await store.loadAll()
    XCTAssertEqual(both.map(\.binary?.localURL), [ref.localURL, twinRef.localURL])

    // A file without a LocalBinary row fails only its own item after a reload, never the store (review M2).
    let orphan = LocalBinaryRef(localURL: location.rootURL.appendingPathComponent("Binaries/ink/missing.drawing"),
                                contentType: "application/octet-stream", sha256: "0000")
    let orphanUpload = item(.uploadBinary, .storage(path: "soapInk/n3/1.drawing"), sequence: 3, stage: .upload,
                            binary: orphan)
    try await store.insert(orphanUpload)
    let reloaded = try await store.loadAll()
    XCTAssertEqual(reloaded.count, 3)
    XCTAssertNil(reloaded.last?.binary, "sent as malformed: fails alone")
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
