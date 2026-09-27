import DesignSystem
import SwiftUI
import TrainerDomain

/// TR-02 회원 목록 (DF-013). Copy comes from the app's string catalog (V1-12 `copy_ko.json` keys `tr02.*`,
/// `common.loadFailed`, `common.retry`; they replace the card's proposed `members.*` keys, V1-12 §1). The shell owns navigation: a row tap calls
/// `onSelect`, and `selectedID` highlights the member shown in the detail column.
public struct MemberListView: View {
  @Bindable private var model: MemberListViewModel
  private let selectedID: String?
  private let onSelect: (Member) -> Void
  private let consentSource: (any EffectiveConsentSource)?

  public init(model: MemberListViewModel, selectedID: String? = nil,
              consentSource: (any EffectiveConsentSource)? = nil, onSelect: @escaping (Member) -> Void) {
    self.model = model
    self.selectedID = selectedID
    self.onSelect = onSelect
    self.consentSource = consentSource
  }

  @ScaledMetric(relativeTo: .headline) private var avatarSize: CGFloat = 40

  public var body: some View {
    // No stop on disappear: a size-class change shows a second list before the first one disappears, and the
    // subscription belongs to the shell's model, which cancels it when it is released (sign-out).
    content
      .searchable(text: $model.searchText, prompt: Text("tr02.search"))
      .onAppear { model.start() }
  }

  @ViewBuilder
  private var content: some View {
    switch model.state {
    case .loading:
      skeleton
    case .loaded:
      // A List does not expose its own identifier to XCUITest; the wrapping container does.
      VStack(spacing: 0) {
        if model.visibleMembers.isEmpty {
          Text("tr02.search.noResult")
            .font(.headline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("tr02.search.noResult")
        } else {
          List {
            ForEach(Array(model.visibleMembers.enumerated()), id: \.element.key) { index, member in
              Button { onSelect(member) } label: {
                MemberRow(member: member, avatarSize: avatarSize, consentSource: consentSource)
              }
              .buttonStyle(.plain)
              .listRowBackground(member.id == selectedID ? Color.accentColor.opacity(0.15) : nil)
              .accessibilityIdentifier("tr02.row.\(index)")
              .accessibilityAddTraits(member.id == selectedID ? .isSelected : [])
            }
          }
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("tr02.list")
    case .empty:
      // The shell owns the '대기 회원 추가' entry point and its sheet.
      Text("tr02.empty")
        .font(.headline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(24)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("tr02.empty")
    case .failed:
      VStack(spacing: 12) {
        Text("common.loadFailed")
          .font(.headline)
        Button { model.retry() } label: {
          Text("common.retry")
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("tr02.retry")
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("tr02.error")
    }
  }

  /// Placeholder rows while the first list loads (AC-DF-013.5): one accessibility element read as '불러오는 중'.
  private var skeleton: some View {
    VStack(spacing: 0) {
      List(0..<3, id: \.self) { _ in
        MemberRow(member: Member(id: "", displayName: "XXXXXXXXXX", trainerId: nil), avatarSize: avatarSize)
      }
      .redacted(reason: .placeholder)
      .allowsHitTesting(false)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text("common.loading"))
    .accessibilityIdentifier("tr02.loading")
  }
}

/// One member row: a locally drawn initials avatar and the display name. No remote image (AC-DF-013.6, NFR-11).
struct MemberRow: View {
  let member: Member
  let avatarSize: CGFloat
  private let consentSource: (any EffectiveConsentSource)?
  @State private var consent: EffectiveConsent?

  init(member: Member, avatarSize: CGFloat, consentSource: (any EffectiveConsentSource)? = nil) {
    self.member = member
    self.avatarSize = avatarSize
    self.consentSource = consentSource
  }

  var body: some View {
    HStack(spacing: 12) {
      Text(verbatim: member.initials)
        .font(.headline)
        .foregroundStyle(.white)
        .frame(width: avatarSize, height: avatarSize)
        .background(Circle().fill(Color.secondary))
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: TrainerSpacing.xs) {
        Text(verbatim: member.displayName.isEmpty ? member.initials : member.displayName)
          .font(.body)
          .fixedSize(horizontal: false, vertical: true)
        ViewThatFits(in: .horizontal) {
          HStack(spacing: TrainerSpacing.xs) { badges }
          VStack(alignment: .leading, spacing: TrainerSpacing.xs) { badges }
        }
      }
      Spacer(minLength: 0)
    }
    .frame(minHeight: 44)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .task(id: member.key) {
      consent = nil
      guard let consentSource else { return }
      for await value in consentSource.observe(member: member.key) {
        guard !Task.isCancelled else { return }
        consent = value
      }
    }
  }

  @ViewBuilder private var badges: some View {
    if member.isPending {
      Text("tr02.badge.pending")
        .font(.caption)
        .padding(.horizontal, TrainerSpacing.s)
        .padding(.vertical, TrainerSpacing.xxs)
        .background(TrainerColor.neutral100, in: Capsule())
        .accessibilityIdentifier("tr02.badge.pending")
    }
    if consentSource != nil {
      let key = consent?.chipState.copyKey ?? "common.loading"
      Text(String(localized: String.LocalizationValue(key), bundle: .main))
        .font(.caption)
        .foregroundStyle(TrainerColor.neutral700)
        .padding(.horizontal, TrainerSpacing.s)
        .padding(.vertical, TrainerSpacing.xxs)
        .background(TrainerColor.neutral100, in: Capsule())
        .accessibilityIdentifier("tr02.consent")
    }
  }
}
