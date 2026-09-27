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
/// A confirmed capture defers to the server, except while the server has not been heard from since the confirmation
/// (its listener update may arrive after the callable's reply): until then it counts as pending. ④⑤ are always
/// `.missing` in the MVP (`EffectiveConsent`).
public final class EffectiveConsentResolver: EffectiveConsentSource {
  private let server: any ConsentStateSource
  private let captures: any ConsentCaptureSource
  private let now: @Sendable () -> Date

  public init(
    server: any ConsentStateSource, captures: any ConsentCaptureSource, now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.server = server
    self.captures = captures
    self.now = now
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

  /// A confirmation the server value has not caught up with yet counts as pending.
  private static func effectiveState(_ capture: ConsentCapture, serverObservedAt: Date?) -> ConsentCaptureState {
    guard capture.state == .confirmed else { return capture.state }
    guard let observed = serverObservedAt, let confirmed = capture.confirmedAt, observed >= confirmed else {
      return .pending
    }
    return .confirmed
  }

  /// The member's effective consent once both sources have answered, then after every change (equal values are not
  /// repeated). The server stream ends when its listener fails (for example a pending member whose document is not on
  /// the server yet); it is subscribed again after the next change of the local captures, which is when the server
  /// state is expected to change.
  public func observe(member: MemberKey) -> AsyncStream<EffectiveConsent> {
    let server = server
    let captures = captures
    let now = now
    return AsyncStream { continuation in
      let task = Task {
        await Self.run(member: member, server: server, captures: captures, now: now, output: continuation)
        continuation.finish()
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  private enum Event: Sendable {
    case server(ConsentState?, generation: Int)
    case serverEnded(generation: Int)
    case captures([ConsentCapture])
    case capturesEnded
  }

  private static func run(
    member: MemberKey, server: any ConsentStateSource, captures: any ConsentCaptureSource,
    now: @escaping @Sendable () -> Date, output: AsyncStream<EffectiveConsent>.Continuation
  ) async {
    let (events, post) = AsyncStream.makeStream(of: Event.self)
    var generation = 0
    var serverTask: Task<Void, Never>?
    func listenToServer() {
      generation += 1
      let current = generation
      serverTask?.cancel()
      serverTask = Task {
        for await state in server.observe(member: member) { post.yield(.server(state, generation: current)) }
        post.yield(.serverEnded(generation: current))
      }
    }
    let capturesTask = Task {
      for await list in captures.observeCaptures(member: member) { post.yield(.captures(list)) }
      post.yield(.capturesEnded)
    }
    defer {
      serverTask?.cancel()
      capturesTask.cancel()
      post.finish()
    }
    listenToServer()

    var serverState: ConsentState?
    var serverObservedAt: Date?
    var serverEnded = false
    var local: [ConsentCapture]?
    var last: EffectiveConsent?
    for await event in events {
      switch event {
      case let .server(state, eventGeneration):
        guard eventGeneration == generation else { continue }
        serverState = state
        serverObservedAt = now()
      case let .serverEnded(eventGeneration):
        guard eventGeneration == generation else { continue }
        serverEnded = true
        if serverObservedAt == nil { serverObservedAt = now() }  // never answered: no state, as the rules read it
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
      guard let local, serverObservedAt != nil else { continue }
      let value = resolve(server: serverState, captures: local, serverObservedAt: serverObservedAt)
      if value != last {
        last = value
        output.yield(value)
      }
    }
  }
}
