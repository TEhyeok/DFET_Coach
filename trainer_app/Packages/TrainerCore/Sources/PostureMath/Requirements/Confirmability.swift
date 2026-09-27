import TrainerContracts

/// Why a draft cannot be confirmed yet, besides missing or unconfirmed landmarks (V1-09 §5.8).
public enum ConfirmBlocker: Equatable, Hashable, Sendable {
  /// The assessment needs `front` and exactly one sagittal view (F-ASM-01.1).
  case viewsIncomplete
  /// V-POS-03: points closer than 1 px.
  case degenerateGeometry(MetricCode)
  /// V-POS-04: a front pair less than 2% of the image width apart ('두 점이 너무 가까워요').
  case pairTooClose(MetricCode)
  /// V-POS-05: the subject's left point is not to the right of its right point in the front view ('좌우가 바뀐 것 같아요').
  case sidesSwapped(MetricCode)
  /// V-POS-07: a landmark code that does not belong to the view.
  case landmarkNotInView(LandmarkCode)
}

public struct Confirmability: Equatable, Sendable {
  public var canConfirm: Bool
  /// Required landmarks not placed yet ('지정 필요').
  public var missing: [LandmarkCode]
  /// Placed landmarks that block: manual-required ones still `auto`, or any not confirmed (AC-ASM-02.1).
  public var blockingLandmarks: [LandmarkCode]
  public var blockingReasons: [ConfirmBlocker]

  public init(canConfirm: Bool, missing: [LandmarkCode], blockingLandmarks: [LandmarkCode],
              blockingReasons: [ConfirmBlocker] = []) {
    self.canConfirm = canConfirm
    self.missing = missing
    self.blockingLandmarks = blockingLandmarks
    self.blockingReasons = blockingReasons
  }
}

public enum PostureConfirmation {
  /// V1-09 §4.4. The pelvic metric counts only when enabled, and only when at least one ASIS is placed; then both must
  /// be valid. With none placed the pelvic metric is simply not computed (F-ASM-04.2).
  public static func confirmability(views: [PostureViewInput], options: MetricOptions = MetricOptions())
    -> Confirmability
  {
    var missing: [LandmarkCode] = []
    var blocking: [LandmarkCode] = []
    var reasons: [ConfirmBlocker] = []

    let fronts = views.filter { $0.view == .front }
    let sagittals = views.filter { $0.view != .front }
    if fronts.count != 1 || sagittals.count != 1 { reasons.append(.viewsIncomplete) }

    for input in views {
      let placed = input.byCode
      for metric in LandmarkRequirements.metrics(on: input.view, options: options) {
        let required = LandmarkRequirements.required(metric, sagittal: input.view)
        if metric == .pelvicTiltFrontal, !required.contains(where: { placed[$0] != nil }) { continue }
        for code in required {
          guard let landmark = placed[code] else {
            missing.append(code)
            continue
          }
          if LandmarkRequirements.manualRequired.contains(code), landmark.origin == .auto {
            blocking.append(code)
          } else if !landmark.confirmed {
            blocking.append(code)
          }
        }
      }
      reasons += geometryBlockers(input, options: options)
    }
    return Confirmability(
      canConfirm: missing.isEmpty && blocking.isEmpty && reasons.isEmpty,
      missing: missing, blockingLandmarks: blocking, blockingReasons: reasons)
  }

  /// V-POS-03, 04, 05 and 07 for one view. They block confirmation but never block the preview computation.
  public static func geometryBlockers(_ input: PostureViewInput, options: MetricOptions = MetricOptions())
    -> [ConfirmBlocker]
  {
    var reasons: [ConfirmBlocker] = []
    let allowed = LandmarkRequirements.codes(in: input.view)
    for landmark in input.landmarks where !allowed.contains(landmark.code) {
      reasons.append(.landmarkNotInView(landmark.code))
    }
    guard input.imageSize.width > 0, input.imageSize.height > 0 else { return reasons }
    switch input.view {
    case .sagittalLeft, .sagittalRight:
      let tragus = LandmarkRequirements.tragus(for: input.view)
      if let t = try? input.corrected(tragus), let c = try? input.corrected(.c7) {
        let vx = t.x - c.x
        let vy = t.y - c.y
        if (vx * vx + vy * vy).squareRoot() < 1 { reasons.append(.degenerateGeometry(.craniovertebralAngle)) }
      }
    case .front:
      for metric in LandmarkRequirements.metrics(on: .front, options: options) {
        let codes = LandmarkRequirements.required(metric)
        guard let l = try? input.corrected(codes[0]), let r = try? input.corrected(codes[1]) else { continue }
        let dx = l.x - r.x
        if abs(dx) < 1 {
          reasons.append(.degenerateGeometry(metric))
        } else if abs(dx) < 0.02 * input.imageSize.width {
          reasons.append(.pairTooClose(metric))
        }
        if l.x <= r.x { reasons.append(.sidesSwapped(metric)) }
      }
    }
    return reasons
  }
}
