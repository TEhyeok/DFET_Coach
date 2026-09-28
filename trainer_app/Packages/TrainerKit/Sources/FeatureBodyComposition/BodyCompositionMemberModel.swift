import DesignSystem
import Foundation
import Observation
import TrainerContracts
import TrainerDomain

/// One member's body composition as TR-03 and TR-11 show it (DF-127, DF-130): the last 12 months of records (server
/// records plus this device's unsynced ones with their sync state, `MeasurementStore.observeBodyCompositionRecords`)
/// and the member's effective consent. Loading, loaded and failed are separate states: a failure is never shown as
/// "no records" (§9.6). The subscriptions live as long as the model; screens only call `start()`.
@MainActor
@Observable
public final class BodyCompositionMemberModel {
  public enum RecordsState: Equatable {
    case loading
    case loaded([BodyCompositionRecord])
    case failed
  }

  /// The mini trend's metrics (AC-DF-130.11, V1-07 TR-11 '미니 추이').
  public static let trendMetrics: [MetricCode] = [.weightKg, .bodyFatPercent, .skeletalMuscleMassKg]
  /// The trend window (DF-130: 최근 12개월).
  public static let trendMonths = 12

  /// One TR-03 row: a metric and the latest active record that measured it.
  public struct LatestValue: Identifiable, Equatable {
    public let key: BodyCompositionKey
    public let record: BodyCompositionRecord
    public var id: BodyCompositionKey { key }
  }

  public let member: MemberKey
  public private(set) var records: RecordsState = .loading
  /// Records TR-11 saved through this model, as saved: `record(id:)` has them before any read does.
  private var savedRecords: [String: BodyCompositionRecord] = [:]
  /// nil until the first value arrives: the save gate treats it as not allowed yet.
  public private(set) var consent: EffectiveConsent?
  /// The metric the mini trend shows.
  public var selectedMetric: MetricCode = .weightKg

  @ObservationIgnored let services: BodyCompositionServices
  @ObservationIgnored let now: () -> Date
  @ObservationIgnored private var recordsTask: Task<Void, Never>?
  @ObservationIgnored private var consentTask: Task<Void, Never>?
  @ObservationIgnored private var generation = 0
  /// The oldest `measuredAt` of a record saved here before the trend window; the read reaches back to it.
  @ObservationIgnored private var earliestSaved: Date?
  /// Where the current read starts: `since`, or `earliestSaved` when that is earlier.
  @ObservationIgnored private var readStart: Date?

  public init(member: MemberKey, services: BodyCompositionServices, now: @escaping () -> Date = Date.init) {
    self.member = member
    self.services = services
    self.now = now
  }

  deinit {
    recordsTask?.cancel()
    consentTask?.cancel()
  }

  /// Subscribes unless subscribed. After a failure it starts again from `.loading`.
  public func start() {
    if consentTask == nil {
      let stream = services.consent.observe(member: member)
      consentTask = Task { [weak self] in
        for await value in stream {
          guard let self else { return }
          self.consent = value
        }
      }
    }
    guard recordsTask == nil else { return }
    generation += 1
    let current = generation
    if case .failed = records { records = .loading }
    let start = min(since, earliestSaved ?? since)
    readStart = start
    let stream = services.store.observeBodyCompositionRecords(member: member, since: start)
    recordsTask = Task { [weak self] in
      do {
        for try await list in stream {
          guard let self, self.generation == current else { return }
          self.records = .loaded(list)
        }
        self?.finished(current, failed: false)
      } catch {
        self?.finished(current, failed: true)
      }
    }
  }

  /// '다시 시도'.
  public func retry() {
    recordsTask?.cancel()
    recordsTask = nil
    generation += 1
    records = .loading
    start()
  }

  private func finished(_ run: Int, failed: Bool) {
    guard run == generation else { return }
    recordsTask = nil
    if failed { records = .failed }
  }

  /// A record TR-11 just saved (review finding 3). `record(id:)` has it at once, from the saved entry, until a read
  /// returns it. One measured before the trend window is not in the 12-month read, so the read reaches back to it: the
  /// record view then shows the stored record and its sync state, while the trend and TR-03 still start at `since`.
  func didSave(_ record: BodyCompositionRecord) {
    savedRecords[record.id] = record
    guard record.measuredAt < (readStart ?? since) else { return }
    earliestSaved = min(record.measuredAt, earliestSaved ?? record.measuredAt)
    recordsTask?.cancel()
    recordsTask = nil
    start()  // keeps the loaded list on screen until the wider read answers
  }

  /// 12 months before now (the mini trend and TR-03 window).
  var since: Date {
    Calendar(identifier: .gregorian).date(byAdding: .month, value: -Self.trendMonths, to: now()) ?? now()
  }

  /// Every loaded record, voided ones included (and saved records older than the trend window).
  public var loadedRecords: [BodyCompositionRecord] {
    if case let .loaded(list) = records { return list }
    return []
  }

  /// Loaded records inside the trend window.
  var windowRecords: [BodyCompositionRecord] {
    let since = since
    return loadedRecords.filter { $0.measuredAt >= since }
  }

  /// The records the mini trend draws from: the window's, without drafts whose sending failed (`syncFailed`: refused
  /// for good, or past the retry limit). Such a draft stays on this device and on its TR-03 row with '동기화 실패'
  /// (V1-07 §4.11, §6), but the server does not have it, so it is no point until it is sent (review finding 4).
  var trendRecords: [BodyCompositionRecord] {
    windowRecords.filter { $0.syncState != .syncFailed }
  }

  /// The latest active record: the form's default device and height (V1-09 §10.3).
  public var latest: BodyCompositionRecord? {
    BodyCompositionSeries.latestActive(loadedRecords)
  }

  /// Whether the trend window has an active record: TR-03 shows the section, else '아직 기록이 없어요'.
  public var hasActiveRecords: Bool {
    windowRecords.contains(where: \.isActive)
  }

  /// TR-03's rows (AC-DF-114.9, review finding 7): per trend metric, the latest active record in the window that
  /// measured it, so a weight-only record does not hide the last body fat %. Each row has its record's own date,
  /// device and sync state; a metric no record measured has no row.
  public var latestValues: [LatestValue] {
    let records = windowRecords
    return Self.trendMetrics.compactMap { metric in
      guard let key = BodyCompositionKey(metricCode: metric),
        let record = BodyCompositionSeries.latestActive(records, measuring: key)
      else { return nil }
      return LatestValue(key: key, record: record)
    }
  }

  /// The record from the read, else as TR-11 saved it.
  public func record(id: String) -> BodyCompositionRecord? {
    loadedRecords.first { $0.id == id } ?? savedRecords[id]
  }

  /// Whether the record is inside the mini trend's window (12 months); an older one is not a point (review finding 3).
  public func isInTrendWindow(_ record: BodyCompositionRecord) -> Bool {
    record.measuredAt >= since
  }

  /// The chart of one metric: active records only, segmented at device and condition changes, '산정 준비 중'.
  public func chartModel(_ metric: MetricCode) -> SeriesChartModel {
    SeriesChartMapping.model(metricCode: metric, points: BodyCompositionSeries.points(from: trendRecords, metricCode: metric))
  }

  /// A new TR-11 entry form for this member.
  public func makeEntryModel(localize: Localizer = .main) -> BodyCompositionEntryModel {
    BodyCompositionEntryModel(memberModel: self, now: now, localize: localize)
  }
}
