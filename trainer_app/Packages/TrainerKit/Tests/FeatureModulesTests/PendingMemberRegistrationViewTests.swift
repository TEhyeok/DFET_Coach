import SwiftUI
import TrainerDomain
import XCTest
@testable import FeatureConsent

/// TR-14 sex options (DF-108), with the app's words: side by side only while every label fits on one line, and
/// stacked inside the row even at the largest accessibility text sizes in a 1/3 Split View window (V1-07 §3.3,
/// TC-X-A11Y-01). Each `ViewThatFits` candidate is checked on its own, and what is drawn is checked, not the reported
/// size: a button reports at most the width it is offered even when its one-line label runs past it.
@MainActor
final class PendingMemberRegistrationViewTests: XCTestCase {
  /// A 320 pt compact inset Form leaves a row about 240 pt wide.
  private let narrowRow: CGFloat = 240

  private func choice() throws -> SexChoice {
    let catalog = try AppCatalog.values()
    let choice = SexChoice(selection: .constant(nil), localize: { catalog[$0] ?? $0 })
    XCTAssertEqual(SexChoice.label(.unspecified, localize: choice.localize), "밝히지 않음")
    return choice
  }

  private func fittingSize(_ view: some View, width: CGFloat, _ size: DynamicTypeSize) -> CGSize {
    UIHostingController(rootView: view.dynamicTypeSize(size)).sizeThatFits(in: CGSize(width: width, height: 10_000))
  }

  /// The right edge of what `view` draws in a row `width` wide, on a white canvas twice as wide.
  private func drawnMaxX(_ view: some View, width: CGFloat, _ size: DynamicTypeSize) throws -> CGFloat {
    let bounds = CGRect(x: 0, y: 0, width: width * 2, height: 600)
    let host = UIHostingController(rootView: view.dynamicTypeSize(size)
      .frame(width: width, alignment: .leading)
      .frame(width: bounds.width, height: bounds.height, alignment: .topLeading)
      .background(Color.white))
    let window = UIWindow(frame: bounds)  // without a window the background is not drawn
    window.rootViewController = host
    window.isHidden = false
    defer { window.isHidden = true }
    host.view.frame = bounds
    host.view.layoutIfNeeded()
    let image = UIGraphicsImageRenderer(bounds: bounds).image { host.view.layer.render(in: $0.cgContext) }
    let cgImage = try XCTUnwrap(image.cgImage)
    let bytes = try XCTUnwrap(CFDataGetBytePtr(cgImage.dataProvider?.data))
    var maxX = 0
    for y in 0..<cgImage.height {
      for x in 0..<cgImage.width {
        let pixel = y * cgImage.bytesPerRow + x * cgImage.bitsPerPixel / 8
        if (0..<3).contains(where: { bytes[pixel + $0] < 200 }) { maxX = max(maxX, x) }
      }
    }
    return CGFloat(maxX + 1) / image.scale
  }

  /// Stacked labels wrap instead of running past the row or being cut ('밝히지 않음'); at the default size they keep
  /// one line.
  func testStackedOptionsWrapInsideANarrowRowAtLargeTextSizes() throws {
    let choice = try choice()
    for size in [DynamicTypeSize.accessibility3, .accessibility5] {
      XCTAssertLessThanOrEqual(try drawnMaxX(choice.stacked, width: narrowRow, size), narrowRow, "\(size)")
      XCTAssertGreaterThan(fittingSize(choice.stacked, width: narrowRow, size).height,
                           fittingSize(choice.stacked, width: 600, size).height, "\(size): a long label wraps")
    }
    XCTAssertEqual(fittingSize(choice.stacked, width: narrowRow, .large).height,
                   fittingSize(choice.stacked, width: 600, .large).height, "one line each at the default size")
  }

  /// Side by side, labels never wrap ('여/성'): in a narrow row that candidate is too wide, so the options stack.
  func testSideBySideKeepsOneLineLabelsAndFitsOnlyAWideRow() throws {
    let choice = try choice()
    XCTAssertGreaterThan(fittingSize(choice.sideBySide, width: narrowRow, .large).width, narrowRow)
    let wide = fittingSize(choice.sideBySide, width: 600, .large)
    XCTAssertLessThanOrEqual(wide.width, 600)
    XCTAssertEqual(fittingSize(choice, width: 600, .large).height, wide.height,
                   "a wide row keeps the options side by side")
  }
}
