import SwiftData

/// LocalStore schema v1 (DF-014, V1-05 §12.1-§12.2, ADR-002).
///
/// Holds the entities whose 'schema' column in V1-05 §12.2 is V1. Every entity carries `trainerUid` and every
/// query adds `trainerUid == session uid` (AC-DF-014.1). Later stories add `LocalStoreSchemaV1_1`, `V1_2`… and a
/// matching `LocalStoreMigrationPlan` stage in the same PR (`LocalPendingMemberDraft` → V1_1 in DF-108,
/// `LocalAssessmentDraft` → DF-203). New attributes must be optional or have a default (lightweight migration).
///
/// The `@Model` classes are nested here so a later version can redeclare them; the module-level typealiases below
/// always point at the current version. All `@Model` classes are `internal` (V1-05 §12.1 access level).
public enum LocalStoreSchemaV1: VersionedSchema {
  public static let versionIdentifier = Schema.Version(1, 0, 0)

  public static var models: [any PersistentModel.Type] {
    [
      LocalSoapDraft.self,
      LocalMeasurementDraft.self,
      LocalConsentCapture.self,
      OutboxItem.self,
      LocalBinary.self,
      TodayListEntry.self,
      StationProfile.self,
      QuickPhrase.self,
      FilterPreference.self,
    ]
  }
}

/// Migration plan (V1-04 §9.3). V1 is the first version, so there are no stages yet.
public enum LocalStoreMigrationPlan: SchemaMigrationPlan {
  public static var schemas: [any VersionedSchema.Type] { [LocalStoreSchemaV1.self] }
  public static var stages: [MigrationStage] { [] }
}

// Current-version names used by the rest of the module (V1-05 §12.1: inside LocalStore `OutboxItem` is the @Model).
typealias LocalSoapDraft = LocalStoreSchemaV1.LocalSoapDraft
typealias LocalMeasurementDraft = LocalStoreSchemaV1.LocalMeasurementDraft
typealias LocalConsentCapture = LocalStoreSchemaV1.LocalConsentCapture
typealias OutboxItem = LocalStoreSchemaV1.OutboxItem
typealias LocalBinary = LocalStoreSchemaV1.LocalBinary
typealias TodayListEntry = LocalStoreSchemaV1.TodayListEntry
typealias StationProfile = LocalStoreSchemaV1.StationProfile
typealias QuickPhrase = LocalStoreSchemaV1.QuickPhrase
typealias FilterPreference = LocalStoreSchemaV1.FilterPreference
