import DesignSystem
import SwiftUI
import TrainerDomain

/// TR-02 회원 목록 (DF-013, DF-113): assigned and pending members in one list, each with a '대기' badge when pending
/// and its consent chip, and a search field. Copy comes from the app's string catalog (V1-12 `copy_ko.json` keys
/// `tr02.*`, `consent.state.awaiting`, `common.loadFailed`, `common.retry`, `common.loading`). The shell owns
/// navigation: a row tap calls `onSelect` with the member's key, '대기 회원 추가' calls `onAddPending`, and
/// `selectedKey` highlights the member shown in the detail column.
public struct MemberListView: View {
  @Bindable private var model: MemberListViewModel
  private let selectedKey: MemberKey?
  private let onSelect: (MemberKey) -> Void
  private let onAddPending: () -> Void

  public init(
    model: MemberListViewModel, selectedKey: MemberKey? = nil, onSelect: @escaping (MemberKey) -> Void,
    onAddPending: @escaping () -> Void
  ) {
    self.model = model
    self.selectedKey = selectedKey
    self.onSelect = onSelect
    self.onAddPending = onAddPending
  }

  @ScaledMetric(relativeTo: .headline) private var avatarSize: CGFloat = 40

  public var body: some View {
    // No stop on disappear: a size-class change shows a second list before the first one disappears, and the
    // subscription belongs to the shell's model, which cancels it when it is released (sign-out).
    content
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
        searchField
        List {
          ForEach(Array(model.visibleEntries.enumerated()), id: \.element.id) { index, entry in
            Button { onSelect(entry.key) } label: {
              MemberRow(entry: entry, chip: model.chips[entry.key], avatarSize: avatarSize)
            }
            .buttonStyle(.plain)
            .listRowBackground(entry.key == selectedKey ? Color.accentColor.opacity(0.15) : nil)
            .accessibilityIdentifier("tr02.row.\(index)")
            .accessibilityAddTraits(entry.key == selectedKey ? .isSelected : [])
          }
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("tr02.list")
    case .empty:
      // AC-DF-113.3: no assigned and no pending member; the one next action is registering a pending member.
      EmptyState(systemImage: "person.2", titleKey: "tr02.empty", actionKey: "tr02.addPending", action: onAddPending)
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

  /// AC-DF-113.5: filters as the trainer types, on the device only.
  private var searchField: some View {
    HStack(spacing: TrainerSpacing.s) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(TrainerColor.neutral500)
        .accessibilityHidden(true)
      TextField("tr02.search", text: $model.query)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.search)
        .frame(minHeight: TrainerSpacing.minTapTarget)
        .accessibilityIdentifier("tr02.search")
    }
    .padding(.horizontal, TrainerSpacing.m)
    .background(TrainerColor.neutral100, in: RoundedRectangle(cornerRadius: TrainerSpacing.cornerRadius))
    .padding(.horizontal, TrainerSpacing.l)
    .padding(.vertical, TrainerSpacing.s)
  }

  /// Placeholder rows while the first list loads (AC-DF-013.5): one accessibility element read as '불러오는 중'.
  private var skeleton: some View {
    VStack(spacing: 0) {
      List(0..<3, id: \.self) { _ in
        MemberRow(entry: MemberListEntry(key: .uid(""), displayName: "XXXXXXXXXX"), chip: nil, avatarSize: avatarSize)
      }
      .redacted(reason: .placeholder)
      .allowsHitTesting(false)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text("common.loading"))
    .accessibilityIdentifier("tr02.loading")
  }
}
