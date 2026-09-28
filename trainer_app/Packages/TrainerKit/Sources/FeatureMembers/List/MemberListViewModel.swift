import Foundation
import Observation
import TrainerDomain

/// TR-02 state (DF-013, DF-113). Loading, empty and failed are separate states: a failure is never shown as an empty
/// list (AC-DF-013.2, AC-DF-013.5, AC-DF-113.3).
///
/// The list joins three streams (AC-DF-113.1): the assigned members, the server's pending members and the pending
/// members registered on this device but not yet on the server. It loads until both server lists have answered; a
/// failure of either fails the whole list, so a partial list is never shown (§9.6).
///
/// Every listed member has its own consent subscription (AC-DF-113.2): the chip reads `EffectiveConsent.chipState`
/// only, never `memberConsentStates` (AC-DF-111.7). A member that leaves the list loses its subscription and chip.
///
/// '등록 취소' (AC-DF-113.6) saves the cancel on the device through `PendingMemberCanceller`; the member leaves the list
/// at once and stays out (the device's unsent cancels, `DevicePendingMembers.cancelled`) until the server's list no
/// longer has it.
///
/// One subscription at a time: every `start()` gets a generation, and a value or completion from an older generation is
/// ignored, so a cancelled run can never overwrite state or drop the current task handles. The subscriptions live as
/// long as the model (the shell keeps one for the session); screens only call `start()`.
@MainActor
@Observable
public final class MemberListViewModel {
  public enum State: Equatable {
    case loading
    case loaded([MemberListEntry])
    case empty
    case failed(MemberDirectoryError)
  }

  public private(set) var state: State = .loading
  /// The search field (AC-DF-113.5). It filters `visibleEntries` on the device; the subscriptions do not change.
  public var query = ""
  /// The consent chip of each listed member, from its latest `EffectiveConsent`. Absent until the first value.
  public private(set) var chips: [MemberKey: ConsentChipState] = [:]
  /// The last '등록 취소' could not be saved on the device (the member stays listed).
  public private(set) var cancelFailed = false

  /// The loaded list filtered by `query`; empty in every other state.
  public var visibleEntries: [MemberListEntry] {
    guard case let .loaded(entries) = state else { return [] }
    return MemberList.search(entries, query: query)
  }

  private let directory: any MemberDirectory
  private let localPending: any LocalPendingMemberSource
  private let consent: any EffectiveConsentSource
  private let canceller: (any PendingMemberCanceller)?
  @ObservationIgnored private var tasks: [Task<Void, Never>] = []
  @ObservationIgnored private var generation = 0
  /// The latest value of each stream in the current generation; nil until the stream's first value.
  @ObservationIgnored private var assigned: [Member]?
  @ObservationIgnored private var serverPending: [PendingMember]?
  @ObservationIgnored private var devicePending = DevicePendingMembers()
  /// Cancelled from this model, so the row leaves before the device source reports the saved cancel.
  @ObservationIgnored private var cancelledHere: Set<String> = []
  @ObservationIgnored private var consentTasks: [MemberKey: Task<Void, Never>] = [:]

  /// `canceller` nil: no '등록 취소'.
  public init(
    directory: any MemberDirectory, localPending: any LocalPendingMemberSource, consent: any EffectiveConsentSource,
    canceller: (any PendingMemberCanceller)? = nil
  ) {
    self.directory = directory
    self.localPending = localPending
    self.consent = consent
    self.canceller = canceller
  }

  /// Whether a pending row offers '등록 취소' (AC-DF-113.6). Assigned rows never do.
  public var canCancelPending: Bool { canceller != nil }

  /// The listed entry of `key`, whatever the search; nil while the list is not loaded or once the member left it.
  public func entry(for key: MemberKey) -> MemberListEntry? {
    guard case let .loaded(entries) = state else { return nil }
    return entries.first { $0.key == key }
  }

  /// AC-DF-113.6 '등록 취소', after the trainer confirmed: the cancel is saved on the device and queued in the Outbox
  /// (`pendingMembers/{id}` → `status: 'cancelled'`), and the member leaves the list now. An assigned member is never
  /// cancelled here.
  public func cancelPending(_ key: MemberKey) async {
    guard case let .pending(id) = key, let canceller else { return }
    cancelFailed = false
    do {
      try await canceller.cancel(pendingMemberId: id)
    } catch {
      cancelFailed = true
      return
    }
    cancelledHere.insert(id)
    publish()
  }

  public func dismissCancelFailure() {
    cancelFailed = false
  }

  deinit {
    tasks.forEach { $0.cancel() }
    consentTasks.values.forEach { $0.cancel() }
  }

  /// Subscribes unless a subscription is running. After a failure it starts again from `.loading`.
  public func start() {
    guard tasks.isEmpty else { return }
    generation += 1
    let run = generation
    if case .failed = state { state = .loading }
    assigned = nil
    serverPending = nil
    devicePending = DevicePendingMembers()
    let assignedStream = directory.observeAssignedMembers()
    let pendingStream = directory.observePendingMembers()
    let deviceStream = localPending.observeLocalPendingMembers()
    tasks = [
      Task { [weak self] in
        do {
          for try await members in assignedStream {
            guard let self, self.generation == run else { return }
            self.assigned = members
            self.publish()
          }
          self?.ended(run, error: nil)
        } catch {
          self?.ended(run, error: error)
        }
      },
      Task { [weak self] in
        do {
          for try await members in pendingStream {
            guard let self, self.generation == run else { return }
            self.serverPending = members
            self.publish()
          }
          self?.ended(run, error: nil)
        } catch {
          self?.ended(run, error: error)
        }
      },
      // The device list cannot fail; if it ends, its last value stays and the server lists go on.
      Task { [weak self] in
        for await members in deviceStream {
          guard let self, self.generation == run else { return }
          self.devicePending = members
          self.publish()
        }
      },
    ]
  }

  /// '다시 시도': drops the current subscription and subscribes again from `.loading`.
  public func retry() {
    stop()
    state = .loading
    start()
  }

  private func stop() {
    tasks.forEach { $0.cancel() }
    tasks = []
    generation += 1
  }

  /// Shows the joined list once both server lists have answered.
  private func publish() {
    guard let assigned, let serverPending else { return }
    let entries = MemberList.merge(
      assigned: assigned, pending: serverPending + devicePending.registered,
      cancelled: devicePending.cancelled.union(cancelledHere))
    state = entries.isEmpty ? .empty : .loaded(entries)
    followConsent(of: entries.map(\.key))
  }

  /// A server stream of the current run ended. An error fails the list; a stream that just finished ends the run too,
  /// keeping the last list, so the next `start()` subscribes again.
  private func ended(_ run: Int, error: Error?) {
    guard run == generation else { return }  // a stopped or replaced run
    stop()
    guard let error else { return }
    state = .failed((error as? MemberDirectoryError) ?? .unknown(code: (error as NSError).code))
    followConsent(of: [])
  }

  /// One consent subscription per listed member: new members get one, members that left lose theirs and their chip.
  private func followConsent(of keys: [MemberKey]) {
    let listed = Set(keys)
    for (key, task) in consentTasks where !listed.contains(key) {
      task.cancel()
      consentTasks[key] = nil
      chips[key] = nil
    }
    for key in keys where consentTasks[key] == nil {
      let stream = consent.observe(member: key)
      consentTasks[key] = Task { [weak self] in
        for await value in stream {
          // Cancelled and removed on this actor: a value still in flight never brings a removed chip back.
          guard let self, !Task.isCancelled else { return }
          self.chips[key] = value.chipState
        }
      }
    }
  }
}
