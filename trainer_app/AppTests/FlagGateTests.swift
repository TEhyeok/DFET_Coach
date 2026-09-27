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
    XCTAssertEqual(FlagGate.visibleEntries(on: .measureMenu, flags: .allOff), [], "no item, no '측정 입력' menu")
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
    XCTAssertEqual(FlagGate.visibleEntries(on: .measureMenu, flags: flags), [])
  }

  /// AC-DF-127.11: TR-03 '측정 입력' holds '신체조성' (TR-11 sheet) and '둘레(줄자)' (DF-129, coming soon); both follow
  /// `bodyComposition`, so the flag off leaves neither the items nor the menu.
  func testMeasureMenuFollowsBodyComposition_AC_DF_127_11() {
    let on = FeatureFlags(enabled: [.bodyComposition])
    XCTAssertEqual(FlagGate.visibleEntries(on: .measureMenu, flags: on), [.bodyComposition, .circumference])
    XCTAssertEqual(FlagGate.visibleEntries(on: .measureMenu, flags: on).map(\.titleKey),
                   ["tr03.measureMenu.bodyComposition", "tr03.measureMenu.circumference"])
    XCTAssertEqual(EntryPoint.bodyComposition.destination, .bodyCompositionEntry)
    XCTAssertEqual(EntryPoint.circumference.destination, .comingSoon)
    let off = FeatureFlags(enabled: Set(FeatureFlags.Key.allCases).subtracting([.bodyComposition]))
    XCTAssertEqual(FlagGate.visibleEntries(on: .measureMenu, flags: off), [])
  }

  /// AC-DF-017.5: gated entries without a screen yet open `common.comingSoon` when a DEBUG override turns them on.
  /// TR-11 is the first with a screen (DF-127).
  func testGatedEntriesOpenComingSoon_AC_DF_017_5() {
    for entry in EntryPoint.allCases where entry.surface != .sidebar {
      XCTAssertEqual(entry.destination, entry == .bodyComposition ? .bodyCompositionEntry : .comingSoon, entry.rawValue)
      XCTAssertTrue(entry.accessibilityID.hasPrefix("tr03.entry."), entry.rawValue)
    }
    XCTAssertEqual(EntryPoint.today.destination, .route(.today))
    XCTAssertEqual(EntryPoint.members.destination, .route(.members))
    XCTAssertEqual(EntryPoint.settings.destination, .route(.settings))
    XCTAssertEqual(EntryPoint.allCases.filter { $0.surface == .sidebar }.map(\.accessibilityID),
                   ["nav.today", "nav.members", "nav.settings"])
  }
}
