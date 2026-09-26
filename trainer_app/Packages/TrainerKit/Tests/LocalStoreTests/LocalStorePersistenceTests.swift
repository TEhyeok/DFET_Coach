import Foundation
import SwiftData
import TrainerContracts
import TrainerDomain
import XCTest
@testable import LocalStore

/// TC-DF014-02 (AC-DF-014.2, NFR-04): a disk container in a temporary directory keeps every `LocalSoapDraft` field
/// across close and reopen (restart simulation).
@MainActor
final class LocalStorePersistenceTests: XCTestCase {
  private var temp: TemporaryDirectory?

  override func tearDown() {
    temp?.remove()
    temp = nil
    super.tearDown()
  }

  func test_TC_DF014_02_AC_DF_014_2_soapDraftKeepsEveryFieldAfterReopen() throws {
    let temp = try TemporaryDirectory()
    self.temp = temp
    let location = LocalStoreLocation(trainerUid: Synthetic.trainerA, applicationSupportURL: temp.url)
    let inkId = UUID()
    let objective = Data(#"{"metrics":[{"metricId":"forwardHead","value":{"$int":12}}]}"#.utf8)
    let exercise = Data(#"{"items":["squat"]}"#.utf8)
    let created = Synthetic.now
    let updated = Synthetic.now.addingTimeInterval(95.125)
    let completed = Synthetic.now.addingTimeInterval(3600.5)

    do {
      let container = try LocalStoreContainer.make(location: location)
      let context = ModelContext(container)
      context.insert(LocalSoapDraft(
        noteId: "AbCdEfGhIjKlMnOpQrSt", trainerUid: Synthetic.trainerA, memberKey: Synthetic.memberA,
        sessionDate: Synthetic.now, lockState: .pendingFinalize, quickNote: "빠른 메모", inkBinaryId: inkId,
        inkRevision: 4, painNrs: 0, painRegions: [.neck, .shoulderLeft], chiefComplaint: "목 뻐근함",
        objectiveJSON: objective, exerciseAssessmentJSON: exercise, planNextSession: "다음 세션 계획",
        planHomeExercise: "홈 운동", memberNote: "회원 메모", serverCreated: true, liveCompletedAt: completed,
        syncState: .syncFailed, lastErrorCode: "permission-denied", createdLocallyAt: created,
        updatedLocallyAt: updated
      ))
      try context.save()
    }

    // Reopen from disk with a brand-new container, as after an app restart.
    let reopened = try LocalStoreContainer.make(location: location)
    let draft = try XCTUnwrap(ModelContext(reopened).fetchOwned(LocalSoapDraft.self, by: Synthetic.trainerA).first)
    XCTAssertEqual(draft.noteId, "AbCdEfGhIjKlMnOpQrSt")
    XCTAssertEqual(draft.trainerUid, Synthetic.trainerA)
    XCTAssertEqual(draft.memberKey, "uid:member-uid-a")
    XCTAssertEqual(draft.sessionDate, Synthetic.now)
    XCTAssertEqual(draft.lockState, "pendingFinalize")
    XCTAssertEqual(draft.quickNote, "빠른 메모")
    XCTAssertEqual(draft.inkBinaryId, inkId)
    XCTAssertEqual(draft.inkRevision, 4)
    XCTAssertEqual(draft.painNrs, 0, "0 is a score, not 'not entered'")
    XCTAssertEqual(draft.painRegions, ["neck", "shoulderLeft"])
    XCTAssertEqual(draft.chiefComplaint, "목 뻐근함")
    XCTAssertEqual(draft.objectiveJSON, objective)
    XCTAssertEqual(draft.exerciseAssessmentJSON, exercise)
    XCTAssertEqual(draft.planNextSession, "다음 세션 계획")
    XCTAssertEqual(draft.planHomeExercise, "홈 운동")
    XCTAssertEqual(draft.memberNote, "회원 메모")
    XCTAssertTrue(draft.serverCreated)
    XCTAssertEqual(draft.liveCompletedAt, completed)
    XCTAssertEqual(draft.syncState, "syncFailed")
    XCTAssertEqual(draft.lastErrorCode, "permission-denied")
    XCTAssertEqual(draft.createdLocallyAt, created)
    XCTAssertEqual(draft.updatedLocallyAt, updated)
  }

  func test_TC_DF014_02_AC_DF_014_2_nilOptionalsStayNilAfterReopen() throws {
    let temp = try TemporaryDirectory()
    self.temp = temp
    let storeURL = temp.url.appendingPathComponent("Nested/LocalStore.store")
    do {
      let context = ModelContext(try LocalStoreContainer.make(url: storeURL))
      context.insert(LocalSoapDraft(
        noteId: "n0", trainerUid: Synthetic.trainerA, memberKey: Synthetic.memberB, sessionDate: Synthetic.now,
        createdLocallyAt: Synthetic.now
      ))
      try context.save()
    }
    let draft = try XCTUnwrap(
      ModelContext(try LocalStoreContainer.make(url: storeURL)).fetchOwned(LocalSoapDraft.self, by: Synthetic.trainerA).first
    )
    XCTAssertEqual(draft.memberKey, "pending:pendingMemberB01")
    XCTAssertEqual(draft.lockState, "editable")
    XCTAssertEqual(draft.syncState, "localSaved")
    XCTAssertEqual(draft.inkRevision, 0)
    XCTAssertNil(draft.painNrs, "nil means not entered")
    XCTAssertEqual(draft.painRegions, [])
    XCTAssertNil(draft.quickNote)
    XCTAssertNil(draft.inkBinaryId)
    XCTAssertNil(draft.objectiveJSON)
    XCTAssertNil(draft.liveCompletedAt)
    XCTAssertFalse(draft.serverCreated)
    XCTAssertEqual(draft.updatedLocallyAt, Synthetic.now)
  }

  func test_TC_DF014_02_partitionPathUsesHashedTrainerKeyNotTheUid() throws {
    let base = URL(fileURLWithPath: "/tmp/appsupport", isDirectory: true)
    let location = LocalStoreLocation(trainerUid: Synthetic.trainerA, applicationSupportURL: base)
    XCTAssertEqual(location.trainerKey.count, 16)
    XCTAssertTrue(location.trainerKey.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    XCTAssertEqual(location.trainerKey, LocalStoreLocation.trainerKey(for: Synthetic.trainerA))
    XCTAssertNotEqual(location.trainerKey, LocalStoreLocation.trainerKey(for: Synthetic.trainerB))
    XCTAssertEqual(location.storeURL.path, "/tmp/appsupport/TrainerKit/\(location.trainerKey)/LocalStore.store")
    XCTAssertEqual(location.binariesURL.path, "/tmp/appsupport/TrainerKit/\(location.trainerKey)/Binaries")
    XCTAssertFalse(location.storeURL.path.contains(Synthetic.trainerA))
    // Known SHA-256("abc") prefix, pinned so the partition name never silently changes.
    XCTAssertEqual(LocalStoreLocation.trainerKey(for: "abc"), "ba7816bf8f01cfea")

    let real = try LocalStoreLocation.inApplicationSupport(trainerUid: Synthetic.trainerA)
    XCTAssertTrue(real.rootURL.path.hasSuffix("Application Support/TrainerKit"), real.rootURL.path)
  }
}
