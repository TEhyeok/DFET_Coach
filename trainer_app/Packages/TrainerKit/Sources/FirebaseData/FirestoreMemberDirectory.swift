import FirebaseFirestore
import Foundation
import os
import TrainerDomain

/// One `trainers/{uid}` value as the gateway saw it.
struct MemberIdsSnapshot: Equatable, Sendable {
  /// `memberIds`; nil when the field is present but not a list of strings.
  let ids: [String]?
  let exists: Bool
  /// Answered from the device cache (offline or before the server replied).
  let isFromCache: Bool
}

/// One chunk of `users` documents.
struct UsersChunk: Sendable {
  let members: [Member]
  let isFromCache: Bool
}

/// The Firestore reads behind `FirestoreMemberDirectory`, separated so tests can use a fake.
protocol MemberDirectoryGateway: Sendable {
  /// `trainers/{uid}` now and after every change.
  func memberIds(trainerUid: String) -> AsyncThrowingStream<MemberIdsSnapshot, Error>
  /// `users where documentId in ids` (at most `MemberChunks.size` ids).
  func users(ids: [String]) async throws -> UsersChunk
}

/// Assigned members from a `trainers/{uid}` listener and chunked `users` reads (DF-013, ported from
/// dfet:trainer_ios/DFETTrainer/Data/FirebaseTrainerRepository.swift:158-220 without its print-and-continue errors).
///
/// - Every `memberIds` change cancels the reads for the previous value; a superseded read never emits or fails the
///   stream (AC-DF-013.1).
/// - All chunks must succeed; a failed chunk fails the stream and nothing partial is emitted (AC-DF-013.2, §9.6).
/// - Offline, cached data is used only when it is complete: an unknown `trainers/{uid}` or a cached chunk that is
///   missing members fails with `.unavailable` instead of showing an empty or partial list (§9.6).
/// - The list keeps the order of `memberIds`. Failures are logged by code only.
///
/// Privacy: only `displayName` and `trainerId` are used, but the client SDK cannot fetch single fields, so each
/// `users/{uid}` document is downloaded whole and kept in the Firestore cache. A trainer-scoped projection that holds
/// only these two fields is a follow-up (issue linked from PR #169); until real uid members exist (after the MVP,
/// DEC-22) no `users` document is read.
public final class FirestoreMemberDirectory: MemberDirectory, Sendable {
  private static let logger = Logger(subsystem: "kr.co.dfet.trainer", category: "members")
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
      let run = StreamRun()
      continuation.onTermination = { _ in run.cancelAll() }  // set before any work starts
      run.setOuter(Task {
        do {
          for try await snapshot in gateway.memberIds(trainerUid: trainerUid) {
            let ids = try Self.ids(from: snapshot)
            let generation = run.nextGeneration()
            run.setRead(Task {
              do {
                let members = try await Self.members(for: ids, gateway: gateway)
                run.ifCurrent(generation) { continuation.yield(members) }
              } catch is CancellationError {
                // superseded by a newer memberIds value or the consumer went away
              } catch {
                run.ifCurrent(generation) { Self.fail(continuation, error) }
              }
            })
          }
          await run.awaitRead()
          continuation.finish()
        } catch {
          run.cancelRead()
          Self.fail(continuation, error)
        }
      })
    }
  }

  private static func fail(_ continuation: AsyncThrowingStream<[Member], Error>.Continuation, _ error: Error) {
    let mapped = MemberDirectoryErrorMapper.map(error)
    logger.error("assigned members failed: \(String(describing: mapped), privacy: .public)")
    continuation.finish(throwing: mapped)
  }

  static func ids(from snapshot: MemberIdsSnapshot) throws -> [String] {
    if !snapshot.exists {
      // Offline without a cached copy we do not know the assignment; the server knows there is none.
      if snapshot.isFromCache { throw MemberDirectoryError.unavailable }
      return []
    }
    guard let ids = snapshot.ids else { throw MemberDirectoryError.unknown(code: 0) }
    return ids
  }

  /// Reads every chunk concurrently; any failure, or a cached chunk that is missing members, throws.
  static func members(for ids: [String], gateway: any MemberDirectoryGateway) async throws -> [Member] {
    let chunks = MemberChunks.chunk(ids)
    var byId: [String: Member] = [:]
    try await withThrowingTaskGroup(of: (requested: Int, chunk: UsersChunk).self) { group in
      for chunk in chunks {
        group.addTask { (chunk.count, try await gateway.users(ids: chunk)) }
      }
      for try await result in group {
        if result.chunk.isFromCache, result.chunk.members.count < result.requested {
          throw MemberDirectoryError.unavailable  // offline with only part of the chunk cached
        }
        for member in result.chunk.members { byId[member.id] = member }
      }
    }
    try Task.checkCancellation()
    return chunks.flatMap { $0 }.compactMap { byId[$0] }
  }
}

/// Task bookkeeping of one stream: the listener task, the current read and its generation, under one lock so a stale
/// read can never emit after a newer one. The lock is recursive: `finish` inside `ifCurrent` runs the stream's
/// `onTermination` (`cancelAll`) synchronously on the same thread.
private final class StreamRun: @unchecked Sendable {
  private let lock = NSRecursiveLock()
  private var outer: Task<Void, Never>?
  private var read: Task<Void, Never>?
  private var generation = 0
  private var cancelled = false

  func setOuter(_ task: Task<Void, Never>) {
    let cancelNow: Bool = lock.withLock {
      outer = task
      return cancelled
    }
    if cancelNow { task.cancel() }
  }

  func nextGeneration() -> Int {
    lock.withLock {
      read?.cancel()
      generation += 1
      return generation
    }
  }

  func setRead(_ task: Task<Void, Never>) {
    let cancelNow: Bool = lock.withLock {
      read = task
      return cancelled
    }
    if cancelNow { task.cancel() }
  }

  /// Runs `body` (a yield or finish) only for the newest read of a live stream, atomically with the check.
  func ifCurrent(_ generation: Int, _ body: () -> Void) {
    lock.withLock {
      guard !cancelled, self.generation == generation, !Task.isCancelled else { return }
      body()
    }
  }

  func awaitRead() async {
    let task = lock.withLock { read }
    await task?.value
  }

  func cancelRead() {
    lock.withLock { read }?.cancel()
  }

  func cancelAll() {
    let tasks: [Task<Void, Never>?] = lock.withLock {
      cancelled = true
      return [outer, read]
    }
    tasks.forEach { $0?.cancel() }
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
  func memberIds(trainerUid: String) -> AsyncThrowingStream<MemberIdsSnapshot, Error> {
    AsyncThrowingStream { continuation in
      let registration = Firestore.firestore().collection("trainers").document(trainerUid)
        .addSnapshotListener { snapshot, error in
          if let error {
            continuation.finish(throwing: error)
            return
          }
          guard let snapshot else { return }
          let raw = snapshot.get("memberIds")
          continuation.yield(MemberIdsSnapshot(
            ids: raw == nil ? [] : raw as? [String], exists: snapshot.exists,
            isFromCache: snapshot.metadata.isFromCache))
        }
      continuation.onTermination = { _ in registration.remove() }
    }
  }

  func users(ids: [String]) async throws -> UsersChunk {
    guard !ids.isEmpty else { return UsersChunk(members: [], isFromCache: false) }
    let snapshot = try await Firestore.firestore().collection("users")
      .whereField(FieldPath.documentID(), in: ids)
      .getDocuments()
    let members = snapshot.documents.map { document in
      Member(
        id: document.documentID,
        displayName: (document.get("displayName") as? String) ?? "",
        trainerId: document.get("trainerId") as? String)
    }
    return UsersChunk(members: members, isFromCache: snapshot.metadata.isFromCache)
  }
}
