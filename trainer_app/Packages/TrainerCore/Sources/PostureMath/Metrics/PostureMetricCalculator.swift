import Foundation
import TrainerContracts

public enum LandmarkOrigin: String, Codable, Sendable {
  case auto
  case manual
}

/// The automatic suggestion a landmark started from (V1-09 §4.3).
public struct SuggestedPoint: Codable, Hashable, Sendable {
  public var x: Double
  public var y: Double
  public var confidence: Double

  public init(x: Double, y: Double, confidence: Double) {
    self.x = x
    self.y = y
    self.confidence = confidence
  }
}

/// One stored landmark. Encoded flat as `{code, x, y, origin, confirmed, suggested?}` (PRD §9.2).
public struct LandmarkValue: Codable, Hashable, Sendable {
  public var code: LandmarkCode
  public var point: NormalizedPoint
  public var origin: LandmarkOrigin
  public var confirmed: Bool
  public var suggested: SuggestedPoint?

  public init(code: LandmarkCode, point: NormalizedPoint, origin: LandmarkOrigin, confirmed: Bool,
              suggested: SuggestedPoint? = nil) {
    self.code = code
    self.point = point
    self.origin = origin
    self.confirmed = confirmed
    self.suggested = suggested
  }

  private enum CodingKeys: String, CodingKey { case code, x, y, origin, confirmed, suggested }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    code = try c.decode(LandmarkCode.self, forKey: .code)
    point = NormalizedPoint(x: try c.decode(Double.self, forKey: .x), y: try c.decode(Double.self, forKey: .y))
    origin = try c.decode(LandmarkOrigin.self, forKey: .origin)
    confirmed = try c.decode(Bool.self, forKey: .confirmed)
    suggested = try c.decodeIfPresent(SuggestedPoint.self, forKey: .suggested)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(code, forKey: .code)
    try c.encode(point.x, forKey: .x)
    try c.encode(point.y, forKey: .y)
    try c.encode(origin, forKey: .origin)
    try c.encode(confirmed, forKey: .confirmed)
    try c.encodeIfPresent(suggested, forKey: .suggested)
  }
}

public struct MetricOptions: Hashable, Sendable {
  /// `pelvicTiltFrontal` is a reference metric that is off by default (AC-ASM-03.6).
  public var includePelvicTilt: Bool

  public init(includePelvicTilt: Bool = false) {
    self.includePelvicTilt = includePelvicTilt
  }
}

public struct PostureMetricResult: Equatable, Sendable {
  public var metricCode: MetricCode
  /// Degrees, rounded half away from zero to one decimal.
  public var value: Double
  public var unit: String
  public var side: Side
  /// `photoManual` when every landmark the metric uses is confirmed, otherwise `photoAuto` (V1-09 §5.7).
  public var sourceGrade: SourceGrade

  public init(metricCode: MetricCode, value: Double, unit: String = "deg", side: Side, sourceGrade: SourceGrade) {
    self.metricCode = metricCode
    self.value = value
    self.unit = unit
    self.side = side
    self.sourceGrade = sourceGrade
  }
}

public enum PostureMathError: Error, Equatable, Sendable {
  /// A coordinate outside 0...1 (V-POS-01, AC-ASM-02.4). The whole computation is refused.
  case coordinateOutOfRange(LandmarkCode)
  /// Width or height ≤ 0 (V-POS-02).
  case zeroImageSize
  /// The points are closer than 1 px, so no angle exists (V-POS-03).
  case degenerateGeometry(MetricCode)
  /// `imageRotationDeg` is not a finite number.
  case invalidRotation
}

/// One view of an assessment, as the calculator and the confirmability rule read it.
public struct PostureViewInput: Sendable {
  public var view: PostureView
  public var imageSize: PixelSize
  /// Roll correction in degrees (tenths), 0 when the photo needed none (DF-204 MVP imports).
  public var imageRotationDeg: Double
  public var landmarks: [LandmarkValue]

  public init(view: PostureView, imageSize: PixelSize, imageRotationDeg: Double, landmarks: [LandmarkValue]) {
    self.view = view
    self.imageSize = imageSize
    self.imageRotationDeg = imageRotationDeg
    self.landmarks = landmarks
  }

  var byCode: [LandmarkCode: LandmarkValue] {
    Dictionary(landmarks.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })
  }

  /// Roll-corrected pixel point of `code`, nil when the landmark is not placed.
  func corrected(_ code: LandmarkCode) throws -> PixelPoint? {
    guard let landmark = byCode[code] else { return nil }
    try Self.validate(landmark)
    guard imageSize.width > 0, imageSize.height > 0 else { throw PostureMathError.zeroImageSize }
    let pixel = PixelGeometry.toPixel(landmark.point, in: imageSize)
    return PixelGeometry.rotateAboutCenter(pixel, degrees: imageRotationDeg, in: imageSize)
  }

  func grade(_ codes: [LandmarkCode]) -> SourceGrade {
    let landmarks = byCode
    return codes.allSatisfy { landmarks[$0]?.confirmed == true } ? .photoManual : .photoAuto
  }

  static func validate(_ landmark: LandmarkValue) throws {
    guard (0...1).contains(landmark.point.x), (0...1).contains(landmark.point.y) else {
      throw PostureMathError.coordinateOutOfRange(landmark.code)
    }
  }
}

/// Posture metrics of one view (V1-09 §5, PRD F-ASM-03.3). `front` gives head tilt, shoulder tilt and, when enabled,
/// pelvic tilt; a sagittal view gives the craniovertebral angle. A metric whose landmarks are not all placed is left
/// out (not 0). The same input always gives bit-identical output (AC-ASM-02.5).
public enum PostureMetricCalculator {
  public static func computeMetrics(
    view: PostureView, imageSize: PixelSize, imageRotationDeg: Double, landmarks: [LandmarkValue],
    options: MetricOptions = MetricOptions()
  ) throws -> [PostureMetricResult] {
    try computeMetrics(
      PostureViewInput(view: view, imageSize: imageSize, imageRotationDeg: imageRotationDeg, landmarks: landmarks),
      options: options)
  }

  public static func computeMetrics(_ input: PostureViewInput, options: MetricOptions = MetricOptions())
    throws -> [PostureMetricResult]
  {
    // Every stored coordinate is checked, used or not (AC-ASM-02.4).
    for landmark in input.landmarks { try PostureViewInput.validate(landmark) }
    guard input.imageSize.width > 0, input.imageSize.height > 0 else { throw PostureMathError.zeroImageSize }
    guard input.imageRotationDeg.isFinite else { throw PostureMathError.invalidRotation }

    switch input.view {
    case .sagittalLeft, .sagittalRight:
      let tragus = LandmarkRequirements.tragus(for: input.view)
      guard let t = try input.corrected(tragus), let c = try input.corrected(.c7) else { return [] }
      let vx = t.x - c.x
      let vy = t.y - c.y
      guard (vx * vx + vy * vy).squareRoot() >= 1 else {
        throw PostureMathError.degenerateGeometry(.craniovertebralAngle)
      }
      let degrees = atan2(-vy, abs(vx)) * 180 / .pi
      return [PostureMetricResult(
        metricCode: .craniovertebralAngle, value: Rounding.roundTenth(degrees), side: .none,
        sourceGrade: input.grade([tragus, .c7]))]
    case .front:
      var results: [PostureMetricResult] = []
      results += try pair(input, .headTiltFrontal, left: .earLeft, right: .earRight, sideIsLower: true)
      results += try pair(input, .shoulderTiltAngle, left: .acromionLeft, right: .acromionRight, sideIsLower: false)
      if options.includePelvicTilt {
        results += try pair(input, .pelvicTiltFrontal, left: .asisLeft, right: .asisRight, sideIsLower: false)
      }
      return results
    }
  }

  /// Tilt of a left/right pair: `atan(|Δy| / |Δx|)`. `side` is the lower point for head tilt and the higher point for
  /// shoulder and pelvis (y grows downward), always the anatomical side of the code suffix.
  private static func pair(
    _ input: PostureViewInput, _ metric: MetricCode, left: LandmarkCode, right: LandmarkCode, sideIsLower: Bool
  ) throws -> [PostureMetricResult] {
    guard let l = try input.corrected(left), let r = try input.corrected(right) else { return [] }
    let dx = l.x - r.x
    let dy = l.y - r.y
    guard abs(dx) >= 1 else { throw PostureMathError.degenerateGeometry(metric) }
    let grade = input.grade([left, right])
    if abs(dy) < 1 {  // under 1 px: level (F-ASM-03.4)
      return [PostureMetricResult(metricCode: metric, value: 0, side: .none, sourceGrade: grade)]
    }
    let value = Rounding.roundTenth(atan(abs(dy) / abs(dx)) * 180 / .pi)
    let leftIsLower = l.y > r.y
    let side: Side = value == 0 ? .none : (leftIsLower == sideIsLower ? .left : .right)
    return [PostureMetricResult(metricCode: metric, value: value, side: side, sourceGrade: grade)]
  }
}
