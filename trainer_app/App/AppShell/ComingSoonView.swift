import SwiftUI

/// Temporary `common.comingSoon` screen for entry points whose flag is on but whose screen does not exist yet
/// (AC-DF-017.5). DF-016 replaces the text with DesignSystem's `ComingSoonLabel`.
struct ComingSoonView: View {
  var body: some View {
    Text(String(localized: "common.comingSoon"))
      .font(.title3)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
      .padding(24)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .accessibilityIdentifier("common.comingSoon")
  }
}

#Preview {
  ComingSoonView()
}
