import TrainerDomain

/// What the shell's screens use, for one signed-in trainer (live) or a preview scenario.
struct ShellServices {
  /// TR-02 (DF-013).
  let memberDirectory: any MemberDirectory
  /// TR-14 registration (DF-108).
  let registrar: any PendingMemberRegistrar
  /// TR-15 upload queue (DF-018): the session's SyncEngine.
  let syncQueue: any SyncQueueService
  /// TR-15 logout (DF-018).
  let signOut: any SessionSignOut
  /// TR-15 계정 row.
  let accountName: String?
  let consent: (any ConsentService)?
  let measurements: (any MeasurementStore)?

  init(memberDirectory: any MemberDirectory, registrar: any PendingMemberRegistrar, syncQueue: any SyncQueueService,
       signOut: any SessionSignOut, accountName: String?, consent: (any ConsentService)? = nil,
       measurements: (any MeasurementStore)? = nil) {
    self.memberDirectory = memberDirectory
    self.registrar = registrar
    self.syncQueue = syncQueue
    self.signOut = signOut
    self.accountName = accountName
    self.consent = consent
    self.measurements = measurements
  }
}

/// Sheets the shell presents over the current screen (V1-07 §3.2: TR-14 is a sheet, not a column route).
enum ShellSheet: Identifiable, Equatable {
  /// TR-14 registration (DF-108).
  case registration
  /// The consent step of a just-registered member (AC-DF-108.4). DF-110 builds the screen; until then a placeholder.
  case consent(member: MemberKey)
  case bodyComposition(member: MemberKey)

  var id: String {
    switch self {
    case .registration: return "registration"
    case let .consent(member): return "consent:\(member.id)"
    case let .bodyComposition(member): return "bodyComposition:\(member.id)"
    }
  }
}
