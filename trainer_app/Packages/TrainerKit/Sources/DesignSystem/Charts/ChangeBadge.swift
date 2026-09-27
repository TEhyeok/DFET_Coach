import SwiftUI
import TrainerContracts

/// What a change slot shows (§6.0.3, V1-12 §3.4). v1 has no active change policy, so every slot is `.pendingPolicy`
/// '산정 준비 중' and the values stay visible (AC-DF-130.5, AC-C-03.1). An indeterminate state carries its reason:
/// there is no way to build one without a `ReasonCode` (AC-DF-130.6, AC-C-03.2). The P3 states come with DF-382.
public enum ChangeBadgeState: Hashable, Sendable {
  case pendingPolicy
  case indeterminate(ReasonCode)
}

/// The change slot as a neutral capsule: '산정 준비 중', or a dashed circle and '판정 불가 · {reason}' (the §3.4
/// glyph). No colour carries the meaning (F-VIZ-07.7, A-02).
public struct ChangeBadge: View {
  private let state: ChangeBadgeState
  private let localize: Localizer

  public init(state: ChangeBadgeState, localize: Localizer = .main) {
    self.state = state
    self.localize = localize
  }

  /// `change.pendingPolicy`, or `change.indeterminate.withReason` filled with the `reason.*` label.
  public static func label(_ state: ChangeBadgeState, localize: Localizer) -> String {
    switch state {
    case .pendingPolicy:
      return localize("change.pendingPolicy")
    case .indeterminate(let reason):
      return localize.format("change.indeterminate.withReason", localize("reason.\(reason.rawValue)"))
    }
  }

  public var body: some View {
    HStack(spacing: TrainerSpacing.xs) {
      if case .indeterminate = state {
        Image(systemName: "circle.dashed")
          .accessibilityHidden(true)
      }
      Text(Self.label(state, localize: localize))
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: true)
    }
    .font(.caption.weight(.medium))
    .foregroundStyle(TrainerColor.neutral700)
    .padding(.horizontal, TrainerSpacing.s)
    .padding(.vertical, TrainerSpacing.xxs)
    .background(TrainerColor.neutral100, in: Capsule())
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier(state == .pendingPolicy ? "change.pendingPolicy" : "change.indeterminate")
  }
}
