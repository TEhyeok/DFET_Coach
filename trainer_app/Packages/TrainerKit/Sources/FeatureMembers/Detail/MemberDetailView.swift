import DesignSystem
import SwiftUI
import TrainerDomain

/// TR-03 회원 상세 셸 (DF-113 AC-DF-113.8): the header (display name, the '대기' badge of a pending member, the consent
/// chip from the same `EffectiveConsent` as the TR-02 row) and `common.comingSoon` where DF-114's timeline comes.
/// `actions` is the shell's flag-gated entry row (DF-017: '세션 시작' only with `soapV2`).
///
/// A pending member whose chip reads '동의 필요' gets '동의 받기' (`tr14.consent.title`), which calls `onTakeConsent`
/// (TR-14's consent step again): the way back for a member whose step was closed, or whose ① was refused, before any
/// consent was recorded. VoiceOver reads the header as one sentence, as the TR-02 row.
public struct MemberDetailView<Actions: View>: View {
  private let entry: MemberListEntry
  private let chip: ConsentChipState?
  private let onTakeConsent: () -> Void
  private let actions: Actions

  public init(
    entry: MemberListEntry, chip: ConsentChipState?, onTakeConsent: @escaping () -> Void,
    @ViewBuilder actions: () -> Actions
  ) {
    self.entry = entry
    self.chip = chip
    self.onTakeConsent = onTakeConsent
    self.actions = actions()
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: TrainerSpacing.l) {
        header
        if entry.isPending, chip == .needed {
          Button { onTakeConsent() } label: {
            Text("tr14.consent.title")
              .frame(minHeight: TrainerSpacing.minTapTarget)
          }
          .buttonStyle(.borderedProminent)
          .tint(TrainerColor.brandBlueFill)
          .accessibilityIdentifier("tr03.takeConsent")
        }
        actions
        ComingSoonLabel()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(TrainerSpacing.xl)
    }
  }

  /// Name, badge and chip on one line when all of it fits at its full width; otherwise the chip goes under the name.
  private var header: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: TrainerSpacing.s) {
        name.fixedSize()
        PendingBadge(isPending: entry.isPending)
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
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isHeader)
    .accessibilityIdentifier("tr03.header")
  }

  private var name: some View {
    Text(verbatim: entry.displayName.isEmpty ? entry.initials : entry.displayName)
      .font(.title2.weight(.semibold))
      .fixedSize(horizontal: false, vertical: true)
  }

  @ViewBuilder
  private var consentChip: some View {
    if let chip {
      ConsentChip(state: chip)
    }
  }
}
