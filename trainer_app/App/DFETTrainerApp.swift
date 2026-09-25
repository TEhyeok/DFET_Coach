import SwiftUI

@main
struct DFETTrainerApp: App {
  /// Resolved once per process, at the latest in `AppDelegate`'s `didFinishLaunching`.
  static let environment = AppEnvironment.resolve(
    arguments: LaunchConfiguration.effectiveArguments(
      CommandLine.arguments, isDebug: LaunchConfiguration.isDebugBuild,
      environment: ProcessInfo.processInfo.environment),
    isDebug: LaunchConfiguration.isDebugBuild,
    bootstrap: .firebase(bundle: .main))

  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup {
      AppRootView(environment: Self.environment)
    }
  }
}
