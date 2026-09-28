import Foundation
import TrainerContracts

/// One consent type in `memberConsentStates/{memberKey}` (V1-05 §4.12).
public struct ConsentStateEntry: Equatable, Sendable {
  public let granted: Bool
  public let documentVersion: String?

  public init(granted: Bool, documentVersion: String?) {
    self.granted = granted
    self.documentVersion = documentVersion
  }
}

/// The server-derived consent state of one member (DF-111 MVP slice; DF-110 reuses it). Only `granted` and
/// `documentVersion` are read. A missing document means no consent at all, the rules' reading too (`hasConsent`).
public struct ConsentState: Equatable, Sendable {
  public let entries: [ConsentType: ConsentStateEntry]

  public init(entries: [ConsentType: ConsentStateEntry]) {
    self.entries = entries
  }

  /// Reads the document (FirebaseData maps the snapshot to `JSONValue`). A type whose value is not a map is absent;
  /// `granted` is true only for a real boolean `true`, as in the rules' `.get('granted', false) == true`.
  public init(document: JSONValue?) {
    var entries: [ConsentType: ConsentStateEntry] = [:]
    for type in ConsentType.allCases {
      guard let map = document?[type.rawValue]?.objectValue else { continue }
      entries[type] = ConsentStateEntry(granted: map["granted"]?.boolValue == true,
                                        documentVersion: map["documentVersion"]?.stringValue)
    }
    self.init(entries: entries)
  }

  public subscript(type: ConsentType) -> ConsentStateEntry? { entries[type] }

  public func isGranted(_ type: ConsentType) -> Bool { entries[type]?.granted == true }
}

/// One reading of `memberConsentStates/{memberKey}` (DF-111). A listener that failed is not a missing document.
public enum ConsentStateReading: Equatable, Sendable {
  /// No document: nothing is granted (the rules' `hasConsent` reads it the same way).
  case absent
  case present(ConsentState)
  /// The listener could not read the document: refused (a pending member whose `pendingMembers` create has not reached
  /// the server yet, so the read rule cannot prove ownership) or a transient error. It says nothing about the consent.
  case unavailable

  /// The server state this reading shows; nil when there is none (`absent`) or it is unknown (`unavailable`).
  public var state: ConsentState? {
    if case let .present(state) = self { return state }
    return nil
  }
}

/// Server consent state per member, as a stream (DF-111 MVP). DF-110's `FirestoreConsentService` implements it with a
/// `memberConsentStates/{memberKey}` listener: `.absent` or `.present` for every snapshot, and `.unavailable` followed
/// by the end of the stream when the listener fails. Server-derived only (V1-06 §8.10): local captures are overlaid by
/// the SyncEngine's `EffectiveConsentResolver`, never here.
public protocol ConsentStateSource: Sendable {
  func observe(member: MemberKey) -> AsyncStream<ConsentStateReading>
}
