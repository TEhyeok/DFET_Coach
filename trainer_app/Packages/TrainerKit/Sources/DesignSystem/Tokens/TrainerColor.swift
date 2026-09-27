import SwiftUI
import UIKit

/// Trainer app colour tokens (DF-016). Q-10 is open, so these are the DEC-21 defaults: a neutral grey scale and the
/// brand blue (ASM-P0-21). The four-axis colours of the old app are not carried over (§8.5).
///
/// `success` (green) means "saved to the server / completed" and nothing else: only `SyncStateBadge(.synced)` and
/// completed-state marks use it (dfet:design.md:111, AC-DF-016.2; `DesignSystemSourceTests` checks the call sites).
/// `danger` is for error text only.
public enum TrainerColor {
  public static let neutral50 = dynamic(light: 0xFAFAFA, dark: 0x18181B)
  public static let neutral100 = dynamic(light: 0xF4F4F5, dark: 0x27272A)
  public static let neutral200 = dynamic(light: 0xE4E4E7, dark: 0x3F3F46)
  public static let neutral300 = dynamic(light: 0xD4D4D8, dark: 0x52525B)
  public static let neutral400 = dynamic(light: 0xA1A1AA, dark: 0x71717A)
  public static let neutral500 = dynamic(light: 0x71717A, dark: 0xA1A1AA)
  public static let neutral600 = dynamic(light: 0x52525B, dark: 0xD4D4D8)
  public static let neutral700 = dynamic(light: 0x3F3F46, dark: 0xE4E4E7)
  public static let neutral800 = dynamic(light: 0x27272A, dark: 0xF4F4F5)
  public static let neutral900 = dynamic(light: 0x18181B, dark: 0xFAFAFA)
  public static let brandBlue = dynamic(light: 0x1D4ED8, dark: 0x60A5FA)
  public static let success = dynamic(light: 0x15803D, dark: 0x4ADE80)
  public static let caution = dynamic(light: 0xB45309, dark: 0xFBBF24)
  public static let danger = dynamic(light: 0xB91C1C, dark: 0xF87171)

  /// Light and dark sRGB values; both pass WCAG AA (4.5:1) as text on `neutral50`.
  static func dynamic(light: UInt32, dark: UInt32) -> Color {
    Color(uiColor: UIColor { traits in
      rgb(traits.userInterfaceStyle == .dark ? dark : light)
    })
  }

  static func rgb(_ hex: UInt32) -> UIColor {
    UIColor(
      red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
  }
}
