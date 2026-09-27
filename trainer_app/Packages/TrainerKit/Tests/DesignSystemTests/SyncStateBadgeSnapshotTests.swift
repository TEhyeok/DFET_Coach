import DesignSystem
import SnapshotTesting
import SwiftUI
import TrainerContracts
import XCTest

/// TC-DF016-01: SyncStateBadge in its five states, light and dark.
///
/// References are recorded on the CI runtime (V1-10: the trainer-app job's iOS 18 simulator). Other runtimes draw
/// text differently, so they skip. When a reference is missing, CI records it, fails, and uploads the
/// `__Snapshots__` folder as the `snapshot-references` artifact of the pull request run; commit it from there.
/// `SNAPSHOT_RECORD=1` (xcodebuild `TEST_RUNNER_SNAPSHOT_RECORD=1`) re-records on purpose.
@MainActor
final class SyncStateBadgeSnapshotTests: XCTestCase {
  static let referenceOSMajor = 18
  private var recording = false

  override func setUpWithError() throws {
    recording = ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "1"
    let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    guard recording || major == Self.referenceOSMajor else {
      throw XCTSkip("snapshot references are recorded on iOS \(Self.referenceOSMajor) (CI); this runtime is iOS \(major)")
    }
  }

  func test_TC_DF016_01_syncStateBadgeLightAndDark() throws {
    let localize = try AppCatalog.localizer()
    for style in [UIUserInterfaceStyle.light, .dark] {
      for state in SyncState.allCases {
        let failed = state == .syncFailed
        let badge = SyncStateBadge(
          state: state, reasonKey: failed ? "sync.reason.network" : nil, onRetry: failed ? {} : nil, localize: localize)
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
