import PostureMath
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
