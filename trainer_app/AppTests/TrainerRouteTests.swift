import TrainerDomain
import XCTest

/// TC-DF017-03 (AC-DF-017.3, AS-21): no schedule/program/alerts route, and every case has a TR ID.
final class TrainerRouteTests: XCTestCase {
  func testNoForbiddenRoutes_TC_DF017_03() {
    let names = TrainerRoute.allCases.map(\.caseName)
    for forbidden in ["schedule", "program", "alerts"] {
      XCTAssertFalse(names.contains { $0.lowercased().contains(forbidden) }, forbidden)
    }
    XCTAssertEqual(names, ["today", "members", "memberDetail", "settings"])
  }

  func testEveryCaseHasATrID() {
    let pattern = try? NSRegularExpression(pattern: "^TR-(0[1-9]|1[0-5])$")
    for route in TrainerRoute.allCases {
      let id = route.trID
      XCTAssertNotNil(pattern?.firstMatch(in: id, range: NSRange(id.startIndex..., in: id)), route.caseName)
    }
    XCTAssertEqual(TrainerRoute.allCases.map(\.trID), ["TR-01", "TR-02", "TR-03", "TR-15"])
    XCTAssertEqual(TrainerRoute.memberDetail(uid: "syn-0001").trID, "TR-03")
  }

  func testInitialRouteFollowsSoapV2() {
    XCTAssertEqual(TrainerRoute.initial(flags: .allOff), .members)
    XCTAssertEqual(TrainerRoute.initial(flags: FeatureFlags(soapV2: true)), .today)
  }
}
