import SwiftUI
import TrainerDomain

/// TR-02 회원 목록 (DF-013). Copy comes from the app's string catalog (V1-12 `copy_ko.json` keys `tr02.*`,
/// `common.loadFailed`, `common.retry`; they replace the card's proposed `members.*` keys, V1-12 §1). The shell owns navigation: a row tap calls
/// `onSelect`, and `selectedID` highlights the member shown in the detail column.
public struct MemberListView: View {
  private let model: MemberListViewModel
  private let selectedID: String?
  private let onSelect: (Member) -> Void

  public init(model: MemberListViewModel, selectedID: String? = nil, onSelect: @escaping (Member) -> Void) {
    self.model = model
    self.selectedID = selectedID
    self.onSelect = onSelect
  }

  public var body: some View {
    content
      .task { model.start() }
  }

  @ViewBuilder
  private var content: some View {
    switch model.state {
    case .loading:
      skeleton
    case let .loaded(members):
      // A List does not expose its own identifier to XCUITest; the wrapping container does.
      VStack(spacing: 0) {
        List {
          ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
            Button { onSelect(member) } label: {
              MemberRow(member: member)
            }
            .buttonStyle(.plain)
            .listRowBackground(member.id == selectedID ? Color.accentColor.opacity(0.15) : nil)
            .accessibilityIdentifier("tr02.row.\(index)")
            .accessibilityAddTraits(member.id == selectedID ? .isSelected : [])
          }
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("tr02.list")
    case .empty:
      // No next action: assignment happens in admin_web, and DF-113 adds the pending-member rows and entry point.
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

  /// Placeholder rows while the first list loads (AC-DF-013.5).
  private var skeleton: some View {
    List(0..<4, id: \.self) { _ in
      MemberRow(member: Member(id: "", displayName: "XXXXXXXXXX", trainerId: nil))
    }
    .redacted(reason: .placeholder)
    .allowsHitTesting(false)
    .accessibilityIdentifier("tr02.loading")
  }
}

/// One member row: a locally drawn initials avatar and the display name. No remote image (AC-DF-013.6, NFR-11).
struct MemberRow: View {
  let member: Member

  var body: some View {
    HStack(spacing: 12) {
      Text(verbatim: member.initials)
        .font(.headline)
        .foregroundStyle(.white)
        .frame(width: 40, height: 40)
        .background(Circle().fill(Color.secondary))
        .accessibilityHidden(true)
      Text(verbatim: member.displayName)
        .font(.body)
      Spacer(minLength: 0)
    }
    .frame(minHeight: 44)
    .contentShape(Rectangle())
  }
}
