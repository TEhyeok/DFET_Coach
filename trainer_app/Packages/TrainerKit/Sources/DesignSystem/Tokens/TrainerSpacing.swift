import CoreGraphics

/// Spacing and size tokens (DF-016). `minTapTarget` is the 44×44 pt floor for every interactive component
/// (F-VIZ-07.7, A-04, AC-DF-016.4).
public enum TrainerSpacing {
  public static let xxs: CGFloat = 2
  public static let xs: CGFloat = 4
  public static let s: CGFloat = 8
  public static let m: CGFloat = 12
  public static let l: CGFloat = 16
  public static let xl: CGFloat = 24
  public static let xxl: CGFloat = 32
  public static let cornerRadius: CGFloat = 8
  public static let minTapTarget: CGFloat = 44
}
