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
    Case(name: "debug emulator without plist (demo-dfet, plist not read)", arguments: ["--use-emulator"],
         isDebug: true, plistPresent: false, expected: .emulator(host: "127.0.0.1")),
    Case(name: "release ignores emulator", arguments: ["--use-emulator", "--emulator-host=10.0.0.2"], isDebug: false,
         plistPresent: true, expected: .production),
    Case(name: "release ignores emulator (no plist) -> misconfigured", arguments: ["--use-emulator"], isDebug: false,
         plistPresent: false, expected: .misconfigured(reason: "missingPlist")),
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

  /// The app's launch path (`AppEnvironment.resolveAtLaunch`) with the real `bundle.url(forResource:)` lookup: the
  /// test bundle never contains the plist, so the result is misconfigured with zero Firebase calls.
  func testLaunchPathWithoutPlistResolvesToMisconfigured() {
    let environment = AppEnvironment.resolveAtLaunch(
      arguments: [], processEnvironment: [:],
      bootstrap: AppBootstrap(plistPresent: LaunchConfiguration.plistPresent(in: Bundle(for: Self.self))) { _ in
        XCTFail("misconfigured must not configure Firebase")
      })
    guard case let .misconfigured(reason) = environment else { return XCTFail("expected misconfigured") }
    XCTAssertEqual(reason, "missingPlist")
  }

  /// The launch path forces a DEBUG process hosted by XCTest into preview even when a plist is present.
  func testLaunchPathForcesXCTestHostIntoPreview() {
    #if DEBUG
    let environment = AppEnvironment.resolveAtLaunch(
      arguments: [], processEnvironment: ["XCTestConfigurationFilePath": "/tmp/x"],
      bootstrap: AppBootstrap(plistPresent: true) { _ in XCTFail("an XCTest host must not configure Firebase") })
    guard case let .preview(preview) = environment else { return XCTFail("expected preview") }
    XCTAssertEqual(preview.scenario, .unitTestHost)
    XCTAssertEqual(preview.unknownArguments, [])
    #endif
  }
}
