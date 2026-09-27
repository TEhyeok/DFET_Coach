import DesignSystem
import SwiftUI
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

  func testAFailedBadgeIsTallerWithItsReasonAndRetry() throws {
    let localize = try AppCatalog.localizer()
    func height(_ view: some View) -> CGFloat {
      UIHostingController(rootView: view).sizeThatFits(in: CGSize(width: 320, height: 600)).height
    }
    let plain = height(SyncStateBadge(state: .syncFailed, localize: localize))
    let full = height(SyncStateBadge(state: .syncFailed, reasonKey: "sync.reason.network", onRetry: {}, localize: localize))
    XCTAssertGreaterThanOrEqual(full - plain, 44, "the retry button adds at least a 44 pt row")
  }
}
