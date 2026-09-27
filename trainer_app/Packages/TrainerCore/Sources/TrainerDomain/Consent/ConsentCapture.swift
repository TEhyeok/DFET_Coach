import Foundation
import TrainerContracts

/// One consent type in an in-person capture (V1-06 §6.2.1 `selections[]`, V1-05 §12.2 `selectionsJSON`).
public struct ConsentSelection: Codable, Equatable, Hashable, Sendable {
  public let consentType: ConsentType
  public let action: ConsentAction
  /// A `consentDocumentVersions` document ID, `{consentType}--{version}` (V1-05 §4.13).
  public let documentVersion: String

  public init(consentType: ConsentType, action: ConsentAction, documentVersion: String) {
    self.consentType = consentType
    self.action = action
    self.documentVersion = documentVersion
  }
}

/// `LocalConsentCapture.captureState` (V1-04 §9.1), mirrored from the capture's `callConsent` Outbox item.
public enum ConsentCaptureState: String, CaseIterable, Sendable {
  /// Not confirmed yet: queued, in flight, blocked, or waiting for another try.
  case pending
  /// `recordConsent` succeeded.
  case confirmed
  /// `recordConsent` failed and waits for the trainer (or was superseded by a newer capture).
  case failed
}

/// An in-person consent capture on this device, as the effective consent reads it (DF-111). A value copy of the
/// LocalStore `LocalConsentCapture` row.
public struct ConsentCapture: Equatable, Sendable {
  /// A lowercase UUID string; the request's `clientCaptureId`.
  public let captureId: String
  public let member: MemberKey
  public let selections: [ConsentSelection]
  public let capturedAt: Date
  public let state: ConsentCaptureState
  /// When this device learned that `recordConsent` succeeded (device clock); nil until then.
  public let confirmedAt: Date?

  public init(
    captureId: String, member: MemberKey, selections: [ConsentSelection], capturedAt: Date,
    state: ConsentCaptureState, confirmedAt: Date? = nil
  ) {
    self.captureId = captureId
    self.member = member
    self.selections = selections
    self.capturedAt = capturedAt
    self.state = state
    self.confirmedAt = confirmedAt
  }
}

/// This device's consent captures of one member (DF-111 MVP). LocalStore implements it.
public protocol ConsentCaptureSource: Sendable {
  /// The member's captures now and after every change, oldest first.
  func observeCaptures(member: MemberKey) -> AsyncStream<[ConsentCapture]>
}

/// Saves an in-person consent capture (TR-14, DF-110). The capture exists on the device at once, offline too; its
/// `recordConsent` call goes through the Outbox (stage 1), after the member's pending-member create and before any
/// of the member's records.
public protocol ConsentCaptureRecorder: Sendable {
  /// Returns the new `captureId`. Throws `ConsentCaptureError.invalidSelections` for an empty list or a type chosen
  /// twice, or the local store's error when the capture could not be saved on the device.
  func capture(member: MemberKey, selections: [ConsentSelection]) async throws -> String
}

public enum ConsentCaptureError: Error, Equatable, Sendable {
  case invalidSelections
}
