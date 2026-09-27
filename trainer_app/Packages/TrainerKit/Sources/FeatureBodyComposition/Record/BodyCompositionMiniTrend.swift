import DesignSystem
import Foundation
import SwiftUI
import TrainerContracts
import TrainerDomain

/// DF-130 adapter: the domain decides points/segments; this layer only translates to chart presentation types.
public enum BodyCompositionTrend {
  public static let metrics: [MetricCode] = [.weightKg, .bodyFatPercent, .skeletalMuscleMassKg]

  public static func model(records: [BodyCompositionRecord], metricCode: MetricCode, now: Date) -> SeriesChartModel {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    let since = calendar.date(byAdding: .month, value: -12, to: now) ?? now
    let recent = records.filter { $0.measuredAt >= since }
    let points = BodyCompositionSeries.points(from: recent, metricCode: metricCode)
    let input = SeriesChartInput.make(points)
    let segments: [ChartSegment]
    switch input {
    case .empty:
      segments = []
    case .rejected:
      // Preserve the rejected grades so SeriesTrendChart presents its normal rejection message.
      segments = [ChartSegment(id: "rejected", points: points.map(chartPoint))]
    case let .ready(_, lines):
      segments = lines.flatMap { line in
        line.segments.map { segment in
          ChartSegment(id: segment.id, side: line.identity.side,
                       breakBefore: segment.breakBefore.map(chartBreak), points: segment.points.map(chartPoint))
        }
      }
    }
    let latestPoint = points.max { ($0.measuredAt, $0.refId) < ($1.measuredAt, $1.refId) }
    return SeriesChartModel(metricCode: metricCode, deviceModel: latestPoint?.conditions.deviceKey,
                            segments: segments, badge: .pendingPolicy)
  }

  private static func chartPoint(_ value: SeriesPoint) -> ChartPoint {
    ChartPoint(measuredAt: value.measuredAt, value: value.value, sourceGrade: value.sourceGrade)
  }

  private static func chartBreak(_ value: SeriesBreak) -> ChartBreakReason {
    switch value.detail {
    case let .device(from, to): return .deviceChanged(from: from, to: to)
    case .protocolVersion: return .protocolChanged
    case let .condition(key): return .conditionMismatch(condition: key == "stationProfile" ? "station" : key)
    }
  }
}

public struct BodyCompositionMiniTrend: View {
  private let records: [BodyCompositionRecord]
  private let now: Date
  private let localize: Localizer
  @State private var metric: MetricCode = .weightKg

  public init(records: [BodyCompositionRecord], now: Date = Date(), localize: Localizer = .main) {
    self.records = records
    self.now = now
    self.localize = localize
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: TrainerSpacing.m) {
      Picker(selection: $metric) {
        ForEach(BodyCompositionTrend.metrics, id: \.self) { code in
          Text(localize("metric.\(code.rawValue).name")).tag(code)
        }
      } label: { Text(localize("tr11.trend.metric")) }
      .pickerStyle(.menu)
      .accessibilityIdentifier("tr11.trend.metric")
      SeriesTrendChart(model: BodyCompositionTrend.model(records: records, metricCode: metric, now: now),
                       localize: localize, timeZone: TimeZone(identifier: "Asia/Seoul")!)
    }
    .accessibilityIdentifier("tr11.trend")
  }
}

/// Reusable record history. Voided measurements are excluded from both the displayed list and the mini trend.
public struct BodyCompositionHistoryView: View {
  private let records: [BodyCompositionRecord]
  private let now: Date
  private let localize: Localizer

  public init(records: [BodyCompositionRecord], now: Date = Date(), localize: Localizer = .main) {
    self.records = records
    self.now = now
    self.localize = localize
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: TrainerSpacing.l) {
      Text(localize("tr11.trend.title")).font(.headline).accessibilityAddTraits(.isHeader)
      BodyCompositionMiniTrend(records: records, now: now, localize: localize)
      Text(localize("tr11.recentRecords")).font(.headline).accessibilityAddTraits(.isHeader)
      let active = records.filter(\.isActive).sorted { ($0.measuredAt, $0.id) > ($1.measuredAt, $1.id) }
      if active.isEmpty {
        Text(localize("tr11.records.empty")).foregroundStyle(.secondary)
      }
      ForEach(active) { record in
        DisclosureGroup {
          ForEach(BodyCompositionKey.allCases, id: \.self) { key in
            if let value = record.values[key] {
              MetricRow(metric: MetricRowModel(code: key.metricCode, value: value, sourceGrade: record.sourceGrade,
                                              deviceModel: record.deviceModel, measuredAt: record.measuredAt),
                        localize: localize, timeZone: TimeZone(identifier: "Asia/Seoul")!)
            }
          }
          if let derived = record.derived {
            MetricRow(metric: MetricRowModel(code: .bmi, value: derived.bmi, sourceGrade: .derived,
                                            measuredAt: record.measuredAt), localize: localize)
          }
          if let fasting = record.fasting { Text(localize(fasting.copyKey)).font(.footnote) }
          if let band = record.timeOfDayBand { Text(localize(band.copyKey)).font(.footnote) }
        } label: {
          VStack(alignment: .leading, spacing: TrainerSpacing.xs) {
            Text(record.measuredAt, format: .dateTime.year().month().day().hour().minute())
              .font(.subheadline.monospacedDigit())
            Text(record.deviceModel).font(.caption).foregroundStyle(.secondary)
          }
          // A group-level identifier propagates to its metric rows and hides their own identifiers.
          .accessibilityIdentifier("tr11.record.\(record.id)")
        }
      }
    }
  }
}
