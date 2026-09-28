import DesignSystem
import FeatureBodyComposition
import SnapshotTesting
import SwiftUI
import TrainerContracts
import TrainerDomain
import XCTest

/// TC-130-11 snapshot part (AC-DF-130.11, DF-127 review finding 2): the TR-11 mini trend as TR-11 and TR-03 show it.
/// Ten months of synthetic weight records with a device change; a voided record and a draft the server refused (both
/// 99 kg) are no points; '산정 준비 중' without a band; light and at xxxLarge.
///
/// It lives with the DesignSystem snapshots and follows `SyncStateBadgeSnapshotTests`: one reference runtime (locally
/// it skips, on CI a missing reference is recorded, fails the run and is uploaded as the `snapshot-references`
/// artifact), one `__Snapshots__` folder.
@MainActor
final class BodyCompositionMiniTrendSnapshotTests: XCTestCase {
  private var recording = false
  private let seoul = TimeZone(identifier: "Asia/Seoul")!
  /// 2026-09-28 09:00 KST.
  private let now = Date(timeIntervalSince1970: 1_790_553_600)

  override func setUpWithError() throws {
    let environment = ProcessInfo.processInfo.environment
    recording = environment["SNAPSHOT_RECORD"] == "1"
    let version = ProcessInfo.processInfo.operatingSystemVersion
    let running = "\(version.majorVersion).\(version.minorVersion)"
    let reference = SyncStateBadgeSnapshotTests.referenceRuntime
    guard recording || running == reference else {
      let message = "snapshot references are for iOS \(reference); this runtime is iOS \(running)"
      if environment["CI"] == "1" { XCTFail(message + " (pin DFET_SIM_RUNTIME)") }
      throw XCTSkip(message)
    }
  }

  /// A store that answers with fixed records.
  private struct Records: MeasurementStore, DeviceModelCatalog {
    let records: [BodyCompositionRecord]

    func saveBodyComposition(member: MemberKey, draft: BodyCompositionDraft) async throws -> String { "" }

    func observeBodyCompositionRecords(member: MemberKey, since: Date)
      -> AsyncThrowingStream<[BodyCompositionRecord], Error>
    {
      let records = records
      return AsyncThrowingStream { $0.yield(records) }
    }

    func latestActiveBodyComposition(member: MemberKey) async throws -> BodyCompositionRecord? {
      BodyCompositionSeries.latestActive(records)
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

  /// (days ago, device, weight, status, sync state)
  private func records() -> [BodyCompositionRecord] {
    let rows: [(Double, String, Double, MeasurementStatus, SyncState?)] = [
      (300, "SYN InBody A", 70.4, .active, nil),
      (240, "SYN InBody A", 69.8, .active, nil),
      (200, "SYN InBody A", 99, .voided, nil),
      (150, "SYN InBody A", 68.9, .active, nil),
      (90, "SYN InBody B", 68.1, .active, nil),
      (40, "SYN InBody B", 99, .active, .syncFailed),
      (10, "SYN InBody B", 67.5, .active, .localSaved),
    ]
    return rows.enumerated().map { index, row in
      let measuredAt = now.addingTimeInterval(-row.0 * 86_400)
      return BodyCompositionRecord(
        id: String(format: "SynBodyComp%09d", index + 1), member: .uid("syn-0001"), deviceModel: row.1,
        measuredAt: measuredAt, fasting: .yes, timeOfDayBand: .morning, source: "manualEntry", sourceGrade: .device,
        values: [.weightKg: row.2], derived: nil, status: row.3, syncState: row.4)
    }
  }

  func test_TC_130_11_miniTrend() async throws {
    let store = Records(records: records())
    let model = BodyCompositionMemberModel(
      member: .uid("syn-0001"), services: BodyCompositionServices(store: store, devices: store, consent: Granted()),
      now: { [now] in now })
    model.start()
    for _ in 0..<200 where model.records == .loading {
      try await Task.sleep(nanoseconds: 5_000_000)
    }
    XCTAssertEqual(model.chartModel(.weightKg).points.count, 5, "no voided and no refused point")
    let localize = try AppCatalog.localizer()
    let sizes: [(String, UIContentSizeCategory, CGFloat)] = [
      ("miniTrend", .large, 560), ("miniTrend-xxxl", .extraExtraExtraLarge, 720),
    ]
    for (name, size, height) in sizes {
      let view = BodyCompositionMiniTrend(model: model, localize: localize, timeZone: seoul)
        .padding(TrainerSpacing.l)
        .frame(width: 560, height: height, alignment: .topLeading)
        .background(Color(uiColor: .systemBackground))
      let traits = UITraitCollection(mutations: { traits in
        traits.userInterfaceStyle = .light
        traits.preferredContentSizeCategory = size
      })
      assertSnapshot(
        of: view, as: .image(perceptualPrecision: 0.98, layout: .fixed(width: 560, height: height), traits: traits),
        named: name, record: recording)
    }
  }
}
