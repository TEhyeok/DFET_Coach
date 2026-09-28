import Foundation
import os
import SwiftData
import SyncEngine
import TrainerContracts
import TrainerDomain

/// `ConsentCaptureRecorder` on LocalStore (TR-14 consent step, DF-110 MVP): saves the `LocalConsentCapture` and its
/// stage 1 `callConsent` Outbox item in one save, then hands the item to the SyncEngine. Nothing waits for the server.
///
/// The item's `requestId` is the capture ID (the request's `clientCaptureId`, V1-06 §6.2.5) and, for a pending member
/// whose create is still on the device, it depends on that create item (ASM-P1a-01, AC-DF-108.5). The SyncEngine sends
/// the member's create first, then this capture, then the member's records.
public final class LocalConsentRecorder: ConsentCaptureRecorder {
  private let outbox: LocalOutboxStore
  private let enqueue: @Sendable (TrainerDomain.OutboxItem) async -> Void
  private let now: @Sendable () -> Date
  private let makeID: @Sendable () -> UUID

  public init(
    outbox: LocalOutboxStore, enqueue: @escaping @Sendable (TrainerDomain.OutboxItem) async -> Void,
    now: @escaping @Sendable () -> Date = { Date() }, makeID: @escaping @Sendable () -> UUID = { UUID() }
  ) {
    self.outbox = outbox
    self.enqueue = enqueue
    self.now = now
    self.makeID = makeID
  }

  public func capture(member: MemberKey, selections: [ConsentSelection]) async throws -> String {
    guard !selections.isEmpty, Set(selections.map(\.consentType)).count == selections.count else {
      throw ConsentCaptureError.invalidSelections
    }
    let date = now()
    let requestId = makeID()
    let captureId = requestId.uuidString.lowercased()
    let dependsOn = try await outbox.pendingMemberCreateItem(for: member).map { [$0] } ?? []
    let item = TrainerDomain.OutboxItem(
      requestId: requestId, memberKey: member, entityRef: .consent(captureId: captureId),
      sequence: try await outbox.nextSequence(for: member), stage: .consent, kind: .callConsent,
      target: .callable(name: RecordConsentRequest.callable),
      payload: RecordConsentRequest.payload(captureId: captureId, member: member, selections: selections,
                                            capturedAt: date),
      dependsOn: dependsOn, createdAt: date)
    try await outbox.insertConsentCapture(
      ConsentCapture(captureId: captureId, member: member, selections: selections, capturedAt: date, state: .pending),
      callItem: item)
    await enqueue(item)
    return captureId
  }
}

/// `ConsentCaptureSource` on LocalStore (DF-111 MVP): one member's `LocalConsentCapture` rows as values, read again
/// whenever this process saves a change to the partition's captures (`ConsentCaptureChanges`). Every read uses a new
/// context, so a row another context changed is never served from this one's memory.
public actor LocalConsentCaptureStore: ConsentCaptureSource {
  private nonisolated let container: ModelContainer
  private let trainerUid: String
  private static let logger = Logger(subsystem: "kr.co.dfet.trainer", category: "consent")

  public init(container: ModelContainer, trainerUid: String) {
    self.container = container
    self.trainerUid = trainerUid
  }

  public nonisolated func observeCaptures(member: MemberKey) -> AsyncStream<[ConsentCapture]> {
    let changes = ConsentCaptureChanges.shared.stream(for: container)
    return AsyncStream { continuation in
      let task = Task {
        var last: [ConsentCapture]?
        func emitCurrent() async {
          let current = await self.captures(of: member)
          guard current != last else { return }
          last = current
          continuation.yield(current)
        }
        await emitCurrent()
        for await _ in changes { await emitCurrent() }
        continuation.finish()
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  /// The member's captures, oldest first. A store that cannot be read counts as no capture (the server state alone
  /// then decides, which never grants more than the server did).
  func captures(of member: MemberKey) -> [ConsentCapture] {
    let uid = trainerUid
    let key = member.storageValue
    let descriptor = FetchDescriptor<LocalConsentCapture>(
      predicate: #Predicate { $0.trainerUid == uid && $0.memberKey == key },
      sortBy: [SortDescriptor(\.capturedAt)])
    do {
      return try ModelContext(container).fetch(descriptor).map { row in
        ConsentCapture(
          captureId: row.captureId, member: member, selections: Self.selections(row.selectionsJSON),
          capturedAt: row.capturedAt,
          state: LocalConsentCaptureState(rawValue: row.captureState).map(ConsentCaptureState.init) ?? .failed,
          confirmedAt: row.serverConfirmedAt, lastErrorCode: row.lastErrorCode)
      }
    } catch {
      Self.logger.error("consent captures unreadable")
      return []
    }
  }

  /// An unreadable list selects nothing, so the capture changes no type.
  static func selections(_ data: Data) -> [ConsentSelection] {
    (try? JSONDecoder().decode([ConsentSelection].self, from: data)) ?? []
  }
}

private extension ConsentCaptureState {
  init(_ local: LocalConsentCaptureState) {
    switch local {
    case .pending: self = .pending
    case .confirmed: self = .confirmed
    case .failed: self = .failed
    }
  }
}

/// Tells this process's capture observers that a partition's consent captures changed. SwiftData offers no change
/// stream for a model actor's saves on iOS 17, so every LocalStore writer that changes captures posts here after its
/// save (`LocalOutboxStore`).
final class ConsentCaptureChanges: @unchecked Sendable {
  static let shared = ConsentCaptureChanges()

  private let lock = NSLock()
  private var subscribers: [UUID: (container: ObjectIdentifier, continuation: AsyncStream<Void>.Continuation)] = [:]

  func stream(for container: ModelContainer) -> AsyncStream<Void> {
    let key = ObjectIdentifier(container)
    let (stream, continuation) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
    let id = UUID()
    lock.withLock { subscribers[id] = (key, continuation) }
    continuation.onTermination = { [weak self] _ in
      self?.lock.withLock { _ = self?.subscribers.removeValue(forKey: id) }
    }
    return stream
  }

  func post(for container: ModelContainer) {
    let key = ObjectIdentifier(container)
    let targets = lock.withLock { subscribers.values.filter { $0.container == key }.map(\.continuation) }
    targets.forEach { $0.yield() }
  }
}
