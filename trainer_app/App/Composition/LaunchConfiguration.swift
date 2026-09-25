import Foundation

/// How this process should start (V1-04 §8.1, §19.2).
enum LaunchMode: Equatable {
  /// Release default and Debug with a bundled GoogleService-Info.plist. Talks to the production project.
  case production
  /// DEBUG + `--use-emulator` (optional `--emulator-host=<ip>`, default 127.0.0.1). Needs the plist.
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
    #if DEBUG
    let isDebug = true
    #else
    let isDebug = false
    #endif
    var arguments = arguments
    if isDebug, ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
      // Hosted XCTest bundles must never configure Firebase against a real project.
      arguments.append(previewPrefix + "unit-test-host")
    }
    let plistPresent = bundle.url(forResource: "GoogleService-Info", withExtension: "plist") != nil
    return LaunchConfiguration(mode: resolve(arguments: arguments, isDebug: isDebug, plistPresent: plistPresent))
  }

  /// Decision order:
  /// 1. DEBUG + `--preview-<scenario>` → `.preview` (plist not needed).
  /// 2. No plist → `.misconfigured("missingPlist")` (Debug and Release alike; V1-04 §19.2).
  /// 3. DEBUG + `--use-emulator` → `.emulator(host:)`.
  /// 4. Otherwise `.production`.
  /// Release builds ignore `--preview-*`, `--use-emulator` and `--emulator-host=`.
  static func resolve(arguments: [String], isDebug: Bool, plistPresent: Bool) -> LaunchMode {
    if isDebug, let flag = arguments.first(where: { $0.hasPrefix(previewPrefix) }) {
      let scenario = String(flag.dropFirst(previewPrefix.count))
      if !scenario.isEmpty {
        return .preview(scenario: scenario)
      }
    }
    guard plistPresent else {
      return .misconfigured(reason: missingPlistReason)
    }
    if isDebug, arguments.contains(useEmulatorFlag) {
      let host = arguments
        .first(where: { $0.hasPrefix(emulatorHostPrefix) })
        .map { String($0.dropFirst(emulatorHostPrefix.count)) }
        .flatMap { $0.isEmpty ? nil : $0 }
      return .emulator(host: host ?? defaultEmulatorHost)
    }
    return .production
  }
}
