import Foundation
import SyncEngine
import TrainerContracts
import TrainerDomain
import XCTest

final class EffectiveConsentResolverTests: XCTestCase {
  func testTC_111_06_serverAndLocalCaptureTableForEveryCoreType() {
    for type in ConsentFlowRules.coreTypes {
      for serverGranted in [false, true] {
        let server = ConsentState(entries: [type: .init(granted: serverGranted, documentVersion: "test-v1")])
        XCTAssertEqual(EffectiveConsentResolver.resolve(server: server, captures: [])[type], serverGranted ? .granted : .missing)
        for state in [ConsentCaptureSnapshot.State.pending, .failed] {
          let capture = snapshot(type: type, state: state, at: 1)
          let actual = EffectiveConsentResolver.resolve(server: server, captures: [capture])[type]
          XCTAssertEqual(actual, serverGranted ? .granted : (state == .pending ? .awaitingConsent : .rejected))
        }
      }
    }
    XCTAssertEqual(EffectiveConsentResolver.resolve(server: nil, captures: []), .none)
  }

  func testTC_111_06_latestCaptureOfEachTypeWinsAndRefusalNeverGrants() {
    let required = snapshot(type: .required, state: .pending, at: 1)
    let health = snapshot(type: .healthData, state: .pending, at: 1)
    let failedHealth = snapshot(type: .healthData, state: .failed, at: 2)
    let refusedPhoto = snapshot(type: .bodyImaging, state: .pending, at: 3, granted: false)
    let consent = EffectiveConsentResolver.resolve(server: nil, captures: [required, health, failedHealth, refusedPhoto])
    XCTAssertEqual(consent.required, .awaitingConsent)
    XCTAssertEqual(consent.healthData, .rejected)
    XCTAssertEqual(consent.bodyImaging, .missing)
    XCTAssertFalse(consent.canSaveHealthRecord)
  }

  func testAC_DF_111_2_localGrantAllowsLocalRecordButNeverPhoto() {
    let captures = ConsentFlowRules.coreTypes.map { snapshot(type: $0, state: .pending, at: 1) }
    let pending = EffectiveConsentResolver.resolve(server: nil, captures: captures)
    XCTAssertEqual(pending.chipState, .awaiting)
    XCTAssertEqual(pending.healthRecordSave, .localOnly)
    XCTAssertFalse(pending.canAttachPhoto)
    XCTAssertFalse(pending.canCapturePosture)
    let server = ConsentState(entries: Dictionary(uniqueKeysWithValues: ConsentType.allCases.map {
      ($0, ConsentStateEntry(granted: true, documentVersion: "test"))
    }))
    let confirmed = EffectiveConsentResolver.resolve(server: server, captures: captures)
    XCTAssertTrue(confirmed.coreGranted)
    XCTAssertTrue(confirmed.canAttachPhoto)
    XCTAssertTrue(confirmed.canCapturePosture)
    XCTAssertEqual(confirmed[.sharing], .missing)
    XCTAssertEqual(confirmed[.research], .missing)
  }

  private func snapshot(type: ConsentType, state: ConsentCaptureSnapshot.State, at: TimeInterval,
                        granted: Bool = true) -> ConsentCaptureSnapshot {
    ConsentCaptureSnapshot(id: UUID(), selections: [.init(type: type, granted: granted)], state: state,
                           capturedAt: Date(timeIntervalSince1970: at))
  }
}
