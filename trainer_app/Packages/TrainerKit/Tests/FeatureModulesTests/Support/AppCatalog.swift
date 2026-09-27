import Foundation
import XCTest

/// The app's string catalog read from disk. A package test bundle has no catalog of its own, so tests that check the
/// words the trainer sees look them up here (the same file the app ships).
enum AppCatalog {
  /// `ko` values of trainer_app/App/Resources/Localizable.xcstrings (this file is
  /// trainer_app/Packages/TrainerKit/Tests/FeatureModulesTests/Support/AppCatalog.swift).
  static func values() throws -> [String: String] {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<6 { url.deleteLastPathComponent() }  // …/trainer_app
    let data = try Data(contentsOf: url.appendingPathComponent("App/Resources/Localizable.xcstrings"))
    let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    let strings = try XCTUnwrap(root["strings"] as? [String: [String: Any]])
    return strings.compactMapValues { entry in
      ((entry["localizations"] as? [String: Any])?["ko"] as? [String: Any])
        .flatMap { $0["stringUnit"] as? [String: Any] }?["value"] as? String
    }
  }
}
