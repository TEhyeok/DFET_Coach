import Foundation
import TrainerDomain
import XCTest
@testable import FeatureSettings

/// DF-018 (AC-DF-018.2, .3, TC-DF018-02): TR-15 state. Synthetic data only.
@MainActor
final class SettingsViewModelTests: XCTestCase {
  private final class FakeQueue: SyncQueueService, @unchecked Sendable {
    private let lock = NSLock()
    private let count: Int
    private let failed: [OutboxItem]
    private var _retried: [UUID] = []
    private var _retryAllCalls = 0
    init(count: Int, failed: [OutboxItem] = []) {
      self.count = count
      self.failed = failed
    }
    var retried: [UUID] { lock.withLock { _retried } }
    var retryAllCalls: Int { lock.withLock { _retryAllCalls } }
    func pendingCount() async -> AsyncStream<Int> { AsyncStream { [count] in $0.yield(count) } }
    func failedItems() async -> AsyncStream<[OutboxItem]> { AsyncStream { [failed] in $0.yield(failed) } }
    func retry(_ id: UUID) async { lock.withLock { _retried.append(id) } }
    func retryAll() async { lock.withLock { _retryAllCalls += 1 } }
  }

  private final class FakeSignOut: SessionSignOut, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls = 0
    let fails: Bool
    init(fails: Bool = false) { self.fails = fails }
    var calls: Int { lock.withLock { _calls } }
    func signOut() async throws {
      lock.withLock { _calls += 1 }
      if fails { throw NSError(domain: "synthetic", code: 1) }
    }
  }

  private func failedItem() -> OutboxItem {
    OutboxItem(memberKey: .uid("syn-0001"), entityRef: .soap(noteId: "SynNote0000000000001"), sequence: 1,
               stage: .document, kind: .createDocument, target: .document(path: "soap_notes/SynNote0000000000001"),
               state: .failed, lastErrorCode: "permission-denied", createdAt: Date(timeIntervalSince1970: 1_780_000_000))
  }

  private func started(_ model: SettingsViewModel, count: Int, failed: Int = 0) async {
    model.start()
    for _ in 0..<200 where model.pendingCount != count || model.failedItems.count != failed {
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
  }

  func testNothingUnsyncedAsksOnceThenSignsOut() async {
    let signOut = FakeSignOut()
    let model = SettingsViewModel(queue: FakeQueue(count: 0), signOut: signOut, accountName: "SYN-TRAINER",
                                  version: "1.0 (1)")
    await started(model, count: 0)
    model.requestSignOut()
    XCTAssertEqual(model.prompt, .confirm)
    await model.signOut()
    XCTAssertEqual(signOut.calls, 1)
    XCTAssertNil(model.prompt)
    XCTAssertFalse(model.isSigningOut)
    XCTAssertFalse(model.signOutFailed)
  }

  /// TC-DF018-02: unsynced records warn with the count; the choices are sync now, keep and log out, or cancel. There is
  /// no delete choice, and logging out never touches the queue.
  func testUnsyncedRecordsWarnAndAreNeverDeleted_TC_DF018_02() async {
    let queue = FakeQueue(count: 3)
    let signOut = FakeSignOut()
    let model = SettingsViewModel(queue: queue, signOut: signOut, accountName: nil, version: "1.0 (1)")
    await started(model, count: 3)
    model.requestSignOut()
    XCTAssertEqual(model.prompt, .unsynced)
    XCTAssertEqual(model.pendingCount, 3)

    await model.syncNow()
    XCTAssertEqual(queue.retryAllCalls, 1)
    XCTAssertEqual(model.prompt, .unsynced, "the warning stays, with the live count")
    XCTAssertEqual(signOut.calls, 0)

    await model.signOut()
    XCTAssertEqual(signOut.calls, 1)
    XCTAssertEqual(queue.retried, [])
    XCTAssertEqual(queue.retryAllCalls, 1)
  }

  func testAFailedSignOutSaysSoAndCanBeTriedAgain() async {
    let model = SettingsViewModel(queue: FakeQueue(count: 0), signOut: FakeSignOut(fails: true), accountName: "",
                                  version: "1.0 (1)")
    XCTAssertNil(model.accountName, "an empty display name shows no account row")
    await model.signOut()
    XCTAssertTrue(model.signOutFailed)
    XCTAssertFalse(model.isSigningOut)
    model.requestSignOut()
    XCTAssertFalse(model.signOutFailed)
  }

  /// Cross-review: records still waiting (queued after '모두 다시 시도' offline, in flight, awaiting consent) with none
  /// failed are not "nothing to send"; the queue says how many wait. Only an empty Outbox is empty.
  func testTheQueueIsEmptyOnlyWhenNothingWaits() async {
    let waiting = SettingsViewModel(queue: FakeQueue(count: 2), signOut: FakeSignOut(), accountName: nil,
                                    version: "1.0 (1)")
    await started(waiting, count: 2)
    XCTAssertEqual(waiting.queueNotice, .waiting(2))

    let empty = SettingsViewModel(queue: FakeQueue(count: 0), signOut: FakeSignOut(), accountName: nil,
                                  version: "1.0 (1)")
    await started(empty, count: 0)
    XCTAssertEqual(empty.queueNotice, .empty)

    let failed = SettingsViewModel(queue: FakeQueue(count: 3, failed: [failedItem()]), signOut: FakeSignOut(),
                                   accountName: nil, version: "1.0 (1)")
    await started(failed, count: 3, failed: 1)
    XCTAssertNil(failed.queueNotice, "the failed items are listed")
  }

  /// AC-DF-018.3: failed items arrive from the queue and '다시 시도' goes to the right item.
  func testFailedItemsAndRetry() async {
    let item = failedItem()
    let queue = FakeQueue(count: 1, failed: [item])
    let model = SettingsViewModel(queue: queue, signOut: FakeSignOut(), accountName: nil, version: "1.0 (1)")
    await started(model, count: 1, failed: 1)
    XCTAssertEqual(model.failedItems.map(\.id), [item.id])
    await model.retry(item.id)
    await model.retryAll()
    XCTAssertEqual(queue.retried, [item.id])
    XCTAssertEqual(queue.retryAllCalls, 1)
  }
}
