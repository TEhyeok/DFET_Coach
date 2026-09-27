import FirebaseFirestore
import Foundation
import os
import TrainerDomain

/// The Firestore reads behind `FirestoreMemberDirectory`, separated so tests can use a fake.
protocol MemberDirectoryGateway: Sendable {
  /// `trainers/{uid}.memberIds` now and after every change; an absent document is an empty list.
  func memberIds(trainerUid: String) -> AsyncThrowingStream<[String], Error>
  /// `users where documentId in ids` (at most `MemberChunks.size` ids), reading only `displayName` and `trainerId`.
  func users(ids: [String]) async throws -> [Member]
}

/// Assigned members from a `trainers/{uid}` listener and chunked `users` reads (DF-013, ported from
/// dfet:trainer_ios/DFETTrainer/Data/FirebaseTrainerRepository.swift:158-220 without its print-and-continue errors).
///
/// - Every `memberIds` change cancels the previous chunk reads and reads again (AC-DF-013.1).
/// - All chunks must succeed; one failed chunk fails the stream and nothing partial is emitted (AC-DF-013.2, §9.6).
/// - The list keeps the order of `memberIds`.
public final class FirestoreMemberDirectory: MemberDirectory, Sendable {
  private let trainerUid: String
  private let gateway: any MemberDirectoryGateway

  public convenience init(trainerUid: String) {
    self.init(trainerUid: trainerUid, gateway: FirestoreMemberGateway())
  }

  init(trainerUid: String, gateway: any MemberDirectoryGateway) {
    self.trainerUid = trainerUid
    self.gateway = gateway
  }

  public func observeAssignedMembers() -> AsyncThrowingStream<[Member], Error> {
    let trainerUid = trainerUid
    let gateway = gateway
    return AsyncThrowingStream { continuation in
      let task = Task {
        var reading: Task<Void, Never>?
        do {
          for try await ids in gateway.memberIds(trainerUid: trainerUid) {
            reading?.cancel()
            reading = Task {
              do {
                let members = try await Self.members(for: ids, gateway: gateway)
                if !Task.isCancelled { continuation.yield(members) }
              } catch is CancellationError {
                // superseded by a newer memberIds value
              } catch {
                if !Task.isCancelled { continuation.finish(throwing: MemberDirectoryErrorMapper.map(error)) }
              }
            }
          }
          await reading?.value
          continuation.finish()
        } catch {
          reading?.cancel()
          continuation.finish(throwing: MemberDirectoryErrorMapper.map(error))
        }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  /// Reads every chunk concurrently; any failure throws and discards the rest.
  static func members(for ids: [String], gateway: any MemberDirectoryGateway) async throws -> [Member] {
    let chunks = MemberChunks.chunk(ids)
    var byId: [String: Member] = [:]
    try await withThrowingTaskGroup(of: [Member].self) { group in
      for chunk in chunks {
        group.addTask { try await gateway.users(ids: chunk) }
      }
      for try await members in group {
        for member in members { byId[member.id] = member }
      }
    }
    try Task.checkCancellation()
    return chunks.flatMap { $0 }.compactMap { byId[$0] }
  }
}

/// Maps Firestore errors to `MemberDirectoryError` by code (AC-DF-013.2).
enum MemberDirectoryErrorMapper {
  static func map(_ error: Error) -> MemberDirectoryError {
    if let mapped = error as? MemberDirectoryError { return mapped }
    let ns = error as NSError
    guard ns.domain == FirestoreErrorDomain, let code = FirestoreErrorCode.Code(rawValue: ns.code) else {
      return .unknown(code: ns.code)
    }
    switch code {
    case .permissionDenied: return .permissionDenied
    case .failedPrecondition: return .indexMissing
    case .unavailable: return .unavailable
    default: return .unknown(code: ns.code)
    }
  }
}

/// Firestore implementation of the gateway.
struct FirestoreMemberGateway: MemberDirectoryGateway {
  func memberIds(trainerUid: String) -> AsyncThrowingStream<[String], Error> {
    AsyncThrowingStream { continuation in
      let registration = Firestore.firestore().collection("trainers").document(trainerUid)
        .addSnapshotListener { snapshot, error in
          if let error {
            continuation.finish(throwing: error)
            return
          }
          continuation.yield((snapshot?.get("memberIds") as? [String]) ?? [])
        }
      continuation.onTermination = { _ in registration.remove() }
    }
  }

  func users(ids: [String]) async throws -> [Member] {
    guard !ids.isEmpty else { return [] }
    let snapshot = try await Firestore.firestore().collection("users")
      .whereField(FieldPath.documentID(), in: ids)
      .getDocuments()
    return snapshot.documents.map { document in
      Member(
        id: document.documentID,
        displayName: (document.get("displayName") as? String) ?? "",
        trainerId: document.get("trainerId") as? String)
    }
  }
}
