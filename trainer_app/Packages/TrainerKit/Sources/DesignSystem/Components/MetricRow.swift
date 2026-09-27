import SwiftUI
import TrainerContracts

/// One measured value as a row (C-01, F-VIZ-07.1, DF-016). Everything the row shows comes in here; the row never
/// computes a change.
public struct MetricRowModel: Equatable, Sendable {
  public let code: MetricCode
  public let value: Double
  public let side: Side
  /// nil means the value's source is unknown: the row is not drawn (C-01, AC-DF-016.3).
  public let sourceGrade: SourceGrade?
  public let deviceModel: String?
  public let measuredAt: Date
  /// `change.*` key of the change state; '산정 준비 중' until change evaluation exists (P3, §7.6).
  public let changeStatusKey: String

  public init(
    code: MetricCode, value: Double, side: Side = .none, sourceGrade: SourceGrade?, deviceModel: String? = nil,
    measuredAt: Date, changeStatusKey: String = "change.pendingPolicy"
  ) {
    self.code = code
    self.value = value
    self.side = side
    self.sourceGrade = sourceGrade
    self.deviceModel = deviceModel
    self.measuredAt = measuredAt
    self.changeStatusKey = changeStatusKey
  }
}

/// Name, value and unit, side, `SourceGradeChip` and the measurement date. Without a source grade (or with one v1
/// never shows) the row is `EmptyView` (AC-DF-016.3). VoiceOver reads the V1-12 `a11y.metric` template
/// (AC-DF-016.5).
public struct MetricRow: View {
  private let metric: MetricRowModel
  private let localize: Localizer
  private let timeZone: TimeZone

  public init(metric: MetricRowModel, localize: Localizer = .main, timeZone: TimeZone = .current) {
    self.metric = metric
    self.localize = localize
    self.timeZone = timeZone
  }

  /// Whether the row draws anything.
  public static func isShown(_ metric: MetricRowModel) -> Bool {
    guard let grade = metric.sourceGrade else { return false }
    return SourceGradeChip.label(grade, deviceModel: metric.deviceModel, localize: Localizer { $0 }) != nil
  }

  public var body: some View {
    if Self.isShown(metric), let grade = metric.sourceGrade {
      HStack(alignment: .firstTextBaseline, spacing: TrainerSpacing.m) {
        VStack(alignment: .leading, spacing: TrainerSpacing.xxs) {
          Text(localize("metric.\(metric.code.rawValue).name"))
            .font(.subheadline)
          if metric.side != .none {
            Text(localize("side.\(metric.side.rawValue)"))
              .font(.caption)
              .foregroundStyle(TrainerColor.neutral600)
          }
        }
        Spacer(minLength: TrainerSpacing.s)
        VStack(alignment: .trailing, spacing: TrainerSpacing.xxs) {
          Text(Self.valueText(metric) + localize("unit.\(Self.unit(metric).rawValue)"))
            .font(.body.monospacedDigit().weight(.semibold))
          HStack(spacing: TrainerSpacing.s) {
            SourceGradeChip(grade: grade, deviceModel: metric.deviceModel, localize: localize)
            Text(Self.dateText(metric.measuredAt, timeZone: timeZone))
              .font(.caption.monospacedDigit())
              .foregroundStyle(TrainerColor.neutral600)
          }
        }
      }
      .frame(minHeight: TrainerSpacing.minTapTarget)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Self.accessibilityLabel(metric, localize: localize, timeZone: timeZone))
      .accessibilityIdentifier("metric.row.\(metric.code.rawValue)")
    }
  }

  static func unit(_ metric: MetricRowModel) -> MetricUnit {
    MetricCatalog.entry(for: metric.code).unit
  }

  /// The catalog's decimals, and U+2212 for negatives so VoiceOver reads '마이너스' (V1-12 §2.6).
  public static func valueText(_ metric: MetricRowModel) -> String {
    let decimals = MetricCatalog.entry(for: metric.code).decimals
    let text = String(format: "%.\(decimals)f", locale: Locale(identifier: "en_US_POSIX"), metric.value)
    return text.hasPrefix("-") ? "\u{2212}" + text.dropFirst() : text
  }

  /// Trainer date format `yyyy.MM.dd` (V1-12 §2.6).
  public static func dateText(_ date: Date, timeZone: TimeZone) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d.%02d.%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
  }

  /// `a11y.metric`: "{metricName} {value}{unit}, {side}, 출처 {source}, {date}, 변화 {status}".
  public static func accessibilityLabel(_ metric: MetricRowModel, localize: Localizer, timeZone: TimeZone) -> String {
    let source = metric.sourceGrade.flatMap { SourceGradeChip.label($0, deviceModel: metric.deviceModel, localize: localize) }
    return localize.format(
      "a11y.metric",
      localize("metric.\(metric.code.rawValue).name"), valueText(metric), localize("unit.\(unit(metric).rawValue)"),
      localize("side.\(metric.side.rawValue)"), source ?? "", dateText(metric.measuredAt, timeZone: timeZone),
      localize(metric.changeStatusKey))
  }
}
