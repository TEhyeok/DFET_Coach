import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

/// Firestore 기반 TrainerRepository 구현.
///
/// 인증된 트레이너 uid를 기준으로:
///   - trainers/{uid}.memberIds 를 구독해 담당 회원 목록 로드
///   - users/{memberId} 일괄 조회로 TrainerMember 캐시 갱신
///   - soap_notes where trainerId == uid 구독
///
/// 모든 사용자 facing 메서드는 동기 인터페이스를 유지하기 위해 내부 캐시를 반환한다.
/// snapshotListener 콜백이 캐시를 갱신하고 `changes` publisher로 알림을 보낸다.
@MainActor
final class FirebaseTrainerRepository: TrainerRepository {
  private let trainerUid: String
  private let db: Firestore
  private let auth: Auth

  private var membersCache: [TrainerMember] = []
  private var notesByMemberID: [String: [SoapNote]] = [:]

  private var trainerDocListener: ListenerRegistration?
  private var usersListener: ListenerRegistration?
  private var soapNotesListener: ListenerRegistration?

  private let changeSubject = PassthroughSubject<Void, Never>()
  var changes: AnyPublisher<Void, Never> { changeSubject.eraseToAnyPublisher() }

  init(trainerUid: String, db: Firestore = Firestore.firestore(), auth: Auth = Auth.auth()) {
    self.trainerUid = trainerUid
    self.db = db
    self.auth = auth
    startListeners()
  }

  deinit {
    trainerDocListener?.remove()
    usersListener?.remove()
    soapNotesListener?.remove()
  }

  // MARK: - TrainerRepository

  func loadMembers() -> [TrainerMember] {
    membersCache
  }

  func loadSoapNotes(memberId: String) -> [SoapNote] {
    notesByMemberID[memberId, default: []]
  }

  @discardableResult
  func saveSoapDraft(_ draft: SoapDraft) -> SoapNote {
    let now = Date()
    let memberName = membersCache.first(where: { $0.id == draft.memberId })?.name ?? ""
    let memberEmail = membersCache.first(where: { $0.id == draft.memberId })?.email

    let completed = ["S", "O", "A", "P"].filter { category in
      switch category {
      case "S": return !draft.subjective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      case "O": return !draft.objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      case "A": return !draft.assessment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      case "P": return !draft.plan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      default: return false
      }
    }

    let noteID = draft.id ?? db.collection("soap_notes").document().documentID
    let note = SoapNote(
      id: noteID,
      memberId: draft.memberId,
      dateLabel: Self.dateLabel(for: now),
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
      drawingData: draft.drawingData,
      trainerId: trainerUid,
      trainerName: auth.currentUser?.displayName,
      memberName: memberName,
      memberEmail: memberEmail,
      date: now,
      isSharedWithMember: true,
      createdAt: now,
      updatedAt: now
    )

    db.collection("soap_notes").document(noteID).setData(
      Self.firestoreMap(for: note),
      merge: true
    ) { [weak self] error in
      if let error = error {
        print("[FirebaseTrainerRepository] saveSoapDraft error:", error.localizedDescription)
        return
      }
      self?.changeSubject.send(())
    }

    // 로컬 캐시 낙관적 갱신
    var memberNotes = notesByMemberID[draft.memberId, default: []]
    memberNotes.removeAll { $0.id == noteID }
    memberNotes.insert(note, at: 0)
    notesByMemberID[draft.memberId] = memberNotes
    return note
  }

  func deleteSoapNote(id: String) {
    db.collection("soap_notes").document(id).delete { [weak self] error in
      if let error = error {
        print("[FirebaseTrainerRepository] deleteSoapNote error:", error.localizedDescription)
        return
      }
      self?.changeSubject.send(())
    }
    for key in notesByMemberID.keys {
      notesByMemberID[key]?.removeAll { $0.id == id }
    }
  }

  func dashboardSummary() -> TrainerDashboardSummary {
    let attentionCount = membersCache.filter { $0.risk != .stable || $0.pain >= 5 }.count
    let averagePain = membersCache.isEmpty
      ? 0
      : Double(membersCache.map(\.pain).reduce(0, +)) / Double(membersCache.count)
    let allNotes = notesByMemberID.values.flatMap { $0 }
    let todoCount = allNotes.filter { $0.workflow.status == .draft }.count

    return TrainerDashboardSummary(
      todaySessionCount: 0,
      completedSessionCount: 0,
      plannedSessionCount: 0,
      managedMemberCount: membersCache.count,
      attentionMemberCount: attentionCount,
      soapTodoCount: todoCount,
      averagePain: averagePain,
      stableGoalPercent: 0,
      soapCompletionPercent: 0,
      homeExercisePercent: 0,
      painTrend: [],
      completionTrend: [],
      trends: []
    )
  }

  // MARK: - Listeners

  private func startListeners() {
    trainerDocListener = db.collection("trainers").document(trainerUid)
      .addSnapshotListener { [weak self] snapshot, error in
        guard let self = self else { return }
        if let error = error {
          print("[FirebaseTrainerRepository] trainers listener:", error.localizedDescription)
          return
        }
        guard let data = snapshot?.data() else {
          self.membersCache = []
          self.changeSubject.send(())
          return
        }
        let memberIds = (data["memberIds"] as? [String]) ?? []
        Task { @MainActor in
          await self.refreshMembers(memberIds: memberIds)
        }
      }

    soapNotesListener = db.collection("soap_notes")
      .whereField("trainerId", isEqualTo: trainerUid)
      .order(by: "date", descending: true)
      .addSnapshotListener { [weak self] snapshot, error in
        guard let self = self else { return }
        if let error = error {
          print("[FirebaseTrainerRepository] soap_notes listener:", error.localizedDescription)
          return
        }
        let notes = snapshot?.documents.compactMap { doc in
          Self.soapNote(from: doc.data(), id: doc.documentID)
        } ?? []
        self.notesByMemberID = Dictionary(grouping: notes, by: \.memberId)
        self.changeSubject.send(())
      }
  }

  /// trainers/{uid}.memberIds 변경 시 호출. users/{memberId} 일괄 조회.
  /// Firestore `whereField('uid', in:)` 10개 제한 → 청크 분할.
  private func refreshMembers(memberIds: [String]) async {
    guard !memberIds.isEmpty else {
      membersCache = []
      changeSubject.send(())
      return
    }
    var loaded: [TrainerMember] = []
    let chunks = stride(from: 0, to: memberIds.count, by: 10).map {
      Array(memberIds[$0..<min($0 + 10, memberIds.count)])
    }
    for chunk in chunks {
      do {
        let snapshot = try await db.collection("users")
          .whereField(FieldPath.documentID(), in: chunk)
          .getDocuments()
        loaded.append(contentsOf: snapshot.documents.compactMap { doc in
          Self.trainerMember(from: doc.data(), id: doc.documentID)
        })
      } catch {
        print("[FirebaseTrainerRepository] refreshMembers:", error.localizedDescription)
      }
    }
    membersCache = loaded
    changeSubject.send(())
  }

  // MARK: - Mapping (internal: round-trip 호환성 테스트에서 사용)

  static func soapNote(from data: [String: Any], id: String) -> SoapNote? {
    let memberId = data["memberId"] as? String ?? ""
    let bodyRegion = data["bodyRegion"] as? String ?? ""
    let pain = (data["painNow"] as? Int) ?? (data["pain"] as? Int) ?? 0
    let dateMillis = data["date"] as? TimeInterval ?? 0
    let date = dateMillis > 0 ? Date(timeIntervalSince1970: dateMillis / 1000) : Date()
    let createdMillis = data["createdAt"] as? TimeInterval ?? dateMillis
    let updatedMillis = data["updatedAt"] as? TimeInterval ?? dateMillis

    let structured = data["structured"] as? [String: Any]
    let metricsRaw = (structured?["metrics"] as? [[String: Any]]) ?? []
    let metrics = metricsRaw.compactMap(metric(from:))
    let workflowRaw = (structured?["workflow"] as? [String: Any]) ?? [:]
    let workflow = soapWorkflow(from: workflowRaw)

    return SoapNote(
      id: id,
      memberId: memberId,
      dateLabel: relativeLabel(for: date),
      bodyRegion: bodyRegion,
      pain: pain,
      subjective: data["subjective"] as? String ?? "",
      objective: data["observation"] as? String ?? "",
      assessment: data["assessment"] as? String ?? "",
      plan: data["treatmentPlan"] as? String ?? "",
      metrics: metrics,
      workflow: workflow,
      drawingData: data["drawingData"] as? Data,
      trainerId: data["trainerId"] as? String ?? "",
      trainerName: data["trainerName"] as? String,
      memberName: data["memberName"] as? String,
      memberEmail: data["memberEmail"] as? String,
      date: date,
      isSharedWithMember: data["isSharedWithMember"] as? Bool ?? true,
      createdAt: Date(timeIntervalSince1970: createdMillis / 1000),
      updatedAt: Date(timeIntervalSince1970: updatedMillis / 1000)
    )
  }

  private static func metric(from data: [String: Any]) -> SoapMetric? {
    guard let typeRaw = data["type"] as? String,
          let type = SoapMetricType(rawValue: typeRaw) else {
      return nil
    }
    let sideRaw = data["side"] as? String ?? "해당 없음"
    let side = SoapMetricSide(rawValue: sideRaw) ?? .none
    let valueStr = data["value"] as? String
    return SoapMetric(
      type: type,
      label: data["label"] as? String ?? "",
      side: side,
      value: valueStr.flatMap { Double($0) },
      unit: data["unit"] as? String ?? "",
      score: data["score"] as? Int,
      note: data["note"] as? String ?? ""
    )
  }

  private static func soapWorkflow(from data: [String: Any]) -> SoapWorkflow {
    let statusRaw = data["status"] as? String ?? "draft"
    let status: SoapWorkflowStatus
    switch statusRaw {
    case "complete", "completed": status = .completed
    case "shared": status = .shared
    default: status = .draft
    }
    let riskRaw = data["riskLevel"] as? String ?? "low"
    let risk: RiskLevel
    switch riskRaw {
    case "high": risk = .high
    case "medium", "attention": risk = .attention
    default: risk = .stable
    }
    let completed = data["completedCategories"] as? [String] ?? []
    let followUp = (data["followUpDate"] as? TimeInterval).map {
      Date(timeIntervalSince1970: $0 / 1000)
    }
    let followUpLabel = followUp.map { dateLabel(for: $0) }
    return SoapWorkflow(
      status: status,
      completedCategories: completed,
      riskLevel: risk,
      followUpDate: followUpLabel
    )
  }

  static func firestoreMap(for note: SoapNote) -> [String: Any] {
    let metrics = note.metrics.map { metric -> [String: Any] in
      [
        "type": metric.type.rawValue,
        "label": metric.label,
        "side": metric.side.rawValue,
        "value": metric.value.map { "\($0)" } ?? "",
        "unit": metric.unit,
        "score": metric.score as Any,
        "note": metric.note,
      ]
    }
    let workflow: [String: Any] = [
      "status": note.workflow.status == .completed ? "complete" : note.workflow.status.rawValue,
      "completedCategories": note.workflow.completedCategories,
      "riskLevel": riskString(note.workflow.riskLevel),
      "followUpDate": NSNull(),
    ]
    let structured: [String: Any] = [
      "subjective": ["chiefComplaint": note.subjective],
      "objective": ["observation": note.objective],
      "assessment": ["problemList": note.assessment],
      "plan": ["treatmentPlan": note.plan],
      "metrics": metrics,
      "workflow": workflow,
    ]
    var map: [String: Any] = [
      "trainerId": note.trainerId,
      "trainerName": note.trainerName as Any,
      "memberId": note.memberId,
      "memberName": note.memberName ?? "",
      "memberEmail": note.memberEmail as Any,
      "date": Int(note.date.timeIntervalSince1970 * 1000),
      "visitType": "initial",
      "setting": "field",
      "bodyRegion": note.bodyRegion,
      "subjective": note.subjective,
      "observation": note.objective,
      "assessment": note.assessment,
      "treatmentPlan": note.plan,
      "painNow": note.pain,
      "isSharedWithMember": note.isSharedWithMember,
      "structured": structured,
      "createdAt": Int(note.createdAt.timeIntervalSince1970 * 1000),
      "updatedAt": Int(note.updatedAt.timeIntervalSince1970 * 1000),
    ]
    if let drawingData = note.drawingData {
      map["drawingData"] = drawingData
    }
    return map
  }

  private static func riskString(_ level: RiskLevel) -> String {
    switch level {
    case .stable: return "low"
    case .attention: return "medium"
    case .high: return "high"
    }
  }

  private static func trainerMember(from data: [String: Any], id: String) -> TrainerMember? {
    let name = (data["displayName"] as? String)
      ?? (data["name"] as? String)
      ?? "이름 없음"
    let email = (data["email"] as? String) ?? ""
    let painNow = (data["lastPainScore"] as? Int) ?? 0
    let region = (data["bodyRegion"] as? String) ?? ""

    return TrainerMember(
      id: id,
      name: name,
      email: email,
      program: (data["program"] as? String) ?? "",
      region: region,
      pain: painNow,
      risk: riskLevel(for: painNow),
      progress: (data["progress"] as? Int) ?? 0,
      lastSoap: "",
      nextPlan: (data["nextPlan"] as? String) ?? "",
      painSeries: [],
      completionSeries: []
    )
  }

  private static func riskLevel(for pain: Int) -> RiskLevel {
    if pain >= 7 { return .high }
    if pain >= 4 { return .attention }
    return .stable
  }

  private static func relativeLabel(for date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) { return "오늘" }
    if calendar.isDateInYesterday(date) { return "어제" }
    let days = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
    if days > 0 { return "\(days)일 전" }
    return dateLabel(for: date)
  }

  private static func dateLabel(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일"
    return formatter.string(from: date)
  }
}
