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
  /// Like `members`, but the list waits until the test taps `preview.releaseMembers`, so the loading skeleton can be
  /// checked however slow the launch is (AC-DF-013.5).
  case membersSlow = "members-slow"
  /// Two assigned and three pending members, one consent chip state or more each (DF-113, AC-DF-113.1/.2).
  case membersPending = "members-pending"
  /// DesignSystem component gallery (DF-016, TC-DF016-04): no shell, synthetic values.
  case designSystem = "design-system"
  /// TR-15 with two synthetic failed Outbox items (DF-018, TC-DF018-04).
  case queueFailed = "queue-failed"
}

/// Scripted result of the DEBUG preview member directory.
enum PreviewMemberScript: Equatable {
  /// `pending`: the server's pending members (DF-113). `waitsForRelease`: held until `PreviewMemberGate.release()`
  /// (`--preview-members-slow`).
  case members([Member], pending: [PendingMember] = [], waitsForRelease: Bool = false)
  case failure(MemberDirectoryError)
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

  /// What the preview `MemberDirectory` returns (DF-013). An error stays an error, never an empty list.
  var memberScript: PreviewMemberScript {
    switch scenario {
    case .members, .membersSlow:
      return .members((1...3).map { Member(id: "syn-000\($0)", displayName: "SYN-000\($0)", trainerId: "syn-trainer") },
                      waitsForRelease: scenario == .membersSlow)
    case .membersPending:
      return .members(
        (1...2).map { Member(id: "syn-000\($0)", displayName: "SYN-000\($0)", trainerId: "syn-trainer") },
        pending: (1...3).map { PendingMember(id: "SynPendingList00000\($0)", displayName: "SYN-P00\($0)") })
    case .membersEmpty, .empty, .login, .unitTestHost, .designSystem, .queueFailed:
      return .members([])
    case .membersError:
      return .failure(.permissionDenied)
    }
  }

  /// What the preview consent source says per member (DF-113). A member not listed has no consent (`.none`).
  var consentScript: [MemberKey: EffectiveConsent] {
    guard scenario == .membersPending else { return [:] }
    let all = EffectiveConsent(required: .granted, healthData: .granted, bodyImaging: .granted)
    return [
      .uid("syn-0001"): all,
      .uid("syn-0002"): .none,
      // An in-person capture the server has not confirmed yet (F-PRIV-03.7).
      .pending("SynPendingList000001"): EffectiveConsent(
        required: .awaitingConsent, healthData: .awaitingConsent, bodyImaging: .awaitingConsent),
      .pending("SynPendingList000002"): all,
      // The capture was refused by the server: '동의 필요' in the MVP.
      .pending("SynPendingList000003"): EffectiveConsent(required: .rejected, healthData: .rejected, bodyImaging: .missing),
    ]
  }
}
#endif
