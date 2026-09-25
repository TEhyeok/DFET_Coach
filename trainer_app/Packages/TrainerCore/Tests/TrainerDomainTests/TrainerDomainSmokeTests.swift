import XCTest
@testable import TrainerDomain

final class TrainerDomainSmokeTests: XCTestCase {
  func testModuleLoads() {
    XCTAssertEqual(TrainerDomainModule.name, "TrainerDomain")
  }

  func testFixtureLoaderFindsRepositoryRoot() throws {
    let root = FixtureLoader.repositoryRoot
    let spec = root.appendingPathComponent("trainer_app/Packages/TrainerCore/Package.swift")
    XCTAssertTrue(
      FileManager.default.fileExists(atPath: spec.path),
      "repository root resolved from #filePath should contain trainer_app/Packages/TrainerCore/Package.swift"
    )
    XCTAssertEqual(FixtureLoader.contractsDirectory, root.appendingPathComponent("contracts", isDirectory: true))
  }
}
