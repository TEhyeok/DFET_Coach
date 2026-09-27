import PostureMath
import TrainerContracts
import XCTest

/// DF-201 AC-DF-201.7: which landmarks block confirmation (V1-09 §4.4).
final class ConfirmabilityTests: XCTestCase {
  private let size = PixelSize(width: 2000, height: 2000)

  private func lm(_ code: LandmarkCode, _ x: Double, _ y: Double, origin: LandmarkOrigin = .manual, confirmed: Bool = true) -> LandmarkValue {
    LandmarkValue(code: code, point: NormalizedPoint(x: x / 2000, y: y / 2000), origin: origin, confirmed: confirmed)
  }

  private func views(front: [LandmarkValue], sagittal: [LandmarkValue]) -> [PostureViewInput] {
    [PostureViewInput(view: .front, imageSize: size, imageRotationDeg: 0, landmarks: front),
     PostureViewInput(view: .sagittalLeft, imageSize: size, imageRotationDeg: 0, landmarks: sagittal)]
  }

  private var front: [LandmarkValue] {
    [lm(.earLeft, 1150, 700), lm(.earRight, 850, 690), lm(.acromionLeft, 1200, 800), lm(.acromionRight, 800, 820)]
  }

  private var sagittal: [LandmarkValue] { [lm(.c7, 1000, 1000), lm(.tragusLeft, 1100, 900)] }

  func test_AC_ASM_02_1_manualRequiredAutoBlocksConfirm() {
    for code in [LandmarkCode.c7, .acromionLeft, .acromionRight] {
      let front = self.front.map { $0.code == code ? lm($0.code, $0.point.x * 2000, $0.point.y * 2000, origin: .auto, confirmed: true) : $0 }
      let sagittal = self.sagittal.map { $0.code == code ? lm($0.code, $0.point.x * 2000, $0.point.y * 2000, origin: .auto, confirmed: true) : $0 }
      let result = PostureConfirmation.confirmability(views: views(front: front, sagittal: sagittal))
      XCTAssertFalse(result.canConfirm, "\(code)")
      XCTAssertEqual(result.blockingLandmarks, [code], "an auto \(code) blocks even when confirmed")
    }
  }

  func test_AC_ASM_04_1_allRequiredConfirmedAllowsConfirm() {
    let result = PostureConfirmation.confirmability(views: views(front: front, sagittal: sagittal))
    XCTAssertEqual(result, Confirmability(canConfirm: true, missing: [], blockingLandmarks: []))
    // Ears and tragus may stay auto once confirmed; they are not manual-required.
    let autoEars = front.map { $0.code == .earLeft ? LandmarkValue(code: .earLeft, point: $0.point, origin: .auto, confirmed: true) : $0 }
    XCTAssertTrue(PostureConfirmation.confirmability(views: views(front: autoEars, sagittal: sagittal)).canConfirm)
  }

  func test_F_ASM_04_2_pelvicUnavailableStillConfirmable() {
    let on = MetricOptions(includePelvicTilt: true)
    XCTAssertTrue(PostureConfirmation.confirmability(views: views(front: front, sagittal: sagittal), options: on).canConfirm,
                  "no ASIS placed: pelvic is simply not computed")
    let oneAsis = front + [lm(.asisLeft, 1150, 1300)]
    let result = PostureConfirmation.confirmability(views: views(front: oneAsis, sagittal: sagittal), options: on)
    XCTAssertFalse(result.canConfirm)
    XCTAssertEqual(result.missing, [.asisRight], "one ASIS placed: both must be valid")
  }

  func testMissingAndUnconfirmedLandmarks() {
    let result = PostureConfirmation.confirmability(views: views(
      front: [lm(.earLeft, 1150, 700), lm(.earRight, 850, 690, confirmed: false), lm(.acromionLeft, 1200, 800)],
      sagittal: sagittal))
    XCTAssertEqual(result.missing, [.acromionRight])
    XCTAssertEqual(result.blockingLandmarks, [.earRight])
  }

  func testGeometryBlockers() {
    let swapped = views(front: [lm(.earLeft, 850, 700), lm(.earRight, 1150, 690), lm(.acromionLeft, 1200, 800), lm(.acromionRight, 800, 820)], sagittal: sagittal)
    XCTAssertEqual(PostureConfirmation.confirmability(views: swapped).blockingReasons, [.sidesSwapped(.headTiltFrontal)])
    let close = views(front: [lm(.earLeft, 1150, 700), lm(.earRight, 850, 690), lm(.acromionLeft, 1020, 800), lm(.acromionRight, 990, 820)], sagittal: sagittal)
    XCTAssertEqual(PostureConfirmation.confirmability(views: close).blockingReasons, [.pairTooClose(.shoulderTiltAngle)])
    let wrongView = views(front: front + [lm(.c7, 1000, 1000)], sagittal: sagittal)
    XCTAssertEqual(PostureConfirmation.confirmability(views: wrongView).blockingReasons, [.landmarkNotInView(.c7)])
    let oneView = [PostureViewInput(view: .front, imageSize: size, imageRotationDeg: 0, landmarks: front)]
    XCTAssertEqual(PostureConfirmation.confirmability(views: oneView).blockingReasons, [.viewsIncomplete])
  }
}
