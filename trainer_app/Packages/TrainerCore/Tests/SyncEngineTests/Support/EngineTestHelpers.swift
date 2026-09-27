import Foundation
import SyncEngine
import TrainerDomain

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
