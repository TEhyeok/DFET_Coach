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
      // Wide rows keep name, badge and chip on one line, only when all of it fits at its full width (nothing in that
      // line may be squeezed, or a short name or the chip breaks one syllable per line). Otherwise the chip goes under
      // the name; very narrow rows (large text) wrap instead of truncating.
      ViewThatFits(in: .horizontal) {
        HStack(spacing: TrainerSpacing.s) {
          name.fixedSize()
          PendingBadge(isPending: entry.isPending)
          Spacer(minLength: TrainerSpacing.s)
          consentChip.fixedSize()
        }
        VStack(alignment: .leading, spacing: TrainerSpacing.xs) {
          HStack(spacing: TrainerSpacing.s) {
            name
            PendingBadge(isPending: entry.isPending)
          }
          consentChip
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
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
  private var consentChip: some View {
    if let chip {
      ConsentChip(state: chip)  // DesignSystem, shared with TR-14's result
    }
  }
}

/// The '대기' badge of a pending member (`tr02.badge.pending`, AC-DF-113.1), in TR-02 rows and the TR-03 header. Never
/// wrapped: it is one short word.
struct PendingBadge: View {
  let isPending: Bool

  var body: some View {
    if isPending {
      Text("tr02.badge.pending")
        .font(.caption.weight(.semibold))
        .foregroundStyle(TrainerColor.neutral700)
        .padding(.horizontal, TrainerSpacing.s)
        .padding(.vertical, TrainerSpacing.xxs)
        .background(TrainerColor.neutral200, in: Capsule())
        .fixedSize()
    }
  }
}
