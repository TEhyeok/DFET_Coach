import FirebaseFirestore
import Foundation
import TrainerDomain
import XCTest
@testable import FirebaseData

/// TC-DF013-01, TC-DF013-02 and the offline rules: chunked reads, one emission, no partial or empty list that is not
/// true. Synthetic data only.
final class FirestoreMemberDirectoryTests: XCTestCase {
  private let ids = (1...23).map { String(format: "synthMember%04d", $0) }

  private func collect(_ directory: FirestoreMemberDirectory) async -> (emissions: [[Member]], error: MemberDirectoryError?) {
    var emissions: [[Member]] = []
    do {
      for try await members in directory.observeAssignedMembers() { emissions.append(members) }
      return (emissions, nil)
    } catch {
      return (emissions, error as? MemberDirectoryError)
    }
  }

  func testTwentyThreeMembersReadInThreeChunksAndEmittedOnce_TC_DF013_01() async {
    let gateway = FakeMemberGateway(snapshots: [.server(ids)])
    let result = await collect(FirestoreMemberDirectory(trainerUid: "synthTrainerA", gateway: gateway))
    XCTAssertNil(result.error)
    XCTAssertEqual(result.emissions.count, 1)
    XCTAssertEqual(result.emissions.first?.map(\.id), ids, "memberIds order")
    XCTAssertEqual(gateway.chunkSizes.sorted(), [3, 10, 10])
  }

  func testAFailedChunkFailsTheStreamWithoutAPartialList_TC_DF013_02() async {
    let gateway = FakeMemberGateway(snapshots: [.server(ids)], failingChunk: 1)
    let result = await collect(FirestoreMemberDirectory(trainerUid: "synthTrainerA", gateway: gateway))
    XCTAssertEqual(result.error, .permissionDenied)
    XCTAssertEqual(result.emissions.count, 0)
  }

  func testNoAssignmentOnTheServerIsAnEmptyList() async {
    let gateway = FakeMemberGateway(snapshots: [MemberIdsSnapshot(ids: [], exists: false, isFromCache: false)])
    let result = await collect(FirestoreMemberDirectory(trainerUid: "synthTrainerA", gateway: gateway))
    XCTAssertEqual(result.emissions, [[]])
    XCTAssertEqual(gateway.chunkSizes, [])
  }

  func testOfflineWithoutACachedAssignmentFailsInsteadOfShowingEmpty() async {
    let gateway = FakeMemberGateway(snapshots: [MemberIdsSnapshot(ids: [], exists: false, isFromCache: true)])
    let result = await collect(FirestoreMemberDirectory(trainerUid: "synthTrainerA", gateway: gateway))
    XCTAssertEqual(result.error, .unavailable)
    XCTAssertEqual(result.emissions.count, 0)
  }

  func testOfflineWithAPartlyCachedChunkFailsInsteadOfShowingPartial() async {
    let gateway = FakeMemberGateway(snapshots: [.cached(Array(ids.prefix(3)))], cachedUsers: Set(ids.prefix(1)))
    let result = await collect(FirestoreMemberDirectory(trainerUid: "synthTrainerA", gateway: gateway))
    XCTAssertEqual(result.error, .unavailable)
    XCTAssertEqual(result.emissions.count, 0)
  }

  func testOfflineWithEverythingCachedShowsTheList() async {
    let gateway = FakeMemberGateway(snapshots: [.cached(Array(ids.prefix(3)))], cachedUsers: Set(ids.prefix(3)))
    let result = await collect(FirestoreMemberDirectory(trainerUid: "synthTrainerA", gateway: gateway))
    XCTAssertNil(result.error)
    XCTAssertEqual(result.emissions.last?.map(\.id), Array(ids.prefix(3)))
  }

  func testAMalformedMemberIdsFieldIsAnError() async {
    let gateway = FakeMemberGateway(snapshots: [MemberIdsSnapshot(ids: nil, exists: true, isFromCache: false)])
    let result = await collect(FirestoreMemberDirectory(trainerUid: "synthTrainerA", gateway: gateway))
    XCTAssertEqual(result.error, .unknown(code: 0))
  }

  /// A read for an older memberIds value never emits after a newer one, even when it finishes last.
  func testASupersededReadNeverEmits() async {
    let gateway = FakeMemberGateway(snapshots: [.server(["a", "b"]), .server(["a"])], gateFirstRead: true)
    let directory = FirestoreMemberDirectory(trainerUid: "synthTrainerA", gateway: gateway)
    let collecting = Task { await collect(directory) }
    let reading = await eventually { gateway.isFirstReadWaiting }
    XCTAssertTrue(reading)
    gateway.sendNextSnapshot()  // ["a"] arrives while the first read is out
    let newer = await eventually { gateway.completedReads >= 1 }
    XCTAssertTrue(newer)
    gateway.releaseFirstRead()
    gateway.finishSnapshots()
    let result = await collecting.value
    XCTAssertNil(result.error)
    XCTAssertEqual(result.emissions.map { $0.map(\.id) }, [["a"]])
  }

  /// L2: a superseded read that fails (for example an unassigned member still in a cached list) does not end the
  /// stream.
  func testASupersededReadFailingDoesNotFailTheStream() async {
    let gateway = FakeMemberGateway(snapshots: [.server(["a", "x"]), .server(["a"])], gateFirstRead: true, failFirstRead: true)
    let directory = FirestoreMemberDirectory(trainerUid: "synthTrainerA", gateway: gateway)
    let collecting = Task { await collect(directory) }
    let reading = await eventually { gateway.isFirstReadWaiting }
    XCTAssertTrue(reading)
    gateway.sendNextSnapshot()
    let newer = await eventually { gateway.completedReads >= 1 }
    XCTAssertTrue(newer)
    gateway.releaseFirstRead()
    gateway.finishSnapshots()
    let result = await collecting.value
    XCTAssertNil(result.error)
    XCTAssertEqual(result.emissions.map { $0.map(\.id) }, [["a"]])
  }

  /// L3: when the consumer goes away, the read in flight is cancelled and the listener removed.
  func testCancellingTheConsumerCancelsTheReadAndTheListener() async {
    let gateway = FakeMemberGateway(snapshots: [.server(["a"])], gateFirstRead: true, keepListenerOpen: true)
    let directory = FirestoreMemberDirectory(trainerUid: "synthTrainerA", gateway: gateway)
    let consumer = Task { await collect(directory) }
    let reading = await eventually { gateway.isFirstReadWaiting }
    XCTAssertTrue(reading)
    consumer.cancel()
    let removed = await eventually { gateway.listenerRemoved }
    XCTAssertTrue(removed, "the trainers/{uid} listener is removed")
    gateway.releaseFirstRead()  // the fake's gate only notices cancellation once it resumes
    let cancelled = await eventually { gateway.firstReadWasCancelled }
    XCTAssertTrue(cancelled, "the read in flight was cancelled")
  }

  func testFirestoreErrorCodesMap() {
    func firestore(_ code: FirestoreErrorCode.Code) -> NSError {
      NSError(domain: FirestoreErrorDomain, code: code.rawValue)
    }
    XCTAssertEqual(MemberDirectoryErrorMapper.map(firestore(.permissionDenied)), .permissionDenied)
    XCTAssertEqual(MemberDirectoryErrorMapper.map(firestore(.failedPrecondition)), .indexMissing)
    XCTAssertEqual(MemberDirectoryErrorMapper.map(firestore(.unavailable)), .unavailable)
    XCTAssertEqual(MemberDirectoryErrorMapper.map(firestore(.internal)), .unknown(code: FirestoreErrorCode.Code.internal.rawValue))
    XCTAssertEqual(MemberDirectoryErrorMapper.map(NSError(domain: "other", code: 5)), .unknown(code: 5))
  }

  private func eventually(_ condition: () -> Bool) async -> Bool {
    for _ in 0..<400 {
      if condition() { return true }
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
    return condition()
  }
}

extension MemberIdsSnapshot {
  static func server(_ ids: [String]) -> MemberIdsSnapshot { MemberIdsSnapshot(ids: ids, exists: true, isFromCache: false) }
  static func cached(_ ids: [String]) -> MemberIdsSnapshot { MemberIdsSnapshot(ids: ids, exists: true, isFromCache: true) }
}

/// Scripted gateway. Snapshots are sent one after another (each after the previous read completed) unless the first
/// read is gated, in which case the test drives them. Cached snapshots read users from `cachedUsers` only.
final class FakeMemberGateway: MemberDirectoryGateway, @unchecked Sendable {
  private let lock = NSLock()
  private let snapshots: [MemberIdsSnapshot]
  private let failingChunk: Int?
  private let cachedUsers: Set<String>?
  private let gateFirstRead: Bool
  private let failFirstRead: Bool
  private let keepListenerOpen: Bool
  private var _chunkSizes: [Int] = []
  private var chunkCalls = 0
  private var _completedReads = 0
  private var firstReadGate: CheckedContinuation<Void, Never>?
  private var firstReadReleased = false
  private var _firstReadWaiting = false
  private var _firstReadCancelled = false
  private var _listenerRemoved = false
  private var continuation: AsyncThrowingStream<MemberIdsSnapshot, Error>.Continuation?
  private var nextSnapshot = 0
  private var currentSnapshotIsCached = false

  init(snapshots: [MemberIdsSnapshot], failingChunk: Int? = nil, cachedUsers: Set<String>? = nil,
       gateFirstRead: Bool = false, failFirstRead: Bool = false, keepListenerOpen: Bool = false) {
    self.snapshots = snapshots
    self.failingChunk = failingChunk
    self.cachedUsers = cachedUsers
    self.gateFirstRead = gateFirstRead
    self.failFirstRead = failFirstRead
    self.keepListenerOpen = keepListenerOpen
  }

  var chunkSizes: [Int] { lock.withLock { _chunkSizes } }
  var completedReads: Int { lock.withLock { _completedReads } }
  var isFirstReadWaiting: Bool { lock.withLock { _firstReadWaiting } }
  var firstReadWasCancelled: Bool { lock.withLock { _firstReadCancelled } }
  var listenerRemoved: Bool { lock.withLock { _listenerRemoved } }

  func memberIds(trainerUid: String) -> AsyncThrowingStream<MemberIdsSnapshot, Error> {
    AsyncThrowingStream { continuation in
      lock.withLock { self.continuation = continuation }
      continuation.onTermination = { [weak self] _ in self?.lock.withLock { self?._listenerRemoved = true } }
      if gateFirstRead {
        sendNextSnapshot()
      } else {
        Task {
          for _ in snapshots {
            sendNextSnapshot()
            try? await Task.sleep(nanoseconds: 50_000_000)
          }
          if !keepListenerOpen { finishSnapshots() }
        }
      }
    }
  }

  func sendNextSnapshot() {
    lock.withLock {
      guard nextSnapshot < snapshots.count else { return }
      let snapshot = snapshots[nextSnapshot]
      nextSnapshot += 1
      currentSnapshotIsCached = snapshot.isFromCache
      continuation?.yield(snapshot)
    }
  }

  func finishSnapshots() {
    lock.withLock { continuation }?.finish()
  }

  func releaseFirstRead() {
    let gate: CheckedContinuation<Void, Never>? = lock.withLock {
      firstReadReleased = true
      defer { firstReadGate = nil }
      return firstReadGate
    }
    gate?.resume()
  }

  func users(ids: [String]) async throws -> UsersChunk {
    let (index, cached): (Int, Bool) = lock.withLock {
      _chunkSizes.append(ids.count)
      defer { chunkCalls += 1 }
      return (chunkCalls, currentSnapshotIsCached)
    }
    if gateFirstRead, index == 0 {
      await withCheckedContinuation { (gate: CheckedContinuation<Void, Never>) in
        let resumeNow: Bool = lock.withLock {
          _firstReadWaiting = true
          if firstReadReleased { return true }
          firstReadGate = gate
          return false
        }
        if resumeNow { gate.resume() }
      }
      if Task.isCancelled { lock.withLock { _firstReadCancelled = true } }
      if failFirstRead {
        throw NSError(domain: FirestoreErrorDomain, code: FirestoreErrorCode.Code.permissionDenied.rawValue)
      }
    }
    defer { lock.withLock { _completedReads += 1 } }
    if index == failingChunk {
      throw NSError(domain: FirestoreErrorDomain, code: FirestoreErrorCode.Code.permissionDenied.rawValue)
    }
    let available = cached ? ids.filter { cachedUsers?.contains($0) ?? true } : ids
    return UsersChunk(members: available.map { Member(id: $0, displayName: "가상 \($0.suffix(4))", trainerId: "synthTrainerA") },
                      isFromCache: cached)
  }
}
