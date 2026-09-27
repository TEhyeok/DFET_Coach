import Foundation
import Observation
import TrainerContracts
import TrainerDomain

/// TR-14 consent step state (DF-110 MVP): one card per ①②③ with '동의' / '동의하지 않음' and no default, then one
/// local save of the capture (the Outbox sends `recordConsent`), then the member's effective consent as a chip. No
/// signature, no ④⑤, no analytics in the MVP.
@MainActor
@Observable
public final class ConsentStepModel {
  public enum Phase: Equatable, Sendable {
    case loading
    /// The published documents could not be read; `onlineRequired` when only an incomplete cache could answer.
    case loadFailed(onlineRequired: Bool)
    /// A core type has no published version (AC-DF-110.3): nothing can be captured.
    case documentMissing
    case choosing
    case saving
    /// The capture is on the device and queued.
    case saved
  }

  public let member: MemberKey
  public private(set) var phase: Phase = .loading
  /// The newest published version of each core type.
  public private(set) var documents: [ConsentType: ConsentDocumentVersion] = [:]
  /// No answer is preselected (AC-DF-110.2).
  public private(set) var choices: [ConsentType: ConsentChoice] = [:]
  /// The capture could not be saved on the device (the answers stay).
  public private(set) var saveFailed = false
  /// The member's chip from `EffectiveConsent` (DF-111): '동의 ①②③' / '동의 확인 대기' / '동의 필요'.
  public private(set) var chip: ConsentChipState?

  @ObservationIgnored private let catalog: any ConsentDocumentCatalog
  @ObservationIgnored private let recorder: any ConsentCaptureRecorder
  @ObservationIgnored private let consent: any EffectiveConsentSource

  public init(
    member: MemberKey, documents: any ConsentDocumentCatalog, recorder: any ConsentCaptureRecorder,
    consent: any EffectiveConsentSource
  ) {
    self.member = member
    catalog = documents
    self.recorder = recorder
    self.consent = consent
  }

  /// The cards, in order.
  public var types: [ConsentType] { ConsentFlowRules.coreTypes }

  /// ① refused: the step cannot record anything (`consent.requiredFirst`).
  public var requiredRefused: Bool { ConsentFlowRules.requiredRefused(choices) }

  public var canSubmit: Bool {
    phase == .choosing && ConsentFlowRules.selections(choices: choices, documents: documents) != nil
  }

  public func load() async {
    phase = .loading
    do {
      let latest = ConsentFlowRules.latestPublished(try await catalog.publishedDocuments())
      documents = latest
      phase = ConsentFlowRules.missingCoreTypes(in: latest).isEmpty ? .choosing : .documentMissing
    } catch {
      phase = .loadFailed(onlineRequired: (error as? RemoteError) == .unavailable)
    }
  }

  public func choose(_ choice: ConsentChoice, for type: ConsentType) {
    guard phase == .choosing, types.contains(type) else { return }
    choices[type] = choice
  }

  /// Saves the capture once; the step then only shows the result.
  public func submit() async {
    guard canSubmit, let selections = ConsentFlowRules.selections(choices: choices, documents: documents) else {
      return
    }
    phase = .saving
    saveFailed = false
    do {
      _ = try await recorder.capture(member: member, selections: selections)
      phase = .saved
    } catch {
      saveFailed = true
      phase = .choosing
    }
  }

  /// Follows the member's effective consent until the caller's task ends.
  public func watchConsent() async {
    for await value in consent.observe(member: member) {
      chip = value.chipState
    }
  }
}
