import SwiftUI

/// Placeholder root. DF-017 replaces it with the NavigationSplitView AppShell.
struct RootPlaceholderView: View {
  var body: some View {
    VStack(spacing: 12) {
      Text("root.placeholder.title")
        .font(.largeTitle.weight(.semibold))
      Text("root.placeholder.subtitle")
        .font(.body)
        .foregroundStyle(.secondary)
    }
    .padding(32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("app.root")
  }
}

#Preview {
  RootPlaceholderView()
}
