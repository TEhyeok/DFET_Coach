import Foundation
import XCTest
@testable import TrainerDomain

/// DF-018 (AC-DF-018.3): TR-15 describes an item by deck keys only, never a member name or a path.
final class SyncQueueLabelsTests: XCTestCase {
  private func item(_ ref: String, code: String?) -> OutboxItem {
    OutboxItem(memberKey: .uid("syn-0001"), entityRef: LocalEntityRef(rawValue: ref), sequence: 1, stage: .document,
               kind: .createDocument, target: .document(path: "x/y"), state: .failed, lastErrorCode: code,
               createdAt: Date(timeIntervalSince1970: 0))
  }

  func testKindFollowsTheEntityPrefix() {
    let cases = [
      ("soap:n", "tr15.queue.kind.soap"), ("bodyComposition:r", "tr15.queue.kind.bodyComposition"),
      ("circumference:m", "tr15.queue.kind.circumference"), ("posture:a", "tr15.queue.kind.posture"),
      ("pendingMember:p", "tr15.queue.kind.pendingMember"), ("consent:c", "tr15.queue.kind.consent"),
      ("somethingNew:z", "tr15.queue.kind.other"), ("", "tr15.queue.kind.other"),
    ]
    for (ref, key) in cases { XCTAssertEqual(SyncQueueLabels.kindKey(item(ref, code: nil)), key, ref) }
  }

  func testReasonFollowsTheErrorCode() {
    let cases: [(String?, String)] = [
      ("permission-denied", "sync.reason.ruleDenied"), ("failed-precondition", "sync.reason.ruleDenied"),
      ("consent-rejected", "sync.reason.consentRejected"), ("upload-unverified", "sync.reason.uploadMismatch"),
      ("upload-mismatch", "sync.reason.uploadMismatch"), ("file-too-large", "sync.reason.fileTooLarge"),
      ("unavailable", "sync.reason.retryLimit"), ("deadline-exceeded", "sync.reason.retryLimit"),
      ("write-uncommitted", "sync.reason.retryLimit"), ("malformed-item", "common.devDefect"),
      ("local-unreadable", "common.devDefect"), (nil, "common.devDefect"),
    ]
    for (code, key) in cases { XCTAssertEqual(SyncQueueLabels.reasonKey(item("soap:n", code: code)), key) }
  }
}
