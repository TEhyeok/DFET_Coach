import Foundation
import TrainerContracts

/// A stored `bodyCompositionRecords/{id}` as TR-11 and the mini trend read it (V1-05 §4.7). Values that cannot be
/// read are nil (or left out of `values`) rather than guessed: a record without a readable `sourceGrade` never
/// becomes a chart point (C-01, AC-DF-130.1).
public struct BodyCompositionRecord: Equatable, Identifiable, Sendable {
  public let id: String
  public let member: MemberKey?
  public let deviceModel: String
  public let measuredAt: Date
  public let fasting: Fasting?
  public let timeOfDayBand: TimeOfDayBand?
  /// `manualEntry` for every client write; kept as text because it is a series identity key (V1-09 §8.3).
  public let source: String?
  public let sourceGrade: SourceGrade?
  public let values: [BodyCompositionKey: Double]
  public let derived: DerivedBMI?
  public let status: MeasurementStatus?
  public let reportPhotoPath: String?
  public let createdAt: Date?

  public init(
    id: String, member: MemberKey?, deviceModel: String, measuredAt: Date, fasting: Fasting?,
    timeOfDayBand: TimeOfDayBand?, source: String?, sourceGrade: SourceGrade?, values: [BodyCompositionKey: Double],
    derived: DerivedBMI?, status: MeasurementStatus?, reportPhotoPath: String? = nil, createdAt: Date? = nil
  ) {
    self.id = id
    self.member = member
    self.deviceModel = deviceModel
    self.measuredAt = measuredAt
    self.fasting = fasting
    self.timeOfDayBand = timeOfDayBand
    self.source = source
    self.sourceGrade = sourceGrade
    self.values = values
    self.derived = derived
    self.status = status
    self.reportPhotoPath = reportPhotoPath
    self.createdAt = createdAt
  }

  /// Reads a document (FirebaseData maps the snapshot to `JSONValue`). nil when it is not an object or has no
  /// `measuredAt` timestamp, since such a record has no place on a timeline.
  public init?(id: String, document: JSONValue) {
    guard let object = document.objectValue, case let .timestamp(measuredAt)? = object["measuredAt"] else { return nil }
    let memberUid = object["memberUid"]?.stringValue
    let pendingId = object["pendingMemberId"]?.stringValue
    var values: [BodyCompositionKey: Double] = [:]
    for (key, value) in object["values"]?.objectValue ?? [:] {
      if let key = BodyCompositionKey(rawValue: key), let number = value.doubleValue { values[key] = number }
    }
    self.init(
      id: id,
      member: memberUid.map(MemberKey.uid) ?? pendingId.map(MemberKey.pending),
      deviceModel: object["deviceModel"]?.stringValue ?? "",
      measuredAt: measuredAt,
      fasting: object["fasting"]?.stringValue.flatMap(Fasting.init(rawValue:)),
      timeOfDayBand: object["timeOfDayBand"]?.stringValue.flatMap(TimeOfDayBand.init(rawValue:)),
      source: object["source"]?.stringValue,
      sourceGrade: object["sourceGrade"]?.stringValue.flatMap(SourceGrade.init(rawValue:)),
      values: values,
      derived: object["derived"].flatMap(Self.derived),
      status: object["status"]?.stringValue.flatMap(MeasurementStatus.init(rawValue:)),
      reportPhotoPath: object["reportPhotoPath"]?.stringValue,
      createdAt: { if case let .timestamp(date)? = object["createdAt"] { return date } else { return nil } }())
  }

  /// A readable `derived` map: numbers, a timestamp and `sourceGrade == "derived"`; anything else is nil.
  private static func derived(_ value: JSONValue) -> DerivedBMI? {
    guard let map = value.objectValue, let bmi = map["bmi"]?.doubleValue, let height = map["heightCmUsed"]?.doubleValue,
      case let .timestamp(measured)? = map["heightMeasuredAt"], map["sourceGrade"]?.stringValue == SourceGrade.derived.rawValue
    else { return nil }
    return DerivedBMI(bmi: bmi, heightCmUsed: height, heightMeasuredAt: measured)
  }

  /// Whether the record counts for trends, defaults and the device-change notice (voided records never do,
  /// F-BC-03.5).
  public var isActive: Bool { status == .active }
}

/// Body composition records → chart points (DF-130, V1-09 §8.1 `bodyComposition` row).
public enum BodyCompositionSeries {
  /// One point per active record that has `metricCode` and a readable source grade, sorted by (`measuredAt`, id).
  /// Voided records (AC-DF-130.11), records without a grade (AC-DF-130.1) and records that did not measure the metric
  /// give no point; nothing is filled in (C-04). `bmi` comes from `derived` with grade `derived`.
  public static func points(from records: [BodyCompositionRecord], metricCode: MetricCode) -> [SeriesPoint] {
    let entry = MetricCatalog.entry(for: metricCode)
    guard entry.family == .bodyComposition else { return [] }
    let key = BodyCompositionKey(metricCode: metricCode)
    return records.compactMap { record -> SeriesPoint? in
      guard record.isActive else { return nil }
      let value: Double?
      let grade: SourceGrade?
      if let key {
        value = record.values[key]
        grade = record.sourceGrade
      } else if metricCode == .bmi {
        value = record.derived?.bmi
        grade = record.derived == nil ? nil : .derived
      } else {
        return nil
      }
      guard let value, let grade else { return nil }
      return SeriesPoint(
        refId: record.id, metricCode: metricCode, sourceGrade: grade, side: .none, value: value,
        unit: entry.unit.rawValue, measuredAt: record.measuredAt, family: .bodyComposition,
        conditions: ConditionSnapshot(
          deviceKey: DeviceModelName.normalize(record.deviceModel), fasting: record.fasting?.rawValue,
          timeOfDayBand: record.timeOfDayBand?.rawValue, source: record.source))
    }
    .sorted { ($0.measuredAt, $0.refId) < ($1.measuredAt, $1.refId) }
  }

  /// The latest active record by (`measuredAt`, id): the form's default device and height, and the record the
  /// device-change notice compares with (V1-09 §10.3, §10.6).
  public static func latestActive(_ records: [BodyCompositionRecord], before date: Date? = nil) -> BodyCompositionRecord? {
    records.filter { record in record.isActive && date.map { record.measuredAt < $0 } ?? true }
      .max { ($0.measuredAt, $0.id) < ($1.measuredAt, $1.id) }
  }

  /// The device-change notice (F-BC-03.4, V1-09 §10.6, AC-DF-128.7): true when the latest active record measured
  /// before `measuredAt` used another (normalized) device. It never blocks saving; the trend breaks there
  /// (`SeriesSegmenter`). No earlier record or no device chosen yet is no notice.
  public static func deviceChanged(_ records: [BodyCompositionRecord], deviceModel: String?, measuredAt: Date) -> Bool {
    let chosen = DeviceModelName.normalize(deviceModel ?? "")
    guard !chosen.isEmpty, let previous = latestActive(records, before: measuredAt) else { return false }
    return DeviceModelName.normalize(previous.deviceModel) != chosen
  }
}
