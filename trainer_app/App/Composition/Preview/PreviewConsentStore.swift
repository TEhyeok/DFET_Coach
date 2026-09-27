#if DEBUG
import Foundation
import TrainerContracts
import TrainerDomain

/// DEBUG preview consent (DF-110, DF-113): synthetic published versions (`{type}--1.0`, the seed's shape), the
/// scenario's server states and captures (`PreviewConsentScript`), and TR-14 captures kept in memory and never sent.
/// It is the server source and the capture source of the real `EffectiveConsentResolver`, so TR-02's chips and TR-14's
/// result chip read exactly what they read live: a new capture of ①②③ reads '동의 확인 대기', a refusal of ② or ③
/// '동의 필요'. `confirmPendingCaptures()` (`--preview-consent-confirm`) plays the server's part. Nothing is sent anywhere.
final class PreviewConsentStore: ConsentDocumentCatalog, ConsentCaptureRecorder, ConsentCaptureSource,
  ConsentStateSource, @unchecked Sendable
{
  private let lock = NSLock()
  private var states: [MemberKey: ConsentState]
  private var captures: [MemberKey: [ConsentCapture]]
  private var captureObservers: [UUID: (member: MemberKey, continuation: AsyncStream<[ConsentCapture]>.Continuation)] =
    [:]
  private var stateObservers: [UUID: (member: MemberKey, continuation: AsyncStream<ConsentState?>.Continuation)] = [:]
  private static let publishedAt = Date(timeIntervalSince1970: 1_780_000_000)

  init(script: PreviewConsentScript = PreviewConsentScript()) {
    states = script.states
    captures = script.captures
  }

  func publishedDocuments() async throws -> [ConsentDocumentVersion] {
    ConsentType.allCases.map {
      ConsentDocumentVersion(id: "\($0.rawValue)--1.0", consentType: $0, version: "1.0", publishedAt: Self.publishedAt)
    }
  }

  func capture(member: MemberKey, selections: [ConsentSelection]) async throws -> String {
    guard !selections.isEmpty else { throw ConsentCaptureError.invalidSelections }
    let capture = ConsentCapture(captureId: UUID().uuidString.lowercased(), member: member, selections: selections,
                                 capturedAt: Date(), state: .pending)
    lock.withLock {
      captures[member, default: []].append(capture)
      publishCaptures(of: member)
    }
    return capture.captureId
  }

  func observeCaptures(member: MemberKey) -> AsyncStream<[ConsentCapture]> {
    AsyncStream { continuation in
      let id = UUID()
      lock.withLock {
        captureObservers[id] = (member, continuation)
        continuation.yield(captures[member] ?? [])
      }
      continuation.onTermination = { [weak self] _ in
        self?.lock.withLock { _ = self?.captureObservers.removeValue(forKey: id) }
      }
    }
  }

  /// The scenario's `memberConsentStates` document of the member, then every change `confirmPendingCaptures()` makes.
  func observe(member: MemberKey) -> AsyncStream<ConsentState?> {
    AsyncStream { continuation in
      let id = UUID()
      lock.withLock {
        stateObservers[id] = (member, continuation)
        continuation.yield(states[member])
      }
      continuation.onTermination = { [weak self] _ in
        self?.lock.withLock { _ = self?.stateObservers.removeValue(forKey: id) }
      }
    }
  }

  /// What `recordConsent` and the state listener would do (`preview.confirmConsent`): each pending capture's grants
  /// become the member's server state, the capture becomes confirmed, and the server state is published first, as a
  /// listener update that arrives before the callable's reply.
  func confirmPendingCaptures() {
    lock.withLock {
      let now = Date()
      for (member, list) in captures where list.contains(where: { $0.state == .pending }) {
        var entries = states[member]?.entries ?? [:]
        captures[member] = list.map { capture in
          guard capture.state == .pending else { return capture }
          for selection in capture.selections {
            entries[selection.consentType] = ConsentStateEntry(
              granted: selection.action == .grant, documentVersion: selection.documentVersion)
          }
          return ConsentCapture(captureId: capture.captureId, member: member, selections: capture.selections,
                                capturedAt: capture.capturedAt, state: .confirmed, confirmedAt: now)
        }
        states[member] = ConsentState(entries: entries)
        stateObservers.values.filter { $0.member == member }.forEach { $0.continuation.yield(states[member]) }
        publishCaptures(of: member)
      }
    }
  }

  /// Called under the lock, so observers see the lists in order.
  private func publishCaptures(of member: MemberKey) {
    let list = captures[member] ?? []
    captureObservers.values.filter { $0.member == member }.forEach { $0.continuation.yield(list) }
  }
}
#endif
