import Foundation
import TrainerContracts
import TrainerDomain
import XCTest
@testable import FirebaseData

/// DF-110 MVP: `FirestoreConsentService` (the `memberConsentStates` listener as a `ConsentStateSource`, the published
/// versions) and the `recordConsent` request as the callable client sends it (V1-06 §6.2.1). Synthetic data only.
final class FirestoreConsentServiceTests: XCTestCase {
  private let published = Date(timeIntervalSince1970: 1_793_577_600)  // 2026-11-02T00:00:00Z

  private func document(_ type: ConsentType, status: String = "published", version: String = "1.0") -> (String, JSONValue) {
    ("\(type.rawValue)--\(version)", .object([
      "consentType": .string(type.rawValue), "version": .string(version), "status": .string(status),
      "publishedAt": .timestamp(published), "schemaVersion": .int(1),
    ]))
  }

  private func values(_ stream: AsyncStream<ConsentStateReading>) async -> [ConsentStateReading] {
    var values: [ConsentStateReading] = []
    for await value in stream { values.append(value) }
    return values
  }

  // MARK: memberConsentStates

  func testTheListenerMapsTheDocumentAndNoDocumentIsAbsent() async {
    let state: JSONValue = .object([
      "required": .object(["granted": .bool(true), "documentVersion": .string("required--1.0")]),
      "healthData": .object(["granted": .bool(true), "documentVersion": .string("healthData--1.0")]),
      "bodyImaging": .object(["granted": .bool(false), "documentVersion": .string("bodyImaging--1.0")]),
    ])
    let gateway = FakeConsentGateway(states: [nil, state])
    let service = FirestoreConsentService(gateway: gateway)
    let emitted = await values(service.observe(member: .pending("SYNTHpending00000001")))
    XCTAssertEqual(emitted, [.absent, .present(ConsentState(document: state))])
    XCTAssertEqual(gateway.observedDocumentIDs, ["SYNTHpending00000001"], "memberConsentStates/{pendingMemberId}")
    XCTAssertEqual(emitted.last?.state?.isGranted(.healthData), true)
    XCTAssertEqual(emitted.last?.state?.isGranted(.bodyImaging), false)
  }

  /// Review (P1a DF-110, V1-06 §8.10): a listener the rules refuse (a pending member whose create has not reached the
  /// server yet) or a transient error is `unavailable`, never "no document", and ends; the resolver subscribes again.
  func testAFailedListenerIsUnavailableNotAbsentAndEnds() async {
    for code in [7, 14] {  // permission-denied, unavailable
      let gateway = FakeConsentGateway(states: [], failure: NSError(domain: "FIRFirestoreErrorDomain", code: code))
      let emitted = await values(FirestoreConsentService(gateway: gateway).observe(member: .uid("synthMember0001")))
      XCTAssertEqual(emitted, [.unavailable], "\(code)")
      XCTAssertEqual(gateway.observedDocumentIDs, ["synthMember0001"])
    }
    let answered = FakeConsentGateway(states: [nil], failure: NSError(domain: "FIRFirestoreErrorDomain", code: 14))
    let emitted = await values(FirestoreConsentService(gateway: answered).observe(member: .uid("synthMember0001")))
    XCTAssertEqual(emitted, [.absent, .unavailable])
  }

  // MARK: consentDocumentVersions

  func testPublishedDocumentsKeepOnlyPublishedVersions() async throws {
    let gateway = FakeConsentGateway(documents: ConsentDocumentsRead(documents: [
      document(.required), document(.healthData), document(.bodyImaging),
      document(.healthData, status: "retired", version: "0.9"),
    ], isFromCache: false))
    let documents = try await FirestoreConsentService(gateway: gateway).publishedDocuments()
    XCTAssertEqual(documents.map(\.id), ["required--1.0", "healthData--1.0", "bodyImaging--1.0"])
  }

  /// The server's answer is final: a missing type is really missing (the step shows `tr14.consent.documentMissing`).
  /// A cache-only answer without every core type is unknown: `unavailable` (`common.onlineRequired`).
  func testAnIncompleteCacheIsUnavailableButAnIncompleteServerAnswerIsNot() async throws {
    let partial = [document(.required), document(.healthData)]
    let server = FakeConsentGateway(documents: ConsentDocumentsRead(documents: partial, isFromCache: false))
    let fromServer = try await FirestoreConsentService(gateway: server).publishedDocuments()
    XCTAssertEqual(fromServer.count, 2)

    let cache = FakeConsentGateway(documents: ConsentDocumentsRead(documents: partial, isFromCache: true))
    do {
      _ = try await FirestoreConsentService(gateway: cache).publishedDocuments()
      XCTFail("expected unavailable")
    } catch {
      XCTAssertEqual(error as? RemoteError, .unavailable)
    }

    let complete = FakeConsentGateway(documents: ConsentDocumentsRead(
      documents: partial + [document(.bodyImaging)], isFromCache: true))
    let fromCache = try await FirestoreConsentService(gateway: complete).publishedDocuments()
    XCTAssertEqual(fromCache.count, 3, "a complete cache is usable offline")
  }

  // MARK: recordConsent on the wire

  /// What `FunctionsCallableClient` sends for a stored capture item: plain JSON with `capturedAt` as an ISO 8601
  /// string in milliseconds (V1-06 `IsoTime`), nothing else added.
  func testTheCallablePayloadIsPlainV1_06Json() throws {
    let capturedAt = Date(timeIntervalSince1970: 1_794_791_550)  // 2026-11-16T01:12:30Z
    let payload = RecordConsentRequest.payload(
      captureId: "3f2b8c1e-5d7a-4b1e-9a51-0c8e2d7f1a90", member: .pending("SYNTHpending00000001"),
      selections: [ConsentSelection(consentType: .required, action: .grant, documentVersion: "required--1.0")],
      capturedAt: capturedAt)
    let plain = try XCTUnwrap(try FunctionsCallableClient.plain(payload) as? [String: Any])
    let json = try JSONSerialization.data(withJSONObject: plain, options: [.sortedKeys])
    XCTAssertEqual(String(decoding: json, as: UTF8.self), #"""
      {"capturedAt":"2026-11-16T01:12:30.000Z","channel":"trainerDeviceInPerson",\#
      "clientCaptureId":"3f2b8c1e-5d7a-4b1e-9a51-0c8e2d7f1a90","memberKey":{"pendingMemberId":"SYNTHpending00000001"},\#
      "selections":[{"action":"grant","consentType":"required","documentVersion":"required--1.0"}]}
      """#)
  }
}

private final class FakeConsentGateway: ConsentGateway, @unchecked Sendable {
  private let lock = NSLock()
  private let states: [JSONValue?]
  private let failure: Error?
  private let documents: ConsentDocumentsRead
  private var _observed: [String] = []

  init(states: [JSONValue?] = [], failure: Error? = nil,
       documents: ConsentDocumentsRead = ConsentDocumentsRead(documents: [], isFromCache: false)) {
    self.states = states
    self.failure = failure
    self.documents = documents
  }

  var observedDocumentIDs: [String] { lock.withLock { _observed } }

  func consentState(documentID: String) -> AsyncThrowingStream<JSONValue?, Error> {
    lock.withLock { _observed.append(documentID) }
    let states = states
    let failure = failure
    return AsyncThrowingStream { continuation in
      states.forEach { continuation.yield($0) }
      continuation.finish(throwing: failure)
    }
  }

  func publishedDocuments() async throws -> ConsentDocumentsRead {
    documents
  }
}
