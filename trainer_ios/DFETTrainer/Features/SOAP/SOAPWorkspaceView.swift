import PencilKit
import SwiftUI

struct SOAPWorkspaceView: View {
  @EnvironmentObject private var store: TrainerStore
  @FocusState private var isTextInputFocused: Bool
  @State private var selectedMode = "SOAP"
  @State private var selectedSoap = "S"
  @State private var selectedTool = "pen"
  @State private var undoSignal = 0
  @State private var drawing = PKDrawing()
  @State private var showingDeleteConfirmation = false

  var body: some View {
    GeometryReader { geometry in
      if usesCompactLayout(for: geometry.size) {
      VStack(spacing: 0) {
        workspace
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .trainerLabel("TR-SOAP-02")
        Divider()
        inspector
            .frame(height: min(390, geometry.size.height * 0.38))
            .trainerLabel("TR-SOAP-14")
        }
      } else {
        HStack(spacing: 0) {
          sessionQueue
            .frame(width: 292)
            .trainerLabel("TR-SOAP-01")
          Divider()
          workspace
            .trainerLabel("TR-SOAP-02")
          Divider()
          inspector
            .frame(width: 310)
            .trainerLabel("TR-SOAP-14")
        }
      }
    }
    .background(StudioBackdrop().ignoresSafeArea())
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("완료") {
          isTextInputFocused = false
        }
      }
    }
    .alert("SOAP 기록을 삭제할까요?", isPresented: $showingDeleteConfirmation) {
      Button("삭제", role: .destructive) {
        store.deleteSelectedNote()
        drawing = PKDrawing()
      }
      Button("취소", role: .cancel) {}
    } message: {
      Text("삭제 후에는 현재 회원의 최신 기록 또는 새 기록으로 이동합니다.")
    }
  }

  private func usesCompactLayout(for size: CGSize) -> Bool {
    size.width < 1180
  }

  private var sessionQueue: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("세션")
        .font(TrainerFont.title(30, weight: .bold))
        .foregroundStyle(TrainerColor.primaryText)
        .padding(.horizontal, 18)
        .padding(.top, 24)
      Text("회원 선택 후 필기와 입력 패널이 같은 기록에 연결됩니다.")
        .font(TrainerFont.body(12, weight: .medium))
        .foregroundStyle(TrainerColor.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 18)

      VStack(spacing: 8) {
        ForEach(Array(store.members.enumerated()), id: \.element.id) { index, member in
          Button {
            store.selectMember(member)
          } label: {
            MemberQueueRow(member: member, selected: member.id == store.selectedMemberID)
              .trainerLabel("TR-SOAP-01-\(index + 1)")
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 14)

      Spacer()

      HealthCard(padding: 16) {
        VStack(alignment: .leading, spacing: 10) {
          Text("작성 원칙")
            .font(TrainerFont.title(17, weight: .bold))
            .foregroundStyle(TrainerColor.primaryText)
          Label("수업 중에는 필기 우선", systemImage: TrainerSymbol.pencil)
          Label("종료 전 S/O/A/P 정리", systemImage: TrainerSymbol.checklist)
          Label("회원 공유 요약 분리", systemImage: TrainerSymbol.protectedShare)
        }
        .font(TrainerFont.body(13, weight: .medium))
        .foregroundStyle(TrainerColor.secondaryText)
      }
      .padding(14)
      .trainerLabel("TR-SOAP-01-GUIDE")
    }
    .background(StudioBackdrop().ignoresSafeArea())
  }

  private var workspace: some View {
    VStack(spacing: 0) {
      soapHeader

      Group {
        switch selectedMode {
        case "SOAP":
          structuredPanel
        case "공유":
          sharePanel
        case "시각화":
          visualizationPanel
        default:
          handwritingPanel
        }
      }
    }
  }

  private var soapHeader: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 14) {
        soapMemberSummary
          .trainerLabel("TR-SOAP-04")

        Spacer(minLength: 10)

        soapModePicker
          .trainerLabel("TR-SOAP-05")

        StatusCapsule(text: store.saveState.label, color: TrainerColor.blue)
          .trainerLabel("TR-SOAP-06")

        saveButton
          .trainerLabel("TR-SOAP-07")
      }

      VStack(alignment: .leading, spacing: 12) {
        HStack {
          soapMemberSummary
            .trainerLabel("TR-SOAP-04")
          Spacer()
          saveButton
            .trainerLabel("TR-SOAP-07")
        }
        soapModePicker
          .trainerLabel("TR-SOAP-05")
      }
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 14)
    .background(TrainerColor.card.opacity(0.88))
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(TrainerColor.border)
        .frame(height: 1)
    }
  }

  private var soapMemberSummary: some View {
    HStack(spacing: 14) {
      TrainerAvatar(member: store.selectedMember, size: 52)

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          Text(store.selectedMember.name)
            .font(TrainerFont.display(30, weight: .bold))
            .foregroundStyle(TrainerColor.primaryText)
            .lineLimit(1)
          StatusCapsule(text: store.draft.risk.rawValue, color: store.draft.risk.color)
        }

        Text("\(store.selectedMember.subtitle) · \(store.draft.bodyRegion) · 통증 \(Int(store.draft.pain))/10")
          .font(TrainerFont.body(14, weight: .medium))
          .foregroundStyle(TrainerColor.secondaryText)
          .lineLimit(1)
      }
    }
    .layoutPriority(1)
  }

  private var soapModePicker: some View {
    NativeSegmentedControl(
      values: ["필기", "SOAP", "공유", "시각화"],
      selection: $selectedMode,
      label: "TR-SOAP-05"
    )
    .frame(width: 320)
  }

  private var saveButton: some View {
    Button {
      store.saveDraft()
    } label: {
      Label("저장", systemImage: TrainerSymbol.save)
    }
    .buttonStyle(TrainerCompactPrimaryButtonStyle())
  }

  private var handwritingPanel: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Pencil Note")
            .font(TrainerFont.label(13, weight: .bold))
            .foregroundStyle(TrainerColor.blue)
          Text("수업 중 필기는 내부 기록으로 보관합니다.")
            .font(TrainerFont.body(14, weight: .medium))
            .foregroundStyle(TrainerColor.secondaryText)
        }
        Spacer()
        StatusCapsule(text: "내부 전용", color: TrainerColor.deepBlue)
      }
      .padding(.horizontal, 24)
      .padding(.top, 20)

      ZStack(alignment: .bottom) {
        PencilCanvas(
          drawing: $drawing,
          selectedTool: $selectedTool,
          undoSignal: $undoSignal
        )
        .background(PaperLines())
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(TrainerColor.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 8)
        .trainerLabel("TR-SOAP-09")

        PencilToolbar(
          selectedTool: $selectedTool,
          undoSignal: $undoSignal,
          onIncreasePain: {
            store.draft.pain = min(10, store.draft.pain + 1)
          },
          onAddROM: {
            store.addDraftMetric(.rom)
            selectedMode = "시각화"
          },
          onAddMMT: {
            store.addDraftMetric(.mmt)
            selectedMode = "시각화"
          }
        )
        .padding(.bottom, 22)
        .trainerLabel("TR-SOAP-10")
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 24)
    }
    .background(StudioBackdrop().ignoresSafeArea())
    .trainerLabel("TR-SOAP-08")
  }

  private var structuredPanel: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        HStack(alignment: .center) {
          VStack(alignment: .leading, spacing: 4) {
            Text("SOAP 정리")
              .font(TrainerFont.title(28, weight: .bold))
              .foregroundStyle(TrainerColor.primaryText)
            Text("필기 내용을 구조화하고 공유 가능한 기록으로 정리합니다.")
              .font(TrainerFont.body(14, weight: .medium))
              .foregroundStyle(TrainerColor.secondaryText)
          }
          Spacer()
          StatusCapsule(text: "\(soapCompletionPercent)% 완료", color: TrainerColor.blue)
        }

        HStack(alignment: .top, spacing: 16) {
          SoapCategoryRail(selectedSoap: $selectedSoap, draft: store.draft)
            .frame(width: 184)
            .trainerLabel("TR-SOAP-12")
          VStack(alignment: .leading, spacing: 14) {
            SoapStepSummary(selectedSoap: selectedSoap, completedCount: store.draft.completedCategoryCount)
              .trainerLabel("TR-SOAP-13")
            activeSoapEditor
              .trainerLabel("TR-SOAP-13-EDITOR")
          }
        }
      }
      .padding(24)
    }
    .background(StudioBackdrop().ignoresSafeArea())
    .trainerLabel("TR-SOAP-11")
  }

  @ViewBuilder
  private var activeSoapEditor: some View {
    switch selectedSoap {
    case "O":
      SoapTextBox(
        title: "O. 객관적 정보",
        placeholder: "관찰, ROM, MMT, special test",
        text: $store.draft.objective,
        focused: $isTextInputFocused
      )
    case "A":
      SoapTextBox(
        title: "A. 평가",
        placeholder: "문제 목록, 임상 판단, 단기/장기 목표",
        text: $store.draft.assessment,
        focused: $isTextInputFocused
      )
    case "P":
      SoapTextBox(
        title: "P. 계획",
        placeholder: "치료계획, 홈운동, 다음 세션",
        text: $store.draft.plan,
        focused: $isTextInputFocused
      )
    default:
      SoapTextBox(
        title: "S. 주관적 정보",
        placeholder: "주호소, onset, 악화/완화 요인",
        text: $store.draft.subjective,
        focused: $isTextInputFocused
      )
    }
  }

  private var sharePanel: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Text("회원 공유 요약")
          .font(TrainerFont.title(30, weight: .bold))
          .foregroundStyle(TrainerColor.primaryText)
        HealthCard {
          VStack(alignment: .leading, spacing: 14) {
            ShareLine(title: "현재 상태", value: "\(store.draft.bodyRegion) · 통증 \(Int(store.draft.pain))/10 · \(store.draft.risk.rawValue)")
            ShareLine(title: "오늘 확인한 점", value: store.draft.assessment)
            ShareLine(title: "다음 실행 계획", value: store.draft.plan)
          }
        }
        .trainerLabel("TR-SOAP-16")
        HealthCard {
          HStack {
            IconTile(symbol: TrainerSymbol.lock, color: TrainerColor.blue)
            VStack(alignment: .leading, spacing: 4) {
              Text("내부 필기는 공유하지 않음")
                .font(TrainerFont.title(19, weight: .bold))
                .foregroundStyle(TrainerColor.primaryText)
              Text("회원에게는 정리된 요약만 전달하고, 트레이너 필기 원본은 내부 관리용으로 유지합니다.")
                .foregroundStyle(TrainerColor.secondaryText)
            }
          }
        }
        .trainerLabel("TR-SOAP-17")
      }
      .padding(24)
    }
    .background(StudioBackdrop().ignoresSafeArea())
    .trainerLabel("TR-SOAP-15")
  }

  private var visualizationPanel: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Text("세션 시각화")
          .font(TrainerFont.title(30, weight: .bold))
          .foregroundStyle(TrainerColor.primaryText)
        HStack(spacing: 14) {
          ProgressMetric(title: "통증", value: "\(Int(store.draft.pain))/10", progress: store.draft.pain / 10, color: TrainerColor.purple, label: "TR-SOAP-19")
          ProgressMetric(title: "목표 진행", value: "\(store.selectedMember.progress)%", progress: Double(store.selectedMember.progress) / 100, color: TrainerColor.blue, label: "TR-SOAP-20")
          ProgressMetric(title: "SOAP 완료", value: "\(soapCompletionPercent)%", progress: Double(soapCompletionPercent) / 100, color: TrainerColor.deepBlue, label: "TR-SOAP-21")
        }
        HealthCard {
          VStack(alignment: .leading, spacing: 14) {
            Text("통증 / 완료율 변화")
              .font(TrainerFont.title(21, weight: .bold))
              .foregroundStyle(TrainerColor.primaryText)
            PainCompletionChart(
              painPoints: store.selectedMember.painSeries,
              completionPoints: store.selectedMember.completionSeries,
              secondaryTitle: "목표 진행"
            )
            .frame(height: 320)
          }
        }
        .trainerLabel("TR-SOAP-22")
      }
      .padding(24)
    }
    .background(StudioBackdrop().ignoresSafeArea())
    .trainerLabel("TR-SOAP-18")
  }

  private var inspector: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Text("빠른 입력")
          .font(TrainerFont.title(24, weight: .bold))
          .foregroundStyle(TrainerColor.primaryText)
        Text("수업 중 바뀌는 값만 즉시 조정합니다.")
          .font(TrainerFont.body(13, weight: .medium))
          .foregroundStyle(TrainerColor.secondaryText)

        HealthCard(padding: 16) {
          VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Text("통증")
                  .font(TrainerFont.label(15, weight: .semibold))
                  .foregroundStyle(TrainerColor.primaryText)
                Spacer()
                Text("\(Int(store.draft.pain))/10")
                  .font(TrainerFont.label(15, weight: .bold))
                  .foregroundStyle(TrainerColor.blue)
              }
              Slider(value: $store.draft.pain, in: 0...10, step: 1)
                .tint(TrainerColor.blue)
            }

            FieldRow(title: "부위", text: $store.draft.bodyRegion, focused: $isTextInputFocused)

            VStack(alignment: .leading, spacing: 8) {
              Text("위험도")
                .font(TrainerFont.label(13, weight: .semibold))
                .foregroundStyle(TrainerColor.secondaryText)
              Picker("위험도", selection: $store.draft.risk) {
                ForEach(RiskLevel.allCases) { level in
                  Text(level.rawValue).tag(level)
                }
              }
              .pickerStyle(.segmented)
            }
          }
        }
        .trainerLabel("TR-SOAP-23")

        VStack(alignment: .leading, spacing: 14) {
          Text("측정값")
            .font(TrainerFont.title(18, weight: .bold))
            .foregroundStyle(TrainerColor.primaryText)
          MetricEntryList(title: "ROM", entries: store.draft.romEntries) {
            store.addDraftMetric(.rom)
          }
          .trainerLabel("TR-SOAP-24")
          MetricEntryList(title: "MMT", entries: store.draft.mmtEntries) {
            store.addDraftMetric(.mmt)
          }
          .trainerLabel("TR-SOAP-25")
        }

        Button {
          selectedMode = "SOAP"
        } label: {
          Label("세션 후 정리", systemImage: TrainerSymbol.soap)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(TrainerPrimaryButtonStyle())
        .trainerLabel("TR-SOAP-26")

        Button {
          resetDraft()
        } label: {
          Label("새 기록", systemImage: TrainerSymbol.add)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(TrainerSecondaryButtonStyle())
        .trainerLabel("TR-SOAP-27")

        Button(role: .destructive) {
          showingDeleteConfirmation = true
        } label: {
          Label("현재 SOAP 삭제", systemImage: TrainerSymbol.delete)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(TrainerDestructiveButtonStyle())
        .disabled(store.draft.id == nil)
        .trainerLabel("TR-SOAP-28")
      }
      .padding(18)
    }
    .background(StudioBackdrop().ignoresSafeArea())
  }

  private var soapCompletionPercent: Int {
    min(100, max(0, store.draft.completedCategoryCount * 25))
  }

  private func resetDraft() {
    drawing = PKDrawing()
    store.resetDraft()
  }
}

private struct MemberQueueRow: View {
  let member: TrainerMember
  let selected: Bool

  var body: some View {
    HStack(spacing: 11) {
      TrainerAvatar(member: member, size: 38)
      VStack(alignment: .leading, spacing: 3) {
        Text(member.name)
          .font(TrainerFont.label(15, weight: .semibold))
          .foregroundStyle(TrainerColor.primaryText)
        Text(member.signal)
          .font(TrainerFont.body(12))
          .foregroundStyle(TrainerColor.secondaryText)
      }
      Spacer()
      Text("\(member.pain)/10")
        .font(TrainerFont.label(12, weight: .bold))
        .foregroundStyle(member.risk.color)
    }
    .padding(12)
    .background(
      selected ? TrainerColor.blue.opacity(0.10) : TrainerColor.card,
      in: RoundedRectangle(cornerRadius: 16, style: .continuous)
    )
  }
}

private struct SoapCategoryRail: View {
  @Binding var selectedSoap: String
  let draft: SoapDraft

  private let categories: [(key: String, title: String, caption: String)] = [
    ("S", "주관", "주호소·통증 양상"),
    ("O", "객관", "ROM·MMT·검사"),
    ("A", "평가", "판단·목표"),
    ("P", "계획", "치료·홈운동")
  ]

  var body: some View {
    VStack(spacing: 9) {
      ForEach(categories, id: \.key) { category in
        Button {
          selectedSoap = category.key
        } label: {
          HStack(spacing: 11) {
            Text(category.key)
              .font(TrainerFont.label(14, weight: .bold))
              .foregroundStyle(selectedSoap == category.key ? TrainerColor.inverseText : TrainerColor.blue)
              .frame(width: 34, height: 34)
              .background(
                selectedSoap == category.key ? TrainerColor.blue : TrainerColor.blue.opacity(0.10),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
              )

            VStack(alignment: .leading, spacing: 2) {
              Text(category.title)
                .font(TrainerFont.label(14, weight: .bold))
                .foregroundStyle(TrainerColor.primaryText)
                .lineLimit(1)
              Text(category.caption)
                .font(TrainerFont.body(11, weight: .medium))
                .foregroundStyle(TrainerColor.secondaryText)
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            if isComplete(category.key) {
              Image(systemName: TrainerSymbol.confirm)
                .font(TrainerFont.label(13, weight: .bold))
                .foregroundStyle(TrainerColor.blue)
            }
          }
          .padding(12)
          .background(
            selectedSoap == category.key ? TrainerColor.blue.opacity(0.10) : TrainerColor.card.opacity(0.78),
            in: RoundedRectangle(cornerRadius: 17, style: .continuous)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
              .stroke(selectedSoap == category.key ? TrainerColor.blue.opacity(0.38) : TrainerColor.border, lineWidth: 1)
          )
        }
        .buttonStyle(.plain)
      }
    }
  }

  private func isComplete(_ key: String) -> Bool {
    switch key {
    case "S": return !draft.subjective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    case "O": return !draft.objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    case "A": return !draft.assessment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    case "P": return !draft.plan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    default: return false
    }
  }
}

private struct SoapStepSummary: View {
  let selectedSoap: String
  let completedCount: Int

  private var title: String {
    switch selectedSoap {
    case "O": return "객관적 평가를 입력합니다"
    case "A": return "판단과 목표를 정리합니다"
    case "P": return "다음 행동 계획을 확정합니다"
    default: return "회원이 말한 내용을 기록합니다"
    }
  }

  private var caption: String {
    switch selectedSoap {
    case "O": return "ROM/MMT는 오른쪽 빠른 입력에서 추가하고, 관찰 내용은 여기서 정리합니다."
    case "A": return "문제 목록, 위험도, 단기/장기 목표를 트레이너 언어로 정리합니다."
    case "P": return "치료 계획, 홈운동, 다음 세션에서 확인할 항목을 남깁니다."
    default: return "주호소, 통증 양상, 악화/완화 요인을 먼저 잡습니다."
    }
  }

  var body: some View {
    HealthCard(padding: 18) {
      HStack(spacing: 14) {
        Text(selectedSoap)
          .font(TrainerFont.display(24, weight: .bold))
          .foregroundStyle(TrainerColor.inverseText)
          .frame(width: 52, height: 52)
          .background(TrainerGradient.actionBlue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(TrainerFont.title(20, weight: .bold))
            .foregroundStyle(TrainerColor.primaryText)
          Text(caption)
            .font(TrainerFont.body(14, weight: .medium))
            .foregroundStyle(TrainerColor.secondaryText)
            .lineLimit(2)
        }

        Spacer()

        StatusCapsule(text: "\(completedCount)/4 완료", color: TrainerColor.blue)
      }
    }
  }
}

private struct SoapTextBox: View {
  let title: String
  let placeholder: String
  @Binding var text: String
  let focused: FocusState<Bool>.Binding

  var body: some View {
    HealthCard {
      VStack(alignment: .leading, spacing: 10) {
        Text(title)
          .font(TrainerFont.title(18, weight: .bold))
          .foregroundStyle(TrainerColor.primaryText)
        ZStack(alignment: .topLeading) {
          if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(placeholder)
              .font(TrainerFont.body(15))
              .foregroundStyle(TrainerColor.secondaryText)
              .padding(.horizontal, 5)
              .padding(.vertical, 8)
          }
          TextEditor(text: $text)
            .font(TrainerFont.body(16))
            .foregroundStyle(TrainerColor.primaryText)
            .frame(minHeight: 280)
            .scrollContentBackground(.hidden)
            .focused(focused)
        }
      }
    }
  }
}

private struct ShareLine: View {
  let title: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title)
        .font(TrainerFont.label(13, weight: .bold))
        .foregroundStyle(TrainerColor.secondaryText)
      Text(value)
        .font(TrainerFont.body(16))
        .foregroundStyle(TrainerColor.primaryText)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

private struct ProgressMetric: View {
  let title: String
  let value: String
  let progress: Double
  let color: Color
  var label: String? = nil

  var body: some View {
    HealthCard {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text(title)
            .font(TrainerFont.label(14, weight: .semibold))
            .foregroundStyle(TrainerColor.secondaryText)
          Spacer()
          Text(value)
            .font(TrainerFont.display(18, weight: .bold))
            .foregroundStyle(color)
        }
        ProgressView(value: min(max(progress, 0), 1))
          .tint(color)
      }
    }
    .trainerLabel(label)
  }
}

private struct FieldRow: View {
  let title: String
  @Binding var text: String
  let focused: FocusState<Bool>.Binding

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(title)
        .font(TrainerFont.label(13, weight: .semibold))
        .foregroundStyle(TrainerColor.secondaryText)
      TextField(title, text: $text)
        .font(TrainerFont.body(15))
        .textFieldStyle(.roundedBorder)
        .focused(focused)
    }
  }
}

private struct MetricEntryList: View {
  let title: String
  let entries: [String]
  let onAdd: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack {
        Text(title)
          .font(TrainerFont.label(15, weight: .bold))
          .foregroundStyle(TrainerColor.primaryText)
        Spacer()
        Button(action: onAdd) {
          Image(systemName: TrainerSymbol.add)
        }
        .buttonStyle(.plain)
      }
      if entries.isEmpty {
        Text("항목 없음")
          .font(TrainerFont.body(13))
          .foregroundStyle(TrainerColor.secondaryText)
      } else {
        ForEach(entries.suffix(3), id: \.self) { entry in
          HStack(spacing: 8) {
            Circle()
              .fill(TrainerColor.blue)
              .frame(width: 6, height: 6)
            Text(entry)
              .font(TrainerFont.body(13, weight: .medium))
              .foregroundStyle(TrainerColor.secondaryText)
              .lineLimit(1)
            Spacer()
          }
        }
      }
    }
    .padding(14)
    .background(TrainerColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(TrainerColor.border, lineWidth: 0.8)
    )
  }
}
