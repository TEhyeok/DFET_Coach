import Foundation

/// Time source of the SyncEngine, injected so tests can check backoff without waiting (DF-015).
public protocol SyncClock: Sendable {
  func now() -> Date
  /// Returns at or after `deadline`; throws `CancellationError` when the task is cancelled.
  func sleep(until deadline: Date) async throws
}

public struct SystemSyncClock: SyncClock {
  public init() {}

  public func now() -> Date {
    Date()
  }

  public func sleep(until deadline: Date) async throws {
    let seconds = deadline.timeIntervalSinceNow
    if seconds > 0 {
      try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
  }
}
