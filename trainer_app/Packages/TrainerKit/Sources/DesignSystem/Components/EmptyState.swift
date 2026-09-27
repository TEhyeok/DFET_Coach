import SwiftUI

/// A successful query with nothing to show (§8.4, V1-07 §4): an icon, a one-line title and at most one next action.
/// Never used for a failed load (that is `common.loadFailed`, AC-VIZ-05.4).
public struct EmptyState: View {
  private let systemImage: String
  private let titleKey: String
  private let actionKey: String?
  private let action: (() -> Void)?
  private let localize: Localizer

  public init(
    systemImage: String, titleKey: String, actionKey: String? = nil, action: (() -> Void)? = nil,
    localize: Localizer = .main
  ) {
    self.systemImage = systemImage
    self.titleKey = titleKey
    self.actionKey = actionKey
    self.action = action
    self.localize = localize
  }

  public var body: some View {
    VStack(spacing: TrainerSpacing.m) {
      Image(systemName: systemImage)
        .font(.largeTitle)
        .foregroundStyle(TrainerColor.neutral400)
        .accessibilityHidden(true)
      Text(localize(titleKey))
        .font(.headline)
        .foregroundStyle(TrainerColor.neutral700)
        .multilineTextAlignment(.center)
      if let actionKey, let action {
        Button(action: action) {
          // The frame goes on the label so the button itself (and its bordered background) is at least 44 pt.
          Text(localize(actionKey))
            .frame(minWidth: TrainerSpacing.minTapTarget, minHeight: TrainerSpacing.minTapTarget)
            .padding(.horizontal, TrainerSpacing.s)
        }
        .buttonStyle(.borderedProminent)
        .tint(TrainerColor.brandBlueFill)
        .accessibilityIdentifier("empty.action")
      }
    }
    .padding(TrainerSpacing.xl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .contain)
  }
}
