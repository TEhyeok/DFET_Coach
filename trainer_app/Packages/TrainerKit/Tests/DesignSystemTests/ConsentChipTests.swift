import SwiftUI
import UIKit
@testable import DesignSystem
import TrainerDomain
import XCTest

/// The consent chip shared by TR-02 rows (DF-113) and TR-14's result (DF-110): the three MVP states and their only
/// wording, one icon each, and no green (AC-DF-016.2).
@MainActor
final class ConsentChipTests: XCTestCase {
  private let states: [ConsentChipState] = [.coreGranted, .needed, .awaiting]

  func testTheThreeStatesUseTheDeckWords() throws {
    let localize = try AppCatalog.localizer()
    XCTAssertEqual(states.map { localize(ConsentChip.labelKey($0)) }, ["동의 ①②③", "동의 필요", "동의 확인 대기"])
  }

  func testEveryStateHasItsOwnIconAndNoneIsGreen() {
    XCTAssertEqual(Set(states.map(ConsentChip.symbol)).count, states.count, "icon and text, never colour alone")
    for style in [UIUserInterfaceStyle.light, .dark] {
      let traits = UITraitCollection(userInterfaceStyle: style)
      let green = UIColor(TrainerColor.success).resolvedColor(with: traits)
      for state in states {
        XCTAssertNotEqual(UIColor(ConsentChip.tint(state)).resolvedColor(with: traits), green, "\(state)")
      }
    }
  }

  /// Both styles render the text and wrap instead of truncating (AC-A11Y-02).
  func testBothStylesWrapInANarrowColumn() throws {
    let localize = try AppCatalog.localizer()
    func height(_ view: some View, width: CGFloat) -> CGFloat {
      UIHostingController(rootView: view).sizeThatFits(in: CGSize(width: width, height: 600)).height
    }
    for style in [ConsentChip.Style.row, .result] {
      let chip = ConsentChip(state: .awaiting, style: style, localize: localize)
      XCTAssertGreaterThan(height(chip, width: 60), height(chip, width: 400), "\(style)")
    }
  }
}
