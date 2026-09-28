import FirebaseAuth
import Foundation
import TrainerContracts
import TrainerDomain
import XCTest
@testable import DFETTrainer

/// DF-127 TC-127-03 and TC-127-05 (AC-DF-127.2, .4) with the DF-130 read path, against the Auth and Firestore
/// emulators and the repository rules: a TR-11 save goes through LocalStore + Outbox + SyncEngine + FirebaseData and the
/// rules accept it; `measuredAt` yesterday stays yesterday with a server `createdAt`; the trend query reads it back;
/// without consent ② the store refuses before anything is queued; TR-11's latest-record read reaches before the trend
/// window. Synthetic data only; every run uses its own trainer, member and LocalStore partition.
final class BodyCompositionEmulatorTests: XCTestCase {
  private var configured = false

  override func setUpWithError() throws {
    try IntegrationEmulator.require("DFET_AUTH_EMULATOR", "DFET_FIRESTORE_EMULATOR")
    try IntegrationEmulator.configure()
    configured = true
    try? Auth.auth().signOut()
  }

  override func tearDownWithError() throws {
    guard configured else { return }
    try? Auth.auth().signOut()
  }

  /// A signed-in trainer with one assigned member whose consent ② is `healthData`, and `bodyComposition` on.
  @MainActor
  private func signedInTrainer(healthData: Bool) async throws -> (ShellServices, member: String) {
    let trainer = try await EmulatorAccounts.create(claims: ["trainer": true])
    let member = "it-member-" + UUID().uuidString.lowercased()
    try await EmulatorDocuments.put("trainers/\(trainer.uid)", [
      "trainerId": trainer.uid, "memberIds": [member], "approvalStatus": "approved",
    ])
    let granted: [String: Any] = ["granted": true, "documentVersion": "it-v1"]
    try await EmulatorDocuments.put("memberConsentStates/\(member)", [
      "required": granted, "healthData": ["granted": healthData, "documentVersion": "it-v1"], "bodyImaging": granted,
    ])
    try await EmulatorDocuments.put("appConfig/features", ["bodyComposition": true])
    let session = try await AppBootstrap.liveAuthService().signIn(email: trainer.email, password: trainer.password)
    return (AppBootstrap.liveServices(session: session), member)
  }

  @MainActor
  func testASaveReachesTheServerAndTheTrendReadsIt_TC_127_03() async throws {
    let (services, member) = try await signedInTrainer(healthData: true)
    let yesterday = Date().addingTimeInterval(-86_400)
    let draft = BodyCompositionDraft(values: [.weightKg: "62,4"], deviceModel: "IT Device", measuredAt: yesterday,
                                     fasting: .yes)
    let id = try await services.bodyComposition.store.saveBodyComposition(member: .uid(member), draft: draft)
    XCTAssertTrue(DocumentID.isValid(id))

    var fields: [String: Any]?
    for _ in 0..<150 where fields == nil {
      fields = try await EmulatorDocuments.get("bodyCompositionRecords/\(id)")
      if fields == nil { try await Task.sleep(nanoseconds: 100_000_000) }
    }
    let stored = try XCTUnwrap(fields, "the Outbox did not create bodyCompositionRecords/\(id)")
    XCTAssertEqual(Set(stored.keys), BodyCompositionPayload.documentKeys.subtracting(["derived"]), "no height, no derived")
    XCTAssertEqual((stored["memberUid"] as? [String: Any])?["stringValue"] as? String, member)
    XCTAssertEqual((stored["deviceModel"] as? [String: Any])?["stringValue"] as? String, "IT Device")
    let values = (stored["values"] as? [String: Any])?["mapValue"] as? [String: Any]
    let valueFields = try XCTUnwrap(values?["fields"] as? [String: Any])
    XCTAssertEqual(Set(valueFields.keys), ["weightKg"], "only the measured key (AC-DF-127.6)")
    XCTAssertEqual((valueFields["weightKg"] as? [String: Any])?["doubleValue"] as? Double, 62.4)
    // AC-DF-127.2: measuredAt is the entered time (yesterday); createdAt is the server's (now).
    func date(_ key: String) -> Date? {
      // REST timestamps carry up to nanoseconds; seconds are enough here.
      ((stored[key] as? [String: Any])?["timestampValue"] as? String).flatMap {
        ISO8601DateFormatter().date(from: $0.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression))
      }
    }
    let measuredAt = try XCTUnwrap(date("measuredAt"))
    let createdAt = try XCTUnwrap(date("createdAt"))
    XCTAssertEqual(measuredAt.timeIntervalSince1970, yesterday.timeIntervalSince1970, accuracy: 1)
    XCTAssertGreaterThan(createdAt.timeIntervalSince(measuredAt), 80_000)

    // DF-130: the trend's Firestore query (existing index shape) reads it back from the server.
    let since = Date().addingTimeInterval(-365 * 86_400)
    var fromServer = false
    for _ in 0..<50 where !fromServer {
      let records = try await firstValue(
        of: services.bodyComposition.store.observeBodyCompositionRecords(member: .uid(member), since: since))
      fromServer = records?.contains { $0.id == id && $0.createdAt != nil } == true
      if !fromServer { try await Task.sleep(nanoseconds: 200_000_000) }
    }
    XCTAssertTrue(fromServer, "the record was not read back through the trend query")
  }

  /// DF-127 second review: TR-11's default device and height come from the member's latest active record at any date,
  /// read through the rules with the trend's index shape (no `since`). Records 14 and 13 months ago, the later one
  /// voided: the answer is the older, active one.
  @MainActor
  func testTheLatestActiveRecordIsReadFromBeforeTheTrendWindow() async throws {
    let (services, member) = try await signedInTrainer(healthData: true)
    let trainer = try XCTUnwrap(Auth.auth().currentUser?.uid)
    func put(_ id: String, monthsAgo: Int, device: String, status: String) async throws {
      let measuredAt = try XCTUnwrap(Calendar(identifier: .gregorian).date(byAdding: .month, value: -monthsAgo, to: Date()))
      try await EmulatorDocuments.put("bodyCompositionRecords/\(id)", [
        "trainerId": trainer, "memberUid": member, "enteredBy": trainer, "source": "manualEntry", "sourceGrade": "device",
        "deviceModel": device, "measuredAt": measuredAt, "fasting": "yes", "timeOfDayBand": "morning",
        "values": ["weightKg": 70.5], "status": status, "legalNature": "coachingRecord", "schemaVersion": 1,
        "createdAt": measuredAt,
      ])
    }
    let active = DocumentID.make()
    try await put(active, monthsAgo: 14, device: "IT Old Device", status: "active")
    try await put(DocumentID.make(), monthsAgo: 13, device: "IT Voided Device", status: "voided")
    let latest = try await services.bodyComposition.store.latestActiveBodyComposition(member: .uid(member))
    XCTAssertEqual(latest?.id, active)
    XCTAssertEqual(latest?.deviceModel, "IT Old Device")
  }

  /// AC-DF-127.4: without ② the store refuses the save before anything reaches the Outbox or the server.
  @MainActor
  func testWithoutConsentTwoTheSaveIsRefused_TC_127_05() async throws {
    let (services, member) = try await signedInTrainer(healthData: false)
    let draft = BodyCompositionDraft(values: [.weightKg: "62.4"], deviceModel: "IT Device", measuredAt: Date(),
                                     fasting: .no)
    do {
      _ = try await services.bodyComposition.store.saveBodyComposition(member: .uid(member), draft: draft)
      XCTFail("expected consentRequired")
    } catch {
      XCTAssertEqual(error as? MeasurementStoreError, .consentRequired(.healthData))
    }
  }
}
