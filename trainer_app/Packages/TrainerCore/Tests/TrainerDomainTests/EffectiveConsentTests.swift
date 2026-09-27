import Foundation
import TrainerContracts
import XCTest
@testable import TrainerDomain

/// DF-111 MVP slice: the effective consent value every screen guard reads (DF-113 chip, DF-127 save, DF-128 photo,
/// DF-204 capture). Only ①②③ are resolved in the MVP; ④⑤ are always `.missing`. Synthetic values only.
final class EffectiveConsentTests: XCTestCase {
  private typealias V = EffectiveConsentValue

  func testSharingAndResearchAreAlwaysMissing() {
    let all = EffectiveConsent(required: .granted, healthData: .granted, bodyImaging: .granted)
    XCTAssertEqual(all[.required], .granted)
    XCTAssertEqual(all[.healthData], .granted)
    XCTAssertEqual(all[.bodyImaging], .granted)
    XCTAssertEqual(all[.sharing], .missing)
    XCTAssertEqual(all[.research], .missing)
    XCTAssertEqual(EffectiveConsent.none[.required], .missing)
  }

  /// Derived values (DF-111 MVP): `coreGranted`, `canAttachPhoto`, `canCapturePosture`, plus the DF-127 save gate.
  func testDerivedValues() {
    let cases: [(V, V, V, core: Bool, photo: Bool, posture: Bool, save: HealthRecordSaveGate, UInt)] = [
      (.granted, .granted, .granted, true, true, true, .allowed, #line),
      (.granted, .granted, .missing, false, true, false, .allowed, #line),
      (.granted, .granted, .awaitingConsent, false, true, false, .allowed, #line),
      (.granted, .awaitingConsent, .granted, false, false, false, .localOnly, #line),
      (.awaitingConsent, .awaitingConsent, .awaitingConsent, false, false, false, .localOnly, #line),
      (.granted, .missing, .granted, false, false, false, .blocked, #line),
      (.granted, .rejected, .granted, false, false, false, .blocked, #line),
      (.missing, .missing, .missing, false, false, false, .blocked, #line),
    ]
    for (r, h, b, core, photo, posture, save, line) in cases {
      let consent = EffectiveConsent(required: r, healthData: h, bodyImaging: b)
      XCTAssertEqual(consent.coreGranted, core, line: line)
      XCTAssertEqual(consent.canAttachPhoto, photo, line: line)
      XCTAssertEqual(consent.canCapturePosture, posture, line: line)
      XCTAssertEqual(consent.healthRecordSave, save, line: line)
      XCTAssertEqual(consent.canSaveHealthRecord, save != .blocked, line: line)
    }
  }

  /// TR-02 and TR-03 chip: '동의 ①②③' / '동의 필요' / '동의 확인 대기'. A rejected capture shows '동의 필요' in the MVP.
  func testChipState() {
    let cases: [(V, V, V, ConsentChipState, UInt)] = [
      (.granted, .granted, .granted, .coreGranted, #line),
      (.granted, .awaitingConsent, .granted, .awaiting, #line),
      (.awaitingConsent, .awaitingConsent, .awaitingConsent, .awaiting, #line),
      (.granted, .missing, .granted, .needed, #line),
      (.awaitingConsent, .missing, .awaitingConsent, .needed, #line),
      (.awaitingConsent, .rejected, .awaitingConsent, .needed, #line),
      (.missing, .missing, .missing, .needed, #line),
    ]
    for (r, h, b, chip, line) in cases {
      XCTAssertEqual(EffectiveConsent(required: r, healthData: h, bodyImaging: b).chipState, chip, line: line)
    }
    XCTAssertEqual(ConsentChipState.coreGranted.copyKey, "tr02.consent.ok")
    XCTAssertEqual(ConsentChipState.needed.copyKey, "tr02.consent.needed")
    XCTAssertEqual(ConsentChipState.awaiting.copyKey, "consent.state.awaiting")
  }

  /// Server state alone (no local capture layer yet): granted is granted, anything else is missing.
  func testServerOnlyResolution() {
    let state = ConsentState(entries: [
      .required: ConsentStateEntry(granted: true, documentVersion: "required--1.0"),
      .healthData: ConsentStateEntry(granted: true, documentVersion: "healthData--1.0"),
      .bodyImaging: ConsentStateEntry(granted: false, documentVersion: "bodyImaging--1.0"),
      .research: ConsentStateEntry(granted: true, documentVersion: "research--1.0"),
    ])
    let consent = EffectiveConsent(server: state)
    XCTAssertEqual(consent[.required], .granted)
    XCTAssertEqual(consent[.healthData], .granted)
    XCTAssertEqual(consent[.bodyImaging], .missing)
    XCTAssertEqual(consent[.research], .missing, "④⑤ are not resolved in the MVP")
    XCTAssertEqual(EffectiveConsent(server: nil), .none)
  }

  /// `memberConsentStates/{memberKey}` (V1-05 §4.12). No document means no consent at all.
  func testConsentStateParsesTheDocument() {
    let updated = FixtureTimestamp.parse("2026-11-16T10:02:00+09:00")!
    let document: JSONValue = .object([
      "required": .object(["granted": .bool(true), "documentVersion": .string("required--1.0"),
                           "updatedAt": .timestamp(updated), "recordId": .string("SYNTHconsentRec00000")]),
      "healthData": .object(["granted": .bool(true), "documentVersion": .string("healthData--1.0")]),
      "bodyImaging": .object(["granted": .bool(false), "documentVersion": .string("bodyImaging--1.0")]),
      "sharing": .object(["granted": .string("true")]),
      "research": .string("yes"),
      "updatedAt": .timestamp(updated),
      "schemaVersion": .int(1),
    ])
    let state = ConsentState(document: document)
    XCTAssertEqual(state[.required], ConsentStateEntry(granted: true, documentVersion: "required--1.0"))
    XCTAssertEqual(state[.healthData]?.granted, true)
    XCTAssertEqual(state[.bodyImaging], ConsentStateEntry(granted: false, documentVersion: "bodyImaging--1.0"))
    XCTAssertEqual(state[.sharing], ConsentStateEntry(granted: false, documentVersion: nil), "not a real boolean: not granted")
    XCTAssertNil(state[.research])
    XCTAssertTrue(state.isGranted(.required))
    XCTAssertFalse(state.isGranted(.bodyImaging))
    XCTAssertFalse(state.isGranted(.research))
    XCTAssertEqual(ConsentState(document: nil), ConsentState(entries: [:]))
  }

  func testGate() {
    let consent = EffectiveConsent(required: .granted, healthData: .awaitingConsent, bodyImaging: .missing)
    XCTAssertEqual(consent.gate(requires: [.healthData], allowAwaiting: true), .awaitingConsent)
    XCTAssertEqual(consent.gate(requires: [.healthData], allowAwaiting: false), .missing([.healthData]))
    XCTAssertEqual(consent.gate(requires: [.healthData, .bodyImaging], allowAwaiting: true), .missing([.bodyImaging]))
    XCTAssertEqual(consent.gate(requires: [.bodyImaging, .healthData], allowAwaiting: false),
                   .missing([.healthData, .bodyImaging]), "listed in ②③⑤ order")
    XCTAssertEqual(consent.gate(requires: [.required], allowAwaiting: false), .allowed)
    XCTAssertEqual(consent.gate(requires: [], allowAwaiting: false), .allowed)
  }
}
