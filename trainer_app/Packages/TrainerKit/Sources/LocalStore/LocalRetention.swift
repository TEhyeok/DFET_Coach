import Foundation
import SwiftData
import TrainerContracts

/// What one `LocalRetention.purge(now:)` run removed. Ids and UUID-named relative paths only; the caller may tell
/// the trainer that unconfirmed consent drafts were destroyed (V1-04 §9.4) without logging any of these values (NFR-10).
public struct LocalRetentionReport: Equatable, Sendable {
  /// Verified uploads whose local original file was removed. Their `LocalBinary` metadata is kept (NFR-17).
  public var purgedBinaryIds: [UUID] = []
  /// Unconfirmed consent captures destroyed after `expiresAt` (AS-32).
  public var destroyedCaptureIds: [String] = []
  public var destroyedSoapNoteIds: [String] = []
  public var destroyedMeasurementRecordIds: [String] = []
  public var destroyedOutboxItemIds: [UUID] = []
  /// Binaries destroyed together with a capture or draft: file and metadata both removed.
  public var destroyedBinaryIds: [UUID] = []
  /// Files under `Binaries/` with no `LocalBinary` row, removed by the orphan sweep (partition-relative paths,
  /// which hold only the binary UUID).
  public var sweptOrphanPaths: [String] = []
  /// Files whose removal failed. The run went on; the orphan sweep of a later run retries them.
  public var failedRelativePaths: [String] = []
  /// Re-applying complete protection to the store files (`.store`, `-wal`, `-shm`) failed.
  public var storeProtectionFailed = false

  public init() {}

  public var isEmpty: Bool { self == LocalRetentionReport() }
}

/// Local retention and destruction (NFR-17, AS-32, V1-04 §9.4, V1-05 §12.3). Runs on every foreground entry.
///
/// 1. An unconfirmed `LocalConsentCapture` (`serverConfirmedAt == nil`) whose `expiresAt` has passed is destroyed
///    with its signature, the member's `blocked` Outbox items, the member's `awaitingConsent` drafts and their
///    binaries and Outbox items.
/// 2. A verified upload (`LocalBinary.verifiedAt != nil`) loses its local original file once `purgeAfter`
///    (= `verifiedAt + window`) has passed; the metadata stays so the SDK can download it again.
/// 3. A file under `Binaries/` that no `LocalBinary` row points at (older than `orphanGrace`) is removed.
/// 4. Complete protection and backup exclusion are re-applied to the store files (`-wal`/`-shm` may be recreated).
///
/// One failed file removal never aborts the run; it is listed in `failedRelativePaths` and retried by the sweep.
///
/// The boundary is strict: an item exactly `window` old is kept, one minute older is removed.
public struct LocalRetention {
  /// 7 days. A hypothesis value, kept as one constant (ASM-P0-16).
  public static let window: TimeInterval = 7 * 24 * 60 * 60
  /// A file under `Binaries/` with no `LocalBinary` row is removed once it is older than this.
  public static let orphanGrace: TimeInterval = 60 * 60

  private let context: ModelContext
  private let binaryStore: LocalBinaryStore
  private let trainerUid: String

  public init(context: ModelContext, binaryStore: LocalBinaryStore, trainerUid: String) {
    self.context = context
    self.binaryStore = binaryStore
    self.trainerUid = trainerUid
  }

  @discardableResult
  public func purge(now: Date) throws -> LocalRetentionReport {
    var report = LocalRetentionReport()
    var filesToRemove: [String] = []

    try destroyExpiredConsentCaptures(now: now, report: &report, filesToRemove: &filesToRemove)
    if context.hasChanges {
      try context.save()
    }
    // Rows are gone first, so a failed file removal leaves an orphan file, never a row pointing at nothing. A failed
    // removal does not stop the run; the orphan sweep below (or the next run's) removes the file.
    for relativePath in filesToRemove {
      removeFile(relativePath, report: &report)
    }

    let binaries = try context.fetchOwned(LocalBinary.self, by: trainerUid)
    for binary in binaries {
      guard let verifiedAt = binary.verifiedAt else { continue }
      let deadline = binary.purgeAfter ?? verifiedAt.addingTimeInterval(Self.window)
      guard deadline < now else { continue }
      if removeFile(binary.relativePath, report: &report) {
        report.purgedBinaryIds.append(binary.id)
      }
    }

    sweepOrphanFiles(knownPaths: Set(binaries.map(\.relativePath)), now: now, report: &report)

    // SQLite sidecars recreated during the session may not carry `.complete`; re-apply it on every run.
    do {
      try LocalStoreContainer.protectStoreFiles(at: binaryStore.location.storeURL, protection: binaryStore.protection)
    } catch {
      report.storeProtectionFailed = true
    }
    return report
  }

  /// Removes one file, recording a failure instead of throwing. Returns true when a file was removed.
  @discardableResult
  private func removeFile(_ relativePath: String, report: inout LocalRetentionReport) -> Bool {
    do {
      return try binaryStore.delete(relativePath: relativePath)
    } catch {
      if !report.failedRelativePaths.contains(relativePath) {
        report.failedRelativePaths.append(relativePath)
      }
      return false
    }
  }

  // MARK: - Orphan files

  /// Removes files under `Binaries/` that no `LocalBinary` row points at, e.g. a signature whose file removal failed
  /// after its row was destroyed. Files younger than `orphanGrace` are left alone so a file written just before its
  /// row is saved (another context) is never taken.
  private func sweepOrphanFiles(knownPaths: Set<String>, now: Date, report: inout LocalRetentionReport) {
    let cutoff = now.addingTimeInterval(-Self.orphanGrace)
    let candidates = binaryStore.storedRelativePaths(modifiedBefore: cutoff)
    for relativePath in candidates where !knownPaths.contains(relativePath) {
      if removeFile(relativePath, report: &report) {
        report.sweptOrphanPaths.append(relativePath)
      }
    }
  }

  // MARK: - Unconfirmed consent (AS-32)

  private func destroyExpiredConsentCaptures(
    now: Date, report: inout LocalRetentionReport, filesToRemove: inout [String]
  ) throws {
    let captures = try context.fetchOwned(LocalConsentCapture.self, by: trainerUid)
    let expired = captures.filter { $0.serverConfirmedAt == nil && $0.expiresAt < now }
    guard !expired.isEmpty else { return }

    let outbox = try context.fetchOwned(OutboxItem.self, by: trainerUid)
    let soapDrafts = try context.fetchOwned(LocalSoapDraft.self, by: trainerUid)
    let measurementDrafts = try context.fetchOwned(LocalMeasurementDraft.self, by: trainerUid)
    var binariesById: [UUID: LocalBinary] = [:]
    for binary in try context.fetchOwned(LocalBinary.self, by: trainerUid) {
      binariesById[binary.id] = binary
    }

    var destroyedRefs: Set<String> = []
    var destroyedBinaryIds: Set<UUID> = []

    for memberKey in Set(expired.map(\.memberKey)).sorted() {
      // Always cascades, even when the member has a newer, still-pending capture (a retake): no draft outlives the
      // capture it waited on (AC-DF-014.4, V1-05 §12.3, AS-32). Keeping drafts for a retake is an open AS-DEV
      // question for the owner; until it is decided the conservative reading applies.
      for capture in expired where capture.memberKey == memberKey {
        destroyedRefs.insert(capture.entityRef)
        destroyedBinaryIds.insert(capture.signatureBinaryId)
        report.destroyedCaptureIds.append(capture.captureId)
        context.delete(capture)
      }

      let blockedRefs = Set(outbox.filter { $0.memberKey == memberKey && Self.isAwaitingConsent($0) }.map(\.entityRef))
      destroyedRefs.formUnion(blockedRefs)
      for draft in soapDrafts where draft.memberKey == memberKey
        && (draft.syncState == SyncState.awaitingConsent.rawValue || blockedRefs.contains(draft.entityRef)) {
        destroyedRefs.insert(draft.entityRef)
        if let inkId = draft.inkBinaryId { destroyedBinaryIds.insert(inkId) }
        report.destroyedSoapNoteIds.append(draft.noteId)
        context.delete(draft)
      }
      for draft in measurementDrafts where draft.memberKey == memberKey
        && (draft.syncState == SyncState.awaitingConsent.rawValue || blockedRefs.contains(draft.entityRef)) {
        destroyedRefs.insert(draft.entityRef)
        if let photoId = draft.reportPhotoBinaryId { destroyedBinaryIds.insert(photoId) }
        report.destroyedMeasurementRecordIds.append(draft.recordId)
        context.delete(draft)
      }
    }

    for item in outbox where destroyedRefs.contains(item.entityRef) {
      if let binaryId = item.binaryId { destroyedBinaryIds.insert(binaryId) }
      report.destroyedOutboxItemIds.append(item.id)
      context.delete(item)
    }
    for binaryId in destroyedBinaryIds.sorted(by: { $0.uuidString < $1.uuidString }) {
      guard let binary = binariesById[binaryId] else { continue }
      filesToRemove.append(binary.relativePath)
      report.destroyedBinaryIds.append(binary.id)
      context.delete(binary)
    }
  }

  private static func isAwaitingConsent(_ item: OutboxItem) -> Bool {
    item.state == LocalOutboxState.blocked.rawValue
      && item.blockedReason == LocalOutboxBlockedReason.awaitingConsent.rawValue
  }
}
