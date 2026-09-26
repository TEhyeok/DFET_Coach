import Foundation
import SwiftData

/// Every LocalStore entity is scoped by `trainerUid` (AC-DF-014.1, V1-05 §12.1). The store already lives in a
/// per-trainer partition; this predicate is the second line of defence and goes into every fetch.
///
/// Each model spells its own `#Predicate` because SwiftData cannot evaluate a key path declared on a protocol.
protocol TrainerScopedModel: PersistentModel {
  var trainerUid: String { get }
  static func ownedBy(_ trainerUid: String) -> Predicate<Self>
}

extension ModelContext {
  /// Rows of `type` owned by `trainerUid`.
  func fetchOwned<T: TrainerScopedModel>(_ type: T.Type, by trainerUid: String) throws -> [T] {
    try fetch(FetchDescriptor<T>(predicate: T.ownedBy(trainerUid)))
  }
}
