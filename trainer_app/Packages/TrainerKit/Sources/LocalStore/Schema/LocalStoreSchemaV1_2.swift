import SwiftData

/// LocalStore schema v1.2 (DF-110): `LocalConsentCapture.signatureBinaryId` becomes optional, because the MVP records
/// in-person consent without a signature (DF-109/DF-110 MVP). Making an attribute optional is a lightweight migration.
/// Entities that did not change are the V1 and V1_1 classes.
public enum LocalStoreSchemaV1_2: VersionedSchema {
  public static let versionIdentifier = Schema.Version(1, 2, 0)

  public static var models: [any PersistentModel.Type] {
    [
      LocalStoreSchemaV1.LocalSoapDraft.self,
      LocalStoreSchemaV1.LocalMeasurementDraft.self,
      LocalConsentCapture.self,
      LocalStoreSchemaV1_1.OutboxItem.self,
      LocalStoreSchemaV1.LocalBinary.self,
      LocalStoreSchemaV1.TodayListEntry.self,
      LocalStoreSchemaV1.StationProfile.self,
      LocalStoreSchemaV1.QuickPhrase.self,
      LocalStoreSchemaV1.FilterPreference.self,
      LocalStoreSchemaV1_1.LocalPendingMemberDraft.self,
    ]
  }
}
