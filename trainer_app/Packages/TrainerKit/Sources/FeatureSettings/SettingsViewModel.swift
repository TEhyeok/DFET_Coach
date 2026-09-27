import Foundation
import Observation
import TrainerDomain

/// TR-15 state (DF-018): the unsynced count and the failed items of the Outbox, and logout with its warning.
@MainActor
@Observable
public final class SettingsViewModel {
  public enum SignOutPrompt: Equatable {
    /// Nothing unsynced: confirm once (V1-07 §5.6).
    case confirm
    /// Unsynced records exist: warn with the live count; they stay on the device (AC-DF-018.2).
    case unsynced
  }

  public private(set) var pendingCount = 0
  public private(set) var failedItems: [OutboxItem] = []
  public var prompt: SignOutPrompt?
  public private(set) var isSigningOut = false
  public private(set) var signOutFailed = false

  /// The signed-in trainer's display name (TR-15 계정).
  public let accountName: String?
  /// `CFBundleShortVersionString (CFBundleVersion)`.
  public let version: String

  @ObservationIgnored private let queue: any SyncQueueService
  @ObservationIgnored private let session: any SessionSignOut
  @ObservationIgnored private var tasks: [Task<Void, Never>] = []

  public init(queue: any SyncQueueService, signOut: any SessionSignOut, accountName: String?, version: String) {
    self.queue = queue
    session = signOut
    self.accountName = accountName?.isEmpty == false ? accountName : nil
    self.version = version
  }

  deinit {
    tasks.forEach { $0.cancel() }
  }

  /// Starts following the Outbox. Called when TR-15 appears; later calls do nothing.
  public func start() {
    guard tasks.isEmpty else { return }
    let queue = queue
    tasks.append(Task { [weak self] in
      for await count in await queue.pendingCount() { self?.pendingCount = count }
    })
    tasks.append(Task { [weak self] in
      for await items in await queue.failedItems() { self?.failedItems = items }
    })
  }

  public func requestSignOut() {
    signOutFailed = false
    prompt = pendingCount == 0 ? .confirm : .unsynced
  }

  /// '지금 동기화': resend everything that failed; the warning keeps showing the live count.
  public func syncNow() async {
    await queue.retryAll()
    prompt = .unsynced
  }

  public func signOut() async {
    prompt = nil
    isSigningOut = true
    defer { isSigningOut = false }
    do {
      try await session.signOut()
    } catch {
      signOutFailed = true
    }
  }

  public func retry(_ id: UUID) async {
    await queue.retry(id)
  }

  public func retryAll() async {
    await queue.retryAll()
  }
}
