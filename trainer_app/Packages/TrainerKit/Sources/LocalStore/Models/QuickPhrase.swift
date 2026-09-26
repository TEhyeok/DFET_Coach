import Foundation
import SwiftData

extension LocalStoreSchemaV1 {
  /// SOAP quick phrase (V1-05 §12.2). Defaults arrive in P1a (DF-124), custom phrases in P2 (DF-327).
  @Model
  final class QuickPhrase {
    @Attribute(.unique) var id: UUID
    var trainerUid: String
    var text: String
    /// `LocalQuickPhraseCategory` raw value (`S`|`O`|`A`|`P`).
    var category: String
    var isDefault: Bool
    var order: Int

    init(
      id: UUID = UUID(),
      trainerUid: String,
      text: String,
      category: LocalQuickPhraseCategory,
      isDefault: Bool,
      order: Int
    ) {
      self.id = id
      self.trainerUid = trainerUid
      self.text = text
      self.category = category.rawValue
      self.isDefault = isDefault
      self.order = order
    }
  }
}

extension QuickPhrase: TrainerScopedModel {
  static func ownedBy(_ trainerUid: String) -> Predicate<QuickPhrase> {
    #Predicate<QuickPhrase> { $0.trainerUid == trainerUid }
  }
}
