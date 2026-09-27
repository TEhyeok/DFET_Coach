import FeatureConsent
import FeatureMembers
import FeatureSettings
import SwiftUI
import TrainerDomain

/// AppShell (PRD §8.1, V1-07 §3.2): sidebar | content | detail. A compact size class (iPad 1/3 Split View,
/// Slide Over) switches to a NavigationStack. Entry points are filtered by `FlagGate` before any route or button
/// exists (AC-IA-02).
///
/// State survives layout changes (NFR-12, V1-07 §3.3): rotation keeps the same view tree, and a size-class change
/// (Split View, Slide Over or Stage Manager resize) converts `navigation` to `stackPath` and back through
/// `ShellNavigation`, so the user stays on the same TR screen.
struct RootSplitView: View {
  private let baseFlags: FeatureFlags
  /// The environment's flags; in DEBUG with TR-15's local override applied (AC-DF-018.4).
  private var flags: FeatureFlags {
    #if DEBUG
    DebugFlagOverrides.shared.apply(to: baseFlags)
    #else
    baseFlags
    #endif
  }

  @Environment(\.horizontalSizeClass) private var sizeClass
  /// Regular layout state. While compact, `stackPath` is the live state and this is rebuilt when widening.
  @State private var navigation: ShellNavigation
  /// Compact layout state. Rebuilt from `navigation` when narrowing.
  @State private var stackPath: [TrainerRoute] = []
  @State private var columnVisibility: NavigationSplitViewVisibility = .all
  @State private var comingSoonEntry: EntryPoint?
  /// TR-14 registration and the consent step after it (DF-108).
  @State private var sheet: ShellSheet?
  /// TR-02 (DF-013). Kept in state so the subscription survives layout changes.
  @State private var memberList: MemberListViewModel
  /// TR-15 (DF-018). Kept in state so the Outbox subscriptions survive layout changes.
  @State private var settings: SettingsViewModel
  private let registrar: any PendingMemberRegistrar
  private let consentDocuments: any ConsentDocumentCatalog
  private let consentRecorder: any ConsentCaptureRecorder
  private let effectiveConsent: any EffectiveConsentSource

  init(flags: FeatureFlags, services: ShellServices) {
    baseFlags = flags
    registrar = services.registrar
    consentDocuments = services.consentDocuments
    consentRecorder = services.consentRecorder
    effectiveConsent = services.effectiveConsent
    _settings = State(initialValue: SettingsViewModel(
      queue: services.syncQueue, signOut: services.signOut, accountName: services.accountName,
      version: Self.appVersion))
    _navigation = State(initialValue: ShellNavigation(selection: TrainerRoute.initial(flags: flags)))
    _memberList = State(initialValue: MemberListViewModel(directory: services.memberDirectory))
  }

  private var isCompact: Bool { sizeClass == .compact }

  var body: some View {
    Group {
      if isCompact {
        stack
      } else {
        split
      }
    }
    .onChange(of: isCompact) { _, nowCompact in
      if nowCompact {
        stackPath = navigation.stackPath
      } else {
        navigation = navigation.restoring(stackPath: stackPath)
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
    .sheet(item: $sheet) { presented in
      switch presented {
      case .registration:
        PendingMemberRegistrationView(
          model: PendingMemberRegistrationModel(registrar: registrar),
          onRegistered: { member in sheet = .consent(member: member) },
          onCancel: { sheet = nil })
      case let .consent(member):
        // TR-14 consent step (DF-110). Not swipe-dismissable (V1-07 §3.2); `tr14.consent.root` carries the member ID.
        ConsentStepView(
          model: ConsentStepModel(member: member, documents: consentDocuments, recorder: consentRecorder,
                                  consent: effectiveConsent),
          onClose: { sheet = nil })
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
      List(selection: sidebarSelection) {
        ForEach(sidebarEntries) { entry in
          if case let .route(route) = entry.destination {
            NavigationLink(value: route) { sidebarLabel(entry) }
              .accessibilityIdentifier(entry.accessibilityID)
          }
        }
      }
      .navigationTitle(String(localized: "app.title"))
    } content: {
      content(for: navigation.selection ?? .members)
    } detail: {
      DetailColumn {
        if case let .memberDetail(uid) = navigation.detail {
          memberDetail(uid: uid)
        } else {
          Color.clear.accessibilityIdentifier("app.detail.empty")
        }
      }
    }
  }

  /// Sidebar taps go through `ShellNavigation.select(_:)`, which closes the detail when the route changes.
  private var sidebarSelection: Binding<TrainerRoute?> {
    Binding(get: { navigation.selection }, set: { navigation.select($0) })
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

  /// Content column. TR-01 and TR-15 arrive with DF-125 and DF-018.
  @ViewBuilder
  private func content(for route: TrainerRoute) -> some View {
    switch route {
    case .today:
      ComingSoonView().container("tr01.root")
    case .settings:
      SettingsView(model: settings, baseFlags: baseFlags).container("tr15.root")
    case .members, .memberDetail:
      // SwiftUI folds single-child wrappers onto the List's collection view, where the outermost identifier wins.
      // The hidden spacer makes this a real container, so `tr02.root` and FeatureMembers' `tr02.list` both exist.
      VStack(spacing: 0) {
        Color.clear.frame(height: 0).accessibilityHidden(true)
        memberListView
      }
      .container("tr02.root")
    }
  }

  /// `CFBundleShortVersionString (CFBundleVersion)` for TR-15 (AC-DF-018.5).
  static var appVersion: String {
    let info = Bundle.main.infoDictionary
    let short = info?["CFBundleShortVersionString"] as? String ?? "?"
    let build = info?["CFBundleVersion"] as? String ?? "?"
    return "\(short) (\(build))"
  }

  /// TR-02. Regular width selects the detail column; compact width pushes TR-03 onto the stack.
  private var memberListView: some View {
    MemberListView(model: memberList, selectedID: selectedMemberID) { member in
      let route = TrainerRoute.memberDetail(uid: member.id)
      if isCompact {
        stackPath.append(route)
      } else {
        navigation.detail = route
      }
    }
    .navigationTitle(String(localized: "tr02.title"))
    .toolbar {
      // TR-14 entry (DF-108). DF-113 adds the pending rows and the empty-state button.
      ToolbarItem(placement: .primaryAction) {
        Button { sheet = .registration } label: {
          Label(String(localized: "tr02.addPending"), systemImage: "person.badge.plus")
        }
        .accessibilityIdentifier("tr02.addPending")
      }
    }
  }

  private var selectedMemberID: String? {
    if case let .memberDetail(uid) = navigation.detail { return uid }
    return nil
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
