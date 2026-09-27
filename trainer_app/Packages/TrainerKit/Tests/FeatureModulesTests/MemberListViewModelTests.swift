import Foundation
import TrainerDomain
import XCTest
@testable import FeatureMembers

/// DF-013, DF-113: TR-02 states through the public start/retry API (AC-DF-013.2, AC-DF-013.5, AC-DF-113.1-.3, .5).
/// A failure stays a failure; one subscription at a time; a chip per listed member from `EffectiveConsent` only.
@MainActor
final class MemberListViewModelTests: XCTestCase {
  private let a = Member(id: "u1", displayName: "가회원", trainerId: "t")
  private let b = Member(id: "u2", displayName: "나회원", trainerId: "t")
  private let p = PendingMember(id: "SynPendingList000001", displayName: "다회원")
  private let local = PendingMember(id: "SynPendingList000009", displayName: "라회원")

  private func entry(_ member: Member) -> MemberListEntry { MemberListEntry(key: .uid(member.id), displayName: member.displayName) }
  private func entry(_ member: PendingMember) -> MemberListEntry {
    MemberListEntry(key: .pending(member.id), displayName: member.displayName)
  }

  private func makeModel(
    _ directory: ControlledDirectory, device: ControlledLocalPending = ControlledLocalPending(),
    consent: ControlledConsent = ControlledConsent()
  ) -> MemberListViewModel {
    MemberListViewModel(directory: directory, localPending: device, consent: consent)
  }

  func testLoadedMembersAreSortedByName() async {
    let directory = ControlledDirectory()
    let model = makeModel(directory)
    XCTAssertEqual(model.state, .loading)
    model.start()
    directory.emit([b, a])
    directory.emitPending([])
    await waitFor { model.state == .loaded([self.entry(self.a), self.entry(self.b)]) }
  }

  /// AC-DF-113.1: assigned, server pending and device-only pending members in one list, by name.
  func test_AC_DF_113_1_assignedAndPendingInOneList() async {
    let directory = ControlledDirectory()
    let device = ControlledLocalPending()
    let model = makeModel(directory, device: device)
    model.start()
    directory.emit([b, a])
    directory.emitPending([p])
    await waitFor { model.state == .loaded([self.entry(self.a), self.entry(self.b), self.entry(self.p)]) }
    device.emit([local, p])  // `p` is on the server already: listed once
    await waitFor {
      model.state == .loaded([self.entry(self.a), self.entry(self.b), self.entry(self.p), self.entry(self.local)])
    }
  }

  /// Both server lists must answer before anything is shown: no list without its pending members, or the reverse.
  func testLoadingUntilBothServerListsAnswered() async {
    let directory = ControlledDirectory()
    let device = ControlledLocalPending()
    let model = makeModel(directory, device: device)
    model.start()
    directory.emit([a])
    device.emit([local])
    try? await Task.sleep(nanoseconds: 50_000_000)
    XCTAssertEqual(model.state, .loading)
    directory.emitPending([])
    await waitFor { model.state == .loaded([self.entry(self.a), self.entry(self.local)]) }
  }

  /// A pending member registered offline is enough for a list: not the empty state.
  func testOnlyADeviceOnlyPendingMemberIsNotEmpty() async {
    let directory = ControlledDirectory()
    let device = ControlledLocalPending()
    let model = makeModel(directory, device: device)
    model.start()
    directory.emit([])
    directory.emitPending([])
    await waitFor { model.state == .empty }
    device.emit([local])
    await waitFor { model.state == .loaded([self.entry(self.local)]) }
  }

  /// The device list cannot fail; if it ends, its last value stays and the server subscriptions go on.
  func testADeviceListThatEndsKeepsTheServerSubscriptions() async {
    let directory = ControlledDirectory()
    let device = ControlledLocalPending()
    let model = makeModel(directory, device: device)
    model.start()
    await waitFor { device.subscribed }
    device.emit([local])
    device.finish()
    directory.emit([a])
    directory.emitPending([])
    await waitFor { model.state == .loaded([self.entry(self.a), self.entry(self.local)]) }
    directory.emit([a, b])
    await waitFor { model.state == .loaded([self.entry(self.a), self.entry(self.b), self.entry(self.local)]) }
    XCTAssertEqual(directory.activeSubscriptions, 1)
    XCTAssertEqual(directory.activePendingSubscriptions, 1)
  }

  func testEmptyAndFailedAreDifferentStates() async {
    let directory = ControlledDirectory()
    let model = makeModel(directory)
    model.start()
    directory.emit([])
    directory.emitPending([])
    await waitFor { model.state == .empty }
    directory.fail(.permissionDenied)
    await waitFor { model.state == .failed(.permissionDenied) }
  }

  /// AC-DF-113.3: a failure of the pending list fails the whole list; the assigned members are not shown alone.
  func test_AC_DF_113_3_aPendingListFailureFailsTheList() async {
    let directory = ControlledDirectory()
    let model = makeModel(directory)
    model.start()
    directory.emit([a])
    directory.failPending(.permissionDenied)
    await waitFor { model.state == .failed(.permissionDenied) }
    XCTAssertEqual(model.visibleEntries, [])
    await waitFor { directory.activeSubscriptions == 0 && directory.activePendingSubscriptions == 0 }
  }

  func testRetryReplacesTheSubscriptionAndStartsFromLoading() async {
    let directory = ControlledDirectory()
    let model = makeModel(directory)
    model.start()
    directory.fail(.unavailable)
    await waitFor { model.state == .failed(.unavailable) }
    model.retry()
    XCTAssertEqual(model.state, .loading)
    await waitFor { directory.activeSubscriptions == 1 && directory.activePendingSubscriptions == 1 }
    directory.emit([a])
    directory.emitPending([])
    await waitFor { model.state == .loaded([self.entry(self.a)]) }
  }

  /// M1: retry while a subscription is still active leaves exactly one subscription, and a later start() does not add
  /// another.
  func testRetryWhileActiveKeepsOneSubscription() async {
    let directory = ControlledDirectory()
    let model = makeModel(directory)
    model.start()
    await waitFor { directory.activeSubscriptions == 1 }
    model.retry()
    await waitFor { directory.activeSubscriptions == 1 && directory.totalSubscriptions == 2 }
    model.start()  // the view reappears
    try? await Task.sleep(nanoseconds: 50_000_000)
    XCTAssertEqual(directory.activeSubscriptions, 1)
    XCTAssertEqual(directory.totalSubscriptions, 2)
    XCTAssertEqual(directory.activePendingSubscriptions, 1)
  }

  func testAStaleSubscriptionCannotOverwriteTheCurrentState() async {
    let directory = ControlledDirectory()
    let model = makeModel(directory)
    model.start()
    model.retry()
    await waitFor { directory.totalSubscriptions == 2 && directory.totalPendingSubscriptions == 2 }
    directory.emit([a], subscription: 1)
    directory.emitPending([], subscription: 1)
    directory.emit([b], subscription: 0)  // the replaced one
    await waitFor { model.state == .loaded([self.entry(self.a)]) }
    try? await Task.sleep(nanoseconds: 50_000_000)
    XCTAssertEqual(model.state, .loaded([entry(a)]))
  }

  func testStartAfterAFailureShowsLoadingAgain() async {
    let directory = ControlledDirectory()
    let model = makeModel(directory)
    model.start()
    directory.fail(.unavailable)
    await waitFor { model.state == .failed(.unavailable) }
    model.start()  // the view came back after the failure
    XCTAssertEqual(model.state, .loading)
  }

  /// Screens never stop the subscription (a resize shows a second list first); releasing the model ends it.
  func testReleasingTheModelEndsTheSubscription() async {
    let directory = ControlledDirectory()
    let consent = ControlledConsent()
    var model: MemberListViewModel? = makeModel(directory, consent: consent)
    model?.start()
    await waitFor { directory.activeSubscriptions == 1 }
    model?.start()  // a second screen appearing
    await waitFor { directory.activeSubscriptions == 1 }
    directory.emit([a])
    directory.emitPending([])
    await waitFor { consent.active == [.uid("u1")] }
    model = nil
    await waitFor { directory.activeSubscriptions == 0 && directory.activePendingSubscriptions == 0 }
    await waitFor { consent.active.isEmpty }
  }

  // MARK: AC-DF-113.2 consent chips

  func test_AC_DF_113_2_eachRowGetsTheChipOfItsEffectiveConsent() async {
    let directory = ControlledDirectory()
    let consent = ControlledConsent()
    let model = makeModel(directory, consent: consent)
    model.start()
    directory.emit([a, b])
    directory.emitPending([p])
    await waitFor { consent.active == [.uid("u1"), .uid("u2"), .pending(self.p.id)] }
    XCTAssertEqual(model.chips, [:], "no chip before the member's first value")
    let all = EffectiveConsent(required: .granted, healthData: .granted, bodyImaging: .granted)
    consent.emit(all, for: .uid("u1"))
    consent.emit(.none, for: .uid("u2"))
    consent.emit(EffectiveConsent(required: .granted, healthData: .awaitingConsent, bodyImaging: .awaitingConsent),
                 for: .pending(p.id))
    await waitFor {
      model.chips == [.uid("u1"): .coreGranted, .uid("u2"): .needed, .pending(self.p.id): .awaiting]
    }
    consent.emit(EffectiveConsent(required: .granted, healthData: .rejected, bodyImaging: .granted), for: .uid("u1"))
    await waitFor { model.chips[.uid("u1")] == .needed }
  }

  /// A member that leaves the list loses its consent subscription and chip; one that stays keeps its one subscription.
  func testAMemberThatLeavesTheListLosesItsChipAndSubscription() async {
    let directory = ControlledDirectory()
    let consent = ControlledConsent()
    let model = makeModel(directory, consent: consent)
    model.start()
    directory.emit([a])
    directory.emitPending([p])
    await waitFor { consent.active == [.uid("u1"), .pending(self.p.id)] }
    consent.emit(.none, for: .pending(p.id))
    await waitFor { model.chips[.pending(self.p.id)] == .needed }
    directory.emitPending([])  // cancelled or promoted on the server
    await waitFor { consent.active == [.uid("u1")] }
    XCTAssertNil(model.chips[.pending(p.id)])
    directory.emit([a, b])
    await waitFor { consent.active == [.uid("u1"), .uid("u2")] }
    XCTAssertEqual(consent.total, 3, "u1 kept its subscription")
  }

  func testAFailedListDropsEveryChip() async {
    let directory = ControlledDirectory()
    let consent = ControlledConsent()
    let model = makeModel(directory, consent: consent)
    model.start()
    directory.emit([a])
    directory.emitPending([])
    await waitFor { consent.active == [.uid("u1")] }
    consent.emit(.none, for: .uid("u1"))
    await waitFor { model.chips[.uid("u1")] == .needed }
    directory.fail(.unavailable)
    await waitFor { model.state == .failed(.unavailable) && consent.active.isEmpty }
    XCTAssertEqual(model.chips, [:])
  }

  // MARK: AC-DF-113.5 search

  func test_AC_DF_113_5_theQueryFiltersTheLoadedList() async {
    let directory = ControlledDirectory()
    let model = makeModel(directory)
    model.start()
    directory.emit([a, b])
    directory.emitPending([p])
    await waitFor { model.visibleEntries.count == 3 }
    model.query = " 다 회 "
    XCTAssertEqual(model.visibleEntries, [entry(p)])
    model.query = "없음"
    XCTAssertEqual(model.visibleEntries, [])
    XCTAssertEqual(model.state, .loaded([entry(a), entry(b), entry(p)]), "searching changes nothing else")
    model.query = ""
    XCTAssertEqual(model.visibleEntries.count, 3)
  }

  private func waitFor(_ condition: @escaping @MainActor () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
    for _ in 0..<200 where !condition() {
      try? await Task.sleep(nanoseconds: 25_000_000)
    }
    XCTAssertTrue(condition(), "condition not reached", file: file, line: line)
  }
}

/// Subscriptions the test drives, numbered from 0.
final class ControlledStreams<Value: Sendable>: @unchecked Sendable {
  private let lock = NSLock()
  private var continuations: [Int: AsyncThrowingStream<Value, Error>.Continuation] = [:]
  private var next = 0

  var active: Int { lock.withLock { continuations.count } }
  var total: Int { lock.withLock { next } }

  func subscribe() -> AsyncThrowingStream<Value, Error> {
    AsyncThrowingStream { continuation in
      let id: Int = lock.withLock {
        defer { next += 1 }
        continuations[next] = continuation
        return next
      }
      continuation.onTermination = { [weak self] _ in
        self?.lock.withLock { _ = self?.continuations.removeValue(forKey: id) }
      }
    }
  }

  /// Emits on the newest subscription unless `subscription` is given.
  func emit(_ value: Value, subscription: Int? = nil) {
    lock.withLock { continuations[subscription ?? (next - 1)] }?.yield(value)
  }

  func fail(_ error: Error) {
    lock.withLock { continuations[next - 1] }?.finish(throwing: error)
  }
}

/// A directory whose assigned and pending subscriptions the test drives.
final class ControlledDirectory: MemberDirectory, @unchecked Sendable {
  let assigned = ControlledStreams<[Member]>()
  let pending = ControlledStreams<[PendingMember]>()

  var activeSubscriptions: Int { assigned.active }
  var totalSubscriptions: Int { assigned.total }
  var activePendingSubscriptions: Int { pending.active }
  var totalPendingSubscriptions: Int { pending.total }

  func observeAssignedMembers() -> AsyncThrowingStream<[Member], Error> { assigned.subscribe() }
  func observePendingMembers() -> AsyncThrowingStream<[PendingMember], Error> { pending.subscribe() }

  func emit(_ members: [Member], subscription: Int? = nil) { assigned.emit(members, subscription: subscription) }
  func emitPending(_ members: [PendingMember], subscription: Int? = nil) { pending.emit(members, subscription: subscription) }
  func fail(_ error: MemberDirectoryError) { assigned.fail(error) }
  func failPending(_ error: MemberDirectoryError) { pending.fail(error) }
}

/// Device-only pending members the test drives (the newest subscription).
final class ControlledLocalPending: LocalPendingMemberSource, @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: AsyncStream<[PendingMember]>.Continuation?

  func observeLocalPendingMembers() -> AsyncStream<[PendingMember]> {
    AsyncStream { continuation in lock.withLock { self.continuation = continuation } }
  }

  var subscribed: Bool { lock.withLock { continuation != nil } }

  func emit(_ members: [PendingMember]) {
    lock.withLock { continuation }?.yield(members)
  }

  func finish() {
    lock.withLock { continuation }?.finish()
  }
}

/// Effective consent per member that the test drives; records which members are subscribed.
final class ControlledConsent: EffectiveConsentSource, @unchecked Sendable {
  private let lock = NSLock()
  private var continuations: [MemberKey: AsyncStream<EffectiveConsent>.Continuation] = [:]
  private var _total = 0

  /// Members with a live subscription, in no particular order.
  var active: Set<MemberKey> { lock.withLock { Set(continuations.keys) } }
  var total: Int { lock.withLock { _total } }

  func observe(member: MemberKey) -> AsyncStream<EffectiveConsent> {
    AsyncStream { continuation in
      lock.withLock {
        continuations[member] = continuation
        _total += 1
      }
      continuation.onTermination = { [weak self] _ in
        self?.lock.withLock { _ = self?.continuations.removeValue(forKey: member) }
      }
    }
  }

  func emit(_ value: EffectiveConsent, for member: MemberKey) {
    lock.withLock { continuations[member] }?.yield(value)
  }
}
