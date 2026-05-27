import Foundation
import Combine
#if canImport(WidgetKit)
import WidgetKit
#endif

enum TrainerSaveState: Equatable {
  case idle
  case saving
  case saved(Date)

  var label: String {
    switch self {
    case .idle: return "자동저장"
    case .saving: return "저장 중"
    case .saved: return "저장됨"
    }
  }
}

@MainActor
final class TrainerStore: ObservableObject {
  @Published var isAuthenticated = false
  @Published var trainerName = "트레이너"
  @Published var authMode = "guest"
  @Published var selectedRoute: TrainerRoute = .productivityExample
  @Published var selectedMemberID: String
  @Published var members: [TrainerMember]
  @Published var soapNotes: [SoapNote]
  @Published var draft: SoapDraft
  @Published var dashboardSummary: TrainerDashboardSummary
  @Published var saveState: TrainerSaveState = .idle

  private var repository: TrainerRepository
  private var changesCancellable: AnyCancellable?

  init(repository: TrainerRepository = PreviewTrainerRepository()) {
    self.repository = repository
    let loadedMembers = repository.loadMembers()
    let first = loadedMembers.first ?? TrainerMember.placeholder
    members = loadedMembers
    selectedMemberID = first.id
    soapNotes = repository.loadSoapNotes(memberId: first.id)
    draft = SoapDraft(member: first)
    dashboardSummary = repository.dashboardSummary()

    if let latest = soapNotes.first {
      draft = SoapDraft(note: latest, member: first)
    }

    let launchArguments = ProcessInfo.processInfo.arguments

    if launchArguments.contains("--preview-authenticated") {
      trainerName = "트레이너 게스트"
      authMode = "guest"
      isAuthenticated = true
    }

    if launchArguments.contains("--preview-members") {
      trainerName = "트레이너 게스트"
      authMode = "guest"
      isAuthenticated = true
      selectedRoute = .members
    }

    if launchArguments.contains("--preview-soap") {
      trainerName = "트레이너 게스트"
      authMode = "guest"
      isAuthenticated = true
      selectedRoute = .soap
    }

    if launchArguments.contains("--preview-reports") {
      trainerName = "트레이너 게스트"
      authMode = "guest"
      isAuthenticated = true
      selectedRoute = .reports
    }

    if launchArguments.contains("--preview-settings") {
      trainerName = "트레이너 게스트"
      authMode = "guest"
      isAuthenticated = true
      selectedRoute = .settings
    }

    if launchArguments.contains("--preview-productivity-example") {
      trainerName = "트레이너 게스트"
      authMode = "guest"
      isAuthenticated = true
      selectedRoute = .productivityExample
    }

    if launchArguments.contains("--preview-login") {
      trainerName = "트레이너"
      authMode = "guest"
      isAuthenticated = false
      selectedRoute = .productivityExample
    }

    subscribeToRepositoryChanges()
    publishWidgetSnapshot()
  }

  /// 로그인 성공 후 Firestore 기반 repository로 전환.
  /// 기존 구독을 취소하고 새 repository의 changes에 다시 구독한다.
  func connect(to firebaseRepository: TrainerRepository) {
    changesCancellable?.cancel()
    repository = firebaseRepository
    refreshMembersAndSummary()
    if let firstMember = members.first {
      selectedMemberID = firstMember.id
      soapNotes = repository.loadSoapNotes(memberId: firstMember.id)
      draft = soapNotes.first.map { SoapDraft(note: $0, member: firstMember) }
        ?? SoapDraft(member: firstMember)
    }
    subscribeToRepositoryChanges()
  }

  private func subscribeToRepositoryChanges() {
    changesCancellable = repository.changes
      .receive(on: DispatchQueue.main)
      .sink { [weak self] in
        guard let self else { return }
        self.refreshMembersAndSummary()
        let currentMember = self.selectedMember
        self.soapNotes = self.repository.loadSoapNotes(memberId: currentMember.id)
      }
  }

  var selectedMember: TrainerMember {
    members.first(where: { $0.id == selectedMemberID })
      ?? members.first
      ?? TrainerMember.placeholder
  }

  var attentionMembers: [TrainerMember] {
    members.filter { $0.risk != .stable || $0.pain >= 5 }
  }

  var averagePain: Double {
    dashboardSummary.averagePain
  }

  func signInDemoTrainer(email: String) {
    let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
    trainerName = trimmed.isEmpty ? "트레이너" : trimmed
    authMode = "trainer"
    isAuthenticated = true
    selectedRoute = .productivityExample
  }

  func signInGuestTrainer() {
    trainerName = "트레이너 게스트"
    authMode = "guest"
    isAuthenticated = true
    selectedRoute = .productivityExample
  }

  func signOut() {
    isAuthenticated = false
    trainerName = "트레이너"
    authMode = "guest"
    selectedRoute = .productivityExample
  }

  func selectMember(_ member: TrainerMember) {
    selectedMemberID = member.id
    soapNotes = repository.loadSoapNotes(memberId: member.id)
    if let latest = soapNotes.first {
      draft = SoapDraft(note: latest, member: member)
    } else {
      draft = SoapDraft(member: member)
    }
  }

  func saveDraft() {
    saveState = .saving
    let note = repository.saveSoapDraft(draft)
    draft.id = note.id
    soapNotes = repository.loadSoapNotes(memberId: note.memberId)
    refreshMembersAndSummary()

    Task { @MainActor in
      try? await Task.sleep(nanoseconds: 450_000_000)
      saveState = .saved(Date())
      try? await Task.sleep(nanoseconds: 1_600_000_000)
      if case .saved = saveState {
        saveState = .idle
      }
    }
  }

  func deleteSelectedNote() {
    guard let id = draft.id else { return }
    repository.deleteSoapNote(id: id)
    soapNotes = repository.loadSoapNotes(memberId: selectedMemberID)
    draft = soapNotes.first.map { SoapDraft(note: $0, member: selectedMember) } ?? SoapDraft(member: selectedMember)
    refreshMembersAndSummary()
  }

  func addDraftMetric(_ type: SoapMetricType) {
    let count = draft.metrics.filter { $0.type == type }.count + 1
    let metric = SoapMetric(
      type: type,
      label: "\(draft.bodyRegion) \(type.rawValue) \(count)",
      side: .none,
      value: nil,
      unit: type == .rom ? "도" : "",
      score: type == .mmt ? 4 : nil,
      note: ""
    )
    draft.metrics.append(metric)
  }

  func resetDraft() {
    draft = SoapDraft(member: selectedMember)
  }

  func refreshWidgetSnapshot() {
    refreshMembersAndSummary()
  }

  private func refreshMembersAndSummary() {
    members = repository.loadMembers()
    dashboardSummary = repository.dashboardSummary()
    publishWidgetSnapshot()
  }

  private func publishWidgetSnapshot() {
    TrainerWidgetSnapshotStore.save(
      TrainerWidgetSnapshot(
        todaySessions: dashboardSummary.todaySessionCount,
        soapTodoCount: dashboardSummary.soapTodoCount,
        reassessmentCount: dashboardSummary.attentionMemberCount,
        averagePain: dashboardSummary.averagePain,
        generatedAtLabel: "방금 업데이트"
      )
    )
    #if canImport(WidgetKit)
    WidgetCenter.shared.reloadAllTimelines()
    #endif
  }

  static let preview = TrainerStore(repository: PreviewTrainerRepository())
}

private extension SoapDraft {
  init(note: SoapNote, member: TrainerMember) {
    id = note.id
    memberId = note.memberId
    bodyRegion = note.bodyRegion
    pain = Double(note.pain)
    risk = note.workflow.riskLevel
    subjective = note.subjective
    objective = note.objective
    assessment = note.assessment
    plan = note.plan
    metrics = note.metrics
    workflow = note.workflow
    drawingData = note.drawingData

    if metrics.isEmpty {
      self = SoapDraft(member: member)
      id = note.id
    }
  }
}
