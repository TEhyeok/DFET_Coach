import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var store: TrainerStore

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        StudioHeroCard(label: "TR-SET-01") {
          HStack {
            VStack(alignment: .leading, spacing: 8) {
              Text("Trainer Studio")
                .font(TrainerFont.label(15, weight: .bold))
                .foregroundStyle(TrainerColor.inverseSecondaryText)
              Text("설정")
                .font(TrainerFont.display(42, weight: .bold))
                .foregroundStyle(TrainerColor.inverseText)
              Text(store.trainerName)
                .font(TrainerFont.body(15, weight: .medium))
                .foregroundStyle(TrainerColor.inverseSecondaryText)
            }
            Spacer()
            Image(systemName: TrainerSymbol.settings)
              .font(TrainerFont.title(24, weight: .bold))
              .foregroundStyle(TrainerColor.darkInk)
              .frame(width: 56, height: 56)
              .background(TrainerColor.inverseText, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
          }
        }

        HealthCard {
          VStack(spacing: 0) {
            SettingsRow(title: "앱 모드", value: "SwiftUI 네이티브", label: "TR-SET-03")
            Divider()
            SettingsRow(title: "기록 방식", value: "Pencil + SOAP", label: "TR-SET-04")
            Divider()
            SettingsRow(title: "데이터 연동", value: "Repository 교체 준비", label: "TR-SET-05")
          }
        }
        .trainerLabel("TR-SET-02")

        HealthCard {
          VStack(spacing: 0) {
            SettingsRow(title: "SOAP 템플릿", value: "PT 확장형", label: "TR-SET-07")
            Divider()
            SettingsRow(title: "회원 공유", value: "요약만 공유", label: "TR-SET-08")
            Divider()
            SettingsRow(title: "필기 원본", value: "트레이너 내부 보관", label: "TR-SET-09")
          }
        }
        .trainerLabel("TR-SET-06")

        HealthCard {
          VStack(spacing: 0) {
            SettingsRow(title: "위젯 데이터", value: "App Group Snapshot", label: "TR-SET-11")
            Divider()
            SettingsRow(title: "오늘 세션", value: "\(store.dashboardSummary.todaySessionCount)건", label: "TR-SET-12")
            Divider()
            SettingsRow(title: "SOAP 미완료", value: "\(store.dashboardSummary.soapTodoCount)건", label: "TR-SET-13")
            Divider()
            SettingsRow(title: "재평가 필요", value: "\(store.dashboardSummary.attentionMemberCount)명", label: "TR-SET-14")
          }
        }
        .trainerLabel("TR-SET-10")

        Button {
          store.refreshWidgetSnapshot()
        } label: {
          Label("위젯 데이터 새로고침", systemImage: TrainerSymbol.refresh)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(TrainerPrimaryButtonStyle())
        .trainerLabel("TR-SET-15")

        Button(role: .destructive) {
          store.signOut()
        } label: {
          Label("로그아웃", systemImage: TrainerSymbol.signOut)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(TrainerDestructiveButtonStyle())
        .trainerLabel("TR-SET-16")
      }
      .padding(32)
      .frame(maxWidth: 820, alignment: .topLeading)
    }
    .background(StudioBackdrop().ignoresSafeArea())
  }
}

private struct SettingsRow: View {
  let title: String
  let value: String
  let label: String?

  var body: some View {
    HStack {
      Text(title)
        .font(TrainerFont.label(16, weight: .semibold))
        .foregroundStyle(TrainerColor.primaryText)
      Spacer()
      Text(value)
        .font(TrainerFont.body(16, weight: .medium))
        .foregroundStyle(TrainerColor.secondaryText)
    }
    .padding(.vertical, 12)
    .trainerLabel(label)
  }
}
