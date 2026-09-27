#if DEBUG
import CoreGraphics
import Foundation
import TrainerContracts
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

/// What the DEBUG preview consent store starts with (DF-110, DF-113): each member's server state
/// (`memberConsentStates`) and device captures. The chips come out of the real `EffectiveConsentResolver`; a member the
/// script does not name has no consent at all.
struct PreviewConsentScript: Equatable {
  var states: [MemberKey: ConsentState] = [:]
  var captures: [MemberKey: [ConsentCapture]] = [:]

  /// Every member the script names.
  var members: Set<MemberKey> { Set(states.keys).union(captures.keys) }
}

/// DEBUG-only in-memory environment (V1-04 §7.1 rule 5: `Preview*` lives only in `Composition/Preview/`).
/// Synthetic data only: member IDs and names are `SYN-*` placeholders.
struct PreviewEnvironment {
  static let flagsPrefix = "--preview-flags="
  static let widthPrefix = "--preview-width="
  static let landscapeArgument = "--preview-landscape"
  static let resizableArgument = "--preview-resizable"
  static let consentConfirmArgument = "--preview-consent-confirm"

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
  /// `--preview-consent-confirm`: shows a `preview.confirmConsent` button that does what `recordConsent` and the
  /// `memberConsentStates` listener would: every pending capture becomes confirmed and its grants become the server
  /// state (DF-110, DF-113 wiring test).
  let confirmsConsent: Bool
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
    confirmsConsent = arguments.contains(Self.consentConfirmArgument)
  }

  private static func isModifier(_ argument: String) -> Bool {
    argument.hasPrefix(flagsPrefix) || argument.hasPrefix(widthPrefix)
      || argument == landscapeArgument || argument == resizableArgument || argument == consentConfirmArgument
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

  /// The preview consent store's start (DF-110, DF-113). `--preview-members-pending` covers every chip state through
  /// the real resolver: server ①②③ ('동의 ①②③'), nothing ('동의 필요'), a capture the server has not confirmed yet
  /// ('동의 확인 대기') and a capture the server refused ('동의 필요'). Version IDs are the preview's `{type}--1.0`.
  var consentScript: PreviewConsentScript {
    guard scenario == .membersPending else { return PreviewConsentScript() }
    let capturedAt = Date(timeIntervalSince1970: 1_790_000_000)
    func grants(_ types: [ConsentType]) -> [ConsentSelection] {
      types.map { ConsentSelection(consentType: $0, action: .grant, documentVersion: "\($0.rawValue)--1.0") }
    }
    let serverAll = ConsentState(entries: Dictionary(uniqueKeysWithValues: ConsentFlowRules.coreTypes.map {
      ($0, ConsentStateEntry(granted: true, documentVersion: "\($0.rawValue)--1.0"))
    }))
    let awaiting = MemberKey.pending("SynPendingList000001")
    let refused = MemberKey.pending("SynPendingList000003")
    return PreviewConsentScript(
      states: [.uid("syn-0001"): serverAll, .pending("SynPendingList000002"): serverAll],
      captures: [
        // An in-person capture the server has not confirmed yet (F-PRIV-03.7).
        awaiting: [ConsentCapture(captureId: "syn-capture-0001", member: awaiting,
                                  selections: grants(ConsentFlowRules.coreTypes), capturedAt: capturedAt,
                                  state: .pending)],
        // The server refused the capture (③ was not granted): '동의 필요' in the MVP.
        refused: [ConsentCapture(captureId: "syn-capture-0003", member: refused,
                                 selections: grants([.required, .healthData]), capturedAt: capturedAt,
                                 state: .failed)],
      ])
  }
}
#endif
