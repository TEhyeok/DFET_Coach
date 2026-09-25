import Foundation

/// How this process should start (V1-04 §8.1, §19.2).
enum LaunchMode: Equatable {
  /// Release default and Debug with a bundled GoogleService-Info.plist. Talks to the production project.
  case production
  /// DEBUG + `--use-emulator` (optional `--emulator-host=<ip>`, default 127.0.0.1). Project `demo-dfet`
  /// from synthetic options; the plist is neither needed nor read.
  case emulator(host: String)
  /// DEBUG + `--preview-<scenario>`. Firebase is never configured; in-memory synthetic data only.
  case preview(scenario: String)
  /// No usable Firebase configuration. Shows the configuration-missing screen instead of silently
  /// falling back to preview data (NFR-03, ADR-019 §3-3).
  case misconfigured(reason: String)
}

/// Resolves the launch mode once at startup. Pure so it can be tested table-style (TC-DF008-05).
struct LaunchConfiguration: Equatable {
  static let previewPrefix = "--preview-"
  static let useEmulatorFlag = "--use-emulator"
  static let emulatorHostPrefix = "--emulator-host="
  static let defaultEmulatorHost = "127.0.0.1"
  static let missingPlistReason = "missingPlist"

  let mode: LaunchMode

  /// Reads the real process arguments and checks whether `GoogleService-Info.plist` was copied into the
  /// bundle by the "Copy Firebase config if present" build phase. Never reads the plist's values.
  static func resolve(arguments: [String], bundle: Bundle) -> LaunchConfiguration {
    resolve(arguments: arguments, bundle: bundle, environment: ProcessInfo.processInfo.environment)
  }

  /// Same as `resolve(arguments:bundle:)` with an injectable environment so tests can exercise the bundle
  /// lookup without the XCTest guard.
  static func resolve(arguments: [String], bundle: Bundle, environment: [String: String]) -> LaunchConfiguration {
    let arguments = effectiveArguments(arguments, isDebug: isDebugBuild, environment: environment)
    return LaunchConfiguration(
      mode: resolve(arguments: arguments, isDebug: isDebugBuild, plistPresent: plistPresent(in: bundle)))
  }

  /// `true` only in DEBUG builds. Release code paths never parse `--preview-*` or `--use-emulator`.
  static var isDebugBuild: Bool {
    #if DEBUG
    return true
    #else
    return false
    #endif
  }

  /// Process arguments plus the XCTest guard: hosted XCTest bundles must never configure Firebase against a
  /// real project, so a DEBUG process running under XCTest is forced into preview.
  static func effectiveArguments(_ arguments: [String], isDebug: Bool, environment: [String: String]) -> [String] {
    guard isDebug, environment["XCTestConfigurationFilePath"] != nil else { return arguments }
    return arguments + [previewPrefix + "unit-test-host"]
  }

  /// Whether the "Copy Firebase config if present" build phase put the plist into the bundle. Never reads it.
  static func plistPresent(in bundle: Bundle) -> Bool {
    bundle.url(forResource: "GoogleService-Info", withExtension: "plist") != nil
  }

  /// Decision order (P0 DF-008 card):
  /// 1. DEBUG + `--preview-<scenario>` → `.preview` (plist not needed).
  /// 2. DEBUG + `--use-emulator` → `.emulator(host:)` (plist not needed; FirebaseData uses `demo-dfet`).
  /// 3. No plist → `.misconfigured("missingPlist")` (Debug and Release alike).
  /// 4. Otherwise `.production`.
  /// Release builds ignore `--preview-*`, `--use-emulator` and `--emulator-host=`.
  static func resolve(arguments: [String], isDebug: Bool, plistPresent: Bool) -> LaunchMode {
    if isDebug, let flag = arguments.first(where: { $0.hasPrefix(previewPrefix) }) {
      let scenario = String(flag.dropFirst(previewPrefix.count))
      if !scenario.isEmpty {
        return .preview(scenario: scenario)
      }
    }
    if isDebug, arguments.contains(useEmulatorFlag) {
      let host = arguments
        .first(where: { $0.hasPrefix(emulatorHostPrefix) })
        .map { String($0.dropFirst(emulatorHostPrefix.count)) }
        .flatMap { $0.isEmpty ? nil : $0 }
      return .emulator(host: host ?? defaultEmulatorHost)
    }
    guard plistPresent else {
      return .misconfigured(reason: missingPlistReason)
    }
    return .production
  }
}
