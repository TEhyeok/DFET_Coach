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
///   stream (AC-DF-013.1). A snapshot whose `memberIds` did not change (a metadata change) starts no read, unless the
///   server confirms a value the last read answered from the cache or could not answer.
/// - All chunks must succeed; a failed chunk fails the stream and nothing partial is emitted (AC-DF-013.2, §9.6).
/// - Firestore answers a new listener from the cache first, even online. What only the server can decide waits for
///   the server's snapshot, for at most `serverWait`, and then fails with `.unavailable` (or the read's error):
///   a cached "no `trainers/{uid}` document" (unknown offline, empty online), and a failed read for a cached
///   `memberIds` value (a member unassigned since, or a chunk only partly cached). Offline, cached data is used only
///   when it is complete (§9.6).
/// - The list keeps the order of `memberIds`. Failures are logged by code only.
///
/// Privacy: only `displayName` and `trainerId` are used, but the client SDK cannot fetch single fields, so each
/// `users/{uid}` document is downloaded whole and kept in the Firestore cache. A trainer-scoped projection that holds
/// only these two fields is a follow-up (issue #171); until real uid members exist (after the MVP, DEC-22) no `users`
/// document is read.
public final class FirestoreMemberDirectory: MemberDirectory, Sendable {
  fileprivate static let logger = Logger(subsystem: "kr.co.dfet.trainer", category: "members")
  private let trainerUid: String
  private let gateway: any MemberDirectoryGateway
  private let serverWait: Duration

  public convenience init(trainerUid: String) {
    self.init(trainerUid: trainerUid, gateway: FirestoreMemberGateway())
  }

  init(trainerUid: String, gateway: any MemberDirectoryGateway, serverWait: Duration = .seconds(10)) {
    self.trainerUid = trainerUid
    self.gateway = gateway
    self.serverWait = serverWait
  }

  public func observeAssignedMembers() -> AsyncThrowingStream<[Member], Error> {
    let trainerUid = trainerUid
    let gateway = gateway
    let serverWait = serverWait
    return AsyncThrowingStream { continuation in
      let task = Task {
        await AssignedMembersRun(gateway: gateway, serverWait: serverWait, output: continuation)
          .run(trainerUid: trainerUid)
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  /// The `memberIds` of a snapshot that is not a cached "no document" (the run waits for the server on those).
  static func ids(from snapshot: MemberIdsSnapshot) throws -> [String] {
    guard snapshot.exists else { return [] }  // the server says there is no assignment
    guard let ids = snapshot.ids else { throw MemberDirectoryError.unknown(code: 0) }
    return ids
  }

  /// Reads every chunk concurrently; any failure, or a cached chunk that is missing members, throws.
  static func members(for ids: [String], gateway: any MemberDirectoryGateway) async throws -> MemberRead {
    let chunks = MemberChunks.chunk(ids)
    var byId: [String: Member] = [:]
    var fromCache = false
    try await withThrowingTaskGroup(of: (requested: Int, chunk: UsersChunk).self) { group in
      for chunk in chunks {
        group.addTask { (chunk.count, try await gateway.users(ids: chunk)) }
      }
      for try await result in group {
        if result.chunk.isFromCache, result.chunk.members.count < result.requested {
          throw MemberDirectoryError.unavailable  // offline with only part of the chunk cached
        }
        fromCache = fromCache || result.chunk.isFromCache
        for member in result.chunk.members { byId[member.id] = member }
      }
    }
    try Task.checkCancellation()
    return MemberRead(members: chunks.flatMap { $0 }.compactMap { byId[$0] }, fromCache: fromCache)
  }
}

/// The result of one read of all chunks.
struct MemberRead: Equatable, Sendable {
  let members: [Member]
  /// At least one chunk was answered from the cache.
  let fromCache: Bool
}

/// One subscription as an event loop: the listener, the current read and the server wait only post events, and only
/// this loop changes state or touches the output, so a stale read can never emit after a newer one. Confined to the
/// task that runs it; cancelling that task ends the loop and cancels the listener, the read and the wait.
private final class AssignedMembersRun {
  private enum Event: Sendable {
    case snapshot(MemberIdsSnapshot)
    case listenerEnded(Error?)
    case read(generation: Int, Result<MemberRead, Error>)
    case serverWaitElapsed(token: Int)
  }

  private let gateway: any MemberDirectoryGateway
  private let serverWait: Duration
  private let output: AsyncThrowingStream<[Member], Error>.Continuation
  private let events: AsyncStream<Event>
  private let post: AsyncStream<Event>.Continuation

  private var generation = 0
  /// `memberIds` of the current or last read.
  private var readIds: [String]?
  private var readTask: Task<Void, Never>?
  private var reading = false
  /// A server snapshot has shown `readIds`, so a failure of their read is final. (A confirmation that arrives after
  /// the failure reads the list once more instead; that read's failure is final.)
  private var confirmed = false
  private var lastReadFromCache = false
  /// A failure that stands unless the server's snapshot says otherwise within `serverWait`.
  private var pending: (error: MemberDirectoryError, token: Int)?
  private var waitTask: Task<Void, Never>?
  private var waitTokens = 0
  private var listenerEnded = false

  init(gateway: any MemberDirectoryGateway, serverWait: Duration,
       output: AsyncThrowingStream<[Member], Error>.Continuation) {
    self.gateway = gateway
    self.serverWait = serverWait
    self.output = output
    (events, post) = AsyncStream.makeStream(of: Event.self)
  }

  func run(trainerUid: String) async {
    let gateway = gateway
    let post = post
    let listener = Task {
      do {
        for try await snapshot in gateway.memberIds(trainerUid: trainerUid) { post.yield(.snapshot(snapshot)) }
        post.yield(.listenerEnded(nil))
      } catch {
        post.yield(.listenerEnded(error))
      }
    }
    defer {
      listener.cancel()
      readTask?.cancel()
      waitTask?.cancel()
      post.finish()
    }
    for await event in events {
      if handle(event) { return }
    }
  }

  /// Returns true when the output has finished.
  private func handle(_ event: Event) -> Bool {
    switch event {
    case let .snapshot(snapshot):
      return receive(snapshot)
    case let .read(generation, result):
      guard generation == self.generation else { return false }  // superseded
      reading = false
      switch result {
      case let .success(read):
        lastReadFromCache = read.fromCache
        output.yield(read.members)
        return listenerEnded ? settle() : false
      case let .failure(error):
        if confirmed || listenerEnded { return fail(error) }
        holdForServer(MemberDirectoryErrorMapper.map(error))  // the cached memberIds may be stale
        return false
      }
    case let .serverWaitElapsed(token):
      guard let pending, pending.token == token else { return false }
      return fail(pending.error)
    case let .listenerEnded(error):
      if let error { return fail(error) }
      listenerEnded = true
      return reading ? false : settle()
    }
  }

  private func receive(_ snapshot: MemberIdsSnapshot) -> Bool {
    if !snapshot.exists, snapshot.isFromCache {
      // Going offline after the server said there is no document: nothing changed.
      if readIds == [], confirmed { return false }
      // Otherwise the cache does not know the document (offline, or a listener's first answer): only the server can
      // say there is no assignment.
      holdForServer(.unavailable)
      return false
    }
    let ids: [String]
    do {
      ids = try FirestoreMemberDirectory.ids(from: snapshot)
    } catch {
      return fail(error)
    }
    if ids == readIds {
      guard !snapshot.isFromCache else { return false }  // metadata only
      confirmed = true
      if reading { return false }  // the read in flight is now final
      if pending == nil, !lastReadFromCache { return false }  // nothing new from the server
    }
    startRead(ids, confirmed: !snapshot.isFromCache)
    return false
  }

  private func startRead(_ ids: [String], confirmed: Bool) {
    generation += 1
    let generation = generation
    let gateway = gateway
    let post = post
    readTask?.cancel()
    clearPending()
    readIds = ids
    reading = true
    self.confirmed = confirmed
    readTask = Task {
      do {
        let read = try await FirestoreMemberDirectory.members(for: ids, gateway: gateway)
        post.yield(.read(generation: generation, .success(read)))
      } catch is CancellationError {
        // superseded or the consumer went away
      } catch {
        post.yield(.read(generation: generation, .failure(error)))
      }
    }
  }

  /// Keeps `error` as the answer unless a server snapshot changes it within `serverWait`.
  private func holdForServer(_ error: MemberDirectoryError) {
    FirestoreMemberDirectory.logger.debug("waiting for the server: \(String(describing: error), privacy: .public)")
    if let pending {
      self.pending = (error, pending.token)
      return
    }
    waitTokens += 1
    let token = waitTokens
    pending = (error, token)
    let serverWait = serverWait
    let post = post
    waitTask = Task {
      guard (try? await Task.sleep(for: serverWait)) != nil else { return }
      post.yield(.serverWaitElapsed(token: token))
    }
  }

  private func clearPending() {
    pending = nil
    waitTask?.cancel()
    waitTask = nil
  }

  /// The listener has ended and no read is out: the last answer stands.
  private func settle() -> Bool {
    if let pending { return fail(pending.error) }
    output.finish()
    return true
  }

  private func fail(_ error: Error) -> Bool {
    let mapped = MemberDirectoryErrorMapper.map(error)
    FirestoreMemberDirectory.logger.error("assigned members failed: \(String(describing: mapped), privacy: .public)")
    output.finish(throwing: mapped)
    return true
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
      // Metadata changes too: the first snapshot often comes from the cache, and the directory waits for the
      // server's answer to decide what the cache cannot (FirestoreMemberDirectory).
      let registration = Firestore.firestore().collection("trainers").document(trainerUid)
        .addSnapshotListener(includeMetadataChanges: true) { snapshot, error in
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
