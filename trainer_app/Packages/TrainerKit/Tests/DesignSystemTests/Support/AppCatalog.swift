import DesignSystem
import Foundation
import XCTest

/// The app's string catalog read from disk. A package test bundle has no catalog of its own, so tests that check the
/// words the trainer sees look them up here (the same file the app ships).
enum AppCatalog {
  /// trainer_app/ (this file is trainer_app/Packages/TrainerKit/Tests/DesignSystemTests/Support/AppCatalog.swift).
  static let trainerApp: URL = {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<6 { url.deleteLastPathComponent() }
    return url
  }()

  static let repositoryRoot = trainerApp.deletingLastPathComponent()

  static func values() throws -> [String: String] {
    let data = try Data(contentsOf: trainerApp.appendingPathComponent("App/Resources/Localizable.xcstrings"))
    let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    let strings = try XCTUnwrap(root["strings"] as? [String: [String: Any]])
    return strings.compactMapValues { entry in
      ((entry["localizations"] as? [String: Any])?["ko"] as? [String: Any])
        .flatMap { $0["stringUnit"] as? [String: Any] }?["value"] as? String
    }
  }

  /// Fails the lookup of a key the catalog does not have, so a missing catalog entry cannot pass as its key.
  static func localizer() throws -> Localizer {
    let values = try values()
    return Localizer { key in
      guard let value = values[key] else {
        XCTFail("\(key) is not in the app catalog")
        return key
      }
      return value
    }
  }
}
