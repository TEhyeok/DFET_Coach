import SwiftUI
import WidgetKit

private enum WidgetColor {
  static let healthRed = Color(red: 1.0, green: 0.176, blue: 0.333)
  static let blue = Color(red: 0.0, green: 0.478, blue: 1.0)
  static let orange = Color(red: 1.0, green: 0.584, blue: 0.0)
  static let green = Color(red: 0.204, green: 0.78, blue: 0.349)
  static let text = Color(red: 0.114, green: 0.114, blue: 0.122)
  static let secondary = Color(red: 0.431, green: 0.431, blue: 0.451)
}

struct TrainerWidgetEntry: TimelineEntry {
  let date: Date
  let snapshot: TrainerWidgetSnapshot
}

struct TrainerWidgetProvider: TimelineProvider {
  func placeholder(in context: Context) -> TrainerWidgetEntry {
    TrainerWidgetEntry(date: Date(), snapshot: .placeholder)
  }

  func getSnapshot(in context: Context, completion: @escaping (TrainerWidgetEntry) -> Void) {
    completion(TrainerWidgetEntry(date: Date(), snapshot: TrainerWidgetSnapshotStore.load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<TrainerWidgetEntry>) -> Void) {
    let entry = TrainerWidgetEntry(date: Date(), snapshot: TrainerWidgetSnapshotStore.load())
    let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
    completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
  }
}

struct TodaySessionWidget: Widget {
  let kind = "TodaySessionWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: TrainerWidgetProvider()) { entry in
      TrainerMetricWidgetView(
        title: "오늘 세션",
        value: "\(entry.snapshot.todaySessions)",
        unit: "건",
        subtitle: entry.snapshot.generatedAtLabel,
        symbol: "calendar.badge.clock",
        color: WidgetColor.healthRed
      )
    }
    .configurationDisplayName("오늘 세션")
    .description("트레이너의 오늘 세션 수를 빠르게 확인합니다.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct SoapTodoWidget: Widget {
  let kind = "SoapTodoWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: TrainerWidgetProvider()) { entry in
      TrainerMetricWidgetView(
        title: "SOAP 미완료",
        value: "\(entry.snapshot.soapTodoCount)",
        unit: "건",
        subtitle: "공유 전 정리 필요",
        symbol: "doc.text.fill",
        color: WidgetColor.blue
      )
    }
    .configurationDisplayName("SOAP 미완료")
    .description("정리가 필요한 SOAP 기록을 확인합니다.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct ReassessmentWidget: Widget {
  let kind = "ReassessmentWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: TrainerWidgetProvider()) { entry in
      TrainerMetricWidgetView(
        title: "재평가 필요",
        value: "\(entry.snapshot.reassessmentCount)",
        unit: "명",
        subtitle: String(format: "평균 통증 %.1f", entry.snapshot.averagePain),
        symbol: "exclamationmark.triangle.fill",
        color: WidgetColor.orange
      )
    }
    .configurationDisplayName("재평가 필요")
    .description("통증 상승 또는 재평가 일정이 있는 회원 수를 보여줍니다.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct TrainerMetricWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let title: String
  let value: String
  let unit: String
  let subtitle: String
  let symbol: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: family == .systemSmall ? 10 : 14) {
      HStack(spacing: 8) {
        Image(systemName: symbol)
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(color)
        Text(title)
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(color)
          .lineLimit(1)
      }

      HStack(alignment: .firstTextBaseline, spacing: 4) {
        Text(value)
          .font(.system(size: family == .systemSmall ? 40 : 46, weight: .bold))
          .foregroundStyle(WidgetColor.text)
        Text(unit)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(WidgetColor.secondary)
      }

      Text(subtitle)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(WidgetColor.secondary)
        .lineLimit(2)

      Spacer(minLength: 0)
    }
    .padding(18)
    .widgetBackground()
  }
}

private extension View {
  @ViewBuilder
  func widgetBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(.fill.tertiary, for: .widget)
    } else {
      background(Color.white)
    }
  }
}

@main
struct DFETTrainerWidgetsBundle: WidgetBundle {
  var body: some Widget {
    TodaySessionWidget()
    SoapTodoWidget()
    ReassessmentWidget()
  }
}
