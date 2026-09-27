import SyncEngine
import TrainerContracts
import TrainerDomain
import XCTest

/// TC-DF015-06: one `syncState` per entity from its items (AC-DF-015.6, PRD §6.0.3).
final class SyncStateCalculatorTests: XCTestCase {
  typealias Item = SyncStateCalculator.Item

  private let committed = OutboxAck.write(WriteAck(serverCommitted: true))
  private let uncommitted = OutboxAck.write(WriteAck(serverCommitted: false))
  private let verified = OutboxAck.upload(UploadReceipt(path: "p", size: 1, sha256: "s", verified: true))
  private let unverified = OutboxAck.upload(UploadReceipt(path: "p", size: 1, sha256: "s", verified: false))

  func testTable() {
    let cases: [(String, Bool, [Item], SyncState)] = [
      ("consent unconfirmed", false, [Item(state: .queued)], .awaitingConsent),
      ("item blocked on consent", true, [Item(state: .blocked(.awaitingConsent))], .awaitingConsent),
      ("consent unconfirmed beats a failure", false, [Item(state: .failed, attempts: 1)], .awaitingConsent),
      ("failed next to acked", true, [Item(state: .acked, attempts: 1, ack: committed), Item(state: .failed, attempts: 1)], .syncFailed),
      ("failed next to in flight", true, [Item(state: .inFlight, attempts: 1), Item(state: .failed, attempts: 5)], .syncFailed),
      ("all acked and confirmed", true, [Item(state: .acked, attempts: 1, ack: committed), Item(state: .acked, attempts: 2, ack: verified), Item(state: .acked, attempts: 1, ack: .call)], .synced),
      ("acked but not server-committed", true, [Item(state: .acked, attempts: 1, ack: uncommitted)], .syncing),
      ("acked but upload unverified", true, [Item(state: .acked, attempts: 1, ack: committed), Item(state: .acked, attempts: 1, ack: unverified)], .syncing),
      ("in flight", true, [Item(state: .inFlight, attempts: 1)], .syncing),
      ("queued after a failed attempt", true, [Item(state: .queued, attempts: 1)], .syncing),
      ("acked then untried", true, [Item(state: .acked, attempts: 1, ack: committed), Item(state: .queued)], .syncing),
      ("nothing tried yet", true, [Item(state: .queued), Item(state: .queued)], .localSaved),
      ("no items", true, [], .localSaved),
    ]
    for (name, consent, items, expected) in cases {
      XCTAssertEqual(SyncStateCalculator.state(consentConfirmed: consent, items: items), expected, name)
    }
  }
}
