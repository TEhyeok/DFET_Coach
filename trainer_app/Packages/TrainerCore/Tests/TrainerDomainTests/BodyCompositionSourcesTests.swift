import Foundation
import TrainerContracts
import XCTest
@testable import TrainerDomain

/// DF-127/DF-130 vertical slice: merging server and local records, the device name rule of the picker, and the
/// server-only effective consent the save gate reads until DF-110. Synthetic values only.
final class BodyCompositionSourcesTests: XCTestCase {
  private func at(_ text: String) -> Date { FixtureTimestamp.parse(text)! }

  private func record(_ id: String, _ date: String, weight: Double = 64, status: MeasurementStatus = .active,
                      createdAt: Date? = nil) -> BodyCompositionRecord {
    BodyCompositionRecord(
      id: id, member: .uid("syn-0001"), deviceModel: "InBody 570", measuredAt: at(date), fasting: .yes,
      timeOfDayBand: .morning, source: "manualEntry", sourceGrade: .device, values: [.weightKg: weight], derived: nil,
      status: status, createdAt: createdAt)
  }

  func testMergeKeepsOneRecordPerIdAndTheServerCopyWins() {
    let serverCopy = record("r2", "2026-09-02T08:30:00+09:00", status: .voided, createdAt: at("2026-09-02T08:31:00+09:00"))
    let merged = BodyCompositionRecordMerge.merge(
      server: [record("r3", "2026-09-03T08:30:00+09:00"), serverCopy],
      local: [record("r2", "2026-09-02T08:30:00+09:00"), record("r1", "2026-09-01T08:30:00+09:00")])
    XCTAssertEqual(merged.map(\.id), ["r1", "r2", "r3"], "sorted by measuredAt, one per id")
    XCTAssertEqual(merged[1], serverCopy, "the server's state (voided, createdAt) wins over the local copy")
  }

  /// Review (DF-127 finding 4): a local record keeps this device's sync state, also when the listener already has a
  /// copy (Firestore's own pending write, or a rejected write it has not rolled back yet). Server-only records have
  /// none.
  func testMergeKeepsTheLocalSyncState() {
    var failed = record("r2", "2026-09-02T08:30:00+09:00")
    failed.syncState = .syncFailed
    var waiting = record("r3", "2026-09-03T08:30:00+09:00")
    waiting.syncState = .syncing
    let merged = BodyCompositionRecordMerge.merge(
      server: [record("r1", "2026-09-01T08:30:00+09:00"), record("r3", "2026-09-03T08:30:00+09:00", createdAt: at("2026-09-03T08:31:00+09:00"))],
      local: [failed, waiting])
    XCTAssertEqual(merged.map(\.syncState), [nil, .syncFailed, .syncing])
    XCTAssertNotNil(merged[2].createdAt, "the server's copy, with the local state")
  }

  /// Review (DF-127 finding 7): TR-03's row of a metric is the latest active record that has it, not the latest record.
  func testLatestActiveRecordOfOneMetric() {
    let full = BodyCompositionRecord(
      id: "r1", member: .uid("syn-0001"), deviceModel: "InBody 970", measuredAt: at("2026-09-18T08:30:00+09:00"),
      fasting: .yes, timeOfDayBand: .morning, source: "manualEntry", sourceGrade: .device,
      values: [.weightKg: 65.1, .bodyFatPercent: 24.3], derived: nil, status: .active)
    let voided = BodyCompositionRecord(
      id: "r2", member: .uid("syn-0001"), deviceModel: "InBody 970", measuredAt: at("2026-09-20T08:30:00+09:00"),
      fasting: .yes, timeOfDayBand: .morning, source: "manualEntry", sourceGrade: .device,
      values: [.bodyFatPercent: 99], derived: nil, status: .voided)
    let weightOnly = record("r3", "2026-09-28T08:30:00+09:00", weight: 62.4)
    let records = [full, voided, weightOnly]
    XCTAssertEqual(BodyCompositionSeries.latestActive(records, measuring: .weightKg)?.id, "r3")
    XCTAssertEqual(BodyCompositionSeries.latestActive(records, measuring: .bodyFatPercent)?.id, "r1",
                   "a newer weight-only record does not hide the body fat %, a voided one never counts")
    XCTAssertNil(BodyCompositionSeries.latestActive(records, measuring: .skeletalMuscleMassKg))
  }

  /// Review (DF-127 finding 3): the record built from the saved entry is the record its payload reads back as, marked
  /// as saved on this device.
  func testTheSavedEntryIsTheRecordItsPayloadReadsBackAs() throws {
    let draft = BodyCompositionDraft(values: [.weightKg: "62,4", .bodyFatPercent: "24.1"], deviceModel: " InBody  970 ",
                                     measuredAt: at("2025-08-01T08:30:00+09:00"), fasting: .no, heightCmInput: "170")
    let entry = try XCTUnwrap(BodyCompositionValidator.validate(draft, now: at("2026-09-28T09:00:00+09:00")).entry)
    let member = MemberKey.pending("SynthPending00000001")
    var readBack = try XCTUnwrap(BodyCompositionRecord(
      id: "SynRecord00000000001", document: BodyCompositionPayload.fields(entry, member: member, trainerUid: "syn-t")))
    XCTAssertNil(readBack.syncState)
    readBack.syncState = .localSaved
    XCTAssertEqual(BodyCompositionRecord(id: "SynRecord00000000001", entry: entry, member: member), readBack)
  }

  func testMergeOrdersTiesById() {
    let merged = BodyCompositionRecordMerge.merge(
      server: [record("b", "2026-09-01T08:30:00+09:00")], local: [record("a", "2026-09-01T08:30:00+09:00")])
    XCTAssertEqual(merged.map(\.id), ["a", "b"])
  }

  func testStorableDeviceNames() {
    XCTAssertEqual(DeviceModelName.storable("  InBody   970 "), "InBody 970")
    XCTAssertNil(DeviceModelName.storable("   "))
    XCTAssertEqual(DeviceModelName.storable(String(repeating: "가", count: 64))?.count, 64)
    XCTAssertNil(DeviceModelName.storable(String(repeating: "가", count: 65)))
    XCTAssertNil(DeviceModelName.storable(String(repeating: "😀", count: 33)), "UTF-16 units, as the rules count")
  }

  private struct FixedStates: ConsentStateSource {
    let states: [ConsentState?]
    func observe(member: MemberKey) -> AsyncStream<ConsentState?> {
      AsyncStream { continuation in
        states.forEach { continuation.yield($0) }
        continuation.finish()
      }
    }
  }

  private struct SilentConsent: EffectiveConsentSource {
    func observe(member: MemberKey) -> AsyncStream<EffectiveConsent> { AsyncStream { _ in } }
  }

  private let grantedAll = ConsentState(entries: [
    .required: ConsentStateEntry(granted: true, documentVersion: "v1"),
    .healthData: ConsentStateEntry(granted: true, documentVersion: "v1"),
    .bodyImaging: ConsentStateEntry(granted: true, documentVersion: "v1"),
  ])

  func testServerSourceMapsEveryStateAndNeverAwaits() async {
    let noHealth = ConsentState(entries: [.required: ConsentStateEntry(granted: true, documentVersion: "v1")])
    let source = ServerEffectiveConsentSource(states: FixedStates(states: [nil, noHealth, grantedAll]))
    var values: [EffectiveConsent] = []
    for await value in source.observe(member: .uid("syn-0001")) { values.append(value) }
    XCTAssertEqual(values, [
      .none,
      EffectiveConsent(required: .granted, healthData: .missing, bodyImaging: .missing),
      EffectiveConsent(required: .granted, healthData: .granted, bodyImaging: .granted),
    ])
    XCTAssertEqual(values.map(\.healthRecordSave), [.blocked, .blocked, .allowed])
  }

  func testCurrentConsentIsTheFirstValueOrNone() async {
    let granted = ServerEffectiveConsentSource(states: FixedStates(states: [grantedAll]))
    let current = await EffectiveConsent.current(from: granted, member: .uid("syn-0001"))
    XCTAssertEqual(current.healthRecordSave, .allowed)

    let ended = ServerEffectiveConsentSource(states: FixedStates(states: []))
    let none = await EffectiveConsent.current(from: ended, member: .uid("syn-0001"))
    XCTAssertEqual(none, .none, "a source that ends without a value refuses")

    let silent = await EffectiveConsent.current(from: SilentConsent(), member: .uid("syn-0001"), timeout: .milliseconds(50))
    XCTAssertEqual(silent, .none, "a source that says nothing refuses after the timeout")
  }
}
