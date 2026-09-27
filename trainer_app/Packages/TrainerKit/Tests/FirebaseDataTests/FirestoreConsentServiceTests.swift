import Foundation
import TrainerContracts
import TrainerDomain
import XCTest
@testable import FirebaseData

final class FirestoreConsentServiceTests: XCTestCase {
  func testAC_DF_110_1_readsDisclosureFieldsAndPreservesDocumentID() throws {
    let card = try FirestoreConsentService.document(id: "healthData--test-1", fields: Self.card)
    XCTAssertEqual(card.consentType, .healthData)
    XCTAssertEqual(card.id, "healthData--test-1")
    XCTAssertEqual(card.version, "test-1")
    XCTAssertEqual(card.items, ["Synthetic item"])
    XCTAssertTrue(card.isCompletePublished)
  }

  func testAC_DF_110_3_missingOrMalformedDisclosureFailsClosed() {
    var fields = Self.card.objectValue!
    fields["items"] = .array([.int(1)])
    XCTAssertThrowsError(try FirestoreConsentService.document(id: "healthData--test-1", fields: .object(fields)))
    fields["items"] = .array([.string("Synthetic item")])
    fields["refusalNotice"] = .string(" ")
    XCTAssertThrowsError(try FirestoreConsentService.document(id: "healthData--test-1", fields: .object(fields)))
    fields["refusalNotice"] = .string("Synthetic refusal")
    fields["status"] = .string("retired")
    XCTAssertThrowsError(try FirestoreConsentService.document(id: "healthData--test-1", fields: .object(fields)))
  }

  func testStateReadErrorClearsAnEarlierGrant() async {
    let access = FakeConsentReadAccess()
    let service = FirestoreConsentService(access: access)
    var iterator = service.observe(member: .pending("SYNTHpending00000001")).makeAsyncIterator()
    access.send(.object(["healthData": .object(["granted": .bool(true)])]))
    let first = await iterator.next()
    XCTAssertEqual(first??.isGranted(.healthData), true)
    access.fail()
    guard let cleared = await iterator.next() else {
      return XCTFail("Failure must publish a nil state before ending the stream")
    }
    XCTAssertNil(cleared)
  }

  private static let card: JSONValue = .object([
    "consentType": .string("healthData"), "version": .string("test-1"), "status": .string("published"),
    "title": .string("Synthetic card"), "purpose": .string("Synthetic purpose"),
    "items": .array([.string("Synthetic item")]), "retention": .string("Test retention"),
    "refusalNotice": .string("Synthetic refusal"), "privacyPolicyVersion": .string("test-policy"),
    "publishedAt": .timestamp(Date(timeIntervalSince1970: 1_800_000_000)),
  ])
}

private final class FakeConsentReadAccess: ConsentReadAccess, @unchecked Sendable {
  private let stream: AsyncThrowingStream<JSONValue?, Error>
  private let continuation: AsyncThrowingStream<JSONValue?, Error>.Continuation
  init() { (stream, continuation) = AsyncThrowingStream.makeStream() }
  func publishedDocuments() async throws -> [ConsentDocumentSnapshot] { [] }
  func observe(member: MemberKey) -> AsyncThrowingStream<JSONValue?, Error> { stream }
  func send(_ fields: JSONValue) { continuation.yield(fields) }
  func fail() { continuation.finish(throwing: RemoteError.permissionDenied) }
}
