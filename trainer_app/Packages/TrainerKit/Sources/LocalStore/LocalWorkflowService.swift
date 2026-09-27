import Foundation
import SyncEngine
import TrainerContracts
import TrainerDomain

/// The real registration → consent → measurement workflow. All writes first commit atomically to LocalStore;
/// only SyncEngine sends them. Feature targets receive the domain protocols and cannot call Firebase directly.
public final class LocalWorkflowService: ConsentService, MeasurementStore, MemberDirectory, Sendable {
  private let outbox: LocalOutboxStore
  private let engine: SyncEngine
  private let documents: any ConsentDocumentsSource
  private let states: any ConsentStateSource
  private let measurements: any MeasurementRecordsSource
  private let assigned: any MemberDirectory
  private let pending: any MemberDirectory
  private let now: @Sendable () -> Date

  public init(outbox: LocalOutboxStore, engine: SyncEngine, documents: any ConsentDocumentsSource,
              states: any ConsentStateSource, measurements: any MeasurementRecordsSource,
              assigned: any MemberDirectory, pending: any MemberDirectory,
              now: @escaping @Sendable () -> Date = { Date() }) {
    self.outbox = outbox
    self.engine = engine
    self.documents = documents
    self.states = states
    self.measurements = measurements
    self.assigned = assigned
    self.pending = pending
    self.now = now
  }

  public func publishedDocuments() async throws -> [ConsentDocumentVersion] {
    try await documents.publishedDocuments()
  }

  public func recentDeviceModels() async throws -> [String] { try await outbox.recentDeviceModels() }

  public func observeBodyCompositionSyncState(recordID: String) async -> AsyncStream<SyncState> {
    await engine.syncState(for: BodyCompositionPayload.entityRef(recordId: recordID))
  }

  public func captureInPerson(member: MemberKey, selections: [ConsentSelection],
                              documentVersions: [ConsentType: String]) async throws {
    let consent = try await currentConsent(member)
    guard selections.contains(where: { $0.type == .required && $0.granted })
      || consent.required == .granted || consent.required == .awaitingConsent
    else { throw ConsentServiceError.invalidSelection }
    let item = try await outbox.saveConsent(member: member, selections: selections, versions: documentVersions, now: now())
    await engine.enqueue(item)
  }

  public func cancelPending(member: MemberKey) async throws {
    let item = try await outbox.cancelPending(member: member, now: now())
    await engine.enqueue(item)
  }

  public func saveBodyComposition(member: MemberKey, draft: BodyCompositionDraft) async throws -> String {
    let consent = try await currentConsent(member)
    guard consent.canSaveHealthRecord else { throw MeasurementStoreError.consentRequired(.healthData) }
    var saving = draft
    // Recheck at the write boundary: the editor may still contain height entered under an earlier server grant.
    if consent.healthData != .granted {
      saving.heightCmInput = nil
      saving.heightMeasuredAt = nil
    }
    let (id, items) = try await outbox.saveMeasurement(member: member, draft: saving, now: now())
    for item in items { await engine.enqueue(item) }
    return id
  }

  private func currentConsent(_ member: MemberKey) async throws -> EffectiveConsent {
    // The first Firestore event can come from the offline cache. Nil remains missing; local captures only grant
    // local-save permission, never photo access or permission to bypass server rules.
    for await server in states.observe(member: member) {
      try Task.checkCancellation()
      return EffectiveConsentResolver.resolve(server: server, captures: try await outbox.consentCaptures(member: member))
    }
    throw ConsentServiceError.unavailable
  }

  public func observe(member: MemberKey) -> AsyncStream<EffectiveConsent> {
    AsyncStream { continuation in
      let task = Task {
        let (events, post) = AsyncStream<ConsentEvent>.makeStream()
        var remote: Task<Void, Never>?
        var localRevision = 0
        var listenerRevision = 0
        func startRemote() {
          listenerRevision = localRevision
          remote = Task {
            for await state in states.observe(member: member) {
              guard !Task.isCancelled else { return }
              post.yield(.server(state))
            }
            if !Task.isCancelled { post.yield(.serverEnded) }
          }
        }
        startRemote()
        let local = Task { for await _ in await outbox.changes() { post.yield(.local) } }
        defer { remote?.cancel(); local.cancel(); post.finish(); continuation.finish() }
        var server: ConsentState?
        for await event in events {
          switch event {
          case let .server(value): server = value
          case .local:
            localRevision += 1
            if remote == nil { startRemote() }
          case .serverEnded:
            remote = nil
            // A newly registered pending member initially has no readable consent state. Registration/consent
            // acknowledgements retry an ended reader. If an ack arrived before its end event, consume that
            // revision here too. An unchanged finite stream never restarts itself in a busy loop.
            if localRevision > listenerRevision { startRemote() }
          }
          do {
            try await outbox.confirmCaptures(member: member, server: server)
            let captures = try await outbox.consentCaptures(member: member)
            continuation.yield(EffectiveConsentResolver.resolve(server: server, captures: captures))
          } catch {
            // Unreadable local data must never grant permission. The queue still exposes the storage failure.
            continuation.yield(.none)
          }
        }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  public func observeBodyCompositionRecords(member: MemberKey, since: Date)
    -> AsyncThrowingStream<[BodyCompositionRecord], Error> {
    AsyncThrowingStream { continuation in
      let task = Task {
        let (events, post) = AsyncStream<RecordsEvent>.makeStream()
        let remote = Task {
          do { for try await records in measurements.records(member: member, since: since) { post.yield(.server(records)) } }
          catch { post.yield(.failed(error)) }
        }
        let local = Task { for await _ in await outbox.changes() { post.yield(.local) } }
        defer { remote.cancel(); local.cancel(); post.finish() }
        var server: [BodyCompositionRecord] = []
        do {
          for await event in events {
            switch event {
            case let .server(records): server = records
            case let .failed(error): throw error
            case .local: break
            }
            var byID = Dictionary(uniqueKeysWithValues: try await outbox.measurementRecords(member: member, since: since)
              .map { ($0.id, $0) })
            server.forEach { byID[$0.id] = $0 }
            continuation.yield(byID.values.sorted { ($0.measuredAt, $0.id) > ($1.measuredAt, $1.id) })
          }
          continuation.finish()
        } catch { continuation.finish(throwing: error) }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  public func observeSeries(member: MemberKey, metricCode: MetricCode, since: Date)
    -> AsyncThrowingStream<[SeriesPoint], Error> {
    AsyncThrowingStream { continuation in
      let task = Task {
        do {
          for try await records in observeBodyCompositionRecords(member: member, since: since) {
            continuation.yield(BodyCompositionSeries.points(from: records, metricCode: metricCode))
          }
          continuation.finish()
        } catch { continuation.finish(throwing: error) }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  public func observeAssignedMembers() -> AsyncThrowingStream<[Member], Error> {
    AsyncThrowingStream { continuation in
      let task = Task {
        let (events, post) = AsyncStream<MembersEvent>.makeStream()
        let assignedTask = Task {
          do { for try await members in assigned.observeAssignedMembers() { post.yield(.assigned(members)) } }
          catch { post.yield(.failed(error)) }
        }
        let pendingTask = Task {
          do { for try await members in pending.observeAssignedMembers() { post.yield(.pending(members)) } }
          catch { post.yield(.failed(error)) }
        }
        let localTask = Task { for await _ in await outbox.changes() { post.yield(.local) } }
        defer { assignedTask.cancel(); pendingTask.cancel(); localTask.cancel(); post.finish() }
        var assignedMembers: [Member] = []
        var pendingMembers: [Member] = []
        do {
          for await event in events {
            switch event {
            case let .assigned(members): assignedMembers = members
            case let .pending(members): pendingMembers = members
            case let .failed(error): throw error
            case .local: break
            }
            let cancelled = try await outbox.cancelledMemberIDs()
            var members = Dictionary(uniqueKeysWithValues: try await outbox.pendingMembers().map { ($0.key, $0) })
            (pendingMembers + assignedMembers).forEach { members[$0.key] = $0 }
            continuation.yield(members.values.filter { !$0.isPending || !cancelled.contains($0.id) })
          }
          continuation.finish()
        } catch { continuation.finish(throwing: error) }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }
}

private enum ConsentEvent: Sendable { case server(ConsentState?), serverEnded, local }
private enum RecordsEvent: Sendable { case server([BodyCompositionRecord]), local, failed(Error) }
private enum MembersEvent: Sendable { case assigned([Member]), pending([Member]), local, failed(Error) }
