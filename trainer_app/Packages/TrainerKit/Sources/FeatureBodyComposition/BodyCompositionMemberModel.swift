import DesignSystem
import Foundation
import Observation
import TrainerContracts
import TrainerDomain

/// One member's body composition as TR-03 and TR-11 show it (DF-127, DF-130): the last 12 months of records (server
/// records plus this device's unsynced ones, `MeasurementStore.observeBodyCompositionRecords`) and the member's
/// effective consent. Loading, loaded and failed are separate states: a failure is never shown as "no records"
/// (§9.6). The subscriptions live as long as the model; screens only call `start()`.
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

  public let member: MemberKey
  public private(set) var records: RecordsState = .loading
  /// nil until the first value arrives: the save gate treats it as not allowed yet.
  public private(set) var consent: EffectiveConsent?
  /// The metric the mini trend shows.
  public var selectedMetric: MetricCode = .weightKg

  @ObservationIgnored let services: BodyCompositionServices
  @ObservationIgnored let now: () -> Date
  @ObservationIgnored private var recordsTask: Task<Void, Never>?
  @ObservationIgnored private var consentTask: Task<Void, Never>?
  @ObservationIgnored private var generation = 0

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
    let stream = services.store.observeBodyCompositionRecords(member: member, since: since)
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

  /// 12 months before now (the mini trend and TR-03 window).
  var since: Date {
    Calendar(identifier: .gregorian).date(byAdding: .month, value: -Self.trendMonths, to: now()) ?? now()
  }

  /// Every loaded record, voided ones included.
  public var loadedRecords: [BodyCompositionRecord] {
    if case let .loaded(list) = records { return list }
    return []
  }

  /// The latest active record: TR-03's latest values, and the form's default device and height (V1-09 §10.3).
  public var latest: BodyCompositionRecord? {
    BodyCompositionSeries.latestActive(loadedRecords)
  }

  public func record(id: String) -> BodyCompositionRecord? {
    loadedRecords.first { $0.id == id }
  }

  /// The chart of one metric: active records only, segmented at device and condition changes, '산정 준비 중'.
  public func chartModel(_ metric: MetricCode) -> SeriesChartModel {
    SeriesChartMapping.model(metricCode: metric, points: BodyCompositionSeries.points(from: loadedRecords, metricCode: metric))
  }

  /// A new TR-11 entry form for this member.
  public func makeEntryModel(localize: Localizer = .main) -> BodyCompositionEntryModel {
    BodyCompositionEntryModel(memberModel: self, now: now, localize: localize)
  }
}
