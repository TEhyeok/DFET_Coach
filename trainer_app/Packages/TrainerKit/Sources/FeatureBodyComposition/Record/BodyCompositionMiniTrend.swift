import DesignSystem
import SwiftUI
import TrainerContracts
import TrainerDomain

/// TR-11 미니 추이 (DF-130, AC-DF-130.11): one of weight, body fat % and skeletal muscle mass over the last 12 months,
/// drawn by `SeriesTrendChart` (source chip '기기 측정 · {device}', a break at a device or condition change, no
/// interpolation, '산정 준비 중'). Voided records are not points.
public struct BodyCompositionMiniTrend: View {
  @Bindable private var model: BodyCompositionMemberModel
  private let localize: Localizer

  public init(model: BodyCompositionMemberModel, localize: Localizer = .main) {
    self.model = model
    self.localize = localize
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: TrainerSpacing.m) {
      Text(localize("tr11.miniTrend"))
        .font(.headline)
        .accessibilityAddTraits(.isHeader)
      Picker(selection: $model.selectedMetric) {
        ForEach(BodyCompositionMemberModel.trendMetrics, id: \.self) { metric in
          Text(localize("metric." + metric.rawValue + ".name")).tag(metric)
        }
      } label: {
        Text(localize("tr11.miniTrend"))
      }
      .pickerStyle(.segmented)
      .accessibilityIdentifier("tr11.miniTrend.metric")
      switch model.records {
      case .loading:
        LoadingLine(localize: localize)
      case .failed:
        LoadFailed(localize: localize) { model.retry() }
      case .loaded:
        SeriesTrendChart(model: model.chartModel(model.selectedMetric), localize: localize)
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("tr11.miniTrend")
  }
}

/// '불러오는 중'.
struct LoadingLine: View {
  let localize: Localizer

  var body: some View {
    HStack(spacing: TrainerSpacing.s) {
      ProgressView()
      Text(localize("common.loading"))
        .foregroundStyle(TrainerColor.neutral600)
    }
    .accessibilityElement(children: .combine)
  }
}

/// '불러오기 실패' and '다시 시도': a failed read is never shown as an empty trend (§9.6).
struct LoadFailed: View {
  let localize: Localizer
  let retry: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: TrainerSpacing.s) {
      Text(localize("common.loadFailed"))
        .font(.subheadline)
      Button(localize("common.retry"), action: retry)
        .buttonStyle(.bordered)
        .frame(minHeight: TrainerSpacing.minTapTarget)
        .accessibilityIdentifier("tr11.retry")
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("tr11.loadFailed")
  }
}
