import Foundation
import SwiftData

extension LocalStoreSchemaV1 {
  /// Metadata of one local binary file (V1-05 §12.2). The file itself lives under the partition at `relativePath`
  /// and is written by `LocalBinaryStore`. After an upload is verified the file is removed after
  /// `LocalRetention.window` and this metadata is kept (NFR-17).
  @Model
  final class LocalBinary {
    @Attribute(.unique) var id: UUID
    var trainerUid: String
    /// `LocalBinaryKind` raw value.
    var kind: String
    /// Relative to the partition directory, e.g. `Binaries/ink/<id>.png`.
    var relativePath: String
    var contentType: String
    var byteSize: Int64
    /// Lowercase hex.
    var sha256: String
    var md5Base64: String?
    var remotePath: String?
    var uploadedAt: Date?
    /// Written only after Storage `size`/`md5Hash`/`customMetadata.sha256` matched (ASM-05-22).
    var verifiedAt: Date?
    /// `verifiedAt + LocalRetention.window`.
    var purgeAfter: Date?

    init(
      id: UUID,
      trainerUid: String,
      kind: LocalBinaryKind,
      relativePath: String,
      contentType: String,
      byteSize: Int64,
      sha256: String,
      md5Base64: String? = nil,
      remotePath: String? = nil,
      uploadedAt: Date? = nil,
      verifiedAt: Date? = nil
    ) {
      self.id = id
      self.trainerUid = trainerUid
      self.kind = kind.rawValue
      self.relativePath = relativePath
      self.contentType = contentType
      self.byteSize = byteSize
      self.sha256 = sha256
      self.md5Base64 = md5Base64
      self.remotePath = remotePath
      self.uploadedAt = uploadedAt
      self.verifiedAt = verifiedAt
      self.purgeAfter = verifiedAt.map { $0.addingTimeInterval(LocalRetention.window) }
    }

    /// Metadata for a file `LocalBinaryStore.write(data:ext:kind:id:)` just wrote.
    convenience init(file: LocalBinaryFile, trainerUid: String) {
      self.init(
        id: file.id,
        trainerUid: trainerUid,
        kind: file.kind,
        relativePath: file.relativePath,
        contentType: file.contentType,
        byteSize: file.byteSize,
        sha256: file.sha256,
        md5Base64: file.md5Base64
      )
    }

    /// Records the verified upload and schedules the local original for removal.
    func markVerified(at date: Date) {
      verifiedAt = date
      purgeAfter = date.addingTimeInterval(LocalRetention.window)
    }
  }
}

extension LocalBinary: TrainerScopedModel {
  static func ownedBy(_ trainerUid: String) -> Predicate<LocalBinary> {
    #Predicate<LocalBinary> { $0.trainerUid == trainerUid }
  }
}
