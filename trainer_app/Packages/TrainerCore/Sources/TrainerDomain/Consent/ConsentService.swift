import TrainerContracts

public protocol ConsentDocumentsSource: Sendable {
  func publishedDocuments() async throws -> [ConsentDocumentVersion]
}

/// Local-first TR-14 service. Captures return after the local transaction and Outbox enqueue, never after a direct
/// callable. Only grants of ①②③ are sent; a required refusal calls `cancelPending` without a consent record.
public protocol ConsentService: ConsentDocumentsSource, EffectiveConsentSource {
  func captureInPerson(member: MemberKey, selections: [ConsentSelection],
                       documentVersions: [ConsentType: String]) async throws
  func cancelPending(member: MemberKey) async throws
}

public enum ConsentServiceError: Error, Equatable, Sendable {
  case unsupportedMember
  case invalidSelection
  case documentMissing
  case unavailable
}
