import Foundation
import TrainerContracts

/// A published `consentDocumentVersions/{versionId}` document (V1-05 §4.13), reduced to what the TR-14 consent step
/// sends: its ID and version. The MVP shows no legal text from it (DF-110 MVP: document text after G-04).
public struct ConsentDocumentVersion: Equatable, Sendable {
  /// `{consentType}--{version}`, the `documentVersion` of a selection.
  public let id: String
  public let consentType: ConsentType
  public let version: String
  public let publishedAt: Date?

  public init(id: String, consentType: ConsentType, version: String, publishedAt: Date?) {
    self.id = id
    self.consentType = consentType
    self.version = version
    self.publishedAt = publishedAt
  }

  /// nil unless the document is `published` with a known `consentType` and a non-empty `version`: a draft or
  /// retired version can never be chosen (the server refuses it with `consent.documentNotPublished`, V5).
  public init?(id: String, document: JSONValue) {
    guard document["status"]?.stringValue == "published",
      let type = document["consentType"]?.stringValue.flatMap(ConsentType.init(rawValue:)),
      let version = document["version"]?.stringValue, !version.isEmpty
    else { return nil }
    var publishedAt: Date?
    if case let .timestamp(date)? = document["publishedAt"] { publishedAt = date }
    self.init(id: id, consentType: type, version: version, publishedAt: publishedAt)
  }
}

/// The published consent documents (FirebaseData: `consentDocumentVersions where status == 'published'`).
public protocol ConsentDocumentCatalog: Sendable {
  /// Every published version. Throws `RemoteError.unavailable` when only an incomplete device cache could answer.
  func publishedDocuments() async throws -> [ConsentDocumentVersion]
}

/// One answer on a TR-14 consent card. There is no default (AC-DF-110.2).
public enum ConsentChoice: String, CaseIterable, Sendable {
  case grant
  case refuse
}

/// Pure rules of the TR-14 consent step (DF-110 MVP: ①②③ only, no signature).
public enum ConsentFlowRules {
  /// The types asked on registration, in card order (F-PRIV-01.1). ④⑤ come later.
  public static let coreTypes: [ConsentType] = [.required, .healthData, .bodyImaging]

  /// The newest published version of each type (ASM-P1a-37): latest `publishedAt`, then the larger ID.
  public static func latestPublished(_ documents: [ConsentDocumentVersion]) -> [ConsentType: ConsentDocumentVersion] {
    var latest: [ConsentType: ConsentDocumentVersion] = [:]
    for document in documents {
      guard let current = latest[document.consentType] else {
        latest[document.consentType] = document
        continue
      }
      let newer = (document.publishedAt ?? .distantPast, document.id) > (current.publishedAt ?? .distantPast, current.id)
      if newer { latest[document.consentType] = document }
    }
    return latest
  }

  /// Core types without a published version: the step stops with `tr14.consent.documentMissing` (AC-DF-110.3).
  public static func missingCoreTypes(in documents: [ConsentType: ConsentDocumentVersion]) -> [ConsentType] {
    coreTypes.filter { documents[$0] == nil }
  }

  /// ① refused: nothing else can be granted without it (V1-06 V8 `consent.requiredFirst`), so nothing is recorded.
  public static func requiredRefused(_ choices: [ConsentType: ConsentChoice]) -> Bool {
    choices[.required] == .refuse
  }

  /// What to record: one `grant` per granted card, in card order. A refusal of a type never granted is not recorded
  /// (F-PRIV-01.1: refused items leave no record). nil while a core card is unanswered, when ① is refused, or when a
  /// granted type has no published version.
  public static func selections(
    choices: [ConsentType: ConsentChoice], documents: [ConsentType: ConsentDocumentVersion]
  ) -> [ConsentSelection]? {
    guard coreTypes.allSatisfy({ choices[$0] != nil }), !requiredRefused(choices) else { return nil }
    var selections: [ConsentSelection] = []
    for type in coreTypes where choices[type] == .grant {
      guard let document = documents[type] else { return nil }
      selections.append(ConsentSelection(consentType: type, action: .grant, documentVersion: document.id))
    }
    return selections
  }
}

/// The `recordConsent` callable request (V1-06 §6.2.1) of an in-person capture on the trainer's iPad. Built when the
/// capture is saved and stored in its Outbox item; the SyncEngine sends it unchanged. MVP (DF-109, DF-110): no
/// `signaturePngBase64`; `reconfirmOf` is for the member app only and is left out.
public enum RecordConsentRequest {
  public static let callable = "recordConsent"
  public static let channel: ConsentChannel = .trainerDeviceInPerson
  /// Every key a trainer-app request has; V1-06 §6.2.1 `required` plus `capturedAt` (ASM-06-09).
  public static let keys: Set<String> = ["clientCaptureId", "memberKey", "channel", "selections", "capturedAt"]

  /// `capturedAt` stays a timestamp here; the callable client sends it as an ISO 8601 string (V1-06 `IsoTime`).
  public static func payload(
    captureId: String, member: MemberKey, selections: [ConsentSelection], capturedAt: Date
  ) -> JSONValue {
    .object([
      "clientCaptureId": .string(captureId),
      "memberKey": memberKey(member),
      "channel": .string(channel.rawValue),
      "selections": .array(selections.map { selection in
        .object([
          "consentType": .string(selection.consentType.rawValue),
          "action": .string(selection.action.rawValue),
          "documentVersion": .string(selection.documentVersion),
        ])
      }),
      "capturedAt": .timestamp(capturedAt),
    ])
  }

  /// V1-06 `MemberKey`: `{memberUid}` or `{pendingMemberId}`.
  public static func memberKey(_ member: MemberKey) -> JSONValue {
    switch member {
    case let .uid(id): return .object(["memberUid": .string(id)])
    case let .pending(id): return .object(["pendingMemberId": .string(id)])
    }
  }
}
