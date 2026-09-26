import Foundation
import SwiftData
import TrainerDomain
import XCTest
@testable import LocalStore

// Synthetic values only (no real member or trainer data).
enum Synthetic {
  static let trainerA = "trainer-uid-a"
  static let trainerB = "trainer-uid-b"
  static let memberA = MemberKey.uid("member-uid-a")
  static let memberB = MemberKey.pending("pendingMemberB01")
  static let now = Date(timeIntervalSince1970: 1_790_000_000)  // 2026-09-21T12:53:20Z
  static let json = Data(#"{"k":"v"}"#.utf8)
}

/// A unique directory under the test process's temporary directory, removed by `remove()`.
struct TemporaryDirectory {
  let url: URL

  init() throws {
    url = FileManager.default.temporaryDirectory
      .appendingPathComponent("LocalStoreTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  }

  func remove() {
    try? FileManager.default.removeItem(at: url)
  }
}

/// One row of every V1 model for `trainerUid`, with ids made unique by `tag`.
@MainActor
enum ModelFactory {
  static func insertOneOfEach(into context: ModelContext, trainerUid: String, tag: String) {
    context.insert(LocalSoapDraft(
      noteId: "note\(tag)", trainerUid: trainerUid, memberKey: Synthetic.memberA, sessionDate: Synthetic.now,
      createdLocallyAt: Synthetic.now
    ))
    context.insert(LocalMeasurementDraft(
      recordId: "record\(tag)", trainerUid: trainerUid, memberKey: Synthetic.memberA, kind: .bodyComposition,
      payloadJSON: Synthetic.json, createdLocallyAt: Synthetic.now
    ))
    context.insert(LocalConsentCapture(
      captureId: UUID().uuidString, trainerUid: trainerUid, memberKey: Synthetic.memberA,
      selectionsJSON: Synthetic.json, signatureBinaryId: UUID(), capturedAt: Synthetic.now
    ))
    context.insert(OutboxItem(
      trainerUid: trainerUid, memberKey: Synthetic.memberA, entityRef: "soap:note\(tag)", sequence: 1,
      stage: .document, kind: .createDocument, targetPath: "soap_notes/note\(tag)", createdAt: Synthetic.now
    ))
    context.insert(LocalBinary(
      id: UUID(), trainerUid: trainerUid, kind: .ink, relativePath: "Binaries/ink/\(tag).png",
      contentType: "image/png", byteSize: 3, sha256: "00"
    ))
    context.insert(TodayListEntry(
      trainerUid: trainerUid, memberKey: Synthetic.memberA, dayKey: "2026-09-21", order: 0, addedAt: Synthetic.now
    ))
    context.insert(StationProfile(
      id: "station\(tag)", trainerUid: trainerUid, name: "Station \(tag)", cameraHeightCm: 100,
      cameraDistanceM: 3, protocolVersion: "posture-v1", createdLocallyAt: Synthetic.now
    ))
    context.insert(QuickPhrase(trainerUid: trainerUid, text: "phrase \(tag)", category: .subjective, isDefault: true, order: 0))
    context.insert(FilterPreference(
      key: "timeline.kinds.\(tag)", trainerUid: trainerUid, valueJSON: Data(#"["soap"]"#.utf8),
      updatedLocallyAt: Synthetic.now
    ))
  }
}

/// Wraps `LocalFileProtection.system` and records every class it was asked to set, keyed by standardized path.
/// The iOS Simulator does not report protection classes, so TC-DF014-03 checks this record there (see
/// `LocalFileProtection`) and the reported class wherever the OS provides one.
final class ProtectionRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var requested: [String: FileProtectionType] = [:]

  var protection: LocalFileProtection {
    LocalFileProtection { [self] url, type in
      try LocalFileProtection.system.setProtection(url, type)
      lock.lock()
      requested[Self.key(url)] = type
      lock.unlock()
    }
  }

  func clear() {
    lock.lock()
    requested.removeAll()
    lock.unlock()
  }

  func requestedProtection(of url: URL) -> FileProtectionType? {
    lock.lock()
    defer { lock.unlock() }
    return requested[Self.key(url)]
  }

  private static func key(_ url: URL) -> String {
    url.standardizedFileURL.resolvingSymlinksInPath().path
  }
}
