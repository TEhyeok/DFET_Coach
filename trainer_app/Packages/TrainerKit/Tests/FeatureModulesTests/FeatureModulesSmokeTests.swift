import FeatureAssessment
import FeatureAuth
import FeatureBodyComposition
import FeatureConsent
import FeatureInsights
import FeatureLidarBeta
import FeatureMembers
import FeatureSettings
import FeatureShare
import FeatureSOAP
import FeatureToday
import XCTest

/// Every Feature* target builds and links on the iPad simulator (DF-008 skeleton).
final class FeatureModulesSmokeTests: XCTestCase {
  func testAllFeatureModulesLoad() {
    let names = [
      FeatureAuthModule.name, FeatureTodayModule.name, FeatureMembersModule.name, FeatureSOAPModule.name,
      FeatureConsentModule.name, FeatureBodyCompositionModule.name, FeatureAssessmentModule.name,
      FeatureInsightsModule.name, FeatureShareModule.name, FeatureLidarBetaModule.name, FeatureSettingsModule.name,
    ]
    XCTAssertEqual(names.count, 11)
    XCTAssertEqual(Set(names).count, 11)
    XCTAssertTrue(names.allSatisfy { $0.hasPrefix("Feature") })
  }
}
