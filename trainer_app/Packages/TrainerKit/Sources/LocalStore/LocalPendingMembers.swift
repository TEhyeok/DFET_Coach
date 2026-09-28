import Foundation
import os
import SwiftData
import TrainerDomain

/// TR-02's pending-member changes that exist only on this device (DF-113): the `LocalPendingMemberDraft` rows of one
/// trainer, saved by registration and deleted once the server acked the create (DF-108, ASM-05-38), and the members
/// whose cancel (`PendingMemberCanceller`, a `pendingMembers/{id}` `status: 'cancelled'` update in the Outbox) is not
/// acked yet. Only the ID and the display name leave the store. Once the cancel is sent, Firestore's own list no
/// longer has the member.
///
/// Every save of a `ModelContext` (the Outbox actor's included) triggers a new read, and the list is emitted when it
/// changed. The observer is in place before the first read, so no save is missed. A read that fails (the store is
/// locked) keeps the last list; before any list it is empty, so TR-02 never waits for this source.
public final class LocalPendingMembers: LocalPendingMemberSource, Sendable {
  private static let logger = Logger(subsystem: "kr.co.dfet.trainer", category: "members")
  private let container: ModelContainer
  private let trainerUid: String

  public init(container: ModelContainer, trainerUid: String) {
    self.container = container
    self.trainerUid = trainerUid
  }

  public func observeLocalPendingMembers() -> AsyncStream<DevicePendingMembers> {
    let container = container
    let trainerUid = trainerUid
    return AsyncStream { continuation in
      let (saves, saved) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
      let observer = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: nil) { _ in
        saved.yield()
      }
      let task = Task {
        var last: DevicePendingMembers?
        func read() {
          let members: DevicePendingMembers
          do {
            members = try Self.read(container: container, trainerUid: trainerUid)
          } catch {
            Self.logger.error("local pending members unreadable: \(String(describing: type(of: error)), privacy: .public)")
            members = last ?? DevicePendingMembers()
          }
          guard members != last else { return }
          last = members
          continuation.yield(members)
        }
        read()
        for await _ in saves {
          read()
        }
      }
      continuation.onTermination = { _ in
        NotificationCenter.default.removeObserver(observer)
        saved.finish()
        task.cancel()
      }
    }
  }

  static func read(container: ModelContainer, trainerUid: String) throws -> DevicePendingMembers {
    let context = ModelContext(container)
    let drafts = try context.fetchOwned(LocalPendingMemberDraft.self, by: trainerUid)
    let update = LocalOutboxKind.updateDocument.rawValue
    let updates = try context.fetch(FetchDescriptor<OutboxItem>(
      predicate: #Predicate { $0.trainerUid == trainerUid && $0.kind == update }))
    return DevicePendingMembers(
      registered: drafts
        .sorted { $0.pendingMemberId < $1.pendingMemberId }
        .map { PendingMember(id: $0.pendingMemberId, displayName: $0.displayName) },
      cancelled: Set(updates.compactMap(unsentCancel)))
  }

  /// The pending member an Outbox row cancels while the cancel is not acked (an acked row keeps no payload).
  static func unsentCancel(_ row: OutboxItem) -> String? {
    let prefix = "pendingMember:"
    guard row.entityRef.hasPrefix(prefix), row.state != LocalOutboxState.acked.rawValue,
      let data = row.payloadJSON, let payload = try? JSONValue(storageData: data),
      payload["status"]?.stringValue == "cancelled"
    else { return nil }
    return String(row.entityRef.dropFirst(prefix.count))
  }
}
