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
  /// Held saves; each resumes with whether it fails.
  private var held: [CheckedContinuation<Bool, Never>] = []

  init(_ items: [OutboxItem] = [], failingLoads: Int = 0) {
    self.items = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    self.failingLoads = failingLoads
  }

  func loadAll() async throws -> [OutboxItem] {
    if failingLoads > 0 {
      failingLoads -= 1
      throw CocoaError(.fileReadNoPermission)  // e.g. NSFileProtectionComplete while locked
    }
    let snapshot = items.values.sorted { $0.sequence < $1.sequence }
    if holdingLoads {
      await withCheckedContinuation { heldLoads.append($0) }
    }
    return snapshot
  }

  private var holdingLoads = false
  private var heldLoads: [CheckedContinuation<Void, Never>] = []
  /// The next `count` loads fail (the store cannot be read, e.g. while locked).
  func failNextLoads(_ count: Int) { failingLoads = count }
  /// The next loads read the rows, then wait until `releaseLoads()`.
  func holdLoads() { holdingLoads = true }
  var heldLoadCount: Int { heldLoads.count }
  func releaseLoads() {
    holdingLoads = false
    let waiting = heldLoads
    heldLoads = []
    waiting.forEach { $0.resume() }
  }

  func insert(_ item: OutboxItem) async throws {
    try await write(item, insert: true)
  }

  func update(_ item: OutboxItem) async throws {
    try await write(item, insert: false)
  }

  private func write(_ item: OutboxItem, insert: Bool) async throws {
    if failSaves || failPredicate?(item) == true { throw CocoaError(.fileWriteNoPermission) }
    savedIds.append(item.id)
    if let holdPredicate, holdPredicate(item) {
      let fails = await withCheckedContinuation { held.append($0) }
      if fails { throw CocoaError(.fileWriteNoPermission) }
    }
    if insert || items[item.id] != nil { items[item.id] = item }  // an update never brings back a deleted row
  }

  func item(_ id: UUID) -> OutboxItem? { items[id] }
  func setFailSaves(_ fail: Bool) { failSaves = fail }
  func failSaves(where predicate: (@Sendable (OutboxItem) -> Bool)?) { failPredicate = predicate }
  /// Deletes rows behind the engine's back, as LocalStore retention does (AS-32).
  func remove(_ ids: [UUID]) { for id in ids { items[id] = nil } }
  func holdSaves(where predicate: @escaping @Sendable (OutboxItem) -> Bool) { holdPredicate = predicate }
  var heldCount: Int { held.count }

  /// Lets the held saves finish; with `failing`, they fail instead (later saves are not affected).
  func releaseSaves(failing: Bool = false) {
    holdPredicate = nil
    let waiting = held
    held = []
    waiting.forEach { $0.resume(returning: failing) }
  }
}
