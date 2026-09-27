import Foundation
import TrainerContracts

/// An explicit answer on one card. Refusal is a UI answer, never a withdrawal request in the MVP.
public struct ConsentSelection: Codable, Equatable, Sendable {
  public let type: ConsentType
  public let granted: Bool

  public init(type: ConsentType, granted: Bool) {
    self.type = type
    self.granted = granted
  }
}

/// A value snapshot of an unconfirmed local capture; the pure SyncEngine target never imports SwiftData.
public struct ConsentCaptureSnapshot: Equatable, Sendable {
  public enum State: String, Codable, Sendable {
    case pending
    case failed
  }

  public let id: UUID
  public let selections: [ConsentSelection]
  public let state: State
  public let capturedAt: Date

  public init(id: UUID, selections: [ConsentSelection], state: State, capturedAt: Date) {
    self.id = id
    self.selections = selections
    self.state = state
    self.capturedAt = capturedAt
  }
}
