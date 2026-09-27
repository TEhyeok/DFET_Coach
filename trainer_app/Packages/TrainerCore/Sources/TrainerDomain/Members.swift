import Foundation

/// An assigned member as TR-02 shows it (DF-013). Only `displayName` and `trainerId` are used; no other field of
/// `users/{uid}` reaches the app's model or UI. `id` is the Firebase uid (`MemberKey.uid`). (The Firestore cache still
/// holds the whole document; see `FirestoreMemberDirectory`.)
public struct Member: Identifiable, Hashable, Sendable {
  public let id: String
  public let displayName: String
  public let trainerId: String?

  public init(id: String, displayName: String, trainerId: String?) {
    self.id = id
    self.displayName = displayName
    self.trainerId = trainerId
  }

  /// Avatar text drawn locally (AC-DF-013.6, NFR-11: no external image request). See `MemberName.initials(of:)`.
  public var initials: String { MemberName.initials(of: displayName) }
}

/// Display-name helpers shared by every member row (TR-02, TR-03).
public enum MemberName {
  /// Latin names with two or more words use the first letters of the first two words ("Jane Doe" → "JD"); anything
  /// else uses the first character ("가상회원" → "가"). An empty name shows "?".
  public static func initials(of displayName: String) -> String {
    let words = displayName.split(whereSeparator: \.isWhitespace)
    guard let first = words.first?.first else { return "?" }
    if words.count >= 2, first.isASCII, first.isLetter, let second = words[1].first, second.isASCII, second.isLetter {
      return "\(first)\(second)".uppercased()
    }
    return String(first).uppercased()
  }
}

/// Why the assigned members could not be loaded. A failure is never shown as an empty list (§9.6, AC-DF-013.2).
public enum MemberDirectoryError: Error, Equatable, Sendable {
  case permissionDenied
  /// A query needs a composite index (Firestore `failed-precondition`).
  case indexMissing
  case unavailable
  case unknown(code: Int)
}

/// The trainer's assigned members (DF-013) and pending members (DF-113). FirebaseData implements it; feature modules
/// use only this protocol.
public protocol MemberDirectory: Sendable {
  /// The full list now and after every change of `trainers/{uid}.memberIds`. Fails with `MemberDirectoryError`
  /// instead of emitting a partial list.
  func observeAssignedMembers() -> AsyncThrowingStream<[Member], Error>
  /// `pendingMembers where trainerId == uid && status == 'pending'` now and after every change (F-LINK-03.2): a
  /// cancelled, expired or promoted member leaves the list. Fails with `MemberDirectoryError` like the assigned list.
  func observePendingMembers() -> AsyncThrowingStream<[PendingMember], Error>
}

/// Firestore allows at most 10 values in an `in` filter; `users` are read in chunks of that size (AC-DF-013.1).
public enum MemberChunks {
  public static let size = 10

  /// `ids` without duplicates, in order, split into chunks of `size`.
  public static func chunk(_ ids: [String]) -> [[String]] {
    var seen: Set<String> = []
    let unique = ids.filter { seen.insert($0).inserted }
    return stride(from: 0, to: unique.count, by: size).map { Array(unique[$0..<min($0 + size, unique.count)]) }
  }
}
