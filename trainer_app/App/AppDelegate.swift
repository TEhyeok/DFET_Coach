import FirebaseData
import UIKit

/// Configures Firebase through FirebaseData's public API only. The App target never imports a Firebase
/// module (AC-DF-008.2, V1-04 ASM-04-03).
final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    switch DFETTrainerApp.launch.mode {
    case .production:
      FirebaseBootstrap.configure(.production)
    case let .emulator(host):
      FirebaseBootstrap.configure(.emulator(host: host))
    case .preview, .misconfigured:
      break  // no Firebase: preview uses synthetic in-memory data, misconfigured shows a blocking screen
    }
    return true
  }
}
