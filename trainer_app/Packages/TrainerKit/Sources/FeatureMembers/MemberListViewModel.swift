import Foundation
import Observation
import TrainerDomain

/// TR-02 state (DF-013). Loading, empty and failed are separate states: a failure is never shown as an empty list
/// (AC-DF-013.2, AC-DF-013.5).
@MainActor
@Observable
public final class MemberListViewModel {
  public enum State: Equatable {
    case loading
    case loaded([Member])
    case empty
    case failed(MemberDirectoryError)
  }

  public private(set) var state: State = .loading

  private let directory: any MemberDirectory
  @ObservationIgnored private var task: Task<Void, Never>?

  public init(directory: any MemberDirectory) {
    self.directory = directory
  }

  /// Starts observing once; later calls do nothing while a subscription is running.
  public func start() {
    guard task == nil else { return }
    task = Task { [weak self] in await self?.observe() }
  }

  /// '다시 시도' after a failure: subscribes again from the loading state.
  public func retry() {
    task?.cancel()
    task = nil
    state = .loading
    start()
  }

  func observe() async {
    do {
      for try await members in directory.observeAssignedMembers() {
        state = members.isEmpty ? .empty : .loaded(Self.sorted(members))
      }
    } catch is CancellationError {
      return
    } catch let error as MemberDirectoryError {
      state = .failed(error)
    } catch {
      state = .failed(.unknown(code: (error as NSError).code))
    }
    task = nil
  }

  /// Name order as the trainer reads it (Korean collation), uid as a tie-breaker.
  static func sorted(_ members: [Member]) -> [Member] {
    members.sorted {
      let order = $0.displayName.localizedStandardCompare($1.displayName)
      return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
    }
  }
}
