import SwiftUI
import TrainerContracts

/// Where a value came from (§7.1, C-01, DF-016). Labels are the deck's `sourceGrade.*` keys (PRD appendix B.4
/// names). `photoAuto` has a dashed border (screening only) and `observedSection` is marked beta. `modelEstimate`
/// and `aiAppearance` are never shown in v1 (their deck keys exist only so they are never '해석 불가').
public struct SourceGradeChip: View {
  private let grade: SourceGrade
  private let deviceModel: String?
  private let localize: Localizer

  public init(grade: SourceGrade, deviceModel: String? = nil, localize: Localizer = .main) {
    self.grade = grade
    self.deviceModel = deviceModel
    self.localize = localize
  }

  /// nil for the grades v1 never shows.
  public static func label(_ grade: SourceGrade, deviceModel: String?, localize: Localizer) -> String? {
    switch grade {
    case .modelEstimate, .aiAppearance:
      return nil
    case .device:
      return localize.format("sourceGrade.device", deviceModel ?? localize("common.notEntered"))
    default:
      return localize("sourceGrade.\(grade.rawValue)")
    }
  }

  public var body: some View {
    if let text = Self.label(grade, deviceModel: deviceModel, localize: localize) {
      Text(text)
        .font(.caption.weight(.medium))
        .foregroundStyle(TrainerColor.neutral700)
        .padding(.horizontal, TrainerSpacing.s)
        .padding(.vertical, TrainerSpacing.xxs)
        .background(TrainerColor.neutral100, in: RoundedRectangle(cornerRadius: TrainerSpacing.cornerRadius))
        .overlay {
          RoundedRectangle(cornerRadius: TrainerSpacing.cornerRadius)
            .strokeBorder(TrainerColor.neutral400, style: StrokeStyle(lineWidth: 1, dash: grade == .photoAuto ? [3, 2] : []))
        }
        .accessibilityIdentifier("sourceGrade.\(grade.rawValue)")
    }
  }
}
