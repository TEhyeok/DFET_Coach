import Foundation
import SyncEngine

/// Manual clock for backoff tests (TC-DF015-04). Sleepers wake only when `advance(by:)` passes their deadline.
final class TestClock: SyncClock, @unchecked Sendable {
  private let lock = NSLock()
  private var current: Date
  private var sleepers: [UUID: (deadline: Date, continuation: CheckedContinuation<Void, Error>)] = [:]

  init(start: Date = Date(timeIntervalSince1970: 1_800_000_000)) {
    current = start
  }

  func now() -> Date {
    lock.withLock { current }
  }

  func sleep(until deadline: Date) async throws {
    let id = UUID()
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        let resumeNow: Bool = lock.withLock {
          if deadline <= current { return true }
          sleepers[id] = (deadline, continuation)
          return false
        }
        if resumeNow { continuation.resume() }
      }
    } onCancel: {
      let continuation = lock.withLock { sleepers.removeValue(forKey: id)?.continuation }
      continuation?.resume(throwing: CancellationError())
    }
  }

  func advance(by seconds: TimeInterval) {
    let due: [CheckedContinuation<Void, Error>] = lock.withLock {
      current = current.addingTimeInterval(seconds)
      let ids = sleepers.filter { $0.value.deadline <= current }.map(\.key)
      return ids.compactMap { sleepers.removeValue(forKey: $0)?.continuation }
    }
    due.forEach { $0.resume() }
  }
}
