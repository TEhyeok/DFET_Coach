import FirebaseData
import Foundation

extension AppBootstrap {
  /// The real bootstrap: plist presence from the bundle and `FirebaseBootstrap.configure(_:)` from FirebaseData.
  /// The App target still imports no Firebase module (AC-DF-008.2, V1-04 ASM-04-03).
  static func firebase(bundle: Bundle) -> AppBootstrap {
    AppBootstrap(plistPresent: LaunchConfiguration.plistPresent(in: bundle)) { backend in
      switch backend {
      case .production:
        FirebaseBootstrap.configure(.production)
      case let .emulator(host):
        FirebaseBootstrap.configure(.emulator(host: host))
      }
    }
  }
}
