import SwiftUI

struct ReportsView: View {
  @EnvironmentObject private var store: TrainerStore

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          hero
            .trainerLabel("TR-RPT-01")
          metricGrid
            .trainerLabel("TR-RPT-02")

          if geometry.size.width >= 980 {
            HStack(alignment: .top, spacing: 18) {
              reportChart
                .trainerLabel("TR-RPT-06")
              trendList
                .frame(width: 360)
                .trainerLabel("TR-RPT-08")
            }
          } else {
            reportChart
              .trainerLabel("TR-RPT-06")
            trendList
              .trainerLabel("TR-RPT-08")
          }
        }
        .padding(32)
        .frame(maxWidth: 1180, alignment: .topLeading)
      }
    }
    .background(StudioBackdrop().ignoresSafeArea())
  }

  private var hero: some View {
    StudioHeroCard(label: "TR-RPT-01") {
      HStack(alignment: .bottom) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Center Analytics")
            .font(TrainerFont.label(15, weight: .bold))
            .foregroundStyle(TrainerColor.inverseSecondaryText)
          Text("리포트")
            .font(TrainerFont.display(42, weight: .bold))
            .foregroundStyle(TrainerColor.inverseText)
          Text("통증, SOAP 완료율, 재평가 대상을 분리해서 봅니다.")
            .font(TrainerFont.body(15, weight: .medium))
            .foregroundStyle(TrainerColor.inverseSecondaryText)
        }
        Spacer()
        StatusCapsule(text: "SOAP \(store.dashboardSummary.soapCompletionPercent)%", color: TrainerColor.inverseText)
      }
    }
  }

  private var metricGrid: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 14)], spacing: 14) {
      HealthFavoriteTile(title: "평균 통증", value: String(format: "%.1f", store.averagePain), unit: "/10", symbol: TrainerSymbol.pain, color: TrainerColor.deepBlue, footnote: "최근 7일", label: "TR-RPT-03")
      HealthFavoriteTile(title: "재평가 필요", value: "\(store.dashboardSummary.attentionMemberCount)", unit: "명", symbol: TrainerSymbol.warning, color: TrainerColor.purple, footnote: "주의 회원", label: "TR-RPT-04")
      HealthFavoriteTile(title: "목표 안정", value: "\(store.dashboardSummary.stableGoalPercent)", unit: "%", symbol: TrainerSymbol.target, color: TrainerColor.blue, footnote: "전체 평균", label: "TR-RPT-05")
    }
  }

  private var reportChart: some View {
    VStack(alignment: .leading, spacing: 12) {
      HealthSectionHeader(title: "센터 변화", label: "TR-RPT-06")
      HealthCard {
        VStack(alignment: .leading, spacing: 18) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
              Text("통증과 기록 품질을 따로 읽습니다")
                .font(TrainerFont.title(24, weight: .bold))
                .foregroundStyle(TrainerColor.primaryText)
              Text("통증은 0-10, 완료율은 0-100 기준이라 같은 축에 섞지 않습니다.")
                .font(TrainerFont.body(15, weight: .medium))
                .foregroundStyle(TrainerColor.secondaryText)
            }
            Spacer()
            Image(systemName: TrainerSymbol.reports)
              .font(TrainerFont.title(22, weight: .bold))
              .foregroundStyle(TrainerColor.blue)
              .frame(width: 46, height: 46)
              .background(TrainerColor.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          }

          ClinicalReportChart(
            painPoints: store.dashboardSummary.painTrend,
            completionPoints: store.dashboardSummary.completionTrend
          )
        }
      }
      .trainerLabel("TR-RPT-07")
    }
  }

  private var trendList: some View {
    VStack(alignment: .leading, spacing: 12) {
      HealthSectionHeader(title: "관리 큐", label: "TR-RPT-08")
      HealthCard(padding: 14) {
        VStack(spacing: 0) {
          ForEach(Array(store.dashboardSummary.trends.enumerated()), id: \.element.id) { index, trend in
            HealthTrendRow(title: trend.title, subtitle: trend.subtitle, symbol: trend.symbol, color: trend.accent.color, value: trend.value, label: "TR-RPT-09-\(index + 1)")
            if trend.id != store.dashboardSummary.trends.last?.id {
              Divider()
            }
          }
        }
      }
      .trainerLabel("TR-RPT-09")

      HealthCard(padding: 18) {
        VStack(alignment: .leading, spacing: 10) {
          Text("해석 기준")
            .font(TrainerFont.title(19, weight: .bold))
            .foregroundStyle(TrainerColor.primaryText)
          ReportGuideRow(title: "통증 6 이상", caption: "다음 세션 전 확인", label: "TR-RPT-11")
          ReportGuideRow(title: "SOAP 80% 미만", caption: "기록 품질 우선 정리", label: "TR-RPT-12")
          ReportGuideRow(title: "목표 70% 미만", caption: "홈운동 계획 재조정", label: "TR-RPT-13")
        }
      }
      .trainerLabel("TR-RPT-10")
    }
  }
}

private struct ReportGuideRow: View {
  let title: String
  let caption: String
  let label: String?

  var body: some View {
    HStack(spacing: 10) {
      Circle()
        .fill(TrainerColor.blue)
        .frame(width: 7, height: 7)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(TrainerFont.label(14, weight: .bold))
          .foregroundStyle(TrainerColor.primaryText)
        Text(caption)
          .font(TrainerFont.body(12, weight: .medium))
          .foregroundStyle(TrainerColor.secondaryText)
      }
      Spacer()
    }
    .trainerLabel(label)
  }
}
