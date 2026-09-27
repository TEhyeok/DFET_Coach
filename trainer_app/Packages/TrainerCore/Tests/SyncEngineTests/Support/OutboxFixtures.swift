import Foundation
import SyncEngine
import TrainerDomain

/// Synthetic Outbox items. Member keys and paths are placeholders, never real data.
enum OutboxFixtures {
  static let createdAt = Date(timeIntervalSince1970: 1_800_000_000)

  /// The five NFR-05 steps of one SOAP note for `member` (AC-DF-015.1): consent, parent create, ink upload,
  /// path record, finalize.
  static func soapSteps(member: String, note: String, firstSequence: Int64 = 1) -> [OutboxItem] {
    let key = MemberKey.uid(member)
    let soap = LocalEntityRef.soap(noteId: note)
    let consent = LocalEntityRef.consent(captureId: "cap-\(member)")
    let fields: JSONValue = .object(["status": .string("draft"), "updatedAt": .serverTimestamp])
    return [
      OutboxItem(memberKey: key, entityRef: consent, sequence: firstSequence, stage: .consent, kind: .callConsent,
                 target: .callable(name: "recordConsent-\(member)"), payload: .object([:]), createdAt: createdAt),
      OutboxItem(memberKey: key, entityRef: soap, sequence: firstSequence + 1, stage: .document, kind: .createDocument,
                 target: .document(path: "soap_notes/\(note)"), payload: fields, createdAt: createdAt),
      OutboxItem(memberKey: key, entityRef: soap, sequence: firstSequence + 2, stage: .upload, kind: .uploadBinary,
                 target: .storage(path: "soapInk/\(note)/1.drawing"),
                 binary: LocalBinaryRef(localURL: URL(fileURLWithPath: "/tmp/\(note).drawing"),
                                        contentType: "application/octet-stream", sha256: "fx-sha"),
                 createdAt: createdAt),
      OutboxItem(memberKey: key, entityRef: soap, sequence: firstSequence + 3, stage: .pathRecord, kind: .recordBinaryPath,
                 target: .document(path: "soap_notes/\(note)"),
                 payload: .object(["inkPath": .string("soapInk/\(note)/1.drawing"), "inkRevision": .int(1)]),
                 createdAt: createdAt),
      OutboxItem(memberKey: key, entityRef: soap, sequence: firstSequence + 4, stage: .finalize, kind: .finalize,
                 target: .document(path: "soap_notes/\(note)"),
                 payload: .object(["status": .string("finalized"), "finalizedAt": .serverTimestamp]),
                 createdAt: createdAt),
    ]
  }

  /// One document create for `member` without a consent step.
  static func create(member: String, note: String, sequence: Int64 = 1) -> OutboxItem {
    OutboxItem(memberKey: .uid(member), entityRef: .soap(noteId: note), sequence: sequence, stage: .document,
               kind: .createDocument, target: .document(path: "soap_notes/\(note)"),
               payload: .object(["status": .string("draft")]), createdAt: createdAt)
  }
}
