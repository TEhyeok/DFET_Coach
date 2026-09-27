import Foundation
import TrainerContracts
import TrainerDomain

/// TC-111-06: one conservative calculation for every consent chip and screen guard. Callers combine their
/// server/local streams and pass snapshots here; this module does not know how SwiftData or Firebase are stored.
public enum EffectiveConsentResolver {
  public static func resolve(server: ConsentState?, captures: [ConsentCaptureSnapshot]) -> EffectiveConsent {
    func value(_ type: ConsentType) -> EffectiveConsentValue {
      if server?.isGranted(type) == true { return .granted }
      // Captures only grant in the MVP. A refused card does not revoke a prior grant or create a server record.
      let latest = captures.filter { $0.selections.contains { $0.type == type && $0.granted } }
        .max { ($0.capturedAt, $0.id.uuidString) < ($1.capturedAt, $1.id.uuidString) }
      guard let latest else { return .missing }
      return latest.state == .pending ? .awaitingConsent : .rejected
    }
    return EffectiveConsent(required: value(.required), healthData: value(.healthData), bodyImaging: value(.bodyImaging))
  }
}
