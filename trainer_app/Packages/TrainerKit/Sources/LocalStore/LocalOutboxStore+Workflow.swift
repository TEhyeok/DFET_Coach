import Foundation
import SwiftData
import SyncEngine
import TrainerContracts
import TrainerDomain

extension LocalOutboxStore {
  /// Emitted only after a successful transaction, including engine acknowledgements and failed retries.
  public func changes() -> AsyncStream<Void> {
    let id = UUID()
    let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    changeContinuations[id] = continuation
    continuation.yield(())
    continuation.onTermination = { [weak self] _ in Task { await self?.removeChanges(id) } }
    return stream
  }

  private func removeChanges(_ id: UUID) { changeContinuations.removeValue(forKey: id) }

  public func pendingMembers() throws -> [Member] {
    let cancelled = try cancelledMemberIDs()
    return try modelContext.fetchOwned(LocalPendingMemberDraft.self, by: trainerUid)
      .filter { !cancelled.contains($0.pendingMemberId) }
      .map { Member(id: $0.pendingMemberId, displayName: $0.displayName, trainerId: trainerUid, isPending: true) }
  }

  public func cancelledMemberIDs() throws -> Set<String> {
    Set(try modelContext.fetchOwned(OutboxItem.self, by: trainerUid)
      .filter { $0.entityRef.hasPrefix("pendingCancellation:") }
      .compactMap { MemberKey(storageValue: $0.memberKey)?.id })
  }

  public func consentCaptures(member: MemberKey) throws -> [ConsentCaptureSnapshot] {
    try modelContext.fetchOwned(LocalConsentCapture.self, by: trainerUid)
      .filter { $0.memberKey == member.storageValue && $0.captureState != LocalConsentCaptureState.confirmed.rawValue }
      .compactMap { capture in
        guard let id = UUID(uuidString: capture.captureId),
          let values = try? JSONValue(storageData: capture.selectionsJSON), case let .array(rows) = values
        else { return nil }
        let selections = rows.compactMap { row -> ConsentSelection? in
          guard let raw = row["consentType"]?.stringValue, let type = ConsentType(rawValue: raw) else { return nil }
          return ConsentSelection(type: type, granted: row["action"]?.stringValue == "grant")
        }
        return ConsentCaptureSnapshot(id: id, selections: selections,
          state: capture.captureState == LocalConsentCaptureState.failed.rawValue ? .failed : .pending,
          capturedAt: capture.capturedAt)
      }
  }

  /// A reader confirms captures only after observing the server-derived state. The callable acknowledgement alone
  /// does not turn a local capture into a server grant on screen.
  public func confirmCaptures(member: MemberKey, server: ConsentState?) throws {
    guard let server else { return }
    var changed = false
    let items = try modelContext.fetchOwned(OutboxItem.self, by: trainerUid)
    for capture in try modelContext.fetchOwned(LocalConsentCapture.self, by: trainerUid)
    where capture.memberKey == member.storageValue && capture.captureState != LocalConsentCaptureState.confirmed.rawValue {
      guard items.contains(where: { $0.entityRef == capture.entityRef && $0.state == "acked" }),
        let value = try? JSONValue(storageData: capture.selectionsJSON), case let .array(rows) = value,
        !rows.isEmpty,
        rows.allSatisfy({ row in
          guard let type = row["consentType"]?.stringValue.flatMap(ConsentType.init(rawValue:)) else { return false }
          return server.isGranted(type) && server[type]?.documentVersion == row["documentVersion"]?.stringValue
        })
      else { continue }
      capture.captureState = LocalConsentCaptureState.confirmed.rawValue
      capture.serverConfirmedAt = Date()
      changed = true
    }
    if changed { try saveOrRollback() }
  }

  public func saveConsent(member: MemberKey, selections: [ConsentSelection], versions: [ConsentType: String],
                          now: Date) throws -> TrainerDomain.OutboxItem {
    guard case let .pending(id) = member else { throw ConsentServiceError.unsupportedMember }
    let granted = selections.filter(\.granted)
    guard !granted.isEmpty, Set(selections.map(\.type)).count == selections.count,
      selections.allSatisfy({ [.required, .healthData, .bodyImaging].contains($0.type) }),
      !selections.contains(where: { $0.type == .required && !$0.granted })
    else { throw ConsentServiceError.invalidSelection }
    let rows: [JSONValue] = try granted.map { selection in
      guard let version = versions[selection.type], !version.isEmpty else { throw ConsentServiceError.documentMissing }
      return .object(["consentType": .string(selection.type.rawValue), "action": .string("grant"),
                      "documentVersion": .string(version)])
    }
    let capture = UUID()
    let item = TrainerDomain.OutboxItem(
      requestId: capture, memberKey: member, entityRef: .consent(captureId: capture.uuidString),
      sequence: try nextSequence(for: member), stage: .consent, kind: .callConsent,
      target: .callable(name: "recordConsent"), payload: .object([
        "memberKey": .object(["pendingMemberId": .string(id)]), "selections": .array(rows),
        "channel": .string("trainerDeviceInPerson"), "capturedAt": .timestamp(now),
      ]), dependsOn: try registrationDependencies(member), createdAt: now)
    modelContext.insert(LocalConsentCapture(captureId: capture.uuidString, trainerUid: trainerUid, memberKey: member,
      selectionsJSON: JSONValue.array(rows).storageData(), capturedAt: now))
    try put(item)
    try saveOrRollback()
    return item
  }

  public func cancelPending(member: MemberKey, now: Date) throws -> TrainerDomain.OutboxItem {
    guard case let .pending(id) = member else { throw ConsentServiceError.unsupportedMember }
    let item = TrainerDomain.OutboxItem(memberKey: member,
      entityRef: .init(rawValue: "pendingCancellation:\(id)"), sequence: try nextSequence(for: member),
      stage: .memberKey, kind: .updateDocument, target: .document(path: "pendingMembers/\(id)"),
      payload: .object(["status": .string("cancelled")]),
      dependsOn: try registrationDependencies(member), createdAt: now)
    try put(item)
    try saveOrRollback()
    return item
  }

  public func measurementRecords(member: MemberKey, since: Date) throws -> [BodyCompositionRecord] {
    try modelContext.fetchOwned(LocalMeasurementDraft.self, by: trainerUid)
      .filter { $0.memberKey == member.storageValue && $0.kind == LocalMeasurementKind.bodyComposition.rawValue }
      .compactMap { row in
        guard let document = try? JSONValue(storageData: row.payloadJSON) else { return nil }
        return BodyCompositionRecord(id: row.recordId, document: document)
      }.filter { $0.measuredAt >= since }
  }

  public func recentDeviceModels() throws -> [String] {
    try modelContext.fetchOwned(DeviceModelEntry.self, by: trainerUid)
      .sorted { $0.lastUsedAt > $1.lastUsedAt }.map(\.name)
  }

  public func saveMeasurement(member: MemberKey, draft: BodyCompositionDraft, now: Date)
    throws -> (String, [TrainerDomain.OutboxItem]) {
    let result = BodyCompositionValidator.validate(draft, now: now)
    guard let entry = result.entry else { throw MeasurementStoreError.invalidDraft(result.issues) }
    let id = DocumentID.make()
    let fields = BodyCompositionPayload.fields(entry, member: member, trainerUid: trainerUid)
    let dependencies = try registrationDependencies(member)
    let latestCapture = try modelContext.fetchOwned(OutboxItem.self, by: trainerUid)
      .filter { $0.memberKey == member.storageValue && $0.kind == "callConsent" && $0.state != "superseded" }
      .max { $0.sequence < $1.sequence }
    let awaitingConsent = latestCapture.map { $0.state != "acked" } ?? false
    let item = TrainerDomain.OutboxItem(memberKey: member, entityRef: BodyCompositionPayload.entityRef(recordId: id),
      sequence: try nextSequence(for: member), stage: .document, kind: .createDocument,
      target: .document(path: BodyCompositionPayload.path(id: id)), payload: fields, dependsOn: dependencies,
      state: awaitingConsent ? .blocked(.awaitingConsent) : .queued, createdAt: now)
    var items = [item]
    if case let .pending(pendingID) = member, let derived = entry.derived {
      items.append(TrainerDomain.OutboxItem(memberKey: member, entityRef: item.entityRef,
        sequence: try nextSequence(for: member), stage: .document, kind: .updateDocument,
        target: .document(path: "pendingMembers/\(pendingID)"), payload: .object([
          "heightCm": .number(derived.heightCmUsed), "heightMeasuredAt": .timestamp(derived.heightMeasuredAt),
        ]), dependsOn: [item.id], state: item.state, createdAt: now))
    }
    modelContext.insert(LocalMeasurementDraft(recordId: id, trainerUid: trainerUid, memberKey: member,
      kind: .bodyComposition, payloadJSON: fields.storageData(),
      syncState: awaitingConsent ? .awaitingConsent : .localSaved, createdLocallyAt: now))
    if let device = try modelContext.fetchOwned(DeviceModelEntry.self, by: trainerUid).first(where: { $0.name == entry.deviceModel }) {
      device.lastUsedAt = now
    } else {
      modelContext.insert(DeviceModelEntry(trainerUid: trainerUid, name: entry.deviceModel, lastUsedAt: now))
    }
    for item in items { try put(item) }
    try saveOrRollback()
    return (id, items)
  }

  private func registrationDependencies(_ member: MemberKey) throws -> [UUID] {
    guard case let .pending(id) = member else { return [] }
    return try modelContext.fetchOwned(OutboxItem.self, by: trainerUid)
      .filter { $0.entityRef == "pendingMember:\(id)" && $0.kind == "createDocument" }
      .map(\.id)
  }

  func updateWorkflowDraft(for item: TrainerDomain.OutboxItem) {
    if item.kind == .callConsent {
      let captures = (try? modelContext.fetchOwned(LocalConsentCapture.self, by: trainerUid)) ?? []
      for capture in captures where capture.captureId == item.requestId.uuidString {
        if capture.captureState != "confirmed" {
          capture.captureState = item.state == .failed || item.state == .superseded ? "failed" : "pending"
        }
        capture.lastErrorCode = item.lastErrorCode
        if item.state == .acked { capture.serverConfirmedAt = Date() }
      }
    }
    if item.entityRef.rawValue.hasPrefix("bodyComposition:") {
      let drafts = (try? modelContext.fetchOwned(LocalMeasurementDraft.self, by: trainerUid)) ?? []
      for draft in drafts where draft.entityRef == item.entityRef.rawValue {
        switch item.state {
        case .acked: draft.syncState = SyncState.synced.rawValue
        case .failed, .superseded: draft.syncState = SyncState.syncFailed.rawValue
        case .blocked: draft.syncState = SyncState.awaitingConsent.rawValue
        case .inFlight: draft.syncState = SyncState.syncing.rawValue
        case .queued: draft.syncState = SyncState.localSaved.rawValue
        }
        draft.lastErrorCode = item.lastErrorCode
      }
    }
  }
}
