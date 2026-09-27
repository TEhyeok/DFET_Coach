import DesignSystem
import SwiftUI
import TrainerDomain

/// One TR-02 row: a locally drawn initials avatar, the display name, the '대기' badge of a pending member
/// (`tr02.badge.pending`, AC-DF-113.1) and the consent chip once it is known (AC-DF-113.2). No remote image
/// (AC-DF-013.6, AC-DF-113.4, NFR-11). VoiceOver reads the row as one sentence: name, badge, chip.
struct MemberRow: View {
  let entry: MemberListEntry
  let chip: ConsentChipState?
  let avatarSize: CGFloat

  var body: some View {
    HStack(spacing: TrainerSpacing.m) {
      Text(verbatim: entry.initials)
        .font(.headline)
        .foregroundStyle(.white)
        .frame(width: avatarSize, height: avatarSize)
        .background(Circle().fill(Color.secondary))
        .accessibilityHidden(true)
      // Wide rows keep name, badge and chip on one line; narrow ones (1/3 Split View, large text) wrap instead of
      // truncating the name.
      ViewThatFits(in: .horizontal) {
        HStack(spacing: TrainerSpacing.s) {
          name
          badge
          Spacer(minLength: TrainerSpacing.s)
          consentChip
        }
        VStack(alignment: .leading, spacing: TrainerSpacing.xs) {
          HStack(spacing: TrainerSpacing.s) {
            name
            badge
          }
          consentChip
        }
      }
      Spacer(minLength: 0)
    }
    .frame(minHeight: TrainerSpacing.minTapTarget)
    .contentShape(Rectangle())
  }

  private var name: some View {
    Text(verbatim: entry.displayName.isEmpty ? entry.initials : entry.displayName)
      .font(.body)
      .fixedSize(horizontal: false, vertical: true)
  }

  @ViewBuilder
  private var badge: some View {
    if entry.isPending {
      Text("tr02.badge.pending")
        .font(.caption.weight(.semibold))
        .foregroundStyle(TrainerColor.neutral700)
        .padding(.horizontal, TrainerSpacing.s)
        .padding(.vertical, TrainerSpacing.xxs)
        .background(TrainerColor.neutral200, in: Capsule())
    }
  }

  @ViewBuilder
  private var consentChip: some View {
    if let chip {
      ConsentChip(state: chip)  // DesignSystem, shared with TR-14's result
    }
  }
}
