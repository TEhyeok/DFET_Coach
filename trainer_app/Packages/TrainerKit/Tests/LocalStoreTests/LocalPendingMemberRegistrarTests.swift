import Foundation
import SwiftData
import SyncEngine
import TrainerDomain
import XCTest
@testable import LocalStore

/// DF-108 (TC-108-02, TC-108-05 without the emulator): registration saves on the device and queues a stage 0
/// `pendingMembers` create that the SyncEngine sends first. Synthetic data only.
final class LocalPendingMemberRegistrarTests: XCTestCase {
  private let draft = PendingMemberDraft(displayName: " 가상회원 가 ", sex: .female, birthYear: 1990, ageConfirmed14: true)
  private let fixedID = "SynthPending00000001"

  private final class Recorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _items: [TrainerDomain.OutboxItem] = []
    var items: [TrainerDomain.OutboxItem] { lock.withLock { _items } }
    func add(_ item: TrainerDomain.OutboxItem) { lock.withLock { _items.append(item) } }
  }

  @MainActor
  func test_AC_DF_108_5_registrationSavesLocallyAndQueuesAStageZeroCreate() async throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let outbox = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerA, binaries: nil)
    let recorder = Recorder()
    let registrar = LocalPendingMemberRegistrar(
      outbox: outbox, trainerUid: Synthetic.trainerA, enqueue: { recorder.add($0) },
      now: { Synthetic.now }, makeID: { [fixedID] in fixedID })
    let id = try await registrar.register(draft)
    XCTAssertEqual(id, fixedID)

    let row = try XCTUnwrap(ModelContext(container).fetchOwned(LocalPendingMemberDraft.self, by: Synthetic.trainerA).first)
    XCTAssertEqual(row.pendingMemberId, fixedID)
    XCTAssertEqual(row.displayName, "가상회원 가")
    XCTAssertEqual(row.sex, "female")
    XCTAssertEqual(row.birthYear, 1990)

    let item = try XCTUnwrap(recorder.items.first)
    XCTAssertEqual(recorder.items.count, 1)
    XCTAssertEqual(row.outboxItemId, item.id, "later consent captures point at this item (dependsOn)")
    XCTAssertEqual(item.memberKey, .pending(fixedID))
    XCTAssertEqual(item.stage, .memberKey)
    XCTAssertEqual(item.kind, .createDocument)
    XCTAssertEqual(item.target, .document(path: "pendingMembers/\(fixedID)"))
    XCTAssertEqual(item.entityRef, .pendingMember(id: fixedID))
    XCTAssertEqual(item.sequence, 1)
    guard case let .object(fields)? = item.payload else { return XCTFail("object payload expected") }
    XCTAssertEqual(Set(fields.keys).union(["createdAt", "updatedAt"]), PendingMemberPayload.documentKeys)
    XCTAssertEqual(fields["trainerId"], .string(Synthetic.trainerA))
  }

  @MainActor
  func testAnInvalidDraftSavesNothing() async throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let outbox = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerA, binaries: nil)
    let recorder = Recorder()
    let registrar = LocalPendingMemberRegistrar(
      outbox: outbox, trainerUid: Synthetic.trainerA, enqueue: { recorder.add($0) },
      now: { Synthetic.now })
    var under14 = draft
    under14.birthYear = 2012  // Synthetic.now is 2026
    do {
      _ = try await registrar.register(under14)
      XCTFail("expected invalidDraft")
    } catch {
      XCTAssertEqual(error as? PendingMemberRegistrationError, .invalidDraft)
    }
    XCTAssertEqual(try ModelContext(container).fetchOwned(LocalPendingMemberDraft.self, by: Synthetic.trainerA).count, 0)
    XCTAssertTrue(recorder.items.isEmpty)
  }

  /// Offline registration, then back online: the SyncEngine sends the create; after a restart the item is still
  /// acked and confirmed (the member reads as synced).
  @MainActor
  func testTheEngineSendsTheCreateAndItStaysSyncedAfterARestart() async throws {
    let temp = try TemporaryDirectory()
    defer { temp.remove() }
    let url = temp.url.appendingPathComponent("store.sqlite")
    let remote = RecordingRemote()
    do {
      let container = try LocalStoreContainer.make(url: url)
      let outbox = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerA, binaries: nil)
      let engine = SyncEngine(store: outbox, writer: remote, uploader: remote, callable: remote)
      await engine.networkDidChange(isReachable: false)
      await engine.start()
      let registrar = LocalPendingMemberRegistrar(
        outbox: outbox, trainerUid: Synthetic.trainerA, enqueue: { await engine.enqueue($0) },
        now: { Synthetic.now }, makeID: { [fixedID] in fixedID })
      _ = try await registrar.register(draft)
      XCTAssertEqual(remote.creates, [], "offline: nothing sent yet")
      await engine.networkDidChange(isReachable: true)
      var sent = false
      for _ in 0..<200 where !sent {
        let pending = await firstPending(engine)
        sent = pending == 0 && !remote.creates.isEmpty
        if !sent { try await Task.sleep(nanoseconds: 20_000_000) }
      }
      XCTAssertEqual(remote.creates, ["pendingMembers/\(fixedID)"])
      await engine.stop()
    }
    let reopened = LocalOutboxStore(container: try LocalStoreContainer.make(url: url), trainerUid: Synthetic.trainerA,
                                    binaries: nil)
    let items = try await reopened.loadAll()
    XCTAssertEqual(items.map(\.state), [.acked])
    let drafts = try ModelContext(try LocalStoreContainer.make(url: url)).fetchOwned(LocalPendingMemberDraft.self, by: Synthetic.trainerA)
    XCTAssertEqual(drafts.count, 0, "the acked create removed the local draft (ASM-05-38)")
    XCTAssertEqual(SyncStateCalculator.state(consentConfirmed: true, items: items.map(SyncStateCalculator.Item.init)),
                   .synced)
  }
}

private func firstPending(_ engine: SyncEngine) async -> Int {
  for await count in await engine.pendingCount() { return count }
  return -1
}

/// A remote that accepts every write and records the create and update paths.
final class RecordingRemote: RemoteWriter, BinaryUploader, CallableClient, @unchecked Sendable {
  private let lock = NSLock()
  private var _creates: [String] = []
  private var _updates: [String] = []
  var creates: [String] { lock.withLock { _creates } }
  var updates: [String] { lock.withLock { _updates } }

  func createIfAbsent(path: String, fields: JSONValue) async throws -> WriteAck {
    lock.withLock { _creates.append(path) }
    return WriteAck(serverCommitted: true)
  }
  func update(path: String, fields: JSONValue) async throws -> WriteAck {
    lock.withLock { _updates.append(path) }
    return WriteAck(serverCommitted: true)
  }
  func delete(path: String) async throws -> WriteAck { WriteAck(serverCommitted: true) }
  func upload(localURL: URL, path: String, contentType: String, sha256: String) async throws -> UploadReceipt {
    UploadReceipt(path: path, size: 0, sha256: sha256, verified: true)
  }
  func delete(path: String) async throws {}
  func call<T: Decodable & Sendable>(_ name: String, _ payload: JSONValue) async throws -> T {
    try JSONDecoder().decode(T.self, from: Data("{}".utf8))
  }
}
