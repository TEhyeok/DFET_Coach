import CoreGraphics

/// Layout of a detail screen, decided by the detail column's usable width and never by orientation
/// (NFR-12, ASM-P0-22, dfet:trainer_ios/design.md:32). SOAP screens use 1180pt from P1a.
enum LayoutMode: Equatable {
  /// Stacked, top-to-bottom reading order.
  case compact
  /// Side-by-side columns.
  case regular

  static let regularMinimumWidth: CGFloat = 1120

  static func `for`(width: CGFloat) -> LayoutMode {
    width >= regularMinimumWidth ? .regular : .compact
  }
}
