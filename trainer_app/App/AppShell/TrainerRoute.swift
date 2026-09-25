import TrainerDomain

/// Routes the AppShell can show (PRD §8.1, V1-07 §3.2). Runner's schedule, program and alerts routes are not
/// ported (AS-21, dfet:ios/Runner/AppDelegate.swift:7876-7885).
///
/// Not yet routes: the session flow TR-04 -> TR-05 -> TR-06 (fullScreenCover) and the sheets TR-11/12/14 arrive
/// with their screens in P1a. Until then their entry points open `common.comingSoon` (see `EntryPoint`).
enum TrainerRoute: Hashable, CaseIterable {
  /// TR-01
  case today
  /// TR-02
  case members
  /// TR-03
  case memberDetail(uid: String)
  /// TR-15
  case settings

  /// One value per case. `memberDetail` carries an empty uid: `allCases` enumerates cases, not members.
  static var allCases: [TrainerRoute] {
    [.today, .members, .memberDetail(uid: ""), .settings]
  }

  /// Case name without associated values (for the AS-21 check and logs; never contains a uid).
  var caseName: String {
    switch self {
    case .today: return "today"
    case .members: return "members"
    case .memberDetail: return "memberDetail"
    case .settings: return "settings"
    }
  }

  /// PRD screen ID.
  var trID: String {
    switch self {
    case .today: return "TR-01"
    case .members: return "TR-02"
    case .memberDetail: return "TR-03"
    case .settings: return "TR-15"
    }
  }

  /// First sidebar selection after launch. V1-07 §4.0: `.today`, or `.members` while `soapV2` is off
  /// (the session board has nothing to start without SOAP v2).
  static func initial(flags: FeatureFlags) -> TrainerRoute {
    flags.soapV2 ? .today : .members
  }
}
