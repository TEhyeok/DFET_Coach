import Foundation

/// `EffectiveConsentSource` from the server state only (`EffectiveConsent(server:)`): granted or missing, never
/// `awaitingConsent`. It stands in for the DF-111 `EffectiveConsentResolver` until in-person consent captures exist
/// on the device (DF-110): with no local capture the resolver's answer is exactly this one.
public struct ServerEffectiveConsentSource: EffectiveConsentSource {
  private let states: any ConsentStateSource

  public init(states: any ConsentStateSource) {
    self.states = states
  }

  public func observe(member: MemberKey) -> AsyncStream<EffectiveConsent> {
    let upstream = states.observe(member: member)
    return AsyncStream { continuation in
      let task = Task {
        for await state in upstream {
          continuation.yield(EffectiveConsent(server: state))
        }
        continuation.finish()
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }
}

extension EffectiveConsent {
  /// The member's consent now: the first value `source` gives, or `.none` when it ends or has said nothing within
  /// `timeout`. A save gate that cannot learn the state refuses, as the rules would (R-14).
  public static func current(
    from source: any EffectiveConsentSource, member: MemberKey, timeout: Duration = .seconds(5)
  ) async -> EffectiveConsent {
    let stream = source.observe(member: member)
    return await withTaskGroup(of: EffectiveConsent?.self) { group in
      group.addTask {
        for await consent in stream { return consent }
        return EffectiveConsent.none
      }
      group.addTask {
        try? await Task.sleep(for: timeout)
        return nil
      }
      let first = await group.next() ?? nil
      group.cancelAll()
      return first ?? .none
    }
  }
}
