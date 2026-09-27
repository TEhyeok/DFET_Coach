import SwiftUI
import UIKit
@testable import DesignSystem
import TrainerContracts
import XCTest

/// AC-DF-016.1: the five states and their only wording; a failure has its reason and '다시 시도'.
@MainActor
final class SyncStateBadgeTests: XCTestCase {
  func test_AC_DF_016_1_theFiveStatesUseTheDeckWords() throws {
    let localize = try AppCatalog.localizer()
    let words = SyncState.allCases.map { localize(SyncStateBadge.labelKey($0)) }
    XCTAssertEqual(words, ["기기에 저장됨", "동기화 중", "동기화됨", "동기화 실패", "동의 확인 대기"])
  }

  /// AC-DF-016.2 by behaviour: every state has its token, and only `.synced` is green, in light and dark.
  func test_AC_DF_016_2_onlySyncedIsGreen() {
    func resolved(_ color: Color, _ style: UIUserInterfaceStyle) -> UIColor {
      UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
    }
    let expected: [SyncState: Color] = [
      .localSaved: TrainerColor.neutral600, .syncing: TrainerColor.neutral600, .synced: TrainerColor.success,
      .syncFailed: TrainerColor.danger, .awaitingConsent: TrainerColor.caution,
    ]
    for style in [UIUserInterfaceStyle.light, .dark] {
      let green = resolved(TrainerColor.success, style)
      for state in SyncState.allCases {
        let tint = resolved(SyncStateBadge.tint(state), style)
        XCTAssertEqual(tint, resolved(expected[state]!, style), "\(state) \(style.rawValue)")
        XCTAssertEqual(tint == green, state == .synced, "\(state) \(style.rawValue)")
      }
    }
  }

  func testAFailedBadgeIsTallerWithItsReasonAndRetry() throws {
    let localize = try AppCatalog.localizer()
    func height(_ view: some View) -> CGFloat {
      UIHostingController(rootView: view).sizeThatFits(in: CGSize(width: 320, height: 600)).height
    }
    let plain = height(SyncStateBadge(state: .syncFailed, localize: localize))
    let full = height(SyncStateBadge(state: .syncFailed, reasonKey: "sync.reason.ruleDenied", onRetry: {}, localize: localize))
    XCTAssertGreaterThanOrEqual(full - plain, 44, "the retry button adds at least a 44 pt row")
  }
}
