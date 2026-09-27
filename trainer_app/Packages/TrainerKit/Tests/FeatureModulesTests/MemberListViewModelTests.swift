import Foundation
import TrainerDomain
import XCTest
@testable import FeatureMembers

/// DF-013: TR-02 states through the public start/retry/stop API (AC-DF-013.2, AC-DF-013.5). A failure stays a
/// failure; one subscription at a time.
@MainActor
final class MemberListViewModelTests: XCTestCase {
  private let a = Member(id: "u1", displayName: "가회원", trainerId: "t")
  private let b = Member(id: "u2", displayName: "나회원", trainerId: "t")

  func testLoadedMembersAreSortedByName() async {
    let directory = ControlledDirectory()
    let model = MemberListViewModel(directory: directory)
    XCTAssertEqual(model.state, .loading)
    model.start()
    directory.emit([b, a])
    await waitFor { model.state == .loaded([self.a, self.b]) }
  }

  func testEmptyAndFailedAreDifferentStates() async {
    let directory = ControlledDirectory()
    let model = MemberListViewModel(directory: directory)
    model.start()
    directory.emit([])
    await waitFor { model.state == .empty }
    directory.fail(.permissionDenied)
    await waitFor { model.state == .failed(.permissionDenied) }
  }

  func testRetryReplacesTheSubscriptionAndStartsFromLoading() async {
    let directory = ControlledDirectory()
    let model = MemberListViewModel(directory: directory)
    model.start()
    directory.fail(.unavailable)
    await waitFor { model.state == .failed(.unavailable) }
    model.retry()
    XCTAssertEqual(model.state, .loading)
    await waitFor { directory.activeSubscriptions == 1 }
    directory.emit([a])
    await waitFor { model.state == .loaded([self.a]) }
  }

  /// M1: retry while a subscription is still active leaves exactly one subscription, and a later start() does not add
  /// another.
  func testRetryWhileActiveKeepsOneSubscription() async {
    let directory = ControlledDirectory()
    let model = MemberListViewModel(directory: directory)
    model.start()
    await waitFor { directory.activeSubscriptions == 1 }
    model.retry()
    await waitFor { directory.activeSubscriptions == 1 && directory.totalSubscriptions == 2 }
    model.start()  // the view reappears
    try? await Task.sleep(nanoseconds: 50_000_000)
    XCTAssertEqual(directory.activeSubscriptions, 1)
    XCTAssertEqual(directory.totalSubscriptions, 2)
  }

  func testAStaleSubscriptionCannotOverwriteTheCurrentState() async {
    let directory = ControlledDirectory()
    let model = MemberListViewModel(directory: directory)
    model.start()
    model.retry()
    await waitFor { directory.totalSubscriptions == 2 }
    directory.emit([a], subscription: 1)
    directory.emit([b], subscription: 0)  // the replaced one
    await waitFor { model.state == .loaded([self.a]) }
    try? await Task.sleep(nanoseconds: 50_000_000)
    XCTAssertEqual(model.state, .loaded([a]))
  }

  func testStartAfterAFailureShowsLoadingAgain() async {
    let directory = ControlledDirectory()
    let model = MemberListViewModel(directory: directory)
    model.start()
    directory.fail(.unavailable)
    await waitFor { model.state == .failed(.unavailable) }
    model.start()  // the view came back after the failure
    XCTAssertEqual(model.state, .loading)
  }

  /// Screens never stop the subscription (a resize shows a second list first); releasing the model ends it.
  func testReleasingTheModelEndsTheSubscription() async {
    let directory = ControlledDirectory()
    var model: MemberListViewModel? = MemberListViewModel(directory: directory)
    model?.start()
    await waitFor { directory.activeSubscriptions == 1 }
    model?.start()  // a second screen appearing
    await waitFor { directory.activeSubscriptions == 1 }
    model = nil
    await waitFor { directory.activeSubscriptions == 0 }
  }

  func testDisplayNameSearchIgnoresCaseAndWhitespace_TC_113_04() {
    let korean = Member(id: "SYN-korean", displayName: "가상 회원", trainerId: "SYN-trainer", isPending: true)
    let latin = Member(id: "SYN-latin", displayName: "Jane Doe", trainerId: "SYN-trainer")
    let members = [korean, latin]
    XCTAssertEqual(MemberListViewModel.filter(members, query: "  가 상\n회  "), [korean])
    XCTAssertEqual(MemberListViewModel.filter(members, query: "JANEdoE"), [latin])
    XCTAssertEqual(MemberListViewModel.filter(members, query: "가상".decomposedStringWithCanonicalMapping), [korean])
    XCTAssertEqual(MemberListViewModel.filter(members, query: "  \n"), members)
    XCTAssertEqual(MemberListViewModel.filter(members, query: "없는회원"), [])
    XCTAssertTrue(MemberListViewModel.filter(members, query: "가상").first?.isPending == true)
  }

  func testSearchKeepsFullStateAndLiveSubscription_TC_113_04() async {
    let directory = ControlledDirectory()
    let model = MemberListViewModel(directory: directory)
    model.start()
    directory.emit([a, b])
    await waitFor { model.state == .loaded([self.a, self.b]) }
    model.searchText = "가"
    XCTAssertEqual(model.visibleMembers, [a])
    XCTAssertEqual(model.state, .loaded([a, b]), "selected-member lookup still sees the complete directory")
    model.searchText = "없는회원"
    XCTAssertTrue(model.visibleMembers.isEmpty)
    XCTAssertTrue(model.hasSearch)
    XCTAssertEqual(model.state, .loaded([a, b]), "no search result is distinct from an empty directory")
    model.searchText = "나"
    directory.emit([b])
    await waitFor { model.state == .loaded([self.b]) }
    XCTAssertEqual(model.visibleMembers, [b])
    model.start()
    XCTAssertEqual(directory.activeSubscriptions, 1)
    XCTAssertEqual(directory.totalSubscriptions, 1, "search does not reopen the directory")
    model.searchText = " \n "
    XCTAssertFalse(model.hasSearch)
    XCTAssertEqual(model.visibleMembers, [b])
  }

  private func waitFor(_ condition: @escaping @MainActor () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
    for _ in 0..<200 where !condition() {
      try? await Task.sleep(nanoseconds: 25_000_000)
    }
    XCTAssertTrue(condition(), "condition not reached", file: file, line: line)
  }
}

/// A directory whose subscriptions the test drives. Subscription numbers count from 0.
final class ControlledDirectory: MemberDirectory, @unchecked Sendable {
  private let lock = NSLock()
  private var continuations: [Int: AsyncThrowingStream<[Member], Error>.Continuation] = [:]
  private var next = 0

  var activeSubscriptions: Int { lock.withLock { continuations.count } }
  var totalSubscriptions: Int { lock.withLock { next } }

  func observeAssignedMembers() -> AsyncThrowingStream<[Member], Error> {
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
  func emit(_ members: [Member], subscription: Int? = nil) {
    lock.withLock { continuations[subscription ?? (next - 1)] }?.yield(members)
  }

  func fail(_ error: MemberDirectoryError) {
    lock.withLock { continuations[next - 1] }?.finish(throwing: error)
  }
}
