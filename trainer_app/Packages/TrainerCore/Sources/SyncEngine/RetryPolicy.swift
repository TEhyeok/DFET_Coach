import Foundation
import TrainerDomain

/// Retry rules of the SyncEngine (DF-015 AC-DF-015.4, V1-04 §10.4). Pure; the engine supplies the jitter.
///
/// The values are hypotheses (ASM-P0-16): five consecutive failures, a 15-minute cap, ±20% jitter.
public struct RetryPolicy: Equatable, Sendable {
  /// What the engine does with a failed attempt.
  public enum Disposition: Equatable, Sendable {
    /// Mark the item failed now and never retry automatically (rule rejections and bad requests).
    case permanent
    /// Retry with backoff; failed after `maxAttempts` consecutive failures.
    case retry
    /// Wait for the next device unlock without counting the attempt (ASM-P0-29).
    case waitForUnlock
    /// Wait for the trainer's next session (`start()`) without counting the attempt.
    case waitForSession
  }

  public var maxAttempts: Int
  public var maxDelay: TimeInterval
  public var jitterFraction: Double

  public static let standard = RetryPolicy(maxAttempts: 5, maxDelay: 15 * 60, jitterFraction: 0.2)

  public init(maxAttempts: Int, maxDelay: TimeInterval, jitterFraction: Double) {
    self.maxAttempts = maxAttempts
    self.maxDelay = maxDelay
    self.jitterFraction = jitterFraction
  }

  /// Delay before the next attempt after `attempts` consecutive failures (1 = the first failure):
  /// `min(2^attempts s, maxDelay) × (1 + jitterFraction × jitterUnit)`, with `jitterUnit` clamped to -1...1.
  public func delay(afterAttempts attempts: Int, jitterUnit: Double) -> TimeInterval {
    let exponent = Double(max(attempts, 0))
    let base = min(pow(2, exponent), maxDelay)
    let unit = min(max(jitterUnit, -1), 1)
    return base * (1 + jitterFraction * unit)
  }

  /// Whether `attempts` consecutive failures reach the limit.
  public func isExhausted(attempts: Int) -> Bool {
    attempts >= maxAttempts
  }

  public static func disposition(for error: RemoteError) -> Disposition {
    switch error {
    case .permissionDenied, .failedPrecondition, .invalidArgument, .notFound, .alreadyExists:
      return .permanent
    case .unavailable, .deadlineExceeded, .unknown:
      return .retry
    case .protectedDataUnavailable:
      return .waitForUnlock
    case .signedOut, .unauthenticated:
      return .waitForSession
    }
  }
}
