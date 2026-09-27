#if DEBUG
import Foundation
import TrainerContracts
import TrainerDomain

/// DEBUG preview consent (DF-110): synthetic published versions (`{type}--1.0`, the seed's shape), captures kept in
/// memory and never sent, and no server state. Through the real `EffectiveConsentResolver` a capture of ①②③ reads
/// '동의 확인 대기' and a refusal of ② or ③ reads '동의 필요'. Nothing is sent anywhere.
final class PreviewConsentStore: ConsentDocumentCatalog, ConsentCaptureRecorder, ConsentCaptureSource,
  ConsentStateSource, @unchecked Sendable
{
  private let lock = NSLock()
  private var captures: [MemberKey: [ConsentCapture]] = [:]
  private var observers: [UUID: (member: MemberKey, continuation: AsyncStream<[ConsentCapture]>.Continuation)] = [:]
  private static let publishedAt = Date(timeIntervalSince1970: 1_780_000_000)

  func publishedDocuments() async throws -> [ConsentDocumentVersion] {
    ConsentType.allCases.map {
      ConsentDocumentVersion(id: "\($0.rawValue)--1.0", consentType: $0, version: "1.0", publishedAt: Self.publishedAt)
    }
  }

  func capture(member: MemberKey, selections: [ConsentSelection]) async throws -> String {
    guard !selections.isEmpty else { throw ConsentCaptureError.invalidSelections }
    let capture = ConsentCapture(captureId: UUID().uuidString.lowercased(), member: member, selections: selections,
                                 capturedAt: Date(), state: .pending)
    let (list, targets) = lock.withLock { () -> ([ConsentCapture], [AsyncStream<[ConsentCapture]>.Continuation]) in
      captures[member, default: []].append(capture)
      return (captures[member] ?? [], observers.values.filter { $0.member == member }.map(\.continuation))
    }
    targets.forEach { $0.yield(list) }
    return capture.captureId
  }

  func observeCaptures(member: MemberKey) -> AsyncStream<[ConsentCapture]> {
    AsyncStream { continuation in
      let id = UUID()
      lock.withLock {
        observers[id] = (member, continuation)
        continuation.yield(captures[member] ?? [])
      }
      continuation.onTermination = { [weak self] _ in
        self?.lock.withLock { _ = self?.observers.removeValue(forKey: id) }
      }
    }
  }

  /// No server in preview: no `memberConsentStates` document.
  func observe(member: MemberKey) -> AsyncStream<ConsentState?> {
    AsyncStream { $0.yield(nil) }
  }
}
#endif
