import SwiftUI

/// Shown when the build has no Firebase configuration (`LaunchMode.misconfigured`).
/// Never falls back to preview data (NFR-03, ADR-019 §3-3). Copy keys are finalised by DF-017.
struct ConfigurationMissingView: View {
  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: 44))
        .foregroundStyle(.orange)
        .accessibilityHidden(true)
      Text("config.missing.title")
        .font(.title2.weight(.semibold))
      Text("config.missing.body")
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(32)
    .frame(maxWidth: 560)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("app.configMissing")
  }
}

#Preview {
  ConfigurationMissingView()
}
