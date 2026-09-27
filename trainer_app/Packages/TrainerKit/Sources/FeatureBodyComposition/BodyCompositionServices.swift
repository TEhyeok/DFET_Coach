import TrainerDomain

/// What TR-11 and the TR-03 body composition section use (DF-127, DF-130). The app composes it: LocalStore's
/// `LocalMeasurementStore` for the store and the device list, and the member's effective consent (DF-111 MVP).
/// Screens read consent only through `consent` (AC-DF-111.7), never `memberConsentStates` directly.
public struct BodyCompositionServices: Sendable {
  public let store: any MeasurementStore
  public let devices: any DeviceModelCatalog
  public let consent: any EffectiveConsentSource

  public init(store: any MeasurementStore, devices: any DeviceModelCatalog, consent: any EffectiveConsentSource) {
    self.store = store
    self.devices = devices
    self.consent = consent
  }
}
