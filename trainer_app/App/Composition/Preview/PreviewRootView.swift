#if DEBUG
import FeatureAuth
import FeatureBodyComposition
import SwiftUI
import UIKit

/// DEBUG-only root for `--preview-*` launches: synthetic data, no Firebase.
struct PreviewRootView: View {
  let preview: PreviewEnvironment

  @Environment(\.horizontalSizeClass) private var windowSizeClass
  /// Whether the `--preview-width=` simulation is applied. Toggled by `preview.toggleWidth` (`--preview-resizable`),
  /// which is in a window of its own above the app's, so it works while a sheet such as TR-11 is open.
  @State private var isNarrow = true
  /// `--preview-login` only. Kept in state so the gate keeps one session source across view updates.
  @State private var auth = PreviewAuthService()
  /// `--preview-members-slow` only: holds the member list until `preview.releaseMembers`.
  @State private var memberGate = PreviewMemberGate()
  /// TR-14 registrations of this launch (DF-108), in memory.
  @State private var registrar = PreviewPendingMemberRegistrar()
  /// TR-15's Outbox view (DF-018), in memory.
  @State private var queue: PreviewSyncQueue
  /// TR-03 body composition and TR-11 (DF-127, DF-130): an in-memory LocalStore over synthetic records.
  @State private var bodyComposition = PreviewBodyComposition.services()

  init(preview: PreviewEnvironment) {
    self.preview = preview
    _queue = State(initialValue: PreviewSyncQueue(
      failed: preview.scenario == .queueFailed ? PreviewSyncQueue.syntheticFailures() : []))
  }

  var body: some View {
    Group {
      if !preview.unknownArguments.isEmpty {
        // A mistyped `--preview-<name>` must not silently run another scenario. No `app.root`, so UI tests fail.
        Text(verbatim: "Unknown preview argument: \(preview.unknownArguments.joined(separator: " "))")
          .accessibilityIdentifier("preview.unknownArgument")
      } else if preview.scenario == .designSystem {
        DesignSystemGallery()
      } else if preview.isSignedIn {
        shell(signOut: PreviewSessionSignOut { [auth] in try await auth.signOut(discardUnsynced: false) })
      } else {
        // `--preview-login`: the real login gate with scripted synthetic accounts (DF-012).
        AuthGate(auth: auth) { _, gate in
          shell(signOut: PreviewSessionSignOut { try await gate.signOut(discardUnsynced: false) })
        }
      }
    }
    .background(PreviewOrientationBridge(forcesLandscape: preview.forcesLandscape))
  }

  /// One view tree whatever the width, so toggling the simulation changes only the size class and frame, exactly
  /// like a real window resize, and `RootSplitView` keeps its state.
  private func shell(signOut: PreviewSessionSignOut) -> some View {
    let narrowWidth = isNarrow ? preview.simulatedWidth : nil
    return RootSplitView(
      flags: preview.flagsProvider,
      services: ShellServices(
        memberDirectory: PreviewMemberDirectory(script: preview.memberScript, gate: memberGate),
        registrar: registrar, syncQueue: queue, signOut: signOut,
        accountName: "SYN-TRAINER", bodyComposition: bodyComposition))
      // 1/3 Split View simulation (AC-DF-017.4): a narrow, compact-size-class window on the leading edge.
      .environment(\.horizontalSizeClass, narrowWidth == nil ? windowSizeClass : .compact)
      .frame(width: narrowWidth)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color(uiColor: .systemGray5).ignoresSafeArea())
      .overlay(alignment: .bottomLeading) {
        if preview.scenario == .membersSlow {
          Button { memberGate.release() } label: { Text(verbatim: "Release members") }  // DEBUG tool, not copy
            .buttonStyle(.borderedProminent)
            .padding(24)
            .accessibilityIdentifier("preview.releaseMembers")
        }
      }
      .background {
        if preview.isResizable, preview.simulatedWidth != nil {
          PreviewToolWindow(content: PreviewWidthToggle(isNarrow: isNarrow) { isNarrow.toggle() })
        }
      }
  }
}

/// The `--preview-resizable` button: switches between the simulated width and the full window.
private struct PreviewWidthToggle: View {
  let isNarrow: Bool
  let toggle: () -> Void

  var body: some View {
    Button(action: toggle) { Text(verbatim: isNarrow ? "Wide" : "Narrow") }  // DEBUG tool, not copy
      .buttonStyle(.borderedProminent)
      .accessibilityIdentifier("preview.toggleWidth")
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// A DEBUG tool in a small window of its own at the top trailing corner, above the app's window and every sheet in
/// it, so a UI test can use it while a sheet is open (a Split View resize with TR-11 open, NFR-12). The window is only
/// as large as the tool and never becomes key, so the rest of the screen and the keyboard focus stay the app's.
private struct PreviewToolWindow: UIViewRepresentable {
  let content: PreviewWidthToggle

  func makeUIView(context: Context) -> Anchor {
    let anchor = Anchor()
    anchor.isUserInteractionEnabled = false
    return anchor
  }

  func updateUIView(_ anchor: Anchor, context: Context) {
    anchor.show(content)
  }

  /// Sits in the app's window, which gives it the scene and the corner to place the tool window in.
  final class Anchor: UIView {
    private static let size = CGSize(width: 120, height: 60)
    private var tool: ToolWindow?
    private var host: UIHostingController<PreviewWidthToggle>?

    func show(_ content: PreviewWidthToggle) {
      if let host {
        host.rootView = content
      } else {
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        self.host = host
      }
      attach()
    }

    override func didMoveToWindow() {
      super.didMoveToWindow()
      attach()
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      place()
    }

    private func attach() {
      guard tool == nil, let host, let scene = window?.windowScene else { return }
      let tool = ToolWindow(windowScene: scene)
      tool.windowLevel = .alert + 1
      tool.backgroundColor = .clear
      tool.rootViewController = host
      tool.isHidden = false
      self.tool = tool
      place()
    }

    private func place() {
      guard let tool, let window else { return }
      let top = window.safeAreaInsets.top + 8
      tool.frame = CGRect(x: window.bounds.maxX - Self.size.width - 16, y: top, width: Self.size.width,
                          height: Self.size.height)
    }
  }
}

/// Never key: a tap on the tool leaves the keyboard focus where it was (a TR-11 field keeps its keyboard).
private final class ToolWindow: UIWindow {
  override var canBecomeKey: Bool { false }
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
