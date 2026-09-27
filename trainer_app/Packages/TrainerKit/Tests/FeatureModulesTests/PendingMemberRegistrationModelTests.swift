import Foundation
import TrainerDomain
import XCTest
@testable import FeatureConsent

/// DF-108 (AC-DF-108.1, .2, .4): the TR-14 model. Synthetic data only.
@MainActor
final class PendingMemberRegistrationModelTests: XCTestCase {
  /// 2026-06-01 12:00 KST.
  private let now2026 = Date(timeIntervalSince1970: 1_780_282_800)

  private final class FakeRegistrar: PendingMemberRegistrar, @unchecked Sendable {
    private let lock = NSLock()
    private var _drafts: [PendingMemberDraft] = []
    let fails: Bool
    init(fails: Bool = false) { self.fails = fails }
    var drafts: [PendingMemberDraft] { lock.withLock { _drafts } }
    func register(_ draft: PendingMemberDraft) async throws -> String {
      lock.withLock { _drafts.append(draft) }
      if fails { throw NSError(domain: "synthetic", code: 1) }
      return "SynthPending00000001"
    }
  }

  private func model(_ registrar: FakeRegistrar) -> PendingMemberRegistrationModel {
    PendingMemberRegistrationModel(registrar: registrar, now: { [now2026] in now2026 })
  }

  func test_AC_DF_108_1_nothingIsPreselectedAndSaveStartsDisabled() {
    let model = model(FakeRegistrar())
    XCTAssertNil(model.draft.sex)
    XCTAssertNil(model.draft.birthYear)
    XCTAssertFalse(model.draft.ageConfirmed14)
    XCTAssertFalse(model.canSave)
    XCTAssertEqual(model.years.first, 2026)
    XCTAssertEqual(model.years.last, 1900)
  }

  func test_AC_DF_108_2_under14AndMissingConfirmationBlockSaving() {
    let model = model(FakeRegistrar())
    model.draft = PendingMemberDraft(displayName: "가상회원 가", sex: .male, birthYear: 2013, ageConfirmed14: true)
    XCTAssertTrue(model.showsUnder14Block)
    XCTAssertFalse(model.canSave)
    model.draft.birthYear = 2012
    XCTAssertTrue(model.showsUnder14Block, "2012 is blocked too (ASM-P1a-02)")
    model.draft.birthYear = 2011
    XCTAssertFalse(model.showsUnder14Block)
    XCTAssertTrue(model.canSave)
    model.draft.ageConfirmed14 = false
    XCTAssertFalse(model.canSave)
  }

  func test_AC_DF_108_4_saveReturnsThePendingMemberKey() async {
    let registrar = FakeRegistrar()
    let model = model(registrar)
    model.draft = PendingMemberDraft(displayName: "가상회원 가", sex: .unspecified, birthYear: 1990, ageConfirmed14: true)
    let member = await model.save()
    XCTAssertEqual(member, .pending("SynthPending00000001"))
    XCTAssertEqual(registrar.drafts.count, 1)
    XCTAssertFalse(model.saveFailed)
  }

  func testAFailedSaveKeepsTheDraftAndSaysSo() async {
    let model = model(FakeRegistrar(fails: true))
    model.draft = PendingMemberDraft(displayName: "가상회원 가", sex: .female, birthYear: 1990, ageConfirmed14: true)
    let member = await model.save()
    XCTAssertNil(member)
    XCTAssertTrue(model.saveFailed)
    XCTAssertEqual(model.draft.displayName, "가상회원 가")
    XCTAssertTrue(model.canSave, "the trainer can try again")
  }

  func testAnInvalidDraftIsNeverSent() async {
    let registrar = FakeRegistrar()
    let model = model(registrar)
    model.draft = PendingMemberDraft(displayName: "", sex: .female, birthYear: 1990, ageConfirmed14: true)
    let member = await model.save()
    XCTAssertNil(member)
    XCTAssertTrue(registrar.drafts.isEmpty)
  }
}
