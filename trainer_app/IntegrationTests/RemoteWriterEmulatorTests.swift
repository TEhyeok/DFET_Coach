import FirebaseAuth
import Foundation
import TrainerDomain
import XCTest
@testable import DFETTrainer

/// DF-104 against the Firestore emulator with the repository's rules (PR #173 review probes P1-P5): the writer
/// creates, reconciles a create and a void sent again after a lost reply, and treats a missing document's delete as
/// done. The rest of the error-injection matrix is DF-107. Synthetic data only; every run uses its own trainer.
final class RemoteWriterEmulatorTests: XCTestCase {
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

  func testWritesAndReconciliationUnderTheRules() async throws {
    let trainer = try await EmulatorAccounts.create(claims: ["trainer": true])
    let member = "it-\(trainer.uid.prefix(8))-m01"
    try await seedAssignment(trainer: trainer.uid, member: member)
    _ = try await AppBootstrap.liveAuthService().signIn(email: trainer.email, password: trainer.password)
    let writer = AppBootstrap.liveRemoteWriter(trainerUid: trainer.uid)
    let path = "bodyCompositionRecords/it-\(UUID().uuidString.lowercased())"
    let record = bodyComposition(trainer: trainer.uid, member: member)

    // P1: a first create does not depend on reading the missing document.
    let created = try await writer.createIfAbsent(path: path, fields: record)
    XCTAssertTrue(created.serverCommitted)
    // P3: the same create sent again (the reply was lost) is denied as an update and reconciled.
    let again = try await writer.createIfAbsent(path: path, fields: record)
    XCTAssertTrue(again.serverCommitted, "a create sent again is reconciled, not failed")

    // P5: a void sent again is denied (voided records are frozen) and reconciled.
    let void = JSONValue.object([
      "status": .string("voided"), "voidedAt": .serverTimestamp, "voidReason": .string("합성 무효 사유"),
    ])
    let voided = try await writer.update(path: path, fields: void)
    XCTAssertTrue(voided.serverCommitted)
    let voidedAgain = try await writer.update(path: path, fields: void)
    XCTAssertTrue(voidedAgain.serverCommitted, "a void sent again is reconciled")

    // A different change to the frozen record stays denied.
    do {
      _ = try await writer.update(path: path, fields: .object(["voidReason": .string("다른 합성 사유")]))
      XCTFail("expected permissionDenied")
    } catch {
      XCTAssertEqual(error as? RemoteError, .permissionDenied)
    }

    // P4: deleting a document that does not exist is denied by the rules and reconciled as done.
    let deleted = try await writer.delete(path: "soap_notes/it-missing-\(UUID().uuidString.lowercased())")
    XCTAssertTrue(deleted.serverCommitted)
  }

  private func seedAssignment(trainer: String, member: String) async throws {
    try await EmulatorDocuments.put("trainers/\(trainer)", [
      "trainerId": trainer, "memberIds": [member], "approvalStatus": "approved",
    ])
    let past = Date().addingTimeInterval(-86_400)
    try await EmulatorDocuments.put("memberConsentStates/\(member)", [
      "updatedAt": past, "schemaVersion": 1,
      "required": ["granted": true, "updatedAt": past] as [String: Any],
      "healthData": ["granted": true, "updatedAt": past] as [String: Any],
    ])
    try await EmulatorDocuments.put("appConfig/features", [
      "gut": false, "blood": false, "insights": false, "soapV2": true, "bodyComposition": true,
      "bodyAssessment": true, "memberShare": true, "lidarBeta": false,
    ])
  }

  private func bodyComposition(trainer: String, member: String) -> JSONValue {
    .object([
      "memberUid": .string(member), "trainerId": .string(trainer), "enteredBy": .string(trainer),
      "source": .string("manualEntry"), "sourceGrade": .string("device"), "deviceModel": .string("합성 체성분 기기"),
      "measuredAt": .timestamp(Date().addingTimeInterval(-3_600)), "fasting": .string("yes"),
      "timeOfDayBand": .string("morning"),
      "values": .object(["weightKg": .number(70.5), "bodyFatPercent": .number(22.4)]),
      "status": .string("active"), "legalNature": .string("coachingRecord"), "schemaVersion": .int(1),
    ])
  }
}
