import Foundation
import PostureMath
import TrainerContracts

/// `contracts/vectors/posture-metrics.v1.json` (DF-201, V1-09 §5.10), read in place from the repository.
struct PostureVectorFile: Decodable {
  let contract: String
  let schemaVersion: Int
  let rounding: String
  let cases: [PostureVectorCase]

  static func load() throws -> PostureVectorFile {
    var url = URL(fileURLWithPath: #filePath)
    while url.pathComponents.count > 1 {
      url.deleteLastPathComponent()
      let candidate = url.appendingPathComponent("contracts/vectors/posture-metrics.v1.json")
      if FileManager.default.fileExists(atPath: candidate.path) {
        return try JSONDecoder().decode(PostureVectorFile.self, from: Data(contentsOf: candidate))
      }
    }
    throw CocoaError(.fileNoSuchFile)
  }
}

struct PostureVectorCase: Decodable {
  struct Image: Decodable { let width: Double; let height: Double }
  struct Options: Decodable { let includePelvicTilt: Bool? }
  struct Expected: Decodable, Equatable {
    let metricCode: MetricCode
    let value: Double
    let unit: String
    let side: Side
    let sourceGrade: SourceGrade
  }
  struct Reason: Decodable { let reason: String; let metricCode: MetricCode? }
  struct ExpectedError: Decodable { let error: String; let metricCode: MetricCode? }
  struct RoundingCase: Decodable { let input: Double; let expected: Double }
  struct View: Decodable {
    let view: PostureView
    let image: Image
    let imageRotationDeg: Double
    let landmarks: [LandmarkValue]
  }
  struct ExpectedConfirmability: Decodable {
    let canConfirm: Bool
    let missing: [LandmarkCode]
    let blockingLandmarks: [LandmarkCode]
  }

  let id: String
  let trace: [String]
  let kind: String?
  let view: PostureView?
  let image: Image?
  let imageRotationDeg: Double?
  let options: Options?
  let landmarks: [LandmarkValue]?
  let expected: [Expected]?
  let expectedBlockingReasons: [Reason]?
  let expectedError: ExpectedError?
  let rounding: [RoundingCase]?
  let views: [View]?
  let expectedConfirmability: ExpectedConfirmability?

  var metricOptions: MetricOptions { MetricOptions(includePelvicTilt: options?.includePelvicTilt ?? false) }

  var input: PostureViewInput? {
    guard let view, let image, let landmarks else { return nil }
    return PostureViewInput(
      view: view, imageSize: PixelSize(width: image.width, height: image.height),
      imageRotationDeg: imageRotationDeg ?? 0, landmarks: landmarks)
  }
}

extension PostureMetricResult {
  var asExpected: PostureVectorCase.Expected {
    PostureVectorCase.Expected(metricCode: metricCode, value: value, unit: unit, side: side, sourceGrade: sourceGrade)
  }
}

extension ConfirmBlocker {
  /// The vector notation `{reason, metricCode}`.
  var vectorReason: String {
    switch self {
    case .viewsIncomplete: return "viewsIncomplete"
    case .degenerateGeometry: return "degenerateGeometry"
    case .pairTooClose: return "pairTooClose"
    case .sidesSwapped: return "sidesSwapped"
    case .landmarkNotInView: return "landmarkNotInView"
    }
  }

  var vectorMetric: MetricCode? {
    switch self {
    case let .degenerateGeometry(m), let .pairTooClose(m), let .sidesSwapped(m): return m
    default: return nil
    }
  }
}
