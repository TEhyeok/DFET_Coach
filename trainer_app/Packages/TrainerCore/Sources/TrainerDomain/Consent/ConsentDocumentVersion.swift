import Foundation
import TrainerContracts

/// Published card content from `consentDocumentVersions` (V1-05 §4.13). `id` is the callable's documentVersion;
/// `version` is the human-readable version. The MVP displays test documents, not substituted legal copy.
public struct ConsentDocumentVersion: Equatable, Sendable, Identifiable {
  public enum Status: String, Codable, Sendable {
    case draft
    case published
    case retired
  }

  public let id: String
  public let consentType: ConsentType
  public let version: String
  public let title: String
  public let purpose: String
  public let items: [String]
  public let retention: String
  public let recipient: String?
  public let refusalNotice: String
  public let privacyPolicyVersion: String
  public let status: Status
  public let publishedAt: Date?

  public init(id: String, consentType: ConsentType, version: String, title: String, purpose: String,
              items: [String], retention: String, recipient: String? = nil, refusalNotice: String,
              privacyPolicyVersion: String, status: Status = .published, publishedAt: Date?) {
    self.id = id
    self.consentType = consentType
    self.version = version
    self.title = title
    self.purpose = purpose
    self.items = items
    self.retention = retention
    self.recipient = recipient
    self.refusalNotice = refusalNotice
    self.privacyPolicyVersion = privacyPolicyVersion
    self.status = status
    self.publishedAt = publishedAt
  }

  public var isCompletePublished: Bool {
    let required = [id, version, title, purpose, retention, refusalNotice, privacyPolicyVersion]
    return status == .published && publishedAt != nil
      && required.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
      && !items.isEmpty && items.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
      && (consentType != .sharing || !(recipient ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
  }
}
