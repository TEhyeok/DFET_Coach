import SwiftData

/// LocalStore schema v1.1 (DF-108): adds `LocalPendingMemberDraft` and `OutboxItem.ackConfirmed`. Both changes are
/// additive (a new entity, an optional attribute), so the migration from V1 is lightweight. Entities that did not
/// change are the V1 classes.
public enum LocalStoreSchemaV1_1: VersionedSchema {
  public static let versionIdentifier = Schema.Version(1, 1, 0)

  public static var models: [any PersistentModel.Type] {
    [
      LocalStoreSchemaV1.LocalSoapDraft.self,
      LocalStoreSchemaV1.LocalMeasurementDraft.self,
      LocalStoreSchemaV1.LocalConsentCapture.self,
      OutboxItem.self,
      LocalStoreSchemaV1.LocalBinary.self,
      LocalStoreSchemaV1.TodayListEntry.self,
      LocalStoreSchemaV1.StationProfile.self,
      LocalStoreSchemaV1.QuickPhrase.self,
      LocalStoreSchemaV1.FilterPreference.self,
      LocalPendingMemberDraft.self,
    ]
  }
}
