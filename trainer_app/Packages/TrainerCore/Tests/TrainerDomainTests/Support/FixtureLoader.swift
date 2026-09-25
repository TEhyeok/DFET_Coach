import Foundation

/// Reads contract fixtures and vectors straight from the repository root `contracts/`
/// directory via `#filePath` (no copy step, V1-04 §6.3, ASM-04-21).
///
/// Path: trainer_app/Packages/TrainerCore/Tests/TrainerDomainTests/Support/FixtureLoader.swift
/// → seven levels up is the repository root.
enum FixtureLoader {
  static let repositoryRoot: URL = {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<7 { url.deleteLastPathComponent() }
    return url
  }()

  static let contractsDirectory: URL = repositoryRoot.appendingPathComponent("contracts", isDirectory: true)

  /// Returns the raw bytes of `contracts/<relativePath>`.
  static func data(_ relativePath: String) throws -> Data {
    try Data(contentsOf: contractsDirectory.appendingPathComponent(relativePath))
  }
}
