import Foundation
import SwiftData
import TrainerContracts
import TrainerDomain
import XCTest
@testable import LocalStore

/// TC-DF014-01 (AC-DF-014.1): the V1 schema, model CRUD on an in-memory container and `trainerUid`-scoped queries.
@MainActor
final class LocalStoreSchemaTests: XCTestCase {
  private static let v1ModelNames: Set<String> = [
    "LocalSoapDraft", "LocalMeasurementDraft", "LocalConsentCapture", "OutboxItem", "LocalBinary",
    "TodayListEntry", "StationProfile", "QuickPhrase", "FilterPreference",
  ]

  func test_TC_DF014_01_AC_DF_014_1_schemaV1ListsExactlyTheNineV1Models() {
    XCTAssertEqual(LocalStoreSchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
    let names = Set(LocalStoreSchemaV1.models.map { String(describing: $0) })
    XCTAssertEqual(names, Self.v1ModelNames)
    XCTAssertEqual(Set(LocalStoreContainer.schema.entities.map(\.name)), Self.v1ModelNames)
    // Added by later schema versions, not V1 (DF-108 V1_1, DF-203).
    XCTAssertFalse(names.contains("LocalPendingMemberDraft"))
    XCTAssertFalse(names.contains("LocalAssessmentDraft"))
    XCTAssertEqual(LocalStoreMigrationPlan.schemas.count, 1)
    XCTAssertTrue(LocalStoreMigrationPlan.stages.isEmpty)
  }

  func test_TC_DF014_01_AC_DF_014_1_everyModelHasANonOptionalTrainerUidAttribute() throws {
    for entity in LocalStoreContainer.schema.entities {
      let attribute = try XCTUnwrap(
        entity.attributes.first { $0.name == "trainerUid" }, "\(entity.name) has no trainerUid"
      )
      XCTAssertFalse(attribute.isOptional, "\(entity.name).trainerUid must be required")
    }
  }

  func test_TC_DF014_01_AC_DF_014_1_uniqueKeysFollowV1_05() {
    let expected: [String: String] = [
      "LocalSoapDraft": "noteId", "LocalMeasurementDraft": "recordId", "LocalConsentCapture": "captureId",
      "OutboxItem": "id", "LocalBinary": "id", "TodayListEntry": "id", "StationProfile": "id", "QuickPhrase": "id",
      "FilterPreference": "key",
    ]
    for entity in LocalStoreContainer.schema.entities {
      let unique = entity.attributes.filter(\.isUnique).map(\.name)
      XCTAssertEqual(unique, expected[entity.name].map { [$0] }, entity.name)
    }
  }

  func test_TC_DF014_01_AC_DF_014_1_everyModelCreatesReadsUpdatesAndDeletesInMemory() throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let context = ModelContext(container)
    ModelFactory.insertOneOfEach(into: context, trainerUid: Synthetic.trainerA, tag: "A1")
    try context.save()

    try assertCount(1, in: context, for: Synthetic.trainerA)

    let draft = try XCTUnwrap(context.fetchOwned(LocalSoapDraft.self, by: Synthetic.trainerA).first)
    draft.quickNote = "updated"
    draft.lockState = LocalSoapLockState.pendingFinalize.rawValue
    try context.save()
    let reread = try XCTUnwrap(context.fetchOwned(LocalSoapDraft.self, by: Synthetic.trainerA).first)
    XCTAssertEqual(reread.quickNote, "updated")
    XCTAssertEqual(reread.lockState, "pendingFinalize")

    try deleteAll(in: context, for: Synthetic.trainerA)
    try context.save()
    try assertCount(0, in: context, for: Synthetic.trainerA)
  }

  func test_TC_DF014_01_AC_DF_014_1_scopedQueriesReturnOnlyTheSessionTrainersRows() throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let context = ModelContext(container)
    ModelFactory.insertOneOfEach(into: context, trainerUid: Synthetic.trainerA, tag: "A1")
    ModelFactory.insertOneOfEach(into: context, trainerUid: Synthetic.trainerA, tag: "A2")
    ModelFactory.insertOneOfEach(into: context, trainerUid: Synthetic.trainerB, tag: "B1")
    try context.save()

    try assertCount(2, in: context, for: Synthetic.trainerA)
    try assertCount(1, in: context, for: Synthetic.trainerB)
    try assertCount(0, in: context, for: "someone-else")
    XCTAssertTrue(try context.fetchOwned(LocalSoapDraft.self, by: Synthetic.trainerB).allSatisfy {
      $0.trainerUid == Synthetic.trainerB && $0.noteId == "noteB1"
    })
  }

  func test_TC_DF014_01_uniqueNoteIdUpsertsInsteadOfDuplicating() throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let context = ModelContext(container)
    for text in ["first", "second"] {
      context.insert(LocalSoapDraft(
        noteId: "noteSame", trainerUid: Synthetic.trainerA, memberKey: Synthetic.memberA,
        sessionDate: Synthetic.now, quickNote: text, createdLocallyAt: Synthetic.now
      ))
      try context.save()
    }
    let drafts = try context.fetchOwned(LocalSoapDraft.self, by: Synthetic.trainerA)
    XCTAssertEqual(drafts.count, 1)
    XCTAssertEqual(drafts.first?.quickNote, "second")
  }

  func test_TC_DF014_01_inMemoryContainersAreIsolated() throws {
    let first = ModelContext(try LocalStoreContainer.make(inMemory: true))
    ModelFactory.insertOneOfEach(into: first, trainerUid: Synthetic.trainerA, tag: "A1")
    try first.save()
    let second = ModelContext(try LocalStoreContainer.make(inMemory: true))
    try assertCount(0, in: second, for: Synthetic.trainerA)
  }

  func test_TC_DF014_01_diskContainerWithoutURLIsRejected() {
    XCTAssertThrowsError(try LocalStoreContainer.make(url: nil, inMemory: false)) { error in
      XCTAssertEqual(error as? LocalStoreError, .missingStoreURL)
    }
  }

  func test_TC_DF014_01_memberKeyIsStoredAsOnePrefixedString() throws {
    XCTAssertEqual(MemberKey.uid("abc").storageValue, "uid:abc")
    XCTAssertEqual(MemberKey.pending("p1").storageValue, "pending:p1")
    XCTAssertEqual(MemberKey(storageValue: "uid:abc"), .uid("abc"))
    XCTAssertEqual(MemberKey(storageValue: "pending:p1"), .pending("p1"))
    XCTAssertNil(MemberKey(storageValue: "uid:"))
    XCTAssertNil(MemberKey(storageValue: "member-1"))

    let context = ModelContext(try LocalStoreContainer.make(inMemory: true))
    context.insert(TodayListEntry(
      trainerUid: Synthetic.trainerA, memberKey: Synthetic.memberB, dayKey: "2026-09-21", order: 3,
      addedAt: Synthetic.now, carriedOverFromDayKey: "2026-09-20"
    ))
    try context.save()
    let entry = try XCTUnwrap(context.fetchOwned(TodayListEntry.self, by: Synthetic.trainerA).first)
    XCTAssertEqual(entry.memberKey, "pending:pendingMemberB01")
    XCTAssertEqual(MemberKey(storageValue: entry.memberKey), Synthetic.memberB)
    XCTAssertEqual(entry.carriedOverFromDayKey, "2026-09-20")
  }

  func test_TC_DF014_01_outboxDefaultsFollowV1_05() {
    let item = OutboxItem(
      trainerUid: Synthetic.trainerA, memberKey: Synthetic.memberA, entityRef: "soap:n1", sequence: 7,
      stage: .upload, kind: .uploadBinary, targetPath: "p", blockedReason: .awaitingConsent, createdAt: Synthetic.now
    )
    XCTAssertEqual(item.requestId, item.id)
    XCTAssertEqual(item.stage, 3)
    XCTAssertEqual(item.state, "queued")
    XCTAssertNil(item.blockedReason, "blockedReason is kept only while state == blocked")
    XCTAssertEqual(item.nextAttemptAt, Synthetic.now)

    let consentRequest = UUID()
    let consent = OutboxItem(
      requestId: consentRequest, trainerUid: Synthetic.trainerA, memberKey: Synthetic.memberA,
      entityRef: "consent:c1", sequence: 1, stage: .consent, kind: .callConsent, targetPath: "recordConsent",
      state: .blocked, blockedReason: .awaitingConsent, createdAt: Synthetic.now
    )
    XCTAssertEqual(consent.requestId, consentRequest)
    XCTAssertEqual(consent.blockedReason, "awaitingConsent")
  }

  // MARK: - Helpers

  private func assertCount(_ expected: Int, in context: ModelContext, for uid: String,
                           file: StaticString = #filePath, line: UInt = #line) throws {
    let counts: [(String, Int)] = [
      ("LocalSoapDraft", try context.fetchOwned(LocalSoapDraft.self, by: uid).count),
      ("LocalMeasurementDraft", try context.fetchOwned(LocalMeasurementDraft.self, by: uid).count),
      ("LocalConsentCapture", try context.fetchOwned(LocalConsentCapture.self, by: uid).count),
      ("OutboxItem", try context.fetchOwned(OutboxItem.self, by: uid).count),
      ("LocalBinary", try context.fetchOwned(LocalBinary.self, by: uid).count),
      ("TodayListEntry", try context.fetchOwned(TodayListEntry.self, by: uid).count),
      ("StationProfile", try context.fetchOwned(StationProfile.self, by: uid).count),
      ("QuickPhrase", try context.fetchOwned(QuickPhrase.self, by: uid).count),
      ("FilterPreference", try context.fetchOwned(FilterPreference.self, by: uid).count),
    ]
    XCTAssertEqual(counts.count, Self.v1ModelNames.count, file: file, line: line)
    for (name, count) in counts {
      XCTAssertEqual(count, expected, "\(name) for \(uid)", file: file, line: line)
    }
  }

  private func deleteAll(in context: ModelContext, for uid: String) throws {
    try context.fetchOwned(LocalSoapDraft.self, by: uid).forEach(context.delete)
    try context.fetchOwned(LocalMeasurementDraft.self, by: uid).forEach(context.delete)
    try context.fetchOwned(LocalConsentCapture.self, by: uid).forEach(context.delete)
    try context.fetchOwned(OutboxItem.self, by: uid).forEach(context.delete)
    try context.fetchOwned(LocalBinary.self, by: uid).forEach(context.delete)
    try context.fetchOwned(TodayListEntry.self, by: uid).forEach(context.delete)
    try context.fetchOwned(StationProfile.self, by: uid).forEach(context.delete)
    try context.fetchOwned(QuickPhrase.self, by: uid).forEach(context.delete)
    try context.fetchOwned(FilterPreference.self, by: uid).forEach(context.delete)
  }
}
