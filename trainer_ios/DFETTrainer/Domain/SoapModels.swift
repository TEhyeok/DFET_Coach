import Foundation

enum SoapMetricType: String, CaseIterable, Codable, Identifiable {
  case pain = "통증"
  case rom = "ROM"
  case mmt = "MMT"
  case functional = "기능검사"
  case specialTest = "특수검사"

  var id: String { rawValue }
}

enum SoapMetricSide: String, CaseIterable, Codable, Identifiable {
  case none = "해당 없음"
  case left = "좌"
  case right = "우"
  case bilateral = "양측"

  var id: String { rawValue }
}

struct SoapMetric: Identifiable, Hashable, Codable {
  var id: String = UUID().uuidString
  var type: SoapMetricType
  var label: String
  var side: SoapMetricSide
  var value: Double?
  var unit: String
  var score: Int?
  var note: String
}

enum SoapWorkflowStatus: String, CaseIterable, Codable, Identifiable {
  case draft = "작성 중"
  case completed = "완료"
  case shared = "공유됨"

  var id: String { rawValue }
}

struct SoapWorkflow: Hashable, Codable {
  var status: SoapWorkflowStatus
  var completedCategories: [String]
  var riskLevel: RiskLevel
  var followUpDate: String?
}

struct SoapNote: Identifiable, Hashable, Codable {
  var id: String
  var memberId: String
  var dateLabel: String
  var bodyRegion: String
  var pain: Int
  var subjective: String
  var objective: String
  var assessment: String
  var plan: String
  var metrics: [SoapMetric]
  var workflow: SoapWorkflow
  var drawingData: Data?

  // Firestore 호환 필드 (Flutter SoapNote.fromFirestore와 정합)
  // 회원/트레이너 정체성과 권한 규칙 평가에 필요한 필드.
  var trainerId: String = ""
  var trainerName: String? = nil
  var memberName: String? = nil
  var memberEmail: String? = nil
  var date: Date = Date()
  var isSharedWithMember: Bool = true
  var createdAt: Date = Date()
  var updatedAt: Date = Date()
}

struct SoapDraft: Hashable, Codable {
  var id: String?
  var memberId: String
  var bodyRegion: String
  var pain: Double
  var risk: RiskLevel
  var subjective: String
  var objective: String
  var assessment: String
  var plan: String
  var metrics: [SoapMetric]
  var workflow: SoapWorkflow
  var drawingData: Data?

  var romEntries: [String] {
    metricLabels(for: .rom)
  }

  var mmtEntries: [String] {
    metricLabels(for: .mmt)
  }

  func metricLabels(for type: SoapMetricType) -> [String] {
    metrics.filter { $0.type == type }.map(\.label)
  }

  var completedCategoryCount: Int {
    workflow.completedCategories.count
  }
}

extension SoapDraft {
  init(member: TrainerMember) {
    memberId = member.id
    bodyRegion = member.region
    pain = Double(member.pain)
    risk = member.risk
    subjective = "스쿼트 하강 구간에서 허리 불편감. 호흡 cue 후 안정."
    objective = "Hip hinge 패턴 제한, 우측 둔근 활성 저하. ROM/MMT 재측정 필요."
    assessment = "요추 과신전 보상과 둔근 약화가 동반된 움직임 패턴 문제."
    plan = "dead bug 2세트, hip hinge 드릴, 다음 세션에서 ROM/MMT 재확인."
    metrics = [
      SoapMetric(type: .rom, label: "고관절 굴곡 ROM", side: .bilateral, value: nil, unit: "도", score: nil, note: "말단 가동 범위 제한"),
      SoapMetric(type: .rom, label: "흉추 회전 ROM", side: .bilateral, value: nil, unit: "도", score: nil, note: "우측 회전 제한"),
      SoapMetric(type: .mmt, label: "우측 둔근 MMT", side: .right, value: nil, unit: "", score: 4, note: "초기 수축 지연")
    ]
    workflow = SoapWorkflow(status: .draft, completedCategories: ["S", "O"], riskLevel: member.risk, followUpDate: "다음 세션")
    drawingData = nil
  }
}
