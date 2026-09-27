import FirebaseFirestore
import Foundation
import XCTest
@testable import FirebaseData

/// DF-018 (cross-review): logout removes every listener and ends the stream each one feeds, so a screen kept after a
/// failed logout sees its subscription end (and offers '다시 시도') instead of waiting forever.
final class FirestoreListenerRegistryTests: XCTestCase {
  private final class FakeListener: NSObject, ListenerRegistration, @unchecked Sendable {
    private let lock = NSLock()
    private var _removals = 0
    var removals: Int { lock.withLock { _removals } }
    func remove() { lock.withLock { _removals += 1 } }
  }

  private final class Ended: @unchecked Sendable {
    private let lock = NSLock()
    private var _names: [String] = []
    var names: [String] { lock.withLock { _names } }
    func add(_ name: String) { lock.withLock { _names.append(name) } }
  }

  func testRemoveAllRemovesEveryListenerAndEndsItsStream() {
    let registry = FirestoreListenerRegistry()
    let ended = Ended()
    let closed = FakeListener()
    let open = FakeListener()
    let token = registry.add(closed) { ended.add("closed") }
    _ = registry.add(open) { ended.add("open") }

    registry.remove(token)  // its stream ended by itself: nothing to end
    XCTAssertEqual(closed.removals, 1)
    XCTAssertEqual(ended.names, [])

    registry.removeAll()
    XCTAssertEqual(open.removals, 1)
    XCTAssertEqual(ended.names, ["open"])
    XCTAssertEqual(registry.count, 0)
    registry.removeAll()
    XCTAssertEqual(ended.names, ["open"], "a listener is ended once")
  }
}
