import Foundation
import TrainerDomain

/// Reads contract fixtures and vectors straight from the repository root `contracts/`
/// directory via `#filePath` (no copy step, V1-04 §6.3, ASM-04-21, ASM-P0-32).
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
  static let fixturesDirectory: URL = contractsDirectory.appendingPathComponent("fixtures", isDirectory: true)

  /// Returns the raw bytes of `contracts/<relativePath>`.
  static func data(_ relativePath: String) throws -> Data {
    try Data(contentsOf: contractsDirectory.appendingPathComponent(relativePath))
  }

  /// `DFET_RECORD_FIXTURES=1` writes record-mode outputs into the original `contracts/fixtures`
  /// (AC-DF-009.5). CI never sets it.
  static var recordMode: Bool { ProcessInfo.processInfo.environment["DFET_RECORD_FIXTURES"] == "1" }

  static func fixtureURL(_ relativePath: String) -> URL {
    fixturesDirectory.appendingPathComponent(relativePath)
  }

  /// One fixture: `contracts/fixtures/<relativePath>` split by `JSONValue.decodeFixture`.
  static func fixture(_ relativePath: String) throws -> LoadedFixture {
    let url = fixtureURL(relativePath)
    let decoded = try JSONValue.decodeFixture(try Data(contentsOf: url))
    return LoadedFixture(
      base: url.deletingPathExtension().lastPathComponent, meta: decoded.meta, path: decoded.path, data: decoded.data)
  }

  /// Every `*.json` directly under `contracts/fixtures/<group>/`, sorted by name.
  static func group(_ group: String) throws -> [LoadedFixture] {
    let dir = fixturesDirectory.appendingPathComponent(group, isDirectory: true)
    let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
      .filter { $0.hasSuffix(".json") }
      .sorted()
    return try names.map { try fixture("\(group)/\($0)") }
  }
}

/// A decoded fixture file.
struct LoadedFixture {
  /// File name without `.json`.
  let base: String
  let meta: FixtureMeta
  let path: String
  /// `data` with the four tags turned into `JSONValue` cases.
  let data: JSONValue
}
