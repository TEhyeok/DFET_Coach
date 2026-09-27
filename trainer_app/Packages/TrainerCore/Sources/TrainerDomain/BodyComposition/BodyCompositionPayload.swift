import Foundation
import TrainerContracts

/// The `bodyCompositionRecords/{id}` create payload (V1-05 §4.7, DF-127 'server create fields'). Only the keys the
/// rules' `bcKeys()` allow. The writer adds `createdAt` and `updatedAt` as server time
/// (`FirestoreRemoteWriter.createIfAbsent`), so they are not here, as with `PendingMemberPayload`.
public enum BodyCompositionPayload {
  public static let collection = "bodyCompositionRecords"
  /// `LocalEntityRef` kind of a body composition record (`bodyComposition:<recordId>`, V1-05 §12.2).
  public static let entityKind = "bodyComposition"
  /// Keys of the stored document, the server timestamps included (the rules' `bcKeys()`).
  public static let documentKeys: Set<String> = [
    "memberUid", "pendingMemberId", "trainerId", "enteredBy", "source", "sourceGrade", "deviceModel", "measuredAt",
    "fasting", "timeOfDayBand", "values", "derived", "reportPhotoPath", "status", "legalNature", "schemaVersion",
    "createdAt", "updatedAt",
  ]
  /// Added by the writer, never by this payload.
  public static let serverTimestampKeys: Set<String> = ["createdAt", "updatedAt"]

  public static func path(id: String) -> String {
    "\(collection)/\(id)"
  }

  public static func entityRef(recordId: String) -> LocalEntityRef {
    .measurement(kind: entityKind, recordId: recordId)
  }

  /// The create fields for a validated entry.
  ///
  /// - The member key is exactly one string, the other key null (the rules' `exactlyOneMemberKey`).
  /// - `trainerId` and `enteredBy` are the signed-in trainer (`rawRecordCreateBase`, `enteredBy == request.auth.uid`).
  /// - `values` holds only the measured keys; `derived` is absent without a trainer-entered height (AC-DF-127.5).
  /// - `reportPhotoPath` is null at create; DF-128 sets it once after the upload.
  public static func fields(_ entry: BodyCompositionEntry, member: MemberKey, trainerUid: String) -> JSONValue {
    var fields: [String: JSONValue] = [
      "trainerId": .string(trainerUid),
      "enteredBy": .string(trainerUid),
      "source": .string(BodyCompositionSource.manualEntry.rawValue),
      "sourceGrade": .string(SourceGrade.device.rawValue),
      "deviceModel": .string(entry.deviceModel),
      "measuredAt": .timestamp(entry.measuredAt),
      "fasting": .string(entry.fasting.rawValue),
      "timeOfDayBand": .string(entry.timeOfDayBand.rawValue),
      "values": .object(Dictionary(uniqueKeysWithValues: entry.values.map { ($0.key.rawValue, JSONValue.number($0.value)) })),
      "reportPhotoPath": .null,
      "status": .string(MeasurementStatus.active.rawValue),
      "legalNature": .string("coachingRecord"),
      "schemaVersion": .int(1),
    ]
    switch member {
    case let .uid(uid):
      fields["memberUid"] = .string(uid)
      fields["pendingMemberId"] = .null
    case let .pending(id):
      fields["memberUid"] = .null
      fields["pendingMemberId"] = .string(id)
    }
    if let derived = entry.derived {
      fields["derived"] = .object([
        "bmi": .number(derived.bmi),
        "heightCmUsed": .number(derived.heightCmUsed),
        "heightMeasuredAt": .timestamp(derived.heightMeasuredAt),
        "sourceGrade": .string(SourceGrade.derived.rawValue),
      ])
    }
    return .object(fields)
  }

  /// Validates and builds in one step; nil when the draft has an error (warnings do not block).
  public static func fields(_ draft: BodyCompositionDraft, member: MemberKey, trainerUid: String, now: Date) -> JSONValue? {
    BodyCompositionValidator.validate(draft, now: now).entry.map { fields($0, member: member, trainerUid: trainerUid) }
  }
}
