import TrainerDomain
import XCTest

/// TC-DF017-02 (AC-DF-017.2, AC-IA-02): `FlagGate` over every flag key x every entry point.
final class FlagGateTests: XCTestCase {
  /// Which single key makes each gated entry visible. Entries missing here are always visible.
  private let requiredKeys: [EntryPoint: Set<FeatureFlags.Key>] = [
    .startSession: [.soapV2],
    .bodyComposition: [.bodyComposition],
    .circumference: [.bodyComposition],
    .postureCapture: [.bodyAssessment],
    .compare: [.bodyAssessment, .bodyComposition],
    .share: [.memberShare],
    .lidar: [.lidarBeta],
  ]

  /// DEC-22 MVP: TR-01 is hidden by `ShellScope.showsToday`, so the sidebar is 회원·설정 (DF-017 MVP section).
  func testAllOffShowsOnlyMembersSettings_AC_DF_017_2() {
    XCTAssertFalse(ShellScope.showsToday)
    XCTAssertEqual(FlagGate.visibleEntries(on: .sidebar, flags: .allOff), [.members, .settings])
    XCTAssertEqual(FlagGate.visibleEntries(on: .memberDetail, flags: .allOff), [])
    let visible = EntryPoint.allCases.filter { FlagGate.isEntryVisible($0, flags: .allOff) }
    XCTAssertEqual(visible.map(\.trID), ["TR-02", "TR-15"])
  }

  func testEachKeyAloneTable_TC_DF017_02() {
    for key in FeatureFlags.Key.allCases {
      let flags = FeatureFlags(enabled: [key])
      for entry in EntryPoint.allCases {
        let expected = entry == .today ? ShellScope.showsToday : (requiredKeys[entry].map { $0.contains(key) } ?? true)
        XCTAssertEqual(FlagGate.isEntryVisible(entry, flags: flags), expected, "\(key.rawValue) on, \(entry.rawValue)")
      }
    }
  }

  func testAllOnShowsEveryEntry() {
    let flags = FeatureFlags(enabled: Set(FeatureFlags.Key.allCases))
    XCTAssertEqual(EntryPoint.allCases.filter { FlagGate.isEntryVisible($0, flags: flags) },
                   EntryPoint.allCases.filter { $0 != .today || ShellScope.showsToday })
  }

  func testMemberAppFlagsGateNothingInTheTrainerApp() {
    let flags = FeatureFlags(gut: true, blood: true, insights: true)
    XCTAssertEqual(FlagGate.visibleEntries(on: .memberDetail, flags: flags), [])
  }

  /// AC-DF-017.5: gated entries have no screen yet, so a DEBUG override that turns them on opens `common.comingSoon`.
  func testGatedEntriesOpenComingSoon_AC_DF_017_5() {
    for entry in EntryPoint.allCases where entry.surface == .memberDetail {
      XCTAssertEqual(entry.destination, .comingSoon, entry.rawValue)
      XCTAssertTrue(entry.accessibilityID.hasPrefix("tr03.entry."), entry.rawValue)
    }
    XCTAssertEqual(EntryPoint.today.destination, .route(.today))
    XCTAssertEqual(EntryPoint.members.destination, .route(.members))
    XCTAssertEqual(EntryPoint.settings.destination, .route(.settings))
    XCTAssertEqual(EntryPoint.allCases.filter { $0.surface == .sidebar }.map(\.accessibilityID),
                   ["nav.today", "nav.members", "nav.settings"])
  }
}
