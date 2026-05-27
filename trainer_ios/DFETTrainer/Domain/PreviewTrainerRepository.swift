import Foundation
import Combine

final class PreviewTrainerRepository: TrainerRepository {
  private var members: [TrainerMember]
  private var notesByMemberID: [String: [SoapNote]]

  /// PreviewRepository는 외부 데이터 소스가 없으므로 빈 publisher.
  let changes: AnyPublisher<Void, Never> = Empty().eraseToAnyPublisher()

  init() {
    members = Self.previewMembers
    notesByMemberID = Dictionary(grouping: Self.previewNotes, by: \.memberId)
  }

  func loadMembers() -> [TrainerMember] {
    members
  }

  func loadSoapNotes(memberId: String) -> [SoapNote] {
    notesByMemberID[memberId, default: []]
  }

  @discardableResult
  func saveSoapDraft(_ draft: SoapDraft) -> SoapNote {
    let noteID = draft.id ?? UUID().uuidString
    let completed = ["S", "O", "A", "P"].filter { category in
      switch category {
      case "S": return !draft.subjective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      case "O": return !draft.objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      case "A": return !draft.assessment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      case "P": return !draft.plan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      default: return false
      }
    }
    let note = SoapNote(
      id: noteID,
      memberId: draft.memberId,
      dateLabel: "오늘",
      bodyRegion: draft.bodyRegion,
      pain: Int(draft.pain),
      subjective: draft.subjective,
      objective: draft.objective,
      assessment: draft.assessment,
      plan: draft.plan,
      metrics: draft.metrics,
      workflow: SoapWorkflow(
        status: completed.count == 4 ? .completed : .draft,
        completedCategories: completed,
        riskLevel: draft.risk,
        followUpDate: draft.workflow.followUpDate
      ),
      drawingData: draft.drawingData
    )

    var notes = notesByMemberID[draft.memberId, default: []]
    notes.removeAll { $0.id == noteID }
    notes.insert(note, at: 0)
    notesByMemberID[draft.memberId] = notes
    updateMemberAfterSaving(note)
    return note
  }

  func deleteSoapNote(id: String) {
    for key in notesByMemberID.keys {
      notesByMemberID[key]?.removeAll { $0.id == id }
    }
  }

  func dashboardSummary() -> TrainerDashboardSummary {
    let attentionCount = members.filter { $0.risk != .stable || $0.pain >= 5 }.count
    let averagePain = members.isEmpty ? 0 : Double(members.map(\.pain).reduce(0, +)) / Double(members.count)
    let allNotes = notesByMemberID.values.flatMap { $0 }
    let todoCount = max(3, allNotes.filter { $0.workflow.status == .draft }.count)

    return TrainerDashboardSummary(
      todaySessionCount: 6,
      completedSessionCount: 3,
      plannedSessionCount: 3,
      managedMemberCount: members.count,
      attentionMemberCount: attentionCount,
      soapTodoCount: todoCount,
      averagePain: averagePain,
      stableGoalPercent: 74,
      soapCompletionPercent: 86,
      homeExercisePercent: 68,
      painTrend: [6.8, 6.4, 6.1, 5.7, 5.2, 4.9, 4.5, 4.2],
      completionTrend: [44, 49, 57, 61, 68, 75, 82, 86],
      trends: [
        TrainerTrend(id: "reassessment", title: "재평가 필요", subtitle: "주의 회원 \(attentionCount)명", symbol: TrainerSymbol.warning, accent: .orange, value: "\(attentionCount)명"),
        TrainerTrend(id: "soap-completion", title: "SOAP 완료율", subtitle: "최근 8주 +42%p", symbol: TrainerSymbol.soap, accent: .blue, value: "86%"),
        TrainerTrend(id: "home-exercise", title: "홈운동 수행", subtitle: "회원 공유 리포트 기준", symbol: TrainerSymbol.exercise, accent: .green, value: "68%")
      ]
    )
  }

  private func updateMemberAfterSaving(_ note: SoapNote) {
    guard let index = members.firstIndex(where: { $0.id == note.memberId }) else { return }
    members[index].pain = note.pain
    members[index].risk = note.workflow.riskLevel
    members[index].lastSoap = note.dateLabel
  }
}

private extension PreviewTrainerRepository {
  static let previewMembers: [TrainerMember] = [
    TrainerMember(
      id: "member-kim",
      name: "김회원",
      email: "kim@example.com",
      program: "허리 관리 · 주 2회",
      region: "허리",
      pain: 7,
      risk: .high,
      progress: 62,
      lastSoap: "오늘",
      nextPlan: "힙힌지 패턴 재교육, 우측 둔근 MMT 재확인, dead bug 홈운동 체크",
      painSeries: [4.8, 5.1, 5.6, 5.9, 6.4, 6.9, 7.2, 7.0],
      completionSeries: [47, 52, 56, 58, 60, 62, 64, 62]
    ),
    TrainerMember(
      id: "member-park",
      name: "박회원",
      email: "park@example.com",
      program: "무릎 안정화 · 재평가",
      region: "무릎",
      pain: 5,
      risk: .attention,
      progress: 74,
      lastSoap: "어제",
      nextPlan: "스쿼트 깊이 제한, knee valgus cue, ROM 재측정",
      painSeries: [6.4, 6.1, 5.9, 5.7, 5.4, 5.2, 5.1, 5.0],
      completionSeries: [51, 57, 62, 66, 69, 72, 75, 74]
    ),
    TrainerMember(
      id: "member-lee",
      name: "이회원",
      email: "lee@example.com",
      program: "어깨 가동성 · 유지",
      region: "어깨",
      pain: 3,
      risk: .stable,
      progress: 86,
      lastSoap: "2일 전",
      nextPlan: "흉추 회전, scapular control, overhead pattern 점검",
      painSeries: [4.0, 3.8, 3.6, 3.4, 3.2, 3.1, 2.9, 2.8],
      completionSeries: [63, 68, 72, 77, 80, 83, 85, 86]
    )
  ]

  static var previewNotes: [SoapNote] {
    previewMembers.map { member in
      let draft = SoapDraft(member: member)
      return SoapNote(
        id: "soap-\(member.id)",
        memberId: member.id,
        dateLabel: member.lastSoap,
        bodyRegion: member.region,
        pain: member.pain,
        subjective: draft.subjective,
        objective: draft.objective,
        assessment: draft.assessment,
        plan: draft.plan,
        metrics: draft.metrics,
        workflow: draft.workflow,
        drawingData: nil
      )
    }
  }
}
