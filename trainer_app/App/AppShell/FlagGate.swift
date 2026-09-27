import TrainerDomain

/// Every place the AppShell can offer to open a screen (V1-07 §3.2, §3.6). The shell asks `FlagGate` before it
/// builds a route or a button, so a flag that is off leaves no entry point at all (AC-IA-02, ADR-010).
enum EntryPoint: String, CaseIterable, Identifiable {
  enum Surface: Equatable {
    case sidebar
    case memberDetail
    /// TR-03's '측정 입력' menu (`tr03.measureMenu`, AC-DF-127.11). No visible item, no menu.
    case measureMenu
  }

  enum Destination: Equatable {
    case route(TrainerRoute)
    /// TR-11 as a sheet over TR-03 (DF-127, V1-07 §3.2).
    case bodyCompositionEntry
    /// The flag is on but the screen does not exist yet: show `common.comingSoon` (AC-DF-017.5).
    case comingSoon
  }

  // Sidebar
  case today           // TR-01
  case members         // TR-02
  case settings        // TR-15
  // TR-03 member detail actions
  case startSession    // TR-04 (soapV2)
  // TR-03 '측정 입력' menu
  case bodyComposition // TR-11 (bodyComposition)
  case circumference   // TR-12 (bodyComposition)
  // TR-03 member detail actions
  case postureCapture  // TR-07 -> TR-08 -> TR-09 (bodyAssessment)
  case compare         // TR-10 (bodyAssessment or bodyComposition, V1-07 §3.2)
  case share           // TR-06 (memberShare)
  case lidar           // TR-13 (lidarBeta)

  var id: String { rawValue }

  var surface: Surface {
    switch self {
    case .today, .members, .settings: return .sidebar
    case .bodyComposition, .circumference: return .measureMenu
    default: return .memberDetail
    }
  }

  var trID: String {
    switch self {
    case .today: return "TR-01"
    case .members: return "TR-02"
    case .settings: return "TR-15"
    case .startSession: return "TR-04"
    case .bodyComposition: return "TR-11"
    case .circumference: return "TR-12"
    case .postureCapture: return "TR-07"
    case .compare: return "TR-10"
    case .share: return "TR-06"
    case .lidar: return "TR-13"
    }
  }

  /// String catalog key of the label (V1-12 `data/copy_ko.json`; the sidebar uses the screens' titles).
  var titleKey: String {
    switch self {
    case .today: return "tr01.title"
    case .members: return "tr02.title"
    case .settings: return "tr15.title"
    case .startSession: return "tr03.startSession"
    case .bodyComposition: return "tr03.measureMenu.bodyComposition"
    case .circumference: return "tr03.measureMenu.circumference"
    case .postureCapture: return "tr07.title"
    case .compare: return "tr10.title"
    case .share: return "tr06.preview"
    case .lidar: return "tr13.title"
    }
  }

  var accessibilityID: String {
    switch surface {
    case .sidebar: return "nav.\(rawValue)"  // stable identifiers, independent of the copy keys
    case .memberDetail, .measureMenu: return "tr03.entry.\(rawValue)"
    }
  }

  var destination: Destination {
    switch self {
    case .today: return .route(.today)
    case .members: return .route(.members)
    case .settings: return .route(.settings)
    case .bodyComposition: return .bodyCompositionEntry  // DF-127
    default: return .comingSoon  // screens arrive in P1a/P1b/P2
    }
  }
}

/// Shell-wide scope constants (not flags). DEC-22 MVP: TR-01 '오늘' (DF-125 session board) is hidden; the sidebar is
/// 회원·설정 and the first screen is TR-02. DF-125 sets `showsToday` back to true (DF-017 MVP section).
enum ShellScope {
  static let showsToday = false
}

/// Pure visibility table for entry points (AC-DF-017.2, TC-DF017-02).
enum FlagGate {
  static func isEntryVisible(_ entry: EntryPoint, flags: FeatureFlags) -> Bool {
    switch entry {
    case .today: return ShellScope.showsToday
    case .members, .settings: return true
    case .startSession: return flags.soapV2
    case .bodyComposition, .circumference: return flags.bodyComposition
    case .postureCapture: return flags.bodyAssessment
    case .compare: return flags.bodyAssessment || flags.bodyComposition
    case .share: return flags.memberShare
    case .lidar: return flags.lidarBeta
    }
  }

  /// Visible entry points of one surface, in declaration order.
  static func visibleEntries(on surface: EntryPoint.Surface, flags: FeatureFlags) -> [EntryPoint] {
    EntryPoint.allCases.filter { $0.surface == surface && isEntryVisible($0, flags: flags) }
  }
}
