import SwiftUI

struct ProductivityTrainerExampleView: View {
  @EnvironmentObject private var store: TrainerStore
  @State private var selectedMode = "진행"
  @State private var isTimerRunning = true
  @State private var selectedDay = 16

  private let modes = ["준비", "진행", "정리", "공유"]

  var body: some View {
    GeometryReader { proxy in
      let usesWideLayout = forceLandscapePreview || proxy.size.width >= 1120

      ScrollView {
        VStack(alignment: .leading, spacing: usesWideLayout ? 18 : 22) {
          iPadHeader
            .trainerLabel("TR-SB-01")
          WorkflowStrip(values: modes, selection: $selectedMode)
            .trainerLabel("TR-SB-02")

          if usesWideLayout {
            landscapeBoard(width: proxy.size.width)
              .trainerLabel("TR-SB-03")
          } else {
            portraitBoard
              .trainerLabel("TR-SB-03")
          }
        }
        .frame(maxWidth: 1240, alignment: .leading)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, usesWideLayout ? 30 : 22)
        .padding(.top, usesWideLayout ? 16 : 20)
        .padding(.bottom, 54)
      }
      .background(ProductivityBackdrop().ignoresSafeArea())
    }
    .navigationTitle("세션 보드")
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        Button("SOAP") {
          store.selectedRoute = .soap
        }
        .foregroundStyle(ProductivityPalette.blue)

        Button("요약") {
          store.selectedRoute = .summary
        }
        .foregroundStyle(ProductivityPalette.purple)
      }
    }
  }

  private var forceLandscapePreview: Bool {
    ProcessInfo.processInfo.arguments.contains("--preview-landscape")
  }

  private func landscapeBoard(width: CGFloat) -> some View {
    HStack(alignment: .top, spacing: 18) {
      VStack(spacing: 18) {
        SessionFocusPanel(
          member: store.selectedMember,
          summary: store.dashboardSummary,
          mode: $selectedMode,
          modes: modes,
          isTimerRunning: $isTimerRunning,
          saveState: store.saveState.label,
          onOpenMember: { store.selectedRoute = .members },
          onOpenSoap: { store.selectedRoute = .soap },
          onSave: { store.saveDraft() }
        )
        .frame(minHeight: 430)
        .trainerLabel("TR-SB-04")

        MetricsRow(summary: store.dashboardSummary, member: store.selectedMember)
          .trainerLabel("TR-SB-08")
      }
      .frame(minWidth: 0, maxWidth: .infinity)

      VStack(spacing: 18) {
        NextActionPanel(
          member: store.selectedMember,
          selectedMode: $selectedMode,
          onOpenSoap: { store.selectedRoute = .soap },
          onOpenMember: { store.selectedRoute = .members },
          onSave: { store.saveDraft() }
        )
        .trainerLabel("TR-SB-09")

        TodayQueuePanel(
          members: store.members,
          selectedMemberID: store.selectedMemberID,
          onSelect: { store.selectMember($0) }
        )
        .trainerLabel("TR-SB-14")

        TrendInsightPanel(member: store.selectedMember)
          .trainerLabel("TR-SB-21")
      }
      .frame(width: min(372, max(320, width * 0.32)))
    }
  }

  private var portraitBoard: some View {
    VStack(spacing: 22) {
      SessionFocusPanel(
        member: store.selectedMember,
        summary: store.dashboardSummary,
        mode: $selectedMode,
        modes: modes,
        isTimerRunning: $isTimerRunning,
        saveState: store.saveState.label,
        onOpenMember: { store.selectedRoute = .members },
        onOpenSoap: { store.selectedRoute = .soap },
        onSave: { store.saveDraft() }
      )
      .trainerLabel("TR-SB-04")

      NextActionPanel(
        member: store.selectedMember,
        selectedMode: $selectedMode,
        onOpenSoap: { store.selectedRoute = .soap },
        onOpenMember: { store.selectedRoute = .members },
        onSave: { store.saveDraft() }
      )
      .trainerLabel("TR-SB-09")

      TodayQueuePanel(
        members: store.members,
        selectedMemberID: store.selectedMemberID,
        onSelect: { store.selectMember($0) }
      )
      .trainerLabel("TR-SB-14")

      MetricsRow(summary: store.dashboardSummary, member: store.selectedMember)
        .trainerLabel("TR-SB-08")
      WorkflowPanel(selectedMode: $selectedMode, member: store.selectedMember)
        .trainerLabel("TR-SB-18")
      CalendarWorkPanel(selectedDay: $selectedDay)
        .trainerLabel("TR-SB-19")
      TrendInsightPanel(member: store.selectedMember)
        .trainerLabel("TR-SB-21")
    }
  }

  private var iPadHeader: some View {
    HStack(alignment: .bottom, spacing: 18) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Trainer workflow")
          .font(TrainerFont.label(15, weight: .bold))
          .foregroundStyle(ProductivityPalette.blue)
        Text("오늘 세션")
          .font(TrainerFont.display(38, weight: .bold))
          .foregroundStyle(TrainerColor.primaryText)
          .tracking(0)
        Text("회원 확인, 세션 진행, SOAP 정리, 공유까지 순서대로 처리합니다.")
          .font(TrainerFont.body(16, weight: .medium))
          .foregroundStyle(TrainerColor.secondaryText)
      }

      Spacer()

      HStack(spacing: 10) {
        StatusCapsule(text: "\(store.dashboardSummary.todaySessionCount) 세션", color: ProductivityPalette.blue)
        StatusCapsule(text: "\(store.dashboardSummary.soapTodoCount) SOAP", color: ProductivityPalette.purple)
        StatusCapsule(text: store.selectedMember.risk.rawValue, color: store.selectedMember.risk.color)
      }
    }
  }
}

private enum ProductivityPalette {
  static let backgroundStart = Color(hex: 0xF8FAFF)
  static let backgroundEnd = Color(hex: 0xEEF5FF)
  static let orange = TrainerColor.purple
  static let purple = TrainerColor.purple
  static let hotOrange = TrainerColor.purple
  static let darkRed = Color(hex: 0x342B58)
  static let blue = TrainerColor.blue
  static let deepBlue = TrainerColor.deepBlue
  static let black = TrainerColor.darkInk
  static let ink = TrainerColor.primaryText
  static let softPanel = TrainerColor.glassPanel
}

private struct ProductivityBackdrop: View {
  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          ProductivityPalette.backgroundStart,
          Color(hex: 0xF2F1FF),
          ProductivityPalette.backgroundEnd,
          Color(hex: 0xE8ECF8)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      RadialGradient(
        colors: [ProductivityPalette.blue.opacity(0.20), .clear],
        center: .center,
        startRadius: 20,
        endRadius: 520
      )
      RadialGradient(
        colors: [ProductivityPalette.orange.opacity(0.12), .clear],
        center: .bottomTrailing,
        startRadius: 20,
        endRadius: 520
      )
    }
  }
}

private struct WorkflowStrip: View {
  let values: [String]
  @Binding var selection: String

  var body: some View {
    HStack(spacing: 10) {
      ForEach(Array(values.enumerated()), id: \.element) { index, value in
        Button {
          selection = value
        } label: {
          HStack(spacing: 9) {
            Text("\(index + 1)")
              .font(TrainerFont.label(12, weight: .bold))
              .foregroundStyle(selection == value ? TrainerColor.inverseText : ProductivityPalette.blue)
              .frame(width: 26, height: 26)
              .background(
                selection == value ? ProductivityPalette.blue : ProductivityPalette.blue.opacity(0.12),
                in: Circle()
              )
            Text(value)
              .font(TrainerFont.label(15, weight: .bold))
              .foregroundStyle(selection == value ? TrainerColor.primaryText : TrainerColor.secondaryText)
          }
          .frame(maxWidth: .infinity)
          .padding(.horizontal, 12)
          .frame(height: 48)
          .background(
            selection == value ? TrainerColor.card.opacity(0.88) : TrainerColor.card.opacity(0.46),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .stroke(selection == value ? ProductivityPalette.blue.opacity(0.38) : TrainerColor.border, lineWidth: 1)
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

private struct NextActionPanel: View {
  let member: TrainerMember
  @Binding var selectedMode: String
  let onOpenSoap: () -> Void
  let onOpenMember: () -> Void
  let onSave: () -> Void

  var body: some View {
    BoardPanel(title: "다음 액션", subtitle: "\(member.name) 세션에서 바로 이어갈 작업입니다.") {
      VStack(spacing: 10) {
        NextActionRow(
          step: "1",
          title: "회원 상태 확인",
          subtitle: "\(member.signal) · 통증 \(member.pain)/10",
          symbol: TrainerSymbol.member,
          active: selectedMode == "준비"
        ) {
          selectedMode = "준비"
          onOpenMember()
        }
        .trainerLabel("TR-SB-10")

        NextActionRow(
          step: "2",
          title: "세션 진행",
          subtitle: "타이머와 Pencil 필기를 유지",
          symbol: TrainerSymbol.pencil,
          active: selectedMode == "진행"
        ) {
          selectedMode = "진행"
        }
        .trainerLabel("TR-SB-11")

        NextActionRow(
          step: "3",
          title: "SOAP 정리",
          subtitle: "S/O/A/P와 ROM/MMT 구조화",
          symbol: TrainerSymbol.soap,
          active: selectedMode == "정리"
        ) {
          selectedMode = "정리"
          onOpenSoap()
        }
        .trainerLabel("TR-SB-12")

        Button {
          onSave()
        } label: {
          Label("현재 상태 저장", systemImage: TrainerSymbol.save)
            .font(TrainerFont.label(15, weight: .bold))
            .foregroundStyle(TrainerColor.inverseText)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(TrainerGradient.actionBlue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
        .trainerLabel("TR-SB-13")
      }
    }
  }
}

private struct NextActionRow: View {
  let step: String
  let title: String
  let subtitle: String
  let symbol: String
  let active: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Text(step)
          .font(TrainerFont.label(13, weight: .bold))
          .foregroundStyle(active ? TrainerColor.inverseText : ProductivityPalette.blue)
          .frame(width: 30, height: 30)
          .background(active ? ProductivityPalette.blue : ProductivityPalette.blue.opacity(0.12), in: Circle())

        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(TrainerFont.label(15, weight: .bold))
            .foregroundStyle(TrainerColor.primaryText)
          Text(subtitle)
            .font(TrainerFont.body(12, weight: .medium))
            .foregroundStyle(TrainerColor.secondaryText)
            .lineLimit(1)
        }

        Spacer()

        Image(systemName: symbol)
          .font(TrainerFont.label(15, weight: .bold))
          .foregroundStyle(active ? ProductivityPalette.blue : TrainerColor.tertiaryText)
      }
      .padding(12)
      .background(
        active ? ProductivityPalette.blue.opacity(0.10) : TrainerColor.quietFill,
        in: RoundedRectangle(cornerRadius: 17, style: .continuous)
      )
    }
    .buttonStyle(.plain)
  }
}

private struct SessionFocusPanel: View {
  let member: TrainerMember
  let summary: TrainerDashboardSummary
  @Binding var mode: String
  let modes: [String]
  @Binding var isTimerRunning: Bool
  let saveState: String
  let onOpenMember: () -> Void
  let onOpenSoap: () -> Void
  let onSave: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(alignment: .top, spacing: 16) {
        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 10) {
            Text("Current Session")
              .font(TrainerFont.label(15, weight: .bold))
              .foregroundStyle(TrainerColor.inverseSecondaryText)
            StatusChip(text: mode, color: TrainerColor.inverseText)
          }

          Text(member.name)
            .font(TrainerFont.display(40, weight: .bold))
            .foregroundStyle(TrainerColor.inverseText)
            .lineLimit(1)
            .minimumScaleFactor(0.72)

          Text(member.subtitle)
            .font(TrainerFont.body(17, weight: .semibold))
            .foregroundStyle(TrainerColor.inverseSecondaryText)
        }

        Spacer()

        TrainerAvatar(member: member, size: 58)
      }

      HStack(alignment: .center, spacing: 24) {
        VStack(alignment: .leading, spacing: 10) {
          Text(isTimerRunning ? "진행 시간" : "일시 정지")
            .font(TrainerFont.label(14, weight: .bold))
            .foregroundStyle(TrainerColor.inverseTertiaryText)
          Text(isTimerRunning ? "02:23:42" : "02:23:42")
            .font(TrainerFont.display(46, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(TrainerColor.inverseText)
            .lineLimit(1)
            .minimumScaleFactor(0.48)
        }
        .frame(minWidth: 230, maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)

        Spacer()

        VStack(spacing: 10) {
          CircleProgress(value: Double(member.progress) / 100, color: TrainerColor.inverseText)
            .frame(width: 104, height: 104)
          Text("목표 \(member.progress)%")
            .font(TrainerFont.label(14, weight: .bold))
            .foregroundStyle(TrainerColor.inverseSecondaryText)
        }
      }

      HStack(spacing: 12) {
        PrimaryBoardButton(
          title: isTimerRunning ? "일시정지" : "시작",
          symbol: isTimerRunning ? TrainerSymbol.pause : TrainerSymbol.play,
          foreground: ProductivityPalette.black,
          background: TrainerColor.inverseText
        ) {
          isTimerRunning.toggle()
        }
        .trainerLabel("TR-SB-05")

        PrimaryBoardButton(
          title: "SOAP 작성",
          symbol: TrainerSymbol.soap,
          foreground: TrainerColor.inverseText,
          background: TrainerColor.inverseControlFill,
          action: onOpenSoap
        )
        .trainerLabel("TR-SB-06")

        PrimaryBoardButton(
          title: saveState,
          symbol: TrainerSymbol.save,
          foreground: TrainerColor.inverseText,
          background: TrainerColor.inverseControlFill,
          action: onSave
        )
        .trainerLabel("TR-SB-07")
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 12)], spacing: 12) {
        SessionMiniStat(title: "통증", value: "\(member.pain)/10", color: member.risk.color)
          .trainerLabel("TR-SB-04-STAT-1")
        SessionMiniStat(title: "오늘", value: "\(summary.completedSessionCount)/\(summary.plannedSessionCount)", color: ProductivityPalette.blue)
          .trainerLabel("TR-SB-04-STAT-2")
        SessionMiniStat(title: "마지막 SOAP", value: member.lastSoap, color: ProductivityPalette.orange)
          .trainerLabel("TR-SB-04-STAT-3")
        Button {
          onOpenMember()
        } label: {
          Label("회원 상세", systemImage: TrainerSymbol.member)
            .font(TrainerFont.label(14, weight: .bold))
            .foregroundStyle(TrainerColor.inverseText)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(TrainerColor.inverseControlFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .trainerLabel("TR-SB-04-DETAIL")
      }
    }
    .padding(24)
    .frame(minHeight: 450, alignment: .topLeading)
    .background {
      ZStack {
        LinearGradient(
          colors: [ProductivityPalette.deepBlue, ProductivityPalette.blue],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        RadialGradient(
          colors: [TrainerColor.inverseText.opacity(0.20), .clear],
          center: .topTrailing,
          startRadius: 20,
          endRadius: 340
        )
        RadialGradient(
          colors: [ProductivityPalette.hotOrange.opacity(0.18), .clear],
          center: .bottomLeading,
          startRadius: 20,
          endRadius: 360
        )
      }
      .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    }
    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    .shadow(color: ProductivityPalette.blue.opacity(0.22), radius: 34, x: 0, y: 18)
  }
}

private struct TodayQueuePanel: View {
  let members: [TrainerMember]
  let selectedMemberID: String
  let onSelect: (TrainerMember) -> Void

  var body: some View {
    BoardPanel(title: "오늘 볼 회원", subtitle: "터치하면 현재 세션이 전환됩니다.") {
      VStack(spacing: 10) {
        ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
          Button {
            onSelect(member)
          } label: {
            QueueMemberRow(member: member, selected: selectedMemberID == member.id)
              .trainerLabel("TR-SB-15-\(index + 1)")
          }
          .buttonStyle(.plain)
        }
      }
    }
  }
}

private struct QueueMemberRow: View {
  let member: TrainerMember
  let selected: Bool

  var body: some View {
    HStack(spacing: 12) {
      TrainerAvatar(member: member, size: 42)

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 7) {
          Text(member.name)
            .font(TrainerFont.label(16, weight: .bold))
            .foregroundStyle(TrainerColor.primaryText)
          StatusChip(text: member.risk.rawValue, color: member.risk.color)
        }
        Text(member.signal)
          .font(TrainerFont.body(13, weight: .medium))
          .foregroundStyle(TrainerColor.secondaryText)
          .lineLimit(1)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 5) {
        Text("\(member.pain)/10")
          .font(TrainerFont.label(15, weight: .bold))
          .foregroundStyle(member.risk.color)
        ProgressView(value: Double(member.progress), total: 100)
          .tint(ProductivityPalette.blue)
          .frame(width: 70)
      }
    }
    .padding(12)
    .background(
      selected ? ProductivityPalette.blue.opacity(0.10) : TrainerColor.quietFill,
      in: RoundedRectangle(cornerRadius: 18, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(selected ? ProductivityPalette.blue.opacity(0.55) : Color.clear, lineWidth: 1)
    )
  }
}

private struct SoapQuickPanel: View {
  let draft: SoapDraft
  let member: TrainerMember
  let onOpenSoap: () -> Void
  let onSave: () -> Void

  var body: some View {
    BoardPanel(title: "SOAP 정리", subtitle: "\(member.name) · \(draft.workflow.status.rawValue)") {
      VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 10) {
          QuickMetricChip(title: "S/O/P", value: "\(draft.completedCategoryCount)/4", color: ProductivityPalette.orange)
          QuickMetricChip(title: "통증", value: "\(Int(draft.pain))/10", color: member.risk.color)
        }

        VStack(alignment: .leading, spacing: 8) {
          Text("다음 계획")
            .font(TrainerFont.label(13, weight: .bold))
            .foregroundStyle(TrainerColor.secondaryText)
          Text(draft.plan)
            .font(TrainerFont.body(15, weight: .semibold))
            .foregroundStyle(TrainerColor.primaryText)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
        }

        HStack(spacing: 10) {
          Button {
            onOpenSoap()
          } label: {
            Label("열기", systemImage: TrainerSymbol.openDocument)
              .boardSecondaryButton()
          }
          .buttonStyle(.plain)

          Button {
            onSave()
          } label: {
            Label("저장", systemImage: TrainerSymbol.confirm)
              .boardSecondaryButton()
          }
          .buttonStyle(.plain)
        }
      }
    }
  }
}

private struct MetricsRow: View {
  let summary: TrainerDashboardSummary
  let member: TrainerMember

  var body: some View {
    LazyVGrid(
      columns: [
        GridItem(.adaptive(minimum: 210), spacing: 16)
      ],
      alignment: .leading,
      spacing: 16
    ) {
      BoardMetricTile(title: "오늘 세션", value: "\(summary.completedSessionCount)/\(summary.plannedSessionCount)", footnote: "\(summary.todaySessionCount)개 예약", symbol: TrainerSymbol.calendar, color: ProductivityPalette.blue, label: "TR-SB-08-1")
      BoardMetricTile(title: "SOAP 미완료", value: "\(summary.soapTodoCount)", footnote: "세션 후 정리 필요", symbol: TrainerSymbol.soap, color: ProductivityPalette.purple, label: "TR-SB-08-2")
      BoardMetricTile(title: "평균 통증", value: String(format: "%.1f", summary.averagePain), footnote: "현재 회원 \(member.pain)/10", symbol: TrainerSymbol.pain, color: TrainerColor.purple, label: "TR-SB-08-3")
      BoardMetricTile(title: "목표 안정", value: "\(summary.stableGoalPercent)%", footnote: "홈운동 \(summary.homeExercisePercent)%", symbol: TrainerSymbol.target, color: TrainerColor.deepBlue, label: "TR-SB-08-4")
    }
  }
}

private struct CalendarWorkPanel: View {
  @Binding var selectedDay: Int
  private let days = Array(12...18)

  var body: some View {
    BoardPanel(title: "주간 캘린더", subtitle: "세션 밀도와 정리 타이밍을 함께 봅니다.") {
      VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 8) {
          ForEach(Array(days.enumerated()), id: \.element) { index, day in
            Button {
              selectedDay = day
            } label: {
              VStack(spacing: 8) {
                Text(weekday(for: day))
                  .font(TrainerFont.label(11, weight: .bold))
                  .foregroundStyle(selectedDay == day ? TrainerColor.inverseSecondaryText : TrainerColor.secondaryText)
                Text("\(day)")
                  .font(TrainerFont.display(18, weight: .bold))
                  .foregroundStyle(selectedDay == day ? TrainerColor.inverseText : TrainerColor.primaryText)
                Capsule()
                  .fill(selectedDay == day ? TrainerColor.inverseText : ProductivityPalette.orange.opacity(0.55))
                  .frame(width: 18, height: 4)
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 13)
              .background(
                selectedDay == day ? ProductivityPalette.darkRed : TrainerColor.quietFill,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
              )
            }
            .buttonStyle(.plain)
            .trainerLabel("TR-SB-19-DAY-\(index + 1)")
          }
        }

        VStack(spacing: 10) {
          CalendarTaskRow(time: "08:30", title: "움직임 재평가", subtitle: "ROM/MMT 입력", color: ProductivityPalette.purple, label: "TR-SB-20-1")
          CalendarTaskRow(time: "11:00", title: "개인 PT 세션", subtitle: "Pencil 기록 후 SOAP 정리", color: ProductivityPalette.blue, label: "TR-SB-20-2")
          CalendarTaskRow(time: "16:30", title: "공유 리포트 확인", subtitle: "회원 앱 공유 전 검토", color: TrainerColor.deepBlue, label: "TR-SB-20-3")
        }
      }
    }
  }

  private func weekday(for day: Int) -> String {
    switch day {
    case 12: return "금"
    case 13: return "토"
    case 14: return "일"
    case 15: return "월"
    case 16: return "화"
    case 17: return "수"
    default: return "목"
    }
  }
}

private struct WorkflowPanel: View {
  @Binding var selectedMode: String
  let member: TrainerMember

  private let steps: [(String, String, String, Color)] = [
    ("준비", "최근 통증, 목표, 위험도를 확인합니다.", TrainerSymbol.prepare, ProductivityPalette.blue),
    ("진행", "세션 타이머와 큐를 유지합니다.", TrainerSymbol.timer, ProductivityPalette.purple),
    ("정리", "S/O/A/P와 검사값을 구조화합니다.", TrainerSymbol.soap, TrainerColor.deepBlue),
    ("공유", "회원에게 보여줄 요약만 분리합니다.", TrainerSymbol.share, TrainerColor.purple)
  ]

  var body: some View {
    BoardPanel(title: "워크플로우", subtitle: "\(member.name)의 현재 단계") {
      VStack(spacing: 10) {
        ForEach(Array(steps.enumerated()), id: \.element.0) { index, step in
          Button {
            selectedMode = step.0
          } label: {
            HStack(spacing: 12) {
              Image(systemName: step.2)
                .font(TrainerFont.label(15, weight: .bold))
                .foregroundStyle(selectedMode == step.0 ? TrainerColor.inverseText : step.3)
                .frame(width: 36, height: 36)
                .background(
                  selectedMode == step.0 ? step.3 : step.3.opacity(0.12),
                  in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

              VStack(alignment: .leading, spacing: 3) {
                Text(step.0)
                  .font(TrainerFont.label(16, weight: .bold))
                  .foregroundStyle(TrainerColor.primaryText)
                Text(step.1)
                  .font(TrainerFont.body(13, weight: .medium))
                  .foregroundStyle(TrainerColor.secondaryText)
                  .lineLimit(2)
              }

              Spacer()

              if selectedMode == step.0 {
                Image(systemName: TrainerSymbol.confirm)
                  .foregroundStyle(step.3)
              }
            }
            .padding(12)
            .background(
              selectedMode == step.0 ? step.3.opacity(0.10) : TrainerColor.quietFill,
              in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
          }
          .buttonStyle(.plain)
          .trainerLabel("TR-SB-18-\(index + 1)")
        }
      }
    }
  }
}

private struct TrendInsightPanel: View {
  let member: TrainerMember

  var body: some View {
    BoardPanel(title: "시각화", subtitle: "통증과 목표 진행을 빠르게 판단합니다.") {
      VStack(alignment: .leading, spacing: 18) {
        MiniTrendChart(values: member.painSeries, color: TrainerColor.purple)
          .frame(height: 126)

        HStack(spacing: 12) {
          QuickMetricChip(title: "통증", value: "\(member.pain)/10", color: TrainerColor.purple)
          QuickMetricChip(title: "목표", value: "\(member.progress)%", color: ProductivityPalette.blue)
        }

        Text(member.nextPlan)
          .font(TrainerFont.body(15, weight: .semibold))
          .foregroundStyle(TrainerColor.primaryText)
          .lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

private struct BoardPanel<Content: View>: View {
  let title: String
  let subtitle: String
  let label: String?
  let content: Content

  init(title: String, subtitle: String, label: String? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.subtitle = subtitle
    self.label = label
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(TrainerFont.title(22, weight: .bold))
          .foregroundStyle(TrainerColor.primaryText)
        Text(subtitle)
          .font(TrainerFont.body(14, weight: .medium))
          .foregroundStyle(TrainerColor.secondaryText)
          .lineLimit(2)
      }

      content
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(
      ProductivityPalette.softPanel,
      in: RoundedRectangle(cornerRadius: 26, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 26, style: .continuous)
        .stroke(TrainerColor.border, lineWidth: 1)
    )
    .shadow(color: Color.black.opacity(0.065), radius: 22, x: 0, y: 12)
    .trainerLabel(label ?? "TR-SB-PANEL-\(title)")
  }
}

private struct BoardMetricTile: View {
  let title: String
  let value: String
  let footnote: String
  let symbol: String
  let color: Color
  let label: String?

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: symbol)
        .font(TrainerFont.label(18, weight: .bold))
        .foregroundStyle(color)
        .frame(width: 44, height: 44)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

      VStack(alignment: .leading, spacing: 7) {
        Text(title)
          .font(TrainerFont.label(14, weight: .bold))
          .foregroundStyle(color)
        Text(value)
          .font(TrainerFont.display(31, weight: .bold))
          .foregroundStyle(TrainerColor.primaryText)
          .lineLimit(1)
          .minimumScaleFactor(0.72)
        Text(footnote)
          .font(TrainerFont.body(13, weight: .medium))
          .foregroundStyle(TrainerColor.secondaryText)
          .lineLimit(1)
      }

      Spacer(minLength: 0)
    }
    .padding(18)
    .background(TrainerColor.card.opacity(0.82), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(TrainerColor.border, lineWidth: 1)
    )
    .trainerLabel(label)
  }
}

private struct CalendarTaskRow: View {
  let time: String
  let title: String
  let subtitle: String
  let color: Color
  let label: String?

  var body: some View {
    HStack(spacing: 12) {
      Text(time)
        .font(TrainerFont.label(15, weight: .bold))
        .monospacedDigit()
        .foregroundStyle(color)
        .frame(width: 58, alignment: .leading)

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(TrainerFont.label(15, weight: .bold))
          .foregroundStyle(TrainerColor.primaryText)
        Text(subtitle)
          .font(TrainerFont.body(13, weight: .medium))
          .foregroundStyle(TrainerColor.secondaryText)
      }

      Spacer()
    }
    .padding(12)
    .background(TrainerColor.card.opacity(0.62), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .trainerLabel(label)
  }
}

private struct BoardSegmentedControl: View {
  let values: [String]
  @Binding var selection: String

  var body: some View {
    HStack(spacing: 4) {
      ForEach(values, id: \.self) { value in
        Button {
          selection = value
        } label: {
          Text(value)
            .font(TrainerFont.label(14, weight: .bold))
            .foregroundStyle(selection == value ? ProductivityPalette.black : TrainerColor.inverseSecondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
              selection == value ? TrainerColor.inverseText : Color.clear,
              in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
        }
        .buttonStyle(.plain)
      }
    }
    .padding(4)
    .background(TrainerColor.darkInk.opacity(0.18), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
  }
}

private struct PrimaryBoardButton: View {
  let title: String
  let symbol: String
  let foreground: Color
  let background: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(title, systemImage: symbol)
        .font(TrainerFont.label(15, weight: .bold))
        .foregroundStyle(foreground)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    .buttonStyle(.plain)
  }
}

private struct SessionMiniStat: View {
  let title: String
  let value: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(TrainerFont.label(12, weight: .bold))
        .foregroundStyle(TrainerColor.inverseTertiaryText)
      Text(value)
        .font(TrainerFont.display(16, weight: .bold))
        .foregroundStyle(TrainerColor.inverseText)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.22), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

private struct QuickMetricChip: View {
  let title: String
  let value: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title)
        .font(TrainerFont.label(12, weight: .bold))
        .foregroundStyle(TrainerColor.secondaryText)
      Text(value)
        .font(TrainerFont.display(19, weight: .bold))
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
    .padding(.horizontal, 13)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

private struct StatusChip: View {
  let text: String
  let color: Color

  var body: some View {
    Text(text)
      .font(TrainerFont.label(11, weight: .bold))
      .foregroundStyle(color)
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(color.opacity(0.14), in: Capsule())
  }
}

private struct CircleProgress: View {
  let value: Double
  let color: Color

  var body: some View {
    ZStack {
      Circle()
        .stroke(TrainerColor.inverseText.opacity(0.22), lineWidth: 12)
      Circle()
        .trim(from: 0, to: min(max(value, 0), 1))
        .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
        .rotationEffect(.degrees(-90))
      Text("\(Int(value * 100))%")
        .font(TrainerFont.display(22, weight: .bold))
        .foregroundStyle(TrainerColor.inverseText)
    }
  }
}

private struct MiniTrendChart: View {
  let values: [Double]
  let color: Color

  var body: some View {
    GeometryReader { proxy in
      let normalized = normalizedValues
      let inset: CGFloat = 16
      let plotWidth = max(proxy.size.width - inset * 2, 1)
      let plotHeight = max(proxy.size.height - inset * 2, 1)
      let points = normalized.enumerated().map { index, value in
        CGPoint(
          x: inset + CGFloat(index) / CGFloat(max(normalized.count - 1, 1)) * plotWidth,
          y: inset + (1 - value) * plotHeight
        )
      }

      ZStack {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(TrainerColor.card.opacity(0.58))

        VStack(spacing: 0) {
          ForEach(0..<3, id: \.self) { index in
            Rectangle()
              .fill(TrainerColor.border.opacity(index == 1 ? 0.72 : 0.42))
              .frame(height: 1)
            if index < 2 {
              Spacer(minLength: 0)
            }
          }
        }
        .padding(.horizontal, inset)
        .padding(.vertical, inset)

        Path { path in
          for index in points.indices {
            if index == 0 {
              path.move(to: points[index])
            } else {
              path.addLine(to: points[index])
            }
          }
        }
        .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

        ForEach(points.indices, id: \.self) { index in
          Circle()
            .fill(color)
            .frame(width: index == points.indices.last ? 10 : 7, height: index == points.indices.last ? 10 : 7)
            .position(points[index])
        }

        if let lastPoint = points.last, let lastValue = values.last {
          Text(String(format: "%.1f", lastValue))
            .font(TrainerFont.label(11, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(TrainerColor.card.opacity(0.86), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.24), lineWidth: 1))
            .position(x: min(max(lastPoint.x + 28, 38), proxy.size.width - 34), y: max(lastPoint.y - 18, 18))
        }
      }
    }
  }

  private var normalizedValues: [Double] {
    guard let minValue = values.min(), let maxValue = values.max(), maxValue > minValue else {
      return values.map { _ in 0.5 }
    }
    return values.map { ($0 - minValue) / (maxValue - minValue) }
  }
}

private extension View {
  func boardSecondaryButton() -> some View {
    self
      .font(TrainerFont.label(14, weight: .bold))
      .foregroundStyle(ProductivityPalette.ink)
      .frame(maxWidth: .infinity)
      .frame(height: 44)
      .background(TrainerColor.card.opacity(0.70), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
  }
}
