import DesignSystem
import SnapshotTesting
import SwiftUI
import TrainerContracts
import XCTest

/// TC-DF016-01: SyncStateBadge in its five states, light and dark.
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
}
