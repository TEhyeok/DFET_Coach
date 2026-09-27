import Foundation
import TrainerDomain

/// Scripted remote for SyncEngine tests: records every call in order, keeps created documents, fails on demand and
/// can hold a call until the test releases it.
final class FakeRemote: RemoteWriter, BinaryUploader, CallableClient, @unchecked Sendable {
  struct Call: Equatable {
    let kind: String  // "create", "update", "upload", "call"
    let target: String
  }

  private let lock = NSLock()
  private var _calls: [Call] = []
  private var _documents: Set<String> = []
  private var _createWrites = 0
  private var _failures: [String: [RemoteError]] = [:]
  private var _holds: [String: [CheckedContinuation<Void, Never>]] = [:]
  private var _heldTargets: Set<String> = []
  private var _concurrent = 0
  private var _maxConcurrent = 0
  private var _unverifiedUploads: Set<String> = []
  private let clock: (any SyncEngineTestClock)?
  private var _callTimes: [Date] = []

  init(clock: (any SyncEngineTestClock)? = nil) {
    self.clock = clock
  }

  var calls: [Call] { lock.withLock { _calls } }
  var callTimes: [Date] { lock.withLock { _callTimes } }
  var createWrites: Int { lock.withLock { _createWrites } }
  var maxConcurrent: Int { lock.withLock { _maxConcurrent } }

  func calls(to target: String) -> [Call] { calls.filter { $0.target == target } }

  /// The next calls to `target` throw these errors, in order.
  func fail(_ target: String, with errors: [RemoteError]) {
    lock.withLock { _failures[target, default: []].append(contentsOf: errors) }
  }

  func seedDocument(_ path: String) {
    lock.withLock { _ = _documents.insert(path) }
  }

  func hasDocument(_ path: String) -> Bool {
    lock.withLock { _documents.contains(path) }
  }

  func markUploadUnverified(_ path: String) {
    lock.withLock { _ = _unverifiedUploads.insert(path) }
  }

  /// Calls to `target` wait until `release(_:)`.
  func hold(_ target: String) {
    lock.withLock { _ = _heldTargets.insert(target) }
  }

  func release(_ target: String) {
    let waiting: [CheckedContinuation<Void, Never>] = lock.withLock {
      _heldTargets.remove(target)
      return _holds.removeValue(forKey: target) ?? []
    }
    waiting.forEach { $0.resume() }
  }

  func isWaiting(on target: String) -> Bool {
    lock.withLock { !(_holds[target] ?? []).isEmpty }
  }

  private func enter(_ kind: String, _ target: String) async throws {
    let error: RemoteError? = lock.withLock {
      _calls.append(Call(kind: kind, target: target))
      if let clock { _callTimes.append(clock.currentDate) }
      _concurrent += 1
      _maxConcurrent = max(_maxConcurrent, _concurrent)
      if var queue = _failures[target], !queue.isEmpty {
        let first = queue.removeFirst()
        _failures[target] = queue
        return first
      }
      return nil
    }
    let held = lock.withLock { _heldTargets.contains(target) }
    if held {
      await withCheckedContinuation { continuation in
        let stillHeld: Bool = lock.withLock {
          guard _heldTargets.contains(target) else { return false }
          _holds[target, default: []].append(continuation)
          return true
        }
        if !stillHeld { continuation.resume() }
      }
    }
    lock.withLock { _concurrent -= 1 }
    if let error { throw error }
  }

  func createIfAbsent(path: String, fields: JSONValue) async throws -> WriteAck {
    try await enter("create", path)
    lock.withLock {
      if !_documents.contains(path) {
        _documents.insert(path)
        _createWrites += 1
      }
    }
    return WriteAck(serverCommitted: true)
  }

  func update(path: String, fields: JSONValue) async throws -> WriteAck {
    try await enter("update", path)
    return WriteAck(serverCommitted: true)
  }

  func upload(localURL: URL, path: String, contentType: String, sha256: String) async throws -> UploadReceipt {
    try await enter("upload", path)
    let verified = lock.withLock { !_unverifiedUploads.contains(path) }
    return UploadReceipt(path: path, size: 3, sha256: sha256, verified: verified)
  }

  func call<T: Decodable & Sendable>(_ name: String, _ payload: JSONValue) async throws -> T {
    try await enter("call", name)
    return try JSONDecoder().decode(T.self, from: Data("{}".utf8))
  }
}

/// Lets `FakeRemote` stamp call times without depending on `TestClock` directly.
protocol SyncEngineTestClock: Sendable {
  var currentDate: Date { get }
}

extension TestClock: SyncEngineTestClock {
  var currentDate: Date { now() }
}
