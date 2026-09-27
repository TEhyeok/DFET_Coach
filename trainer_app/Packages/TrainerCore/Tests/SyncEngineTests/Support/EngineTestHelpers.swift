import Foundation
import SyncEngine
import TrainerDomain
import XCTest

func makeTestEngine(
  store: any OutboxStore = InMemoryOutboxStore(), remote: FakeRemote, clock: TestClock = TestClock(),
  policy: RetryPolicy = .standard, jitter: Double = 0
) -> SyncEngine {
  SyncEngine(
    store: store, writer: remote, uploader: remote, callable: remote, clock: clock, policy: policy,
    jitter: { jitter })
}

/// Polls `condition` on real time for up to `timeout` seconds.
func eventually(timeout: TimeInterval = 5, _ condition: () async -> Bool) async -> Bool {
  let deadline = Date().addingTimeInterval(timeout)
  while Date() < deadline {
    if await condition() { return true }
    try? await Task.sleep(nanoseconds: 5_000_000)
  }
  return await condition()
}

func firstValue<T: Sendable>(of stream: AsyncStream<T>) async -> T? {
  for await value in stream { return value }
  return nil
}

/// `waitUntilIdle()` with a deadline, so a scheduling bug fails the test instead of hanging the suite. The wait runs
/// in an unstructured task (it cannot be cancelled), and this polls for it.
func idle(_ engine: SyncEngine, timeout: Double = 5, file: StaticString = #filePath, line: UInt = #line) async {
  let flag = IdleFlag()
  Task {
    await engine.waitUntilIdle()
    flag.set()
  }
  let deadline = Date().addingTimeInterval(timeout)
  while !flag.isSet, Date() < deadline {
    try? await Task.sleep(nanoseconds: 2_000_000)
  }
  if !flag.isSet { XCTFail("engine did not become idle within \(timeout) s", file: file, line: line) }
}

final class IdleFlag: @unchecked Sendable {
  private let lock = NSLock()
  private var value = false
  var isSet: Bool { lock.withLock { value } }
  func set() { lock.withLock { value = true } }
}
