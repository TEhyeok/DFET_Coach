import Foundation
import Observation
import TrainerContracts
import TrainerDomain

/// TR-14 consent step state (DF-110 MVP): one card per ①②③ with '동의' / '동의하지 않음' and no default, then one
/// local save of the capture (the Outbox sends `recordConsent`), then the member's effective consent as a chip. No
/// signature, no ④⑤, no analytics in the MVP. A pending member who refuses ① can have the registration cancelled
/// here instead (AC-DF-110.5): nothing is recorded and `pendingMembers/{id}` becomes `cancelled` through the Outbox.
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
    /// ① was refused and the pending member's registration is cancelled (AC-DF-110.5): nothing was recorded.
    case registrationCancelled
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
  @ObservationIgnored private let canceller: (any PendingMemberCanceller)?

  /// `canceller` nil: a refused ① only blocks the step (no '등록 취소').
  public init(
    member: MemberKey, documents: any ConsentDocumentCatalog, recorder: any ConsentCaptureRecorder,
    consent: any EffectiveConsentSource, canceller: (any PendingMemberCanceller)? = nil
  ) {
    self.member = member
    catalog = documents
    self.recorder = recorder
    self.consent = consent
    self.canceller = canceller
  }

  /// The cards, in order.
  public var types: [ConsentType] { ConsentFlowRules.coreTypes }

  /// ① refused: the step cannot record anything (`consent.requiredFirst`).
  public var requiredRefused: Bool { ConsentFlowRules.requiredRefused(choices) }

  public var canSubmit: Bool {
    phase == .choosing && ConsentFlowRules.selections(choices: choices, documents: documents) != nil
  }

  /// AC-DF-110.5: ① refused for a pending member offers '등록 취소'. A uid member's refusal only closes the step.
  public var canCancelRegistration: Bool {
    guard case .pending = member, canceller != nil else { return false }
    return phase == .choosing && requiredRefused
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

  /// AC-DF-110.5, after the trainer confirmed: the pending member's cancel is saved on the device and queued (the Outbox
  /// sends `status: 'cancelled'`); no consent is recorded. A failed save keeps the answers.
  public func cancelRegistration() async {
    guard canCancelRegistration, case let .pending(id) = member, let canceller else { return }
    phase = .saving
    saveFailed = false
    do {
      try await canceller.cancel(pendingMemberId: id)
      phase = .registrationCancelled
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
