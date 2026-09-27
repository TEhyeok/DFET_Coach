import DesignSystem
import Foundation
import TrainerContracts
import TrainerDomain
import XCTest
@testable import FeatureBodyComposition

/// DF-127 form boundaries and DF-130's real record-to-chart adapter. All members and records are synthetic.
@MainActor
final class BodyCompositionEntryModelTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_790_000_000)
  private let member = MemberKey.pending("SYNTHpending00000001")

  private struct ConsentSource: EffectiveConsentSource {
    let value: EffectiveConsent
    func observe(member: MemberKey) -> AsyncStream<EffectiveConsent> {
      AsyncStream { $0.yield(value); $0.finish() }
    }
  }

  private final class Store: MeasurementStore, @unchecked Sendable {
    private let lock = NSLock()
    private var savedDrafts: [BodyCompositionDraft] = []
    let records: [BodyCompositionRecord]
    let saveFails: Bool
    let recordsFail: Bool
    let syncState: SyncState?
    init(records: [BodyCompositionRecord] = [], saveFails: Bool = false, recordsFail: Bool = false, syncState: SyncState? = nil) {
      self.records = records
      self.saveFails = saveFails
      self.recordsFail = recordsFail
      self.syncState = syncState
    }
    var saves: [BodyCompositionDraft] { lock.withLock { savedDrafts } }
    func observeBodyCompositionSyncState(recordID: String) async -> AsyncStream<SyncState> {
      AsyncStream { if let syncState { $0.yield(syncState) }; $0.finish() }
    }
    func saveBodyComposition(member: MemberKey, draft: BodyCompositionDraft) async throws -> String {
      if saveFails { throw NSError(domain: "synthetic", code: 1) }
      lock.withLock { savedDrafts.append(draft) }
      return "SYNTHbody000000000001"
    }
    func observeBodyCompositionRecords(member: MemberKey, since: Date) -> AsyncThrowingStream<[BodyCompositionRecord], Error> {
      AsyncThrowingStream {
        if recordsFail { $0.finish(throwing: NSError(domain: "synthetic", code: 2)) }
        else { $0.yield(records.filter { $0.measuredAt >= since }); $0.finish() }
      }
    }
    func observeSeries(member: MemberKey, metricCode: MetricCode, since: Date) -> AsyncThrowingStream<[SeriesPoint], Error> {
      AsyncThrowingStream { $0.yield([]); $0.finish() }
    }
  }

  private func model(_ store: Store, health: EffectiveConsentValue = .granted) async -> BodyCompositionEntryModel {
    let model = BodyCompositionEntryModel(
      member: member, measurements: store,
      consentSource: ConsentSource(value: EffectiveConsent(required: .granted, healthData: health, bodyImaging: .missing)),
      now: { [now] in now })
    await model.observeConsent()
    return model
  }

  private func fill(_ model: BodyCompositionEntryModel) {
    model.setDevice("SYN-DEVICE-A")
    model.draft.values[.weightKg] = "62,4"
    model.draft.fasting = .yes
  }

  func testRequiredMetaAndConsentGate_TC_127_01_05() async {
    let store = Store()
    let granted = await model(store)
    XCTAssertNil(granted.draft.fasting, "no implicit fasting choice")
    granted.draft.values[.weightKg] = "62,4"
    XCTAssertFalse(granted.canSave)
    granted.setDevice("SYN-A")
    XCTAssertFalse(granted.canSave)
    granted.draft.fasting = .no
    XCTAssertTrue(granted.canSave)

    let missing = await model(store, health: .missing)
    fill(missing)
    XCTAssertFalse(missing.canSave)
    let saved = await missing.save()
    XCTAssertNil(saved)
    XCTAssertTrue(store.saves.isEmpty)
  }

  func testAwaitingConsentSavesOnlyLocallyWithoutCollectingHeight_TC_127_05() async {
    let store = Store()
    let value = await model(store, health: .awaitingConsent)
    fill(value)
    value.setHeight("165")
    XCTAssertFalse(value.allowsHeightEntry)
    XCTAssertTrue(value.canSave)
    let saved = await value.save()
    XCTAssertNotNil(saved)
    XCTAssertEqual(value.savedState, .awaitingConsent)
    XCTAssertNil(store.saves.first?.heightCmInput)
    XCTAssertNil(store.saves.first?.heightMeasuredAt)
  }

  func testSuccessfulSaveKeepsMeasurementDateAndPreventsDuplicates_TC_127_03_07() async {
    let store = Store()
    let value = await model(store)
    fill(value)
    value.draft.measuredAt = now.addingTimeInterval(-86_400)
    value.setHeight("165")
    let saved = await value.save()
    XCTAssertNotNil(saved)
    XCTAssertEqual(value.savedState, .localSaved, "local save never claims server-synced")
    XCTAssertEqual(store.saves.first?.measuredAt, now.addingTimeInterval(-86_400))
    XCTAssertEqual(store.saves.first?.values, [.weightKg: "62,4"])
    XCTAssertEqual(value.validation.bmi, 22.9)
    XCTAssertFalse(value.canSave)
    let duplicate = await value.save()
    XCTAssertNil(duplicate)
    XCTAssertEqual(store.saves.count, 1)
    value.beginNewEntry()
    XCTAssertNil(value.savedRecordID)
    XCTAssertTrue(value.draft.values.isEmpty)
    XCTAssertNil(value.draft.fasting)
    XCTAssertEqual(value.draft.heightMeasuredAt, now.addingTimeInterval(-86_400))
  }

  func testSaveFailureRetainsInputAndCanRetry() async {
    let value = await model(Store(saveFails: true))
    fill(value)
    let saved = await value.save()
    XCTAssertNil(saved)
    XCTAssertEqual(value.saveErrorKey, "tr11.saveFailed")
    XCTAssertEqual(value.draft.values[.weightKg], "62,4")
    XCTAssertTrue(value.canSave)
    XCTAssertFalse(value.isSaving)
  }

  func testSavedBadgeFollowsConfirmedQueueStateAndResetsForNewEntry() async {
    let value = await model(Store(syncState: .synced))
    fill(value)
    _ = await value.save()
    XCTAssertEqual(value.savedState, .localSaved)
    await value.observeSavedState()
    XCTAssertEqual(value.savedState, .synced)
    value.beginNewEntry()
    XCTAssertEqual(value.savedState, .localSaved)
  }

  func testHistoryFailureIsNotAnEmptySuccess() async {
    let value = await model(Store(recordsFail: true))
    await value.observeRecords()
    XCTAssertTrue(value.recordsFailed)
    XCTAssertFalse(value.isLoadingRecords)
  }

  func testLatestRecordDefaultsDoNotOverwriteEditing() async {
    let older = record("SYN-old", daysAgo: 500, device: "SYN-A", height: 166)
    let voided = record("SYN-void", daysAgo: 1, device: "SYN-VOID", status: .voided, height: 180)
    let store = Store(records: [voided, older])
    let initial = await model(store)
    await initial.observeRecords()
    XCTAssertEqual(initial.draft.deviceModel, "SYN-A", "old latest records still provide defaults")
    XCTAssertEqual(initial.draft.heightCmInput, "166")
    XCTAssertEqual(initial.draft.heightMeasuredAt, older.measuredAt)
    let edited = await model(store)
    edited.setDevice("SYN-EDITED")
    edited.setHeight("170")
    await edited.observeRecords()
    XCTAssertEqual(edited.draft.deviceModel, "SYN-EDITED")
    XCTAssertEqual(edited.draft.heightCmInput, "170")
    XCTAssertNil(edited.draft.heightMeasuredAt, "fresh height follows the new measurement date")
    XCTAssertFalse(edited.deviceNames.contains("SYN-VOID"))
  }

  func testRangeErrorAndCrossWarning_TC_127_08_09() async {
    let value = await model(Store())
    fill(value)
    value.draft.values[.bodyFatPercent] = "120"
    XCTAssertFalse(value.canSave)
    let range = value.validation.errors.first?.range
    XCTAssertEqual(range?.min, 0)
    XCTAssertEqual(range?.max, 100)
    value.draft.values[.bodyFatPercent] = "0"
    value.draft.values[.bodyFatMassKg] = "70"
    XCTAssertTrue(value.canSave)
    XCTAssertTrue(value.validation.warnings.contains(.fatMassOverWeight))
  }

  func testMiniTrendFiltersAndPreservesDeviceBreak_TC_130_01_03_04_11() {
    let records = [record("SYN-1", daysAgo: 10, device: "SYN-A"),
                   record("SYN-2", daysAgo: 9, device: "SYN-A"),
                   record("SYN-3", daysAgo: 1, device: "SYN-B"),
                   record("SYN-void", daysAgo: 3, device: "SYN-A", status: .voided),
                   record("SYN-old", daysAgo: 500, device: "SYN-A"),
                   record("SYN-nograde", daysAgo: 2, device: "SYN-A", grade: nil)]
    let chart = BodyCompositionTrend.model(records: records, metricCode: .weightKg, now: now)
    XCTAssertEqual(chart.points.count, 3)
    XCTAssertEqual(chart.segments.map { $0.points.count }, [2, 1])
    XCTAssertEqual(chart.segments.last?.breakBefore, .deviceChanged(from: "SYN-A", to: "SYN-B"))
    XCTAssertEqual(chart.points.map(\.measuredAt), [10.0, 9.0, 1.0].map { now.addingTimeInterval(-$0 * 86_400) })
    XCTAssertEqual(chart.deviceModel, "SYN-B")
    XCTAssertEqual(chart.badge, .pendingPolicy)
  }

  func testMixedGradesStayRejectedInChartAdapter_TC_130_02() {
    let chart = BodyCompositionTrend.model(
      records: [record("SYN-A", daysAgo: 2, device: "SYN-A"),
                record("SYN-B", daysAgo: 1, device: "SYN-A", grade: .selfReport)], metricCode: .weightKg, now: now)
    XCTAssertEqual(chart.content, .rejectedMixedSource)
  }

  private func record(
    _ id: String, daysAgo: Double, device: String, status: MeasurementStatus = .active,
    grade: SourceGrade? = .device, height: Double? = nil
  ) -> BodyCompositionRecord {
    let date = now.addingTimeInterval(-daysAgo * 86_400)
    return BodyCompositionRecord(
      id: id, member: member, deviceModel: device, measuredAt: date, fasting: .yes, timeOfDayBand: .morning,
      source: "manualEntry", sourceGrade: grade, values: [.weightKg: 62.4],
      derived: height.map { DerivedBMI(bmi: 22.6, heightCmUsed: $0, heightMeasuredAt: date) }, status: status)
  }
}
