import FirebaseFirestore
import Foundation
import os
import TrainerContracts
import TrainerDomain

/// The read side of TR-14. Capture writes belong to LocalStore + SyncEngine, never to a view's Firebase adapter.
public final class FirestoreConsentService: ConsentDocumentsSource, ConsentStateSource, Sendable {
  private static let logger = Logger(subsystem: "kr.co.dfet.trainer", category: "consent")
  private let access: any ConsentReadAccess

  public convenience init() { self.init(access: LiveConsentReadAccess()) }

  init(access: any ConsentReadAccess) { self.access = access }

  public func publishedDocuments() async throws -> [ConsentDocumentVersion] {
    do {
      let documents = try await access.publishedDocuments()
      return try documents.map { try Self.document(id: $0.id, fields: $0.fields) }
    } catch {
      Self.logger.error("consent document read failed")
      throw error
    }
  }

  public func observe(member: MemberKey) -> AsyncStream<ConsentState?> { observeState(member: member) }

  public func observeState(member: MemberKey) -> AsyncStream<ConsentState?> {
    let access = access
    return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
      let task = Task {
        do {
          for try await fields in access.observe(member: member) {
            guard !Task.isCancelled else { break }
            continuation.yield(fields.map { ConsentState(document: $0) })
          }
        } catch {
          // The source protocol has no error case. A lost permission/read must remove any old grant, not retain it.
          Self.logger.error("consent state read failed")
          if !Task.isCancelled { continuation.yield(nil) }
        }
        continuation.finish()
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  /// Strict decoding prevents submitting a card with missing disclosure fields (AC-DF-110.1/.3).
  static func document(id: String, fields: JSONValue) throws -> ConsentDocumentVersion {
    guard let rawType = fields["consentType"]?.stringValue, let type = ConsentType(rawValue: rawType),
          let version = fields["version"]?.stringValue, let title = fields["title"]?.stringValue,
          let purpose = fields["purpose"]?.stringValue, let rawItems = fields["items"]?.arrayValue,
          let retention = fields["retention"]?.stringValue, let refusal = fields["refusalNotice"]?.stringValue,
          let policy = fields["privacyPolicyVersion"]?.stringValue,
          let rawStatus = fields["status"]?.stringValue, let status = ConsentDocumentVersion.Status(rawValue: rawStatus),
          case let .timestamp(publishedAt)? = fields["publishedAt"],
          rawItems.allSatisfy({ $0.stringValue != nil }) else { throw ConsentServiceError.documentMissing }
    let document = ConsentDocumentVersion(
      id: id, consentType: type, version: version, title: title, purpose: purpose,
      items: rawItems.compactMap(\.stringValue), retention: retention, recipient: fields["recipient"]?.stringValue,
      refusalNotice: refusal, privacyPolicyVersion: policy, status: status, publishedAt: publishedAt)
    guard document.isCompletePublished else { throw ConsentServiceError.documentMissing }
    return document
  }
}

struct ConsentDocumentSnapshot: Sendable {
  let id: String
  let fields: JSONValue
}

protocol ConsentReadAccess: Sendable {
  func publishedDocuments() async throws -> [ConsentDocumentSnapshot]
  func observe(member: MemberKey) -> AsyncThrowingStream<JSONValue?, Error>
}

private struct LiveConsentReadAccess: ConsentReadAccess {
  func publishedDocuments() async throws -> [ConsentDocumentSnapshot] {
    let snapshot = try await Firestore.firestore().collection("consentDocumentVersions")
      .whereField("status", isEqualTo: "published").getDocuments()
    return snapshot.documents.map { ConsentDocumentSnapshot(id: $0.documentID, fields: JSONValueFirestoreMapper.json($0.data())) }
  }

  func observe(member: MemberKey) -> AsyncThrowingStream<JSONValue?, Error> {
    AsyncThrowingStream { continuation in
      let path = "memberConsentStates/" + member.id
      do { try FirestorePayload.validateDocumentPath(path) } catch {
        continuation.finish(throwing: error)
        return
      }
      let registration = Firestore.firestore().document(path).addSnapshotListener { snapshot, error in
        if let error {
          continuation.finish(throwing: RemoteErrorMapper.map(error))
          return
        }
        guard let snapshot else { return }
        continuation.yield(snapshot.exists ? JSONValueFirestoreMapper.json(snapshot.data()) : nil)
      }
      // Logout removing the listener ends the stream as a failed read, so `observeState` drops the last grant
      // (yields nil) instead of keeping it or waiting forever (DF-018).
      let token = FirestoreListenerRegistry.shared.add(registration) {
        continuation.finish(throwing: RemoteError.unavailable)
      }
      continuation.onTermination = { _ in FirestoreListenerRegistry.shared.remove(token) }
    }
  }
}
