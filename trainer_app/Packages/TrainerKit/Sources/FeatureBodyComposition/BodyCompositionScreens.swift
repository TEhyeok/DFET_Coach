import DesignSystem
import Foundation
import Observation
import TrainerDomain

/// What the AppShell keeps for TR-03's body composition and the TR-11 sheet (DF-127, DF-130), above its
/// regular/compact switch: a size-class change (Split View, Slide Over, Stage Manager) rebuilds TR-03 around the same
/// member model, and an open TR-11 keeps its form and what was typed (NFR-12, V1-07 §3.3; DF-127 second review).
@MainActor
@Observable
public final class BodyCompositionScreens {
  /// The open TR-11 form; nil while TR-11 is closed.
  public private(set) var entry: BodyCompositionEntryModel?
  /// The `bodyComposition` flag as the shell sees it. Turning it off locks an open TR-11 without clearing what was
  /// typed (V1-07 §3.6, ASM-07-06).
  public var isFeatureOn = true {
    didSet { entry?.isFeatureOn = isFeatureOn }
  }

  @ObservationIgnored private let services: BodyCompositionServices
  @ObservationIgnored private let localize: Localizer
  /// The member model of the member on screen. Another member gets a new one, so a fresh subscription.
  @ObservationIgnored private var memberModel: BodyCompositionMemberModel?

  public init(services: BodyCompositionServices, localize: Localizer = .main) {
    self.services = services
    self.localize = localize
  }

  /// The member's model: the one TR-03 and TR-11 already use when it is the same member, else a new one. Made on
  /// first use, so a member whose section is never shown is never subscribed to.
  public func memberModel(for member: MemberKey) -> BodyCompositionMemberModel {
    if let memberModel, memberModel.member == member { return memberModel }
    let model = BodyCompositionMemberModel(member: member, services: services)
    memberModel = model
    return model
  }

  /// '측정 입력 > 신체조성': a new TR-11 form for the member.
  public func openEntry(for member: MemberKey) {
    let form = memberModel(for: member).makeEntryModel(localize: localize)
    form.isFeatureOn = isFeatureOn
    entry = form
  }

  public func closeEntry() {
    entry = nil
  }
}
