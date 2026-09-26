import Foundation
import SwiftData
import TrainerContracts

/// What one `LocalRetention.purge(now:)` run removed. Ids only; the caller may tell the trainer that unconfirmed
/// consent drafts were destroyed (V1-04 §9.4) without logging any of these values (NFR-10).
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
///
/// The boundary is strict: an item exactly `window` old is kept, one minute older is removed.
public struct LocalRetention {
  /// 7 days. A hypothesis value, kept as one constant (ASM-P0-16).
  public static let window: TimeInterval = 7 * 24 * 60 * 60

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
    // Rows are gone first, so a failed file removal leaves an orphan file, never a row pointing at nothing.
    for relativePath in filesToRemove {
      try binaryStore.delete(relativePath: relativePath)
    }

    for binary in try context.fetchOwned(LocalBinary.self, by: trainerUid) {
      guard let verifiedAt = binary.verifiedAt else { continue }
      let deadline = binary.purgeAfter ?? verifiedAt.addingTimeInterval(Self.window)
      guard deadline < now else { continue }
      if try binaryStore.delete(relativePath: binary.relativePath) {
        report.purgedBinaryIds.append(binary.id)
      }
    }
    return report
  }

  // MARK: - Unconfirmed consent (AS-32)

  private func destroyExpiredConsentCaptures(
    now: Date, report: inout LocalRetentionReport, filesToRemove: inout [String]
  ) throws {
    let captures = try context.fetchOwned(LocalConsentCapture.self, by: trainerUid)
    let expired = captures.filter { $0.serverConfirmedAt == nil && $0.expiresAt < now }
    guard !expired.isEmpty else { return }
    let expiredIds = Set(expired.map(\.captureId))

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
      // Drafts of a member who still has a live, unexpired pending capture wait for that capture instead.
      let memberStillAwaitsAnotherCapture = captures.contains {
        $0.memberKey == memberKey && !expiredIds.contains($0.captureId) && $0.serverConfirmedAt == nil
          && $0.captureState == LocalConsentCaptureState.pending.rawValue
      }
      for capture in expired where capture.memberKey == memberKey {
        destroyedRefs.insert(capture.entityRef)
        destroyedBinaryIds.insert(capture.signatureBinaryId)
        report.destroyedCaptureIds.append(capture.captureId)
        context.delete(capture)
      }
      guard !memberStillAwaitsAnotherCapture else { continue }

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
