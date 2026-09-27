import Foundation
import TrainerContracts
import TrainerDomain
import XCTest
@testable import FeatureConsent

/// DF-110 MVP: the TR-14 consent step model (AC-DF-110.2, AC-DF-110.3 and the result chip). Synthetic data only.
@MainActor
final class ConsentStepModelTests: XCTestCase {
  private let member = MemberKey.pending("SynthPending00000001")

  private struct Catalog: ConsentDocumentCatalog {
    var result: Result<[ConsentDocumentVersion], RemoteError>
    func publishedDocuments() async throws -> [ConsentDocumentVersion] { try result.get() }

    static func versions(_ types: [ConsentType] = ConsentType.allCases, version: String = "1.0") -> Catalog {
      Catalog(result: .success(types.map {
        ConsentDocumentVersion(id: "\($0.rawValue)--\(version)", consentType: $0, version: version,
                               publishedAt: Date(timeIntervalSince1970: 1_793_577_600))
      }))
    }
  }

  private final class Recorder: ConsentCaptureRecorder, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls: [(MemberKey, [ConsentSelection])] = []
    let fails: Bool
    init(fails: Bool = false) { self.fails = fails }
    var calls: [(member: MemberKey, selections: [ConsentSelection])] { lock.withLock { _calls } }
    func capture(member: MemberKey, selections: [ConsentSelection]) async throws -> String {
      lock.withLock { _calls.append((member, selections)) }
      if fails { throw NSError(domain: "synthetic", code: 1) }
      return "3f2b8c1e-5d7a-4b1e-9a51-0c8e2d7f1a90"
    }
  }

  private final class Consent: EffectiveConsentSource, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: AsyncStream<EffectiveConsent>.Continuation?
    func observe(member: MemberKey) -> AsyncStream<EffectiveConsent> {
      AsyncStream { continuation in lock.withLock { self.continuation = continuation } }
    }
    func send(_ value: EffectiveConsent) { lock.withLock { continuation }?.yield(value) }
    var hasObserver: Bool { lock.withLock { continuation != nil } }
  }

  private func model(_ catalog: Catalog = .versions(), recorder: Recorder = Recorder(),
                     consent: Consent = Consent()) -> ConsentStepModel {
    ConsentStepModel(member: member, documents: catalog, recorder: recorder, consent: consent)
  }

  /// AC-DF-110.2: no answer is preselected and nothing can be submitted before ①②③ are all answered.
  func test_AC_DF_110_2_nothingIsPreselected() async {
    let model = model()
    XCTAssertEqual(model.phase, .loading)
    await model.load()
    XCTAssertEqual(model.phase, .choosing)
    XCTAssertEqual(model.types, [.required, .healthData, .bodyImaging], "④⑤ are not asked in the MVP")
    XCTAssertEqual(model.choices, [:])
    XCTAssertFalse(model.canSubmit)
    model.choose(.grant, for: .required)
    model.choose(.grant, for: .healthData)
    XCTAssertFalse(model.canSubmit, "③ unanswered")
    model.choose(.refuse, for: .bodyImaging)
    XCTAssertTrue(model.canSubmit)
    model.choose(.grant, for: .sharing)
    XCTAssertNil(model.choices[.sharing], "not a card")
  }

  /// AC-DF-110.3: a core type without a published version stops the step; nothing can be captured.
  func test_AC_DF_110_3_aMissingDocumentStopsTheStep() async {
    let model = model(.versions([.required, .healthData]))
    await model.load()
    XCTAssertEqual(model.phase, .documentMissing)
    model.choose(.grant, for: .required)
    XCTAssertEqual(model.choices, [:])
    XCTAssertFalse(model.canSubmit)
  }

  func testLoadFailuresAreNotShownAsMissingDocuments() async {
    let offline = model(Catalog(result: .failure(.unavailable)))
    await offline.load()
    XCTAssertEqual(offline.phase, .loadFailed(onlineRequired: true))
    let denied = model(Catalog(result: .failure(.permissionDenied)))
    await denied.load()
    XCTAssertEqual(denied.phase, .loadFailed(onlineRequired: false))
  }

  /// Granted cards are recorded with the newest published version; a refused card leaves no record.
  func testSubmitRecordsTheGrantsOnceWithTheirVersions() async {
    let recorder = Recorder()
    let model = model(.versions(), recorder: recorder)
    await model.load()
    model.choose(.grant, for: .required)
    model.choose(.refuse, for: .healthData)
    model.choose(.grant, for: .bodyImaging)
    await model.submit()
    XCTAssertEqual(model.phase, .saved)
    XCTAssertFalse(model.canSubmit, "saved once")
    XCTAssertEqual(recorder.calls.count, 1)
    XCTAssertEqual(recorder.calls.first?.member, member)
    XCTAssertEqual(recorder.calls.first?.selections, [
      ConsentSelection(consentType: .required, action: .grant, documentVersion: "required--1.0"),
      ConsentSelection(consentType: .bodyImaging, action: .grant, documentVersion: "bodyImaging--1.0"),
    ])
    await model.submit()
    XCTAssertEqual(recorder.calls.count, 1)
  }

  /// ① refused: `consent.requiredFirst` and nothing to submit (V1-06 V8).
  func testRequiredRefusedBlocksSubmitting() async {
    let recorder = Recorder()
    let model = model(recorder: recorder)
    await model.load()
    model.choose(.refuse, for: .required)
    model.choose(.grant, for: .healthData)
    model.choose(.grant, for: .bodyImaging)
    XCTAssertTrue(model.requiredRefused)
    XCTAssertFalse(model.canSubmit)
    await model.submit()
    XCTAssertTrue(recorder.calls.isEmpty)
    model.choose(.grant, for: .required)
    XCTAssertFalse(model.requiredRefused)
    XCTAssertTrue(model.canSubmit)
  }

  func testAFailedSaveKeepsTheAnswers() async {
    let model = model(recorder: Recorder(fails: true))
    await model.load()
    for type in model.types { model.choose(.grant, for: type) }
    await model.submit()
    XCTAssertTrue(model.saveFailed)
    XCTAssertEqual(model.phase, .choosing)
    XCTAssertEqual(model.choices.count, 3)
    XCTAssertTrue(model.canSubmit)
  }

  /// The result chip follows `EffectiveConsent.chipState` (DF-111): '동의 확인 대기' until the server confirms.
  func testTheChipFollowsTheEffectiveConsent() async {
    let consent = Consent()
    let model = model(consent: consent)
    let watch = Task { await model.watchConsent() }
    defer { watch.cancel() }
    await waitFor { consent.hasObserver }
    consent.send(EffectiveConsent(required: .awaitingConsent, healthData: .awaitingConsent,
                                  bodyImaging: .awaitingConsent))
    await waitFor { model.chip == .awaiting }
    XCTAssertEqual(model.chip, .awaiting)
    consent.send(EffectiveConsent(required: .granted, healthData: .granted, bodyImaging: .granted))
    await waitFor { model.chip == .coreGranted }
    XCTAssertEqual(model.chip, .coreGranted)
  }

  private func waitFor(_ condition: () -> Bool) async {
    for _ in 0..<200 where !condition() {
      try? await Task.sleep(nanoseconds: 10_000_000)
    }
  }
}
