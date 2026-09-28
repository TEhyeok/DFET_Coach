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

  /// The chip's ideal size is one line holding the whole text, icon and padding: TR-02's row decides by it whether
  /// name and chip fit on one line (the row itself is checked on screen, `MemberListUITests`).
  func testTheIdealSizeIsOneLineWithTheWholeText() throws {
    let localize = try AppCatalog.localizer()
    let unbounded = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    for state in states {
      let text = Text(localize(ConsentChip.labelKey(state))).font(.caption.weight(.medium))
      let textSize = UIHostingController(rootView: text).sizeThatFits(in: unbounded)
      let chip = ConsentChip(state: state, style: .row, localize: localize).fixedSize()
      let chipSize = UIHostingController(rootView: chip).sizeThatFits(in: unbounded)
      XCTAssertGreaterThan(chipSize.width, textSize.width + 2 * TrainerSpacing.s, "\(state): text, icon and padding")
      XCTAssertLessThan(chipSize.height, 2 * textSize.height, "\(state): one line")
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
