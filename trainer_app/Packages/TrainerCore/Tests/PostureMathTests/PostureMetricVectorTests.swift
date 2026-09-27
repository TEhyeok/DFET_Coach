import Foundation
import PostureMath
import TrainerContracts
import XCTest

/// DF-201: posture metrics against the shared vectors and the card's named cases. Synthetic coordinates only.
final class PostureMetricVectorTests: XCTestCase {
  private let square = PixelSize(width: 2000, height: 2000)

  private func landmark(_ code: LandmarkCode, _ px: Double, _ py: Double, in size: PixelSize,
                        origin: LandmarkOrigin = .manual, confirmed: Bool = true) -> LandmarkValue {
    LandmarkValue(code: code, point: NormalizedPoint(x: px / size.width, y: py / size.height),
                  origin: origin, confirmed: confirmed)
  }

  func test_AC_ASM_03_1_cvaAndShoulderVector() throws {
    let cva = try PostureMetricCalculator.computeMetrics(
      view: .sagittalLeft, imageSize: square, imageRotationDeg: 0,
      landmarks: [landmark(.c7, 1000, 1000, in: square), landmark(.tragusLeft, 1100, 900, in: square)])
    XCTAssertEqual(cva, [PostureMetricResult(metricCode: .craniovertebralAngle, value: 45.0, side: .none, sourceGrade: .photoManual)])

    let shoulder = try PostureMetricCalculator.computeMetrics(
      view: .front, imageSize: square, imageRotationDeg: 0,
      landmarks: [landmark(.acromionLeft, 1200, 800, in: square), landmark(.acromionRight, 800, 820, in: square)])
    XCTAssertEqual(shoulder, [PostureMetricResult(metricCode: .shoulderTiltAngle, value: 2.9, side: .left, sourceGrade: .photoManual)])
  }

  /// Q upright at 0°, and P = Q turned −2° about the centre at +2°, give the same rounded results.
  func test_AC_ASM_03_2_rotationEquivalence() throws {
    let q: [(LandmarkCode, Double, Double)] = [
      (.c7, 1000, 1000), (.tragusLeft, 1100, 900),
    ]
    let upright = q.map { landmark($0.0, $0.1, $0.2, in: square) }
    let turned = q.map { code, x, y -> LandmarkValue in
      let p = PixelGeometry.rotateAboutCenter(PixelPoint(x: x, y: y), degrees: -2, in: square)
      return landmark(code, p.x, p.y, in: square)
    }
    let reference = try PostureMetricCalculator.computeMetrics(view: .sagittalLeft, imageSize: square, imageRotationDeg: 0, landmarks: upright)
    let corrected = try PostureMetricCalculator.computeMetrics(view: .sagittalLeft, imageSize: square, imageRotationDeg: 2, landmarks: turned)
    let uncorrected = try PostureMetricCalculator.computeMetrics(view: .sagittalLeft, imageSize: square, imageRotationDeg: 0, landmarks: turned)
    XCTAssertEqual(corrected, reference)
    XCTAssertEqual(uncorrected.first?.value, 43.0, "the correction must matter")
  }

  func test_AC_ASM_03_4_pixelConversionRegression() throws {
    let size = PixelSize(width: 1600, height: 1200)
    let result = try PostureMetricCalculator.computeMetrics(
      view: .sagittalLeft, imageSize: size, imageRotationDeg: 0,
      landmarks: [landmark(.c7, 800, 600, in: size), landmark(.tragusLeft, 900, 480, in: size)])
    XCTAssertEqual(result.first?.value, 50.2, "58.0 means normalized coordinates were used")
  }

  func test_AC_ASM_03_3_unconfirmedLandmarkMakesPhotoAuto() throws {
    let result = try PostureMetricCalculator.computeMetrics(
      view: .front, imageSize: square, imageRotationDeg: 0,
      landmarks: [
        landmark(.earLeft, 1150, 700, in: square), landmark(.earRight, 850, 690, in: square),
        landmark(.acromionLeft, 1200, 800, in: square), landmark(.acromionRight, 800, 820, in: square, confirmed: false),
      ])
    XCTAssertEqual(result.first { $0.metricCode == .shoulderTiltAngle }?.sourceGrade, .photoAuto)
    XCTAssertEqual(result.first { $0.metricCode == .headTiltFrontal }?.sourceGrade, .photoManual)
  }

  func test_AC_ASM_03_6_pelvicTiltOffByDefault() throws {
    let asis = [landmark(.asisLeft, 1150, 1300, in: square), landmark(.asisRight, 850, 1320, in: square)]
    let off = try PostureMetricCalculator.computeMetrics(view: .front, imageSize: square, imageRotationDeg: 0, landmarks: asis)
    XCTAssertFalse(off.contains { $0.metricCode == .pelvicTiltFrontal })
    let oneSide = try PostureMetricCalculator.computeMetrics(
      view: .front, imageSize: square, imageRotationDeg: 0, landmarks: [asis[0]], options: MetricOptions(includePelvicTilt: true))
    XCTAssertEqual(oneSide, [], "not computed, not 0, not an error (F-ASM-04.2)")
  }

  func test_AC_DF_201_6_levelAndNegativeCva() throws {
    let level = try PostureMetricCalculator.computeMetrics(
      view: .front, imageSize: square, imageRotationDeg: 0,
      landmarks: [landmark(.acromionLeft, 1200, 800, in: square), landmark(.acromionRight, 800, 800.6, in: square)])
    XCTAssertEqual(level.first?.value, 0.0)
    XCTAssertEqual(level.first?.side, Side.none)
    let negative = try PostureMetricCalculator.computeMetrics(
      view: .sagittalLeft, imageSize: square, imageRotationDeg: 0,
      landmarks: [landmark(.c7, 1000, 1000, in: square), landmark(.tragusLeft, 1100, 1050, in: square)])
    XCTAssertEqual(negative.first?.value, -26.6)
  }

  func test_AC_DF_201_9_allVectorCasesPass() throws {
    let file = try PostureVectorFile.load()
    XCTAssertEqual(file.contract, "posture-metric-vectors")
    XCTAssertEqual(file.rounding, "halfAwayFromZero")
    XCTAssertEqual(file.cases.map(\.id), (1...20).map { String(format: "PM-%02d", $0) })
    for vector in file.cases {
      switch vector.kind {
      case "rounding":
        for row in vector.rounding ?? [] {
          XCTAssertEqual(Rounding.roundTenth(row.input), row.expected, "\(vector.id) \(row.input)")
        }
      case "confirmability":
        let views = (vector.views ?? []).map {
          PostureViewInput(view: $0.view, imageSize: PixelSize(width: $0.image.width, height: $0.image.height),
                           imageRotationDeg: $0.imageRotationDeg, landmarks: $0.landmarks)
        }
        let result = PostureConfirmation.confirmability(views: views, options: vector.metricOptions)
        let expected = try XCTUnwrap(vector.expectedConfirmability, vector.id)
        XCTAssertEqual(result.canConfirm, expected.canConfirm, vector.id)
        XCTAssertEqual(result.missing, expected.missing, vector.id)
        XCTAssertEqual(result.blockingLandmarks, expected.blockingLandmarks, vector.id)
      default:
        let input = try XCTUnwrap(vector.input, vector.id)
        if let expectedError = vector.expectedError {
          XCTAssertThrowsError(try PostureMetricCalculator.computeMetrics(input, options: vector.metricOptions), vector.id) { error in
            XCTAssertEqual(error as? PostureMathError, .degenerateGeometry(try! XCTUnwrap(expectedError.metricCode)), vector.id)
          }
          continue
        }
        let results = try PostureMetricCalculator.computeMetrics(input, options: vector.metricOptions)
        XCTAssertEqual(results.map(\.asExpected), vector.expected ?? [], vector.id)
        for reason in vector.expectedBlockingReasons ?? [] {
          let blockers = PostureConfirmation.geometryBlockers(input, options: vector.metricOptions)
          XCTAssertTrue(blockers.contains { $0.vectorReason == reason.reason && $0.vectorMetric == reason.metricCode },
                        "\(vector.id): \(reason.reason) not in \(blockers)")
        }
      }
    }
  }
}
