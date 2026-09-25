import Foundation
import XCTest

/// AC-DF-008.3 / TC-DF008-02: TrainerCore sources must stay platform-neutral so that
/// macOS `swift test` keeps working. Mirrors the CI grep
/// `grep -REn "^import (UIKit|SwiftUI|SwiftData|Firebase)" trainer_app/Packages/TrainerCore/Sources`.
final class TrainerCorePurityTests: XCTestCase {
  func testSourcesDoNotImportUIOrFirebaseFrameworks() throws {
    let sources = FixtureLoader.repositoryRoot
      .appendingPathComponent("trainer_app/Packages/TrainerCore/Sources", isDirectory: true)
    let forbidden = try NSRegularExpression(pattern: "^import (UIKit|SwiftUI|SwiftData|Firebase)", options: [.anchorsMatchLines])
    guard let walker = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else {
      return XCTFail("cannot enumerate \(sources.path)")
    }
    var scanned = 0
    var violations: [String] = []
    for case let file as URL in walker where file.pathExtension == "swift" {
      scanned += 1
      let text = try String(contentsOf: file, encoding: .utf8)
      let range = NSRange(text.startIndex..., in: text)
      if forbidden.firstMatch(in: text, range: range) != nil {
        violations.append(file.lastPathComponent)
      }
    }
    XCTAssertGreaterThanOrEqual(scanned, 5, "expected at least one source file per TrainerCore target")
    XCTAssertEqual(violations, [], "TrainerCore must not import UIKit, SwiftUI, SwiftData or Firebase")
  }
}
