import Foundation
import TrainerContracts
import TrainerDomain

/// The effective consent of a member (DF-111 MVP): the server state (`ConsentStateSource`, FirebaseData's
/// `memberConsentStates/{memberKey}` listener) combined with this device's in-person captures (`ConsentCaptureSource`,
/// LocalStore). Every screen guard and chip reads this, never `memberConsentStates` itself (AC-DF-111.7).
///
/// Per type of ①②③ (TC-111-06), the member's newest capture that selects the type decides together with the server:
///
/// | server       | newest capture of the type        | value             |
/// |--------------|-----------------------------------|-------------------|
/// | granted      | none, pending grant, failed grant | `granted`         |
/// | not granted  | none                              | `missing`         |
/// | not granted  | pending grant                     | `awaitingConsent` |
/// | not granted  | failed grant                      | `rejected`        |
/// | any          | pending withdraw                  | `missing`         |
///
/// Only the server refuses: a capture that failed with a transient code (`SyncEngine.transientErrorCodes`: it ran out
/// of attempts on an outage and `retryExhausted()` sends it again) still counts as pending, as the engine counts it.
/// A confirmed capture defers to the server, except while the server has not been heard from since the confirmation
/// (its listener update may arrive after the callable's reply): until then it counts as pending. ④⑤ are always
/// `.missing` in the MVP (`EffectiveConsent`).
public final class EffectiveConsentResolver: EffectiveConsentSource {
  private let server: any ConsentStateSource
  private let captures: any ConsentCaptureSource
  private let now: @Sendable () -> Date
  private let retryDelay: @Sendable (Int) -> TimeInterval

  /// `retryDelay(n)` is the wait before subscribing to the server again after its stream ended n times in a row
  /// without a reading (default `backoff`).
  public init(
    server: any ConsentStateSource, captures: any ConsentCaptureSource, now: @escaping @Sendable () -> Date = { Date() },
    retryDelay: @escaping @Sendable (Int) -> TimeInterval = EffectiveConsentResolver.backoff
  ) {
    self.server = server
    self.captures = captures
    self.now = now
    self.retryDelay = retryDelay
  }

  /// 1, 2, 4 … seconds, at most 60.
  public static let backoff: @Sendable (Int) -> TimeInterval = { failures in
    min(pow(2, Double(max(failures - 1, 0))), 60)
  }

  /// Pure resolution. `serverObservedAt` is when the server value was received (device clock); nil when it has not
  /// been received yet.
  public static func resolve(
    server: ConsentState?, captures: [ConsentCapture], serverObservedAt: Date? = nil
  ) -> EffectiveConsent {
    func value(_ type: ConsentType) -> EffectiveConsentValue {
      let serverGranted = server?.isGranted(type) == true
      let newest = captures
        .filter { capture in capture.selections.contains { $0.consentType == type } }
        .max { $0.capturedAt < $1.capturedAt }
      guard let capture = newest, let action = capture.selections.first(where: { $0.consentType == type })?.action
      else { return serverGranted ? .granted : .missing }
      switch effectiveState(capture, serverObservedAt: serverObservedAt) {
      case .pending:
        if action == .withdraw { return .missing }  // withdrawn on the device at once (DF-112)
        return serverGranted ? .granted : .awaitingConsent
      case .failed:
        if serverGranted { return .granted }
        return action == .grant ? .rejected : .missing
      case .confirmed:
        return serverGranted ? .granted : .missing
      }
    }
    return EffectiveConsent(required: value(.required), healthData: value(.healthData),
                            bodyImaging: value(.bodyImaging))
  }

  /// A failure the engine will send again, and a confirmation the server value has not caught up with yet, count as
  /// pending.
  private static func effectiveState(_ capture: ConsentCapture, serverObservedAt: Date?) -> ConsentCaptureState {
    switch capture.state {
    case .pending:
      return .pending
    case .failed:
      return SyncEngine.transientErrorCodes.contains(capture.lastErrorCode ?? "") ? .pending : .failed
    case .confirmed:
      guard let observed = serverObservedAt, let confirmed = capture.confirmedAt, observed >= confirmed else {
        return .pending
      }
      return .confirmed
    }
  }

  /// The member's effective consent once both sources have answered, then after every change (equal values are not
  /// repeated). The server stream ends after `.unavailable` when its listener fails: a pending member whose
  /// `pendingMembers` create has not reached the server yet (the read rule cannot prove ownership), or a transient
  /// error. That is not "no document": the last reading stays, and before any reading nothing counts as granted and a
  /// confirmed capture still waits. The server is subscribed again after the next change of the local captures (the
  /// capture's `recordConsent`, which comes after the create, is when the state is expected to change) and after
  /// `retryDelay`, so a member whose create is acked later, or an outage that ends, is read again without one.
  public func observe(member: MemberKey) -> AsyncStream<EffectiveConsent> {
    let server = server
    let captures = captures
    let now = now
    let retryDelay = retryDelay
    return AsyncStream { continuation in
      let task = Task {
        await Self.run(member: member, server: server, captures: captures, now: now, retryDelay: retryDelay,
                       output: continuation)
        continuation.finish()
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  private enum Event: Sendable {
    case server(ConsentStateReading, generation: Int)
    case serverEnded(generation: Int)
    case retryServer(generation: Int)
    case captures([ConsentCapture])
    case capturesEnded
  }

  private static func run(
    member: MemberKey, server: any ConsentStateSource, captures: any ConsentCaptureSource,
    now: @escaping @Sendable () -> Date, retryDelay: @escaping @Sendable (Int) -> TimeInterval,
    output: AsyncStream<EffectiveConsent>.Continuation
  ) async {
    let (events, post) = AsyncStream.makeStream(of: Event.self)
    var generation = 0
    var serverTask: Task<Void, Never>?
    var retryTask: Task<Void, Never>?
    func listenToServer() {
      generation += 1
      let current = generation
      serverTask?.cancel()
      retryTask?.cancel()
      serverTask = Task {
        for await reading in server.observe(member: member) { post.yield(.server(reading, generation: current)) }
        post.yield(.serverEnded(generation: current))
      }
    }
    func retryLater(after failures: Int) {
      let current = generation
      let delay = max(retryDelay(failures), 0)
      retryTask?.cancel()
      retryTask = Task {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        guard !Task.isCancelled else { return }
        post.yield(.retryServer(generation: current))
      }
    }
    let capturesTask = Task {
      for await list in captures.observeCaptures(member: member) { post.yield(.captures(list)) }
      post.yield(.capturesEnded)
    }
    defer {
      serverTask?.cancel()
      retryTask?.cancel()
      capturesTask.cancel()
      post.finish()
    }
    listenToServer()

    var serverState: ConsentState?
    /// When the last real reading (`absent` or `present`) arrived; nil before any.
    var serverObservedAt: Date?
    /// The server has given a reading or ended at least once, so a value can be shown.
    var serverAnswered = false
    var serverEnded = false
    /// Ends in a row without a reading.
    var serverFailures = 0
    var local: [ConsentCapture]?
    var last: EffectiveConsent?
    for await event in events {
      switch event {
      case let .server(reading, eventGeneration):
        guard eventGeneration == generation else { continue }
        switch reading {
        case .absent, .present:
          serverState = reading.state
          serverObservedAt = now()
          serverAnswered = true
          serverFailures = 0
        case .unavailable:
          continue  // not "no document": the last reading stays; the end of the stream follows
        }
      case let .serverEnded(eventGeneration):
        guard eventGeneration == generation else { continue }
        serverEnded = true
        serverAnswered = true
        serverFailures += 1
        retryLater(after: serverFailures)
      case let .retryServer(eventGeneration):
        guard eventGeneration == generation, serverEnded else { continue }
        serverEnded = false
        listenToServer()
        continue
      case let .captures(list):
        let changed = local != nil && local != list
        local = list
        if changed, serverEnded {
          serverEnded = false
          listenToServer()
        }
      case .capturesEnded:
        return
      }
      guard let local, serverAnswered else { continue }
      let value = resolve(server: serverState, captures: local, serverObservedAt: serverObservedAt)
      if value != last {
        last = value
        output.yield(value)
      }
    }
  }
}
