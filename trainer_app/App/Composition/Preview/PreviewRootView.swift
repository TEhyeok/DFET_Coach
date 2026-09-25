#if DEBUG
import SwiftUI
import UIKit

/// DEBUG-only root for `--preview-*` launches: synthetic data, no Firebase.
struct PreviewRootView: View {
  let preview: PreviewEnvironment

  var body: some View {
    Group {
      if preview.isSignedIn {
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

  @ViewBuilder
  private var shell: some View {
    let root = RootSplitView(flags: preview.flagsProvider.current, members: preview.members)
    if let width = preview.simulatedWidth {
      // 1/3 Split View simulation (AC-DF-017.4): a narrow, compact-size-class window on the leading edge.
      root
        .environment(\.horizontalSizeClass, .compact)
        .frame(width: width)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemGray5).ignoresSafeArea())
    } else {
      root
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
