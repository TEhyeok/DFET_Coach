import FirebaseAppCheck
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseFunctions
import FirebaseStorage
import Foundation

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

  /// Emulator ports (V1-10 §4.2, dfet:firebase.json). Auth and Functions ports are added to firebase.json by the seed story.
  public enum EmulatorPort {
    public static let firestore = 18080
    public static let storage = 19199
    public static let auth = 19099
    public static let functions = 5001
  }

  public static var appCheckProviderKind: AppCheckProviderKind {
    #if DEBUG
    return .debug
    #else
    return .appAttest
    #endif
  }

  /// Order matters: App Check provider first, then `FirebaseApp.configure()`, then Firestore settings
  /// (V1-04 §10.7). Must be called at most once, from `application(_:didFinishLaunchingWithOptions:)`.
  public static func configure(_ environment: FirebaseEnvironment) {
    AppCheck.setAppCheckProviderFactory(makeAppCheckProviderFactory())
    FirebaseApp.configure()

    let settings = FirestoreSettings()
    settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: 100 * 1024 * 1024))  // ASM-04-13
    if case let .emulator(host) = environment {
      settings.host = "\(host):\(EmulatorPort.firestore)"
      settings.isSSLEnabled = false
      Auth.auth().useEmulator(withHost: host, port: EmulatorPort.auth)
      Storage.storage().useEmulator(withHost: host, port: EmulatorPort.storage)
      Functions.functions(region: functionsRegion).useEmulator(withHost: host, port: EmulatorPort.functions)
    }
    Firestore.firestore().settings = settings
  }

  static func makeAppCheckProviderFactory() -> AppCheckProviderFactory {
    switch appCheckProviderKind {
    case .debug:
      return AppCheckDebugProviderFactory()
    case .appAttest:
      return AppAttestProviderFactory()
    }
  }
}

/// Firebase ships `AppAttestProvider` but no factory for it.
final class AppAttestProviderFactory: NSObject, AppCheckProviderFactory {
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    AppAttestProvider(app: app)
  }
}
