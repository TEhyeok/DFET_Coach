#if DEBUG
import Foundation
import TrainerContracts
import TrainerDomain

/// Interactive synthetic demo, isolated from Firebase and from every disk-backed trainer partition.
actor PreviewWorkflowService: ConsentService, MeasurementStore, MemberDirectory, PendingMemberRegistrar {
  private var members: [Member] = []
  private var consent: [MemberKey: EffectiveConsent] = [:]
  private var records: [MemberKey: [BodyCompositionRecord]] = [:]
  private var devices: [String] = []
  private var observers: [UUID: AsyncStream<Void>.Continuation] = [:]

  func publishedDocuments() async throws -> [ConsentDocumentVersion] {
    [.required, .healthData, .bodyImaging].map { type in
      ConsentDocumentVersion(id: "\(type.rawValue)--mvp-test-1", consentType: type, version: "mvp-test-1",
        title: "SYNTH — \(type.rawValue)", purpose: "합성 회원으로 기록 흐름을 확인하는 테스트 문서",
        items: ["합성 테스트 정보"], retention: "테스트 종료 시 삭제", refusalNotice: "동의하지 않으면 해당 기록을 입력할 수 없습니다",
        privacyPolicyVersion: "synthetic-test", publishedAt: Date(timeIntervalSince1970: 1_700_000_000))
    }
  }

  func register(_ draft: PendingMemberDraft) async throws -> String {
    guard draft.problems(now: Date()).isEmpty else { throw PendingMemberRegistrationError.invalidDraft }
    let id = DocumentID.make()
    members.append(Member(id: id, displayName: draft.trimmedName, trainerId: "synthTrainerA", isPending: true))
    changed()
    return id
  }

  func captureInPerson(member: MemberKey, selections: [ConsentSelection], documentVersions: [ConsentType: String]) async throws {
    func answer(_ type: ConsentType) -> EffectiveConsentValue {
      if consent[member]?[type] == .granted { return .granted }
      return selections.contains { $0.type == type && $0.granted } ? .granted : .missing
    }
    consent[member] = EffectiveConsent(required: answer(.required), healthData: answer(.healthData), bodyImaging: answer(.bodyImaging))
    changed()
  }

  func cancelPending(member: MemberKey) async throws {
    members.removeAll { $0.key == member }
    changed()
  }

  func recentDeviceModels() async throws -> [String] { devices }

  func saveBodyComposition(member: MemberKey, draft: BodyCompositionDraft) async throws -> String {
    guard consent[member]?.canSaveHealthRecord == true else { throw MeasurementStoreError.consentRequired(.healthData) }
    let result = BodyCompositionValidator.validate(draft, now: Date())
    guard let entry = result.entry else { throw MeasurementStoreError.invalidDraft(result.issues) }
    let id = DocumentID.make()
    let payload = BodyCompositionPayload.fields(entry, member: member, trainerUid: "synthTrainerA")
    if let record = BodyCompositionRecord(id: id, document: payload) { records[member, default: []].append(record) }
    devices.removeAll { $0 == entry.deviceModel }
    devices.insert(entry.deviceModel, at: 0)
    changed()
    return id
  }

  nonisolated func observe(member: MemberKey) -> AsyncStream<EffectiveConsent> {
    AsyncStream { continuation in
      let task = Task {
        for await _ in await changes() { continuation.yield(await consent[member] ?? .none) }
        continuation.finish()
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  nonisolated func observeAssignedMembers() -> AsyncThrowingStream<[Member], Error> {
    AsyncThrowingStream { continuation in
      let task = Task {
        for await _ in await changes() { continuation.yield(await members) }
        continuation.finish()
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  nonisolated func observeBodyCompositionRecords(member: MemberKey, since: Date) -> AsyncThrowingStream<[BodyCompositionRecord], Error> {
    AsyncThrowingStream { continuation in
      let task = Task {
        for await _ in await changes() { continuation.yield(await records[member, default: []].filter { $0.measuredAt >= since }) }
        continuation.finish()
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  nonisolated func observeSeries(member: MemberKey, metricCode: MetricCode, since: Date) -> AsyncThrowingStream<[SeriesPoint], Error> {
    AsyncThrowingStream { continuation in
      let task = Task {
        for await _ in await changes() {
          let values = await records[member, default: []].filter { $0.measuredAt >= since }
          continuation.yield(BodyCompositionSeries.points(from: values, metricCode: metricCode))
        }
        continuation.finish()
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  private func changes() -> AsyncStream<Void> {
    let id = UUID()
    let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    observers[id] = continuation
    continuation.yield(())
    continuation.onTermination = { _ in Task { await self.remove(id) } }
    return stream
  }
  private func remove(_ id: UUID) { observers.removeValue(forKey: id) }
  private func changed() { observers.values.forEach { $0.yield(()) } }
}
#endif
