import Foundation
import SwiftData
import TrainerDomain
import XCTest
@testable import LocalStore

/// DF-018 (AC-DF-018.1, .2, ASM-P0-17): logout removes what the server has and keeps everything it does not.
/// Synthetic data only.
@MainActor
final class LocalPurgeSyncedTests: XCTestCase {
  private var temp: TemporaryDirectory?

  override func tearDown() {
    temp?.remove()
    temp = nil
    super.tearDown()
  }

  func test_AC_DF_018_1_syncedRowsAndFilesGoUnsyncedStay() throws {
    let temp = try TemporaryDirectory()
    self.temp = temp
    let location = LocalStoreLocation(trainerUid: Synthetic.trainerA, applicationSupportURL: temp.url)
    let context = ModelContext(try LocalStoreContainer.make(location: location))
    let binaries = LocalBinaryStore(location: location)
    let syncedInk = try binaries.write(data: Data("synced ink".utf8), ext: "drawing", kind: .ink)
    let waitingInk = try binaries.write(data: Data("waiting ink".utf8), ext: "drawing", kind: .ink)
    for (file, verified) in [(syncedInk, true), (waitingInk, false)] {
      context.insert(LocalBinary(
        id: file.id, trainerUid: Synthetic.trainerA, kind: .ink, relativePath: file.relativePath,
        contentType: file.contentType, byteSize: file.byteSize, sha256: file.sha256,
        verifiedAt: verified ? Synthetic.now : nil))
    }
    // A synced note (every item acked) and a note whose upload failed.
    context.insert(LocalSoapDraft(noteId: "synced", trainerUid: Synthetic.trainerA, memberKey: Synthetic.memberA,
                                  sessionDate: Synthetic.now, inkBinaryId: syncedInk.id, createdLocallyAt: Synthetic.now))
    context.insert(LocalSoapDraft(noteId: "waiting", trainerUid: Synthetic.trainerA, memberKey: Synthetic.memberA,
                                  sessionDate: Synthetic.now, inkBinaryId: waitingInk.id, createdLocallyAt: Synthetic.now))
    let ackedCreate = OutboxItem(trainerUid: Synthetic.trainerA, memberKey: Synthetic.memberA, entityRef: "soap:synced",
                                 sequence: 1, stage: .document, kind: .createDocument, targetPath: "soap_notes/synced",
                                 state: .acked, ackConfirmed: true, createdAt: Synthetic.now)
    let failedUpload = OutboxItem(trainerUid: Synthetic.trainerA, memberKey: Synthetic.memberA, entityRef: "soap:waiting",
                                  sequence: 2, stage: .upload, kind: .uploadBinary, targetPath: "soapInk/waiting/1.drawing",
                                  binaryId: waitingInk.id, state: .failed, lastErrorCode: "permission-denied",
                                  createdAt: Synthetic.now)
    let ackedUpload = OutboxItem(trainerUid: Synthetic.trainerA, memberKey: Synthetic.memberA, entityRef: "soap:synced",
                                 sequence: 2, stage: .upload, kind: .uploadBinary, targetPath: "soapInk/synced/1.drawing",
                                 binaryId: syncedInk.id, state: .acked, ackConfirmed: true, createdAt: Synthetic.now)
    context.insert(ackedCreate)
    context.insert(ackedUpload)
    context.insert(failedUpload)
    // A confirmed consent capture and one still waiting for the server.
    let confirmed = LocalConsentCapture(captureId: "confirmed", trainerUid: Synthetic.trainerA, memberKey: Synthetic.memberA,
                                        selectionsJSON: Synthetic.json, signatureBinaryId: UUID(), capturedAt: Synthetic.now)
    confirmed.serverConfirmedAt = Synthetic.now
    context.insert(confirmed)
    context.insert(LocalConsentCapture(captureId: "pending", trainerUid: Synthetic.trainerA, memberKey: Synthetic.memberA,
                                       selectionsJSON: Synthetic.json, signatureBinaryId: UUID(), capturedAt: Synthetic.now))
    context.insert(StationProfile(id: "default-v1", trainerUid: Synthetic.trainerA, name: "tr07.station.default",
                                  cameraHeightCm: 100, cameraDistanceM: 3, protocolVersion: "posture-v1",
                                  createdLocallyAt: Synthetic.now))
    // Another trainer's synced row on the same container is not touched.
    context.insert(OutboxItem(trainerUid: Synthetic.trainerB, memberKey: Synthetic.memberA, entityRef: "soap:other",
                              sequence: 1, stage: .document, kind: .createDocument, targetPath: "soap_notes/other",
                              state: .acked, createdAt: Synthetic.now))
    try context.save()

    let report = try LocalRetention(context: context, binaryStore: binaries, trainerUid: Synthetic.trainerA).purgeSynced()

    XCTAssertEqual(Set(report.destroyedOutboxItemIds), [ackedCreate.id, ackedUpload.id])
    XCTAssertEqual(report.destroyedSoapNoteIds, ["synced"])
    XCTAssertEqual(report.destroyedCaptureIds, ["confirmed"])
    XCTAssertEqual(report.destroyedBinaryIds, [syncedInk.id])
    XCTAssertEqual(try context.fetchOwned(LocalSoapDraft.self, by: Synthetic.trainerA).map(\.noteId), ["waiting"])
    XCTAssertEqual(try context.fetchOwned(OutboxItem.self, by: Synthetic.trainerA).map(\.id), [failedUpload.id])
    XCTAssertEqual(try context.fetchOwned(LocalConsentCapture.self, by: Synthetic.trainerA).map(\.captureId), ["pending"])
    XCTAssertEqual(try context.fetchOwned(LocalBinary.self, by: Synthetic.trainerA).map(\.id), [waitingInk.id])
    XCTAssertFalse(binaries.fileExists(relativePath: syncedInk.relativePath))
    XCTAssertTrue(binaries.fileExists(relativePath: waitingInk.relativePath), "an unsynced file is never deleted")
    XCTAssertEqual(try context.fetchOwned(StationProfile.self, by: Synthetic.trainerA).count, 1)
    XCTAssertEqual(try context.fetchOwned(OutboxItem.self, by: Synthetic.trainerB).count, 1)
  }

  /// #177 review HIGH-1: a draft with no Outbox item (a Live session still being written) or edited after its last
  /// acked step is unsynced and stays, with its ink.
  func testDraftsWithoutEvidenceThatTheServerHasThemStay() throws {
    let temp = try TemporaryDirectory()
    self.temp = temp
    let location = LocalStoreLocation(trainerUid: Synthetic.trainerA, applicationSupportURL: temp.url)
    let context = ModelContext(try LocalStoreContainer.make(location: location))
    let binaries = LocalBinaryStore(location: location)
    let ink = try binaries.write(data: Data("live ink".utf8), ext: "drawing", kind: .ink)
    context.insert(LocalBinary(
      id: ink.id, trainerUid: Synthetic.trainerA, kind: .ink, relativePath: ink.relativePath,
      contentType: ink.contentType, byteSize: ink.byteSize, sha256: ink.sha256, verifiedAt: Synthetic.now))
    context.insert(LocalSoapDraft(noteId: "live", trainerUid: Synthetic.trainerA, memberKey: Synthetic.memberA,
                                  sessionDate: Synthetic.now, inkBinaryId: ink.id, createdLocallyAt: Synthetic.now))
    let edited = LocalSoapDraft(noteId: "edited", trainerUid: Synthetic.trainerA, memberKey: Synthetic.memberA,
                                sessionDate: Synthetic.now, createdLocallyAt: Synthetic.now)
    edited.updatedLocallyAt = Synthetic.now.addingTimeInterval(60)
    context.insert(edited)
    context.insert(OutboxItem(trainerUid: Synthetic.trainerA, memberKey: Synthetic.memberA, entityRef: "soap:edited",
                              sequence: 1, stage: .document, kind: .createDocument, targetPath: "soap_notes/edited",
                              state: .acked, ackConfirmed: true, createdAt: Synthetic.now))
    try context.save()

    let report = try LocalRetention(context: context, binaryStore: binaries, trainerUid: Synthetic.trainerA).purgeSynced()

    XCTAssertEqual(report.destroyedSoapNoteIds, [])
    XCTAssertEqual(report.destroyedBinaryIds, [])
    XCTAssertEqual(Set(try context.fetchOwned(LocalSoapDraft.self, by: Synthetic.trainerA).map(\.noteId)), ["live", "edited"])
    XCTAssertTrue(binaries.fileExists(relativePath: ink.relativePath))
  }
}
