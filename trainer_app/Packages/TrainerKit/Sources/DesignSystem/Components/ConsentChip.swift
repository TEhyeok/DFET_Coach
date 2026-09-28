import SwiftUI
import TrainerDomain

/// A member's consent chip (DF-113 MVP: three states, DF-110 result, DF-111 `EffectiveConsent.chipState`). The only
/// wording: '동의 ①②③' (`tr02.consent.ok`), '동의 필요' (`tr02.consent.needed`), '동의 확인 대기'
/// (`consent.state.awaiting`). Icon and text tell the states apart, never colour alone, and there is no green: green
/// is the synced state's (AC-DF-016.2). `.row` sits in a TR-02 row (VoiceOver reads the row as one sentence);
/// `.result` is TR-14's result after a capture and is one accessibility element whose label is the text.
public struct ConsentChip: View {
  public enum Style: Sendable {
    case row
    case result
  }

  private let state: ConsentChipState
  private let style: Style
  private let localize: Localizer

  public init(state: ConsentChipState, style: Style = .row, localize: Localizer = .main) {
    self.state = state
    self.style = style
    self.localize = localize
  }

  /// Deck key of the state label.
  public static func labelKey(_ state: ConsentChipState) -> String {
    state.copyKey
  }

  public var body: some View {
    let text = localize(Self.labelKey(state))
    // Icon and text in a stack: its ideal size is one line of the whole text, which TR-02's row measures.
    let chip = HStack(spacing: TrainerSpacing.xs) {
      Image(systemName: Self.symbol(state))
        .accessibilityHidden(true)  // the text says it all
      Text(text)
        .fixedSize(horizontal: false, vertical: true)
    }
    .font(style == .row ? .caption.weight(.medium) : .headline)
    .foregroundStyle(Self.tint(state))
    .lineLimit(nil)
    .padding(.horizontal, style == .row ? TrainerSpacing.s : TrainerSpacing.m)
    .padding(.vertical, style == .row ? TrainerSpacing.xxs : TrainerSpacing.s)
    .background(TrainerColor.neutral100, in: RoundedRectangle(cornerRadius: TrainerSpacing.cornerRadius))
    .overlay {
      RoundedRectangle(cornerRadius: TrainerSpacing.cornerRadius).strokeBorder(TrainerColor.neutral400)
    }
    switch style {
    case .row:
      chip
    case .result:
      chip
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text))
    }
  }

  static func symbol(_ state: ConsentChipState) -> String {
    switch state {
    case .coreGranted: return "checkmark.circle"
    case .needed: return "exclamationmark.circle"
    case .awaiting: return "hourglass"
    }
  }

  /// `caution` for what still needs the trainer or the server, as `SyncStateBadge` does for '동의 확인 대기'.
  static func tint(_ state: ConsentChipState) -> Color {
    switch state {
    case .coreGranted: return TrainerColor.neutral700
    case .needed, .awaiting: return TrainerColor.caution
    }
  }
}
