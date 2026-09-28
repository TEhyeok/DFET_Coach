import DesignSystem
import SwiftUI
import TrainerDomain

/// TR-02 회원 목록 (DF-013, DF-113): assigned and pending members in one list, each with a '대기' badge when pending
/// and its consent chip, and a search field. Copy comes from the app's string catalog (V1-12 `copy_ko.json` keys
/// `tr02.*`, `consent.state.awaiting`, `common.loadFailed`, `common.retry`, `common.loading`). The shell owns
/// navigation: a row tap calls `onSelect` with the member's key, '대기 회원 추가' calls `onAddPending`, and
/// `selectedKey` highlights the member shown in the detail column.
///
/// A pending row has a menu (long press or secondary click, AC-DF-113.6): '동의 받기' (`tr14.consent.title`) while
/// its chip reads '동의 필요', which calls `onTakeConsent` (TR-14's consent step again: the way back for a member whose
/// step was closed or refused), and '등록 취소' (`tr02.menu.cancelPending`), confirmed with `tr02.cancelPending.confirm`.
/// Assigned rows have no menu.
public struct MemberListView: View {
  @Bindable private var model: MemberListViewModel
  private let selectedKey: MemberKey?
  private let onSelect: (MemberKey) -> Void
  private let onAddPending: () -> Void
  private let onTakeConsent: (MemberKey) -> Void
  /// The pending member whose '등록 취소' waits for the trainer's confirmation.
  @State private var cancelling: MemberKey?

  public init(
    model: MemberListViewModel, selectedKey: MemberKey? = nil, onSelect: @escaping (MemberKey) -> Void,
    onAddPending: @escaping () -> Void, onTakeConsent: @escaping (MemberKey) -> Void = { _ in }
  ) {
    self.model = model
    self.selectedKey = selectedKey
    self.onSelect = onSelect
    self.onAddPending = onAddPending
    self.onTakeConsent = onTakeConsent
  }

  @ScaledMetric(relativeTo: .headline) private var avatarSize: CGFloat = 40

  public var body: some View {
    // No stop on disappear: a size-class change shows a second list before the first one disappears, and the
    // subscription belongs to the shell's model, which cancels it when it is released (sign-out).
    content
      .onAppear { model.start() }
      .alert(Text("tr02.menu.cancelPending"), isPresented: isConfirmingCancel, presenting: cancelling) { key in
        Button(role: .destructive) {
          Task { await model.cancelPending(key) }
        } label: {
          Text("tr02.menu.cancelPending")
        }
        .accessibilityIdentifier("tr02.cancelPending.confirm")
        Button(role: .cancel) {} label: { Text("common.cancel") }
      } message: { _ in
        Text("tr02.cancelPending.confirm")
      }
      .alert(Text("common.devDefect"), isPresented: isShowingCancelFailure) {
        Button(role: .cancel) { model.dismissCancelFailure() } label: { Text("common.confirm") }
      }
  }

  private var isConfirmingCancel: Binding<Bool> {
    Binding(get: { cancelling != nil }, set: { if !$0 { cancelling = nil } })
  }

  private var isShowingCancelFailure: Binding<Bool> {
    Binding(get: { model.cancelFailed }, set: { if !$0 { model.dismissCancelFailure() } })
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
            row(entry)
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

  @ViewBuilder
  private func row(_ entry: MemberListEntry) -> some View {
    let button = Button { onSelect(entry.key) } label: {
      MemberRow(entry: entry, chip: model.chips[entry.key], avatarSize: avatarSize)
    }
    .buttonStyle(.plain)
    if entry.isPending {
      button.contextMenu {
        if model.chips[entry.key] == .needed {
          Button { onTakeConsent(entry.key) } label: {
            Label { Text("tr14.consent.title") } icon: { Image(systemName: "checkmark.shield") }
          }
          .accessibilityIdentifier("tr02.menu.takeConsent")
        }
        if model.canCancelPending {
          Button(role: .destructive) { cancelling = entry.key } label: {
            Label { Text("tr02.menu.cancelPending") } icon: { Image(systemName: "person.badge.minus") }
          }
          .accessibilityIdentifier("tr02.menu.cancelPending")
        }
      }
    } else {
      button
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
