import TrainerDomain

/// `memberKey: String` storage form (V1-05 §12.1): `"uid:<memberUid>"` or `"pending:<pendingMemberId>"`, 1:1 with
/// TrainerDomain `MemberKey`. There is no local UUID member key (AC-LINK-03.3).
extension MemberKey {
  static let uidPrefix = "uid:"
  static let pendingPrefix = "pending:"

  var storageValue: String {
    switch self {
    case let .uid(id): return MemberKey.uidPrefix + id
    case let .pending(id): return MemberKey.pendingPrefix + id
    }
  }

  /// nil for a string that is not one of the two forms or has an empty id.
  init?(storageValue: String) {
    if storageValue.hasPrefix(MemberKey.uidPrefix) {
      let id = String(storageValue.dropFirst(MemberKey.uidPrefix.count))
      guard !id.isEmpty else { return nil }
      self = .uid(id)
    } else if storageValue.hasPrefix(MemberKey.pendingPrefix) {
      let id = String(storageValue.dropFirst(MemberKey.pendingPrefix.count))
      guard !id.isEmpty else { return nil }
      self = .pending(id)
    } else {
      return nil
    }
  }
}
