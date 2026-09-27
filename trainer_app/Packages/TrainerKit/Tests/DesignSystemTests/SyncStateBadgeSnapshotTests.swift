import DesignSystem
import SnapshotTesting
import SwiftUI
import TrainerContracts
import XCTest

/// TC-DF016-01: SyncStateBadge in its five states, light and dark; MetricRow as drawn (chip and date included) at
/// the default size and at xxxLarge in a 320 pt column (1/3 Split View), light and dark.
///
/// References belong to one simulator runtime, the one CI pins (`DFET_SIM_RUNTIME` in trainer-app.yml, V1-10). Other
/// runtimes draw text differently: locally they skip, on CI (`CI=1`) they fail, so a runner image update cannot
/// silently turn the test off. A missing reference is recorded, fails the run, and CI uploads the `__Snapshots__`
/// folder as the `snapshot-references` artifact of the pull request run; commit it from there. To re-record on
/// purpose, put `TEST_RUNNER_SNAPSHOT_RECORD=1` in xcodebuild's environment (not as a build setting).
@MainActor
final class SyncStateBadgeSnapshotTests: XCTestCase {
  /// The runtime of the committed references: `DFET_SIM_RUNTIME` in trainer-app.yml.
  static let referenceRuntime = "26.2"
  private var recording = false

  override func setUpWithError() throws {
    let environment = ProcessInfo.processInfo.environment
    recording = environment["SNAPSHOT_RECORD"] == "1"
    let version = ProcessInfo.processInfo.operatingSystemVersion
    let running = "\(version.majorVersion).\(version.minorVersion)"
    guard recording || running == Self.referenceRuntime else {
      let message = "snapshot references are for iOS \(Self.referenceRuntime); this runtime is iOS \(running)"
      if environment["CI"] == "1" { XCTFail(message + " (pin DFET_SIM_RUNTIME)") }
      throw XCTSkip(message)
    }
  }

  func test_TC_DF016_01_syncStateBadgeLightAndDark() throws {
    let localize = try AppCatalog.localizer()
    for style in [UIUserInterfaceStyle.light, .dark] {
      for state in SyncState.allCases {
        let failed = state == .syncFailed
        let badge = SyncStateBadge(
          state: state, reasonKey: failed ? "sync.reason.ruleDenied" : nil, onRetry: failed ? {} : nil, localize: localize)
        let view = badge
          .padding(TrainerSpacing.s)
          .frame(width: 320, alignment: .leading)
          .background(Color(uiColor: .systemBackground))
        assertSnapshot(
          of: view,
          as: .image(perceptualPrecision: 0.98, layout: .fixed(width: 320, height: failed ? 132 : 44),
                     traits: UITraitCollection(userInterfaceStyle: style)),
          named: "\(state.rawValue)-\(style == .dark ? "dark" : "light")",
          record: recording)
      }
    }
  }

  func test_TC_DF016_01_metricRowsLightDarkAndLargeText() throws {
    let localize = try AppCatalog.localizer()
    let seoul = TimeZone(identifier: "Asia/Seoul")!
    let measured = Date(timeIntervalSince1970: 1_790_000_000)
    let rows = [
      MetricRowModel(code: .weightKg, value: 72.4, sourceGrade: .device, deviceModel: "합성 체성분 기기", measuredAt: measured),
      MetricRowModel(code: .shoulderTiltAngle, value: 1.3, side: .left, sourceGrade: .photoAuto, measuredAt: measured),
      MetricRowModel(code: .waistCircumference, value: 80.2, sourceGrade: .tape, measuredAt: measured),
    ]
    let sizes: [(String, UIContentSizeCategory)] = [("default", .large), ("xxxl", .extraExtraExtraLarge)]
    for style in [UIUserInterfaceStyle.light, .dark] {
      for (sizeName, size) in sizes {
        let view = VStack(alignment: .leading, spacing: TrainerSpacing.s) {
          ForEach(rows, id: \.code) { MetricRow(metric: $0, localize: localize, timeZone: seoul) }
        }
        .padding(TrainerSpacing.s)
        .frame(width: 320, height: 560, alignment: .topLeading)
        .background(Color(uiColor: .systemBackground))
        let traits = UITraitCollection(traitsFrom: [
          UITraitCollection(userInterfaceStyle: style), UITraitCollection(preferredContentSizeCategory: size),
        ])
        assertSnapshot(
          // A fixed frame, like a List row gets: `.sizeThatFits` measures without a width proposal, and ViewThatFits
          // then reports the wide candidate's height while drawing the stacked one.
          of: view, as: .image(perceptualPrecision: 0.98, layout: .fixed(width: 320, height: 560), traits: traits),
          named: "rows-\(sizeName)-\(style == .dark ? "dark" : "light")", record: recording)
      }
    }
  }
}
