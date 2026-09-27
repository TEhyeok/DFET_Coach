import DesignSystem
import SwiftUI
import TrainerDomain

/// The consent chip of a TR-02 row (AC-DF-113.2, DF-113 MVP: three states). It shows `EffectiveConsent.chipState` and
/// nothing else: '동의 ①②③' (`tr02.consent.ok`), '동의 필요' (`tr02.consent.needed`) or '동의 확인 대기'
/// (`consent.state.awaiting`). Icon and text tell the states apart, never colour alone; no green (AC-DF-016.2).
struct ConsentStatusChip: View {
  let state: ConsentChipState

  var body: some View {
    Label {
      Text(Self.label(state))
    } icon: {
      Image(systemName: Self.symbol(state))
        .accessibilityHidden(true)  // the text says it all; VoiceOver reads the row as one sentence
    }
    .font(.caption.weight(.medium))
    .foregroundStyle(Self.tint(state))
    .lineLimit(nil)
    .fixedSize(horizontal: false, vertical: true)
    .padding(.horizontal, TrainerSpacing.s)
    .padding(.vertical, TrainerSpacing.xxs)
    .background(TrainerColor.neutral100, in: RoundedRectangle(cornerRadius: TrainerSpacing.cornerRadius))
    .overlay {
      RoundedRectangle(cornerRadius: TrainerSpacing.cornerRadius).strokeBorder(TrainerColor.neutral400)
    }
  }

  /// The deck text of the state. The key is a `String` value, never an interpolated literal (SE-0213).
  static func label(_ state: ConsentChipState) -> String {
    let key = state.copyKey
    return String(localized: String.LocalizationValue(key), bundle: .main)
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
