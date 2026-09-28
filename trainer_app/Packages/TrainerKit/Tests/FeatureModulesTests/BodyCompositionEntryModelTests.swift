import DesignSystem
import Foundation
import TrainerContracts
import TrainerDomain
import XCTest
@testable import FeatureBodyComposition

/// DF-127 TR-11 form state (TC-127-01, -05, -06, -07, -08, -09 on the screen model) and DF-130 chart mapping. The words
/// are the app catalog's. Synthetic data only.
@MainActor
final class BodyCompositionEntryModelTests: XCTestCase {
  private let member = MemberKey.uid("syn-0001")
  private let now = FixtureTimestamp.parse("2026-09-28T09:00:00+09:00")!

  private final class FakeStore: MeasurementStore, DeviceModelCatalog, @unchecked Sendable {
    private let lock = NSLock()
    private let records: [BodyCompositionRecord]
    private var _saved: [BodyCompositionDraft] = []
    private var _devices: [String]
    /// Reads wait here until `releaseRecords()` (a slow server); nil answers at once.
    private var held: [AsyncThrowingStream<[BodyCompositionRecord], Error>.Continuation]?
    var saved: [BodyCompositionDraft] { lock.withLock { _saved } }

    init(records: [BodyCompositionRecord] = [], devices: [String] = [], holdsRecords: Bool = false) {
      self.records = records
      _devices = devices
      held = holdsRecords ? [] : nil
    }

    func releaseRecords() {
      lock.withLock {
        held?.forEach { $0.yield(records) }
        held = nil
      }
    }

    func saveBodyComposition(member: MemberKey, draft: BodyCompositionDraft) async throws -> String {
      lock.withLock { _saved.append(draft) }
      return "SynRecord00000000001"
    }

    func observeBodyCompositionRecords(member: MemberKey, since: Date)
      -> AsyncThrowingStream<[BodyCompositionRecord], Error>
    {
      AsyncThrowingStream { continuation in
        lock.withLock {
          if held != nil {
            held?.append(continuation)
          } else {
            continuation.yield(records)
          }
        }
      }
    }

    func latestActiveBodyComposition(member: MemberKey) async throws -> BodyCompositionRecord? {
      BodyCompositionSeries.latestActive(records)
    }

    func observeSeries(member: MemberKey, metricCode: MetricCode, since: Date) -> AsyncThrowingStream<[SeriesPoint], Error> {
      AsyncThrowingStream { $0.finish() }
    }

    func recentDeviceModels() async throws -> [String] { lock.withLock { _devices } }

    func addDeviceModel(_ name: String) async throws -> String {
      guard let stored = DeviceModelName.storable(name) else { throw DeviceModelCatalogError.invalidName }
      lock.withLock { _devices.insert(stored, at: 0) }
      return stored
    }
  }

  private struct FixedConsent: EffectiveConsentSource {
    let value: EffectiveConsent?
    func observe(member: MemberKey) -> AsyncStream<EffectiveConsent> {
      let value = value
      return AsyncStream { continuation in
        if let value { continuation.yield(value) }
      }
    }
  }

  private static let granted = EffectiveConsent(required: .granted, healthData: .granted, bodyImaging: .granted)

  private func record(_ id: String, daysAgo: Double, device: String, weight: Double = 65, height: Double? = nil,
                      fasting: Fasting = .yes, status: MeasurementStatus = .active) -> BodyCompositionRecord {
    let measuredAt = now.addingTimeInterval(-daysAgo * 86_400)
    return BodyCompositionRecord(
      id: id, member: member, deviceModel: device, measuredAt: measuredAt, fasting: fasting, timeOfDayBand: .morning,
      source: "manualEntry", sourceGrade: .device, values: [.weightKg: weight],
      derived: height.map { DerivedBMI(bmi: 22.5, heightCmUsed: $0, heightMeasuredAt: measuredAt) }, status: status)
  }

  /// A started member model with its first records and consent, and a new form.
  private func makeForm(
    consent: EffectiveConsent? = granted, records: [BodyCompositionRecord] = [], devices: [String] = []
  ) async throws -> (BodyCompositionEntryModel, BodyCompositionMemberModel, FakeStore) {
    let store = FakeStore(records: records, devices: devices)
    let services = BodyCompositionServices(store: store, devices: store, consent: FixedConsent(value: consent))
    let memberModel = BodyCompositionMemberModel(member: member, services: services, now: { [now] in now })
    memberModel.start()
    for _ in 0..<200 where memberModel.records == .loading || (consent != nil && memberModel.consent == nil) {
      try await Task.sleep(nanoseconds: 5_000_000)
    }
    let form = memberModel.makeEntryModel(localize: try AppCatalog.localizer())
    return (form, memberModel, store)
  }

  // MARK: - AC-DF-127.1: meta and a value before saving

  func testSaveStaysOffUntilDeviceFastingAndAValue_AC_DF_127_1() async throws {
    let (form, _, _) = try await makeForm()
    XCTAssertFalse(form.canSave)
    XCTAssertEqual(form.missingMessages, ["기기 모델을 골라 주세요", "공복 여부를 골라 주세요", "측정값을 하나 이상 입력하세요"])
    form.draft.deviceModel = "InBody 970"
    XCTAssertFalse(form.canSave)
    form.draft.fasting = .yes
    XCTAssertFalse(form.canSave)
    form.draft.values[.weightKg] = "62,4"
    XCTAssertTrue(form.canSave)
    XCTAssertEqual(form.missingMessages, [])
    XCTAssertEqual(form.validation.entry?.values, [.weightKg: 62.4], "'62,4' is 62.4 and the only key (AC-DF-127.6)")
  }

  func testFastingHasNoDefaultAndTimeOfDayIsComputed_AC_DF_127_9() async throws {
    let (form, _, _) = try await makeForm()
    XCTAssertNil(form.draft.fasting)
    XCTAssertEqual(form.timeOfDayText, "오전(11시 전)")
    form.draft.measuredAt = FixtureTimestamp.parse("2026-09-28T17:00:00+09:00")!
    XCTAssertEqual(form.timeOfDayText, "저녁(17시 이후)")
    form.draft.measuredAt = now.addingTimeInterval(10 * 60)
    XCTAssertEqual(form.measuredAtMessage, "측정 일시가 지금보다 늦어요. 다시 확인하세요")
  }

  // MARK: - AC-DF-127.4: consent ②

  func testConsentTwoGatesSavingAndTheHeightRow_AC_DF_127_4() async throws {
    let cases: [(EffectiveConsent?, canSave: Bool, needed: Bool, localOnly: Bool, height: Bool, UInt)] = [
      (Self.granted, true, false, false, true, #line),
      (EffectiveConsent(required: .granted, healthData: .awaitingConsent, bodyImaging: .missing), true, false, true, true,
       #line),
      (EffectiveConsent(required: .granted, healthData: .missing, bodyImaging: .granted), false, true, false, false, #line),
      (EffectiveConsent(required: .granted, healthData: .rejected, bodyImaging: .granted), false, true, false, false, #line),
      (nil, false, false, false, false, #line),  // not known yet: off, without claiming consent is missing
    ]
    for (consent, canSave, needed, localOnly, height, line) in cases {
      let (form, _, _) = try await makeForm(consent: consent)
      form.draft = BodyCompositionDraft(values: [.weightKg: "62.4"], deviceModel: "InBody 970", measuredAt: now,
                                        fasting: .no)
      XCTAssertEqual(form.canSave, canSave, line: line)
      XCTAssertEqual(form.showsConsentNeeded, needed, line: line)
      XCTAssertEqual(form.savesLocallyOnly, localOnly, line: line)
      XCTAssertEqual(form.showsHeight, height, line: line)
    }
  }

  // MARK: - AC-DF-127.7: ranges

  func testRangeErrorTextAndZeroBodyFat_AC_DF_127_7() async throws {
    let (form, _, _) = try await makeForm()
    form.draft = BodyCompositionDraft(values: [.bodyFatPercent: "120"], deviceModel: "InBody 970", measuredAt: now,
                                      fasting: .yes)
    XCTAssertEqual(form.errorMessage(for: .value(.bodyFatPercent)), "0~100% 사이로 입력하세요")
    XCTAssertFalse(form.canSave)
    form.draft.values[.bodyFatPercent] = "0"
    XCTAssertNil(form.errorMessage(for: .value(.bodyFatPercent)), "0 % is a value (R-27)")
    XCTAssertTrue(form.canSave)
    form.draft.values[.weightKg] = "600.1"
    XCTAssertEqual(form.errorMessage(for: .value(.weightKg)), "0.1~600kg 사이로 입력하세요")
    form.draft.values[.weightKg] = "62.45"
    XCTAssertEqual(form.errorMessage(for: .value(.weightKg)), "숫자로 입력하세요. 소수점 아래는 한 자리까지예요")
  }

  // MARK: - AC-DF-127.8: warnings still save

  func testCrossWarningsShowAndSavingStaysOn_AC_DF_127_8() async throws {
    let (form, _, store) = try await makeForm()
    form.draft = BodyCompositionDraft(
      values: [.weightKg: "60", .bodyFatMassKg: "70", .skeletalMuscleMassKg: "61"], deviceModel: "InBody 970",
      measuredAt: now, fasting: .yes)
    XCTAssertEqual(form.warningMessages, [
      "체지방량이 체중보다 커요. 결과지를 다시 확인하세요", "골격근량이 체중 이상이에요. 결과지를 다시 확인하세요",
    ])
    XCTAssertTrue(form.hasWarnings)
    XCTAssertTrue(form.canSave)
    let id = await form.save()
    XCTAssertEqual(id, "SynRecord00000000001")
    XCTAssertEqual(store.saved.count, 1)
    XCTAssertFalse(form.canSave, "a saved form cannot save the same record again")
  }

  // MARK: - The flag turned off while TR-11 is open (V1-07 §3.6, ASM-07-06)

  /// DF-127 second review: `bodyComposition` turned off while the form is open locks it. Saving is off, `save()` writes
  /// nothing (it checks right before the write), and what was typed stays; turned on again, it saves.
  func testTheFlagTurnedOffLocksTheFormAndKeepsTheDraft() async throws {
    let (form, _, store) = try await makeForm()
    form.draft = BodyCompositionDraft(values: [.weightKg: "62,4"], deviceModel: "InBody 970", measuredAt: now,
                                      fasting: .yes)
    XCTAssertTrue(form.canSave)
    form.isFeatureOn = false
    XCTAssertFalse(form.canSave)
    let refused = await form.save()
    XCTAssertNil(refused)
    XCTAssertEqual(store.saved.count, 0, "nothing reaches the store, so nothing reaches the Outbox")
    XCTAssertFalse(form.saveFailed)
    XCTAssertEqual(form.draft.values[.weightKg], "62,4", "the draft stays")
    form.isFeatureOn = true
    let id = await form.save()
    XCTAssertEqual(id, "SynRecord00000000001")
  }

  /// DF-127 second review (TR-11 lost on a size-class change): the shell's `BodyCompositionScreens` gives a rebuilt
  /// TR-03 the same member model, holds the open form with what was typed, and passes the flag on to it.
  func testTheShellKeepsTheMemberModelAndTheOpenForm() throws {
    let store = FakeStore()
    let screens = BodyCompositionScreens(
      services: BodyCompositionServices(store: store, devices: store, consent: FixedConsent(value: Self.granted)),
      localize: try AppCatalog.localizer())
    let model = screens.memberModel(for: member)
    XCTAssertTrue(screens.memberModel(for: member) === model, "a rebuilt TR-03 gets the same model")
    screens.openEntry(for: member)
    let form = try XCTUnwrap(screens.entry)
    XCTAssertTrue(form.memberModel === model)
    form.draft.values[.weightKg] = "62,4"
    XCTAssertTrue(screens.memberModel(for: member) === model)
    XCTAssertTrue(screens.entry === form, "the form outlives the views that show it")

    screens.isFeatureOn = false
    XCTAssertFalse(form.isFeatureOn, "the open form locks")
    XCTAssertEqual(screens.entry?.draft.values[.weightKg], "62,4")
    screens.isFeatureOn = true
    XCTAssertTrue(form.isFeatureOn)
    screens.closeEntry()
    XCTAssertNil(screens.entry)
    XCTAssertFalse(screens.memberModel(for: .uid("syn-0002")) === model, "another member, another model")
  }

  // MARK: - AC-DF-127.5: BMI

  func testBMIIsDerivedOnlyWithATrainerHeight_AC_DF_127_5() async throws {
    let (form, _, _) = try await makeForm()
    form.draft = BodyCompositionDraft(values: [.weightKg: "62.4"], deviceModel: "InBody 970", measuredAt: now,
                                      fasting: .yes)
    XCTAssertEqual(form.bmiText, "미측정")
    XCTAssertFalse(form.hasBMI)
    form.setHeight("170")
    XCTAssertEqual(form.bmiText, "21.6 kg/m²")
    XCTAssertEqual(form.validation.entry?.derived?.heightCmUsed, 170)
    XCTAssertEqual(form.validation.entry?.derived?.heightMeasuredAt, now, "typed now: measured with this record")
  }

  // MARK: - Defaults, device list, device change

  func testDefaultsComeFromTheLatestActiveRecord() async throws {
    let records = [
      record("SynBodyComp000000001", daysAgo: 40, device: "InBody 570"),
      record("SynBodyComp000000002", daysAgo: 10, device: "InBody 970", height: 170),
      record("SynBodyComp000000003", daysAgo: 5, device: "Voided Device", status: .voided),
    ]
    let (form, _, _) = try await makeForm(records: records, devices: ["Tanita MC-780"])
    await form.prepare()
    XCTAssertEqual(form.draft.deviceModel, "InBody 970", "the latest active record's device, not a voided one")
    XCTAssertEqual(form.deviceModels, ["Tanita MC-780", "InBody 970"])
    XCTAssertEqual(form.draft.heightCmInput, "170")
    XCTAssertEqual(form.draft.heightMeasuredAt, records[1].measuredAt, "a carried-over height keeps its date")
    form.setHeight("171")
    XCTAssertNil(form.draft.heightMeasuredAt)

    XCTAssertFalse(form.showsDeviceChanged)
    form.draft.deviceModel = "InBody 570"
    XCTAssertTrue(form.showsDeviceChanged, "another device than the latest active record (AC-DF-128.7)")
  }

  /// DF-127 second review: TR-11 opened before the member's records arrive (a slow server) does not settle on this
  /// iPad's last device and no height. The defaults come from the records once they are there, and a device the
  /// trainer chose meanwhile stays.
  func testDefaultsWaitForTheMembersRecords() async throws {
    let store = FakeStore(records: [record("SynBodyComp000000001", daysAgo: 10, device: "InBody 970", height: 170)],
                          devices: ["Tanita MC-780", "InBody 570"], holdsRecords: true)
    let services = BodyCompositionServices(store: store, devices: store, consent: FixedConsent(value: Self.granted))
    let memberModel = BodyCompositionMemberModel(member: member, services: services, now: { [now] in now })
    let form = memberModel.makeEntryModel(localize: try AppCatalog.localizer())
    let preparing = Task { await form.prepare() }
    for _ in 0..<200 where form.deviceModels.isEmpty {
      try await Task.sleep(nanoseconds: 5_000_000)
    }
    XCTAssertEqual(form.deviceModels, ["Tanita MC-780", "InBody 570"], "the list is there to choose from at once")
    XCTAssertEqual(memberModel.records, .loading)
    XCTAssertNil(form.draft.deviceModel, "no default before the member's records are known")
    XCTAssertNil(form.draft.heightCmInput)

    store.releaseRecords()
    await preparing.value
    XCTAssertEqual(form.draft.deviceModel, "InBody 970", "the member's latest device, not this iPad's last one")
    XCTAssertEqual(form.draft.heightCmInput, "170")

    let second = memberModel.makeEntryModel(localize: try AppCatalog.localizer())
    second.draft.deviceModel = "InBody 570"
    await second.prepare()
    XCTAssertEqual(second.draft.deviceModel, "InBody 570", "a device the trainer chose is kept")
    XCTAssertEqual(second.draft.heightCmInput, "170")
  }

  func testWithoutRecordsTheMostRecentlyUsedDeviceIsTheDefault() async throws {
    let (form, _, _) = try await makeForm(devices: ["Tanita MC-780", "InBody 570"])
    await form.prepare()
    XCTAssertEqual(form.draft.deviceModel, "Tanita MC-780")
    XCTAssertNil(form.draft.heightCmInput)
  }

  func testAddingADeviceSelectsIt() async throws {
    let (form, _, _) = try await makeForm(devices: ["InBody 570"])
    await form.prepare()
    let added = await form.addDevice("  InBody   970 ")
    XCTAssertTrue(added)
    XCTAssertEqual(form.draft.deviceModel, "InBody 970")
    XCTAssertEqual(form.deviceModels.first, "InBody 970")
    let blank = await form.addDevice("   ")
    XCTAssertFalse(blank)
  }

  // MARK: - DF-130 chart model

  /// AC-DF-130.4 data, AC-DF-130.5, AC-DF-130.11: device A twice then B → two segments, the second starting with a
  /// device break; voided records are no points; the badge is '산정 준비 중'; the chip names the latest device.
  func testTheChartBreaksAtADeviceChangeAndSkipsVoidedRecords() async throws {
    let records = [
      record("SynBodyComp000000001", daysAgo: 60, device: "InBody 570", weight: 66),
      record("SynBodyComp000000002", daysAgo: 45, device: "InBody 570", weight: 99, status: .voided),
      record("SynBodyComp000000003", daysAgo: 30, device: "InBody 570", weight: 65.5),
      record("SynBodyComp000000004", daysAgo: 10, device: "InBody 970", weight: 65),
    ]
    let (_, memberModel, _) = try await makeForm(records: records)
    let chart = memberModel.chartModel(.weightKg)
    XCTAssertEqual(chart.segments.map { $0.points.map(\.value) }, [[66, 65.5], [65]])
    XCTAssertNil(chart.segments[0].breakBefore)
    XCTAssertEqual(chart.segments[1].breakBefore, .deviceChanged(from: "InBody 570", to: "InBody 970"))
    XCTAssertEqual(chart.deviceModel, "InBody 970")
    XCTAssertEqual(chart.badge, .pendingPolicy)
    XCTAssertEqual(chart.content, .chart(.device))
    XCTAssertEqual(Set(chart.segments.map(\.id)).count, 2, "distinct Swift Charts series: never joined")
    XCTAssertEqual(memberModel.latest?.id, "SynBodyComp000000004")
  }

  func testAFastingChangeIsAConditionBreak() {
    let records = [
      record("SynBodyComp000000001", daysAgo: 20, device: "InBody 970", weight: 66),
      record("SynBodyComp000000002", daysAgo: 10, device: "InBody 970", weight: 65, fasting: .no),
    ]
    let chart = SeriesChartMapping.model(
      metricCode: .weightKg, points: BodyCompositionSeries.points(from: records, metricCode: .weightKg))
    XCTAssertEqual(chart.segments.count, 2)
    XCTAssertEqual(chart.segments[1].breakBefore, .conditionMismatch(condition: "fasting"))
    XCTAssertEqual(SeriesChartMapping.reason(SeriesBreak(reason: .conditionMismatch, detail: .condition(key: "stationProfile"))),
                   .conditionMismatch(condition: "station"))
  }

  func testNoRecordsIsAnEmptyChartNotAZeroLine() {
    let chart = SeriesChartMapping.model(metricCode: .weightKg, points: [])
    XCTAssertEqual(chart.content, .empty)
  }

  // MARK: - AC-DF-127.3

  /// TC-127-04 code search: nothing on the body composition path reads the member-edited `users` document.
  func testNoBodyCompositionCodeReadsTheUsersDocument_AC_DF_127_3() throws {
    let sources = AppCatalog.trainerApp.appendingPathComponent("Packages/TrainerKit/Sources")
    var files = try FileManager.default.subpathsOfDirectory(atPath: sources.appendingPathComponent("FeatureBodyComposition").path)
      .filter { $0.hasSuffix(".swift") }
      .map { sources.appendingPathComponent("FeatureBodyComposition/" + $0) }
    files += ["LocalStore/LocalMeasurementStore.swift", "LocalStore/LocalOutboxStore+Measurements.swift",
              "FirebaseData/FirestoreBodyCompositionReads.swift"].map { sources.appendingPathComponent($0) }
    XCTAssertGreaterThan(files.count, 5)
    for file in files {
      // Code only: the doc comments say that `users.height` is never read.
      let code = try String(contentsOf: file, encoding: .utf8).split(separator: "\n")
        .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
        .joined(separator: "\n")
      XCTAssertNil(code.range(of: #""users"|users/|users\.(height|weight)"#, options: .regularExpression),
                   file.lastPathComponent)
    }
  }
}
