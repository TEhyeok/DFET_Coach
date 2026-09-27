import SwiftUI

/// An entry point that exists but is not built yet: '추후 추가 예정' (§6.0.3, dfet:design.md:258). Trainer app only;
/// never used for v2 features (V1-12 `common.comingSoon`).
public struct ComingSoonLabel: View {
  private let localize: Localizer

  public init(localize: Localizer = .main) {
    self.localize = localize
  }

  public var body: some View {
    Text(localize("common.comingSoon"))
      .font(.footnote.weight(.medium))
      .foregroundStyle(TrainerColor.neutral600)
      .padding(.horizontal, TrainerSpacing.s)
      .padding(.vertical, TrainerSpacing.xxs)
      .background(TrainerColor.neutral100, in: Capsule())
      .accessibilityIdentifier("common.comingSoon")
  }
}
