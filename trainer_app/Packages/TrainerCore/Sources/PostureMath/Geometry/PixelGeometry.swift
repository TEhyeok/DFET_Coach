import Foundation

/// A stored landmark coordinate: 0...1, origin at the top left of the upright image, y down (V1-09 §2).
public struct NormalizedPoint: Codable, Hashable, Sendable {
  public var x: Double
  public var y: Double

  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }
}

/// Size of the upright image in pixels.
public struct PixelSize: Hashable, Sendable {
  public var width: Double
  public var height: Double

  public init(width: Double, height: Double) {
    self.width = width
    self.height = height
  }
}

/// A point in pixels of the upright image (y down). Kept free of CoreGraphics so the package stays platform-neutral.
public struct PixelPoint: Hashable, Sendable {
  public var x: Double
  public var y: Double

  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }
}

/// Pixel conversion and roll correction (V1-09 §2.4). Angles are measured on pixels, never on normalized coordinates:
/// with a non-square image the normalized angle is wrong (AC-ASM-03.4).
public enum PixelGeometry {
  public static func toPixel(_ point: NormalizedPoint, in size: PixelSize) -> PixelPoint {
    PixelPoint(x: point.x * size.width, y: point.y * size.height)
  }

  /// Rotates about the image centre; positive degrees turn counter-clockwise on screen in the y-down frame:
  /// `x' = cx + dx·cos t + dy·sin t`, `y' = cy − dx·sin t + dy·cos t`.
  public static func rotateAboutCenter(_ point: PixelPoint, degrees: Double, in size: PixelSize) -> PixelPoint {
    let cx = size.width / 2
    let cy = size.height / 2
    let dx = point.x - cx
    let dy = point.y - cy
    let t = degrees * .pi / 180
    return PixelPoint(x: cx + dx * cos(t) + dy * sin(t), y: cy - dx * sin(t) + dy * cos(t))
  }

  /// Tolerance of the 1 px boundary, in pixels. Far above the rounding error of pixel values up to about 10⁴ (about
  /// 10⁻¹² px) and far below any distance a trainer can place.
  static let onePixelTolerance = 1e-9

  /// Whether a pixel distance is under 1 px: the level rule (F-ASM-03.4) and V-POS-03 (V1-09 §5.6, §5.8). A gap of
  /// exactly one pixel can come out a hair under 1 after the conversion (0.5005 × 2000 = 1000.9999999999999), so it
  /// still counts as 1 px. The only epsilon of PostureMath; rounding has none (§1.3).
  static func isUnderOnePixel(_ distance: Double) -> Bool {
    abs(distance) < 1 - onePixelTolerance
  }
}
