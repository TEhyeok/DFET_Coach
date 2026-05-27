import SwiftUI

struct SummaryView: View {
  @EnvironmentObject private var store: TrainerStore

  private let favoriteColumns = [
    GridItem(.adaptive(minimum: 210), spacing: 14)
  ]

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          dateCaption
          prioritySummary
          iPadContent(width: geometry.size.width)
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 24)
        .frame(maxWidth: 1180, alignment: .topLeading)
      }
    }
    .background(StudioBackdrop().ignoresSafeArea())
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          store.selectedRoute = .settings
        } label: {
          Image(systemName: TrainerSymbol.member)
            .font(TrainerFont.title(24, weight: .regular))
            .foregroundStyle(TrainerColor.blue)
        }
        .accessibilityLabel("내 정보")
      }
    }
  }

  private var dateCaption: some View {
    Text(todayLabel)
      .font(TrainerFont.label(15, weight: .semibold))
      .foregroundStyle(TrainerColor.blue)
      .trainerLabel("TR-SUM-01")
  }

  private var prioritySummary: some View {
    Button {
      store.selectedRoute = .members
    } label: {
      StudioHeroCard(label: "TR-SUM-02") {
        HStack(spacing: 15) {
          Image(systemName: TrainerSymbol.warning)
            .font(TrainerFont.title(26, weight: .bold))
            .foregroundStyle(TrainerColor.darkInk)
            .frame(width: 54, height: 54)
            .background(TrainerColor.inverseText, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          VStack(alignment: .leading, spacing: 4) {
            Text("오늘의 우선 확인")
              .font(TrainerFont.label(15, weight: .bold))
              .foregroundStyle(TrainerColor.inverseSecondaryText)
            Text("주의 회원 \(store.dashboardSummary.attentionMemberCount)명, SOAP 미완료 \(store.dashboardSummary.soapTodoCount)건")
              .font(TrainerFont.title(22, weight: .bold))
              .foregroundStyle(TrainerColor.inverseText)
              .lineLimit(1)
              .minimumScaleFactor(0.8)
            Text("통증 상승, 재평가, 공유 전 노트를 먼저 확인하세요.")
              .font(TrainerFont.body(14, weight: .medium))
              .foregroundStyle(TrainerColor.inverseSecondaryText)
          }

          Spacer(minLength: 12)

          Image(systemName: TrainerSymbol.chevron)
            .font(TrainerFont.label(15, weight: .bold))
            .foregroundStyle(TrainerColor.darkInk)
            .frame(width: 34, height: 34)
            .background(TrainerColor.inverseText, in: Circle())
        }
      }
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private func iPadContent(width: CGFloat) -> some View {
    if width < 980 {
      VStack(alignment: .leading, spacing: 28) {
        favorites
        highlights
        trends
        todayMembers
      }
    } else {
      HStack(alignment: .top, spacing: 20) {
        VStack(alignment: .leading, spacing: 28) {
          favorites
          highlights
        }

        VStack(alignment: .leading, spacing: 28) {
          trends
          todayMembers
        }
        .frame(width: 360)
      }
    }
  }

  private var favorites: some View {
    VStack(alignment: .leading, spacing: 12) {
      HealthSectionHeader(title: "즐겨찾기", actionTitle: "편집", label: "TR-SUM-03") {}

      LazyVGrid(columns: favoriteColumns, spacing: 14) {
        HealthFavoriteTile(
          title: "오늘 세션",
          value: "\(store.dashboardSummary.todaySessionCount)",
          unit: "건",
          symbol: TrainerSymbol.calendar,
          color: TrainerColor.blue,
          footnote: "완료 \(store.dashboardSummary.completedSessionCount) · 예정 \(store.dashboardSummary.plannedSessionCount)",
          label: "TR-SUM-04"
        )
        HealthFavoriteTile(
          title: "관리 회원",
          value: "\(store.dashboardSummary.managedMemberCount)",
          unit: "명",
          symbol: TrainerSymbol.members,
          color: TrainerColor.blue,
          footnote: "최근 SOAP 기준",
          label: "TR-SUM-05"
        )
        HealthFavoriteTile(
          title: "평균 통증",
          value: String(format: "%.1f", store.averagePain),
          unit: "/10",
          symbol: TrainerSymbol.pain,
          color: TrainerColor.purple,
          footnote: "최근 기록 평균",
          label: "TR-SUM-06"
        )
        HealthFavoriteTile(
          title: "목표 안정",
          value: "\(store.dashboardSummary.stableGoalPercent)",
          unit: "%",
          symbol: TrainerSymbol.target,
          color: TrainerColor.deepBlue,
          footnote: "전체 회원 평균",
          label: "TR-SUM-07"
        )
      }
      .trainerLabel("TR-SUM-03-GRID")
    }
  }

  private var highlights: some View {
    VStack(alignment: .leading, spacing: 12) {
      HealthSectionHeader(title: "하이라이트", label: "TR-SUM-08")

      VStack(spacing: 14) {
        HealthHighlightCard(
          title: "통증 추세",
          subtitle: "최근 SOAP 기록 기준",
          value: String(format: "평균 %.1f", store.averagePain),
          color: TrainerColor.blue,
          legend: [
            ("통증", TrainerColor.purple),
            ("기록 완료율", TrainerColor.blue)
          ],
          label: "TR-SUM-09"
        ) {
          PainCompletionChart(
            painPoints: store.dashboardSummary.painTrend,
            completionPoints: store.dashboardSummary.completionTrend
          )
        }

        HealthHighlightCard(
          title: "SOAP 완료율",
          subtitle: "공유 가능한 노트 정리 상태",
          value: "\(store.dashboardSummary.soapCompletionPercent)%",
          color: TrainerColor.blue,
          label: "TR-SUM-10"
        ) {
          HStack(spacing: 16) {
            HealthProgressPill(
              title: "SOAP",
              value: store.dashboardSummary.soapCompletionPercent,
              color: TrainerColor.blue
            )
            HealthProgressPill(
              title: "홈운동",
              value: store.dashboardSummary.homeExercisePercent,
              color: TrainerColor.deepBlue
            )
          }
          .padding(.top, 8)
        }
      }
    }
  }

  private var trends: some View {
    VStack(alignment: .leading, spacing: 12) {
      HealthSectionHeader(title: "트렌드", actionTitle: "전체", label: "TR-SUM-11") {
        store.selectedRoute = .reports
      }

      HealthCard(padding: 14) {
        VStack(spacing: 0) {
          ForEach(Array(store.dashboardSummary.trends.enumerated()), id: \.element.id) { index, trend in
            HealthTrendRow(
              title: trend.title,
              subtitle: trend.subtitle,
              symbol: trend.symbol,
              color: trend.accent.color,
              value: trend.value,
              label: "TR-SUM-12-\(index + 1)"
            )
            if trend.id != store.dashboardSummary.trends.last?.id {
              Divider()
            }
          }
        }
      }
      .trainerLabel("TR-SUM-12")
    }
  }

  private var todayMembers: some View {
    VStack(alignment: .leading, spacing: 12) {
      HealthSectionHeader(title: "오늘 볼 회원", actionTitle: "전체", label: "TR-SUM-13") {
        store.selectedRoute = .members
      }

      HealthCard(padding: 14) {
        VStack(spacing: 0) {
          ForEach(Array(store.attentionMembers.prefix(3).enumerated()), id: \.element.id) { index, member in
            Button {
              store.selectMember(member)
              store.selectedRoute = .members
            } label: {
              MemberSignalRow(member: member)
                .trainerLabel("TR-SUM-14-\(index + 1)")
            }
            .buttonStyle(.plain)

            if member.id != store.attentionMembers.prefix(3).last?.id {
              Divider()
            }
          }
        }
      }
      .trainerLabel("TR-SUM-14")
    }
  }

  private var todayLabel: String {
    Date.now.formatted(
      .dateTime
        .locale(Locale(identifier: "ko_KR"))
        .month(.wide)
        .day()
        .weekday(.wide)
    )
  }
}

private struct HealthHighlightCard<Content: View>: View {
  let title: String
  let subtitle: String
  let value: String
  let color: Color
  let legend: [(String, Color)]
  let label: String?
  let content: Content

  init(
    title: String,
    subtitle: String,
    value: String,
    color: Color,
    legend: [(String, Color)] = [],
    label: String? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.subtitle = subtitle
    self.value = value
    self.color = color
    self.legend = legend
    self.label = label
    self.content = content()
  }

  var body: some View {
    HealthCard {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 4) {
            Text(title)
              .font(TrainerFont.title(22, weight: .bold))
              .foregroundStyle(TrainerColor.primaryText)
            Text(subtitle)
              .font(TrainerFont.label(13, weight: .semibold))
              .foregroundStyle(TrainerColor.secondaryText)
          }
          Spacer()
          StatusCapsule(text: value, color: color)
        }

        content
          .frame(minHeight: 132)

        if !legend.isEmpty {
          HStack(spacing: 16) {
            ForEach(legend.indices, id: \.self) { index in
              LegendDot(label: legend[index].0, color: legend[index].1)
            }
          }
          .font(TrainerFont.label(12, weight: .semibold))
        }
      }
    }
    .trainerLabel(label)
  }
}

private struct HealthProgressPill: View {
  let title: String
  let value: Int
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(title)
          .font(TrainerFont.label(14, weight: .bold))
          .foregroundStyle(TrainerColor.primaryText)
        Spacer()
        Text("\(value)%")
          .font(TrainerFont.label(14, weight: .bold))
          .foregroundStyle(color)
      }

      ProgressView(value: Double(value) / 100)
        .tint(color)
    }
    .padding(16)
    .frame(maxWidth: .infinity)
    .background(TrainerColor.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

struct MemberSignalRow: View {
  let member: TrainerMember

  var body: some View {
    HStack(spacing: 11) {
      TrainerAvatar(member: member, size: 44)

      VStack(alignment: .leading, spacing: 3) {
        Text(member.name)
          .font(TrainerFont.label(15, weight: .semibold))
          .foregroundStyle(TrainerColor.primaryText)
        Text(member.signal)
          .font(TrainerFont.body(13, weight: .medium))
          .foregroundStyle(TrainerColor.secondaryText)
      }

      Spacer()

      Text("\(member.pain)/10")
        .font(TrainerFont.label(13, weight: .bold))
        .foregroundStyle(member.risk.color)

      Image(systemName: TrainerSymbol.chevron)
        .font(TrainerFont.label(11, weight: .bold))
        .foregroundStyle(TrainerColor.tertiaryText)
    }
    .contentShape(Rectangle())
    .padding(.vertical, 10)
  }
}
