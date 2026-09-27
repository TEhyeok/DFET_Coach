import Foundation
import TrainerContracts

/// DF-110 MVP: three separate answers, with no signature, bulk choice, withdrawal or reconsent behavior.
public enum ConsentFlowRules {
  public static let coreTypes: [ConsentType] = [.required, .healthData, .bodyImaging]

  public static func canSubmit(selections: [ConsentSelection]) -> Bool {
    selections.count == coreTypes.count && Set(selections.map(\.type)) == Set(coreTypes)
  }

  /// Latest published date per type; the document ID breaks ties deterministically. Retired/draft/incomplete
  /// documents never replace a complete published card (AC-DF-110.3, TC-110-02).
  public static func latestPublished(_ documents: [ConsentDocumentVersion]) -> [ConsentType: ConsentDocumentVersion] {
    var latest: [ConsentType: ConsentDocumentVersion] = [:]
    for document in documents where document.isCompletePublished {
      if let existing = latest[document.consentType],
         (existing.publishedAt!, existing.id) >= (document.publishedAt!, document.id) { continue }
      latest[document.consentType] = document
    }
    return latest
  }
}
