import SwiftUI

@main
struct DFETTrainerApp: App {
  /// Resolved once per process, at the latest in `AppDelegate`'s `didFinishLaunching`.
  static let environment = AppEnvironment.resolveAtLaunch(
    arguments: CommandLine.arguments, processEnvironment: ProcessInfo.processInfo.environment,
    bootstrap: .firebase(bundle: .main))

  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup {
      AppRootView(environment: Self.environment)
    }
  }
}
