import Foundation
import Combine

protocol TrainerRepository: AnyObject {
  func loadMembers() -> [TrainerMember]
  func loadSoapNotes(memberId: String) -> [SoapNote]
  @discardableResult func saveSoapDraft(_ draft: SoapDraft) -> SoapNote
  func deleteSoapNote(id: String)
  func dashboardSummary() -> TrainerDashboardSummary

  /// 데이터 캐시가 갱신될 때마다 Void 신호를 발행.
  /// PreviewTrainerRepository는 빈 publisher를, FirebaseTrainerRepository는
  /// snapshotListener 콜백마다 신호를 발행한다.
  var changes: AnyPublisher<Void, Never> { get }
}
