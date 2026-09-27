import Foundation
import os
import SwiftData
import TrainerDomain

/// TR-02's pending members that exist only on this device (DF-113): the `LocalPendingMemberDraft` rows of one trainer,
/// saved by registration and deleted once the server acked the create (DF-108, ASM-05-38). Only the ID and the display
/// name leave the store.
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

  public func observeLocalPendingMembers() -> AsyncStream<[PendingMember]> {
    let container = container
    let trainerUid = trainerUid
    return AsyncStream { continuation in
      let (saves, saved) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
      let observer = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: nil) { _ in
        saved.yield()
      }
      let task = Task {
        var last: [PendingMember]?
        func read() {
          let members: [PendingMember]
          do {
            members = try Self.read(container: container, trainerUid: trainerUid)
          } catch {
            Self.logger.error("local pending members unreadable: \(String(describing: type(of: error)), privacy: .public)")
            members = last ?? []
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

  static func read(container: ModelContainer, trainerUid: String) throws -> [PendingMember] {
    let drafts = try ModelContext(container).fetchOwned(LocalPendingMemberDraft.self, by: trainerUid)
    return drafts
      .sorted { $0.pendingMemberId < $1.pendingMemberId }
      .map { PendingMember(id: $0.pendingMemberId, displayName: $0.displayName) }
  }
}
