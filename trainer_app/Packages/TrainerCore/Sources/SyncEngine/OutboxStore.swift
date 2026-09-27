import Foundation
import TrainerDomain

/// Persistence of Outbox items. The app's implementation maps to the LocalStore `OutboxItem` model (DF-014).
///
/// `insert` stores a new row. `update` replaces an existing row and must do nothing when the row is gone: LocalStore
/// retention (AS-32) may delete a row while the engine's save of it is already running, and that save must not bring
/// the row back.
public protocol OutboxStore: Sendable {
  func loadAll() async throws -> [OutboxItem]
  func insert(_ item: OutboxItem) async throws
  func update(_ item: OutboxItem) async throws
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

  public func insert(_ item: OutboxItem) {
    items[item.id] = item
  }

  public func update(_ item: OutboxItem) {
    guard items[item.id] != nil else { return }
    items[item.id] = item
  }

  public func item(_ id: UUID) -> OutboxItem? {
    items[id]
  }

  /// Deletes rows behind the engine's back, as LocalStore retention does.
  public func remove(_ ids: [UUID]) {
    for id in ids { items[id] = nil }
  }
}
