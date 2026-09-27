import Foundation
import Observation
import TrainerDomain

/// TR-02 state (DF-013). Loading, empty and failed are separate states: a failure is never shown as an empty list
/// (AC-DF-013.2, AC-DF-013.5).
///
/// One subscription at a time: every `start()` gets a generation, and a result or completion from an older
/// generation is ignored, so a cancelled run can never overwrite state or drop the current task handle.
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
  @ObservationIgnored private var generation = 0

  public init(directory: any MemberDirectory) {
    self.directory = directory
  }

  deinit {
    task?.cancel()
  }

  /// Subscribes unless a subscription is running. After a failure it starts again from `.loading`.
  public func start() {
    guard task == nil else { return }
    generation += 1
    let current = generation
    if case .failed = state { state = .loading }
    let stream = directory.observeAssignedMembers()
    task = Task { [weak self] in
      do {
        for try await members in stream {
          guard let self, self.generation == current else { return }
          self.state = members.isEmpty ? .empty : .loaded(Self.sorted(members))
        }
        self?.finished(current, error: nil)
      } catch {
        self?.finished(current, error: error)
      }
    }
  }

  /// Ends the subscription (the list left the screen). `start()` subscribes again.
  public func stop() {
    task?.cancel()
    task = nil
    generation += 1
  }

  /// '다시 시도': drops the current subscription and subscribes again from `.loading`.
  public func retry() {
    stop()
    state = .loading
    start()
  }

  private func finished(_ run: Int, error: Error?) {
    guard run == generation else { return }  // a stopped or replaced run
    task = nil
    guard let error else { return }
    state = .failed((error as? MemberDirectoryError) ?? .unknown(code: (error as NSError).code))
  }

  /// Name order as the trainer reads it (Korean collation), uid as a tie-breaker.
  static func sorted(_ members: [Member]) -> [Member] {
    members.sorted {
      let order = $0.displayName.localizedStandardCompare($1.displayName)
      return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
    }
  }
}
