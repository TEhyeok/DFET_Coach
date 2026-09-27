import DesignSystem
import SwiftUI
import TrainerContracts
import XCTest

/// TC-DF016-02, TC-DF016-05. Synthetic values only.
@MainActor
final class MetricRowTests: XCTestCase {
  private let seoul = TimeZone(identifier: "Asia/Seoul")!
  private let measured = Date(timeIntervalSince1970: 1_790_000_000)  // 2026-09-21 21:53 KST

  private func row(_ grade: SourceGrade?, value: Double = 72.4, code: MetricCode = .weightKg) -> MetricRowModel {
    MetricRowModel(code: code, value: value, sourceGrade: grade, deviceModel: "합성 체성분 기기", measuredAt: measured)
  }

  private func fittingSize(_ view: some View) -> CGSize {
    UIHostingController(rootView: view).sizeThatFits(in: CGSize(width: 600, height: 600))
  }

  /// AC-DF-016.3 / C-01: no source, no row.
  func test_TC_DF016_02_aValueWithoutASourceIsNotDrawn() throws {
    let localize = try AppCatalog.localizer()
    XCTAssertFalse(MetricRow.isShown(row(nil)))
    XCTAssertEqual(fittingSize(MetricRow(metric: row(nil), localize: localize)), .zero)
    XCTAssertFalse(MetricRow.isShown(row(.modelEstimate)), "grades v1 never shows are not drawn either")
    XCTAssertFalse(MetricRow.isShown(row(.device, code: .phaseAngleDeg)), "v2 metrics have no v1 name and are not drawn")
    XCTAssertTrue(MetricRow.isShown(row(.device)))
    let shown = fittingSize(MetricRow(metric: row(.device), localize: localize))
    XCTAssertGreaterThanOrEqual(shown.height, 44)
  }

  /// AC-DF-016.5: "{nameKo} {값}{단위}, {측면}, 출처 {출처 라벨}, {측정일}, 변화 {상태}" with the app's words.
  func test_TC_DF016_05_accessibilityLabelFollowsTheTemplate() throws {
    let localize = try AppCatalog.localizer()
    // No side: the "{side}, " fragment is left out (V1-12 §3.7).
    XCTAssertEqual(MetricRow.accessibilityLabel(row(.device), localize: localize, timeZone: seoul),
                   "체중 72.4kg, 출처 기기 측정 · 합성 체성분 기기, 2026.09.21, 변화 산정 준비 중")
    // A higher-side magnitude reads the higher side (sideRule magnitudeWithHigherSide).
    let shoulder = MetricRowModel(code: .shoulderTiltAngle, value: 1.26, side: .left, sourceGrade: .photoManual,
                                  measuredAt: measured)
    XCTAssertEqual(MetricRow.accessibilityLabel(shoulder, localize: localize, timeZone: seoul),
                   "어깨 높이차(견봉선 기울기각) 1.3°, 왼쪽이 높음, 출처 사진 측정(확정), 2026.09.21, 변화 산정 준비 중")
    let circumference = MetricRowModel(code: .thighCircumference, value: 52.4, side: .right, sourceGrade: .tape,
                                       measuredAt: measured)
    XCTAssertEqual(MetricRow.sideText(circumference, localize: localize), "오른쪽")
    let level = MetricRowModel(code: .shoulderTiltAngle, value: 0, side: .none, sourceGrade: .photoManual,
                               measuredAt: measured)
    XCTAssertEqual(MetricRow.sideText(level, localize: localize), "좌우 높이 같음")
  }

  func testValuesUseTheCatalogDecimalsAndATrueMinus() {
    XCTAssertEqual(MetricRow.valueText(row(.tape, value: 80, code: .waistCircumference)), "80.0")
    XCTAssertEqual(MetricRow.valueText(row(.trainerObserved, value: 4, code: .mmtGrade)), "4")
    XCTAssertEqual(MetricRow.valueText(row(.photoManual, value: -0.04, code: .shoulderTiltAngle)), "0.0", "no negative zero")
    XCTAssertEqual(MetricRow.valueText(row(.tape, value: 80.25, code: .waistCircumference)), "80.3", "half away from zero")
    XCTAssertEqual(MetricRow.valueText(row(.photoManual, value: -1.25, code: .shoulderTiltAngle)), "\u{2212}1.3")
    XCTAssertEqual(MetricRow.dateText(measured, timeZone: seoul), "2026.09.21")
  }
}
