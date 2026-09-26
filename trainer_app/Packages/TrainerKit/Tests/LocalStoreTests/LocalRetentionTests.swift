import Foundation
import SwiftData
import TrainerContracts
import TrainerDomain
import XCTest
@testable import LocalStore

/// TC-DF014-04 (AC-DF-014.4, NFR-17, AS-32): purge boundaries at 7 days ± 1 minute and the cascade that destroys an
/// unconfirmed consent capture with the member's `awaitingConsent` drafts.
@MainActor
final class LocalRetentionTests: XCTestCase {
  private let minute: TimeInterval = 60
  private let hour: TimeInterval = 3600
  private var temp: TemporaryDirectory?
  private var context: ModelContext!
  private var container: ModelContainer?
  private var store: LocalBinaryStore!

  override func setUpWithError() throws {
    try super.setUpWithError()
    let temp = try TemporaryDirectory()
    self.temp = temp
    let location = LocalStoreLocation(trainerUid: Synthetic.trainerA, applicationSupportURL: temp.url)
    let container = try LocalStoreContainer.make(inMemory: true)
    self.container = container
    context = ModelContext(container)
    store = LocalBinaryStore(location: location)
  }

  override func tearDown() {
    temp?.remove()
    temp = nil
    context = nil
    container = nil
    store = nil
    super.tearDown()
  }

  private var retention: LocalRetention {
    LocalRetention(context: context, binaryStore: store, trainerUid: Synthetic.trainerA)
  }

  func test_TC_DF014_04_AC_DF_014_4_windowIsSevenDays() {
    XCTAssertEqual(LocalRetention.window, 7 * 24 * 60 * 60)
  }

  func test_TC_DF014_04_AC_DF_014_4_verifiedBinaryOriginalIsRemovedAfterSevenDaysAndMetadataKept() throws {
    let now = Synthetic.now
    let old = try insertBinary(kind: .ink, verifiedAt: now - LocalRetention.window - minute)
    let young = try insertBinary(kind: .ink, verifiedAt: now - (6 * 24 * hour + 23 * hour))
    let unverified = try insertBinary(kind: .posture, verifiedAt: nil)
    try context.save()

    let report = try retention.purge(now: now)

    XCTAssertEqual(report.purgedBinaryIds, [old.id])
    XCTAssertFalse(store.fileExists(relativePath: old.relativePath), "7 days + 1 minute: original removed")
    XCTAssertTrue(store.fileExists(relativePath: young.relativePath), "6 days 23 hours: kept")
    XCTAssertTrue(store.fileExists(relativePath: unverified.relativePath), "never verified: kept")
    let remaining = try context.fetchOwned(LocalBinary.self, by: Synthetic.trainerA).map(\.id)
    XCTAssertEqual(Set(remaining), [old.id, young.id, unverified.id], "metadata stays for re-download")

    // A second run finds nothing more to do.
    XCTAssertTrue(try retention.purge(now: now).isEmpty)
  }

  func test_TC_DF014_04_AC_DF_014_4_exactlySevenDaysIsKept() throws {
    let now = Synthetic.now
    let edge = try insertBinary(kind: .ink, verifiedAt: now - LocalRetention.window)
    try insertCapture(id: "capture-edge", member: Synthetic.memberA, capturedAt: now - LocalRetention.window)
    try context.save()

    let report = try retention.purge(now: now)

    XCTAssertTrue(report.isEmpty)
    XCTAssertTrue(store.fileExists(relativePath: edge.relativePath))
    XCTAssertEqual(try context.fetchOwned(LocalConsentCapture.self, by: Synthetic.trainerA).count, 1)
  }

  func test_TC_DF014_04_AC_DF_014_4_unconfirmedCaptureOlderThanSevenDaysCascadesToAwaitingConsentDrafts() throws {
    let now = Synthetic.now
    let member = Synthetic.memberA
    let (capture, signature) = try insertCapture(id: "capture-old", member: member, capturedAt: now - LocalRetention.window - minute)
    let consentItem = insertOutbox(entityRef: capture.entityRef, member: member, stage: .consent, kind: .callConsent, state: .queued)

    // An awaitingConsent SOAP draft with ink, its blocked document and upload items.
    let ink = try insertBinary(kind: .ink, verifiedAt: nil)
    let soap = LocalSoapDraft(noteId: "noteAwaiting", trainerUid: Synthetic.trainerA, memberKey: member, sessionDate: now,
                              inkBinaryId: ink.id, syncState: .awaitingConsent, createdLocallyAt: now - 8 * 24 * hour)
    context.insert(soap)
    let soapDoc = insertOutbox(entityRef: soap.entityRef, member: member, stage: .document, kind: .createDocument, state: .blocked)
    let soapUpload = insertOutbox(entityRef: soap.entityRef, member: member, stage: .upload, kind: .uploadBinary,
                                  state: .blocked, binaryId: ink.id)

    // An awaitingConsent measurement found only through its blocked Outbox item (syncState cache not yet written).
    let photo = try insertBinary(kind: .bodycompReport, verifiedAt: nil)
    let measurement = LocalMeasurementDraft(recordId: "recordAwaiting", trainerUid: Synthetic.trainerA, memberKey: member,
                                            kind: .bodyComposition, payloadJSON: Synthetic.json,
                                            reportPhotoBinaryId: photo.id, createdLocallyAt: now - 8 * 24 * hour)
    context.insert(measurement)
    let measurementDoc = insertOutbox(entityRef: measurement.entityRef, member: member, stage: .document,
                                      kind: .createDocument, state: .blocked)

    // Survivors: the same member's already-synced draft, another member's awaiting draft, another trainer's capture.
    let synced = LocalSoapDraft(noteId: "noteSynced", trainerUid: Synthetic.trainerA, memberKey: member, sessionDate: now,
                                syncState: .synced, createdLocallyAt: now - 9 * 24 * hour)
    context.insert(synced)
    let otherMember = LocalSoapDraft(noteId: "noteOtherMember", trainerUid: Synthetic.trainerA, memberKey: Synthetic.memberB,
                                     sessionDate: now, syncState: .awaitingConsent, createdLocallyAt: now - 8 * 24 * hour)
    context.insert(otherMember)
    let otherTrainer = LocalConsentCapture(captureId: "capture-other-trainer", trainerUid: Synthetic.trainerB, memberKey: member,
                                           selectionsJSON: Synthetic.json, signatureBinaryId: UUID(),
                                           capturedAt: now - 30 * 24 * hour)
    context.insert(otherTrainer)
    try context.save()

    let report = try retention.purge(now: now)

    XCTAssertEqual(report.destroyedCaptureIds, ["capture-old"])
    XCTAssertEqual(report.destroyedSoapNoteIds, ["noteAwaiting"])
    XCTAssertEqual(report.destroyedMeasurementRecordIds, ["recordAwaiting"])
    XCTAssertEqual(Set(report.destroyedOutboxItemIds), [consentItem.id, soapDoc.id, soapUpload.id, measurementDoc.id])
    XCTAssertEqual(Set(report.destroyedBinaryIds), [signature.id, ink.id, photo.id])
    XCTAssertTrue(report.purgedBinaryIds.isEmpty)

    for path in [signature.relativePath, ink.relativePath, photo.relativePath] {
      XCTAssertFalse(store.fileExists(relativePath: path), path)
    }
    XCTAssertTrue(try context.fetchOwned(LocalConsentCapture.self, by: Synthetic.trainerA).isEmpty)
    XCTAssertTrue(try context.fetchOwned(OutboxItem.self, by: Synthetic.trainerA).isEmpty)
    XCTAssertTrue(try context.fetchOwned(LocalBinary.self, by: Synthetic.trainerA).isEmpty)
    XCTAssertTrue(try context.fetchOwned(LocalMeasurementDraft.self, by: Synthetic.trainerA).isEmpty)
    XCTAssertEqual(Set(try context.fetchOwned(LocalSoapDraft.self, by: Synthetic.trainerA).map(\.noteId)),
                   ["noteSynced", "noteOtherMember"])
    XCTAssertEqual(try context.fetchOwned(LocalConsentCapture.self, by: Synthetic.trainerB).count, 1,
                   "another trainer's rows are outside this purge")
  }

  func test_TC_DF014_04_AC_DF_014_4_youngOrConfirmedCapturesAreKept() throws {
    let now = Synthetic.now
    let (young, youngSignature) = try insertCapture(id: "capture-young", member: Synthetic.memberA,
                                                capturedAt: now - (6 * 24 * hour + 23 * hour))
    let (confirmed, _) = try insertCapture(id: "capture-confirmed", member: Synthetic.memberB,
                                       capturedAt: now - 30 * 24 * hour)
    confirmed.serverConfirmedAt = now - 29 * 24 * hour
    confirmed.captureState = LocalConsentCaptureState.confirmed.rawValue
    context.insert(LocalSoapDraft(noteId: "noteYoung", trainerUid: Synthetic.trainerA, memberKey: Synthetic.memberA,
                                  sessionDate: now, syncState: .awaitingConsent, createdLocallyAt: now))
    try context.save()

    let report = try retention.purge(now: now)

    XCTAssertTrue(report.isEmpty)
    XCTAssertEqual(Set(try context.fetchOwned(LocalConsentCapture.self, by: Synthetic.trainerA).map(\.captureId)),
                   [young.captureId, confirmed.captureId])
    XCTAssertEqual(try context.fetchOwned(LocalSoapDraft.self, by: Synthetic.trainerA).count, 1)
    XCTAssertTrue(store.fileExists(relativePath: youngSignature.relativePath))
  }

  func test_TC_DF014_04_expiredCaptureKeepsDraftsThatWaitOnANewerPendingCapture() throws {
    let now = Synthetic.now
    let member = Synthetic.memberA
    try insertCapture(id: "capture-expired", member: member, capturedAt: now - 8 * 24 * hour)
    try insertCapture(id: "capture-retaken", member: member, capturedAt: now - hour)
    context.insert(LocalSoapDraft(noteId: "noteWaiting", trainerUid: Synthetic.trainerA, memberKey: member, sessionDate: now,
                                  syncState: .awaitingConsent, createdLocallyAt: now - 8 * 24 * hour))
    try context.save()

    let report = try retention.purge(now: now)

    XCTAssertEqual(report.destroyedCaptureIds, ["capture-expired"])
    XCTAssertTrue(report.destroyedSoapNoteIds.isEmpty)
    XCTAssertEqual(try context.fetchOwned(LocalSoapDraft.self, by: Synthetic.trainerA).count, 1)
    XCTAssertEqual(try context.fetchOwned(LocalConsentCapture.self, by: Synthetic.trainerA).map(\.captureId), ["capture-retaken"])
  }

  func test_TC_DF014_04_captureExpiresAtIsCapturedAtPlusWindow() {
    let capture = LocalConsentCapture(captureId: "c", trainerUid: Synthetic.trainerA, memberKey: Synthetic.memberA,
                                      selectionsJSON: Synthetic.json, signatureBinaryId: UUID(), capturedAt: Synthetic.now)
    XCTAssertEqual(capture.expiresAt, Synthetic.now + LocalRetention.window)
    XCTAssertEqual(capture.captureState, "pending")
  }

  // MARK: - Helpers

  @discardableResult
  private func insertBinary(kind: LocalBinaryKind, verifiedAt: Date?) throws -> LocalBinary {
    let file = try store.write(data: Data(UUID().uuidString.utf8), ext: kind == .ink ? "png" : "jpg", kind: kind)
    let binary = LocalBinary(file: file, trainerUid: Synthetic.trainerA)
    if let verifiedAt { binary.markVerified(at: verifiedAt) }
    context.insert(binary)
    return binary
  }

  @discardableResult
  private func insertCapture(id: String, member: MemberKey, capturedAt: Date) throws -> (LocalConsentCapture, LocalBinary) {
    let signature = try insertBinary(kind: .signature, verifiedAt: nil)
    let capture = LocalConsentCapture(captureId: id, trainerUid: Synthetic.trainerA, memberKey: member,
                                      selectionsJSON: Synthetic.json, signatureBinaryId: signature.id, capturedAt: capturedAt)
    context.insert(capture)
    return (capture, signature)
  }

  @discardableResult
  private func insertOutbox(entityRef: String, member: MemberKey, stage: LocalOutboxStage, kind: LocalOutboxKind,
                            state: LocalOutboxState, binaryId: UUID? = nil) -> OutboxItem {
    let item = OutboxItem(trainerUid: Synthetic.trainerA, memberKey: member, entityRef: entityRef, sequence: 1,
                          stage: stage, kind: kind, targetPath: "target", binaryId: binaryId, state: state,
                          blockedReason: state == .blocked ? .awaitingConsent : nil, createdAt: Synthetic.now)
    context.insert(item)
    return item
  }
}
