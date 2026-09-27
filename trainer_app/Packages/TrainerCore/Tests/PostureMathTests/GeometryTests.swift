@testable import PostureMath
import TrainerContracts
import XCTest

/// DF-201 AC-DF-201.8 and the shared rounding rule (V1-09 §1.3, §2.4).
final class GeometryTests: XCTestCase {
  private let size = PixelSize(width: 2000, height: 2000)

  func test_AC_ASM_02_4_outOfRangeRejected() {
    let landmarks = [
      LandmarkValue(code: .c7, point: NormalizedPoint(x: 0.5, y: 1.0001), origin: .manual, confirmed: true),
      LandmarkValue(code: .tragusLeft, point: NormalizedPoint(x: 0.55, y: 0.45), origin: .manual, confirmed: true),
    ]
    XCTAssertThrowsError(try PostureMetricCalculator.computeMetrics(view: .sagittalLeft, imageSize: size, imageRotationDeg: 0, landmarks: landmarks)) {
      XCTAssertEqual($0 as? PostureMathError, .coordinateOutOfRange(.c7))
    }
    XCTAssertThrowsError(try PostureMetricCalculator.computeMetrics(
      view: .sagittalLeft, imageSize: PixelSize(width: 0, height: 10), imageRotationDeg: 0,
      landmarks: [LandmarkValue(code: .c7, point: NormalizedPoint(x: 0.5, y: 0.5), origin: .manual, confirmed: true)])) {
      XCTAssertEqual($0 as? PostureMathError, .zeroImageSize)
    }
  }

  /// §5.1 step 2: every stored coordinate is checked, including landmarks this view does not use.
  func test_AC_DF_201_8_unusedOutOfRangeLandmarkRefusesTheComputation() {
    let sagittal = [
      LandmarkValue(code: .c7, point: NormalizedPoint(x: 0.5, y: 0.5), origin: .manual, confirmed: true),
      LandmarkValue(code: .tragusLeft, point: NormalizedPoint(x: 0.55, y: 0.45), origin: .manual, confirmed: true),
      LandmarkValue(code: .tragusRight, point: NormalizedPoint(x: 0.5, y: 1.2), origin: .manual, confirmed: true),
    ]
    XCTAssertThrowsError(try PostureMetricCalculator.computeMetrics(view: .sagittalLeft, imageSize: size, imageRotationDeg: 0, landmarks: sagittal)) {
      XCTAssertEqual($0 as? PostureMathError, .coordinateOutOfRange(.tragusRight))
    }
    let front = [
      LandmarkValue(code: .acromionLeft, point: NormalizedPoint(x: 0.6, y: 0.4), origin: .manual, confirmed: true),
      LandmarkValue(code: .acromionRight, point: NormalizedPoint(x: 0.4, y: 0.41), origin: .manual, confirmed: true),
      LandmarkValue(code: .asisLeft, point: NormalizedPoint(x: -0.1, y: 0.6), origin: .manual, confirmed: true),
    ]
    XCTAssertThrowsError(try PostureMetricCalculator.computeMetrics(view: .front, imageSize: size, imageRotationDeg: 0, landmarks: front)) {
      XCTAssertEqual($0 as? PostureMathError, .coordinateOutOfRange(.asisLeft), "pelvic is off, the ASIS is still checked")
    }
  }

  func testANonFiniteRotationIsRefusedAndBlocksConfirmation() {
    let landmarks = [
      LandmarkValue(code: .c7, point: NormalizedPoint(x: 0.5, y: 0.5), origin: .manual, confirmed: true),
      LandmarkValue(code: .tragusLeft, point: NormalizedPoint(x: 0.55, y: 0.45), origin: .manual, confirmed: true),
    ]
    XCTAssertThrowsError(try PostureMetricCalculator.computeMetrics(view: .sagittalLeft, imageSize: size, imageRotationDeg: .nan, landmarks: landmarks)) {
      XCTAssertEqual($0 as? PostureMathError, .invalidRotation)
    }
    let input = PostureViewInput(view: .sagittalLeft, imageSize: size, imageRotationDeg: .infinity, landmarks: landmarks)
    XCTAssertTrue(PostureConfirmation.geometryBlockers(input).contains(.invalidRotation))
  }

  func testAFrontPairUnderOnePixelApartIsDegenerate() {
    let ears = [
      LandmarkValue(code: .earLeft, point: NormalizedPoint(x: 1000.4 / 2000, y: 0.35), origin: .manual, confirmed: true),
      LandmarkValue(code: .earRight, point: NormalizedPoint(x: 0.5, y: 0.345), origin: .manual, confirmed: true),
    ]
    XCTAssertThrowsError(try PostureMetricCalculator.computeMetrics(view: .front, imageSize: size, imageRotationDeg: 0, landmarks: ears)) {
      XCTAssertEqual($0 as? PostureMathError, .degenerateGeometry(.headTiltFrontal))
    }
  }

  /// V1-09 §5.6, §5.8: a gap of exactly one pixel (one 1-pixel move, AC-DF-208.4) is 1 px, although 0.5005 × 2000
  /// makes it 0.9999999999998863. The level rule, V-POS-03 and confirmation share the boundary.
  func testExactlyOnePixelIsNotUnderOnePixel() throws {
    func shoulders(leftY: Double) -> [LandmarkValue] {
      [LandmarkValue(code: .acromionLeft, point: NormalizedPoint(x: 0.6, y: leftY), origin: .manual, confirmed: true),
       LandmarkValue(code: .acromionRight, point: NormalizedPoint(x: 0.4, y: 0.5), origin: .manual, confirmed: true)]
    }
    let tilted = try PostureMetricCalculator.computeMetrics(
      view: .front, imageSize: size, imageRotationDeg: 0, landmarks: shoulders(leftY: 0.5005))
    XCTAssertEqual(tilted, [PostureMetricResult(metricCode: .shoulderTiltAngle, value: 0.1, side: .right, sourceGrade: .photoManual)])
    let level = try PostureMetricCalculator.computeMetrics(
      view: .front, imageSize: size, imageRotationDeg: 0, landmarks: shoulders(leftY: 1000.9 / 2000))
    XCTAssertEqual(level.first?.value, 0.0, "0.9 px is still level")
    XCTAssertEqual(level.first?.side, Side.none)

    // A front pair exactly 1 px apart has an angle; only V-POS-04 blocks it.
    let ears = PostureViewInput(view: .front, imageSize: size, imageRotationDeg: 0, landmarks: [
      LandmarkValue(code: .earLeft, point: NormalizedPoint(x: 0.5005, y: 0.35), origin: .manual, confirmed: true),
      LandmarkValue(code: .earRight, point: NormalizedPoint(x: 0.5, y: 0.35), origin: .manual, confirmed: true),
    ])
    XCTAssertEqual(try PostureMetricCalculator.computeMetrics(ears).first?.metricCode, .headTiltFrontal)
    XCTAssertEqual(PostureConfirmation.geometryBlockers(ears), [.pairTooClose(.headTiltFrontal)])

    // A tragus exactly 1 px above C7 is 90.0°, not degenerate.
    let sagittal = PostureViewInput(view: .sagittalLeft, imageSize: size, imageRotationDeg: 0, landmarks: [
      LandmarkValue(code: .c7, point: NormalizedPoint(x: 0.5, y: 0.5005), origin: .manual, confirmed: true),
      LandmarkValue(code: .tragusLeft, point: NormalizedPoint(x: 0.5, y: 0.5), origin: .manual, confirmed: true),
    ])
    XCTAssertEqual(try PostureMetricCalculator.computeMetrics(sagittal).first?.value, 90.0)
    XCTAssertEqual(PostureConfirmation.geometryBlockers(sagittal), [])
  }

  func testOnePixelBoundaryToleratesOnlyConversionError() {
    XCTAssertFalse(PixelGeometry.isUnderOnePixel(1))
    XCTAssertFalse(PixelGeometry.isUnderOnePixel(-0.9999999999998863))
    XCTAssertFalse(PixelGeometry.isUnderOnePixel(1 - PixelGeometry.onePixelTolerance))
    XCTAssertTrue(PixelGeometry.isUnderOnePixel(1 - 2 * PixelGeometry.onePixelTolerance))
    XCTAssertTrue(PixelGeometry.isUnderOnePixel(-0.9999))
    XCTAssertTrue(PixelGeometry.isUnderOnePixel(0))
  }

  func test_AC_ASM_02_5_recomputeIsDeterministic() throws {
    let landmarks = [
      LandmarkValue(code: .acromionLeft, point: NormalizedPoint(x: 0.6034290325, y: 0.403550867), origin: .manual, confirmed: true),
      LandmarkValue(code: .acromionRight, point: NormalizedPoint(x: 0.403201872, y: 0.406564876), origin: .manual, confirmed: true),
    ]
    let first = try PostureMetricCalculator.computeMetrics(view: .front, imageSize: size, imageRotationDeg: 2, landmarks: landmarks)
    for _ in 0..<100 {
      let again = try PostureMetricCalculator.computeMetrics(view: .front, imageSize: size, imageRotationDeg: 2, landmarks: landmarks)
      XCTAssertEqual(again, first)
      XCTAssertEqual(again.first?.value.bitPattern, first.first?.value.bitPattern)
    }
  }

  func test_roundTenth_halfAwayFromZero() {
    XCTAssertEqual(Rounding.roundTenth(2.25), 2.3)
    XCTAssertEqual(Rounding.roundTenth(-2.25), -2.3)
    XCTAssertEqual(Rounding.roundTenth(44.98), 45.0)
    XCTAssertEqual(Rounding.roundTenth(-0.04).sign, .plus, "-0.0 is stored as 0.0")
  }

  func testRotationDirection() {
    // A point right of the centre turned +90° goes up (counter-clockwise on screen, y down).
    let p = PixelGeometry.rotateAboutCenter(PixelPoint(x: 1001, y: 1000), degrees: 90, in: size)
    XCTAssertEqual(p.x, 1000, accuracy: 1e-9)
    XCTAssertEqual(p.y, 999, accuracy: 1e-9)
  }

  func testLandmarkValueEncodesFlat() throws {
    let value = LandmarkValue(code: .c7, point: NormalizedPoint(x: 0.5, y: 0.25), origin: .auto, confirmed: false,
                              suggested: SuggestedPoint(x: 0.5, y: 0.25, confidence: 0.8))
    let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any]
    XCTAssertEqual(json?["code"] as? String, "c7")
    XCTAssertEqual(json?["x"] as? Double, 0.5)
    XCTAssertEqual(json?["origin"] as? String, "auto")
    XCTAssertNil(json?["point"])
    XCTAssertEqual(try JSONDecoder().decode(LandmarkValue.self, from: JSONEncoder().encode(value)), value)
  }
}
