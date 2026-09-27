import Foundation
import TrainerDomain
import XCTest
@testable import FeatureMembers

/// DF-013: TR-02 states (AC-DF-013.2, AC-DF-013.5). A failure stays a failure; retry subscribes again.
@MainActor
final class MemberListViewModelTests: XCTestCase {
  func testLoadedMembersAreSortedByName() async {
    let model = MemberListViewModel(directory: ScriptedDirectory(results: [.success([
      Member(id: "u2", displayName: "나회원", trainerId: "t"),
      Member(id: "u1", displayName: "가회원", trainerId: "t"),
    ])]))
    XCTAssertEqual(model.state, .loading)
    await model.observe()
    XCTAssertEqual(model.state, .loaded([
      Member(id: "u1", displayName: "가회원", trainerId: "t"),
      Member(id: "u2", displayName: "나회원", trainerId: "t"),
    ]))
  }

  func testEmptyListIsEmptyAndErrorIsFailedNotEmpty() async {
    let empty = MemberListViewModel(directory: ScriptedDirectory(results: [.success([])]))
    await empty.observe()
    XCTAssertEqual(empty.state, .empty)

    let failed = MemberListViewModel(directory: ScriptedDirectory(results: [.failure(.permissionDenied)]))
    await failed.observe()
    XCTAssertEqual(failed.state, .failed(.permissionDenied))
  }

  func testRetryResubscribesFromLoading() async {
    let directory = ScriptedDirectory(results: [.failure(.unavailable), .success([Member(id: "u1", displayName: "가", trainerId: nil)])])
    let model = MemberListViewModel(directory: directory)
    await model.observe()
    XCTAssertEqual(model.state, .failed(.unavailable))
    model.retry()
    XCTAssertEqual(model.state, .loading)
    for _ in 0..<200 where model.state == .loading {
      try? await Task.sleep(nanoseconds: 25_000_000)
    }
    XCTAssertEqual(model.state, .loaded([Member(id: "u1", displayName: "가", trainerId: nil)]))
    XCTAssertEqual(directory.subscriptions, 2)
  }
}

/// Each subscription takes the next scripted result.
final class ScriptedDirectory: MemberDirectory, @unchecked Sendable {
  private let lock = NSLock()
  private var results: [Result<[Member], MemberDirectoryError>]
  private var _subscriptions = 0

  init(results: [Result<[Member], MemberDirectoryError>]) {
    self.results = results
  }

  var subscriptions: Int { lock.withLock { _subscriptions } }

  func observeAssignedMembers() -> AsyncThrowingStream<[Member], Error> {
    let next: Result<[Member], MemberDirectoryError>? = lock.withLock {
      _subscriptions += 1
      return results.isEmpty ? nil : results.removeFirst()
    }
    return AsyncThrowingStream { continuation in
      switch next {
      case let .success(members)?:
        continuation.yield(members)
        continuation.finish()
      case let .failure(error)?:
        continuation.finish(throwing: error)
      case nil:
        continuation.finish()
      }
    }
  }
}
