import Foundation
import SyncEngine
import TrainerDomain

/// An `OutboxStore` for failure tests: can hold matching saves until released, fail saves, or fail the first loads.
actor ControllableStore: OutboxStore {
  private var items: [UUID: OutboxItem]
  private var failingLoads: Int
  private var failSaves = false
  private var failPredicate: (@Sendable (OutboxItem) -> Bool)?
  private var holdPredicate: (@Sendable (OutboxItem) -> Bool)?
  private(set) var savedIds: [UUID] = []
  private var held: [CheckedContinuation<Void, Never>] = []

  init(_ items: [OutboxItem] = [], failingLoads: Int = 0) {
    self.items = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    self.failingLoads = failingLoads
  }

  func loadAll() throws -> [OutboxItem] {
    if failingLoads > 0 {
      failingLoads -= 1
      throw CocoaError(.fileReadNoPermission)  // e.g. NSFileProtectionComplete while locked
    }
    return items.values.sorted { $0.sequence < $1.sequence }
  }

  func save(_ item: OutboxItem) async throws {
    if failSaves || failPredicate?(item) == true { throw CocoaError(.fileWriteNoPermission) }
    savedIds.append(item.id)
    if let holdPredicate, holdPredicate(item) {
      await withCheckedContinuation { held.append($0) }
    }
    items[item.id] = item
  }

  func item(_ id: UUID) -> OutboxItem? { items[id] }
  func setFailSaves(_ fail: Bool) { failSaves = fail }
  func failSaves(where predicate: (@Sendable (OutboxItem) -> Bool)?) { failPredicate = predicate }
  /// Deletes rows behind the engine's back, as LocalStore retention does (AS-32).
  func remove(_ ids: [UUID]) { for id in ids { items[id] = nil } }
  func holdSaves(where predicate: @escaping @Sendable (OutboxItem) -> Bool) { holdPredicate = predicate }
  var heldCount: Int { held.count }

  func releaseSaves() {
    holdPredicate = nil
    let waiting = held
    held = []
    waiting.forEach { $0.resume() }
  }
}
