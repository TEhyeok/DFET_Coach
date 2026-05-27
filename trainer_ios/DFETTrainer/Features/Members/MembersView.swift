import SwiftUI

struct MembersView: View {
  @EnvironmentObject private var store: TrainerStore
  @State private var showingShareReport = false

  var body: some View {
    GeometryReader { geometry in
      if geometry.size.width < 900 {
        ScrollView {
          VStack(alignment: .leading, spacing: 18) {
            memberPicker
              .trainerLabel("TR-MBR-01")
            memberDetail
              .trainerLabel("TR-MBR-04")
          }
          .padding(24)
        }
        .background(StudioBackdrop().ignoresSafeArea())
      } else {
        HStack(spacing: 0) {
          memberList
            .frame(width: 336)
            .trainerLabel("TR-MBR-02")
          ScrollView {
            memberDetail
              .padding(32)
              .trainerLabel("TR-MBR-04")
          }
          .background(StudioBackdrop().ignoresSafeArea())
        }
      }
    }
    .alert("공유 리포트", isPresented: $showingShareReport) {
      Button("확인", role: .cancel) {}
    } message: {
      Text("\(store.selectedMember.name) 회원에게 전달할 요약 리포트 화면을 준비했습니다.")
    }
  }

  private var memberPicker: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(store.members) { member in
          memberChip(member)
            .frame(width: 224)
        }
      }
    }
  }

  private var memberList: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        VStack(alignment: .leading, spacing: 4) {
          Text("회원")
            .font(TrainerFont.title(30, weight: .bold))
            .foregroundStyle(TrainerColor.primaryText)
          Text("최근 SOAP 기준")
            .font(TrainerFont.body(13, weight: .medium))
            .foregroundStyle(TrainerColor.secondaryText)
        }
        .padding(.horizontal, 4)

        HealthCard(padding: 14) {
          VStack(spacing: 0) {
            ForEach(Array(store.members.enumerated()), id: \.element.id) { index, member in
              memberChip(member)
                .trainerLabel("TR-MBR-03-\(index + 1)")
              if member.id != store.members.last?.id {
                Divider()
              }
            }
          }
        }
      }
      .padding(18)
    }
    .background(StudioBackdrop().ignoresSafeArea())
  }

  private func memberChip(_ member: TrainerMember) -> some View {
    let selected = member.id == store.selectedMemberID
    return Button {
      store.selectMember(member)
    } label: {
      HStack(spacing: 12) {
        TrainerAvatar(member: member, size: 44)
        VStack(alignment: .leading, spacing: 4) {
          Text(member.name)
            .font(TrainerFont.label(16, weight: .semibold))
            .foregroundStyle(TrainerColor.primaryText)
          Text(member.signal)
            .font(TrainerFont.body(13))
            .foregroundStyle(TrainerColor.secondaryText)
        }
        Spacer()
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity)
      .background(
        selected ? TrainerColor.blue.opacity(0.10) : Color.clear,
        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
      )
    }
    .buttonStyle(.plain)
  }

  private var memberDetail: some View {
    VStack(alignment: .leading, spacing: 22) {
      memberHeader
        .trainerLabel("TR-MBR-05")

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 14)], spacing: 14) {
        HealthFavoriteTile(
          title: "통증",
          value: "\(store.selectedMember.pain)",
          unit: "/10",
          symbol: TrainerSymbol.pain,
          color: store.selectedMember.risk.color,
          footnote: store.selectedMember.signal,
          label: "TR-MBR-06"
        )
        HealthFavoriteTile(
          title: "목표 진행",
          value: "\(store.selectedMember.progress)",
          unit: "%",
          symbol: TrainerSymbol.target,
          color: TrainerColor.blue,
          footnote: "계획 대비",
          label: "TR-MBR-07"
        )
        HealthFavoriteTile(
          title: "최근 SOAP",
          value: store.selectedMember.lastSoap,
          unit: "",
          symbol: TrainerSymbol.soap,
          color: TrainerColor.blue,
          footnote: store.selectedMember.region,
          label: "TR-MBR-08"
        )
      }
      .trainerLabel("TR-MBR-06-GRID")

      VStack(alignment: .leading, spacing: 12) {
        HealthSectionHeader(title: "하이라이트", label: "TR-MBR-09")
        HealthCard {
          VStack(alignment: .leading, spacing: 14) {
            Text("통증 / 목표 변화")
              .font(TrainerFont.title(23, weight: .bold))
              .foregroundStyle(TrainerColor.primaryText)
            PainCompletionChart(
              painPoints: store.selectedMember.painSeries,
              completionPoints: store.selectedMember.completionSeries,
              secondaryTitle: "목표 진행"
            )
            .frame(height: 320)
            HStack(spacing: 16) {
              LegendDot(label: "통증", color: TrainerColor.purple)
              LegendDot(label: "목표 진행", color: TrainerColor.blue)
            }
          }
        }
        .trainerLabel("TR-MBR-10")
      }

      VStack(alignment: .leading, spacing: 12) {
        HealthSectionHeader(title: "다음 세션", label: "TR-MBR-11")
        HealthCard {
          VStack(alignment: .leading, spacing: 12) {
            HealthTrendRow(
              title: "진행 메모",
              subtitle: store.selectedMember.nextPlan,
              symbol: TrainerSymbol.checkedList,
              color: TrainerColor.deepBlue,
              value: "확인",
              label: "TR-MBR-12"
            )
          Text(store.selectedMember.nextPlan)
            .font(TrainerFont.body(16))
            .foregroundStyle(TrainerColor.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
          }
        }
        .trainerLabel("TR-MBR-13")
      }
    }
  }

  private var memberHeader: some View {
    StudioHeroCard {
      HStack(spacing: 16) {
        TrainerAvatar(member: store.selectedMember, size: 66)

        VStack(alignment: .leading, spacing: 4) {
          Text(store.selectedMember.name)
            .font(TrainerFont.display(34, weight: .bold))
            .foregroundStyle(TrainerColor.inverseText)
          Text(store.selectedMember.subtitle)
            .font(TrainerFont.body(15, weight: .medium))
            .foregroundStyle(TrainerColor.inverseSecondaryText)
        }

        Spacer()

        Button {
          store.selectedRoute = .soap
        } label: {
          Label("SOAP", systemImage: TrainerSymbol.soap)
            .font(TrainerFont.label(15, weight: .bold))
            .foregroundStyle(TrainerColor.inverseText)
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(TrainerGradient.actionBlue, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
        .trainerLabel("TR-MBR-14")

        Button {
          showingShareReport = true
        } label: {
          Image(systemName: TrainerSymbol.share)
            .foregroundStyle(TrainerColor.inverseText)
            .frame(width: 32, height: 32)
            .background(TrainerColor.inverseControlFill, in: Circle())
        }
        .buttonStyle(.plain)
        .trainerLabel("TR-MBR-15")
      }
    }
  }
}
