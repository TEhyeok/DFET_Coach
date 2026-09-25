#if DEBUG
import SwiftUI
import UIKit

/// DEBUG-only root for `--preview-*` launches: synthetic data, no Firebase.
struct PreviewRootView: View {
  let preview: PreviewEnvironment

  @Environment(\.horizontalSizeClass) private var windowSizeClass
  /// Whether the `--preview-width=` simulation is applied. Toggled by `preview.toggleWidth` (`--preview-resizable`).
  @State private var isNarrow = true

  var body: some View {
    Group {
      if !preview.unknownArguments.isEmpty {
        // A mistyped `--preview-<name>` must not silently run another scenario. No `app.root`, so UI tests fail.
        Text(verbatim: "Unknown preview argument: \(preview.unknownArguments.joined(separator: " "))")
          .accessibilityIdentifier("preview.unknownArgument")
      } else if preview.isSignedIn {
        shell
      } else {
        // `--preview-login`: FeatureAuth's login screen (DF-012) replaces this placeholder.
        ComingSoonView()
          .accessibilityElement(children: .contain)
          .accessibilityIdentifier("login.root")
      }
    }
    .background(PreviewOrientationBridge(forcesLandscape: preview.forcesLandscape))
  }

  /// One view tree whatever the width, so toggling the simulation changes only the size class and frame, exactly
  /// like a real window resize, and `RootSplitView` keeps its state.
  private var shell: some View {
    let narrowWidth = isNarrow ? preview.simulatedWidth : nil
    return RootSplitView(flags: preview.flagsProvider.current, members: preview.members)
      // 1/3 Split View simulation (AC-DF-017.4): a narrow, compact-size-class window on the leading edge.
      .environment(\.horizontalSizeClass, narrowWidth == nil ? windowSizeClass : .compact)
      .frame(width: narrowWidth)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color(uiColor: .systemGray5).ignoresSafeArea())
      .overlay(alignment: .bottomTrailing) {
        if preview.isResizable, preview.simulatedWidth != nil {
          Button { isNarrow.toggle() } label: { Text(verbatim: isNarrow ? "Wide" : "Narrow") }  // DEBUG tool, not copy
            .buttonStyle(.borderedProminent)
            .padding(24)
            .accessibilityIdentifier("preview.toggleWidth")
        }
      }
  }
}

/// `--preview-landscape` (ported from dfet:trainer_ios/DFETTrainer/App/DFETTrainerApp.swift:59-90).
private struct PreviewOrientationBridge: UIViewControllerRepresentable {
  let forcesLandscape: Bool

  func makeUIViewController(context: Context) -> UIViewController {
    UIViewController()
  }

  func updateUIViewController(_ controller: UIViewController, context: Context) {
    guard forcesLandscape else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
      let scene = controller.view.window?.windowScene
        ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
      scene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
    }
  }
}
#endif
