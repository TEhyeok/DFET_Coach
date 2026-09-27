import Foundation
import Observation
import TrainerDomain

/// TR-14 registration state (DF-108). Saving is local and quick; the server create goes through the Outbox.
@MainActor
@Observable
public final class PendingMemberRegistrationModel {
  public var draft = PendingMemberDraft()
  public private(set) var isSaving = false
  /// The member could not be saved on the device (the draft stays filled in).
  public private(set) var saveFailed = false
  /// The member was saved; '다음' stays off so the same draft is never registered twice (review L3).
  public private(set) var didSave = false

  @ObservationIgnored private let registrar: any PendingMemberRegistrar
  @ObservationIgnored private let now: () -> Date

  public init(registrar: any PendingMemberRegistrar, now: @escaping () -> Date = Date.init) {
    self.registrar = registrar
    self.now = now
  }

  public var problems: [PendingMemberDraftProblem] { draft.problems(now: now()) }
  public var canSave: Bool { problems.isEmpty && !isSaving && !didSave }
  /// Shown next to the birth year as soon as an under-14 year is picked (AC-DF-108.2).
  public var showsUnder14Block: Bool { problems.contains(.under14) }

  /// Every year from this Seoul year back to 1900, so a too-recent year can be picked and explained.
  public var years: [Int] {
    Array((AgeGate.minimumBirthYear...AgeGate.currentYear(now: now())).reversed())
  }

  /// The registered member, or nil when nothing was saved.
  public func save() async -> MemberKey? {
    guard canSave else { return nil }
    isSaving = true
    saveFailed = false
    defer { isSaving = false }
    do {
      let id = try await registrar.register(draft)
      didSave = true
      return .pending(id)
    } catch {
      saveFailed = true
      return nil
    }
  }
}
