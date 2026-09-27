import Accessibility
import SwiftUI
import TrainerContracts

/// The audio graph of `SeriesTrendChart` (A-03, AC-DF-130.10): x is the measurement date, y the value in the
/// metric's unit, one series per segment named by its side and the break it starts with. The summary is the
/// `chart.summary` sentence.
struct SeriesChartDescriptor: AXChartDescriptorRepresentable {
  let model: SeriesChartModel
  let localize: Localizer
  let timeZone: TimeZone

  func makeChartDescriptor() -> AXChartDescriptor {
    let code = model.metricCode
    let name = localize("metric.\(code.rawValue).name")
    let unit = SeriesTrendChart.unitText(code, localize: localize)
    let timeZone = timeZone
    let dates = model.points.map { $0.measuredAt.timeIntervalSince1970 }
    let values = model.points.map(\.value)
    let xAxis = AXNumericDataAxisDescriptor(
      title: localize("chart.measuredAt"), range: (dates.min() ?? 0)...(dates.max() ?? 0), gridlinePositions: []
    ) { MetricRow.dateText(Date(timeIntervalSince1970: $0), timeZone: timeZone) }
    let yAxis = AXNumericDataAxisDescriptor(
      title: name, range: (values.min() ?? 0)...(values.max() ?? 0), gridlinePositions: []
    ) { MetricRow.valueText($0, code: code) + unit }
    let series = model.segments.filter { !$0.points.isEmpty }.map { segment in
      AXDataSeriesDescriptor(
        name: seriesName(segment), isContinuous: true,
        dataPoints: segment.points.map { AXDataPoint(x: $0.measuredAt.timeIntervalSince1970, y: $0.value) })
    }
    return AXChartDescriptor(
      title: name, summary: SeriesTrendChart.summary(model, localize: localize, timeZone: timeZone),
      xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: series)
  }

  /// The side ('왼쪽') and the break the segment starts with ('기기 변경: A → B'), joined by ' · ' (V1-12 §2.6);
  /// the metric name for a plain segment.
  func seriesName(_ segment: ChartSegment) -> String {
    let side = segment.side == .left || segment.side == .right ? localize("chart.legend.\(segment.side.rawValue)") : nil
    let parts = [side, segment.breakBefore.map { SeriesTrendChart.breakLabel($0, localize: localize) }].compactMap { $0 }
    return parts.isEmpty ? localize("metric.\(model.metricCode.rawValue).name") : parts.joined(separator: " · ")
  }
}
