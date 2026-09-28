import FirebaseAuth
import Foundation
import TrainerDomain
import XCTest
@testable import DFETTrainer

/// DF-127 review finding 1: live and emulator builds get their flags from `appConfig/features` through the provider
/// the app's bootstrap hands the shell (FirebaseData `FirestoreFeatureFlags`), not a fixed all-off one. Against the Auth
/// and Firestore emulators with the repository rules: a signed-in trainer reads the document; `bodyComposition: true`
/// puts '신체조성' in TR-03's '측정 입력' menu, a change reaches an open subscription (no relaunch), and `false`, no
/// document or a refused read takes it away (fail-closed). Synthetic data only.
final class FeatureFlagsEmulatorTests: XCTestCase {
  private var configured = false

  override func setUpWithError() throws {
    try IntegrationEmulator.require("DFET_AUTH_EMULATOR", "DFET_FIRESTORE_EMULATOR")
    try IntegrationEmulator.configure()
    configured = true
    try? Auth.auth().signOut()
  }

  override func tearDownWithError() throws {
    guard configured else { return }
    try? Auth.auth().signOut()
  }

  /// The live provider exactly as the app resolves it for `--use-emulator` (Firebase is already configured here).
  @MainActor
  private func liveProvider() -> any FeatureFlagsProvider {
    let bootstrap = AppBootstrap(plistPresent: false, configureLive: { _ in },
                                 liveFlags: AppBootstrap.firebase(bundle: .main).liveFlags)
    return AppEnvironment.resolve(arguments: ["--use-emulator"], isDebug: true, bootstrap: bootstrap).flagsProvider
  }

  /// One subscription's values up to and including the first that `done` takes after `action` ran. `action` runs once,
  /// at the first value `ready` takes (a stale cached value before it is only collected). nil when nothing is done
  /// within `seconds`.
  private func values(
    of provider: any FeatureFlagsProvider, seconds: Double = 15,
    when ready: @escaping @Sendable (FeatureFlags) -> Bool = { _ in true },
    then action: @escaping @Sendable () async throws -> Void = {},
    until done: @escaping @Sendable (FeatureFlags) -> Bool
  ) async throws -> [FeatureFlags]? {
    try await withThrowingTaskGroup(of: [FeatureFlags]?.self) { group in
      group.addTask {
        var seen: [FeatureFlags] = []
        var acted = false
        for await flags in provider.updates() {
          seen.append(flags)
          if !acted, ready(flags) {
            acted = true
            try await action()
          }
          if acted, done(flags) { return seen }
        }
        return nil
      }
      group.addTask {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        return nil
      }
      let first = try await group.next() ?? nil
      group.cancelAll()
      return first
    }
  }

  @MainActor
  func testTheLiveFlagsFollowAppConfigFeatures() async throws {
    let trainer = try await EmulatorAccounts.create(claims: ["trainer": true])
    try await EmulatorDocuments.put("appConfig/features", ["bodyComposition": true, "soapV2": false])
    _ = try await AppBootstrap.liveAuthService().signIn(email: trainer.email, password: trainer.password)
    let provider = liveProvider()

    // The trainer reads the document: '신체조성' is in TR-03's '측정 입력' menu.
    let first = try await values(of: provider, until: { $0.bodyComposition })
    let on = try XCTUnwrap(first?.last, "no bodyComposition: true")
    XCTAssertEqual(on, FeatureFlags(bodyComposition: true))
    XCTAssertEqual(FlagGate.visibleEntries(on: .measureMenu, flags: on), [.bodyComposition, .circumference])
    XCTAssertEqual(provider.current, on, "the shell's first value")

    // A change reaches the open subscription while the app runs: on, then off.
    let changed = try await values(of: provider, when: { $0.bodyComposition }, then: {
      try await EmulatorDocuments.put("appConfig/features", ["bodyComposition": false])
    }, until: { !$0.bodyComposition })
    XCTAssertEqual(changed?.last, .allOff, "the subscription that had the flag on got the change")
    XCTAssertEqual(FlagGate.visibleEntries(on: .measureMenu, flags: try XCTUnwrap(changed?.last)), [], "no menu")

    // No document: every flag off.
    try await EmulatorDocuments.put("appConfig/features", ["bodyComposition": true])
    let deleted = try await values(of: provider, when: { $0.bodyComposition }, then: {
      try await EmulatorDocuments.delete("appConfig/features")
    }, until: { !$0.bodyComposition })
    XCTAssertEqual(deleted?.last, .allOff)
  }

  /// A read the rules refuse (nobody signed in: `appConfig` needs `isAuth()`) is every flag off, and the stream ends.
  @MainActor
  func testARefusedReadIsEveryFlagOff() async throws {
    try await EmulatorDocuments.put("appConfig/features", ["bodyComposition": true])
    let provider = liveProvider()
    let received = try await withThrowingTaskGroup(of: [FeatureFlags]?.self) { group in
      group.addTask {
        var seen: [FeatureFlags] = []
        for await flags in provider.updates() { seen.append(flags) }
        return seen  // the stream ended
      }
      group.addTask {
        try await Task.sleep(nanoseconds: 15_000_000_000)
        return nil
      }
      let first = try await group.next() ?? nil
      group.cancelAll()
      return first
    }
    let seen = try XCTUnwrap(received, "a refused read ends the stream")
    XCTAssertFalse(seen.isEmpty)
    XCTAssertEqual(Set(seen), [.allOff])
    XCTAssertEqual(provider.current, .allOff)
  }
}
