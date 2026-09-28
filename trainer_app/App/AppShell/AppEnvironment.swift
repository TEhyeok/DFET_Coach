import TrainerDomain

/// Backend of a live environment. `FirebaseAppBootstrap.swift` maps it to FirebaseData's `FirebaseEnvironment`,
/// so this file (and its tests) never import FirebaseData.
enum LiveBackend: Equatable {
  case production
  case emulator(host: String)
}

/// Side effects of choosing an environment, injected so tests can count Firebase calls (AC-DF-017.6).
/// The app passes `.firebase(bundle:)`.
struct AppBootstrap {
  /// Whether `GoogleService-Info.plist` is in the bundle. Its values are never read here.
  var plistPresent: Bool
  /// Configures the live backend (`FirebaseBootstrap.configure(_:)`). Called once, and only for `.live`.
  var configureLive: (LiveBackend) -> Void
  /// The live flags: FirebaseData's `appConfig/features` subscription (`FirestoreFeatureFlags`). Called only for
  /// `.live`, after `configureLive`; it touches Firestore only when the signed-in shell subscribes.
  var liveFlags: () -> any FeatureFlagsProvider = { FixedFeatureFlagsProvider.allOff }
}

/// Dependencies of a live (production or emulator) process: FirebaseData implementations.
struct LiveEnvironment {
  let backend: LiveBackend
  /// `appConfig/features` as it changes (DF-127 review): missing document or a failed read is every flag off.
  let flagsProvider: any FeatureFlagsProvider
}

/// Dependency container chosen once at launch (V1-04 §8). Preview (in-memory fakes) exists only in DEBUG builds
/// and only when a `--preview-*` argument is present (NFR-03). Release has no preview case at all.
enum AppEnvironment {
  case live(LiveEnvironment)
  #if DEBUG
  case preview(PreviewEnvironment)
  #endif
  /// No usable Firebase configuration: the configuration-missing screen, zero Firebase calls.
  case misconfigured(reason: String)

  /// The environment's flags now; the shell follows `flagsProvider.updates()`.
  var flags: FeatureFlags { flagsProvider.current }

  var flagsProvider: any FeatureFlagsProvider {
    switch self {
    case let .live(live): return live.flagsProvider
    #if DEBUG
    case let .preview(preview): return preview.flagsProvider
    #endif
    case .misconfigured: return FixedFeatureFlagsProvider.allOff
    }
  }

  /// The app's launch path (`DFETTrainerApp.environment`): process arguments plus the XCTest guard, the build's
  /// DEBUG flag, then `resolve(arguments:isDebug:bootstrap:)`. Tests call this same function.
  static func resolveAtLaunch(
    arguments: [String], processEnvironment: [String: String], bootstrap: AppBootstrap
  ) -> AppEnvironment {
    let isDebug = LaunchConfiguration.isDebugBuild
    return resolve(
      arguments: LaunchConfiguration.effectiveArguments(arguments, isDebug: isDebug, environment: processEnvironment),
      isDebug: isDebug, bootstrap: bootstrap)
  }

  /// Decides the environment from the launch mode (`LaunchConfiguration`, DF-008) and configures Firebase for
  /// `.live` only. `isDebug == false` ignores every `--preview-*` argument, so Release never gets preview data.
  static func resolve(arguments: [String], isDebug: Bool, bootstrap: AppBootstrap) -> AppEnvironment {
    switch LaunchConfiguration.resolve(arguments: arguments, isDebug: isDebug, plistPresent: bootstrap.plistPresent) {
    case .production:
      bootstrap.configureLive(.production)
      return .live(LiveEnvironment(backend: .production, flagsProvider: bootstrap.liveFlags()))
    case let .emulator(host):
      bootstrap.configureLive(.emulator(host: host))
      return .live(LiveEnvironment(backend: .emulator(host: host), flagsProvider: bootstrap.liveFlags()))
    case .preview:
      #if DEBUG
      return .preview(PreviewEnvironment(arguments: arguments))
      #else
      // Unreachable: LaunchConfiguration never returns .preview when isDebug is false. Block, never fall back.
      return .misconfigured(reason: "previewUnavailable")
      #endif
    case let .misconfigured(reason):
      return .misconfigured(reason: reason)
    }
  }
}
