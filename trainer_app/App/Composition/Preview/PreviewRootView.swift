#if DEBUG
import FeatureAuth
import SwiftUI
import SyncEngine
import UIKit

/// DEBUG-only root for `--preview-*` launches: synthetic data, no Firebase.
struct PreviewRootView: View {
  let preview: PreviewEnvironment

  @Environment(\.horizontalSizeClass) private var windowSizeClass
  /// Whether the `--preview-width=` simulation is applied. Toggled by `preview.toggleWidth` (`--preview-resizable`).
  @State private var isNarrow = true
  /// `--preview-login` only. Kept in state so the gate keeps one session source across view updates.
  @State private var auth = PreviewAuthService()
  /// `--preview-members-slow` only: holds the member list until `preview.releaseMembers`.
  @State private var memberGate = PreviewMemberGate()
  /// TR-14 registrations of this launch (DF-108), in memory; TR-02 lists them as device-only pending members.
  @State private var registrar = PreviewPendingMemberRegistrar()
  /// The scenario's consent and the TR-14 captures of this launch (DF-110, DF-113), in memory; published versions
  /// and server states are synthetic. TR-02 and TR-14 read it through one real `EffectiveConsentResolver`.
  @State private var consent: PreviewConsentStore
  @State private var effectiveConsent: EffectiveConsentResolver
  /// TR-15's Outbox view (DF-018), in memory.
  @State private var queue: PreviewSyncQueue

  init(preview: PreviewEnvironment) {
    self.preview = preview
    let consent = PreviewConsentStore(script: preview.consentScript)
    _consent = State(initialValue: consent)
    _effectiveConsent = State(initialValue: EffectiveConsentResolver(server: consent, captures: consent))
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
      flags: preview.flagsProvider.current,
      services: ShellServices(
        memberDirectory: PreviewMemberDirectory(script: preview.memberScript, gate: memberGate),
        localPendingMembers: registrar, registrar: registrar, consentDocuments: consent, consentRecorder: consent,
        effectiveConsent: effectiveConsent, syncQueue: queue, signOut: signOut,
        accountName: "SYN-TRAINER"))
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
        } else if preview.confirmsConsent {
          // The server's part of a capture (recordConsent + the state listener), on demand.
          Button { consent.confirmPendingCaptures() } label: {
            Text(verbatim: "Confirm consent")  // DEBUG tool, not copy
          }
          .buttonStyle(.borderedProminent)
          .padding(24)
          .accessibilityIdentifier("preview.confirmConsent")
        }
      }
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
