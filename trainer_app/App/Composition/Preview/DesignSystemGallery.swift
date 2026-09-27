#if DEBUG
import DesignSystem
import SwiftUI
import TrainerContracts

/// `--preview-design-system`: every DesignSystem component once, with synthetic values, for layout checks
/// (TC-DF016-04) and manual review in light and dark mode. DEBUG only.
struct DesignSystemGallery: View {
  private let measuredAt = Date(timeIntervalSince1970: 1_790_000_000)
  /// Fixed, so the dates read the same on any device (DesignSystemUITests).
  private let seoul = TimeZone(identifier: "Asia/Seoul")!

  var body: some View {
    List {
      Section {
        ForEach(SyncState.allCases, id: \.self) { state in
          let failed = state == .syncFailed
          SyncStateBadge(state: state, reasonKey: failed ? "sync.reason.ruleDenied" : nil, onRetry: failed ? {} : nil)
        }
      }
      Section {
        ForEach(SourceGrade.allCases, id: \.self) { grade in
          SourceGradeChip(grade: grade, deviceModel: "SYN-DEVICE")
        }
      }
      Section {
        MetricRow(metric: MetricRowModel(code: .weightKg, value: 72.4, sourceGrade: .device, deviceModel: "SYN-DEVICE",
                                         measuredAt: measuredAt), timeZone: seoul)
        MetricRow(metric: MetricRowModel(code: .shoulderTiltAngle, value: 1.3, side: .left, sourceGrade: .photoManual,
                                         measuredAt: measuredAt), timeZone: seoul)
        MetricRow(metric: MetricRowModel(code: .waistCircumference, value: 80.2, sourceGrade: nil, measuredAt: measuredAt),
                  timeZone: seoul)
      }
      Section {
        ComingSoonLabel()
        EmptyState(systemImage: "tray", titleKey: "tr02.empty", actionKey: "common.retry", action: {})
          .frame(height: 220)
      }
      Section {
        // DF-130, last so the DF-016 checks above stay on the first screen: two segments (device SYN-DEVICE-A twice,
        // then SYN-DEVICE-B) with the device-change break and '산정 준비 중'.
        SeriesTrendChart(model: deviceChangeTrend, timeZone: seoul)
        ChangeBadge(state: .indeterminate(.deviceChanged))
      }
    }
    .accessibilityIdentifier("preview.designSystem")
  }

  /// Synthetic weights on 1, 2 and 10 January 2026 (irregular spacing on a date axis).
  private var deviceChangeTrend: SeriesChartModel {
    func point(_ day: Int, _ value: Double) -> ChartPoint {
      ChartPoint(measuredAt: Date(timeIntervalSince1970: 1_767_225_600 + Double(day - 1) * 86_400), value: value,
                 sourceGrade: .device)
    }
    return SeriesChartModel(metricCode: .weightKg, deviceModel: "SYN-DEVICE-B", segments: [
      ChartSegment(id: "weightKg#0", points: [point(1, 72.4), point(2, 71.9)]),
      ChartSegment(id: "weightKg#1", breakBefore: .deviceChanged(from: "SYN-DEVICE-A", to: "SYN-DEVICE-B"),
                   points: [point(10, 70.2)]),
    ])
  }
}
#endif
