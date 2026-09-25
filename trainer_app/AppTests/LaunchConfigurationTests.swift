import XCTest

/// TC-DF008-05: table-driven checks for `LaunchConfiguration.resolve(arguments:isDebug:plistPresent:)`.
/// `LaunchConfiguration.swift` is compiled straight into this (host-less) bundle, so the app never
/// launches and Firebase is never touched.
final class LaunchConfigurationTests: XCTestCase {
  private struct Case {
    let name: String
    let arguments: [String]
    let isDebug: Bool
    let plistPresent: Bool
    let expected: LaunchMode
  }

  private let cases: [Case] = [
    Case(name: "debug preview without plist", arguments: ["--preview-empty"], isDebug: true, plistPresent: false,
         expected: .preview(scenario: "empty")),
    Case(name: "debug preview wins over emulator", arguments: ["--use-emulator", "--preview-members"], isDebug: true,
         plistPresent: true, expected: .preview(scenario: "members")),
    Case(name: "release ignores preview (plist present)", arguments: ["--preview-empty"], isDebug: false,
         plistPresent: true, expected: .production),
    Case(name: "release ignores preview (no plist) -> misconfigured", arguments: ["--preview-empty"], isDebug: false,
         plistPresent: false, expected: .misconfigured(reason: "missingPlist")),
    Case(name: "debug emulator default host", arguments: ["--use-emulator"], isDebug: true, plistPresent: true,
         expected: .emulator(host: "127.0.0.1")),
    Case(name: "debug emulator custom host", arguments: ["--use-emulator", "--emulator-host=192.168.0.10"],
         isDebug: true, plistPresent: true, expected: .emulator(host: "192.168.0.10")),
    Case(name: "debug emulator without plist -> misconfigured", arguments: ["--use-emulator"], isDebug: true,
         plistPresent: false, expected: .misconfigured(reason: "missingPlist")),
    Case(name: "release ignores emulator", arguments: ["--use-emulator", "--emulator-host=10.0.0.2"], isDebug: false,
         plistPresent: true, expected: .production),
    Case(name: "release without plist -> misconfigured", arguments: [], isDebug: false, plistPresent: false,
         expected: .misconfigured(reason: "missingPlist")),
    Case(name: "debug without plist -> misconfigured (no silent preview)", arguments: [], isDebug: true,
         plistPresent: false, expected: .misconfigured(reason: "missingPlist")),
    Case(name: "release with plist -> production", arguments: [], isDebug: false, plistPresent: true,
         expected: .production),
    Case(name: "empty preview scenario is not a preview", arguments: ["--preview-"], isDebug: true, plistPresent: true,
         expected: .production),
  ]

  func testResolveTable() {
    for c in cases {
      let mode = LaunchConfiguration.resolve(arguments: c.arguments, isDebug: c.isDebug, plistPresent: c.plistPresent)
      XCTAssertEqual(mode, c.expected, c.name)
    }
  }

  func testBundleWithoutPlistResolvesToMisconfiguredOrPreview() {
    // The test bundle never contains GoogleService-Info.plist.
    let resolved = LaunchConfiguration.resolve(arguments: [], bundle: Bundle(for: Self.self))
    switch resolved.mode {
    case .misconfigured(reason: "missingPlist"), .preview:
      break
    default:
      XCTFail("unexpected mode \(resolved.mode)")
    }
  }
}
