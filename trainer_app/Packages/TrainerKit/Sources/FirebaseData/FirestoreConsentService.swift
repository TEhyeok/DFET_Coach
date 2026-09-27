import FirebaseFirestore
import Foundation
import os
import TrainerDomain

/// One read of the published `consentDocumentVersions`.
struct ConsentDocumentsRead: Sendable {
  let documents: [(id: String, data: JSONValue)]
  /// Answered from the device cache (offline, or before the server replied).
  let isFromCache: Bool
}

/// The Firestore reads behind `FirestoreConsentService`, separated so tests can use a fake.
protocol ConsentGateway: Sendable {
  /// `memberConsentStates/{documentID}` now and after every change; nil while the document does not exist.
  func consentState(documentID: String) -> AsyncThrowingStream<JSONValue?, Error>
  /// `consentDocumentVersions where status == 'published'`.
  func publishedDocuments() async throws -> ConsentDocumentsRead
}

/// Consent reads for TR-14 and every consent guard (DF-110, DF-111 MVP). Writes never happen here: consent is
/// recorded by the `recordConsent` callable through the Outbox (V1-06 §6.2), and `memberConsentStates` is written by
/// the server only (R-20).
///
/// - `observe(member:)` (`ConsentStateSource`) listens to `memberConsentStates/{memberKey}` (registered in
///   `FirestoreListenerRegistry`, so logout removes it). A missing document is nil (no consent). When the listener
///   fails, for example a pending member whose `pendingMembers` document is not on the server yet (the read rule
///   cannot prove ownership), the stream yields nil and ends; `EffectiveConsentResolver` subscribes again after the
///   member's next capture change.
/// - `publishedDocuments()` (`ConsentDocumentCatalog`) reads the published versions (V1-05 §4.13). A cache-only answer
///   that lacks one of ①②③ throws `RemoteError.unavailable` instead of claiming the document does not exist.
public final class FirestoreConsentService: ConsentStateSource, ConsentDocumentCatalog, Sendable {
  private static let logger = Logger(subsystem: "kr.co.dfet.trainer", category: "consent")
  private let gateway: any ConsentGateway

  public convenience init() {
    self.init(gateway: FirestoreConsentGateway())
  }

  init(gateway: any ConsentGateway) {
    self.gateway = gateway
  }

  public func observe(member: MemberKey) -> AsyncStream<ConsentState?> {
    let states = gateway.consentState(documentID: member.id)
    return AsyncStream { continuation in
      let task = Task {
        do {
          for try await document in states {
            continuation.yield(document.map { ConsentState(document: $0) })
          }
        } catch {
          Self.logger.notice("consent state listener ended: \(RemoteErrorMapper.map(error).code, privacy: .public)")
          continuation.yield(nil)
        }
        continuation.finish()
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  public func publishedDocuments() async throws -> [ConsentDocumentVersion] {
    let read: ConsentDocumentsRead
    do {
      read = try await gateway.publishedDocuments()
    } catch {
      let remote = RemoteErrorMapper.map(error)
      Self.logger.error("consent documents failed: \(remote.code, privacy: .public)")
      throw remote
    }
    let documents = read.documents.compactMap { ConsentDocumentVersion(id: $0.id, document: $0.data) }
    if read.isFromCache,
      !ConsentFlowRules.missingCoreTypes(in: ConsentFlowRules.latestPublished(documents)).isEmpty {
      throw RemoteError.unavailable  // offline without every document cached: unknown, not missing
    }
    return documents
  }
}

/// Firestore implementation of the gateway.
struct FirestoreConsentGateway: ConsentGateway {
  func consentState(documentID: String) -> AsyncThrowingStream<JSONValue?, Error> {
    AsyncThrowingStream { continuation in
      let registration = Firestore.firestore().collection("memberConsentStates").document(documentID)
        .addSnapshotListener { snapshot, error in
          if let error {
            continuation.finish(throwing: error)
            return
          }
          guard let snapshot else { return }
          continuation.yield(snapshot.exists ? JSONValueFirestoreMapper.json(snapshot.data()) : nil)
        }
      let token = FirestoreListenerRegistry.shared.add(registration)
      continuation.onTermination = { _ in FirestoreListenerRegistry.shared.remove(token) }
    }
  }

  func publishedDocuments() async throws -> ConsentDocumentsRead {
    let snapshot = try await Firestore.firestore().collection("consentDocumentVersions")
      .whereField("status", isEqualTo: "published")
      .getDocuments()
    return ConsentDocumentsRead(
      documents: snapshot.documents.map { ($0.documentID, JSONValueFirestoreMapper.json($0.data())) },
      isFromCache: snapshot.metadata.isFromCache)
  }
}
