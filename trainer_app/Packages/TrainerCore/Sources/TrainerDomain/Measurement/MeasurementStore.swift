import Foundation
import TrainerContracts

/// Why a measurement could not be saved.
public enum MeasurementStoreError: Error, Equatable, Sendable {
  /// The draft has validation errors (the form should not have allowed saving).
  case invalidDraft([BodyCompositionIssue])
  /// The member has no usable consent of this type (`EffectiveConsent.healthRecordSave == .blocked`, AC-DF-127.4).
  case consentRequired(ConsentType)
}

/// TR-11 body composition storage (the spine's `MeasurementStore`, body composition part; DF-127, DF-130).
/// The implementation saves on the device first and queues the server create in the Outbox, so a save works offline
/// and while consent ② only waits for the server (the SyncEngine holds the item, DF-015). DF-128 adds
/// `attachReportPhoto` and `voidAndPrefill`, DF-129 the tape methods.
public protocol MeasurementStore: Sendable {
  /// Validates the draft (`BodyCompositionValidator`, with the implementation's clock), stores it locally with a new
  /// document ID and enqueues `createDocument` at `BodyCompositionPayload.path(id:)` with
  /// `BodyCompositionPayload.fields(_:member:trainerUid:)`. Returns the record ID.
  ///
  /// Throws `MeasurementStoreError.invalidDraft` for a draft with errors and `.consentRequired(.healthData)` when ②
  /// is neither granted nor awaiting confirmation; otherwise the local store's error.
  func saveBodyComposition(member: MemberKey, draft: BodyCompositionDraft) async throws -> String

  /// The member's records measured at or after `since`, local unsynced ones included, now and after every change.
  /// Voided records are included (TR-03 lists them); trends and defaults use `BodyCompositionSeries`, which skips them.
  func observeBodyCompositionRecords(member: MemberKey, since: Date) -> AsyncThrowingStream<[BodyCompositionRecord], Error>

  /// One metric's trend points since `since` (the mini trend: 12 months, AC-DF-130.11), sorted by `measuredAt`.
  /// For body composition metrics this is `BodyCompositionSeries.points(from:metricCode:)` over
  /// `observeBodyCompositionRecords`. Charts pass the result to `SeriesChartInput.make`.
  func observeSeries(member: MemberKey, metricCode: MetricCode, since: Date) -> AsyncThrowingStream<[SeriesPoint], Error>
}
