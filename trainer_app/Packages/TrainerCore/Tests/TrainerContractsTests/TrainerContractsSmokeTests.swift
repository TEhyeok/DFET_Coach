import XCTest
@testable import TrainerContracts

final class TrainerContractsSmokeTests: XCTestCase {
  func testModuleLoads() {
    XCTAssertEqual(TrainerContractsModule.name, "TrainerContracts")
  }
}
