import XCTest
@testable import D_FET_Trainer

/// SoapNote ↔ Firestore map 매핑이 Flutter SoapNote.fromFirestore/toFirestore와
/// 호환되는지 검증한다. 양쪽 앱이 같은 Firestore 문서를 무손실로 읽고 쓸 수 있어야 한다.
///
/// 호환 기준은 docs/firestore_schema.md에 정의되어 있다.
final class SoapNoteFirestoreCompatTests: XCTestCase {

  // MARK: - 정체성 필드 (Firestore Rule 평가에 필수)

  func testFirestoreMapContainsIdentityFieldsRequiredByRules() {
    let note = makeNote()
    let map = FirebaseTrainerRepository.firestoreMap(for: note)

    XCTAssertEqual(map["trainerId"] as? String, "trainer-1")
    XCTAssertEqual(map["memberId"] as? String, "member-1")
    XCTAssertEqual(map["isSharedWithMember"] as? Bool, true)
    XCTAssertNotNil(map["date"] as? Int, "date는 ms epoch int로 직렬화되어야 한다")
  }

  // MARK: - 레거시 평탄 필드 (Flutter SoapNote.fromFirestore 호환)

  func testFirestoreMapPreservesLegacyFlatFields() {
    let note = makeNote(
      subjective: "스쿼트 하강 시 허리 불편",
      objective: "Hip hinge 제한",
      assessment: "요추 과신전",
      plan: "dead bug 2세트"
    )
    let map = FirebaseTrainerRepository.firestoreMap(for: note)

    XCTAssertEqual(map["subjective"] as? String, "스쿼트 하강 시 허리 불편")
    // SwiftUI의 'objective'는 Flutter의 'observation' 필드로 매핑
    XCTAssertEqual(map["observation"] as? String, "Hip hinge 제한")
    XCTAssertEqual(map["assessment"] as? String, "요추 과신전")
    // SwiftUI의 'plan'은 Flutter의 'treatmentPlan' 필드로 매핑
    XCTAssertEqual(map["treatmentPlan"] as? String, "dead bug 2세트")
    XCTAssertEqual(map["painNow"] as? Int, 6)
  }

  // MARK: - structured 필드 구조

  func testFirestoreMapBuildsStructuredCategoryMaps() {
    let note = makeNote(subjective: "통증 호소", objective: "ROM 제한")
    let map = FirebaseTrainerRepository.firestoreMap(for: note)
    let structured = map["structured"] as? [String: Any]

    XCTAssertNotNil(structured, "structured 필드가 누락되었다")
    let subjective = structured?["subjective"] as? [String: Any]
    XCTAssertEqual(subjective?["chiefComplaint"] as? String, "통증 호소")
    let objective = structured?["objective"] as? [String: Any]
    XCTAssertEqual(objective?["observation"] as? String, "ROM 제한")
  }

  // MARK: - RiskLevel/Status 매핑

  func testRiskLevelMappingsFollowFlutterConvention() {
    let stable = makeNote(risk: .stable)
    let attention = makeNote(risk: .attention)
    let high = makeNote(risk: .high)

    let stableWorkflow = (FirebaseTrainerRepository.firestoreMap(for: stable)["structured"] as? [String: Any])?["workflow"] as? [String: Any]
    let attentionWorkflow = (FirebaseTrainerRepository.firestoreMap(for: attention)["structured"] as? [String: Any])?["workflow"] as? [String: Any]
    let highWorkflow = (FirebaseTrainerRepository.firestoreMap(for: high)["structured"] as? [String: Any])?["workflow"] as? [String: Any]

    XCTAssertEqual(stableWorkflow?["riskLevel"] as? String, "low")
    XCTAssertEqual(attentionWorkflow?["riskLevel"] as? String, "medium")
    XCTAssertEqual(highWorkflow?["riskLevel"] as? String, "high")
  }

  // MARK: - Round-trip

  func testEncodeThenDecodePreservesCoreFields() throws {
    let original = makeNote(
      subjective: "S 본문",
      objective: "O 본문",
      assessment: "A 본문",
      plan: "P 본문",
      risk: .high,
      metrics: [
        SoapMetric(type: .rom, label: "고관절 굴곡", side: .bilateral, value: 110, unit: "도", score: nil, note: ""),
        SoapMetric(type: .mmt, label: "둔근", side: .right, value: nil, unit: "", score: 4, note: "초기 수축 지연")
      ]
    )

    let map = FirebaseTrainerRepository.firestoreMap(for: original)
    let decoded = try XCTUnwrap(FirebaseTrainerRepository.soapNote(from: map, id: original.id))

    XCTAssertEqual(decoded.id, original.id)
    XCTAssertEqual(decoded.memberId, original.memberId)
    XCTAssertEqual(decoded.trainerId, original.trainerId)
    XCTAssertEqual(decoded.subjective, original.subjective)
    XCTAssertEqual(decoded.objective, original.objective)
    XCTAssertEqual(decoded.assessment, original.assessment)
    XCTAssertEqual(decoded.plan, original.plan)
    XCTAssertEqual(decoded.pain, original.pain)
    XCTAssertEqual(decoded.workflow.riskLevel, original.workflow.riskLevel)
    XCTAssertEqual(decoded.metrics.count, original.metrics.count)
    XCTAssertEqual(decoded.isSharedWithMember, original.isSharedWithMember)
  }

  // MARK: - Helpers

  private func makeNote(
    subjective: String = "기본 S",
    objective: String = "기본 O",
    assessment: String = "기본 A",
    plan: String = "기본 P",
    risk: RiskLevel = .attention,
    metrics: [SoapMetric] = []
  ) -> SoapNote {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    return SoapNote(
      id: "note-1",
      memberId: "member-1",
      dateLabel: "오늘",
      bodyRegion: "허리",
      pain: 6,
      subjective: subjective,
      objective: objective,
      assessment: assessment,
      plan: plan,
      metrics: metrics,
      workflow: SoapWorkflow(
        status: .draft,
        completedCategories: ["S", "O"],
        riskLevel: risk,
        followUpDate: nil
      ),
      drawingData: nil,
      trainerId: "trainer-1",
      trainerName: "트레이너 김",
      memberName: "회원 박",
      memberEmail: "park@example.com",
      date: now,
      isSharedWithMember: true,
      createdAt: now,
      updatedAt: now
    )
  }
}
