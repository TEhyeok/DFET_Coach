/// Global feature flags from `appConfig/features` (ADR-010, V1-05 §4.17). A missing document or key is `false`.
///
/// DF-017 defines the value type with all eight keys and `.allOff`. DF-027 replaces `Key` with the generated
/// `FeatureFlagKey` (contracts/feature-flags.v1.json) and adds `init(map:)`. The Firestore subscription arrives in
/// P1a (FirebaseData); until then the app uses `FixedFeatureFlagsProvider.allOff`.
public struct FeatureFlags: Equatable, Hashable, Sendable {
  /// Key names as stored in `appConfig/features`. Temporary constants until DF-027 generates them.
  public enum Key: String, CaseIterable, Sendable {
    case gut, blood, insights
    case soapV2, bodyComposition, bodyAssessment, memberShare, lidarBeta
  }

  // Existing member-app flags (D4). The trainer app gates no entry point on them.
  public var gut: Bool
  public var blood: Bool
  public var insights: Bool
  // New v1 flags (ADR-010 §3-1). All default to false.
  public var soapV2: Bool
  public var bodyComposition: Bool
  public var bodyAssessment: Bool
  public var memberShare: Bool
  public var lidarBeta: Bool

  public init(
    gut: Bool = false, blood: Bool = false, insights: Bool = false,
    soapV2: Bool = false, bodyComposition: Bool = false, bodyAssessment: Bool = false,
    memberShare: Bool = false, lidarBeta: Bool = false
  ) {
    self.gut = gut
    self.blood = blood
    self.insights = insights
    self.soapV2 = soapV2
    self.bodyComposition = bodyComposition
    self.bodyAssessment = bodyAssessment
    self.memberShare = memberShare
    self.lidarBeta = lidarBeta
  }

  /// Every key false: the default when the document or a key is missing.
  public static let allOff = FeatureFlags()

  /// Flags with exactly the given keys switched on.
  public init(enabled keys: Set<Key>) {
    self.init()
    for key in keys {
      self[key] = true
    }
  }

  public subscript(key: Key) -> Bool {
    get {
      switch key {
      case .gut: return gut
      case .blood: return blood
      case .insights: return insights
      case .soapV2: return soapV2
      case .bodyComposition: return bodyComposition
      case .bodyAssessment: return bodyAssessment
      case .memberShare: return memberShare
      case .lidarBeta: return lidarBeta
      }
    }
    set {
      switch key {
      case .gut: gut = newValue
      case .blood: blood = newValue
      case .insights: insights = newValue
      case .soapV2: soapV2 = newValue
      case .bodyComposition: bodyComposition = newValue
      case .bodyAssessment: bodyAssessment = newValue
      case .memberShare: memberShare = newValue
      case .lidarBeta: lidarBeta = newValue
      }
    }
  }
}

/// Source of the current flags. P1a adds a FirebaseData implementation that observes `appConfig/features`.
public protocol FeatureFlagsProvider: Sendable {
  var current: FeatureFlags { get }
}

/// A provider that always returns the same flags. Live builds use `.allOff` until P1a.
public struct FixedFeatureFlagsProvider: FeatureFlagsProvider {
  public let current: FeatureFlags

  public init(_ flags: FeatureFlags) {
    current = flags
  }

  public static let allOff = FixedFeatureFlagsProvider(.allOff)
}
