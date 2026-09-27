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
    }
    .accessibilityIdentifier("preview.designSystem")
  }
}
#endif
