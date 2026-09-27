import Foundation
import TrainerContracts

/// A capture station as the capture flow sees it (DF-203). Device-local; posture documents keep only `id`
/// (`stationProfileId`) and the values at capture time (`captureConditions`).
public struct StationProfileValue: Equatable, Sendable {
  public let id: String
  /// Display name, or a string-catalog key for the built-in default station.
  public let name: String
  public let cameraHeightCm: Double
  public let cameraDistanceM: Double
  public let protocolVersion: String

  public init(id: String, name: String, cameraHeightCm: Double, cameraDistanceM: Double, protocolVersion: String) {
    self.id = id
    self.name = name
    self.cameraHeightCm = cameraHeightCm
    self.cameraDistanceM = cameraDistanceM
    self.protocolVersion = protocolVersion
  }
}

/// The one station of the DEC-22 MVP. Its values come from the generated protocol, never from code constants
/// (ASM-P1b-05): the middle of the draft camera ranges. If DF-915 confirms different ranges, the id moves to
/// `default-v2` so documents recorded against `default-v1` keep their meaning.
public enum DefaultStation {
  public static let id = "default-v1"
  public static let nameKey = "tr07.station.default"

  public static var cameraHeightCm: Double { middle(PostureProtocolV1.cameraHeightCm) }
  public static var cameraDistanceM: Double { middle(PostureProtocolV1.cameraDistanceM) }

  public static var profile: StationProfileValue {
    StationProfileValue(
      id: id, name: nameKey, cameraHeightCm: cameraHeightCm, cameraDistanceM: cameraDistanceM,
      protocolVersion: PostureProtocolV1.protocolVersion)
  }

  private static func middle(_ range: ClosedRange<Double>) -> Double {
    (range.lowerBound + range.upperBound) / 2
  }
}

/// `postureAssessments.captureConditions` (V1-05 §4.6). With both angles set, `jsonValue` has exactly the keys of
/// the rules' `captureConditions.keys().hasOnly([...])` list (CaptureTests reads firestore.rules).
public struct CaptureConditions: Equatable, Sendable {
  public var clothing: Clothing
  public var barefoot: Bool
  public var markersPlaced: Bool
  public var verbalConsentCheck: Bool
  public var cameraHeightCm: Double
  public var cameraDistanceM: Double
  /// Filled by the shutter at capture time (DF-204).
  public var levelDeg: Double?
  public var pitchDeg: Double?

  /// The document map. `levelDeg` and `pitchDeg` are left out until DF-204 measures them.
  public var jsonValue: JSONValue {
    var fields: [String: JSONValue] = [
      "clothing": .string(clothing.rawValue),
      "barefoot": .bool(barefoot),
      "markersPlaced": .bool(markersPlaced),
      "verbalConsentCheck": .bool(verbalConsentCheck),
      "cameraHeightCm": .number(cameraHeightCm),
      "cameraDistanceM": .number(cameraDistanceM),
    ]
    if let levelDeg { fields["levelDeg"] = .number(levelDeg) }
    if let pitchDeg { fields["pitchDeg"] = .number(pitchDeg) }
    return .object(fields)
  }
}

public enum CaptureConditionsBuilder {
  /// DEC-22 MVP form: the chosen clothing and the station's camera values. The three checklist booleans are `false`,
  /// meaning "not checked" (the checklist arrives after the MVP); they are never written `true` without a check.
  public static func build(profile: StationProfileValue, clothing: Clothing) -> CaptureConditions {
    CaptureConditions(
      clothing: clothing, barefoot: false, markersPlaced: false, verbalConsentCheck: false,
      cameraHeightCm: profile.cameraHeightCm, cameraDistanceM: profile.cameraDistanceM, levelDeg: nil, pitchDeg: nil)
  }
}

/// What the trainer confirms before shooting. MVP: clothing only, chosen again for every new draft.
public struct CaptureChecklist: Equatable, Sendable {
  public var clothing: Clothing?

  public init(clothing: Clothing? = nil) {
    self.clothing = clothing
  }

  /// A new session (new draft) starts unchecked (AC-DF-203.3).
  public mutating func reset() {
    clothing = nil
  }
}

/// Why the shutter is blocked. No raw type: DF-204 adds reasons that carry values (V1-09 §3.2).
public enum ShutterBlockReason: Equatable, Sendable {
  case clothingNotSelected
}

/// Whether the shutter may fire (DF-203 MVP part; DF-204 adds the level conditions).
public struct ShutterGate: Equatable, Sendable {
  public let reasons: [ShutterBlockReason]
  public var canShoot: Bool { reasons.isEmpty }

  public static func evaluate(_ checklist: CaptureChecklist) -> ShutterGate {
    ShutterGate(reasons: checklist.clothing == nil ? [.clothingNotSelected] : [])
  }
}
