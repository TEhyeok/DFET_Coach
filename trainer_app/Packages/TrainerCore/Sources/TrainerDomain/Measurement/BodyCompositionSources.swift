import Foundation

/// The member's `bodyCompositionRecords` as the server has them (FirebaseData; the DF-130 mini trend query,
/// `trainerId == uid && <member key> == m && measuredAt >= since`). `MeasurementStore` implementations merge it with
/// this device's records the server does not have yet (`BodyCompositionRecordMerge`).
public protocol BodyCompositionRecordSource: Sendable {
  /// Records measured at or after `since`, voided ones included, now and after every change. Fails when the server
  /// refuses the read; an offline device answers from its cache.
  func observeRecords(member: MemberKey, since: Date) -> AsyncThrowingStream<[BodyCompositionRecord], Error>

  /// The member's latest active record at any date (newest first, voided ones skipped), or nil when there is none. One
  /// answer; an offline device answers from its cache.
  func latestActiveRecord(member: MemberKey) async throws -> BodyCompositionRecord?
}

/// The device models this iPad has entered body composition with (TR-11 device picker, ASM-P1a-14): a device-local
/// list, not synced and not per member. Saving a record marks its device as used.
public protocol DeviceModelCatalog: Sendable {
  /// Stored names (`DeviceModelName.normalize`), most recently used first.
  func recentDeviceModels() async throws -> [String]
  /// Adds `name`, or marks it used when it is already there, and returns it normalized. Throws
  /// `DeviceModelCatalogError.invalidName` for a name that is blank or longer than `DeviceModelName.limit`.
  func addDeviceModel(_ name: String) async throws -> String
}

public enum DeviceModelCatalogError: Error, Equatable, Sendable {
  case invalidName
}

extension DeviceModelName {
  /// The normalized name when it can be stored (1~64 UTF-16 units, the rules' `strRange(deviceModel, 1, 64)`).
  public static func storable(_ text: String) -> String? {
    let name = normalize(text)
    return limit.contains(name.utf16.count) ? name : nil
  }
}

/// Server records and this device's unsynced records as one list (DF-130 mini trend, TR-03).
public enum BodyCompositionRecordMerge {
  /// One record per id. The server's copy wins: it carries `createdAt` and any later change of state (voided,
  /// DF-128). A local record's `syncState` stays on it, though: while this device still waits for the write, the
  /// copy the listener has may be Firestore's own pending write, and it must not look synced. Sorted by
  /// (`measuredAt`, id).
  public static func merge(server: [BodyCompositionRecord], local: [BodyCompositionRecord]) -> [BodyCompositionRecord] {
    var byId: [String: BodyCompositionRecord] = [:]
    for record in local { byId[record.id] = record }
    for var record in server {
      record.syncState = byId[record.id]?.syncState
      byId[record.id] = record
    }
    return byId.values.sorted { ($0.measuredAt, $0.id) < ($1.measuredAt, $1.id) }
  }
}
