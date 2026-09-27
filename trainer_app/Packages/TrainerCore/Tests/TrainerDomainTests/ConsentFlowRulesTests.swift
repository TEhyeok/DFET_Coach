import Foundation
import TrainerContracts
import TrainerDomain
import XCTest

final class ConsentFlowRulesTests: XCTestCase {
  func testAC_DF_110_2_requiresThreeSeparateAnswersWithoutDefaultGrant() {
    XCTAssertFalse(ConsentFlowRules.canSubmit(selections: []))
    XCTAssertFalse(ConsentFlowRules.canSubmit(selections: [.init(type: .required, granted: true)]))
    XCTAssertFalse(ConsentFlowRules.canSubmit(selections: [
      .init(type: .required, granted: true), .init(type: .required, granted: true), .init(type: .healthData, granted: true),
    ]))
    XCTAssertTrue(ConsentFlowRules.canSubmit(selections: [
      .init(type: .required, granted: true), .init(type: .healthData, granted: false), .init(type: .bodyImaging, granted: true),
    ]), "A refusal is an explicit response, not an invalid answer")
  }

  func testTC_110_02_choosesLatestPublishedDateNotLexicographicVersion() {
    let first = doc("healthData--9", type: .healthData, at: 10)
    let latest = doc("healthData--10", type: .healthData, at: 20)
    let retired = doc("healthData--11", type: .healthData, at: 30, status: .retired)
    let required = doc("required--1", type: .required, at: 5)
    let actual = ConsentFlowRules.latestPublished([first, latest, retired, required])
    XCTAssertEqual(actual[.healthData], latest)
    XCTAssertEqual(actual[.required], required)
    XCTAssertNil(actual[.bodyImaging])
  }

  func testAC_DF_110_3_unpublishedOrIncompleteCardIsNotSubmittable() {
    let incomplete = ConsentDocumentVersion(id: "required--1", consentType: .required, version: "1", title: "Test",
      purpose: " ", items: [], retention: "Test retention", refusalNotice: "Test refusal",
      privacyPolicyVersion: "test-policy", publishedAt: Date())
    XCTAssertTrue(ConsentFlowRules.latestPublished([incomplete]).isEmpty)
    XCTAssertTrue(ConsentFlowRules.latestPublished([doc("required--1", type: .required, at: 1, status: .draft)]).isEmpty)
  }

  private func doc(_ id: String, type: ConsentType, at time: TimeInterval,
                   status: ConsentDocumentVersion.Status = .published) -> ConsentDocumentVersion {
    ConsentDocumentVersion(id: id, consentType: type, version: id, title: "Synthetic card", purpose: "Synthetic purpose",
      items: ["Synthetic item"], retention: "Test retention", refusalNotice: "Test refusal",
      privacyPolicyVersion: "test-policy", status: status, publishedAt: Date(timeIntervalSince1970: time))
  }
}
