import DesignSystem
import Foundation
import TrainerContracts
import TrainerDomain
import XCTest
@testable import FeatureBodyComposition

/// DF-127/DF-130 review findings 3, 4 and 7 on the member model TR-03 and TR-11 read: a record saved before the trend
/// window, drafts the server refused, and TR-03's rows per metric. Synthetic data only.
@MainActor
final class BodyCompositionMemberModelTests: XCTestCase {
  private let member = MemberKey.uid("syn-0001")
  private let now = FixtureTimestamp.parse("2026-09-28T09:00:00+09:00")!

  /// A store that keeps what it saves and answers every read with the records measured at or after its `since`, like
  /// the Firestore query and the local draft filter do. It records each `since` it was asked for.
  private final class WindowStore: MeasurementStore, DeviceModelCatalog, @unchecked Sendable {
    private let lock = NSLock()
    private var records: [BodyCompositionRecord]
    private var continuations: [(since: Date, continuation: AsyncThrowingStream<[BodyCompositionRecord], Error>.Continuation)] = []
    private var _reads: [Date] = []
    var reads: [Date] { lock.withLock { _reads } }
    let now: Date

    init(records: [BodyCompositionRecord], now: Date) {
      self.records = records
      self.now = now
    }

    func saveBodyComposition(member: MemberKey, draft: BodyCompositionDraft) async throws -> String {
      let entry = try XCTUnwrap(BodyCompositionValidator.validate(draft, now: now).entry)
      let record = BodyCompositionRecord(id: "SynRecord00000000009", entry: entry, member: member)
      lock.withLock {
        records.append(record)
        for (since, continuation) in continuations { continuation.yield(records.filter { $0.measuredAt >= since }) }
      }
      return record.id
    }

    func observeBodyCompositionRecords(member: MemberKey, since: Date)
      -> AsyncThrowingStream<[BodyCompositionRecord], Error>
    {
      AsyncThrowingStream { continuation in
        lock.withLock {
          _reads.append(since)
          continuations.append((since, continuation))
          continuation.yield(records.filter { $0.measuredAt >= since })
        }
      }
    }

    func latestActiveBodyComposition(member: MemberKey) async throws -> BodyCompositionRecord? {
      BodyCompositionSeries.latestActive(lock.withLock { records })
    }

    func observeSeries(member: MemberKey, metricCode: MetricCode, since: Date) -> AsyncThrowingStream<[SeriesPoint], Error> {
      AsyncThrowingStream { $0.finish() }
    }

    func recentDeviceModels() async throws -> [String] { [] }
    func addDeviceModel(_ name: String) async throws -> String { name }
  }

  private struct Granted: EffectiveConsentSource {
    func observe(member: MemberKey) -> AsyncStream<EffectiveConsent> {
      AsyncStream { $0.yield(EffectiveConsent(required: .granted, healthData: .granted, bodyImaging: .granted)) }
    }
  }

  private func record(
    _ id: String, daysAgo: Double, device: String = "InBody 970", values: [BodyCompositionKey: Double],
    status: MeasurementStatus = .active, syncState: SyncState? = nil
  ) -> BodyCompositionRecord {
    BodyCompositionRecord(
      id: id, member: member, deviceModel: device, measuredAt: now.addingTimeInterval(-daysAgo * 86_400), fasting: .yes,
      timeOfDayBand: .morning, source: "manualEntry", sourceGrade: .device, values: values, derived: nil, status: status,
      syncState: syncState)
  }

  private func makeModel(_ records: [BodyCompositionRecord]) async throws -> (BodyCompositionMemberModel, WindowStore) {
    let store = WindowStore(records: records, now: now)
    let model = BodyCompositionMemberModel(
      member: member, services: BodyCompositionServices(store: store, devices: store, consent: Granted()),
      now: { [now] in now })
    model.start()
    for _ in 0..<200 where model.records == .loading || model.consent == nil {
      try await Task.sleep(nanoseconds: 5_000_000)
    }
    return (model, store)
  }

  // MARK: - Finding 3: a record measured before the trend window

  /// Saved with `measuredAt` 13 months ago: TR-11 shows it at once from the saved entry, the read reaches back to it
  /// (so its sync state comes from the store), it is marked as outside the trend window and it is no trend point.
  func testARecordOlderThanTheTrendWindowIsShownAfterSaving() async throws {
    let (model, store) = try await makeModel([record("SynBodyComp000000001", daysAgo: 30, values: [.weightKg: 65])])
    let form = model.makeEntryModel(localize: try AppCatalog.localizer())
    let old = Calendar(identifier: .gregorian).date(byAdding: .month, value: -13, to: now)!
    form.draft = BodyCompositionDraft(values: [.weightKg: "71.2"], deviceModel: "InBody 570", measuredAt: old,
                                      fasting: .yes)
    let saved = await form.save()
    let id = try XCTUnwrap(saved)
    let shown = try XCTUnwrap(model.record(id: id), "the record view has it right after saving, not '불러오는 중'")
    XCTAssertEqual(shown.values, [.weightKg: 71.2])
    XCTAssertEqual(shown.measuredAt, old)
    XCTAssertFalse(model.isInTrendWindow(shown), "the record view says the trend does not have it")
    XCTAssertEqual(shown.syncState, .localSaved)

    for _ in 0..<200 where !model.loadedRecords.contains(where: { $0.id == id }) {
      try await Task.sleep(nanoseconds: 5_000_000)
    }
    XCTAssertEqual(store.reads.count, 2, "one wider read after the save")
    XCTAssertLessThanOrEqual(try XCTUnwrap(store.reads.last), old, "the read reaches back to the saved record")
    XCTAssertTrue(model.loadedRecords.contains { $0.id == id }, "the stored record replaces the saved entry")
    XCTAssertEqual(model.chartModel(.weightKg).points.map(\.value), [65], "the trend still starts 12 months ago")
    XCTAssertEqual(model.latestValues.map(\.record.id), ["SynBodyComp000000001"], "TR-03 keeps its 12-month window")
  }

  // MARK: - Second review: TR-11 defaults from a record before the trend window

  /// The member was last measured 13 months ago: the 12-month read has nothing, but TR-11 still defaults to that
  /// record's device and height (V1-09 §10.3, ASM-P1a-41), while TR-03 keeps its window.
  func testTheDefaultsComeFromTheLatestRecordBeforeTheTrendWindow() async throws {
    let old = Calendar(identifier: .gregorian).date(byAdding: .month, value: -13, to: now)!
    let (model, _) = try await makeModel([
      BodyCompositionRecord(
        id: "SynBodyComp000000001", member: member, deviceModel: "InBody 570", measuredAt: old, fasting: .yes,
        timeOfDayBand: .morning, source: "manualEntry", sourceGrade: .device, values: [.weightKg: 70],
        derived: DerivedBMI(bmi: 24.2, heightCmUsed: 170, heightMeasuredAt: old), status: .active),
    ])
    XCTAssertFalse(model.hasActiveRecords, "nothing in the 12-month window")
    XCTAssertNil(model.latest)
    let form = model.makeEntryModel(localize: try AppCatalog.localizer())
    await form.prepare()
    XCTAssertEqual(form.draft.deviceModel, "InBody 570")
    XCTAssertEqual(form.draft.heightCmInput, "170")
    XCTAssertEqual(form.draft.heightMeasuredAt, old, "a carried-over height keeps its date")
  }

  // MARK: - Finding 4: a draft the server refused

  /// A refused draft is not a trend point and does not move the device-change notice, but it stays on its TR-03 row
  /// with its state; an unsynced draft that waits is a point with its state.
  func testARefusedDraftIsNoTrendPointButKeepsItsRowAndState() async throws {
    let (model, _) = try await makeModel([
      record("SynBodyComp000000001", daysAgo: 30, values: [.weightKg: 65]),
      record("SynBodyComp000000002", daysAgo: 20, values: [.weightKg: 64.5], syncState: .localSaved),
      record("SynBodyComp000000003", daysAgo: 5, device: "Refused Device", values: [.weightKg: 99],
             syncState: .syncFailed),
    ])
    XCTAssertEqual(model.chartModel(.weightKg).points.map(\.value), [65, 64.5], "the refused 99 kg is no point")
    let weight = try XCTUnwrap(model.latestValues.first { $0.key == .weightKg })
    XCTAssertEqual(weight.record.id, "SynBodyComp000000003", "the failure stays on the TR-03 row (V1-07 §6)")
    XCTAssertEqual(weight.record.syncState, .syncFailed)
    XCTAssertEqual(model.record(id: "SynBodyComp000000002")?.syncState, .localSaved)
    XCTAssertNil(model.record(id: "SynBodyComp000000001")?.syncState, "the server's copy has no state: synced")

    let form = model.makeEntryModel(localize: try AppCatalog.localizer())
    form.draft = BodyCompositionDraft(values: [.weightKg: "64"], deviceModel: "InBody 970", measuredAt: now, fasting: .yes)
    XCTAssertFalse(form.showsDeviceChanged, "compared with the trend's latest record, not the refused one")
  }

  // MARK: - Finding 7: TR-03 rows per metric

  /// A weight-only record does not hide the last body fat % and skeletal muscle mass; each row has its own record.
  func testEachTR03RowIsTheLatestRecordOfItsMetric() async throws {
    let (model, _) = try await makeModel([
      record("SynBodyComp000000001", daysAgo: 10, device: "InBody 970",
             values: [.weightKg: 65.1, .bodyFatPercent: 24.3, .skeletalMuscleMassKg: 26.9]),
      record("SynBodyComp000000002", daysAgo: 3, device: "InBody 570", values: [.bodyFatPercent: 99], status: .voided),
      record("SynBodyComp000000003", daysAgo: 0, device: "Home Scale", values: [.weightKg: 62.4]),
    ])
    XCTAssertTrue(model.hasActiveRecords)
    XCTAssertEqual(model.latestValues.map(\.key), [.weightKg, .bodyFatPercent, .skeletalMuscleMassKg])
    XCTAssertEqual(model.latestValues.map(\.record.id),
                   ["SynBodyComp000000003", "SynBodyComp000000001", "SynBodyComp000000001"])
    XCTAssertEqual(model.latestValues.map { $0.record.values[$0.key] }, [62.4, 24.3, 26.9])
    XCTAssertEqual(model.latestValues.map(\.record.deviceModel), ["Home Scale", "InBody 970", "InBody 970"])
  }

  func testWithOnlyVoidedRecordsThereAreNoRows() async throws {
    let (model, _) = try await makeModel([
      record("SynBodyComp000000001", daysAgo: 3, values: [.weightKg: 65], status: .voided),
    ])
    XCTAssertFalse(model.hasActiveRecords)
    XCTAssertEqual(model.latestValues, [])
  }
}
