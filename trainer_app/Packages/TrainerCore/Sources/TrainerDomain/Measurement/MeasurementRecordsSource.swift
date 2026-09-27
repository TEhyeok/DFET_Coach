import Foundation

/// Read-only server records. LocalStore merges these with drafts that have not reached the server yet.
public protocol MeasurementRecordsSource: Sendable {
  func records(member: MemberKey, since: Date) -> AsyncThrowingStream<[BodyCompositionRecord], Error>
}
