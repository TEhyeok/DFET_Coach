#if DEBUG
import CoreGraphics
import TrainerDomain

/// Named `--preview-<scenario>` launches (DF-017 card, README "Preview arguments"). An unknown name is reported in
/// `PreviewEnvironment.unknownArguments` and blocks the shell, so a mistyped UI-test argument fails loudly.
enum PreviewScenario: String, CaseIterable {
  case empty
  /// Added by `LaunchConfiguration.effectiveArguments` when a hosted XCTest bundle launches the app.
  case unitTestHost = "unit-test-host"
  case login
  case members
  case membersEmpty = "members-empty"
  case membersError = "members-error"
}

/// DEBUG-only in-memory environment (V1-04 §7.1 rule 5: `Preview*` lives only in `Composition/Preview/`).
/// Synthetic data only: member IDs and names are `SYN-*` placeholders.
struct PreviewEnvironment {
  static let flagsPrefix = "--preview-flags="
  static let widthPrefix = "--preview-width="
  static let landscapeArgument = "--preview-landscape"
  static let resizableArgument = "--preview-resizable"

  let scenario: PreviewScenario
  /// `--preview-flags=soapV2,lidarBeta`: local DEBUG override of the client entry points only; rules still use
  /// the emulator's `appConfig/features` (ADR-010 §3-6). Unknown keys are ignored.
  let flagsProvider: FixedFeatureFlagsProvider
  /// `--preview-landscape` (ported from dfet:trainer_ios/DFETTrainer/App/DFETTrainerApp.swift:76).
  let forcesLandscape: Bool
  /// `--preview-width=375`: renders the shell in a window of this width with a compact size class, to simulate
  /// a 1/3 Split View (AC-DF-017.4).
  let simulatedWidth: CGFloat?
  /// `--preview-resizable` (with `--preview-width=`): shows a `preview.toggleWidth` button that switches between the
  /// simulated width and the full window at runtime, to test size-class changes (TC-DF017-06).
  let isResizable: Bool
  /// `--preview-*` arguments that are neither a scenario nor a modifier. Non-empty means a typo.
  let unknownArguments: [String]

  init(arguments: [String]) {
    let names = arguments
      .filter { $0.hasPrefix(LaunchConfiguration.previewPrefix) }
      .map { String($0.dropFirst(LaunchConfiguration.previewPrefix.count)) }
    scenario = names.lazy.compactMap(PreviewScenario.init(rawValue:)).first ?? .empty
    unknownArguments = arguments.filter {
      $0.hasPrefix(LaunchConfiguration.previewPrefix) && !Self.isModifier($0)
        && PreviewScenario(rawValue: String($0.dropFirst(LaunchConfiguration.previewPrefix.count))) == nil
    }

    let flagKeys = arguments
      .filter { $0.hasPrefix(Self.flagsPrefix) }
      .flatMap { $0.dropFirst(Self.flagsPrefix.count).split(separator: ",") }
      .compactMap { FeatureFlags.Key(rawValue: String($0)) }
    flagsProvider = FixedFeatureFlagsProvider(FeatureFlags(enabled: Set(flagKeys)))

    forcesLandscape = arguments.contains(Self.landscapeArgument)

    simulatedWidth = arguments
      .first { $0.hasPrefix(Self.widthPrefix) }
      .flatMap { Double($0.dropFirst(Self.widthPrefix.count)) }
      .flatMap { $0 > 0 ? CGFloat($0) : nil }

    isResizable = arguments.contains(Self.resizableArgument)
  }

  private static func isModifier(_ argument: String) -> Bool {
    argument.hasPrefix(flagsPrefix) || argument.hasPrefix(widthPrefix)
      || argument == landscapeArgument || argument == resizableArgument
  }

  var isSignedIn: Bool { scenario != .login }

  var members: MemberListState {
    switch scenario {
    case .members:
      return .loaded((1...3).map { ShellMember(id: "syn-000\($0)", displayName: "SYN-000\($0)") })
    case .membersEmpty, .empty, .login, .unitTestHost:
      return .empty
    case .membersError:
      return .failed
    }
  }
}
#endif
