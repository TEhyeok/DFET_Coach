import SwiftUI
import TrainerDomain

/// AppShell (PRD §8.1, V1-07 §3.2): sidebar | content | detail. A compact size class (iPad 1/3 Split View,
/// Slide Over) switches to a NavigationStack. Entry points are filtered by `FlagGate` before any route or button
/// exists (AC-IA-02). Selection lives in `@State` here, so rotation and window resizing keep it (NFR-12).
struct RootSplitView: View {
  let flags: FeatureFlags
  let members: MemberListState

  @Environment(\.horizontalSizeClass) private var sizeClass
  @State private var selection: TrainerRoute?
  @State private var detail: TrainerRoute?
  @State private var stackPath: [TrainerRoute] = []
  @State private var columnVisibility: NavigationSplitViewVisibility = .all
  @State private var comingSoonEntry: EntryPoint?

  init(flags: FeatureFlags, members: MemberListState) {
    self.flags = flags
    self.members = members
    _selection = State(initialValue: TrainerRoute.initial(flags: flags))
  }

  var body: some View {
    Group {
      if sizeClass == .compact {
        stack
      } else {
        split
      }
    }
    .sheet(item: $comingSoonEntry) { _ in
      NavigationStack {
        ComingSoonView()
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button(String(localized: "common.close")) { comingSoonEntry = nil }
                .accessibilityIdentifier("common.close")
            }
          }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("app.root")
  }

  private var sidebarEntries: [EntryPoint] {
    FlagGate.visibleEntries(on: .sidebar, flags: flags)
  }

  // MARK: Regular width: NavigationSplitView

  private var split: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      List(selection: $selection) {
        ForEach(sidebarEntries) { entry in
          if case let .route(route) = entry.destination {
            NavigationLink(value: route) { sidebarLabel(entry) }
              .accessibilityIdentifier(entry.accessibilityID)
          }
        }
      }
      .navigationTitle(String(localized: "app.title"))
    } content: {
      content(for: selection ?? .members)
    } detail: {
      DetailColumn {
        if case let .memberDetail(uid) = detail {
          memberDetail(uid: uid)
        } else {
          Color.clear.accessibilityIdentifier("app.detail.empty")
        }
      }
    }
    .onChange(of: selection) { _, _ in detail = nil }
  }

  // MARK: Compact width: NavigationStack

  private var stack: some View {
    NavigationStack(path: $stackPath) {
      List {
        ForEach(sidebarEntries) { entry in
          if case let .route(route) = entry.destination {
            NavigationLink(value: route) { sidebarLabel(entry) }
              .accessibilityIdentifier(entry.accessibilityID)
          }
        }
      }
      .navigationTitle(String(localized: "app.title"))
      .navigationDestination(for: TrainerRoute.self) { route in
        switch route {
        case let .memberDetail(uid):
          DetailColumn { memberDetail(uid: uid) }
        default:
          content(for: route)
        }
      }
    }
  }

  // MARK: Columns

  private func sidebarLabel(_ entry: EntryPoint) -> some View {
    Label(String(localized: String.LocalizationValue(entry.titleKey)), systemImage: symbol(for: entry))
  }

  private func symbol(for entry: EntryPoint) -> String {
    switch entry {
    case .today: return "sun.max"
    case .members: return "person.2"
    default: return "gearshape"
    }
  }

  /// Content column. TR-01 and TR-15 arrive with DF-125 and DF-018; TR-02 with DF-013.
  @ViewBuilder
  private func content(for route: TrainerRoute) -> some View {
    switch route {
    case .today:
      ComingSoonView().container("tr01.root")
    case .settings:
      ComingSoonView().container("tr15.root")
    case .members, .memberDetail:
      memberList.container("tr02.root")
    }
  }

  @ViewBuilder
  private var memberList: some View {
    switch members {
    case .notConnected:
      ComingSoonView()
    case let .loaded(rows):
      if sizeClass == .compact {
        List(rows) { memberRow($0) }  // links push onto the stack path
      } else {
        List(rows, selection: $detail) { memberRow($0) }  // links select the detail column
      }
    case .empty:
      Text(String(localized: "tr02.empty"))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .failed:
      Text(String(localized: "common.loadFailed"))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func memberRow(_ member: ShellMember) -> some View {
    NavigationLink(value: TrainerRoute.memberDetail(uid: member.id)) {
      Text(verbatim: member.displayName)
    }
    .accessibilityIdentifier("tr02.row.\(member.id)")
  }

  private func memberDetail(uid: String) -> some View {
    MemberDetailShell(entries: FlagGate.visibleEntries(on: .memberDetail, flags: flags)) { entry in
      if entry.destination == .comingSoon {
        comingSoonEntry = entry
      }
    }
    .container("tr03.root")
  }
}

/// TR-03 placeholder: only the flag-gated action row. The screen itself arrives in P1a.
private struct MemberDetailShell: View {
  let entries: [EntryPoint]
  let open: (EntryPoint) -> Void
  @Environment(\.layoutMode) private var layoutMode

  var body: some View {
    let layout = layoutMode == .regular
      ? AnyLayout(HStackLayout(spacing: 12))
      : AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
    ScrollView {
      layout {
        ForEach(entries) { entry in
          Button(String(localized: String.LocalizationValue(entry.titleKey))) { open(entry) }
            .buttonStyle(.bordered)
            .accessibilityIdentifier(entry.accessibilityID)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(24)
    }
  }
}

/// Measures the detail column and publishes `LayoutMode.for(width:)` to its content (V1-07 §3.3).
private struct DetailColumn<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    GeometryReader { proxy in
      content
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .environment(\.layoutMode, LayoutMode.for(width: proxy.size.width))
    }
  }
}

private struct LayoutModeKey: EnvironmentKey {
  static let defaultValue = LayoutMode.compact
}

extension EnvironmentValues {
  var layoutMode: LayoutMode {
    get { self[LayoutModeKey.self] }
    set { self[LayoutModeKey.self] = newValue }
  }
}

private extension View {
  func container(_ identifier: String) -> some View {
    accessibilityElement(children: .contain).accessibilityIdentifier(identifier)
  }
}
