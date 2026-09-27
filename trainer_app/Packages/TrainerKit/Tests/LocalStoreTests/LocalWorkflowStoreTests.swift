import Foundation
import SwiftData
import SyncEngine
import TrainerContracts
import TrainerDomain
import XCTest
@testable import LocalStore

/// Real LocalStore transactions and the live workflow service with synthetic protocol adapters only.
@MainActor
final class LocalWorkflowStoreTests: XCTestCase {
  private let member = MemberKey.pending("SYNTHpending00000001")
  private let versions: [ConsentType: String] = [
    .required: "required--test-1", .healthData: "healthData--test-1", .bodyImaging: "bodyImaging--test-1",
  ]
  private var selections: [ConsentSelection] { ConsentFlowRules.coreTypes.map { .init(type: $0, granted: true) } }
  private var draft: BodyCompositionDraft {
    BodyCompositionDraft(values: [.weightKg: "65"], deviceModel: "Synthetic device", measuredAt: Synthetic.now,
                         fasting: .yes, heightCmInput: "170")
  }

  func testRegistrationConsentAndMeasurementReopenWithOrderedDependenciesAndNoSignature() async throws {
    let temp = try TemporaryDirectory()
    defer { temp.remove() }
    let url = temp.url.appendingPathComponent("workflow.store")
    var expected: [TrainerDomain.OutboxItem] = []
    var recordID = ""
    do {
      let store = LocalOutboxStore(container: try LocalStoreContainer.make(url: url), trainerUid: Synthetic.trainerA, binaries: nil)
      let registration = try await register(in: store)
      let consent = try await store.saveConsent(member: member, selections: selections, versions: versions, now: Synthetic.now)
      let (id, measurement) = try await store.saveMeasurement(member: member, draft: draft, now: Synthetic.now)
      recordID = id
      expected = [registration, consent] + measurement
      XCTAssertEqual(consent.dependsOn, [registration.id])
      XCTAssertEqual(measurement.first?.dependsOn, [registration.id])
      XCTAssertEqual(measurement.first?.state, .blocked(.awaitingConsent),
                     "A crash before enqueue must not lose the consent-retention dependency")
      XCTAssertEqual(measurement.last?.state, .blocked(.awaitingConsent))
      XCTAssertEqual(measurement.last?.entityRef, measurement.first?.entityRef,
                     "The height update belongs to the measurement for sync state and retention")
      XCTAssertEqual(measurement.last?.dependsOn, [measurement[0].id], "Height updates follow successful record creation")
      XCTAssertEqual(expected.map(\.sequence), [1, 2, 3, 4])
    }
    let container = try LocalStoreContainer.make(url: url)
    let reopened = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerA, binaries: nil)
    let loaded = try await reopened.loadAll()
    XCTAssertEqual(loaded, expected)
    let pending = try await reopened.pendingMembers()
    XCTAssertEqual(pending.map(\.id), [member.id])
    let records = try await reopened.measurementRecords(member: member, since: .distantPast)
    XCTAssertEqual(records.map(\.id), [recordID])
    XCTAssertEqual(records.first?.values[.weightKg], 65)
    let devices = try await reopened.recentDeviceModels()
    XCTAssertEqual(devices, ["Synthetic device"])
    let context = ModelContext(container)
    let capture = try XCTUnwrap(context.fetchOwned(LocalConsentCapture.self, by: Synthetic.trainerA).first)
    XCTAssertNil(capture.signatureBinaryId, "The MVP must not fabricate a signature or binary identifier")
    XCTAssertEqual(capture.captureId, expected[1].requestId.uuidString)
  }

  func testExpiredConsentAfterReopenRemovesMeasurementAndHeightButKeepsPendingRegistration() async throws {
    let temp = try TemporaryDirectory()
    defer { temp.remove() }
    let location = LocalStoreLocation(trainerUid: Synthetic.trainerA, applicationSupportURL: temp.url)
    var saved: [TrainerDomain.OutboxItem] = []
    var recordID = ""
    do {
      let store = LocalOutboxStore(container: try LocalStoreContainer.make(url: location.storeURL),
                                   trainerUid: Synthetic.trainerA, binaries: nil)
      let registration = try await register(in: store)
      let consent = try await store.saveConsent(member: member, selections: selections, versions: versions, now: Synthetic.now)
      let (id, measurement) = try await store.saveMeasurement(member: member, draft: draft, now: Synthetic.now)
      recordID = id
      saved = [registration, consent] + measurement
      XCTAssertEqual(measurement.count, 2, "The synthetic draft also updates the pending member's height")
      // Simulate a process ending after the transaction but before any engine enqueue.
    }

    let container = try LocalStoreContainer.make(url: location.storeURL)
    let context = ModelContext(container)
    let retention = LocalRetention(context: context, binaryStore: LocalBinaryStore(location: location),
                                   trainerUid: Synthetic.trainerA)
    let report = try retention.purge(now: Synthetic.now.addingTimeInterval(LocalRetention.window + 60))

    XCTAssertEqual(report.destroyedMeasurementRecordIds, [recordID])
    XCTAssertEqual(Set(report.destroyedOutboxItemIds), Set(saved.dropFirst().map(\.id)))
    XCTAssertTrue(try context.fetchOwned(LocalMeasurementDraft.self, by: Synthetic.trainerA).isEmpty)
    XCTAssertTrue(try context.fetchOwned(LocalConsentCapture.self, by: Synthetic.trainerA).isEmpty)
    let remaining = try context.fetchOwned(OutboxItem.self, by: Synthetic.trainerA)
    XCTAssertEqual(remaining.map(\.id), [saved[0].id], "Retention must preserve the stage 0 registration")
    XCTAssertEqual(remaining.first?.stage, LocalOutboxStage.memberKey.rawValue)
    XCTAssertEqual(try context.fetchOwned(LocalPendingMemberDraft.self, by: Synthetic.trainerA).map(\.pendingMemberId),
                   [member.id])
  }

  func testInvalidConsentDoesNotLeaveAPartialCaptureOrOutboxItem() async throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let store = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerA, binaries: nil)
    for answers in [[ConsentSelection(type: .required, granted: false)], selections] {
      do {
        _ = try await store.saveConsent(member: member, selections: answers, versions: [:], now: Synthetic.now)
        XCTFail("Invalid selection or missing document version must fail")
      } catch {}
    }
    let rows = try await store.loadAll()
    XCTAssertTrue(rows.isEmpty)
    XCTAssertTrue(try ModelContext(container).fetchOwned(LocalConsentCapture.self, by: Synthetic.trainerA).isEmpty)
  }

  func testServiceBlocksMissingConsentAndKeepsAwaitingRecordsLocalUntilConsentRunsFirst() async throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let store = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerA, binaries: nil)
    let remote = WorkflowRecordingRemote()
    let engine = SyncEngine(store: store, writer: remote, uploader: remote, callable: remote)
    let service = service(store: store, engine: engine)
    _ = try await register(in: store)
    do {
      _ = try await service.saveBodyComposition(member: member, draft: draft)
      XCTFail("Missing health-data consent must block before any draft is persisted")
    } catch {
      XCTAssertEqual(error as? MeasurementStoreError, .consentRequired(.healthData))
    }
    let missingRecords = try await store.measurementRecords(member: member, since: .distantPast)
    XCTAssertTrue(missingRecords.isEmpty)
    try await service.captureInPerson(member: member, selections: selections, documentVersions: versions)
    var entered = draft
    entered.heightMeasuredAt = Synthetic.now.addingTimeInterval(-3600)
    let id = try await service.saveBodyComposition(member: member, draft: entered)
    let queued = try await store.loadAll()
    let record = try XCTUnwrap(queued.first { $0.entityRef == BodyCompositionPayload.entityRef(recordId: id) })
    XCTAssertEqual(record.state, .blocked(.awaitingConsent))
    XCTAssertNil(record.payload?["derived"], "Awaiting consent cannot retain a previously entered height or derived BMI")
    XCTAssertFalse(queued.contains { $0.kind == .updateDocument && $0.payload?["heightCm"] != nil })
    XCTAssertTrue(remote.calls.isEmpty, "Saving is local-first; only start() permits sending")
    let local = try XCTUnwrap(ModelContext(container).fetchOwned(LocalMeasurementDraft.self, by: Synthetic.trainerA).first)
    XCTAssertEqual(local.syncState, SyncState.awaitingConsent.rawValue)
    let stored = try JSONValue(storageData: local.payloadJSON)
    XCTAssertNil(stored["derived"])
    XCTAssertEqual(stored["values"]?["weightKg"], .number(65), "The values-only local draft remains available")
    await engine.start()
    await engine.waitUntilIdle()
    await engine.stop()
    XCTAssertEqual(remote.calls, ["create:pendingMembers/\(member.id)", "call:recordConsent",
      "create:bodyCompositionRecords/\(id)"])
    let synced = try XCTUnwrap(ModelContext(container).fetchOwned(LocalMeasurementDraft.self, by: Synthetic.trainerA).first)
    XCTAssertEqual(synced.syncState, SyncState.synced.rawValue)
  }

  func testFailedConsentBlocksHealthRecordSaveAndAckWaitsForMatchingServerState() async throws {
    let container = try LocalStoreContainer.make(inMemory: true)
    let store = LocalOutboxStore(container: container, trainerUid: Synthetic.trainerA, binaries: nil)
    var consent = try await store.saveConsent(member: member, selections: selections, versions: versions, now: Synthetic.now)
    consent.state = .failed
    consent.lastErrorCode = "failed-precondition"
    try await store.update(consent)
    var captures = try await store.consentCaptures(member: member)
    XCTAssertEqual(captures.map(\.state), [.failed])
    XCTAssertEqual(EffectiveConsentResolver.resolve(server: nil, captures: captures).healthRecordSave, .blocked)
    let remote = WorkflowRecordingRemote()
    let engine = SyncEngine(store: store, writer: remote, uploader: remote, callable: remote)
    do {
      _ = try await service(store: store, engine: engine).saveBodyComposition(member: member, draft: draft)
      XCTFail("Rejected consent must not allow another health draft")
    } catch { XCTAssertEqual(error as? MeasurementStoreError, .consentRequired(.healthData)) }

    consent.state = .superseded
    try await store.update(consent)
    let superseded = try await store.consentCaptures(member: member)
    XCTAssertEqual(EffectiveConsentResolver.resolve(server: nil, captures: superseded).healthRecordSave, .blocked,
                   "Replacing a rejected capture must not make its old health grant usable again")

    consent.state = .acked
    consent.ack = .call
    consent.lastErrorCode = nil
    try await store.update(consent)
    captures = try await store.consentCaptures(member: member)
    XCTAssertEqual(captures.map(\.state), [.pending], "Callable ack alone never enables camera access")
    let wrong = ConsentState(entries: [.healthData: .init(granted: true, documentVersion: "older")])
    try await store.confirmCaptures(member: member, server: wrong)
    let unconfirmed = try await store.consentCaptures(member: member)
    XCTAssertEqual(unconfirmed.count, 1)
    let server = ConsentState(entries: Dictionary(uniqueKeysWithValues: versions.map {
      ($0.key, ConsentStateEntry(granted: true, documentVersion: $0.value))
    }))
    try await store.confirmCaptures(member: member, server: server)
    let remainingCaptures = try await store.consentCaptures(member: member)
    XCTAssertTrue(remainingCaptures.isEmpty)
    XCTAssertTrue(EffectiveConsentResolver.resolve(server: server, captures: []).coreGranted)
  }

  func testRequiredRefusalQueuesCancellationWithoutConsentAndHidesPendingMember() async throws {
    let store = LocalOutboxStore(container: try LocalStoreContainer.make(inMemory: true), trainerUid: Synthetic.trainerA, binaries: nil)
    let registration = try await register(in: store)
    let cancelled = try await store.cancelPending(member: member, now: Synthetic.now)
    XCTAssertEqual(cancelled.dependsOn, [registration.id])
    XCTAssertEqual(cancelled.payload?["status"], .string("cancelled"))
    let pending = try await store.pendingMembers()
    XCTAssertTrue(pending.isEmpty)
    let remainingCaptures = try await store.consentCaptures(member: member)
    XCTAssertTrue(remainingCaptures.isEmpty)
    let items = try await store.loadAll()
    XCTAssertFalse(items.contains { $0.kind == .callConsent })
  }

  func testV1_1CaptureMigratesToNullableSignatureWithoutLosingItsStoredSignature() throws {
    let temp = try TemporaryDirectory()
    defer { temp.remove() }
    let url = temp.url.appendingPathComponent("v1_1.store")
    let signatureID = UUID()
    let captureID = UUID().uuidString
    do {
      let old = try ModelContainer(for: Schema(versionedSchema: LocalStoreSchemaV1_1.self),
                                   configurations: [ModelConfiguration(url: url)])
      let context = ModelContext(old)
      context.insert(LocalStoreSchemaV1.LocalConsentCapture(captureId: captureID, trainerUid: Synthetic.trainerA,
        memberKey: member, selectionsJSON: Synthetic.json, signatureBinaryId: signatureID, capturedAt: Synthetic.now))
      try context.save()
    }
    let current = ModelContext(try LocalStoreContainer.make(url: url))
    let migrated = try XCTUnwrap(current.fetchOwned(LocalConsentCapture.self, by: Synthetic.trainerA).first)
    XCTAssertEqual(migrated.captureId, captureID)
    XCTAssertEqual(migrated.signatureBinaryId, signatureID)
    XCTAssertEqual(migrated.capturedAt, Synthetic.now)
    current.insert(LocalConsentCapture(captureId: UUID().uuidString, trainerUid: Synthetic.trainerA,
      memberKey: member, selectionsJSON: Synthetic.json, capturedAt: Synthetic.now))
    try current.save()
    XCTAssertEqual(try current.fetchOwned(LocalConsentCapture.self, by: Synthetic.trainerA).filter { $0.signatureBinaryId == nil }.count, 1)
  }

  private func register(in store: LocalOutboxStore) async throws -> TrainerDomain.OutboxItem {
    let id = member.id
    let registrar = LocalPendingMemberRegistrar(outbox: store, trainerUid: Synthetic.trainerA, enqueue: { _ in },
                                               now: { Synthetic.now }, makeID: { id })
    _ = try await registrar.register(PendingMemberDraft(displayName: "합성 회원", sex: .unspecified,
                                                       birthYear: 1990, ageConfirmed14: true))
    let items = try await store.loadAll()
    return try XCTUnwrap(items.first { $0.stage == .memberKey })
  }

  private func service(store: LocalOutboxStore, engine: SyncEngine, state: ConsentState? = nil) -> LocalWorkflowService {
    LocalWorkflowService(outbox: store, engine: engine, documents: WorkflowEmptyDocuments(),
      states: WorkflowConsentState(state: state), measurements: WorkflowEmptyMeasurements(),
      assigned: WorkflowEmptyDirectory(), pending: WorkflowEmptyDirectory(), now: { Synthetic.now })
  }
}

private struct WorkflowEmptyDocuments: ConsentDocumentsSource {
  func publishedDocuments() async throws -> [ConsentDocumentVersion] { [] }
}
private struct WorkflowConsentState: ConsentStateSource {
  let state: ConsentState?
  func observe(member: MemberKey) -> AsyncStream<ConsentState?> { AsyncStream { $0.yield(state); $0.finish() } }
}
private struct WorkflowEmptyMeasurements: MeasurementRecordsSource {
  func records(member: MemberKey, since: Date) -> AsyncThrowingStream<[BodyCompositionRecord], Error> {
    AsyncThrowingStream { $0.yield([]); $0.finish() }
  }
}
private struct WorkflowEmptyDirectory: MemberDirectory {
  func observeAssignedMembers() -> AsyncThrowingStream<[Member], Error> { AsyncThrowingStream { $0.yield([]); $0.finish() } }
}
private final class WorkflowRecordingRemote: RemoteWriter, BinaryUploader, CallableClient, @unchecked Sendable {
  private let lock = NSLock()
  private var events: [String] = []
  var calls: [String] { lock.withLock { events } }
  func createIfAbsent(path: String, fields: JSONValue) async throws -> WriteAck {
    lock.withLock { events.append("create:" + path) }
    return WriteAck(serverCommitted: true)
  }
  func update(path: String, fields: JSONValue) async throws -> WriteAck {
    lock.withLock { events.append("update:" + path) }
    return WriteAck(serverCommitted: true)
  }
  func delete(path: String) async throws -> WriteAck { WriteAck(serverCommitted: true) }
  func upload(localURL: URL, path: String, contentType: String, sha256: String) async throws -> UploadReceipt {
    UploadReceipt(path: path, size: 0, sha256: sha256, verified: true)
  }
  func delete(path: String) async throws {}
  func call<T: Decodable & Sendable>(_ name: String, _ payload: JSONValue) async throws -> T {
    lock.withLock { events.append("call:" + name) }
    return try JSONDecoder().decode(T.self, from: Data("{}".utf8))
  }
}
