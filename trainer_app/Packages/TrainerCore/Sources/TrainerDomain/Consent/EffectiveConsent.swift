import Foundation
import TrainerContracts

/// The consent a screen guard acts on for one type (DF-111): the server state combined with this device's in-person
/// captures that the server has not confirmed yet.
public enum EffectiveConsentValue: String, Equatable, Sendable {
  /// Confirmed by the server (`memberConsentStates`).
  case granted
  /// Granted in a local in-person capture the server has not confirmed yet (F-PRIV-03.7).
  case awaitingConsent
  /// Not granted: no document, `granted == false`, or withdrawn.
  case missing
  /// The local capture was refused by the server (`recordConsent` failed). Shown as '동의 필요' in the MVP.
  case rejected
}

/// Whether TR-11/TR-12 may save a health record (AC-DF-127.4, V1-07 §3.7).
public enum HealthRecordSaveGate: Equatable, Sendable {
  /// ② confirmed by the server.
  case allowed
  /// ② only in a local capture: saved on the device; the SyncEngine holds it until consent is confirmed (DF-015).
  case localOnly
  /// No ②: the save button is disabled with `tr11.consentNeeded`.
  case blocked
}

/// The TR-02 row and TR-03 header consent chip (DF-113 MVP: three states).
public enum ConsentChipState: Equatable, Sendable {
  /// ①②③ all confirmed: '동의 ①②③'.
  case coreGranted
  /// Something of ①②③ is missing or was rejected: '동의 필요'.
  case needed
  /// Everything of ①②③ that is not confirmed is waiting for the server: '동의 확인 대기'.
  case awaiting

  public var copyKey: String {
    switch self {
    case .coreGranted: return "tr02.consent.ok"
    case .needed: return "tr02.consent.needed"
    case .awaiting: return "consent.state.awaiting"
    }
  }
}

/// V1-07 §3.7 gate result for a set of required types.
public enum ConsentGateResult: Equatable, Sendable {
  case allowed
  /// Allowed only locally: every required type is granted or waiting for the server, and waiting is allowed.
  case awaitingConsent
  /// The required types that block, in ①~⑤ order.
  case missing([ConsentType])
}

/// Effective consent of one member (DF-111 MVP slice). Every guard reads this value only, never
/// `memberConsentStates` directly (AC-DF-111.7). The MVP resolves ①②③; ④⑤ are always `.missing`.
public struct EffectiveConsent: Equatable, Sendable {
  public let required: EffectiveConsentValue
  public let healthData: EffectiveConsentValue
  public let bodyImaging: EffectiveConsentValue

  public init(required: EffectiveConsentValue, healthData: EffectiveConsentValue, bodyImaging: EffectiveConsentValue) {
    self.required = required
    self.healthData = healthData
    self.bodyImaging = bodyImaging
  }

  /// Server state only: a granted type is `.granted`, anything else `.missing`. The SyncEngine resolver (DF-111)
  /// overlays unconfirmed local captures as `.awaitingConsent` or `.rejected`.
  public init(server: ConsentState?) {
    func value(_ type: ConsentType) -> EffectiveConsentValue { server?.isGranted(type) == true ? .granted : .missing }
    self.init(required: value(.required), healthData: value(.healthData), bodyImaging: value(.bodyImaging))
  }

  /// Nothing granted.
  public static let none = EffectiveConsent(required: .missing, healthData: .missing, bodyImaging: .missing)

  public subscript(type: ConsentType) -> EffectiveConsentValue {
    switch type {
    case .required: return required
    case .healthData: return healthData
    case .bodyImaging: return bodyImaging
    case .sharing, .research: return .missing
    }
  }

  private var core: [EffectiveConsentValue] { [required, healthData, bodyImaging] }

  /// ①②③ all confirmed by the server.
  public var coreGranted: Bool { core.allSatisfy { $0 == .granted } }

  /// Report photo attachment (AC-DF-111.2, AC-DF-128.4): ② confirmed by the server, never on a local capture.
  public var canAttachPhoto: Bool { healthData == .granted }

  /// Posture capture (DF-204): ② and ③ confirmed by the server.
  public var canCapturePosture: Bool { healthData == .granted && bodyImaging == .granted }

  /// Body composition and tape saves (AC-DF-127.4, AC-DF-129.10).
  public var healthRecordSave: HealthRecordSaveGate {
    switch healthData {
    case .granted: return .allowed
    case .awaitingConsent: return .localOnly
    case .missing, .rejected: return .blocked
    }
  }

  public var canSaveHealthRecord: Bool { healthRecordSave != .blocked }

  public var chipState: ConsentChipState {
    if coreGranted { return .coreGranted }
    return core.allSatisfy { $0 == .granted || $0 == .awaitingConsent } ? .awaiting : .needed
  }

  /// V1-07 §3.7: `.allowed` when every required type is confirmed; `.awaitingConsent` when the rest only waits for
  /// the server and `allowAwaiting`; otherwise the blocking types.
  public func gate(requires: Set<ConsentType>, allowAwaiting: Bool) -> ConsentGateResult {
    let ordered = ConsentType.allCases.filter(requires.contains)
    let blocking = ordered.filter { self[$0] != .granted && !(allowAwaiting && self[$0] == .awaitingConsent) }
    if !blocking.isEmpty { return .missing(blocking) }
    return ordered.contains { self[$0] == .awaitingConsent } ? .awaitingConsent : .allowed
  }
}

/// What screens read (DF-111 MVP): the member's effective consent, now and after every change. The SyncEngine's
/// `EffectiveConsentResolver` implements it from `ConsentStateSource` and the local consent captures.
public protocol EffectiveConsentSource: Sendable {
  func observe(member: MemberKey) -> AsyncStream<EffectiveConsent>
}
