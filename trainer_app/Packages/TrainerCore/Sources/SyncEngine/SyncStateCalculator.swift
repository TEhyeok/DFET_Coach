import TrainerContracts
import TrainerDomain

/// The single `syncState` of one local entity from its Outbox items (AC-DF-015.6, PRD §6.0.3). Pure.
public enum SyncStateCalculator {
  public struct Item: Equatable, Sendable {
    public var state: OutboxItemState
    public var attempts: Int
    public var ack: OutboxAck?

    public init(state: OutboxItemState, attempts: Int = 0, ack: OutboxAck? = nil) {
      self.state = state
      self.attempts = attempts
      self.ack = ack
    }

    public init(_ item: OutboxItem) {
      self.init(state: item.state, attempts: item.attempts, ack: item.ack)
    }
  }

  /// Rules, first match wins:
  /// 1. a step the entity depends on failed (the member's pending-member create): `syncFailed`
  /// 2. the member's consent capture is not confirmed on the server, or an item waits for it: `awaitingConsent`
  /// 3. any item failed: `syncFailed`
  /// 4. every item acked, every write server-committed and every upload verified: `synced`
  /// 5. any item attempted, in flight or acked: `syncing`
  /// 6. otherwise (nothing attempted yet, or no items): `localSaved`. `synced` is never claimed without evidence.
  ///
  /// V1-04 §11 lists `failed` before `blocked`; here a missing consent wins (AC-DF-015.2, .6), and "offline" is not an
  /// input: an item waiting for the network after an attempt reads `syncing` (V1-04 v1.0.3).
  public static func state(consentConfirmed: Bool, upstreamFailed: Bool = false, items: [Item]) -> SyncState {
    if upstreamFailed {
      return .syncFailed
    }
    if !consentConfirmed || items.contains(where: { $0.state == .blocked(.awaitingConsent) }) {
      return .awaitingConsent
    }
    if items.contains(where: { $0.state == .failed }) {
      return .syncFailed
    }
    if !items.isEmpty, items.allSatisfy({ $0.state == .acked && ($0.ack?.isConfirmed ?? false) }) {
      return .synced
    }
    if items.contains(where: { $0.state == .inFlight || $0.state == .acked || $0.attempts > 0 }) {
      return .syncing
    }
    return .localSaved
  }
}
