import SwiftUI
import UIKit
import FirebaseCore
import FirebaseAppCheck

@main
struct DFETTrainerApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @StateObject private var store = TrainerStore()
  @State private var didLeavePreviewLogin = false

  private let startsOnLogin = ProcessInfo.processInfo.arguments.contains("--preview-login")

  var body: some Scene {
    WindowGroup {
      Group {
        if store.isAuthenticated && (!startsOnLogin || didLeavePreviewLogin) {
          TrainerRootView()
        } else {
          LoginView {
            didLeavePreviewLogin = true
          }
        }
      }
        .environmentObject(store)
        .tint(TrainerColor.blue)
        .background(PreviewOrientationBridge())
    }
  }
}

/// 프리뷰 전용 실행 인자가 있을 때는 Firebase 초기화를 건너뛴다.
/// (GoogleService-Info.plist 미배치 환경에서도 프리뷰가 동작하도록)
private var isPreviewLaunch: Bool {
  ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("--preview-") }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    guard !isPreviewLaunch else { return true }

    // App Check (App Attest) — Auth/Firestore 호출 시 무결성 검증
    #if DEBUG
    let providerFactory = AppCheckDebugProviderFactory()
    #else
    let providerFactory = AppAttestProviderFactory()
    #endif
    AppCheck.setAppCheckProviderFactory(providerFactory)

    FirebaseApp.configure()
    return true
  }
}

private final class AppAttestProviderFactory: NSObject, AppCheckProviderFactory {
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    return AppAttestProvider(app: app)
  }
}

private struct PreviewOrientationBridge: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> UIViewController {
    let controller = UIViewController()
    requestLandscapeIfNeeded(from: controller)
    return controller
  }

  func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    requestLandscapeIfNeeded(from: uiViewController)
  }

  private func requestLandscapeIfNeeded(from controller: UIViewController) {
    guard CommandLine.arguments.contains("--preview-landscape") else {
      return
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
      controller.setNeedsUpdateOfSupportedInterfaceOrientations()

      guard #available(iOS 16.0, *) else {
        return
      }

      let scene = controller.view.window?.windowScene
        ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
      scene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
    }
  }
}
