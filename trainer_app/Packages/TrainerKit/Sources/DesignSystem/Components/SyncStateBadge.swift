import SwiftUI
import TrainerContracts

/// The save state of one record (§6.0.3, DF-016). The only wording for these states: '기기에 저장됨', '동기화 중',
/// '동기화됨', '동기화 실패', '동의 확인 대기'. There is no plain '저장됨' (C-05). A failed state carries its reason
/// (`sync.reason.*`) and a '다시 시도' button (AC-DF-016.1).
public struct SyncStateBadge: View {
  private let state: SyncState
  private let reasonKey: String?
  private let onRetry: (() -> Void)?
  private let localize: Localizer

  public init(state: SyncState, reasonKey: String? = nil, onRetry: (() -> Void)? = nil, localize: Localizer = .main) {
    self.state = state
    self.reasonKey = reasonKey
    self.onRetry = onRetry
    self.localize = localize
  }

  /// Deck key of the state label.
  public static func labelKey(_ state: SyncState) -> String {
    "sync.\(state.rawValue)"
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: TrainerSpacing.xs) {
      Label {
        Text(localize(Self.labelKey(state)))
      } icon: {
        Image(systemName: Self.symbol(state))
      }
      .font(.footnote.weight(.medium))
      .foregroundStyle(Self.tint(state))
      .accessibilityIdentifier("sync.badge.\(state.rawValue)")
      if state == .syncFailed {
        if let reasonKey {
          Text(localize(reasonKey))
            .font(.footnote)
            .foregroundStyle(TrainerColor.danger)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("sync.badge.reason")
        }
        if let onRetry {
          Button(action: onRetry) {
            Text(localize("common.retry"))
              .font(.footnote.weight(.semibold))
              .frame(minWidth: TrainerSpacing.minTapTarget, minHeight: TrainerSpacing.minTapTarget)
              .contentShape(Rectangle())
          }
          .accessibilityIdentifier("sync.badge.retry")
        }
      }
    }
    .accessibilityElement(children: .contain)
  }

  static func symbol(_ state: SyncState) -> String {
    switch state {
    case .localSaved: return "iphone"
    case .syncing: return "arrow.triangle.2.circlepath"
    case .synced: return "checkmark.icloud"
    case .syncFailed: return "exclamationmark.icloud"
    case .awaitingConsent: return "hourglass"
    }
  }

  /// Green only for `.synced` (AC-DF-016.2).
  static func tint(_ state: SyncState) -> Color {
    switch state {
    case .synced: return TrainerColor.success
    case .syncFailed: return TrainerColor.danger
    case .awaitingConsent: return TrainerColor.caution
    case .localSaved, .syncing: return TrainerColor.neutral600
    }
  }
}
