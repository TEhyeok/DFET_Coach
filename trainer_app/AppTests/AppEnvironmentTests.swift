import Foundation
import SyncEngine
import TrainerDomain
import XCTest

/// TC-DF017-01 (AC-DF-017.1, AC-DF-017.6): table-driven `AppEnvironment.resolve(arguments:isDebug:bootstrap:)`.
/// The bootstrap is a spy, so every row also counts Firebase configuration calls.
final class AppEnvironmentTests: XCTestCase {
  private enum Kind: Equatable {
    case live(LiveBackend)
    case preview(PreviewScenario)
    case misconfigured(String)
  }

  private struct Case {
    let name: String
    let arguments: [String]
    let isDebug: Bool
    let plistPresent: Bool
    let expected: Kind
  }

  private let cases: [Case] = [
    // AC-DF-017.1: Release ignores --preview-*; the result is live, never preview.
    Case(name: "AC-DF-017.1 release + --preview-empty -> live", arguments: ["--preview-empty"], isDebug: false,
         plistPresent: true, expected: .live(.production)),
    Case(name: "release + every preview argument -> live",
         arguments: ["--preview-members", "--preview-flags=soapV2", "--preview-landscape", "--preview-width=375"],
         isDebug: false, plistPresent: true, expected: .live(.production)),
    Case(name: "release + --preview-empty without plist -> misconfigured, never preview", arguments: ["--preview-empty"],
         isDebug: false, plistPresent: false, expected: .misconfigured("missingPlist")),
    Case(name: "release + --use-emulator -> production", arguments: ["--use-emulator"], isDebug: false,
         plistPresent: true, expected: .live(.production)),
    // DEBUG: preview only with a --preview-* argument.
    Case(name: "debug + --preview-empty -> preview", arguments: ["--preview-empty"], isDebug: true,
         plistPresent: false, expected: .preview(.empty)),
    Case(name: "debug + --preview-members-error -> preview", arguments: ["--preview-members-error"], isDebug: true,
         plistPresent: true, expected: .preview(.membersError)),
    Case(name: "debug + modifiers only -> preview empty", arguments: ["--preview-landscape"], isDebug: true,
         plistPresent: false, expected: .preview(.empty)),
    Case(name: "debug without preview and with plist -> live", arguments: [], isDebug: true, plistPresent: true,
         expected: .live(.production)),
    Case(name: "debug + --use-emulator -> live emulator", arguments: ["--use-emulator", "--emulator-host=10.0.0.2"],
         isDebug: true, plistPresent: false, expected: .live(.emulator(host: "10.0.0.2"))),
    // AC-DF-017.6: no plist -> configuration-missing, zero Firebase calls.
    Case(name: "AC-DF-017.6 debug without plist -> misconfigured", arguments: [], isDebug: true, plistPresent: false,
         expected: .misconfigured("missingPlist")),
    Case(name: "AC-DF-017.6 release without plist -> misconfigured", arguments: [], isDebug: false, plistPresent: false,
         expected: .misconfigured("missingPlist")),
  ]

  func testResolveTable_TC_DF017_01() {
    for c in cases {
      var configured: [LiveBackend] = []
      let bootstrap = AppBootstrap(plistPresent: c.plistPresent) { configured.append($0) }
      let environment = AppEnvironment.resolve(arguments: c.arguments, isDebug: c.isDebug, bootstrap: bootstrap)
      let kind = Self.kind(of: environment)
      XCTAssertEqual(kind, c.expected, c.name)
      if case let .live(backend) = kind {
        XCTAssertEqual(configured, [backend], "\(c.name): live configures Firebase exactly once")
        XCTAssertEqual(environment.flags, .allOff, "\(c.name): live flags are the fixed .allOff provider in P0")
      } else {
        XCTAssertEqual(configured, [], "\(c.name): Firebase calls must be 0")
      }
    }
  }

  func testPreviewFlagOverrideParsesKnownKeysOnly() {
    let environment = AppEnvironment.resolve(
      arguments: ["--preview-members", "--preview-flags=soapV2,lidarBeta,unknownKey"], isDebug: true,
      bootstrap: AppBootstrap(plistPresent: false) { _ in XCTFail("preview must not configure Firebase") })
    XCTAssertEqual(environment.flags, FeatureFlags(soapV2: true, lidarBeta: true))
    XCTAssertEqual(Self.kind(of: environment), .preview(.members))
  }

  func testPreviewMembersScenariosKeepErrorsDistinctFromEmpty() {
    func script(_ argument: String) -> PreviewMemberScript? {
      guard case let .preview(preview) = AppEnvironment.resolve(
        arguments: [argument], isDebug: true, bootstrap: AppBootstrap(plistPresent: false) { _ in }) else { return nil }
      return preview.memberScript
    }
    XCTAssertEqual(script("--preview-members-empty"), .members([], waitsForRelease: false))
    XCTAssertEqual(script("--preview-members-error"), .failure(.permissionDenied))
    guard case let .members(rows, pending, held)? = script("--preview-members") else { return XCTFail("expected rows") }
    XCTAssertFalse(held)
    XCTAssertEqual(pending, [])
    guard case let .members(_, _, slowHeld)? = script("--preview-members-slow") else { return XCTFail("expected rows") }
    XCTAssertTrue(slowHeld, "the slow list waits for preview.releaseMembers")
    XCTAssertEqual(rows.map(\.id), ["syn-0001", "syn-0002", "syn-0003"])
  }

  /// DF-113: synthetic pending members, and every chip state among the listed members.
  func testPreviewPendingMembersCoverEveryChipState() {
    let preview = PreviewEnvironment(arguments: ["--preview-members-pending"])
    guard case let .members(rows, pending, held) = preview.memberScript else { return XCTFail("expected rows") }
    XCTAssertFalse(held)
    XCTAssertEqual(rows.map(\.displayName), ["SYN-0001", "SYN-0002"])
    XCTAssertEqual(pending.map(\.displayName), ["SYN-P001", "SYN-P002", "SYN-P003"])
    XCTAssertTrue(pending.allSatisfy { DocumentID.isValid($0.id) }, "the rules' pending ID shape")
    let keys = rows.map { MemberKey.uid($0.id) } + pending.map { MemberKey.pending($0.id) }
    let script = preview.consentScript
    XCTAssertTrue(script.members.isSubset(of: Set(keys)), "the script names listed members only")
    // Through the real resolver, as TR-02 reads it: every MVP chip state, in the rows' order.
    let chips = keys.map {
      EffectiveConsentResolver.resolve(server: script.states[$0], captures: script.captures[$0] ?? [],
                                       serverObservedAt: Date()).chipState
    }
    XCTAssertEqual(chips, [.coreGranted, .needed, .awaiting, .coreGranted, .needed])
    for (member, captures) in script.captures {
      XCTAssertTrue(captures.allSatisfy { $0.member == member && !$0.selections.isEmpty }, "\(member)")
    }
    XCTAssertEqual(PreviewEnvironment(arguments: ["--preview-members"]).consentScript, PreviewConsentScript())
  }

  /// `--preview-consent-confirm` is a modifier (DF-113 wiring test), not a scenario.
  func testConsentConfirmModifier() {
    let preview = PreviewEnvironment(arguments: ["--preview-members", "--preview-consent-confirm"])
    XCTAssertEqual(preview.scenario, .members)
    XCTAssertTrue(preview.confirmsConsent)
    XCTAssertEqual(preview.unknownArguments, [])
    XCTAssertFalse(PreviewEnvironment(arguments: ["--preview-members"]).confirmsConsent)
  }


  func testPreviewWidthAndLandscapeModifiers() {
    let preview = PreviewEnvironment(arguments: ["--preview-empty", "--preview-width=375", "--preview-landscape"])
    XCTAssertEqual(preview.simulatedWidth, 375)
    XCTAssertTrue(preview.forcesLandscape)
    XCTAssertNil(PreviewEnvironment(arguments: ["--preview-width=abc"]).simulatedWidth)
    XCTAssertNil(PreviewEnvironment(arguments: ["--preview-width=0"]).simulatedWidth)
  }

  /// A mistyped scenario is reported, never silently run as `empty`; modifiers alone are not unknown.
  func testUnknownPreviewArgumentsAreReported() {
    XCTAssertEqual(PreviewEnvironment(arguments: ["--preview-member", "--preview-flags=soapV2"]).unknownArguments,
                   ["--preview-member"])
    XCTAssertEqual(PreviewEnvironment(arguments: ["--preview-widht=375", "--preview-members"]).unknownArguments,
                   ["--preview-widht=375"])
    let valid = PreviewEnvironment(arguments: [
      "--preview-members", "--preview-flags=soapV2", "--preview-width=375", "--preview-landscape",
      "--preview-resizable", "--preview-unit-test-host", "--use-emulator",
    ])
    XCTAssertEqual(valid.unknownArguments, [])
    XCTAssertTrue(valid.isResizable)
    XCTAssertEqual(valid.scenario, .members)
  }

  private static func kind(of environment: AppEnvironment) -> Kind {
    switch environment {
    case let .live(live): return .live(live.backend)
    case let .preview(preview): return .preview(preview.scenario)
    case let .misconfigured(reason): return .misconfigured(reason)
    }
  }
}
