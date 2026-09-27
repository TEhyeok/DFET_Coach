import TrainerContracts

/// Which landmarks each metric needs and which must be placed by hand (V1-09 §4.1, PRD appendix A.3).
public enum LandmarkRequirements {
  /// Automatic suggestions are never enough for these: the trainer palpates and places them (AC-ASM-02.1).
  public static let manualRequired: Set<LandmarkCode> = [.c7, .acromionLeft, .acromionRight, .asisLeft, .asisRight]

  /// The tragus of the side facing the camera (ASM-P1b-01).
  public static func tragus(for view: PostureView) -> LandmarkCode {
    view == .sagittalRight ? .tragusRight : .tragusLeft
  }

  /// The view a metric is computed on and its required landmarks; `sagittal` picks the tragus side.
  public static func required(_ metric: MetricCode, sagittal: PostureView = .sagittalLeft) -> [LandmarkCode] {
    switch metric {
    case .craniovertebralAngle: return [tragus(for: sagittal), .c7]
    case .headTiltFrontal: return [.earLeft, .earRight]
    case .shoulderTiltAngle: return [.acromionLeft, .acromionRight]
    case .pelvicTiltFrontal: return [.asisLeft, .asisRight]
    default: return []
    }
  }

  /// Metrics computed on `view` with `options`.
  public static func metrics(on view: PostureView, options: MetricOptions) -> [MetricCode] {
    switch view {
    case .sagittalLeft, .sagittalRight:
      return [.craniovertebralAngle]
    case .front:
      return [.headTiltFrontal, .shoulderTiltAngle] + (options.includePelvicTilt ? [.pelvicTiltFrontal] : [])
    }
  }

  /// Landmark codes that belong to `view` (V-POS-07).
  public static func codes(in view: PostureView) -> Set<LandmarkCode> {
    switch view {
    case .front: return [.earLeft, .earRight, .acromionLeft, .acromionRight, .asisLeft, .asisRight]
    case .sagittalLeft: return [.tragusLeft, .c7]
    case .sagittalRight: return [.tragusRight, .c7]
    }
  }
}
