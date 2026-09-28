import FeatureBodyComposition
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
///
/// The flags follow the provider while the shell is shown (live: `appConfig/features`), so an entry point appears or
/// goes away without a relaunch.
struct RootSplitView: View {
  private let flagsProvider: any FeatureFlagsProvider
  /// The provider's latest flags.
  @State private var baseFlags: FeatureFlags
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
  /// TR-03 body composition and TR-11 (DF-127, DF-130).
  private let bodyComposition: BodyCompositionServices

  init(flags provider: any FeatureFlagsProvider, services: ShellServices) {
    let flags = provider.current
    flagsProvider = provider
    _baseFlags = State(initialValue: flags)
    registrar = services.registrar
    bodyComposition = services.bodyComposition
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
        NavigationStack {
          ComingSoonView()
            .toolbar {
              ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "common.close")) { sheet = nil }
                  .accessibilityIdentifier("common.close")
              }
            }
        }
        .interactiveDismissDisabled()  // V1-07 §3.2: `.consent` is `sheet(.large, interactiveDismissDisabled)`
        // The member key is a random pending ID, not personal data; UI tests read it (AC-DF-108.4).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tr14.consent.root")
        .accessibilityValue(member.id)
      }
    }
    .task {
      for await flags in flagsProvider.updates() { baseFlags = flags }
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
    MemberDetailShell(member: .uid(uid), flags: flags, bodyComposition: bodyComposition) { entry in
      if entry.destination == .comingSoon {
        comingSoonEntry = entry
      }
    }
    .id(uid)  // another member gets a fresh body composition subscription
    .container("tr03.root")
  }
}

/// TR-03 until DF-113/DF-114 build the screen: the flag-gated actions — the '측정 입력' menu (AC-DF-127.11) and the
/// other entry points — and, with `bodyComposition`, the member's body composition (latest values, mini trend). TR-11
/// opens as a sheet over it (V1-07 §3.2). The entries follow the flags as they change; the body composition model is
/// made when the flag is first on and kept (an open TR-11 sheet is not torn down), its section shown only while on.
private struct MemberDetailShell: View {
  private let member: MemberKey
  private let flags: FeatureFlags
  private let services: BodyCompositionServices
  private let open: (EntryPoint) -> Void
  /// nil until `bodyComposition` is on: no section, no subscription.
  @State private var bodyComposition: BodyCompositionMemberModel?
  @State private var showsBodyCompositionEntry = false
  @Environment(\.layoutMode) private var layoutMode

  init(member: MemberKey, flags: FeatureFlags, bodyComposition services: BodyCompositionServices,
       open: @escaping (EntryPoint) -> Void) {
    self.member = member
    self.flags = flags
    self.services = services
    self.open = open
    _bodyComposition = State(initialValue: flags.bodyComposition
      ? BodyCompositionMemberModel(member: member, services: services) : nil)
  }

  private var entries: [EntryPoint] { FlagGate.visibleEntries(on: .memberDetail, flags: flags) }
  private var measureEntries: [EntryPoint] { FlagGate.visibleEntries(on: .measureMenu, flags: flags) }

  var body: some View {
    let layout = layoutMode == .regular
      ? AnyLayout(HStackLayout(spacing: 12))
      : AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        layout {
          if !measureEntries.isEmpty {
            measureMenu
          }
          ForEach(entries) { entry in
            Button(Self.title(entry)) { select(entry) }
              .buttonStyle(.bordered)
              .accessibilityIdentifier(entry.accessibilityID)
          }
        }
        if flags.bodyComposition, let bodyComposition {
          BodyCompositionSection(model: bodyComposition)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(24)
    }
    .onChange(of: flags.bodyComposition) { _, isOn in
      if isOn, bodyComposition == nil {
        bodyComposition = BodyCompositionMemberModel(member: member, services: services)
      }
    }
    .sheet(isPresented: $showsBodyCompositionEntry) {
      if let bodyComposition {
        BodyCompositionSheet(memberModel: bodyComposition) { showsBodyCompositionEntry = false }
      }
    }
  }

  /// '측정 입력': one item per visible measurement screen; no item, no menu (AC-DF-127.11).
  private var measureMenu: some View {
    Menu {
      ForEach(measureEntries) { entry in
        Button(Self.title(entry)) { select(entry) }
          .accessibilityIdentifier(entry.accessibilityID)
      }
    } label: {
      Label(String(localized: "tr03.measureMenu"), systemImage: "plus.circle")
    }
    .menuStyle(.button)
    .buttonStyle(.bordered)
    .accessibilityIdentifier("tr03.measureMenu")
  }

  private func select(_ entry: EntryPoint) {
    if entry.destination == .bodyCompositionEntry {
      showsBodyCompositionEntry = true
    } else {
      open(entry)
    }
  }

  /// The key is a `String` value, so `LocalizationValue` looks it up as it is (SE-0213).
  private static func title(_ entry: EntryPoint) -> String {
    String(localized: String.LocalizationValue(entry.titleKey))
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
