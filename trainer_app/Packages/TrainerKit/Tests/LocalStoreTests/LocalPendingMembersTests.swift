import Foundation
import SwiftData
import TrainerDomain
import XCTest
@testable import LocalStore

/// DF-113: TR-02 lists a pending member registered on this device before the server has it (DF-108 drafts), and
/// stops once the create is acked (the server's list has it then). A member cancelled on this device is hidden until the
/// cancel is acked (AC-DF-113.6). Synthetic data only.
final class LocalPendingMembersTests: XCTestCase {
  private let draft = PendingMemberDraft(displayName: "가상 대기 회원", sex: .unspecified, birthYear: 1990, ageConfirmed14: true)

  /// Reads a stream's values into a list the test can poll.
  private final class Collector: @unchecked Sendable {
    private let lock = NSLock()
    private var _values: [DevicePendingMembers] = []
    var values: [DevicePendingMembers] { lock.withLock { _values } }
    var registered: [[PendingMember]] { values.map(\.registered) }
    func add(_ value: DevicePendingMembers) { lock.withLock { _values.append(value) } }
  }

  @MainActor
  func testARegistrationIsListedUntilItsCreateIsAcked() async throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let outbox = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerA, binaries: nil)
    let queued = Queued()
    let registrar = LocalPendingMemberRegistrar(
      outbox: outbox, trainerUid: Synthetic.trainerA, enqueue: { queued.set($0) }, now: { Synthetic.now },
      makeID: { "SynthPending00000001" })
    let collector = Collector()
    let stream = LocalPendingMembers(container: container, trainerUid: Synthetic.trainerA).observeLocalPendingMembers()
    let consumer = Task { for await value in stream { collector.add(value) } }
    defer { consumer.cancel() }

    await waitFor { collector.registered == [[]] }
    let id = try await registrar.register(draft)
    let member = PendingMember(id: id, displayName: "가상 대기 회원")
    await waitFor { collector.registered.last == [member] }

    var item = try XCTUnwrap(queued.item)
    item.state = .acked
    item.ack = .write(WriteAck(serverCommitted: true))
    try await outbox.update(item)  // deletes the draft (ASM-05-38)
    await waitFor { collector.registered.last == [] }
    XCTAssertEqual(collector.registered, [[], [member], []], "one value per change, nothing repeated")
    XCTAssertTrue(collector.values.allSatisfy(\.cancelled.isEmpty))
  }

  /// AC-DF-113.6: a cancel saved on the device hides the member at once (a registration still on the device too, and
  /// a member the server lists), for as long as the cancel is unsent, failed or in flight; once acked, the server's list
  /// no longer has the member and the device stops hiding it.
  @MainActor
  func test_AC_DF_113_6_aCancelHidesTheMemberUntilItIsAcked() async throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let outbox = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerA, binaries: nil)
    let queued = Queued()
    let registrar = LocalPendingMemberRegistrar(
      outbox: outbox, trainerUid: Synthetic.trainerA, enqueue: { queued.set($0) }, now: { Synthetic.now },
      makeID: { "SynthPending00000001" })
    let collector = Collector()
    let stream = LocalPendingMembers(container: container, trainerUid: Synthetic.trainerA).observeLocalPendingMembers()
    let consumer = Task { for await value in stream { collector.add(value) } }
    defer { consumer.cancel() }

    let id = try await registrar.register(draft)
    try await registrar.cancel(pendingMemberId: id)
    try await registrar.cancel(pendingMemberId: "SynthPending00000009")  // one the server lists
    await waitFor { collector.values.last?.cancelled == [id, "SynthPending00000009"] }
    XCTAssertEqual(collector.values.last?.registered.map(\.id), [id], "the draft is still there, but hidden")

    var cancel = try XCTUnwrap(queued.item)
    XCTAssertEqual(cancel.kind, .updateDocument)
    cancel.state = .failed
    cancel.lastErrorCode = "unavailable"
    try await outbox.update(cancel)
    XCTAssertEqual(try LocalPendingMembers.read(container: container, trainerUid: Synthetic.trainerA).cancelled,
                   [id, "SynthPending00000009"], "a failed cancel still hides the member")
    cancel.state = .acked
    cancel.ack = .write(WriteAck(serverCommitted: true))
    try await outbox.update(cancel)
    await waitFor { collector.values.last?.cancelled == [id] }
  }

  @MainActor
  func testAnotherTrainersDraftIsNotListed() async throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let outbox = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerB, binaries: nil)
    let registrar = LocalPendingMemberRegistrar(
      outbox: outbox, trainerUid: Synthetic.trainerB, enqueue: { _ in }, now: { Synthetic.now },
      makeID: { "SynthPending00000002" })
    _ = try await registrar.register(draft)
    try await registrar.cancel(pendingMemberId: "SynthPending00000002")
    XCTAssertEqual(try LocalPendingMembers.read(container: container, trainerUid: Synthetic.trainerA),
                   DevicePendingMembers())
    let own = try LocalPendingMembers.read(container: container, trainerUid: Synthetic.trainerB)
    XCTAssertEqual(own.registered.map(\.id), ["SynthPending00000002"])
    XCTAssertEqual(own.cancelled, ["SynthPending00000002"])
  }

  private final class Queued: @unchecked Sendable {
    private let lock = NSLock()
    private var _item: TrainerDomain.OutboxItem?
    var item: TrainerDomain.OutboxItem? { lock.withLock { _item } }
    func set(_ item: TrainerDomain.OutboxItem) { lock.withLock { _item = item } }
  }

  private func waitFor(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
    for _ in 0..<200 where !condition() {
      try? await Task.sleep(nanoseconds: 25_000_000)
    }
    XCTAssertTrue(condition(), "condition not reached", file: file, line: line)
  }
}
