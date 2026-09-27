import Foundation
import Observation
import TrainerContracts
import TrainerDomain

/// TR-14, DF-110 MVP. Explicit answers are kept separately from server state; an existing grant is read-only,
/// because withdrawal and reconsent are deferred. A save only acknowledges durable local capture.
@MainActor
@Observable
public final class ConsentFlowModel {
  public enum Stage: Equatable { case handoff, choices, finished, cancelled }
  public enum DocumentState: Equatable { case loading, ready, missing, failed }

  public let member: MemberKey
  public private(set) var stage: Stage = .handoff
  public private(set) var documentState: DocumentState = .loading
  public private(set) var documents: [ConsentType: ConsentDocumentVersion] = [:]
  public private(set) var selections: [ConsentType: Bool] = [:]
  public private(set) var effectiveConsent: EffectiveConsent = .none
  public private(set) var isSaving = false
  public private(set) var saveFailed = false
  public private(set) var didCapture = false
  public var showsRequiredRefusalConfirmation = false

  @ObservationIgnored private let service: any ConsentService
  @ObservationIgnored private var observation: Task<Void, Never>?
  @ObservationIgnored private var loadGeneration = 0

  public init(member: MemberKey, service: any ConsentService) {
    self.member = member
    self.service = service
  }

  deinit { observation?.cancel() }

  public var supportsMember: Bool {
    if case .pending = member { return true }
    return false
  }

  public func start() async {
    guard supportsMember else { documentState = .missing; return }
    if observation == nil {
      let stream = service.observe(member: member)
      observation = Task { [weak self] in
        for await consent in stream {
          guard !Task.isCancelled else { return }
          self?.effectiveConsent = consent
        }
      }
    }
    if documentState != .ready { await reloadDocuments() }
  }

  public func stop() {
    observation?.cancel()
    observation = nil
    loadGeneration += 1
  }

  public func reloadDocuments() async {
    loadGeneration += 1
    let generation = loadGeneration
    documentState = .loading
    do {
      let latest = ConsentFlowRules.latestPublished(try await service.publishedDocuments())
      guard !Task.isCancelled, generation == loadGeneration else { return }
      documents = latest
      documentState = ConsentFlowRules.coreTypes.allSatisfy { latest[$0] != nil } ? .ready : .missing
    } catch {
      guard !Task.isCancelled, generation == loadGeneration else { return }
      documentState = error as? ConsentServiceError == .documentMissing ? .missing : .failed
    }
  }

  public func beginChoices() {
    guard documentState == .ready, supportsMember else { return }
    stage = .choices
  }

  public func isReadOnly(_ type: ConsentType) -> Bool {
    effectiveConsent[type] == .granted || effectiveConsent[type] == .awaitingConsent
  }

  public func choose(_ type: ConsentType, granted: Bool) {
    guard stage == .choices, !isSaving, ConsentFlowRules.coreTypes.contains(type), !isReadOnly(type) else { return }
    selections[type] = granted
    saveFailed = false
  }

  public var canSubmit: Bool {
    guard stage == .choices, documentState == .ready, !isSaving, supportsMember else { return false }
    // Refusing ① cancels registration immediately; asking for ②③ would collect unnecessary answers.
    if selections[.required] == false, !isReadOnly(.required) { return true }
    return ConsentFlowRules.coreTypes.allSatisfy { isReadOnly($0) || selections[$0] != nil }
  }

  public func submit() async {
    guard canSubmit else { return }
    if selections[.required] == false, !isReadOnly(.required) {
      showsRequiredRefusalConfirmation = true
      return
    }
    let answers = ConsentFlowRules.coreTypes.compactMap { type -> ConsentSelection? in
      guard !isReadOnly(type), let granted = selections[type] else { return nil }
      return ConsentSelection(type: type, granted: granted)
    }
    // A status-only visit never creates an additional consent record.
    guard answers.contains(where: \.granted) else { stage = .finished; return }
    isSaving = true
    saveFailed = false
    defer { isSaving = false }
    let versions = Dictionary(uniqueKeysWithValues: answers.compactMap { answer in
      documents[answer.type].map { (answer.type, $0.id) }
    })
    do {
      try await service.captureInPerson(member: member, selections: answers, documentVersions: versions)
      didCapture = true
      stage = .finished
    } catch {
      saveFailed = true
    }
  }

  public func confirmRequiredRefusal() async {
    guard !isSaving, stage == .choices, selections[.required] == false, !isReadOnly(.required) else { return }
    showsRequiredRefusalConfirmation = false
    isSaving = true
    saveFailed = false
    defer { isSaving = false }
    do {
      try await service.cancelPending(member: member)
      stage = .cancelled
    } catch {
      saveFailed = true
    }
  }
}
