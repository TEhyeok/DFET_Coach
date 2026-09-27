import FeatureConsent
import Foundation
import TrainerContracts
import TrainerDomain
import XCTest

@MainActor
final class ConsentFlowModelTests: XCTestCase {
  func testAC_DF_110_2_noPreselectionAndEachCardNeedsAnAnswer() async {
    let service = TestConsentService()
    let model = ConsentFlowModel(member: .pending("SYNTHpending00000001"), service: service)
    await model.start()
    defer { model.stop() }
    model.beginChoices()
    XCTAssertTrue(model.selections.isEmpty)
    XCTAssertFalse(model.canSubmit)
    model.choose(.required, granted: true)
    model.choose(.healthData, granted: true)
    XCTAssertFalse(model.canSubmit)
    model.choose(.bodyImaging, granted: false)
    XCTAssertTrue(model.canSubmit)
    await model.submit()
    XCTAssertEqual(model.stage, .finished)
    XCTAssertTrue(model.didCapture)
    XCTAssertEqual(service.capturedAnswers, [
      .init(type: .required, granted: true), .init(type: .healthData, granted: true), .init(type: .bodyImaging, granted: false),
    ])
    XCTAssertEqual(service.capturedVersions[.healthData], "healthData--test-1", "Send document ID, not display version")
  }

  func testAC_DF_110_3_missingPublishedTypeStopsBeforeCapture() async {
    let service = TestConsentService(documents: TestConsentService.documents.filter { $0.consentType != .bodyImaging })
    let model = ConsentFlowModel(member: .pending("SYNTHpending00000001"), service: service)
    await model.start()
    defer { model.stop() }
    model.beginChoices()
    XCTAssertEqual(model.documentState, .missing)
    XCTAssertEqual(model.stage, .handoff)
    XCTAssertFalse(model.canSubmit)
    await model.submit()
    XCTAssertEqual(service.captureCount, 0)
  }

  func testAC_DF_110_5_requiredRefusalConfirmsCancellationWithoutConsentRecord() async {
    let service = TestConsentService()
    let model = ConsentFlowModel(member: .pending("SYNTHpending00000001"), service: service)
    await model.start()
    defer { model.stop() }
    model.beginChoices()
    model.choose(.required, granted: false)
    await model.submit()
    XCTAssertTrue(model.showsRequiredRefusalConfirmation)
    XCTAssertEqual(service.cancelCount, 0)
    XCTAssertEqual(service.captureCount, 0)
    await model.confirmRequiredRefusal()
    XCTAssertEqual(service.cancelCount, 1)
    XCTAssertEqual(service.captureCount, 0)
    XCTAssertEqual(model.stage, .cancelled)
  }

  func testFailedLocalSaveKeepsAnswersAndAllowsRetry() async {
    let service = TestConsentService()
    service.setFailure(true)
    let model = ConsentFlowModel(member: .pending("SYNTHpending00000001"), service: service)
    await model.start()
    defer { model.stop() }
    model.beginChoices()
    for type in ConsentFlowRules.coreTypes { model.choose(type, granted: true) }
    await model.submit()
    XCTAssertTrue(model.saveFailed)
    XCTAssertEqual(model.selections.count, 3)
    XCTAssertEqual(model.stage, .choices)
    XCTAssertTrue(model.canSubmit)
    service.setFailure(false)
    await model.submit()
    XCTAssertEqual(model.stage, .finished)
  }

  func testExistingGrantIsReadOnlyAndIsNotCapturedAgain() async {
    let service = TestConsentService(initial: .init(required: .granted, healthData: .granted, bodyImaging: .missing))
    let model = ConsentFlowModel(member: .pending("SYNTHpending00000001"), service: service)
    await model.start()
    defer { model.stop() }
    for _ in 0..<100 where model.effectiveConsent.required != .granted { await Task.yield() }
    XCTAssertEqual(model.effectiveConsent.required, .granted)
    model.beginChoices()
    model.choose(.required, granted: false)
    model.choose(.healthData, granted: false)
    XCTAssertTrue(model.selections.isEmpty, "An existing grant is status, not a preselected answer or a withdrawal")
    model.choose(.bodyImaging, granted: true)
    await model.submit()
    XCTAssertEqual(service.capturedAnswers, [.init(type: .bodyImaging, granted: true)])
    XCTAssertEqual(service.cancelCount, 0)
  }

  func testMVPDoesNotOpenRegisteredMemberConsentCapture() async {
    let model = ConsentFlowModel(member: .uid("synthMember0001"), service: TestConsentService())
    await model.start()
    XCTAssertFalse(model.supportsMember)
    XCTAssertFalse(model.canSubmit)
    XCTAssertEqual(model.documentState, .missing)
  }
}

private final class TestConsentService: ConsentService, @unchecked Sendable {
  private let lock = NSLock()
  private let docs: [ConsentDocumentVersion]
  private let initial: EffectiveConsent
  private var failure = false
  private var answers: [ConsentSelection] = []
  private var versions: [ConsentType: String] = [:]
  private var captures = 0
  private var cancellations = 0

  init(documents: [ConsentDocumentVersion] = TestConsentService.documents, initial: EffectiveConsent = .none) {
    docs = documents
    self.initial = initial
  }

  var capturedAnswers: [ConsentSelection] { lock.withLock { answers } }
  var capturedVersions: [ConsentType: String] { lock.withLock { versions } }
  var captureCount: Int { lock.withLock { captures } }
  var cancelCount: Int { lock.withLock { cancellations } }
  func setFailure(_ value: Bool) { lock.withLock { failure = value } }

  func publishedDocuments() async throws -> [ConsentDocumentVersion] { docs }
  func observe(member: MemberKey) -> AsyncStream<EffectiveConsent> { AsyncStream { $0.yield(initial) } }
  func captureInPerson(member: MemberKey, selections: [ConsentSelection], documentVersions: [ConsentType: String]) async throws {
    try lock.withLock {
      if failure { throw ConsentServiceError.unavailable }
      answers = selections
      versions = documentVersions
      captures += 1
    }
  }
  func cancelPending(member: MemberKey) async throws { lock.withLock { cancellations += 1 } }

  static let documents = ConsentFlowRules.coreTypes.map {
    ConsentDocumentVersion(id: $0.rawValue + "--test-1", consentType: $0, version: "test-1", title: "합성 동의 문서",
      purpose: "합성 테스트 목적", items: ["합성 항목"], retention: "테스트 종료 시", refusalNotice: "합성 거부 안내",
      privacyPolicyVersion: "test-policy", publishedAt: Date(timeIntervalSince1970: 1_800_000_000))
  }
}
