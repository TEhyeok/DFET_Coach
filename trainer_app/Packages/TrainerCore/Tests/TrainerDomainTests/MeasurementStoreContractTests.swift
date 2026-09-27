import Foundation
import TrainerContracts
import XCTest
@testable import TrainerDomain

/// The TR-11 store and consent read protocols are implementable by a plain Sendable type (the LocalStore and
/// SyncEngine implementations arrive with the integration). Synthetic values only.
final class MeasurementStoreContractTests: XCTestCase {
  private actor FakeStore: MeasurementStore, EffectiveConsentSource {
    var saved: [(MemberKey, BodyCompositionEntry)] = []
    let consent: EffectiveConsent
    let now: Date

    init(consent: EffectiveConsent, now: Date) {
      self.consent = consent
      self.now = now
    }

    func saveBodyComposition(member: MemberKey, draft: BodyCompositionDraft) async throws -> String {
      guard consent.canSaveHealthRecord else { throw MeasurementStoreError.consentRequired(.healthData) }
      let validation = BodyCompositionValidator.validate(draft, now: now)
      guard let entry = validation.entry else { throw MeasurementStoreError.invalidDraft(validation.errors) }
      saved.append((member, entry))
      return "SYNTHbc\(saved.count)"
    }

    nonisolated func observeBodyCompositionRecords(member: MemberKey, since: Date)
      -> AsyncThrowingStream<[BodyCompositionRecord], Error>
    {
      AsyncThrowingStream { $0.finish() }
    }

    nonisolated func observeSeries(member: MemberKey, metricCode: MetricCode, since: Date)
      -> AsyncThrowingStream<[SeriesPoint], Error>
    {
      AsyncThrowingStream { $0.finish() }
    }

    nonisolated func observe(member: MemberKey) -> AsyncStream<EffectiveConsent> {
      let value = consent
      return AsyncStream { continuation in
        continuation.yield(value)
        continuation.finish()
      }
    }
  }

  private let now = FixtureTimestamp.parse("2026-12-07T09:00:00+09:00")!

  func testAFakeStoreSavesOnlyValidDraftsWithConsent() async throws {
    let draft = BodyCompositionDraft(values: [.weightKg: "62,4"], deviceModel: "InBody 570",
                                     measuredAt: now.addingTimeInterval(-600), fasting: .yes)
    let store = FakeStore(consent: EffectiveConsent(required: .granted, healthData: .awaitingConsent, bodyImaging: .missing),
                          now: now)
    let id = try await store.saveBodyComposition(member: .pending("p"), draft: draft)
    XCTAssertEqual(id, "SYNTHbc1")

    var bad = draft
    bad.fasting = nil
    do {
      _ = try await store.saveBodyComposition(member: .pending("p"), draft: bad)
      XCTFail("expected invalidDraft")
    } catch let error as MeasurementStoreError {
      XCTAssertEqual(error, .invalidDraft([.fastingMissing]))
    }

    let blocked = FakeStore(consent: .none, now: now)
    do {
      _ = try await blocked.saveBodyComposition(member: .uid("u"), draft: draft)
      XCTFail("expected consentRequired")
    } catch let error as MeasurementStoreError {
      XCTAssertEqual(error, .consentRequired(.healthData))
    }

    var received: [EffectiveConsent] = []
    for await value in store.observe(member: .pending("p")) { received.append(value) }
    XCTAssertEqual(received.map(\.healthRecordSave), [.localOnly])
  }
}
