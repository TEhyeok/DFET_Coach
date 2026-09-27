import Foundation
import XCTest

/// TC-DF016-03: no plain '저장됨' anywhere the trainer can see it, and green only where the design allows it.
final class DesignSystemSourceTests: XCTestCase {
  func test_TC_DF016_03_noStandaloneSavedString() throws {
    for (key, value) in try AppCatalog.values() {
      XCTAssertNotEqual(value.trimmingCharacters(in: .whitespaces), "저장됨", key)
    }
    let deck = try Data(contentsOf: AppCatalog.repositoryRoot.appendingPathComponent("docs/v1/data/copy_ko.json"))
    let strings = try XCTUnwrap((try JSONSerialization.jsonObject(with: deck) as? [String: Any])?["strings"] as? [String: [String: Any]])
    for (key, entry) in strings {
      XCTAssertNotEqual((entry["ko"] as? String)?.trimmingCharacters(in: .whitespaces), "저장됨", key)
    }
  }

  /// AC-DF-016.2: `TrainerColor.success` appears only in the token file and the synced badge.
  func test_TC_DF016_03_successColourOnlyWhereAllowed() throws {
    let allowed: Set<String> = [
      "Packages/TrainerKit/Sources/DesignSystem/Tokens/TrainerColor.swift",
      "Packages/TrainerKit/Sources/DesignSystem/Components/SyncStateBadge.swift",
    ]
    var users: Set<String> = []
    let root = AppCatalog.trainerApp
    let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
    while let url = files?.nextObject() as? URL {
      let path = url.path.replacingOccurrences(of: root.path + "/", with: "")
      if path.hasPrefix(".spm") || path.hasPrefix("build") || path.contains("/.build/") || path.contains("/Tests/") {
        continue
      }
      guard url.pathExtension == "swift", let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
      if text.contains("TrainerColor.success") {
        users.insert(path)
      }
    }
    XCTAssertEqual(users.subtracting(allowed), [], "green is for the synced state only")
    XCTAssertTrue(users.contains("Packages/TrainerKit/Sources/DesignSystem/Components/SyncStateBadge.swift"))
  }
}
