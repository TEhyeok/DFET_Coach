import XCTest
@testable import D_FET_Trainer

final class TrainerRepositoryTests: XCTestCase {
  func testDashboardSummaryAggregatesPreviewMembers() {
    let repository = PreviewTrainerRepository()
    let summary = repository.dashboardSummary()

    XCTAssertEqual(repository.loadMembers().count, 3)
    XCTAssertEqual(summary.managedMemberCount, 3)
    XCTAssertEqual(summary.attentionMemberCount, 2)
    XCTAssertEqual(summary.todaySessionCount, 6)
    XCTAssertEqual(summary.soapTodoCount, 3)
    XCTAssertEqual(summary.averagePain, 5.0, accuracy: 0.01)
  }

  func testSaveDraftCreatesStructuredSoapNote() {
    let repository = PreviewTrainerRepository()
    let member = repository.loadMembers()[0]
    var draft = SoapDraft(member: member)
    draft.pain = 4
    draft.risk = .attention
    draft.metrics.append(
      SoapMetric(type: .functional, label: "스쿼트 패턴", side: .bilateral, value: nil, unit: "", score: 3, note: "무릎 정렬 cue 필요")
    )

    let note = repository.saveSoapDraft(draft)
    let notes = repository.loadSoapNotes(memberId: member.id)

    XCTAssertEqual(note.pain, 4)
    XCTAssertTrue(note.metrics.contains { $0.type == .functional })
    XCTAssertEqual(notes.first?.id, note.id)
    XCTAssertEqual(repository.loadMembers()[0].lastSoap, "오늘")
  }

  func testDeleteSoapNoteRemovesSavedNote() {
    let repository = PreviewTrainerRepository()
    let member = repository.loadMembers()[0]
    let note = repository.saveSoapDraft(SoapDraft(member: member))

    repository.deleteSoapNote(id: note.id)

    XCTAssertFalse(repository.loadSoapNotes(memberId: member.id).contains { $0.id == note.id })
  }

  func testWidgetSnapshotCodableRoundTrip() throws {
    let snapshot = TrainerWidgetSnapshot(todaySessions: 4, soapTodoCount: 2, reassessmentCount: 1, averagePain: 3.5, generatedAtLabel: "테스트")
    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(TrainerWidgetSnapshot.self, from: data)

    XCTAssertEqual(decoded, snapshot)
  }
}
