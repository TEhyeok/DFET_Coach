import SwiftData

/// LocalStore schema v1.2 (DF-127): adds `DeviceModelEntry`, the TR-11 device picker list (ASM-P1a-14). A new entity
/// only, so the migration from V1_1 is lightweight. Entities that did not change are the V1 and V1_1 classes; V1_1
/// stays frozen as DF-108 left it.
public enum LocalStoreSchemaV1_2: VersionedSchema {
  public static let versionIdentifier = Schema.Version(1, 2, 0)

  public static var models: [any PersistentModel.Type] {
    [
      LocalStoreSchemaV1.LocalSoapDraft.self,
      LocalStoreSchemaV1.LocalMeasurementDraft.self,
      LocalStoreSchemaV1.LocalConsentCapture.self,
      LocalStoreSchemaV1_1.OutboxItem.self,
      LocalStoreSchemaV1.LocalBinary.self,
      LocalStoreSchemaV1.TodayListEntry.self,
      LocalStoreSchemaV1.StationProfile.self,
      LocalStoreSchemaV1.QuickPhrase.self,
      LocalStoreSchemaV1.FilterPreference.self,
      LocalStoreSchemaV1_1.LocalPendingMemberDraft.self,
      DeviceModelEntry.self,
    ]
  }
}
