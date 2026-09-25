import UIKit

/// Resolves the environment during launch. `AppEnvironment.resolve` configures Firebase through FirebaseData's
/// public API for live environments only; preview and misconfigured launches make no Firebase call
/// (AC-DF-008.2, AC-DF-017.6).
final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    _ = DFETTrainerApp.environment
    return true
  }
}
