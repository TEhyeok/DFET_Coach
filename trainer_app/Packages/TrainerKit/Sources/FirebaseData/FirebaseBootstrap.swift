import FirebaseAppCheck
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseFunctions
import Foundation
import os

/// Which Firebase backend the app talks to. The App target decides this in
/// `LaunchConfiguration` and never imports Firebase itself (V1-04 §8.1, ASM-04-03).
public enum FirebaseEnvironment: Equatable, Sendable {
  case production
  case emulator(host: String)
}

/// App Check provider selected for the current build (AC-DF-008.5, NFR-09).
public enum AppCheckProviderKind: Equatable, Sendable {
  /// DEBUG builds: `AppCheckDebugProviderFactory`.
  case debug
  /// Release builds: App Attest (`com.apple.developer.devicecheck.appattest-environment`).
  case appAttest
}

/// The single entry point that configures Firebase. Public API of FirebaseData; the App target calls
/// `FirebaseBootstrap.configure(_:)` and nothing else from Firebase (AC-DF-008.2).
public enum FirebaseBootstrap {
  /// Functions region for callables (ADR-017).
  public static let functionsRegion = "asia-northeast3"

  /// Default ports match firebase.json. DEBUG integration runs can isolate all emulators with one offset.
  public enum EmulatorPort {
    #if DEBUG
    private static let offset: Int = {
      guard let raw = ProcessInfo.processInfo.environment["DFET_EMULATOR_PORT_OFFSET"] else { return 0 }
      guard !raw.isEmpty, raw.utf8.allSatisfy({ (48...57).contains($0) }),
            let value = Int(raw), (0...46336).contains(value) else {
        preconditionFailure("DFET_EMULATOR_PORT_OFFSET must be an integer from 0 through 46336")
      }
      return value
    }()
    #else
    private static let offset = 0
    #endif

    public static let firestore = 18080 + offset
    public static let storage = 19199 + offset
    public static let auth = 19099 + offset
    public static let functions = 5001 + offset
  }

  public static var appCheckProviderKind: AppCheckProviderKind {
    #if DEBUG
    return .debug
    #else
    return .appAttest
    #endif
  }

  /// Project used by every emulator run: local development, UI tests and trainer integration tests
  /// (V1-04 ASM-04-09, V1-10 ASM-10-03, V1-13 §2). The `demo-` prefix never reaches real resources.
  public static let emulatorProjectID = "demo-dfet"

  /// Order matters: App Check provider first, then `FirebaseApp.configure`, then Firestore settings
  /// (V1-04 §10.7). Must be called at most once, from `application(_:didFinishLaunchingWithOptions:)`.
  ///
  /// `.production` reads the bundled `GoogleService-Info.plist`. `.emulator` never reads it: the app is
  /// configured from synthetic `emulatorOptions()` (project `demo-dfet`) and App Check uses a local
  /// provider, so no request can reach the production project.
  private static let configuredEmulatorHost = OSAllocatedUnfairLock<String?>(initialState: nil)

  /// The emulator host `configure` used, or nil for production. Logout re-applies the Firestore settings with it.
  static var emulatorHost: String? { configuredEmulatorHost.withLock { $0 } }

  public static func configure(_ environment: FirebaseEnvironment) {
    AppCheck.setAppCheckProviderFactory(makeAppCheckProviderFactory(for: environment))
    switch environment {
    case .production:
      FirebaseApp.configure()
    case .emulator:
      FirebaseApp.configure(options: emulatorOptions())
    }

    var emulatorHost: String?
    if case let .emulator(host) = environment {
      emulatorHost = host
      configuredEmulatorHost.withLock { $0 = host }
      Auth.auth().useEmulator(withHost: host, port: EmulatorPort.auth)
      StorageFactory.useEmulator(host: host, port: EmulatorPort.storage)
      Functions.functions(region: functionsRegion).useEmulator(withHost: host, port: EmulatorPort.functions)
    }
    // Settings first, then the first use of Firestore (AC-DF-104.1).
    Firestore.firestore().settings = FirestoreConfigurator.settings(emulatorHost: emulatorHost)
  }

  /// Synthetic options for emulator runs. Pure: building `FirebaseOptions` does not configure an app.
  /// The IDs are well-formed placeholders, not a registered app; the API key is not a Google key.
  static func emulatorOptions() -> FirebaseOptions {
    let options = FirebaseOptions(googleAppID: "1:000000000000:ios:0000000000000000", gcmSenderID: "000000000000")
    options.projectID = emulatorProjectID
    options.apiKey = "demo-dfet-emulator-no-key"
    options.storageBucket = "\(emulatorProjectID).appspot.com"
    options.bundleID = Bundle.main.bundleIdentifier ?? "kr.co.dfet.trainer"
    return options
  }

  static func makeAppCheckProviderFactory(for environment: FirebaseEnvironment) -> AppCheckProviderFactory {
    if case .emulator = environment {
      // The App Check exchange endpoint has no emulator; never let it run in emulator mode.
      return EmulatorAppCheckProviderFactory()
    }
    switch appCheckProviderKind {
    case .debug:
      return AppCheckDebugProviderFactory()
    case .appAttest:
      return AppAttestProviderFactory()
    }
  }
}

/// Emulator-only App Check provider: hands out a local placeholder token without any network call.
/// Firebase emulators do not verify App Check tokens.
final class EmulatorAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    EmulatorAppCheckProvider()
  }
}

final class EmulatorAppCheckProvider: NSObject, AppCheckProvider {
  func getToken(completion handler: @escaping (AppCheckToken?, Error?) -> Void) {
    handler(AppCheckToken(token: "emulator", expirationDate: .distantFuture), nil)
  }
}

/// Firebase ships `AppAttestProvider` but no factory for it.
final class AppAttestProviderFactory: NSObject, AppCheckProviderFactory {
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    AppAttestProvider(app: app)
  }
}
