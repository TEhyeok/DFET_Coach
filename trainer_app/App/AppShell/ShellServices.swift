import TrainerDomain

/// What the shell's screens use, for one signed-in trainer (live) or a preview scenario.
struct ShellServices {
  /// TR-02 (DF-013).
  let memberDirectory: any MemberDirectory
  /// TR-14 registration (DF-108).
  let registrar: any PendingMemberRegistrar
}

/// Sheets the shell presents over the current screen (V1-07 §3.2: TR-14 is a sheet, not a column route).
enum ShellSheet: Identifiable, Equatable {
  /// TR-14 registration (DF-108).
  case registration
  /// The consent step of a just-registered member (AC-DF-108.4). DF-110 builds the screen; until then a placeholder.
  case consent(member: MemberKey)

  var id: String {
    switch self {
    case .registration: return "registration"
    case let .consent(member): return "consent:\(member.id)"
    }
  }
}
