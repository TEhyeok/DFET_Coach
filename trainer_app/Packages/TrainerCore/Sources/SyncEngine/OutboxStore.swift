import Foundation
import TrainerDomain

/// Persistence of Outbox items. The app's implementation maps to the LocalStore `OutboxItem` model (DF-014);
/// SyncEngine only needs load and save.
public protocol OutboxStore: Sendable {
  func loadAll() async throws -> [OutboxItem]
  func save(_ item: OutboxItem) async throws
}

/// In-memory store for tests and previews. Survives an engine restart when the same instance is reused.
public actor InMemoryOutboxStore: OutboxStore {
  private var items: [UUID: OutboxItem]

  public init(_ items: [OutboxItem] = []) {
    self.items = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
  }

  public func loadAll() -> [OutboxItem] {
    items.values.sorted { $0.sequence < $1.sequence }
  }

  public func save(_ item: OutboxItem) {
    items[item.id] = item
  }

  public func item(_ id: UUID) -> OutboxItem? {
    items[id]
  }
}
