import SwiftUI

/// Shown for `LaunchMode.misconfigured` (no Firebase configuration in the build). Never falls back to preview data
/// and makes no Firebase call (NFR-03, ADR-019 §3-3, AC-DF-017.6).
struct ConfigurationMissingView: View {
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: 44))
        .foregroundStyle(.orange)
        .accessibilityHidden(true)
      Text(String(localized: "app.config.missing"))
        .font(.title3)
        .multilineTextAlignment(.center)
    }
    .padding(32)
    .frame(maxWidth: 560)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("app.config.missing")
  }
}

#Preview {
  ConfigurationMissingView()
}
