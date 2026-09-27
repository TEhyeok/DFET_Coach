import TrainerDomain

/// What the shell's screens use, for one signed-in trainer (live) or a preview scenario.
struct ShellServices {
  /// TR-02 (DF-013): assigned and pending members from the server.
  let memberDirectory: any MemberDirectory
  /// TR-02 (DF-113): pending members registered on this device that the server has not acked yet.
  let localPendingMembers: any LocalPendingMemberSource
  /// TR-02 consent chips (DF-113): each member's effective consent. DF-111's `EffectiveConsentResolver` provides it;
  /// until it is wired the live app uses `UnresolvedConsentSource`.
  let consentStatus: any EffectiveConsentSource
  /// TR-14 registration (DF-108).
  let registrar: any PendingMemberRegistrar
  /// TR-14 consent step (DF-110): the published consent document versions.
  let consentDocuments: any ConsentDocumentCatalog
  /// TR-14 consent step (DF-110): saves an in-person capture and queues its `recordConsent` call.
  let consentRecorder: any ConsentCaptureRecorder
  /// Every consent chip and guard (DF-111): the member's effective consent (server state + local captures).
  let effectiveConsent: any EffectiveConsentSource
  /// TR-15 upload queue (DF-018): the session's SyncEngine.
  let syncQueue: any SyncQueueService
  /// TR-15 logout (DF-018).
  let signOut: any SessionSignOut
  /// TR-15 계정 row.
  let accountName: String?
}

/// Sheets the shell presents over the current screen (V1-07 §3.2: TR-14 is a sheet, not a column route).
enum ShellSheet: Identifiable, Equatable {
  /// TR-14 registration (DF-108).
  case registration
  /// The consent step of a just-registered member (AC-DF-108.4, DF-110).
  case consent(member: MemberKey)

  var id: String {
    switch self {
    case .registration: return "registration"
    case let .consent(member): return "consent:\(member.id)"
    }
  }
}

/// Consent that is not known yet: the stream stays silent, so TR-02 shows no chip rather than a wrong one. The live
/// app uses it until DF-111's `EffectiveConsentResolver` (fed by DF-110's `memberConsentStates` listener) is wired.
struct UnresolvedConsentSource: EffectiveConsentSource {
  func observe(member: MemberKey) -> AsyncStream<EffectiveConsent> {
    AsyncStream { _ in }
  }
}
