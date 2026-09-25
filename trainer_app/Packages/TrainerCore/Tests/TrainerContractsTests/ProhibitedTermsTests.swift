import XCTest
@testable import TrainerContracts

/// DF-010: the generated rules mirror contracts/prohibited-terms.v1.json (the matcher itself is DF-120).
final class ProhibitedTermsTests: XCTestCase {
  func test_AC_DF_010_1_generatedRuleSetsMirrorContract() {
    XCTAssertEqual(ProhibitedTerms.version, 1)
    XCTAssertEqual(ProhibitedTerms.common.count, 24)
    XCTAssertEqual(ProhibitedTerms.common.first?.id, "C1-01")
    XCTAssertEqual(ProhibitedTerms.member.map(\.id), ["C3-M-01", "C3-M-02", "C3-M-03", "C3-M-04"])
    XCTAssertTrue(ProhibitedTerms.trainer.isEmpty)
    XCTAssertEqual(ProhibitedTerms.trainerAbbreviations, ["SOAP", "ROM", "AROM", "PROM", "MMT", "NRS", "MDC"])
    XCTAssertTrue(ProhibitedTerms.causalPatterns.allSatisfy { $0.id.hasPrefix("C2-") })
  }

  func test_AC_DF_010_1_ruleIdsAreUniqueAndAllowEntriesPointAtRules() {
    let ids = (ProhibitedTerms.common + ProhibitedTerms.member + ProhibitedTerms.trainer).map(\.id)
    XCTAssertEqual(Set(ids).count, ids.count)
    for entry in ProhibitedTerms.allowEntries {
      XCTAssertTrue(entry.rules.allSatisfy(ids.contains), entry.id)
    }
    XCTAssertEqual(ProhibitedTerms.allowEntries.first?.exactString, "운동 지도와 건강관리 기록용이며 진단이나 치료를 위한 정보가 아닙니다.")
  }

  func test_AC_DF_010_1_lidarMeasuredValueRuleIsPathLimited() {
    let rule = ProhibitedTerms.common.first { $0.id == "C1-23" }
    XCTAssertEqual(rule?.onlyInGlobs?.first, "trainer_app/Packages/TrainerKit/Sources/FeatureLidarBeta/**")
    XCTAssertEqual(ProhibitedTerms.common.first { $0.id == "C1-16" }?.boundary, .wordStart)
  }
}
