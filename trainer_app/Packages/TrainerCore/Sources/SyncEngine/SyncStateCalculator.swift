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
  /// 1. the member's consent capture is not confirmed on the server, or an item waits for it: `awaitingConsent`
  /// 2. any item failed: `syncFailed`
  /// 3. every item acked, every write server-committed and every upload verified: `synced`
  /// 4. any item attempted, in flight or acked: `syncing`
  /// 5. otherwise (nothing attempted yet, or no items): `localSaved`. `synced` is never claimed without evidence.
  public static func state(consentConfirmed: Bool, items: [Item]) -> SyncState {
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
