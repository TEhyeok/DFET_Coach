import Foundation

/// A pending member as TR-02 lists it (DF-113): a `pendingMembers/{id}` document with `status == 'pending'`, or a
/// registration on this device whose server create is not acked yet. Only the display name is used; sex and birth
/// year never reach the list.
public struct PendingMember: Identifiable, Hashable, Sendable {
  /// `pendingMemberId` (`MemberKey.pending`).
  public let id: String
  public let displayName: String

  public init(id: String, displayName: String) {
    self.id = id
    self.displayName = displayName
  }
}

/// Pending members registered on this device whose `pendingMembers/{id}` create the server has not acked yet (the
/// DF-108 drafts, ASM-05-38). Offline the SyncEngine sends nothing, so without these a member registered on site would
/// be missing from TR-02 until the device is back online (V1-07 §8: '대기 회원 표시(로컬)'). LocalStore implements it.
public protocol LocalPendingMemberSource: Sendable {
  /// The current list first, then the list after every change.
  func observeLocalPendingMembers() -> AsyncStream<[PendingMember]>
}

/// One TR-02 row (DF-113): an assigned member (`.uid`) or a pending member (`.pending`).
public struct MemberListEntry: Identifiable, Hashable, Sendable {
  public let key: MemberKey
  public let displayName: String

  public init(key: MemberKey, displayName: String) {
    self.key = key
    self.displayName = displayName
  }

  public var id: MemberKey { key }

  /// Shows the '대기' badge (`tr02.badge.pending`, AC-DF-113.1).
  public var isPending: Bool {
    if case .pending = key { return true }
    return false
  }

  /// Avatar text drawn locally (NFR-11).
  public var initials: String { MemberName.initials(of: displayName) }
}

/// TR-02 list logic (DF-113), pure so it is table-tested.
public enum MemberList {
  /// Assigned and pending members in one list, in display-name order as the trainer reads it (Korean collation);
  /// equal names put assigned members first, then order by key. A pending member listed twice (the server's document
  /// and this device's unacked registration) appears once, with the first name seen: pass the server's list first.
  public static func merge(assigned: [Member], pending: [PendingMember]) -> [MemberListEntry] {
    var seen: Set<MemberKey> = []
    let entries = assigned.map { MemberListEntry(key: .uid($0.id), displayName: $0.displayName) }
      + pending.map { MemberListEntry(key: .pending($0.id), displayName: $0.displayName) }
    return entries.filter { seen.insert($0.key).inserted }.sorted(by: inNameOrder)
  }

  /// AC-DF-113.5: display-name partial match, ignoring case and whitespace. An empty or all-blank query keeps every
  /// entry. Local only: no search query goes to the server (V1-07 §4.2).
  public static func search(_ entries: [MemberListEntry], query: String) -> [MemberListEntry] {
    let needle = withoutWhitespace(query)
    guard !needle.isEmpty else { return entries }
    return entries.filter { withoutWhitespace($0.displayName).range(of: needle, options: .caseInsensitive) != nil }
  }

  static func inNameOrder(_ lhs: MemberListEntry, _ rhs: MemberListEntry) -> Bool {
    let order = lhs.displayName.localizedStandardCompare(rhs.displayName)
    if order != .orderedSame { return order == .orderedAscending }
    if lhs.isPending != rhs.isPending { return !lhs.isPending }
    return lhs.key.id < rhs.key.id
  }

  private static func withoutWhitespace(_ text: String) -> String {
    text.filter { !$0.isWhitespace }
  }
}
