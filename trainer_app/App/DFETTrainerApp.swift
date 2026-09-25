import SwiftUI

@main
struct DFETTrainerApp: App {
  /// Resolved once per process, before `AppDelegate` runs.
  static let launch = LaunchConfiguration.resolve(arguments: CommandLine.arguments, bundle: .main)

  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup {
      switch Self.launch.mode {
      case .misconfigured:
        ConfigurationMissingView()
      case .production, .emulator, .preview:
        RootPlaceholderView()  // replaced by AppShell in DF-017
      }
    }
  }
}
