import Foundation
import SwiftData
import TrainerContracts
import TrainerDomain
import XCTest
@testable import LocalStore

/// TC-DF014-05 (AC-DF-014.5): state and kind attributes are stored only as English raw values.
@MainActor
final class LocalRawValueTests: XCTestCase {
  private static let englishIdentifier = try! NSRegularExpression(pattern: "^[A-Za-z][A-Za-z0-9]*$")

  private func isEnglishIdentifier(_ value: String) -> Bool {
    Self.englishIdentifier.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
  }

  func test_TC_DF014_05_AC_DF_014_5_everyLocalEnumRawValueIsAnEnglishIdentifier() {
    let rawValues: [String] =
      LocalSoapLockState.allCases.map(\.rawValue) + LocalMeasurementKind.allCases.map(\.rawValue)
      + LocalConsentCaptureState.allCases.map(\.rawValue) + LocalOutboxKind.allCases.map(\.rawValue)
      + LocalOutboxState.allCases.map(\.rawValue) + LocalOutboxBlockedReason.allCases.map(\.rawValue)
      + LocalBinaryKind.allCases.map(\.rawValue) + LocalQuickPhraseCategory.allCases.map(\.rawValue)
      + SyncState.allCases.map(\.rawValue)
    XCTAssertFalse(rawValues.isEmpty)
    for value in rawValues {
      XCTAssertTrue(isEnglishIdentifier(value), "non-English raw value: \(value)")
    }
  }

  func test_TC_DF014_05_AC_DF_014_5_allowedValuesMatchV1_05() {
    XCTAssertEqual(LocalSoapLockState.allCases.map(\.rawValue), ["editable", "pendingFinalize", "finalized"])
    XCTAssertEqual(LocalMeasurementKind.allCases.map(\.rawValue), ["bodyComposition", "circumference"])
    XCTAssertEqual(LocalConsentCaptureState.allCases.map(\.rawValue), ["pending", "confirmed", "failed"])
    XCTAssertEqual(LocalOutboxKind.allCases.map(\.rawValue), [
      "createDocument", "updateDocument", "deleteDocument", "uploadBinary", "deleteBinary", "recordBinaryPath",
      "finalize", "callConsent", "callFunction",
    ])
    XCTAssertEqual(LocalOutboxState.allCases.map(\.rawValue), ["queued", "inFlight", "acked", "failed", "blocked"])
    XCTAssertEqual(LocalOutboxBlockedReason.allCases.map(\.rawValue), ["awaitingConsent"])
    XCTAssertEqual(LocalOutboxStage.allCases.map(\.rawValue), [0, 1, 2, 3, 4, 5])
    XCTAssertEqual(LocalBinaryKind.allCases.map(\.rawValue), ["ink", "posture", "bodycompReport", "signature"])
    XCTAssertEqual(LocalQuickPhraseCategory.allCases.map(\.rawValue), ["S", "O", "A", "P"])
    XCTAssertEqual(SyncState.allCases.map(\.rawValue),
                   ["localSaved", "syncing", "synced", "syncFailed", "awaitingConsent"])
  }

  /// Every state/kind attribute of every model, written through the typed initialisers and read back from the store.
  func test_TC_DF014_05_AC_DF_014_5_storedStateAndKindAttributesAreEnglish() throws {
    let context = ModelContext(try LocalStoreContainer.make(inMemory: true))
    for (index, lock) in LocalSoapLockState.allCases.enumerated() {
      context.insert(LocalSoapDraft(noteId: "n\(index)", trainerUid: Synthetic.trainerA, memberKey: Synthetic.memberA,
                                    sessionDate: Synthetic.now, lockState: lock, painRegions: [.neck],
                                    syncState: SyncState.allCases[index], createdLocallyAt: Synthetic.now))
    }
    for (index, kind) in LocalMeasurementKind.allCases.enumerated() {
      context.insert(LocalMeasurementDraft(recordId: "r\(index)", trainerUid: Synthetic.trainerA, memberKey: Synthetic.memberA,
                                           kind: kind, payloadJSON: Synthetic.json, createdLocallyAt: Synthetic.now))
    }
    for (index, state) in LocalConsentCaptureState.allCases.enumerated() {
      context.insert(LocalConsentCapture(captureId: "c\(index)", trainerUid: Synthetic.trainerA, memberKey: Synthetic.memberA,
                                         selectionsJSON: Synthetic.json, signatureBinaryId: UUID(),
                                         capturedAt: Synthetic.now, captureState: state))
    }
    for (index, kind) in LocalOutboxKind.allCases.enumerated() {
      let state = LocalOutboxState.allCases[index % LocalOutboxState.allCases.count]
      context.insert(OutboxItem(trainerUid: Synthetic.trainerA, memberKey: Synthetic.memberA, entityRef: "soap:n\(index)",
                                sequence: Int64(index), stage: .document, kind: kind, targetPath: "t", state: state,
                                blockedReason: .awaitingConsent, createdAt: Synthetic.now))
    }
    for kind in LocalBinaryKind.allCases {
      context.insert(LocalBinary(id: UUID(), trainerUid: Synthetic.trainerA, kind: kind, relativePath: "Binaries/x",
                                 contentType: "image/png", byteSize: 1, sha256: "00"))
    }
    for (index, category) in LocalQuickPhraseCategory.allCases.enumerated() {
      context.insert(QuickPhrase(trainerUid: Synthetic.trainerA, text: "문구", category: category, isDefault: false, order: index))
    }
    try context.save()

    var stored: [String] = []
    for draft in try context.fetchOwned(LocalSoapDraft.self, by: Synthetic.trainerA) {
      stored += [draft.lockState, draft.syncState] + draft.painRegions
    }
    for draft in try context.fetchOwned(LocalMeasurementDraft.self, by: Synthetic.trainerA) {
      stored += [draft.kind, draft.syncState]
    }
    for capture in try context.fetchOwned(LocalConsentCapture.self, by: Synthetic.trainerA) {
      stored += [capture.captureState, capture.syncState]
    }
    for item in try context.fetchOwned(OutboxItem.self, by: Synthetic.trainerA) {
      stored += [item.kind, item.state] + (item.blockedReason.map { [$0] } ?? [])
    }
    stored += try context.fetchOwned(LocalBinary.self, by: Synthetic.trainerA).map(\.kind)
    stored += try context.fetchOwned(QuickPhrase.self, by: Synthetic.trainerA).map(\.category)

    XCTAssertEqual(stored.count, 3 * 3 + 2 * 2 + 3 * 2 + 9 * 2 + 1 + 4 + 4)
    for value in stored {
      XCTAssertTrue(isEnglishIdentifier(value), "stored non-English value: \(value)")
    }
  }

  /// Source search: no `case x = "<Hangul>"` raw value anywhere in the LocalStore target.
  func test_TC_DF014_05_AC_DF_014_5_localStoreSourcesDeclareNoHangulRawValues() throws {
    let sources = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("Sources/LocalStore", isDirectory: true)
    let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
    let rawValueWithHangul = try NSRegularExpression(pattern: #"case\s+`?\w+`?\s*=\s*"[^"]*[\x{AC00}-\x{D7A3}\x{3131}-\x{318E}]"#)
    var scanned = 0
    for case let url as URL in enumerator where url.pathExtension == "swift" {
      let text = try String(contentsOf: url, encoding: .utf8)
      scanned += 1
      let matches = rawValueWithHangul.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
      XCTAssertEqual(matches, 0, url.lastPathComponent)
    }
    XCTAssertGreaterThanOrEqual(scanned, 12, "the LocalStore sources were not found at \(sources.path)")
  }
}
