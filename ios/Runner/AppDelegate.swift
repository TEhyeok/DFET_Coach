import Flutter
import Contacts
import ContactsUI
import PencilKit
import PhotosUI
import SceneKit
import SwiftUI
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let didFinishLaunching = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    configureNativeSoapWorkspaceChannel()
    configureNativeTrainerHomeChannel()
    presentNativeTrainerHomePreviewIfRequested()
    presentNativeSoapPreviewIfRequested()
    return didFinishLaunching
  }

  private func configureNativeSoapWorkspaceChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "dfet/native_soap_workspace",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self, weak controller] call, result in
      guard call.method == "openSoapWorkspace" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let presenter = controller else {
        result(
          FlutterError(
            code: "no_presenter",
            message: "Native workspace presenter is unavailable.",
            details: nil
          )
        )
        return
      }

      let arguments = call.arguments as? [String: Any] ?? [:]
      self?.presentNativeSoapWorkspace(
        arguments: arguments,
        from: presenter,
        flutterResult: result
      )
    }
  }

  private func configureNativeTrainerHomeChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "dfet/native_trainer_home",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self, weak controller] call, result in
      guard call.method == "openTrainerHome" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let presenter = controller else {
        result(
          FlutterError(
            code: "no_presenter",
            message: "Native trainer home presenter is unavailable.",
            details: nil
          )
        )
        return
      }

      let arguments = call.arguments as? [String: Any] ?? [:]
      self?.presentNativeTrainerHome(
        arguments: arguments,
        from: presenter,
        flutterResult: result,
        syncChannel: channel
      )
    }
  }

  private func presentNativeSoapWorkspace(
    arguments: [String: Any],
    from presenter: UIViewController,
    flutterResult: FlutterResult?
  ) {
    var didFinish = false
    var hostingController: UIViewController?

    func finish(_ payload: Any?) {
      guard !didFinish else { return }
      didFinish = true
      hostingController?.dismiss(animated: true) {
        flutterResult?(payload)
      }
    }

    let workspace = NativeSoapWorkspaceView(
      arguments: arguments,
      onSave: { payload in finish(payload) },
      onCancel: { finish(nil) }
    )

    let host = UIHostingController(rootView: workspace)
    host.modalPresentationStyle = .fullScreen
    host.view.backgroundColor = UIColor(hex: 0xF6F8FF)
    hostingController = host

    topMostViewController(from: presenter).present(host, animated: true)
  }

  private func presentNativeTrainerHome(
    arguments: [String: Any] = [:],
    from presenter: UIViewController,
    flutterResult: FlutterResult?,
    syncChannel: FlutterMethodChannel? = nil
  ) {
    var didFinish = false
    var hostingController: UIViewController?

    func finish() {
      guard !didFinish else { return }
      didFinish = true
      hostingController?.dismiss(animated: true) {
        flutterResult?(nil)
      }
    }

    func logoutToLogin() {
      guard !didFinish else { return }
      didFinish = true
      syncChannel?.invokeMethod("nativeTrainerLogout", arguments: nil)
      hostingController?.dismiss(animated: true) {
        flutterResult?(nil)
      }
    }

    let initialRoute = NativeTrainerRoute(
      rawValue: arguments["initialRoute"] as? String ?? ""
    ) ?? .sessionBoard
    let home = NativeTrainerHomeView(
      initialRoute: initialRoute,
      onClose: finish,
      onLogoutToLogin: logoutToLogin,
      onSyncSoap: { payload, completion in
        guard let syncChannel else {
          completion(false)
          return
        }
        syncChannel.invokeMethod("saveNativeTrainerSoapNote", arguments: payload) { response in
          if response is FlutterError {
            completion(false)
            return
          }
          let responseMap = response as? [String: Any]
          completion(responseMap?["synced"] as? Bool ?? false)
        }
      }
    )
    let host = UIHostingController(rootView: home)
    host.modalPresentationStyle = .fullScreen
    host.view.backgroundColor = UIColor.systemGroupedBackground
    hostingController = host

    topMostViewController(from: presenter).present(host, animated: true)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if url.scheme == "dfetcoach", url.host == "native-soap-preview" {
      guard let presenter = window?.rootViewController else {
        return false
      }
      presentNativeSoapWorkspace(
        arguments: [
          "memberName": "김회원",
          "diagnosis": "허리 관리",
          "bodyRegion": "허리",
          "painNow": 7,
          "painSite": "허리",
          "riskLevel": "high",
          "subjective": "스쿼트 시 허리 불편\n호흡 cue 후 안정",
          "treatmentPlan": "hip hinge 패턴 재교육",
          "homeExercise": "dead bug 2세트",
          "nextPlan": "ROM/MMT 재확인"
        ],
        from: presenter,
        flutterResult: nil
      )
      return true
    }
    if url.scheme == "dfetcoach", url.host == "native-trainer-home-preview" {
      guard let presenter = window?.rootViewController else {
        return false
      }
      let route = URLComponents(url: url, resolvingAgainstBaseURL: false)?
        .queryItems?
        .first(where: { $0.name == "route" })?
        .value
      presentNativeTrainerHome(
        arguments: route.map { ["initialRoute": $0] } ?? [:],
        from: presenter,
        flutterResult: nil
      )
      return true
    }
    return super.application(app, open: url, options: options)
  }

  private func topMostViewController(from root: UIViewController) -> UIViewController {
    var current = root
    while let presented = current.presentedViewController {
      current = presented
    }
    return current
  }

  private func currentRootViewController() -> UIViewController? {
    if let root = window?.rootViewController {
      return root
    }

    return UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)?
      .rootViewController
  }

  private func presentNativeSoapPreviewIfRequested() {
    guard shouldOpenNativeSoapPreview() else {
      return
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
      self?.presentNativeSoapPreview(retriesRemaining: 12)
    }
  }

  private func presentNativeTrainerHomePreviewIfRequested() {
    guard shouldOpenNativeTrainerHomePreview() else {
      return
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
      self?.presentNativeTrainerHomePreview(retriesRemaining: 12)
    }
  }

  private func presentNativeTrainerHomePreview(retriesRemaining: Int) {
    guard shouldOpenNativeTrainerHomePreview() else {
      return
    }

    guard let presenter = currentRootViewController() else {
      guard retriesRemaining > 0 else { return }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
        self?.presentNativeTrainerHomePreview(retriesRemaining: retriesRemaining - 1)
      }
      return
    }

    UserDefaults.standard.set(false, forKey: "DFETOpenNativeTrainerHomePreview")
    presentNativeTrainerHome(
      arguments: nativeTrainerHomePreviewArguments(),
      from: presenter,
      flutterResult: nil
    )
  }

  private func presentNativeSoapPreview(retriesRemaining: Int) {
    guard shouldOpenNativeSoapPreview() else {
      return
    }

    guard let presenter = currentRootViewController() else {
      guard retriesRemaining > 0 else { return }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
        self?.presentNativeSoapPreview(retriesRemaining: retriesRemaining - 1)
      }
      return
    }

    UserDefaults.standard.set(false, forKey: "DFETOpenNativeSOAPPreview")
    presentNativeSoapWorkspace(
      arguments: [
        "memberName": "김회원",
        "diagnosis": "허리 관리",
        "bodyRegion": "허리",
        "painNow": 7,
        "painSite": "허리",
        "riskLevel": "high",
        "subjective": "스쿼트 시 허리 불편\n호흡 cue 후 안정",
        "treatmentPlan": "hip hinge 패턴 재교육",
        "homeExercise": "dead bug 2세트",
        "nextPlan": "ROM/MMT 재확인"
      ],
      from: presenter,
      flutterResult: nil
    )
  }

  private func shouldOpenNativeSoapPreview() -> Bool {
    UserDefaults.standard.bool(forKey: "DFETOpenNativeSOAPPreview") ||
      ProcessInfo.processInfo.arguments.contains("-DFETOpenNativeSOAPPreview")
  }

  private func shouldOpenNativeTrainerHomePreview() -> Bool {
    UserDefaults.standard.bool(forKey: "DFETOpenNativeTrainerHomePreview") ||
      ProcessInfo.processInfo.arguments.contains("-DFETOpenNativeTrainerHomePreview")
  }

  private func nativeTrainerHomePreviewArguments() -> [String: Any] {
    let arguments = ProcessInfo.processInfo.arguments
    if let routeFlagIndex = arguments.firstIndex(of: "-DFETNativeTrainerRoute"),
       arguments.indices.contains(routeFlagIndex + 1) {
      return ["initialRoute": arguments[routeFlagIndex + 1]]
    }
    if let route = UserDefaults.standard.string(forKey: "DFETNativeTrainerHomeRoute") {
      UserDefaults.standard.removeObject(forKey: "DFETNativeTrainerHomeRoute")
      return ["initialRoute": route]
    }
    return [:]
  }
}

private struct NativeTrainerHomeView: View {
  let onClose: () -> Void
  let onLogoutToLogin: () -> Void
  let onSyncSoap: ([String: Any], @escaping (Bool) -> Void) -> Void

  @State private var selectedRoute: NativeTrainerRoute = .sessionBoard
  @State private var members: [NativeTrainerMember]
  @State private var selectedMemberId: NativeTrainerMember.ID = NativeTrainerMember.emptySelectionId
  @State private var requestedSoapMode = "필기"
  @State private var soapDraftsByDay: [String: NativeSoapDailyDraft] = [:]
  @State private var pendingFeatureTitle = ""
  @State private var showingPendingFeature = false

  init(
    initialRoute: NativeTrainerRoute = .summary,
    onClose: @escaping () -> Void,
    onLogoutToLogin: @escaping () -> Void,
    onSyncSoap: @escaping ([String: Any], @escaping (Bool) -> Void) -> Void = { _, completion in completion(false) }
  ) {
    self.onClose = onClose
    self.onLogoutToLogin = onLogoutToLogin
    self.onSyncSoap = onSyncSoap
    let storedMembers = NativeTrainerMember.loadStoredMembers()
    _members = State(initialValue: storedMembers)
    _selectedRoute = State(initialValue: initialRoute)
    _selectedMemberId = State(initialValue: storedMembers.first?.id ?? NativeTrainerMember.emptySelectionId)
  }

  var body: some View {
    Group {
      if #available(iOS 16.0, *) {
        NavigationSplitView {
          sidebar
        } detail: {
          detail
        }
      } else {
        HStack(spacing: 0) {
          sidebar.frame(width: 286)
          Divider()
          detail
        }
      }
    }
    .tint(NativeHealthColor.blue)
    .preferredColorScheme(.light)
    .alert("추후 추가 예정", isPresented: $showingPendingFeature) {
      Button("확인", role: .cancel) {}
    } message: {
      Text("\(pendingFeatureTitle)은 다음 단계에서 실제 데이터와 저장 흐름을 연결합니다.")
    }
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 10) {
        NativeDFETLogoMark(size: 38)
        VStack(alignment: .leading, spacing: 2) {
          Text("D-FET")
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white)
          Text("Trainer")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.62))
        }
        Spacer()
        Button(action: onClose) {
          Image(systemName: "xmark")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color.white.opacity(0.72))
            .frame(width: 30, height: 30)
            .background(Color.white.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 18)
      .padding(.top, 24)
      .padding(.bottom, 22)

      VStack(alignment: .leading, spacing: 7) {
        ForEach(NativeTrainerRoute.mainRoutes) { route in
          routeRow(route)
        }
      }
      .padding(.horizontal, 12)

      Spacer()

      VStack(alignment: .leading, spacing: 7) {
        ForEach(NativeTrainerRoute.utilityRoutes) { route in
          routeRow(route)
        }
      }
      .padding(.horizontal, 12)

      VStack(alignment: .leading, spacing: 7) {
        Text("구현 전")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(Color.white.opacity(0.46))
          .padding(.horizontal, 12)
          .padding(.bottom, 2)

        ForEach(NativeTrainerRoute.pendingRoutes) { route in
          routeRow(route)
        }
      }
      .padding(.horizontal, 12)
      .padding(.top, 14)
      .padding(.bottom, 12)

      logoutToLoginButton
        .padding(.horizontal, 12)
        .padding(.bottom, 20)
    }
    .frame(minWidth: 238)
    .background(
      LinearGradient(
        colors: [NativeHealthColor.sidebarNavy, NativeHealthColor.deepBlue],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()
    )
  }

  private var detail: some View {
    Group {
      switch selectedRoute {
      case .sessionBoard:
        NativeTrainerSessionBoardDetail(
          selectedMemberId: $selectedMemberId,
          members: members,
          onOpenMembers: { selectedRoute = .members },
          onOpenSoapMode: { mode in
            requestedSoapMode = mode
            selectedRoute = .soap
          }
        )
      case .summary:
        NativeTrainerSummaryDetail(
          members: members,
          soapDraftsByDay: soapDraftsByDay,
          onOpenMembers: { selectedRoute = .members },
          onOpenSoap: {
            requestedSoapMode = "SOAP"
            selectedRoute = .soap
          }
        )
      case .members:
        NativeTrainerMembersDetail(
          selectedMemberId: $selectedMemberId,
          members: $members,
          soapDraftsByDay: $soapDraftsByDay,
          onOpenSoap: {
            requestedSoapMode = "SOAP"
            selectedRoute = .soap
          }
        )
      case .soap:
        NativeTrainerSoapDetail(
          selectedMemberId: $selectedMemberId,
          members: members,
          requestedMode: $requestedSoapMode,
          soapDraftsByDay: $soapDraftsByDay,
          onSyncSoap: onSyncSoap
        )
      case .schedule:
        NativeTrainerPlaceholderDetail(
          title: "일정",
          subtitle: "오늘 수업과 재평가 일정을 한 화면에서 정리합니다.",
          symbol: "calendar"
        )
      case .program:
        NativeTrainerPlaceholderDetail(
          title: "프로그램",
          subtitle: "운동 처방, 세트, 반복, 강도, 진행도를 관리합니다.",
          symbol: "list.bullet.rectangle"
        )
      case .reports:
        NativeTrainerReportsDetail(members: members, soapDraftsByDay: soapDraftsByDay)
      case .alerts:
        NativeTrainerPlaceholderDetail(
          title: "알림",
          subtitle: "SOAP 미완료, 재평가 도래, 공유 대기 항목을 모읍니다.",
          symbol: "bell"
        )
      case .settings:
        NativeTrainerSettingsDetail(onLogoutToLogin: onLogoutToLogin)
      }
    }
    .background(NativeHealthColor.background.ignoresSafeArea())
    .navigationTitle("")
  }

  private var logoutToLoginButton: some View {
    Button(action: onLogoutToLogin) {
      HStack(spacing: 10) {
        Image(systemName: "rectangle.portrait.and.arrow.right")
          .font(.system(size: 15, weight: .semibold))
          .frame(width: 20)

        Text("로그인 화면")
          .font(.system(size: 15, weight: .bold))

        Spacer(minLength: 8)

        Text("TR-SB-LOGIN")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(Color.white.opacity(0.66))
          .padding(.horizontal, 6)
          .frame(height: 18)
          .background(Color.white.opacity(0.12), in: Capsule())
      }
      .foregroundStyle(Color.white)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 11)
      .padding(.horizontal, 12)
      .background(Color.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(Color.white.opacity(0.14), lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel("로그인 화면으로 나가기")
  }

  private func routeRow(_ route: NativeTrainerRoute) -> some View {
    Button {
      guard !route.isPending else {
        showPendingFeature(route.title)
        return
      }
      if route == .soap {
        requestedSoapMode = "SOAP"
      }
      selectedRoute = route
    } label: {
      HStack(spacing: 10) {
        Image(systemName: route.symbol)
          .font(.system(size: 15, weight: .semibold))
          .frame(width: 20)

        Text(route.title)
          .font(.system(size: 15, weight: selectedRoute == route ? .bold : .semibold))

        Spacer(minLength: 8)

        if route.isPending {
          Text("구현 전")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.white.opacity(0.58))
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(Color.white.opacity(0.10), in: Capsule())
        }
      }
      .foregroundStyle(selectedRoute == route ? Color.white : Color.white.opacity(route.isPending ? 0.45 : 0.70))
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 10)
      .padding(.horizontal, 12)
      .background(
        selectedRoute == route && !route.isPending ? NativeHealthColor.blue : Color.clear,
        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
      )
    }
    .buttonStyle(.plain)
  }

  private func showPendingFeature(_ title: String) {
    pendingFeatureTitle = title
    showingPendingFeature = true
  }

  private func memberRow(_ member: NativeTrainerMember) -> some View {
    Button {
      selectedRoute = .members
      selectedMemberId = member.id
    } label: {
      HStack(spacing: 10) {
        NativeMemojiAvatar(member: member, size: 34)

        VStack(alignment: .leading, spacing: 2) {
          Text(member.name)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(NativeHealthColor.primaryText)
          Text(member.subtitle)
            .font(.system(size: 12))
            .foregroundStyle(NativeHealthColor.secondaryText)
        }

        Spacer()

        Text(member.riskLabel)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(member.statusColor)
      }
      .padding(.vertical, 6)
    }
    .buttonStyle(.plain)
  }
}

private struct NativeDFETLogoMark: View {
  let size: CGFloat

  var body: some View {
    Image("DFETLogo")
      .resizable()
      .scaledToFit()
      .padding(size * 0.13)
      .frame(width: size, height: size)
      .background(
        LinearGradient(
          colors: [NativeHealthColor.deepBlue, NativeHealthColor.sidebarNavy],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
          .stroke(Color.white.opacity(0.16), lineWidth: 1)
      )
      .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 5)
  }
}

private struct NativeEmptyState: View {
  let title: String
  let message: String
  let symbol: String

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: symbol)
        .font(.system(size: 30, weight: .bold))
        .foregroundStyle(NativeHealthColor.blue)
        .frame(width: 58, height: 58)
        .background(NativeHealthColor.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

      Text(title)
        .font(.system(size: 19, weight: .bold, design: .rounded))
        .foregroundStyle(NativeHealthColor.primaryText)

      Text(message)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(NativeHealthColor.secondaryText)
        .multilineTextAlignment(.center)
        .lineSpacing(2)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 30)
    .padding(.horizontal, 18)
    .background(NativeHealthColor.subPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(NativeHealthColor.border, lineWidth: 1)
    )
  }
}

private struct NativeTrainerSessionBoardDetail: View {
  @Binding var selectedMemberId: NativeTrainerMember.ID
  let members: [NativeTrainerMember]
  let onOpenMembers: () -> Void
  let onOpenSoapMode: (String) -> Void
  @State private var pendingFeatureTitle = ""
  @State private var showingPendingFeature = false

  private var selectedMember: NativeTrainerMember {
    members.first(where: { $0.id == selectedMemberId }) ?? NativeTrainerMember.emptyMember
  }

  private let scheduleRows: [(String, String, String)] = []

  var body: some View {
    GeometryReader { geometry in
      let wide = geometry.size.width >= 1060

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          dashboardHeader
          if wide {
            HStack(alignment: .top, spacing: 18) {
              VStack(spacing: 18) {
                todaySchedulePanel
                progressPanel
                recentNotesPanel
              }
                .frame(maxWidth: .infinity)

              VStack(spacing: 18) {
                quickRecordPanel
                alertsPanel
              }
              .frame(width: min(390, max(340, geometry.size.width * 0.34)))
            }
          } else {
            VStack(spacing: 18) {
              todaySchedulePanel
              quickRecordPanel
              progressPanel
              alertsPanel
              recentNotesPanel
            }
          }
        }
        .padding(wide ? 28 : 20)
        .frame(maxWidth: 1220, alignment: .topLeading)
        .frame(maxWidth: .infinity)
      }
      .background(NativeHealthColor.background.ignoresSafeArea())
    }
    .alert("추후 추가 예정", isPresented: $showingPendingFeature) {
      Button("확인", role: .cancel) {}
    } message: {
      Text("\(pendingFeatureTitle)은 다음 단계에서 실제 데이터, 저장, 알림 흐름을 연결합니다.")
    }
  }

  private var dashboardHeader: some View {
    HStack(alignment: .center, spacing: 16) {
      VStack(alignment: .leading, spacing: 5) {
        Text("홈 대시보드")
          .font(.system(size: 32, weight: .bold, design: .rounded))
          .foregroundStyle(NativeHealthColor.primaryText)
        Text("오늘 일정, 회원 현황, 빠른 기록, 알림, 최근 노트를 한눈에 봅니다.")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(NativeHealthColor.secondaryText)
      }

      Spacer()

      HStack(spacing: 10) {
        NativeStatusCapsule(text: "오늘 0건", color: NativeHealthColor.blue)
        NativeStatusCapsule(text: "회원 \(members.count)명", color: NativeHealthColor.purple)
        NativeStatusCapsule(text: "SOAP 0건", color: NativeHealthColor.green)
      }
    }
  }

  private var todaySchedulePanel: some View {
    NativeBoardPanel(title: "오늘 일정", subtitle: "등록된 일정 없음") {
      VStack(spacing: 0) {
        NativeEmptyState(
          title: "등록된 일정이 없습니다",
          message: "회원과 수업 일정을 연결하면 오늘 할 일이 여기에 표시됩니다.",
          symbol: "calendar"
        )
      }
    }
  }

  private var quickRecordPanel: some View {
    NativeBoardPanel(title: "빠른 기록", subtitle: "수업 중 자주 쓰는 작업") {
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
	        quickRecordButton(title: "필기 SOAP 시작", symbol: "pencil.and.scribble", color: NativeHealthColor.blue) {
	          onOpenSoapMode("필기")
        }
        quickRecordButton(title: "회원 관리", symbol: "person.2", color: NativeHealthColor.purple) {
          onOpenMembers()
        }
	        quickRecordButton(title: "키보드 SOAP 정리", symbol: "square.and.pencil", color: NativeHealthColor.orange) {
	          onOpenSoapMode("SOAP")
	        }
      }
    }
  }

  private var progressPanel: some View {
    NativeBoardPanel(title: "진행 현황", subtitle: "오늘 처리해야 할 핵심 상태") {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
        dashboardMetric(title: "완료", value: "0", caption: "오늘 수업", color: NativeHealthColor.blue)
        dashboardMetric(title: "회원", value: "\(members.count)", caption: "관리 대상", color: NativeHealthColor.green)
        dashboardMetric(title: "재평가", value: "0", caption: "이번 주", color: NativeHealthColor.orange)
        dashboardMetric(title: "SOAP", value: "0", caption: "작성 기록", color: NativeHealthColor.purple)
      }
    }
  }

  private var alertsPanel: some View {
    NativeBoardPanel(title: "알림", subtitle: "우선 확인할 항목") {
      VStack(spacing: 10) {
        NativeEmptyState(
          title: "알림이 없습니다",
          message: "회원 기록과 SOAP가 쌓이면 확인할 항목이 표시됩니다.",
          symbol: "bell"
        )
      }
    }
  }

  private var recentNotesPanel: some View {
    NativeBoardPanel(title: "최근 노트", subtitle: "오늘 작성 또는 수정된 기록") {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
        if members.isEmpty {
          NativeEmptyState(
            title: "최근 노트가 없습니다",
            message: "첫 SOAP 노트를 작성하면 이 영역에 최근 기록이 표시됩니다.",
            symbol: "doc.text"
          )
        } else {
          ForEach(members) { member in
          Button {
            selectedMemberId = member.id
            onOpenSoapMode("SOAP")
          } label: {
            VStack(alignment: .leading, spacing: 10) {
              HStack(spacing: 8) {
                NativeMemojiAvatar(member: member, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                  Text(member.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(NativeHealthColor.primaryText)
                  Text(member.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NativeHealthColor.secondaryText)
                    .lineLimit(1)
                }
                Spacer()
              }
              Text(member.nextPlan)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(NativeHealthColor.secondaryText)
                .lineLimit(2)
            }
            .padding(12)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
              RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(NativeHealthColor.border, lineWidth: 1)
            )
          }
          .buttonStyle(.plain)
          }
        }
      }
    }
  }

  private func quickRecordButton(
    title: String,
    symbol: String,
    color: Color,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: symbol)
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(color)
          .frame(width: 34, height: 34)
          .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        Text(title)
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(NativeHealthColor.primaryText)
          .lineLimit(2)
        Spacer(minLength: 0)
      }
      .padding(12)
      .frame(minHeight: 64)
      .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(NativeHealthColor.border, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
  }

	  private func dashboardMetric(title: String, value: String, caption: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(NativeHealthColor.secondaryText)
      Text(value)
        .font(.system(size: 24, weight: .bold, design: .rounded))
        .foregroundStyle(NativeHealthColor.primaryText)
      HStack(spacing: 6) {
        Circle()
          .fill(color)
          .frame(width: 6, height: 6)
        Text(caption)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(NativeHealthColor.secondaryText)
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(NativeHealthColor.border, lineWidth: 1)
	    )
	  }

  private func showPendingFeature(_ title: String) {
    pendingFeatureTitle = title
    showingPendingFeature = true
  }
}

private struct NativeTrainerPlaceholderDetail: View {
  let title: String
  let subtitle: String
  let symbol: String

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(spacing: 14) {
        Image(systemName: symbol)
          .font(.system(size: 20, weight: .bold))
          .foregroundStyle(NativeHealthColor.blue)
          .frame(width: 48, height: 48)
          .background(NativeHealthColor.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        VStack(alignment: .leading, spacing: 5) {
          HStack(spacing: 10) {
            Text(title)
              .font(.system(size: 32, weight: .bold, design: .rounded))
              .foregroundStyle(NativeHealthColor.primaryText)
            NativeStatusCapsule(text: "추후 추가 예정", color: NativeHealthColor.orange)
          }
          Text(subtitle)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(NativeHealthColor.secondaryText)
        }
      }

      NativeHealthCard {
        VStack(alignment: .leading, spacing: 12) {
          Text("추후 추가 예정")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(NativeHealthColor.primaryText)
          Text("현재 1차 구현 범위는 홈 대시보드, 회원 프로필·평가, SOAP 노트 작성입니다. \(title) 기능은 다음 단계에서 실제 데이터, 저장, 알림, 리포트 흐름을 연결합니다.")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(NativeHealthColor.secondaryText)
        }
      }
    }
    .padding(32)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(NativeHealthColor.background)
  }
}

private struct NativeTrainerSummaryDetail: View {
  let members: [NativeTrainerMember]
  let soapDraftsByDay: [String: NativeSoapDailyDraft]
  let onOpenMembers: () -> Void
  let onOpenSoap: () -> Void

  private let columns = [
    GridItem(.adaptive(minimum: 190), spacing: 14)
  ]

  private var analytics: NativeSoapAnalytics {
    NativeSoapAnalytics(members: members, soapDraftsByDay: soapDraftsByDay)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        header

        NativeHealthCard {
          HStack(spacing: 16) {
            NativeIconSquare(systemName: "heart.fill", color: NativeHealthColor.green)

            VStack(alignment: .leading, spacing: 5) {
              Text("오늘 상태")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(NativeHealthColor.secondaryText)
          Text(members.isEmpty ? "첫 회원을 등록하세요" : "회원 \(members.count)명을 관리 중입니다")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(NativeHealthColor.primaryText)
          Text(members.isEmpty ? "회원등록 후 SOAP 기록을 시작할 수 있습니다." : "통증 상승과 재평가 일정을 확인하세요.")
                .font(.system(size: 15))
                .foregroundStyle(NativeHealthColor.secondaryText)
            }

            Spacer()

            Button(action: onOpenMembers) {
              Text("회원 확인")
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
          }
        }

        LazyVGrid(columns: columns, spacing: 14) {
          NativeMetricTile(title: "오늘 SOAP", value: "\(analytics.todaySoapCount)", unit: "건", symbol: "calendar", color: NativeHealthColor.blue)
          NativeMetricTile(title: "관리 회원", value: "\(members.count)", unit: "명", symbol: "person.2", color: NativeHealthColor.purple)
          NativeMetricTile(title: "주의 필요", value: "\(analytics.attentionMemberCount)", unit: "명", symbol: "exclamationmark.triangle", color: NativeHealthColor.orange)
          NativeMetricTile(title: "SOAP 기록", value: "\(analytics.totalSoapCount)", unit: "건", symbol: "doc.text", color: NativeHealthColor.green)
        }

        HStack(alignment: .top, spacing: 16) {
          NativeHealthCard {
            VStack(alignment: .leading, spacing: 16) {
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  Text("회원 상태 변화")
                    .font(.system(size: 21, weight: .bold))
                  Text("최근 6회 SOAP 기준")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(NativeHealthColor.secondaryText)
                }
                Spacer()
                NativeStatusCapsule(text: analytics.averagePainText, color: NativeHealthColor.blue)
              }

              if analytics.painPoints.isEmpty && analytics.completionPoints.isEmpty {
                NativeEmptyState(
                  title: "SOAP 그래프 데이터 없음",
                  message: "회원별 날짜 SOAP를 저장하면 통증과 완료율 변화가 표시됩니다.",
                  symbol: "chart.xyaxis.line"
                )
                .frame(height: 210)
              } else {
                NativeLineChart(
                  painPoints: analytics.painPoints,
                  completionPoints: analytics.completionPoints,
                  labels: analytics.chartLabels
                )
                .frame(height: 210)
              }

              HStack(spacing: 16) {
                NativeLegend(label: "통증", color: NativeHealthColor.red)
                NativeLegend(label: "SOAP 완료율", color: NativeHealthColor.blue)
              }
            }
          }

          VStack(spacing: 16) {
            NativeHealthCard {
              VStack(alignment: .leading, spacing: 14) {
                HStack {
                  Text("오늘 볼 회원")
                    .font(.system(size: 21, weight: .bold))
                  Spacer()
                  Button("전체 보기", action: onOpenMembers)
                    .font(.system(size: 14, weight: .semibold))
                }

                if members.isEmpty {
                  NativeEmptyState(
                    title: "등록된 회원이 없습니다",
                    message: "회원 관리에서 첫 회원을 등록하세요.",
                    symbol: "person.crop.circle.badge.plus"
                  )
                } else {
                  ForEach(members.prefix(3)) { member in
                  NativeMemberSignalRow(member: member)
                  if member.id != members.prefix(3).last?.id {
                    Divider()
                  }
                  }
                }
              }
            }

            NativeHealthCard {
              VStack(alignment: .leading, spacing: 14) {
                Text("빠른 작업")
                  .font(.system(size: 21, weight: .bold))
                Button(action: onOpenSoap) {
                  Label("새 SOAP 기록", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: onOpenMembers) {
                  Label("회원 타임라인", systemImage: "chart.xyaxis.line")
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
              }
            }
          }
          .frame(width: 330)
        }
      }
      .padding(32)
      .frame(maxWidth: 1180, alignment: .topLeading)
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text("5월 4일 월요일")
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(NativeHealthColor.secondaryText)
      Text("트레이너 요약")
        .font(.system(size: 38, weight: .bold))
        .foregroundStyle(NativeHealthColor.primaryText)
    }
  }
}

private struct NativeTrainerMembersDetail: View {
  @Binding var selectedMemberId: NativeTrainerMember.ID
  @Binding var members: [NativeTrainerMember]
  @Binding var soapDraftsByDay: [String: NativeSoapDailyDraft]
  let onOpenSoap: () -> Void
  @State private var showingShareReport = false
  @State private var showingMemberRegistration = false
  @State private var showingMemberCancelConfirmation = false
  @State private var showingMemojiKeyboardPicker = false
  @State private var showingPhotoPicker = false
  @State private var showingContactImagePicker = false
  @State private var avatarPickerError: String?
  @State private var isResolvingAutomaticAvatar = false
  @State private var selectedMemberTimelineDate = Calendar.current.startOfDay(for: Date())

  private var selectedMember: NativeTrainerMember {
    members.first(where: { $0.id == selectedMemberId }) ?? NativeTrainerMember.emptyMember
  }

  var body: some View {
    GeometryReader { geometry in
      let wide = geometry.size.width >= 1080

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          memberHeader

          if members.isEmpty {
            NativeEmptyState(
              title: "등록된 회원이 없습니다",
              message: "회원등록을 누르면 프로필, 평가, 세션 히스토리와 SOAP 작성 흐름을 시작할 수 있습니다.",
              symbol: "person.crop.circle.badge.plus"
            )
          } else if wide {
            HStack(alignment: .top, spacing: 18) {
              profileRail
                .frame(width: 238)
              evaluationPanel
                .frame(maxWidth: .infinity)
              managementPanel
                .frame(width: 320)
            }
          } else {
            VStack(spacing: 18) {
              profileRail
              evaluationPanel
              managementPanel
            }
          }
        }
        .padding(28)
        .frame(maxWidth: 1220, alignment: .topLeading)
        .frame(maxWidth: .infinity)
      }
      .background(NativeHealthColor.background.ignoresSafeArea())
    }
    .alert("공유 리포트", isPresented: $showingShareReport) {
      Button("확인", role: .cancel) {}
    } message: {
      Text("\(selectedMember.name) 회원에게 전달할 요약 리포트 화면을 준비했습니다.")
    }
    .alert("회원 취소", isPresented: $showingMemberCancelConfirmation) {
      Button("닫기", role: .cancel) {}
      Button("회원 취소", role: .destructive) {
        cancelSelectedMember()
      }
    } message: {
      Text("\(selectedMember.name) 회원을 목록에서 제거하고 이 iPad에 저장된 SOAP 초안을 정리합니다.")
    }
    .sheet(isPresented: $showingMemberRegistration) {
      NativeMemberRegistrationSheet { member, initialDraft in
        members.append(member)
        NativeTrainerMember.persist(members)
        selectedMemberId = member.id
        if let initialDraft {
          let key = NativeSoapDraftStore.key(member: member, date: Date())
          soapDraftsByDay[key] = initialDraft
          NativeSoapDraftStore.persist(initialDraft, key: key)
        }
      }
    }
    .sheet(isPresented: $showingMemojiKeyboardPicker) {
      NativeMemojiKeyboardSelectionSheet { imageData in
        avatarPickerError = nil
        updateSelectedMemberAvatar(imageData)
      } onError: { message in
        avatarPickerError = message
      }
    }
    .sheet(isPresented: $showingPhotoPicker) {
      NativePhotoLibraryImagePicker { imageData in
        avatarPickerError = nil
        updateSelectedMemberAvatar(imageData)
      } onError: { message in
        avatarPickerError = message
      }
    }
    .sheet(isPresented: $showingContactImagePicker) {
      NativeContactImagePicker { imageData in
        avatarPickerError = nil
        updateSelectedMemberAvatar(imageData)
      } onError: { message in
        avatarPickerError = message
      }
    }
  }

  private var memberHeader: some View {
    HStack {
      VStack(alignment: .leading, spacing: 5) {
        Text("회원 프로필 / 평가")
          .font(.system(size: 30, weight: .bold, design: .rounded))
          .foregroundStyle(NativeHealthColor.primaryText)
        Text("통증 부위, 목표, ROM, 평가 결과, 세션 히스토리를 통합 관리합니다.")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(NativeHealthColor.secondaryText)
      }
      Spacer()
      Button {
        showingMemberRegistration = true
      } label: {
        Label("회원 등록", systemImage: "person.crop.circle.badge.plus")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(NativeHealthColor.blue)
          .padding(.horizontal, 15)
          .frame(height: 38)
          .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .stroke(NativeHealthColor.border, lineWidth: 1)
          )
      }
      .buttonStyle(.plain)
      Button(action: onOpenSoap) {
        Label("SOAP 작성", systemImage: "square.and.pencil")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(Color.white)
          .padding(.horizontal, 15)
          .frame(height: 38)
          .background(NativeHealthColor.blue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      }
      .buttonStyle(.plain)
    }
  }

  private var profileRail: some View {
    VStack(spacing: 14) {
      NativeHealthCard(padding: 16) {
        VStack(spacing: 12) {
          NativeMemojiAvatar(member: selectedMember, size: 86)
          VStack(spacing: 4) {
            Text(selectedMember.name)
              .font(.system(size: 22, weight: .bold, design: .rounded))
              .foregroundStyle(NativeHealthColor.primaryText)
            Text(selectedMember.subtitle)
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(NativeHealthColor.secondaryText)
          }
          NativeStatusCapsule(text: selectedMember.riskLabel, color: selectedMember.statusColor)

          Menu {
            Button {
              Task {
                await autoAssignSelectedMemberAvatar()
              }
            } label: {
              Label("자동 미모지 배정", systemImage: "wand.and.stars")
            }
            Button {
              showingMemojiKeyboardPicker = true
            } label: {
              Label("iOS 미모지 키보드에서 선택", systemImage: "face.smiling")
            }
            Button {
              showingContactImagePicker = true
            } label: {
              Label("연락처 미모지 가져오기", systemImage: "person.crop.circle")
            }
            Button {
              showingPhotoPicker = true
            } label: {
              Label("사진 보관함에서 선택", systemImage: "photo.on.rectangle")
            }
            if selectedMember.avatarImageData != nil {
              Divider()
              Button("프로필 사진 제거", role: .destructive) {
                updateSelectedMemberAvatar(nil)
              }
            }
          } label: {
            Label("프로필 사진 변경", systemImage: "person.crop.circle.badge.plus")
              .font(.system(size: 12, weight: .bold))
              .foregroundStyle(NativeHealthColor.blue)
              .padding(.horizontal, 12)
              .frame(height: 32)
              .background(NativeHealthColor.blue.opacity(0.10), in: Capsule())
          }
          .buttonStyle(.plain)
          .disabled(members.isEmpty || isResolvingAutomaticAvatar)

          if isResolvingAutomaticAvatar {
            HStack(spacing: 7) {
              ProgressView()
                .controlSize(.small)
              Text("자동 배정 중")
                .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(NativeHealthColor.secondaryText)
          }

          if let avatarPickerError {
            Text(avatarPickerError)
              .font(.system(size: 11, weight: .bold))
              .foregroundStyle(NativeHealthColor.red)
              .multilineTextAlignment(.center)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .frame(maxWidth: .infinity)
      }

      NativeHealthCard(padding: 10) {
        VStack(spacing: 4) {
          ForEach(members) { member in
            memberListButton(member)
          }
        }
      }
    }
  }

  private var evaluationPanel: some View {
    VStack(spacing: 18) {
      NativeHealthCard {
        HStack(alignment: .top, spacing: 18) {
          VStack(alignment: .leading, spacing: 12) {
            Text("통증 부위")
              .font(.system(size: 18, weight: .bold))
              .foregroundStyle(NativeHealthColor.primaryText)
            Text(selectedMember.displayBodyRegion)
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(NativeHealthColor.secondaryText)
            NativeBodyMapView(
              color: selectedMember.statusColor,
              selectedRegions: selectedMember.bodyRegionItems
            )
              .frame(height: 260)
          }
          .frame(maxWidth: .infinity)

          VStack(alignment: .leading, spacing: 14) {
            Text("통증 정도 (NPRS)")
              .font(.system(size: 18, weight: .bold))
              .foregroundStyle(NativeHealthColor.primaryText)
            NativePainScaleView(value: Int(selectedMember.pain) ?? 0)
            NativeChecklistRow(title: "S 주관 작성", checked: !selectedMember.subjective.trimmedForDisplay.isEmpty)
            NativeChecklistRow(title: "O 객관 작성", checked: !selectedMember.objective.trimmedForDisplay.isEmpty)
            NativeChecklistRow(title: "A 평가 작성", checked: !selectedMember.assessment.trimmedForDisplay.isEmpty)
            NativeChecklistRow(title: "P 계획 작성", checked: !selectedMember.plan.trimmedForDisplay.isEmpty)
          }
          .frame(width: 290)
        }
      }

      NativeBoardPanel(title: "초기 SOAP 기록", subtitle: "회원등록 때 작성한 내용만 표시합니다.") {
        VStack(alignment: .leading, spacing: 12) {
          if selectedMember.hasInitialSoap {
            NativeShareLine(title: "S. 주관적 정보", value: soapValue(selectedMember.subjective))
            Divider()
            NativeShareLine(title: "O. 객관적 정보", value: soapValue(selectedMember.objective))
            Divider()
            NativeShareLine(title: "A. 평가", value: soapValue(selectedMember.assessment))
            Divider()
            NativeShareLine(title: "P. 계획", value: soapValue(selectedMember.plan))
          } else {
            Text("아직 작성된 초기 SOAP 기록이 없습니다. SOAP 작성 버튼으로 회원 기록을 추가하세요.")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(NativeHealthColor.secondaryText)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }

      memberTimelinePanel
    }
  }

  private var managementPanel: some View {
    VStack(spacing: 18) {
      NativeBoardPanel(title: "관리 계획", subtitle: "초기 SOAP 기준") {
        VStack(alignment: .leading, spacing: 12) {
          NativeShareLine(title: "평가", value: soapValue(selectedMember.assessment))
          Divider()
          NativeShareLine(title: "계획", value: soapValue(selectedMember.plan))
          Divider()
          NativeReadinessRow(
            title: "SOAP 완성도",
            value: "\(selectedMember.soapCompletionPercent)%",
            progress: Double(selectedMember.soapCompletionPercent) / 100
          )
        }
      }

      NativeBoardPanel(title: "세션 히스토리", subtitle: "최근 기록") {
        VStack(spacing: 10) {
          if selectedMember.hasInitialSoap {
            NativeRiskItem(title: selectedMember.lastSoap, value: "회원등록 · 초기 SOAP", color: NativeHealthColor.blue)
          } else {
            Text("아직 세션 기록이 없습니다.")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(NativeHealthColor.secondaryText)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }

      Button {
        showingShareReport = true
      } label: {
        Label("공유 리포트", systemImage: "square.and.arrow.up")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(NativeHealthColor.blue)
          .frame(maxWidth: .infinity)
          .frame(height: 46)
          .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .stroke(NativeHealthColor.border, lineWidth: 1)
          )
      }
      .buttonStyle(.plain)

      Button {
        showingMemberCancelConfirmation = true
      } label: {
        Label("회원 취소", systemImage: "person.crop.circle.badge.xmark")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(NativeHealthColor.red)
          .frame(maxWidth: .infinity)
          .frame(height: 46)
          .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .stroke(NativeHealthColor.red.opacity(0.28), lineWidth: 1)
          )
      }
      .buttonStyle(.plain)
    }
  }

  private func soapValue(_ text: String) -> String {
    let trimmed = text.trimmedForDisplay
    return trimmed.isEmpty ? "작성 전" : trimmed
  }

  private var memberTimelinePanel: some View {
    let selectedDraft = draft(for: selectedMember, date: selectedMemberTimelineDate)
    return NativeBoardPanel(title: "날짜별 SOAP", subtitle: "작성한 날짜는 잔디처럼 진하게 표시됩니다.") {
      VStack(alignment: .leading, spacing: 14) {
        NativeMemberSoapGrassView(
          member: selectedMember,
          selectedDate: $selectedMemberTimelineDate,
          datesWithDrafts: datesWithDrafts(for: selectedMember)
        )

        Divider()

        HStack {
          Text(Self.memberTimelineDateFormatter.string(from: selectedMemberTimelineDate))
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(NativeHealthColor.primaryText)
          Spacer()
          if selectedDraft != nil {
            NativeStatusCapsule(text: "작성됨", color: NativeHealthColor.green)
          } else {
            NativeStatusCapsule(text: "기록 없음", color: NativeHealthColor.secondaryText)
          }
        }

        if let selectedDraft {
          NativeShareLine(title: "상태", value: "\(selectedDraft.bodyRegion.trimmedForDisplay.isEmpty ? selectedMember.displayBodyRegion : selectedDraft.bodyRegion) · 통증 \(Int(selectedDraft.painValue))/10")
          Divider()
          NativeShareLine(title: "S", value: soapValue(selectedDraft.subjective))
          Divider()
          NativeShareLine(title: "O", value: soapValue(selectedDraft.objective))
          Divider()
          NativeShareLine(title: "A", value: soapValue(selectedDraft.assessment))
          Divider()
          NativeShareLine(title: "P", value: soapValue(selectedDraft.plan))
        } else {
          Text("이 날짜에는 저장된 SOAP 노트가 없습니다.")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(NativeHealthColor.secondaryText)
        }
      }
    }
  }

  private var selectedTimelineDraftKey: String {
    NativeSoapDraftStore.key(member: selectedMember, date: selectedMemberTimelineDate)
  }

  private func draft(for member: NativeTrainerMember, date: Date) -> NativeSoapDailyDraft? {
    let key = NativeSoapDraftStore.key(member: member, date: date)
    return soapDraftsByDay[key] ?? NativeSoapDraftStore.load(key: key)
  }

  private func datesWithDrafts(for member: NativeTrainerMember) -> Set<Date> {
    var dates = NativeSoapDraftStore.datesWithDrafts(for: member)
    for key in soapDraftsByDay.keys where key.hasPrefix("\(member.avatarSeed)-") {
      guard let draft = soapDraftsByDay[key], draft.hasUserContent else {
        continue
      }
      let rawDate = String(key.dropFirst(member.avatarSeed.count + 1))
      if let date = Self.memberTimelineStorageDateFormatter.date(from: rawDate) {
        dates.insert(Calendar.current.startOfDay(for: date))
      }
    }
    return dates
  }

  private func cancelSelectedMember() {
    let member = selectedMember
    guard member.id != NativeTrainerMember.emptySelectionId else {
      return
    }

    members.removeAll { $0.id == member.id }
    NativeTrainerMember.persist(members)
    soapDraftsByDay = soapDraftsByDay.filter { !$0.key.hasPrefix("\(member.avatarSeed)-") }
    NativeSoapDraftStore.removeAll(for: member)
    selectedMemberId = members.first?.id ?? NativeTrainerMember.emptySelectionId
  }

  private func updateSelectedMemberAvatar(_ imageData: Data?) {
    guard let memberIndex = members.firstIndex(where: { $0.id == selectedMemberId }) else {
      return
    }

    members[memberIndex] = members[memberIndex].updatingAvatarImageData(imageData)
    NativeTrainerMember.persist(members)
  }

  @MainActor
  private func autoAssignSelectedMemberAvatar() async {
    guard !isResolvingAutomaticAvatar,
          selectedMember.id != NativeTrainerMember.emptySelectionId else {
      return
    }

    isResolvingAutomaticAvatar = true
    defer { isResolvingAutomaticAvatar = false }

    do {
      let imageData = try await NativeAutomaticMemojiAvatarProvider.avatarImageData(
        name: selectedMember.name,
        email: selectedMember.email
      )
      avatarPickerError = nil
      updateSelectedMemberAvatar(imageData)
    } catch {
      avatarPickerError = "자동 미모지 배정에 실패했습니다. 네트워크를 확인하세요."
    }
  }

  private static let memberTimelineDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "yyyy.MM.dd (E)"
    return formatter
  }()

  private static let memberTimelineStorageDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  private func memberListButton(_ member: NativeTrainerMember) -> some View {
    let isSelected = member.id == selectedMemberId
    return Button {
      selectedMemberId = member.id
    } label: {
      HStack(spacing: 10) {
        NativeMemojiAvatar(member: member, size: 34)
        VStack(alignment: .leading, spacing: 2) {
          Text(member.name)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(NativeHealthColor.primaryText)
          Text(member.riskLabel)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(member.statusColor)
        }
        Spacer()
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 9)
      .background(isSelected ? NativeHealthColor.blue.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private func assessmentRow(title: String, value: String, result: String, color: Color) -> some View {
    HStack {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(NativeHealthColor.primaryText)
        Text(result)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(NativeHealthColor.secondaryText)
      }
      Spacer()
      Text(value)
        .font(.system(size: 15, weight: .bold, design: .rounded))
        .foregroundStyle(color)
    }
    .padding(.vertical, 12)
  }
}

private struct NativeMemberRegistrationSheet: View {
  let onSave: (NativeTrainerMember, NativeSoapDailyDraft?) -> Void

  @Environment(\.dismiss) private var dismiss
  @FocusState private var isTextInputFocused: Bool
  @State private var name = ""
  @State private var email = ""
  @State private var program = ""
  @State private var selectedBodyRegions: [String] = []
  @State private var pain = 0.0
  @State private var selectedSoap = "S"
  @State private var subjective = ""
  @State private var objective = ""
  @State private var assessment = ""
  @State private var plan = ""
  @State private var showValidation = false
  @State private var avatarImageData: Data?
  @State private var showingMemojiKeyboardPicker = false
  @State private var showingPhotoPicker = false
  @State private var showingContactImagePicker = false
  @State private var avatarPickerError: String?
  @State private var isResolvingAutomaticAvatar = false

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          VStack(alignment: .leading, spacing: 6) {
            Text("회원등록")
              .font(.system(size: 30, weight: .bold, design: .rounded))
              .foregroundStyle(NativeHealthColor.primaryText)
            Text("회원 기본정보와 첫 SOAP 기록을 같은 흐름으로 작성합니다.")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(NativeHealthColor.secondaryText)
          }

          avatarPickerCard

	          NativeHealthCard {
	            VStack(alignment: .leading, spacing: 14) {
	              registrationField("회원명", text: $name, placeholder: "예: 김회원", textContentType: .name)
	              registrationField("이메일", text: $email, placeholder: "member@email.com", keyboardType: .emailAddress, textContentType: .emailAddress)
	              programPicker
	              bodyRegionPicker

	              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text("초기 통증")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(NativeHealthColor.primaryText)
                  Spacer()
                  Text("\(Int(pain))/10")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(NativeTrainerMember.riskColor(forPain: Int(pain)))
                }
                Slider(value: $pain, in: 0...10, step: 1)
                  .tint(NativeTrainerMember.riskColor(forPain: Int(pain)))
              }
            }
          }

          VStack(alignment: .leading, spacing: 12) {
            HStack {
              Text("초기 SOAP")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(NativeHealthColor.primaryText)
              Spacer()
              NativeStatusCapsule(text: "SOAP \(soapCompletionPercent)%", color: soapCompletionPercent >= 75 ? NativeHealthColor.green : NativeHealthColor.orange)
            }

            NativeSegmentedPicker(values: ["Subjective", "Objective", "Assessment", "Plan"], selection: selectedSoapLabel)

            selectedRegistrationSoapEditor

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
              NativeSoapStepCard(title: "S", caption: "주관", value: subjective.trimmedForDisplay.isEmpty ? "비어 있음" : "작성됨", color: NativeHealthColor.blue)
              NativeSoapStepCard(title: "O", caption: "객관", value: objective.trimmedForDisplay.isEmpty ? "비어 있음" : "작성됨", color: NativeHealthColor.orange)
              NativeSoapStepCard(title: "A", caption: "평가", value: assessment.trimmedForDisplay.isEmpty ? "비어 있음" : "작성됨", color: NativeHealthColor.red)
              NativeSoapStepCard(title: "P", caption: "계획", value: plan.trimmedForDisplay.isEmpty ? "비어 있음" : "작성됨", color: NativeHealthColor.green)
            }
          }

          if showValidation {
            Text("회원명은 필수입니다.")
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(NativeHealthColor.red)
          }
        }
        .padding(24)
      }
      .background(NativeHealthColor.background.ignoresSafeArea())
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("취소") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("저장") {
            Task {
              await save()
            }
          }
          .font(.system(size: 16, weight: .bold))
          .disabled(isResolvingAutomaticAvatar)
        }
      }
      .sheet(isPresented: $showingMemojiKeyboardPicker) {
        NativeMemojiKeyboardSelectionSheet { imageData in
          avatarPickerError = nil
          avatarImageData = imageData
        } onError: { message in
          avatarPickerError = message
        }
      }
      .sheet(isPresented: $showingPhotoPicker) {
        NativePhotoLibraryImagePicker { imageData in
          avatarPickerError = nil
          avatarImageData = imageData
        } onError: { message in
          avatarPickerError = message
        }
      }
      .sheet(isPresented: $showingContactImagePicker) {
        NativeContactImagePicker { imageData in
          avatarPickerError = nil
          avatarImageData = imageData
        } onError: { message in
          avatarPickerError = message
        }
      }
    }
  }

  private var avatarPickerCard: some View {
    NativeHealthCard {
      HStack(spacing: 16) {
        NativeAvatarImageDataView(
          imageData: avatarImageData,
          fallbackName: name.trimmedForDisplay.isEmpty ? "회원" : name.trimmedForDisplay,
          fallbackSeed: "registration-\(name)"
        )
        .frame(width: 74, height: 74)
        .clipShape(Circle())
        .overlay(
          Circle()
            .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )

        VStack(alignment: .leading, spacing: 8) {
          Text("iOS 미모지 프로필")
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(NativeHealthColor.primaryText)
          Text("연락처에 설정한 Memoji 또는 사진 앱에 저장한 Memoji 이미지를 가져옵니다.")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(NativeHealthColor.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
          if let avatarPickerError {
            Text(avatarPickerError)
              .font(.system(size: 12, weight: .bold))
              .foregroundStyle(NativeHealthColor.red)
              .fixedSize(horizontal: false, vertical: true)
          }
          if isResolvingAutomaticAvatar {
            HStack(spacing: 7) {
              ProgressView()
                .controlSize(.small)
              Text("자동 미모지 배정 중")
                .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(NativeHealthColor.secondaryText)
          }
        }

        Spacer(minLength: 8)

        Menu {
          Button {
            Task {
              await autoAssignAvatarForRegistration()
            }
          } label: {
            Label("자동 미모지 배정", systemImage: "wand.and.stars")
          }
          Button {
            showingMemojiKeyboardPicker = true
          } label: {
            Label("iOS 미모지 키보드에서 선택", systemImage: "face.smiling")
          }
          Button {
            showingContactImagePicker = true
          } label: {
            Label("연락처 미모지 가져오기", systemImage: "person.crop.circle")
          }
          Button {
            showingPhotoPicker = true
          } label: {
            Label("사진 보관함에서 선택", systemImage: "photo.on.rectangle")
          }
          if avatarImageData != nil {
            Divider()
            Button("프로필 사진 제거", role: .destructive) {
              avatarImageData = nil
            }
          }
        } label: {
          Label("선택", systemImage: "plus.circle")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(NativeHealthColor.blue)
            .padding(.horizontal, 13)
            .frame(height: 36)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
              RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NativeHealthColor.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isResolvingAutomaticAvatar)
      }
    }
  }

  private var selectedSoapLabel: Binding<String> {
    Binding(
      get: {
        switch selectedSoap {
        case "O": return "Objective"
        case "A": return "Assessment"
        case "P": return "Plan"
        default: return "Subjective"
        }
      },
      set: { value in
        switch value {
        case "Objective": selectedSoap = "O"
        case "Assessment": selectedSoap = "A"
        case "Plan": selectedSoap = "P"
        default: selectedSoap = "S"
        }
      }
    )
  }

  @ViewBuilder
  private var selectedRegistrationSoapEditor: some View {
    switch selectedSoap {
    case "O":
      NativeSoapTextBox(
        title: "O. 객관적 정보",
        subtitle: "관찰, ROM, MMT, 테스트 결과를 적습니다.",
        placeholder: "예: SLR 68도, hip hinge 제한, 우측 둔근 활성 저하",
        accent: NativeHealthColor.orange,
        text: $objective,
        focused: $isTextInputFocused
      )
    case "A":
      NativeSoapTextBox(
        title: "A. 평가",
        subtitle: "문제 목록, 판단, 위험도, 목표를 적습니다.",
        placeholder: "예: 요추 과신전 보상과 둔근 약화가 동반된 움직임 패턴",
        accent: NativeHealthColor.red,
        text: $assessment,
        focused: $isTextInputFocused
      )
    case "P":
      NativeSoapTextBox(
        title: "P. 계획",
        subtitle: "세션 계획, 홈운동, 다음 재평가를 적습니다.",
        placeholder: "예: dead bug 2세트, hip hinge 드릴, 다음 세션 ROM 재확인",
        accent: NativeHealthColor.green,
        text: $plan,
        focused: $isTextInputFocused
      )
    default:
      NativeSoapTextBox(
        title: "S. 주관적 정보",
        subtitle: "주호소, 통증 양상, 악화/완화 요인을 적습니다.",
        placeholder: "예: 스쿼트 하강 구간에서 허리 불편감",
        accent: NativeHealthColor.blue,
        text: $subjective,
        focused: $isTextInputFocused
      )
    }
  }

  private var soapCompletionPercent: Int {
    let completed = [subjective, objective, assessment, plan]
      .filter { !$0.trimmedForDisplay.isEmpty }
      .count
    return Int((Double(completed) / 4.0) * 100)
  }

  private var programOptions: [String] {
    ["통증 관리", "자세 교정", "재활 트레이닝", "근력 강화", "체형 교정", "컨디셔닝", "퍼포먼스", "홈운동 관리"]
  }

  private var bodyRegionGroups: [(String, [String])] {
    NativePainBodyRegionCatalog.groups
  }

  private var normalizedBodyRegions: String {
    selectedBodyRegions.map { $0.trimmedForDisplay }.filter { !$0.isEmpty }.joined(separator: " · ")
  }

  private var programPicker: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text("프로그램")
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(NativeHealthColor.secondaryText)

      Menu {
        ForEach(programOptions, id: \.self) { option in
          Button {
            program = option
          } label: {
            Label(option, systemImage: program == option ? "checkmark" : "circle")
          }
        }
        if !program.isEmpty {
          Divider()
          Button("선택 해제", role: .destructive) {
            program = ""
          }
        }
      } label: {
        HStack {
          Text(program.isEmpty ? "프로그램 선택" : program)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(program.isEmpty ? NativeHealthColor.secondaryText.opacity(0.72) : NativeHealthColor.primaryText)
          Spacer()
          Image(systemName: "chevron.down")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(NativeHealthColor.secondaryText)
        }
        .padding(.horizontal, 13)
        .frame(height: 46)
        .background(NativeHealthColor.subPanel, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 13, style: .continuous)
            .stroke(NativeHealthColor.border, lineWidth: 1)
        )
      }
      .buttonStyle(.plain)
    }
  }

  private var bodyRegionPicker: some View {
    VStack(alignment: .leading, spacing: 9) {
      Text("부위")
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(NativeHealthColor.secondaryText)

      Menu {
        ForEach(bodyRegionGroups, id: \.0) { group in
          Menu(group.0) {
            Button {
              toggleBodyRegion(group.0)
            } label: {
              Label(group.0, systemImage: selectedBodyRegions.contains(group.0) ? "checkmark.circle.fill" : "circle")
            }

            Divider()

            ForEach(group.1, id: \.self) { region in
              let regionTitle = "\(group.0) > \(region)"
              Button {
                toggleBodyRegion(regionTitle)
              } label: {
                Label(region, systemImage: selectedBodyRegions.contains(regionTitle) ? "checkmark.circle.fill" : "circle")
              }
            }
          }
        }
        if !selectedBodyRegions.isEmpty {
          Divider()
          Button("전체 해제", role: .destructive) {
            selectedBodyRegions.removeAll()
          }
        }
      } label: {
        HStack {
          Text(selectedBodyRegions.isEmpty ? "부위 선택" : "\(selectedBodyRegions.count)개 선택")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(selectedBodyRegions.isEmpty ? NativeHealthColor.secondaryText.opacity(0.72) : NativeHealthColor.primaryText)
          Spacer()
          Image(systemName: "chevron.down")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(NativeHealthColor.secondaryText)
        }
        .padding(.horizontal, 13)
        .frame(height: 46)
        .background(NativeHealthColor.subPanel, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 13, style: .continuous)
            .stroke(NativeHealthColor.border, lineWidth: 1)
        )
      }
      .buttonStyle(.plain)

      if !selectedBodyRegions.isEmpty {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 8)], alignment: .leading, spacing: 8) {
          ForEach(selectedBodyRegions, id: \.self) { region in
            Button {
              toggleBodyRegion(region)
            } label: {
              HStack(spacing: 6) {
                Text(region.replacingOccurrences(of: " > ", with: " / "))
                  .font(.system(size: 12, weight: .bold))
                Image(systemName: "xmark")
                  .font(.system(size: 9, weight: .bold))
              }
              .foregroundStyle(NativeHealthColor.blue)
              .padding(.horizontal, 10)
              .frame(height: 30)
              .background(NativeHealthColor.blue.opacity(0.10), in: Capsule())
              .overlay(
                Capsule()
                  .stroke(NativeHealthColor.blue.opacity(0.18), lineWidth: 1)
              )
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }

  private func toggleBodyRegion(_ region: String) {
    if selectedBodyRegions.contains(region) {
      selectedBodyRegions.removeAll { $0 == region }
    } else {
      selectedBodyRegions.append(region)
    }
  }

  private func registrationField(
    _ title: String,
    text: Binding<String>,
    placeholder: String,
    keyboardType: UIKeyboardType = .default,
    textContentType: UITextContentType? = nil
  ) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(title)
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(NativeHealthColor.secondaryText)
      NativeCompositionSafeTextField(
        placeholder: placeholder,
        text: text,
        keyboardType: keyboardType,
        textContentType: textContentType
      )
        .padding(.horizontal, 13)
        .frame(height: 46)
        .background(NativeHealthColor.subPanel, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 13, style: .continuous)
            .stroke(NativeHealthColor.border, lineWidth: 1)
        )
    }
  }

  @MainActor
  private func save() async {
    let trimmedName = name.trimmedForDisplay
    guard !trimmedName.isEmpty else {
      showValidation = true
      return
    }

    let normalizedProgram = program.trimmedForDisplay
    let normalizedBodyRegion = normalizedBodyRegions
    let normalizedSubjective = subjective.trimmedForDisplay
    let normalizedObjective = objective.trimmedForDisplay
    let normalizedAssessment = assessment.trimmedForDisplay
    let normalizedPlan = plan.trimmedForDisplay
    let resolvedAvatarImageData = await resolvedAvatarImageDataForSave(
      name: trimmedName,
      email: email.trimmingCharacters(in: .whitespacesAndNewlines)
    )

    let member = NativeTrainerMember.registeredFromSoap(
      name: trimmedName,
      email: email.trimmingCharacters(in: .whitespacesAndNewlines),
      program: normalizedProgram,
      bodyRegion: normalizedBodyRegion,
      pain: Int(pain),
      subjective: normalizedSubjective,
      objective: normalizedObjective,
      assessment: normalizedAssessment,
      plan: normalizedPlan,
      avatarImageData: resolvedAvatarImageData
    )

    let hasInitialSoap = [normalizedSubjective, normalizedObjective, normalizedAssessment, normalizedPlan]
      .contains { !$0.isEmpty }
    let initialDraft = hasInitialSoap ? NativeSoapDailyDraft(
      drawing: PKDrawing(),
      painValue: pain,
      riskLevel: member.riskLabel,
      bodyRegion: normalizedBodyRegion,
      subjective: normalizedSubjective,
      objective: normalizedObjective,
      assessment: normalizedAssessment,
      plan: normalizedPlan,
      romEntries: [],
      mmtEntries: []
    ) : nil

    onSave(member, initialDraft)
    dismiss()
  }

  @MainActor
  private func autoAssignAvatarForRegistration() async {
    let trimmedName = name.trimmedForDisplay
    guard !isResolvingAutomaticAvatar else {
      return
    }
    guard !trimmedName.isEmpty else {
      showValidation = true
      avatarPickerError = "자동 배정하려면 회원명을 먼저 입력하세요."
      return
    }

    isResolvingAutomaticAvatar = true
    defer { isResolvingAutomaticAvatar = false }

    do {
      avatarImageData = try await NativeAutomaticMemojiAvatarProvider.avatarImageData(
        name: trimmedName,
        email: email.trimmingCharacters(in: .whitespacesAndNewlines)
      )
      avatarPickerError = nil
    } catch {
      avatarPickerError = "자동 미모지 배정에 실패했습니다. 네트워크를 확인하세요."
    }
  }

  @MainActor
  private func resolvedAvatarImageDataForSave(name: String, email: String) async -> Data? {
    if let avatarImageData {
      return avatarImageData
    }
    guard !isResolvingAutomaticAvatar else {
      return nil
    }

    isResolvingAutomaticAvatar = true
    defer { isResolvingAutomaticAvatar = false }

    do {
      let imageData = try await NativeAutomaticMemojiAvatarProvider.avatarImageData(
        name: name,
        email: email
      )
      avatarPickerError = nil
      avatarImageData = imageData
      return imageData
    } catch {
      avatarPickerError = "자동 미모지 배정에 실패해 기본 아바타로 저장했습니다."
      return nil
    }
  }
}

private struct NativeCompositionSafeTextField: UIViewRepresentable {
  let placeholder: String
  @Binding var text: String
  var keyboardType: UIKeyboardType = .default
  var textContentType: UITextContentType?

  func makeUIView(context: Context) -> UITextField {
    let textField = UITextField(frame: .zero)
    textField.delegate = context.coordinator
    textField.borderStyle = .none
    textField.backgroundColor = .clear
    textField.keyboardType = keyboardType
    textField.textContentType = textContentType
    textField.autocorrectionType = .no
    textField.spellCheckingType = .no
    textField.autocapitalizationType = .none
    textField.returnKeyType = .done
    textField.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
    textField.textColor = UIColor(hex: 0x12213D)
    textField.tintColor = UIColor(hex: 0x2856B8)
    textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)
    applyPlaceholder(to: textField)
    return textField
  }

  func updateUIView(_ uiView: UITextField, context: Context) {
    uiView.keyboardType = keyboardType
    uiView.textContentType = textContentType
    uiView.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
    uiView.textColor = UIColor(hex: 0x12213D)
    uiView.tintColor = UIColor(hex: 0x2856B8)
    applyPlaceholder(to: uiView)

    if uiView.markedTextRange == nil {
      let composedText = NativeHangulComposer.compose(text)
      if uiView.text != composedText {
        uiView.text = composedText
      }
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text)
  }

  private func applyPlaceholder(to textField: UITextField) {
    textField.attributedPlaceholder = NSAttributedString(
      string: placeholder,
      attributes: [
        .foregroundColor: UIColor(hex: 0x657089).withAlphaComponent(0.66),
        .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
      ]
    )
  }

  final class Coordinator: NSObject, UITextFieldDelegate {
    private var text: Binding<String>

    init(text: Binding<String>) {
      self.text = text
    }

    @objc func textDidChange(_ textField: UITextField) {
      guard textField.markedTextRange == nil else {
        return
      }
      let composedText = NativeHangulComposer.compose(textField.text ?? "")
      if textField.text != composedText {
        textField.text = composedText
      }
      text.wrappedValue = composedText
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
      let composedText = NativeHangulComposer.compose(textField.text ?? "")
      if textField.text != composedText {
        textField.text = composedText
      }
      text.wrappedValue = composedText
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
      textField.resignFirstResponder()
      return true
    }
  }
}

private enum NativeHangulComposer {
  private static let leadingJamo = [
    "ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ",
  ]

  private static let medialJamo = [
    "ㅏ", "ㅐ", "ㅑ", "ㅒ", "ㅓ", "ㅔ", "ㅕ", "ㅖ", "ㅗ", "ㅘ", "ㅙ", "ㅚ", "ㅛ", "ㅜ", "ㅝ", "ㅞ", "ㅟ", "ㅠ", "ㅡ", "ㅢ", "ㅣ",
  ]

  private static let trailingJamo = [
    "", "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ", "ㄺ", "ㄻ", "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ",
    "ㅁ", "ㅂ", "ㅄ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ",
  ]

  private static let leading: [String: Int] = [
    "ㄱ": 0, "ㄲ": 1, "ㄴ": 2, "ㄷ": 3, "ㄸ": 4, "ㄹ": 5, "ㅁ": 6, "ㅂ": 7, "ㅃ": 8,
    "ㅅ": 9, "ㅆ": 10, "ㅇ": 11, "ㅈ": 12, "ㅉ": 13, "ㅊ": 14, "ㅋ": 15, "ㅌ": 16,
    "ㅍ": 17, "ㅎ": 18,
  ]

  private static let medial: [String: Int] = [
    "ㅏ": 0, "ㅐ": 1, "ㅑ": 2, "ㅒ": 3, "ㅓ": 4, "ㅔ": 5, "ㅕ": 6, "ㅖ": 7,
    "ㅗ": 8, "ㅘ": 9, "ㅙ": 10, "ㅚ": 11, "ㅛ": 12, "ㅜ": 13, "ㅝ": 14,
    "ㅞ": 15, "ㅟ": 16, "ㅠ": 17, "ㅡ": 18, "ㅢ": 19, "ㅣ": 20,
  ]

  private static let trailing: [String: Int] = [
    "ㄱ": 1, "ㄲ": 2, "ㄳ": 3, "ㄴ": 4, "ㄵ": 5, "ㄶ": 6, "ㄷ": 7, "ㄹ": 8,
    "ㄺ": 9, "ㄻ": 10, "ㄼ": 11, "ㄽ": 12, "ㄾ": 13, "ㄿ": 14, "ㅀ": 15,
    "ㅁ": 16, "ㅂ": 17, "ㅄ": 18, "ㅅ": 19, "ㅆ": 20, "ㅇ": 21, "ㅈ": 22,
    "ㅊ": 23, "ㅋ": 24, "ㅌ": 25, "ㅍ": 26, "ㅎ": 27,
  ]

  private static let vowelCombinations: [String: String] = [
    "ㅗㅏ": "ㅘ", "ㅗㅐ": "ㅙ", "ㅗㅣ": "ㅚ",
    "ㅜㅓ": "ㅝ", "ㅜㅔ": "ㅞ", "ㅜㅣ": "ㅟ",
    "ㅡㅣ": "ㅢ",
  ]

  private static let trailingCombinations: [String: String] = [
    "ㄱㅅ": "ㄳ", "ㄴㅈ": "ㄵ", "ㄴㅎ": "ㄶ",
    "ㄹㄱ": "ㄺ", "ㄹㅁ": "ㄻ", "ㄹㅂ": "ㄼ", "ㄹㅅ": "ㄽ", "ㄹㅌ": "ㄾ", "ㄹㅍ": "ㄿ", "ㄹㅎ": "ㅀ",
    "ㅂㅅ": "ㅄ",
  ]

  static func compose(_ source: String) -> String {
    guard !source.isEmpty else {
      return source
    }

    let tokens = expandHangulSyllables(source).map(String.init)
    var result = ""
    var index = 0

    while index < tokens.count {
      guard let leadingIndex = leading[tokens[index]],
            index + 1 < tokens.count else {
        result += tokens[index]
        index += 1
        continue
      }

      var vowelToken = tokens[index + 1]
      var afterVowelIndex = index + 2

      if afterVowelIndex < tokens.count,
         let combinedVowel = vowelCombinations[vowelToken + tokens[afterVowelIndex]] {
        vowelToken = combinedVowel
        afterVowelIndex += 1
      }

      guard let medialIndex = medial[vowelToken] else {
        result += tokens[index]
        index += 1
        continue
      }

      var trailingIndex = 0
      var nextIndex = afterVowelIndex

      if nextIndex < tokens.count,
         let singleTrailingIndex = trailing[tokens[nextIndex]] {
        let firstTrailingToken = tokens[nextIndex]
        let followingIndex = nextIndex + 1
        let followingIsVowel = followingIndex < tokens.count && medial[tokens[followingIndex]] != nil

        if !followingIsVowel {
          if followingIndex < tokens.count,
             let combinedTrailing = trailingCombinations[firstTrailingToken + tokens[followingIndex]],
             let combinedTrailingIndex = trailing[combinedTrailing] {
            let afterCombinedIndex = followingIndex + 1
            let afterCombinedIsVowel = afterCombinedIndex < tokens.count && medial[tokens[afterCombinedIndex]] != nil

            if afterCombinedIsVowel {
              trailingIndex = singleTrailingIndex
              nextIndex += 1
            } else {
              trailingIndex = combinedTrailingIndex
              nextIndex += 2
            }
          } else {
            trailingIndex = singleTrailingIndex
            nextIndex += 1
          }
        }
      }

      let scalarValue = 0xAC00 + ((leadingIndex * 21) + medialIndex) * 28 + trailingIndex
      if let scalar = UnicodeScalar(UInt32(scalarValue)) {
        result += String(scalar)
      }
      index = nextIndex
    }

    return result
  }

  private static func expandHangulSyllables(_ source: String) -> String {
    var expanded = ""

    for scalar in source.unicodeScalars {
      let value = scalar.value
      guard (0xAC00...0xD7A3).contains(value) else {
        expanded += String(scalar)
        continue
      }

      let syllableIndex = Int(value - 0xAC00)
      let leadingIndex = syllableIndex / (21 * 28)
      let medialIndex = (syllableIndex % (21 * 28)) / 28
      let trailingIndex = syllableIndex % 28

      expanded += leadingJamo[leadingIndex]
      expanded += medialJamo[medialIndex]
      if trailingIndex > 0 {
        expanded += trailingJamo[trailingIndex]
      }
    }

    return expanded
  }
}

private extension String {
  var trimmedForDisplay: String {
    NativeHangulComposer.compose(self).trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

private struct NativeSoapDailyDraft {
  var drawing: PKDrawing
  var painValue: Double
  var riskLevel: String
  var bodyRegion: String
  var subjective: String
  var objective: String
  var assessment: String
  var plan: String
  var romEntries: [String]
  var mmtEntries: [String]

  var hasUserContent: Bool {
    if !drawing.bounds.isNull, !drawing.bounds.isEmpty {
      return true
    }
    if ![subjective, objective, assessment, plan]
      .allSatisfy({ $0.trimmedForDisplay.isEmpty }) {
      return true
    }
    return !romEntries.isEmpty || !mmtEntries.isEmpty
  }

  static func blank(member: NativeTrainerMember) -> NativeSoapDailyDraft {
    NativeSoapDailyDraft(
      drawing: PKDrawing(),
      painValue: Double(Int(member.pain) ?? 0),
      riskLevel: member.riskLabel,
      bodyRegion: NativeSoapDailyDraft.defaultBodyRegion(for: member),
      subjective: "",
      objective: "",
      assessment: "",
      plan: "",
      romEntries: [],
      mmtEntries: []
    )
  }

  private static func defaultBodyRegion(for member: NativeTrainerMember) -> String {
    if !member.bodyRegion.trimmedForDisplay.isEmpty {
      return member.bodyRegion.trimmedForDisplay
    }
    if member.subtitle.contains("무릎") {
      return "무릎"
    }
    if member.subtitle.contains("어깨") {
      return "어깨"
    }
    return "허리"
  }
}

private struct NativeSoapDailyDraftPayload: Codable {
  let drawingData: Data
  let painValue: Double
  let riskLevel: String
  let bodyRegion: String
  let subjective: String
  let objective: String
  let assessment: String
  let plan: String
  let romEntries: [String]
  let mmtEntries: [String]
}

private extension NativeSoapDailyDraft {
  func encodedData() -> Data? {
    let payload = NativeSoapDailyDraftPayload(
      drawingData: drawing.dataRepresentation(),
      painValue: painValue,
      riskLevel: riskLevel,
      bodyRegion: bodyRegion,
      subjective: subjective,
      objective: objective,
      assessment: assessment,
      plan: plan,
      romEntries: romEntries,
      mmtEntries: mmtEntries
    )
    return try? JSONEncoder().encode(payload)
  }

  init?(encodedData data: Data) {
    guard let payload = try? JSONDecoder().decode(NativeSoapDailyDraftPayload.self, from: data) else {
      return nil
    }

    let decodedDrawing = (try? PKDrawing(data: payload.drawingData)) ?? PKDrawing()
    self = NativeSoapDailyDraft(
      drawing: decodedDrawing,
      painValue: payload.painValue,
      riskLevel: payload.riskLevel,
      bodyRegion: payload.bodyRegion,
      subjective: payload.subjective,
      objective: payload.objective,
      assessment: payload.assessment,
      plan: payload.plan,
      romEntries: payload.romEntries,
      mmtEntries: payload.mmtEntries
    )
  }
}

private enum NativeSoapDraftStore {
  private static let storagePrefix = "DFETNativeSoapDraft."

  private static let storageDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  static func key(member: NativeTrainerMember, date: Date) -> String {
    "\(member.avatarSeed)-\(storageDateFormatter.string(from: Calendar.current.startOfDay(for: date)))"
  }

  static func persist(_ draft: NativeSoapDailyDraft, key: String) {
    guard draft.hasUserContent else {
      UserDefaults.standard.removeObject(forKey: storagePrefix + key)
      return
    }

    guard let data = draft.encodedData() else {
      return
    }
    UserDefaults.standard.set(data, forKey: storagePrefix + key)
  }

  static func load(key: String) -> NativeSoapDailyDraft? {
    guard let data = UserDefaults.standard.data(forKey: storagePrefix + key) else {
      return nil
    }
    return NativeSoapDailyDraft(encodedData: data)
  }

  static func datesWithDrafts(for member: NativeTrainerMember) -> Set<Date> {
    let prefix = storagePrefix + member.avatarSeed + "-"
    let dates = UserDefaults.standard.dictionaryRepresentation().keys.compactMap { key -> Date? in
      guard key.hasPrefix(prefix) else {
        return nil
      }
      if let data = UserDefaults.standard.data(forKey: key),
         let draft = NativeSoapDailyDraft(encodedData: data),
         !draft.hasUserContent {
        return nil
      }
      let dateString = String(key.dropFirst(prefix.count))
      return storageDateFormatter.date(from: dateString)
    }
    return Set(dates.map { Calendar.current.startOfDay(for: $0) })
  }

  static func removeAll(for member: NativeTrainerMember) {
    let memberPrefix = storagePrefix + member.avatarSeed + "-"
    for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix(memberPrefix) {
      UserDefaults.standard.removeObject(forKey: key)
    }
  }
}

private struct NativeTrainerSoapDetail: View {
  @Binding var selectedMemberId: NativeTrainerMember.ID
  let members: [NativeTrainerMember]
  @Binding var requestedMode: String
  @Binding var soapDraftsByDay: [String: NativeSoapDailyDraft]
  let onSyncSoap: ([String: Any], @escaping (Bool) -> Void) -> Void
  @FocusState private var isTextInputFocused: Bool
  @State private var selectedMode = "SOAP"
  @State private var selectedSoap = "S"
  @State private var selectedSoapDate = Calendar.current.startOfDay(for: Date())
  @State private var activeDraftKey = ""
  @State private var selectedTool = "pen"
  @State private var undoSignal = 0
  @State private var drawing = PKDrawing()
  @State private var saveStatus = "저장됨"
  @State private var isLoadingDraft = false
  @State private var keyboardHeight: CGFloat = 0
  @State private var isKeyboardPresented = false
  @State private var painValue = 0.0
  @State private var riskLevel = "안정"
  @State private var bodyRegion = ""
  @State private var subjective = ""
  @State private var objective = ""
  @State private var assessment = ""
  @State private var plan = ""
  @State private var romEntries: [String] = []
  @State private var mmtEntries: [String] = []

  private var analytics: NativeSoapAnalytics {
    NativeSoapAnalytics(members: members, soapDraftsByDay: soapDraftsByDay)
  }

  private var selectedMemberPoints: [NativeSoapAnalytics.DailyPoint] {
    analytics.pointsForMember(selectedMember)
  }

  private static let draftStoragePrefix = "DFETNativeSoapDraft."

  private var selectedMember: NativeTrainerMember {
    members.first(where: { $0.id == selectedMemberId }) ?? NativeTrainerMember.emptyMember
  }

  var body: some View {
    GeometryReader { geometry in
      if members.isEmpty {
        VStack {
          NativeEmptyState(
            title: "SOAP를 작성할 회원이 없습니다",
            message: "회원을 먼저 연결하면 날짜별 SOAP 타임라인에서 기록을 작성할 수 있습니다.",
            symbol: "doc.text.magnifyingglass"
          )
          .frame(maxWidth: 560)
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
      } else {
        soapWorkspace
          .frame(width: geometry.size.width, height: geometry.size.height)
      }
    }
    .background(NativeHealthColor.background)
    .onAppear {
      activeDraftKey = draftKey(member: selectedMember, date: selectedSoapDate)
      loadActiveDraft()
      applyRequestedMode()
    }
    .onDisappear {
      persistCurrentDraft()
      dismissKeyboard()
    }
    .onChange(of: selectedMemberId) { _ in
      persistCurrentDraft()
      activeDraftKey = draftKey(member: selectedMember, date: selectedSoapDate)
      loadActiveDraft()
    }
    .onChange(of: requestedMode) { _ in
      applyRequestedMode()
    }
    .onChange(of: selectedMode) { mode in
      persistCurrentDraft()
      if mode != "SOAP" {
        dismissKeyboard()
      }
    }
    .onChange(of: drawing) { _ in markDraftNeedsSave() }
    .onChange(of: painValue) { _ in markDraftNeedsSave() }
    .onChange(of: riskLevel) { _ in markDraftNeedsSave() }
    .onChange(of: bodyRegion) { _ in markDraftNeedsSave() }
    .onChange(of: subjective) { _ in markDraftNeedsSave() }
    .onChange(of: objective) { _ in markDraftNeedsSave() }
    .onChange(of: assessment) { _ in markDraftNeedsSave() }
    .onChange(of: plan) { _ in markDraftNeedsSave() }
    .onChange(of: romEntries) { _ in markDraftNeedsSave() }
    .onChange(of: mmtEntries) { _ in markDraftNeedsSave() }
    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
      updateKeyboardHeight(from: notification)
    }
    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
      updateKeyboardHeight(from: notification, forceHidden: true)
    }
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("완료") {
          dismissKeyboard()
        }
      }
    }
  }

  private var selectedSoapDateBinding: Binding<Date> {
    Binding(
      get: { selectedSoapDate },
      set: { newDate in
        setSoapDate(newDate)
      }
    )
  }

  private var selectedDateTitle: String {
    Self.longDateFormatter.string(from: selectedSoapDate)
  }

  private var keyboardBottomInset: CGFloat {
    guard isKeyboardLayoutActive else {
      return 0
    }
    return keyboardHeight > 0 ? keyboardHeight : 0
  }

  private var isKeyboardLayoutActive: Bool {
    selectedMode == "SOAP" && (isTextInputFocused || isKeyboardPresented || keyboardHeight > 0)
  }

  private var completionPercent: Int {
    var completed = 0
    if !subjective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { completed += 1 }
    if !objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !romEntries.isEmpty || !mmtEntries.isEmpty { completed += 1 }
    if !assessment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { completed += 1 }
    if !plan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { completed += 1 }
    return Int((Double(completed) / 4.0 * 100).rounded())
  }

  private var riskColor: Color {
    switch riskLevel {
    case "고위험":
      return NativeHealthColor.red
    case "주의", "재평가":
      return NativeHealthColor.orange
    default:
      return NativeHealthColor.green
    }
  }

  private var saveStatusLabel: String {
    switch saveStatus {
    case "서버 동기화됨":
      return "서버 동기화됨"
    case "서버 동기화 중":
      return "서버 동기화 중"
    case "저장됨":
      return "로컬 저장됨"
    case "저장 중":
      return "저장 중"
    case "저장 실패":
      return "저장 실패"
    case "기록 없음":
      return "기록 없음"
    default:
      return "저장 필요"
    }
  }

  private var saveStatusColor: Color {
    switch saveStatus {
    case "서버 동기화됨":
      return NativeHealthColor.green
    case "서버 동기화 중":
      return NativeHealthColor.blue
    case "저장됨":
      return NativeHealthColor.green
    case "저장 실패":
      return NativeHealthColor.red
    case "기록 없음":
      return NativeHealthColor.secondaryText
    default:
      return NativeHealthColor.orange
    }
  }

  private var saveButtonTitle: String {
    saveStatus == "서버 동기화 중" || saveStatus == "저장 중" ? "저장 중" : "저장"
  }

  private var saveButtonIcon: String {
    saveStatus == "서버 동기화됨" || saveStatus == "저장됨" ? "checkmark" : "square.and.arrow.down"
  }

  private var recentSoapDates: [Date] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    var dates = NativeSoapDraftStore.datesWithDrafts(for: selectedMember)
    for key in soapDraftsByDay.keys where key.hasPrefix("\(selectedMember.avatarSeed)-") {
      guard let draft = soapDraftsByDay[key], draft.hasUserContent else {
        continue
      }
      let rawDate = String(key.dropFirst(selectedMember.avatarSeed.count + 1))
      if let date = Self.storageDateFormatter.date(from: rawDate) {
        dates.insert(calendar.startOfDay(for: date))
      }
    }
    dates.insert(today)
    return dates.sorted(by: >).prefix(8).sorted()
  }

  private static let longDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "yyyy.MM.dd (E)"
    return formatter
  }()

  private static let shortDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "MM.dd"
    return formatter
  }()

  private static let storageDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  private func setSoapDate(_ date: Date) {
    persistCurrentDraft()
    selectedSoapDate = Calendar.current.startOfDay(for: date)
    activeDraftKey = draftKey(member: selectedMember, date: selectedSoapDate)
    loadActiveDraft()
  }

  private func draftKey(member: NativeTrainerMember, date: Date) -> String {
    NativeSoapDraftStore.key(member: member, date: date)
  }

  @discardableResult
  private func persistCurrentDraft() -> Bool {
    guard !activeDraftKey.isEmpty else {
      return false
    }
    let draft = currentDraft()
    if draft.hasUserContent {
      soapDraftsByDay[activeDraftKey] = draft
      guard draft.encodedData() != nil else {
        saveStatus = "저장 실패"
        return false
      }
      NativeSoapDraftStore.persist(draft, key: activeDraftKey)
      saveStatus = "저장됨"
    } else {
      soapDraftsByDay.removeValue(forKey: activeDraftKey)
      NativeSoapDraftStore.persist(draft, key: activeDraftKey)
      saveStatus = "기록 없음"
    }
    return true
  }

  private func markDraftNeedsSave() {
    guard !activeDraftKey.isEmpty, !isLoadingDraft else {
      return
    }
    saveStatus = "저장 중"
    _ = persistCurrentDraft()
  }

  private func loadActiveDraft() {
    if let draft = soapDraftsByDay[activeDraftKey] {
      applyDraft(draft)
      saveStatus = "저장됨"
    } else if let draft = NativeSoapDraftStore.load(key: activeDraftKey) {
      soapDraftsByDay[activeDraftKey] = draft
      applyDraft(draft)
      saveStatus = "저장됨"
    } else {
      let draft = NativeSoapDailyDraft.blank(member: selectedMember)
      applyDraft(draft)
      saveStatus = "기록 없음"
    }
  }

  private func currentDraft() -> NativeSoapDailyDraft {
    NativeSoapDailyDraft(
      drawing: drawing,
      painValue: painValue,
      riskLevel: riskLevel,
      bodyRegion: bodyRegion,
      subjective: subjective,
      objective: objective,
      assessment: assessment,
      plan: plan,
      romEntries: romEntries,
      mmtEntries: mmtEntries
    )
  }

  private func syncPayload() -> [String: Any] {
    let dateMillis = Int(Calendar.current.startOfDay(for: selectedSoapDate).timeIntervalSince1970 * 1000)
    return [
      "id": "native_\(selectedMember.avatarSeed)_\(Self.storageDateFormatter.string(from: selectedSoapDate))",
      "memberId": selectedMember.avatarSeed,
      "memberName": selectedMember.name,
      "memberEmail": selectedMember.email,
      "dateMillis": dateMillis,
      "createdAtMillis": dateMillis,
      "diagnosis": selectedMember.subtitle,
      "bodyRegion": bodyRegion,
      "painNow": Int(painValue),
      "painSite": bodyRegion,
      "riskLevel": riskLevel,
      "subjective": subjective,
      "objective": objective,
      "assessment": assessment,
      "treatmentPlan": plan,
      "homeExercise": "",
      "nextPlan": selectedMember.nextPlan,
      "nativeRomEntries": romEntries,
      "nativeMmtEntries": mmtEntries,
      "nativeExerciseEntries": [],
      "inkDataBase64": drawing.dataRepresentation().base64EncodedString(),
      "inkStrokeCount": drawing.strokes.count
    ]
  }

  private func applyDraft(_ draft: NativeSoapDailyDraft) {
    isLoadingDraft = true
    drawing = draft.drawing
    painValue = draft.painValue
    riskLevel = draft.riskLevel
    bodyRegion = draft.bodyRegion
    subjective = draft.subjective
    objective = draft.objective
    assessment = draft.assessment
    plan = draft.plan
    romEntries = draft.romEntries
    mmtEntries = draft.mmtEntries
    DispatchQueue.main.async {
      isLoadingDraft = false
    }
  }

  private func applyRequestedMode() {
    guard ["필기", "SOAP", "공유", "시각화"].contains(requestedMode) else {
      return
    }
    selectedMode = requestedMode
  }

  private func dismissKeyboard() {
    isTextInputFocused = false
    isKeyboardPresented = false
    keyboardHeight = 0
    UIApplication.shared.sendAction(
      #selector(UIResponder.resignFirstResponder),
      to: nil,
      from: nil,
      for: nil
    )
  }

  private func riskLevelForPain(_ pain: Int) -> String {
    if pain >= 8 { return "고위험" }
    if pain >= 5 { return "주의" }
    return "안정"
  }

  private func updateKeyboardHeight(from notification: Notification, forceHidden: Bool = false) {
    let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.22

    guard !forceHidden,
          let frameValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
      withAnimation(.easeOut(duration: duration)) {
        keyboardHeight = 0
        isKeyboardPresented = false
      }
      return
    }

    let keyboardFrame = frameValue.cgRectValue
    let overlap: CGFloat
    if let windowScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
       let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
      let convertedFrame = window.convert(keyboardFrame, from: nil)
      overlap = max(0, window.bounds.maxY - convertedFrame.minY)
    } else {
      let screenHeight = UIScreen.main.bounds.height
      overlap = max(0, screenHeight - keyboardFrame.minY)
    }

    withAnimation(.easeOut(duration: duration)) {
      keyboardHeight = overlap
      isKeyboardPresented = overlap > 24
    }
  }

  private var soapWorkspace: some View {
    GeometryReader { geometry in
      let compactHeader = geometry.size.width < 720

      VStack(spacing: 0) {
        soapDateBar

        VStack(alignment: .leading, spacing: compactHeader ? 10 : 0) {
          HStack(spacing: 12) {
            NativeMemojiAvatar(member: selectedMember, size: compactHeader ? 42 : 48)

            VStack(alignment: .leading, spacing: 4) {
              HStack(spacing: 8) {
                Text(selectedMember.name)
                  .font(.system(size: compactHeader ? 22 : 26, weight: .bold, design: .rounded))
                  .foregroundStyle(NativeHealthColor.primaryText)
	                  .lineLimit(1)
	                  .layoutPriority(2)
	                NativeStatusCapsule(text: riskLevel, color: riskColor)
	              }
              Text("\(selectedMember.subtitle) · \(bodyRegion) · 통증 \(Int(painValue))/10")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(NativeHealthColor.secondaryText)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(2)

            if !compactHeader {
              NativeSegmentedPicker(
                values: ["필기", "SOAP", "공유", "시각화"],
                selection: $selectedMode
              )
              .frame(width: 270)
            }

	            NativeStatusCapsule(
	              text: saveStatusLabel,
	              color: saveStatusColor
	            )
          }

          if compactHeader {
            NativeSegmentedPicker(
              values: ["필기", "SOAP", "공유", "시각화"],
              selection: $selectedMode
            )
          }
        }
        .padding(.horizontal, compactHeader ? 18 : 24)
        .padding(.vertical, compactHeader ? 12 : 0)
        .frame(minHeight: compactHeader ? 126 : 76)
        .background {
          LinearGradient(
            colors: [Color.white.opacity(0.98), Color(hex: 0xEEF3FF).opacity(0.94)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        }
        .overlay(
          Rectangle()
            .fill(NativeHealthColor.boardStroke)
            .frame(height: 1),
          alignment: .bottom
        )

        Group {
          switch selectedMode {
          case "SOAP":
            structuredSoapPanel
          case "공유":
            sharePanel
          case "시각화":
            visualizationPanel
          default:
            handwritingPanel
          }
        }
      }
    }
  }

  private var soapDateBar: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Label("날짜별 SOAP", systemImage: "calendar")
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(NativeHealthColor.primaryText)
          Text("먼저 작성일을 고르고, 해당 날짜의 필기와 SOAP를 이어서 작성합니다.")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(NativeHealthColor.secondaryText)
        }

        Spacer(minLength: 8)

        Text(selectedDateTitle)
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(NativeHealthColor.secondaryText)
          .lineLimit(1)

        DatePicker(
          "날짜 선택",
          selection: selectedSoapDateBinding,
          displayedComponents: .date
        )
        .labelsHidden()
        .datePickerStyle(.compact)
      }

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
          ForEach(recentSoapDates, id: \.self) { date in
            soapDateChip(date)
          }
        }
      }
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 14)
    .background(Color.white)
    .overlay(
      Rectangle()
        .fill(NativeHealthColor.boardStroke)
        .frame(height: 1),
      alignment: .bottom
    )
  }

  private var handwritingPanel: some View {
    ZStack {
      NativeTrainerPencilCanvasView(
        drawing: $drawing,
        selectedTool: $selectedTool,
        undoSignal: $undoSignal
      )
      .background(NativePaperLines())
      .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .stroke(NativeHealthColor.border, lineWidth: 1)
      )
      .padding(24)

      VStack {
        handwritingContextBar
          .padding(.horizontal, 34)
          .padding(.top, 34)
        Spacer()
      }

      VStack {
        Spacer()
        handwritingToolBar
          .padding(.bottom, 34)
      }
    }
  }

  private var structuredSoapPanel: some View {
    GeometryReader { geometry in
      let wide = geometry.size.width >= 1040

      ScrollViewReader { proxy in
        ZStack(alignment: .bottom) {
          if isKeyboardLayoutActive {
            keyboardFocusedSoapWorkspace(
              size: CGSize(
                width: geometry.size.width,
                height: max(210, geometry.size.height - keyboardBottomInset - 44)
              )
            )
            .padding(16)
            .padding(.bottom, keyboardBottomInset)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
          } else {
            ScrollView {
              VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                  NativeSegmentedPicker(values: ["Subjective", "Objective", "Assessment", "Plan"], selection: selectedSoapLabel)
                    .frame(maxWidth: wide ? 520 : .infinity)
                  Spacer()
	                  NativeStatusCapsule(text: "SOAP \(completionPercent)%", color: completionPercent >= 75 ? NativeHealthColor.green : NativeHealthColor.orange)
                }

                if wide {
                HStack(alignment: .top, spacing: 18) {
                  soapInputColumn
                    .frame(maxWidth: .infinity)
                  soapAttachmentColumn
                    .frame(width: min(420, max(340, geometry.size.width * 0.34)))
                }
                } else {
                  VStack(spacing: 18) {
                    soapInputColumn
                    soapAttachmentColumn
                  }
                }
              }
              .padding(24)
              .padding(.bottom, 24)
            }
            .background(NativeHealthColor.background)
          }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: isTextInputFocused) { focused in
          guard focused else {
            return
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 0.22)) {
              proxy.scrollTo("activeSoapEditor", anchor: .top)
            }
          }
        }
        .onChange(of: selectedSoap) { _ in
          guard isTextInputFocused else {
            return
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeOut(duration: 0.20)) {
              proxy.scrollTo("activeSoapEditor", anchor: .top)
            }
          }
        }
      }
    }
  }

  private func keyboardFocusedSoapWorkspace(size: CGSize) -> some View {
    let workspaceHeight = max(210, size.height)
    let horizontalSplit = size.width >= 760

    return Group {
      if horizontalSplit {
        HStack(spacing: 14) {
          keyboardFocusedEditorPane(height: workspaceHeight)
            .frame(maxWidth: .infinity, maxHeight: workspaceHeight)
          keyboardFocusedHandwritingPane(height: workspaceHeight)
            .frame(maxWidth: .infinity, maxHeight: workspaceHeight)
        }
      } else {
        VStack(spacing: 14) {
          keyboardFocusedEditorPane(height: max(170, workspaceHeight / 2))
            .frame(maxHeight: .infinity)
          keyboardFocusedHandwritingPane(height: max(170, workspaceHeight / 2))
            .frame(maxHeight: .infinity)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: workspaceHeight, alignment: .top)
    .background(NativeHealthColor.background)
  }

  private func keyboardFocusedEditorPane(height: CGFloat) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        NativeStatusCapsule(text: activeSoapTitle, color: activeSoapColor)
        Text("작성 중")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(NativeHealthColor.secondaryText)
	        Spacer()
	        Button {
	          dismissKeyboard()
	        } label: {
          Label("완료", systemImage: "keyboard.chevron.compact.down")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(NativeHealthColor.blue, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
      }

      NativeSegmentedPicker(values: ["Subjective", "Objective", "Assessment", "Plan"], selection: selectedSoapLabel)

      VStack(alignment: .leading, spacing: 5) {
        Text(activeSoapLongTitle)
          .font(.system(size: 18, weight: .bold, design: .rounded))
          .foregroundStyle(NativeHealthColor.primaryText)
        Text(activeSoapSubtitle)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(NativeHealthColor.secondaryText)
          .lineLimit(2)
      }

      ZStack(alignment: .topLeading) {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(NativeHealthColor.subPanel)
          .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .stroke(activeSoapColor.opacity(0.22), lineWidth: 1)
          )

        if activeSoapPreview.isEmpty {
          Text(activeSoapPlaceholder)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(NativeHealthColor.secondaryText.opacity(0.74))
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
        }

        TextEditor(text: activeSoapTextBinding)
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(NativeHealthColor.primaryText)
          .padding(10)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color.clear)
          .focused($isTextInputFocused)
      }
      .frame(maxHeight: max(130, height - 168))
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: height, alignment: .top)
    .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .stroke(activeSoapColor.opacity(0.20), lineWidth: 1)
    )
    .shadow(color: NativeHealthColor.deepBlue.opacity(0.08), radius: 18, x: 0, y: 10)
  }

  private func keyboardFocusedHandwritingPane(height: CGFloat) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        NativeStatusCapsule(text: "필기 원본", color: NativeHealthColor.blue)
        Text(selectedDateTitle)
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(NativeHealthColor.secondaryText)
	        Spacer()
	        Button {
	          dismissKeyboard()
	          selectedMode = "필기"
	        } label: {
          Text("필기 편집")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(NativeHealthColor.blue)
        }
        .buttonStyle(.plain)
      }

      Text("왼쪽 입력창에 정리하면서 오른쪽에서 원본 필기를 계속 확인합니다.")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(NativeHealthColor.secondaryText)
        .lineLimit(2)

      handwritingPreviewSurface(height: max(150, height - 86))
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: height, alignment: .top)
    .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .stroke(NativeHealthColor.border, lineWidth: 1)
    )
    .shadow(color: NativeHealthColor.deepBlue.opacity(0.08), radius: 18, x: 0, y: 10)
  }

  private var activeSoapTextBinding: Binding<String> {
    Binding(
      get: {
        switch selectedSoap {
        case "O": return objective
        case "A": return assessment
        case "P": return plan
        default: return subjective
        }
      },
      set: { value in
        switch selectedSoap {
        case "O": objective = value
        case "A": assessment = value
        case "P": plan = value
        default: subjective = value
        }
      }
    )
  }

  private var activeSoapSubtitle: String {
    switch selectedSoap {
    case "O": return "관찰, ROM, MMT, special test를 수치와 함께 정리합니다."
    case "A": return "문제 목록, 임상 판단, 위험도, 단기/장기 목표를 정리합니다."
    case "P": return "치료계획, 홈운동, 다음 세션, 재평가 일정을 정리합니다."
    default: return "주호소, onset, 악화/완화 요인, 통증 패턴을 빠르게 남깁니다."
    }
  }

  private var activeSoapPlaceholder: String {
    switch selectedSoap {
    case "O": return "관찰, ROM, MMT, special test"
    case "A": return "문제 목록, 임상 판단, 목표"
    case "P": return "치료계획, 홈운동, 다음 세션"
    default: return "주호소, onset, 악화/완화 요인"
    }
  }

  private var selectedSoapLabel: Binding<String> {
    Binding(
      get: {
        switch selectedSoap {
        case "O": return "Objective"
        case "A": return "Assessment"
        case "P": return "Plan"
        default: return "Subjective"
        }
      },
      set: { value in
        switch value {
        case "Objective": selectedSoap = "O"
        case "Assessment": selectedSoap = "A"
        case "Plan": selectedSoap = "P"
        default: selectedSoap = "S"
        }
      }
    )
  }

  private var soapInputColumn: some View {
    VStack(alignment: .leading, spacing: 16) {
      selectedSoapEditor
        .id("activeSoapEditor")
      painAndRestrictionPanel
      soapSectionSummary
      soapBottomActions
    }
  }

  private var soapAttachmentColumn: some View {
    VStack(spacing: 16) {
      handwritingReferenceCard

      soapPersistencePanel

      NativeBoardPanel(title: "날짜별 SOAP", subtitle: "선택한 날짜 기준으로 정리합니다.") {
        VStack(spacing: 10) {
          NativeRiskItem(title: "작성일", value: selectedDateTitle, color: NativeHealthColor.blue)
          NativeRiskItem(title: "현재 파트", value: activeSoapTitle, color: activeSoapColor)
          NativeRiskItem(title: "저장 방식", value: "회원·날짜별 로컬 저장", color: NativeHealthColor.green)
        }
      }
    }
  }

  private var soapPersistencePanel: some View {
    NativeBoardPanel(title: "저장 상태", subtitle: "앱을 다시 열어도 이 iPad에서 이어서 작성합니다.") {
      VStack(spacing: 10) {
        NativeRiskItem(title: saveStatusLabel, value: "\(selectedMember.name) · \(selectedDateTitle)", color: saveStatusColor)
        NativeRiskItem(title: "저장 위치", value: "iPad 로컬 저장소", color: NativeHealthColor.green)
        NativeRiskItem(title: "저장 기준", value: "회원 + 작성일", color: NativeHealthColor.blue)
      }
    }
  }

  private var handwritingReferenceCard: some View {
    NativeBoardPanel(title: "필기 원본", subtitle: "\(activeSoapTitle) 기준으로 보면서 정리합니다.") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 8) {
          NativeStatusCapsule(text: selectedDateTitle, color: NativeHealthColor.blue)
          NativeStatusCapsule(text: activeSoapTitle, color: activeSoapColor)
          Spacer()
          Button {
            selectedMode = "필기"
          } label: {
            Text("필기 보기")
              .font(.system(size: 12, weight: .bold))
              .foregroundStyle(NativeHealthColor.blue)
          }
          .buttonStyle(.plain)
        }

        handwritingPreviewSurface(height: 150)

        Text("필기 원본을 보면서 왼쪽 입력창에 키보드로 정리합니다.")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(NativeHealthColor.secondaryText)
      }
    }
  }

  private var keyboardSoapContextBar: some View {
    HStack(spacing: 12) {
      handwritingPreviewSurface(height: 76, compact: true)
        .frame(width: 150)

      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 8) {
          NativeStatusCapsule(text: activeSoapTitle, color: activeSoapColor)
          Text(selectedDateTitle)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(NativeHealthColor.secondaryText)
        }

        Text("키보드 입력 중: \(activeSoapLongTitle)")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(NativeHealthColor.primaryText)
          .lineLimit(1)

        Text(activeSoapPreview.isEmpty ? "필기 원본을 보면서 현재 파트를 정리하세요." : activeSoapPreview)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(NativeHealthColor.secondaryText)
          .lineLimit(1)
      }

	      Spacer()

	      Button {
	        dismissKeyboard()
	      } label: {
        Label("완료", systemImage: "keyboard.chevron.compact.down")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(Color.white)
          .padding(.horizontal, 14)
          .frame(height: 38)
          .background(NativeHealthColor.blue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 10)
    .background(Color.white.opacity(0.98))
    .overlay(
      Rectangle()
        .fill(NativeHealthColor.boardStroke)
        .frame(height: 1),
      alignment: .top
    )
    .shadow(color: NativeHealthColor.deepBlue.opacity(0.12), radius: 18, x: 0, y: -6)
  }

  private func handwritingPreviewSurface(height: CGFloat, compact: Bool = false) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous)
        .fill(NativeHealthColor.subPanel)

      if let image = handwritingSnapshotImage {
        Image(uiImage: image)
          .resizable()
          .scaledToFit()
          .padding(compact ? 6 : 10)
      } else {
        VStack(spacing: compact ? 4 : 8) {
          Image(systemName: "pencil")
            .font(.system(size: compact ? 16 : 22, weight: .bold))
            .foregroundStyle(NativeHealthColor.blue.opacity(0.72))
          Text(compact ? "필기 없음" : "아직 필기 없음")
            .font(.system(size: compact ? 11 : 13, weight: .bold))
            .foregroundStyle(NativeHealthColor.primaryText)
          if !compact {
            Text("필기 탭에서 작성하면 여기에서 바로 확인합니다.")
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(NativeHealthColor.secondaryText)
          }
        }
      }
    }
    .frame(height: height)
    .overlay(
      RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous)
        .stroke(NativeHealthColor.border, lineWidth: 1)
    )
  }

  private var handwritingSnapshotImage: UIImage? {
    let bounds = drawing.bounds
    guard !bounds.isNull, !bounds.isEmpty else {
      return nil
    }
    let paddedBounds = bounds.insetBy(dx: -28, dy: -28)
    return drawing.image(from: paddedBounds, scale: UIScreen.main.scale)
  }

  private func soapDateChip(_ date: Date) -> some View {
    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedSoapDate)
    let title = Calendar.current.isDateInToday(date) ? "오늘" : Self.shortDateFormatter.string(from: date)

    return Button {
      setSoapDate(date)
    } label: {
      Text(title)
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(isSelected ? Color.white : NativeHealthColor.primaryText)
        .padding(.horizontal, 11)
        .frame(height: 30)
        .background(
          isSelected ? NativeHealthColor.blue : NativeHealthColor.subPanel,
          in: Capsule()
        )
        .overlay(
          Capsule()
            .stroke(isSelected ? NativeHealthColor.blue.opacity(0.2) : NativeHealthColor.border, lineWidth: 1)
        )
    }
    .buttonStyle(.plain)
  }

  private var handwritingContextBar: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 8) {
          NativeStatusCapsule(text: selectedDateTitle, color: NativeHealthColor.blue)
          NativeStatusCapsule(text: activeSoapTitle, color: activeSoapColor)
        }
        NativeSegmentedPicker(values: ["S", "O", "A", "P"], selection: $selectedSoap)
          .frame(width: 250)
      }

      VStack(alignment: .leading, spacing: 5) {
        Text("필기 기준: \(activeSoapLongTitle)")
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(NativeHealthColor.primaryText)
        Text(activeSoapPreview.isEmpty ? "아직 이 파트의 정리 내용이 없습니다. 필기 후 SOAP 탭에서 문장으로 정리하세요." : activeSoapPreview)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(NativeHealthColor.secondaryText)
          .lineLimit(2)
      }

      Spacer()

      Button {
        selectedMode = "SOAP"
      } label: {
        Label("SOAP 정리", systemImage: "text.badge.checkmark")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(NativeHealthColor.blue)
          .padding(.horizontal, 13)
          .frame(height: 36)
          .background(NativeHealthColor.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
      }
      .buttonStyle(.plain)
    }
    .padding(14)
    .background(Color.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(NativeHealthColor.border, lineWidth: 1)
    )
    .shadow(color: NativeHealthColor.deepBlue.opacity(0.08), radius: 16, x: 0, y: 8)
  }

  private var handwritingToolBar: some View {
    HStack(spacing: 8) {
      nativeToolButton("pencil.tip", tool: "pen")
      nativeToolButton("highlighter", tool: "marker")
      nativeToolButton("eraser", tool: "eraser")
      Button {
        undoSignal += 1
      } label: {
        Image(systemName: "arrow.uturn.backward")
          .frame(width: 36, height: 36)
      }
      .buttonStyle(.plain)
      .foregroundStyle(NativeHealthColor.secondaryText)

      Divider().frame(height: 24)
      nativeQuickChip("+통증") {
        selectedSoap = "S"
        painValue = min(10, painValue + 1)
      }
      nativeQuickChip("+ROM") {
        selectedSoap = "O"
        romEntries.append("\(bodyRegion) ROM \(romEntries.count + 1)")
        selectedMode = "시각화"
      }
      nativeQuickChip("+MMT") {
        selectedSoap = "O"
        mmtEntries.append("\(bodyRegion) MMT \(mmtEntries.count + 1)")
        selectedMode = "시각화"
      }
    }
    .padding(9)
    .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(NativeHealthColor.border, lineWidth: 1)
    )
    .shadow(color: NativeHealthColor.deepBlue.opacity(0.10), radius: 18, x: 0, y: 10)
  }

  private var activeSoapTitle: String {
    switch selectedSoap {
    case "O": return "O 객관"
    case "A": return "A 평가"
    case "P": return "P 계획"
    default: return "S 주관"
    }
  }

  private var activeSoapLongTitle: String {
    switch selectedSoap {
    case "O": return "O. 객관적 정보"
    case "A": return "A. 평가"
    case "P": return "P. 계획"
    default: return "S. 주관적 정보"
    }
  }

  private var activeSoapColor: Color {
    switch selectedSoap {
    case "O": return NativeHealthColor.orange
    case "A": return NativeHealthColor.red
    case "P": return NativeHealthColor.green
    default: return NativeHealthColor.blue
    }
  }

  private var activeSoapPreview: String {
    let text: String
    switch selectedSoap {
    case "O": text = objective
    case "A": text = assessment
    case "P": text = plan
    default: text = subjective
    }
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var painAndRestrictionPanel: some View {
    NativeHealthCard {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Text("통증 정도 (NPRS)")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(NativeHealthColor.primaryText)
          Spacer()
          Text("\(Int(painValue))/10")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(NativeHealthColor.red)
        }
	        NativePainScaleView(value: Int(painValue)) { value in
	          painValue = Double(value)
	          riskLevel = riskLevelForPain(value)
	        }

        VStack(alignment: .leading, spacing: 10) {
          Text("가중/제한")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(NativeHealthColor.primaryText)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
            NativeChecklistRow(title: "걷기", checked: false)
            NativeChecklistRow(title: "계단 내려가기", checked: true)
            NativeChecklistRow(title: "달리기", checked: false)
            NativeChecklistRow(title: "스쿼트", checked: false)
            NativeChecklistRow(title: "점프", checked: false)
            NativeChecklistRow(title: "기타", checked: false)
          }
        }
      }
    }
  }

  private var soapBottomActions: some View {
    Button {
      saveSession()
    } label: {
      Label("SOAP 저장", systemImage: "square.and.arrow.down")
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(Color.white)
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background(NativeHealthColor.blue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private var selectedSoapEditor: some View {
    switch selectedSoap {
    case "O":
      NativeSoapTextBox(
        title: "O. 객관적 정보",
        subtitle: "관찰, ROM, MMT, special test를 수치와 함께 정리합니다.",
        placeholder: "관찰, ROM, MMT, special test",
        accent: NativeHealthColor.orange,
        text: $objective,
        focused: $isTextInputFocused
      )
    case "A":
      NativeSoapTextBox(
        title: "A. 평가",
        subtitle: "문제 목록, 임상 판단, 위험도, 단기/장기 목표를 정리합니다.",
        placeholder: "문제 목록, 임상 판단, 목표",
        accent: NativeHealthColor.red,
        text: $assessment,
        focused: $isTextInputFocused
      )
    case "P":
      NativeSoapTextBox(
        title: "P. 계획",
        subtitle: "치료계획, 홈운동, 다음 세션, 재평가 일정을 정리합니다.",
        placeholder: "치료계획, 홈운동, 다음 세션",
        accent: NativeHealthColor.green,
        text: $plan,
        focused: $isTextInputFocused
      )
    default:
      NativeSoapTextBox(
        title: "S. 주관적 정보",
        subtitle: "주호소, onset, 악화/완화 요인, 통증 패턴을 빠르게 남깁니다.",
        placeholder: "주호소, onset, 악화/완화 요인",
        accent: NativeHealthColor.blue,
        text: $subjective,
        focused: $isTextInputFocused
      )
    }
  }

  private var soapSectionSummary: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
      NativeSoapStepCard(title: "S", caption: "주관", value: subjective.isEmpty ? "비어 있음" : "작성됨", color: NativeHealthColor.blue)
      NativeSoapStepCard(title: "O", caption: "객관", value: "\(romEntries.count + mmtEntries.count)개 지표", color: NativeHealthColor.orange)
      NativeSoapStepCard(title: "A", caption: "평가", value: assessment.isEmpty ? "초안 전" : "초안", color: NativeHealthColor.red)
      NativeSoapStepCard(title: "P", caption: "계획", value: plan.isEmpty ? "초안 전" : "공유 가능", color: NativeHealthColor.green)
    }
  }

  private var sharePanel: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Text("회원 공유 요약")
          .font(.system(size: 30, weight: .bold))
        NativeHealthCard {
          VStack(alignment: .leading, spacing: 14) {
            NativeShareLine(title: "현재 상태", value: "\(bodyRegion) · 통증 \(Int(painValue))/10 · \(riskLevel)")
            NativeShareLine(title: "오늘 확인한 점", value: assessment)
            NativeShareLine(title: "다음 실행 계획", value: plan)
          }
        }
        NativeHealthCard {
          HStack {
            NativeIconSquare(systemName: "lock.shield", color: NativeHealthColor.green)
            VStack(alignment: .leading, spacing: 4) {
              Text("내부 필기는 공유하지 않음")
                .font(.system(size: 19, weight: .bold))
              Text("회원에게는 정리된 요약만 전달하고, 트레이너 필기 원본은 내부 관리용으로 유지합니다.")
                .foregroundStyle(NativeHealthColor.secondaryText)
            }
          }
        }
      }
      .padding(24)
    }
  }

  private var visualizationPanel: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Text("세션 시각화")
          .font(.system(size: 30, weight: .bold))
        HStack(spacing: 14) {
          NativeProgressMetric(title: "통증", value: "\(Int(painValue))/10", progress: painValue / 10, color: NativeHealthColor.red)
          NativeProgressMetric(title: "목표 진행", value: selectedMember.progress + "%", progress: (Double(selectedMember.progress) ?? 0) / 100, color: NativeHealthColor.blue)
	          NativeProgressMetric(title: "SOAP 완료", value: "\(completionPercent)%", progress: Double(completionPercent) / 100, color: completionPercent >= 75 ? NativeHealthColor.green : NativeHealthColor.orange)
        }
        NativeHealthCard {
          VStack(alignment: .leading, spacing: 14) {
            Text("통증 / 완료율 변화")
              .font(.system(size: 21, weight: .bold))
            if selectedMemberPoints.isEmpty {
              NativeEmptyState(
                title: "그래프 데이터 없음",
                message: "이 회원의 날짜별 SOAP를 저장하면 통증과 완료율 그래프가 표시됩니다.",
                symbol: "chart.xyaxis.line"
              )
              .frame(height: 250)
            } else {
              NativeLineChart(
                painPoints: Array(selectedMemberPoints.suffix(8).map(\.pain)),
                completionPoints: Array(selectedMemberPoints.suffix(8).map(\.completion)),
                labels: Array(selectedMemberPoints.suffix(8).map { Self.shortDateFormatter.string(from: $0.date) })
              )
              .frame(height: 250)
            }
          }
        }
      }
      .padding(24)
    }
  }

  private var metricInspector: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        VStack(alignment: .leading, spacing: 5) {
          Text("SOAP 입력")
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundStyle(NativeHealthColor.primaryText)
          Text("수업 중 필요한 수치만 빠르게 조정합니다.")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(NativeHealthColor.secondaryText)
        }

        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("통증")
              .font(.system(size: 15, weight: .semibold))
            Spacer()
            Text("\(Int(painValue))/10")
              .font(.system(size: 15, weight: .bold))
              .foregroundStyle(NativeHealthColor.red)
          }
          Slider(value: $painValue, in: 0...10, step: 1)
            .tint(NativeHealthColor.red)
        }

        NativeFieldRow(title: "부위", text: $bodyRegion, focused: $isTextInputFocused)

        VStack(alignment: .leading, spacing: 8) {
          Text("위험도")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(NativeHealthColor.secondaryText)
          NativeSegmentedPicker(values: ["안정", "주의", "고위험"], selection: $riskLevel)
        }

        NativeMetricEntryList(title: "ROM", entries: romEntries) {
          romEntries.append("\(bodyRegion) ROM \(romEntries.count + 1)")
        }
        NativeMetricEntryList(title: "MMT", entries: mmtEntries) {
          mmtEntries.append("\(bodyRegion) MMT \(mmtEntries.count + 1)")
        }

        Button {
          selectedMode = "SOAP"
        } label: {
          Label("세션 후 정리", systemImage: "text.badge.checkmark")
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
              LinearGradient(
                colors: [NativeHealthColor.blue, NativeHealthColor.deepBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(.plain)

        Button {
          drawing = PKDrawing()
          subjective = ""
          objective = ""
          assessment = ""
          plan = ""
          romEntries = []
          mmtEntries = []
          painValue = 0
          riskLevel = "안정"
        } label: {
          Label("새 기록", systemImage: "plus")
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(NativeHealthColor.blue)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(NativeHealthColor.subPanel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
              RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(NativeHealthColor.blue.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
      }
      .padding(18)
    }
    .background(NativeStudioBackdrop().opacity(0.64))
  }

  private func saveSession() {
    dismissKeyboard()
    saveStatus = "저장 중"
    guard persistCurrentDraft() else {
      return
    }
    saveStatus = "서버 동기화 중"
    onSyncSoap(syncPayload()) { synced in
      DispatchQueue.main.async {
        saveStatus = synced ? "서버 동기화됨" : "저장됨"
      }
    }
  }

  private func nativeToolButton(_ systemName: String, tool: String) -> some View {
    Button {
      selectedTool = tool
    } label: {
      Image(systemName: systemName)
        .frame(width: 36, height: 36)
        .foregroundStyle(selectedTool == tool ? NativeHealthColor.blue : NativeHealthColor.secondaryText)
        .background(
          selectedTool == tool ? NativeHealthColor.blue.opacity(0.12) : Color.clear,
          in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
    .buttonStyle(.plain)
  }

  private func nativeQuickChip(_ title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(NativeHealthColor.primaryText)
        .padding(.horizontal, 11)
        .frame(height: 32)
        .background(NativeHealthColor.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    .buttonStyle(.plain)
  }
}

private struct NativeTrainerReportsDetail: View {
  let members: [NativeTrainerMember]
  let soapDraftsByDay: [String: NativeSoapDailyDraft]

  private var analytics: NativeSoapAnalytics {
    NativeSoapAnalytics(members: members, soapDraftsByDay: soapDraftsByDay)
  }

  var body: some View {
    GeometryReader { geometry in
      let wide = geometry.size.width >= 1040

      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          VStack(alignment: .leading, spacing: 7) {
            Text("센터 리포트")
              .font(.system(size: 38, weight: .bold, design: .rounded))
              .foregroundStyle(NativeHealthColor.primaryText)
            Text("회원별 통증 변화, SOAP 완료율, 재평가 필요 상태를 한 화면에서 봅니다.")
              .font(.system(size: 16, weight: .medium))
              .foregroundStyle(NativeHealthColor.secondaryText)
          }

          HStack(spacing: 14) {
            NativeSessionMetricCard(title: "평균 통증", value: analytics.averagePainValueText, unit: "/10", symbol: "waveform.path.ecg", color: NativeHealthColor.red)
            NativeSessionMetricCard(title: "SOAP 완료", value: "\(analytics.averageCompletionPercent)", unit: "%", symbol: "checklist.checked", color: NativeHealthColor.green)
            NativeSessionMetricCard(title: "재평가 필요", value: "\(analytics.attentionMemberCount)", unit: "명", symbol: "clock.badge.exclamationmark", color: NativeHealthColor.orange)
          }

          if wide {
            HStack(alignment: .top, spacing: 18) {
              reportTrendCard
              VStack(spacing: 18) {
                reportMemberCard
                reportActionCard
              }
              .frame(width: 360)
            }
          } else {
            VStack(spacing: 18) {
              reportTrendCard
              reportMemberCard
              reportActionCard
            }
          }
        }
        .padding(32)
        .frame(maxWidth: 1220, alignment: .topLeading)
        .frame(maxWidth: .infinity)
      }
      .background(NativeStudioBackdrop().ignoresSafeArea())
    }
  }

  private var reportTrendCard: some View {
    NativeBoardPanel(title: "핵심 추세", subtitle: "큰 차트 대신 관리 판단에 필요한 변화만 압축합니다.") {
      if analytics.painPoints.isEmpty && analytics.completionPoints.isEmpty {
        NativeEmptyState(
          title: "리포트 데이터가 없습니다",
          message: "SOAP 기록이 쌓이면 통증 변화와 완료율이 여기에 표시됩니다.",
          symbol: "chart.line.uptrend.xyaxis"
        )
      } else {
        NativeLineChart(
          painPoints: analytics.painPoints,
          completionPoints: analytics.completionPoints,
          labels: analytics.chartLabels
        )
        .frame(height: 240)
      }
    }
  }

  private var reportMemberCard: some View {
    NativeBoardPanel(title: "회원별 우선순위", subtitle: "오늘 확인할 순서") {
      VStack(spacing: 10) {
        if members.isEmpty {
          NativeEmptyState(
            title: "우선순위 회원이 없습니다",
            message: "회원 기록을 추가하면 오늘 확인할 순서가 표시됩니다.",
            symbol: "person.2"
          )
        } else {
          ForEach(members) { member in
          NativeReportMemberRow(member: member)
          }
        }
      }
    }
  }

  private var reportActionCard: some View {
    NativeBoardPanel(title: "운영 체크", subtitle: "센터 관점에서 필요한 조치") {
      VStack(spacing: 10) {
        NativeRiskItem(title: "오늘 SOAP", value: "\(analytics.todaySoapCount)건", color: NativeHealthColor.blue)
        NativeRiskItem(title: "전체 SOAP", value: "\(analytics.totalSoapCount)건", color: NativeHealthColor.purple)
        NativeRiskItem(title: "회원 공유", value: "0건", color: NativeHealthColor.deepBlue)
      }
    }
  }
}

private struct NativeTrainerSettingsDetail: View {
  let onLogoutToLogin: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        Text("설정")
          .font(.system(size: 38, weight: .bold))
        NativeHealthCard {
          VStack(spacing: 0) {
            NativeSettingsRow(title: "모드", value: "게스트")
            Divider()
            NativeSettingsRow(title: "기록 방식", value: "Pencil + SOAP")
          }
        }
        NativeHealthCard {
          VStack(spacing: 0) {
            NativeSettingsRow(title: "SOAP 기록", value: "날짜별 작성")
            Divider()
            NativeSettingsRow(title: "회원 공유", value: "요약만 공유")
          }
        }
        NativeHealthCard {
          Button(action: onLogoutToLogin) {
            HStack(spacing: 14) {
              Image(systemName: "rectangle.portrait.and.arrow.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(NativeHealthColor.blue)
                .frame(width: 42, height: 42)
                .background(NativeHealthColor.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

              VStack(alignment: .leading, spacing: 4) {
                Text("로그인 화면으로 나가기")
                  .font(.system(size: 17, weight: .bold))
                  .foregroundStyle(NativeHealthColor.primaryText)
                Text("TR-SET-LOGIN")
                  .font(.system(size: 11, weight: .bold))
                  .foregroundStyle(NativeHealthColor.secondaryText)
              }

              Spacer()

              Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(NativeHealthColor.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("로그인 화면으로 나가기")
        }
      }
      .padding(32)
    }
    .background(NativeHealthColor.background)
  }
}

private struct NativeSettingsRow: View {
  let title: String
  let value: String

  var body: some View {
    HStack {
      Text(title)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(NativeHealthColor.primaryText)
      Spacer()
      Text(value)
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(NativeHealthColor.secondaryText)
    }
    .padding(.vertical, 12)
  }
}

private struct NativePainScaleView: View {
  let value: Int
  var onSelect: ((Int) -> Void)? = nil

  var body: some View {
    HStack(spacing: 6) {
      ForEach(0...10, id: \.self) { item in
        Button {
          onSelect?(item)
        } label: {
          Text("\(item)")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(item == value ? Color.white : NativeHealthColor.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(
              item == value ? NativeHealthColor.blue : NativeHealthColor.subPanel,
              in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .overlay(
              RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(item == value ? NativeHealthColor.blue : NativeHealthColor.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(onSelect == nil)
      }
    }
  }
}

private struct NativeChecklistRow: View {
  let title: String
  let checked: Bool

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: checked ? "checkmark.square.fill" : "square")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(checked ? NativeHealthColor.blue : NativeHealthColor.secondaryText)
      Text(title)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(NativeHealthColor.primaryText)
        .lineLimit(1)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 10)
    .frame(height: 34)
    .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(NativeHealthColor.border, lineWidth: 1)
    )
  }
}

private enum NativePainBodyRegionCatalog {
  static let groups: [(String, [String])] = [
    ("머리", ["두통", "측두부", "후두부", "턱관절"]),
    ("목", ["경추", "상부 승모근", "목 전면", "목 후면"]),
    ("어깨", ["전면 어깨", "측면 어깨", "후면 어깨", "견갑", "회전근개"]),
    ("가슴", ["흉골", "대흉근", "늑골", "흉추 전면"]),
    ("상완", ["상완 이두", "상완 삼두", "상완 외측", "상완 내측"]),
    ("전완", ["전완 굴곡근", "전완 신전근", "요측 전완", "척측 전완"]),
    ("손목", ["손목 전면", "손목 후면", "요측 손목", "척측 손목"]),
    ("손", ["손바닥", "손등", "엄지", "손가락"]),
    ("등", ["상부 등", "중부 등", "광배", "능형근"]),
    ("허리", ["요추", "요방형근", "천장관절", "허리 중앙"]),
    ("골반", ["골반 전면", "골반 후면", "둔근", "고관절"]),
    ("대퇴", ["대퇴 전면", "대퇴 후면", "대퇴 내측", "대퇴 외측"]),
    ("무릎", ["무릎 전면", "무릎 후면", "무릎 내측", "무릎 외측"]),
    ("하퇴", ["종아리", "정강이", "아킬레스", "비골근"]),
    ("발목", ["발목 전면", "발목 후면", "발목 내측", "발목 외측"]),
    ("발", ["발바닥", "발등", "뒤꿈치", "발가락"]),
  ]
}

private struct NativeBodyMapView: View {
  let color: Color
  let selectedRegions: [String]

  var body: some View {
    GeometryReader { geometry in
      let width = geometry.size.width
      let height = geometry.size.height
      let selectedGroups = selectedTopLevelRegions

      ZStack {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(NativeHealthColor.subPanel)

        HStack(spacing: 14) {
          NativeMusclePainSceneView(selectedGroups: selectedGroups)
            .frame(width: min(width * 0.46, 220), height: height * 0.90)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
              RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )

          VStack(alignment: .leading, spacing: 6) {
            HStack {
              Text("3D 근육 통증 맵")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(NativeHealthColor.secondaryText)
              Spacer()
            }
            Text("선택한 부위의 근육 세그먼트를 빨간색으로 표시합니다.")
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(NativeHealthColor.secondaryText.opacity(0.82))
              .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 6)], alignment: .leading, spacing: 6) {
              ForEach(NativePainBodyRegionCatalog.groups, id: \.0) { group in
                regionBadge(group.0, selected: selectedGroups.contains(group.0))
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
      }
    }
  }

  private var selectedTopLevelRegions: Set<String> {
    let values = selectedRegions.map { region in
      region.components(separatedBy: " > ").first?.trimmedForDisplay ?? region.trimmedForDisplay
    }
    return Set(values.filter { !$0.isEmpty })
  }

  private func bodySilhouette(width: CGFloat, height: CGFloat) -> some View {
    ZStack {
      Capsule()
        .fill(bodyFill(for: "머리"))
        .frame(width: width * 0.22, height: height * 0.16)
        .offset(y: -height * 0.40)
      RoundedRectangle(cornerRadius: width * 0.12, style: .continuous)
        .fill(bodyFill(for: "가슴"))
        .frame(width: width * 0.42, height: height * 0.36)
        .offset(y: -height * 0.16)
      RoundedRectangle(cornerRadius: width * 0.08, style: .continuous)
        .fill(bodyFill(for: "상완"))
        .frame(width: width * 0.16, height: height * 0.28)
        .offset(x: -width * 0.28, y: -height * 0.16)
      RoundedRectangle(cornerRadius: width * 0.08, style: .continuous)
        .fill(bodyFill(for: "상완"))
        .frame(width: width * 0.16, height: height * 0.28)
        .offset(x: width * 0.28, y: -height * 0.16)
      RoundedRectangle(cornerRadius: width * 0.06, style: .continuous)
        .fill(bodyFill(for: "전완"))
        .frame(width: width * 0.13, height: height * 0.24)
        .offset(x: -width * 0.33, y: height * 0.06)
      RoundedRectangle(cornerRadius: width * 0.06, style: .continuous)
        .fill(bodyFill(for: "전완"))
        .frame(width: width * 0.13, height: height * 0.24)
        .offset(x: width * 0.33, y: height * 0.06)
      RoundedRectangle(cornerRadius: width * 0.08, style: .continuous)
        .fill(bodyFill(for: "대퇴"))
        .frame(width: width * 0.17, height: height * 0.38)
        .offset(x: -width * 0.12, y: height * 0.22)
      RoundedRectangle(cornerRadius: width * 0.08, style: .continuous)
        .fill(bodyFill(for: "대퇴"))
        .frame(width: width * 0.17, height: height * 0.38)
        .offset(x: width * 0.12, y: height * 0.22)
      RoundedRectangle(cornerRadius: width * 0.06, style: .continuous)
        .fill(bodyFill(for: "하퇴"))
        .frame(width: width * 0.14, height: height * 0.28)
        .offset(x: -width * 0.12, y: height * 0.52)
      RoundedRectangle(cornerRadius: width * 0.06, style: .continuous)
        .fill(bodyFill(for: "하퇴"))
        .frame(width: width * 0.14, height: height * 0.28)
        .offset(x: width * 0.12, y: height * 0.52)
    }
    .frame(width: width, height: height)
  }

  private func painPoint() -> some View {
    Circle()
      .fill(color.opacity(0.22))
      .frame(width: 28, height: 28)
      .overlay(
        Circle()
          .fill(color)
          .frame(width: 10, height: 10)
      )
  }

  private func bodyFill(for group: String) -> Color {
    selectedTopLevelRegions.contains(group) ? color.opacity(0.52) : Color(hex: 0xDCE4F1)
  }

  private func regionBadge(_ title: String, selected: Bool) -> some View {
    Text(title)
      .font(.system(size: 11, weight: .bold))
      .foregroundStyle(selected ? Color.white : NativeHealthColor.secondaryText)
      .padding(.horizontal, 8)
      .frame(height: 24)
      .background(selected ? NativeHealthColor.red : Color.white, in: Capsule())
      .overlay(
        Capsule()
          .stroke(selected ? NativeHealthColor.red.opacity(0.30) : NativeHealthColor.border, lineWidth: 1)
      )
  }

  private func markerPoint(for group: String, width: CGFloat, height: CGFloat) -> CGPoint? {
    let x = width / 2
    switch group {
    case "머리": return CGPoint(x: x, y: height * 0.10)
    case "목": return CGPoint(x: x, y: height * 0.20)
    case "어깨": return CGPoint(x: x, y: height * 0.28)
    case "가슴": return CGPoint(x: x, y: height * 0.36)
    case "상완": return CGPoint(x: x + width * 0.31, y: height * 0.36)
    case "전완", "손목", "손": return CGPoint(x: x + width * 0.36, y: height * 0.52)
    case "등": return CGPoint(x: x, y: height * 0.42)
    case "허리": return CGPoint(x: x, y: height * 0.50)
    case "골반": return CGPoint(x: x, y: height * 0.60)
    case "대퇴": return CGPoint(x: x + width * 0.13, y: height * 0.72)
    case "무릎": return CGPoint(x: x + width * 0.13, y: height * 0.84)
    case "하퇴", "발목", "발": return CGPoint(x: x + width * 0.13, y: height * 0.96)
    default: return nil
    }
  }
}

private struct NativeMusclePainSceneView: UIViewRepresentable {
  let selectedGroups: Set<String>

  func makeUIView(context: Context) -> SCNView {
    let view = SCNView()
    view.backgroundColor = .clear
    view.allowsCameraControl = true
    view.autoenablesDefaultLighting = false
    view.defaultCameraController.interactionMode = .orbitTurntable
    view.scene = makeScene()
    return view
  }

  func updateUIView(_ uiView: SCNView, context: Context) {
    uiView.scene = makeScene()
  }

  private func makeScene() -> SCNScene {
    let scene = SCNScene()
    scene.background.contents = UIColor.clear

    let cameraNode = SCNNode()
    cameraNode.camera = SCNCamera()
    cameraNode.camera?.fieldOfView = 34
    cameraNode.position = SCNVector3(0, 0.18, 6.4)
    scene.rootNode.addChildNode(cameraNode)

    let ambientLight = SCNNode()
    ambientLight.light = SCNLight()
    ambientLight.light?.type = .ambient
    ambientLight.light?.color = UIColor(white: 0.80, alpha: 1)
    scene.rootNode.addChildNode(ambientLight)

    let keyLight = SCNNode()
    keyLight.light = SCNLight()
    keyLight.light?.type = .omni
    keyLight.light?.intensity = 850
    keyLight.position = SCNVector3(-2.2, 3.1, 3.8)
    scene.rootNode.addChildNode(keyLight)

    let bodyRoot = SCNNode()
    bodyRoot.eulerAngles = SCNVector3(-0.05, -0.30, 0)
    scene.rootNode.addChildNode(bodyRoot)

    addMuscleNodes(to: bodyRoot)
    return scene
  }

  private func addMuscleNodes(to root: SCNNode) {
    root.addChildNode(sphere(group: "머리", radius: 0.26, position: SCNVector3(0, 2.24, 0.02), scale: SCNVector3(0.92, 1.10, 0.88), baseColor: UIColor(red: 0.82, green: 0.62, blue: 0.46, alpha: 1)))
    root.addChildNode(capsule(group: "목", radius: 0.09, height: 0.34, position: SCNVector3(0, 1.88, 0), baseColor: muscleColor))

    root.addChildNode(sphere(group: "어깨", radius: 0.18, position: SCNVector3(-0.48, 1.64, 0), scale: SCNVector3(1.35, 0.82, 0.72), baseColor: muscleColor))
    root.addChildNode(sphere(group: "어깨", radius: 0.18, position: SCNVector3(0.48, 1.64, 0), scale: SCNVector3(1.35, 0.82, 0.72), baseColor: muscleColor))

    root.addChildNode(sphere(group: "가슴", radius: 0.22, position: SCNVector3(-0.20, 1.36, 0.08), scale: SCNVector3(1.25, 0.68, 0.28), baseColor: muscleColor))
    root.addChildNode(sphere(group: "가슴", radius: 0.22, position: SCNVector3(0.20, 1.36, 0.08), scale: SCNVector3(1.25, 0.68, 0.28), baseColor: muscleColor))
    root.addChildNode(sphere(group: "등", radius: 0.25, position: SCNVector3(-0.25, 1.25, -0.14), scale: SCNVector3(0.78, 1.22, 0.26), baseColor: deepMuscleColor))
    root.addChildNode(sphere(group: "등", radius: 0.25, position: SCNVector3(0.25, 1.25, -0.14), scale: SCNVector3(0.78, 1.22, 0.26), baseColor: deepMuscleColor))

    root.addChildNode(capsule(group: "허리", radius: 0.08, height: 0.58, position: SCNVector3(-0.12, 0.88, 0.08), baseColor: muscleColor))
    root.addChildNode(capsule(group: "허리", radius: 0.08, height: 0.58, position: SCNVector3(0.12, 0.88, 0.08), baseColor: muscleColor))
    root.addChildNode(sphere(group: "골반", radius: 0.22, position: SCNVector3(0, 0.48, 0), scale: SCNVector3(1.38, 0.70, 0.46), baseColor: deepMuscleColor))

    root.addChildNode(capsule(group: "상완", radius: 0.105, height: 0.72, position: SCNVector3(-0.66, 1.12, 0), eulerAngles: SCNVector3(0, 0, 0.18), baseColor: muscleColor))
    root.addChildNode(capsule(group: "상완", radius: 0.105, height: 0.72, position: SCNVector3(0.66, 1.12, 0), eulerAngles: SCNVector3(0, 0, -0.18), baseColor: muscleColor))
    root.addChildNode(capsule(group: "전완", radius: 0.085, height: 0.62, position: SCNVector3(-0.76, 0.52, 0.02), eulerAngles: SCNVector3(0, 0, 0.08), baseColor: tendonColor))
    root.addChildNode(capsule(group: "전완", radius: 0.085, height: 0.62, position: SCNVector3(0.76, 0.52, 0.02), eulerAngles: SCNVector3(0, 0, -0.08), baseColor: tendonColor))
    root.addChildNode(capsule(group: "손목", radius: 0.055, height: 0.16, position: SCNVector3(-0.79, 0.14, 0.02), baseColor: tendonColor))
    root.addChildNode(capsule(group: "손목", radius: 0.055, height: 0.16, position: SCNVector3(0.79, 0.14, 0.02), baseColor: tendonColor))
    root.addChildNode(sphere(group: "손", radius: 0.10, position: SCNVector3(-0.80, -0.02, 0.03), scale: SCNVector3(0.82, 1.06, 0.56), baseColor: UIColor(red: 0.82, green: 0.62, blue: 0.46, alpha: 1)))
    root.addChildNode(sphere(group: "손", radius: 0.10, position: SCNVector3(0.80, -0.02, 0.03), scale: SCNVector3(0.82, 1.06, 0.56), baseColor: UIColor(red: 0.82, green: 0.62, blue: 0.46, alpha: 1)))

    root.addChildNode(capsule(group: "대퇴", radius: 0.14, height: 0.86, position: SCNVector3(-0.20, -0.20, 0.02), baseColor: muscleColor))
    root.addChildNode(capsule(group: "대퇴", radius: 0.14, height: 0.86, position: SCNVector3(0.20, -0.20, 0.02), baseColor: muscleColor))
    root.addChildNode(sphere(group: "무릎", radius: 0.13, position: SCNVector3(-0.20, -0.74, 0.05), scale: SCNVector3(0.94, 0.78, 0.62), baseColor: tendonColor))
    root.addChildNode(sphere(group: "무릎", radius: 0.13, position: SCNVector3(0.20, -0.74, 0.05), scale: SCNVector3(0.94, 0.78, 0.62), baseColor: tendonColor))
    root.addChildNode(capsule(group: "하퇴", radius: 0.115, height: 0.78, position: SCNVector3(-0.20, -1.20, 0.02), baseColor: muscleColor))
    root.addChildNode(capsule(group: "하퇴", radius: 0.115, height: 0.78, position: SCNVector3(0.20, -1.20, 0.02), baseColor: muscleColor))
    root.addChildNode(sphere(group: "발목", radius: 0.075, position: SCNVector3(-0.20, -1.66, 0.02), scale: SCNVector3(0.86, 0.78, 0.68), baseColor: tendonColor))
    root.addChildNode(sphere(group: "발목", radius: 0.075, position: SCNVector3(0.20, -1.66, 0.02), scale: SCNVector3(0.86, 0.78, 0.68), baseColor: tendonColor))
    root.addChildNode(box(group: "발", size: SCNVector3(0.26, 0.10, 0.46), position: SCNVector3(-0.23, -1.83, 0.12), baseColor: UIColor(red: 0.82, green: 0.62, blue: 0.46, alpha: 1)))
    root.addChildNode(box(group: "발", size: SCNVector3(0.26, 0.10, 0.46), position: SCNVector3(0.23, -1.83, 0.12), baseColor: UIColor(red: 0.82, green: 0.62, blue: 0.46, alpha: 1)))
  }

  private func capsule(
    group: String,
    radius: CGFloat,
    height: CGFloat,
    position: SCNVector3,
    eulerAngles: SCNVector3 = SCNVector3(0, 0, 0),
    baseColor: UIColor
  ) -> SCNNode {
    let geometry = SCNCapsule(capRadius: radius, height: height)
    geometry.radialSegmentCount = 32
    geometry.materials = [material(for: group, baseColor: baseColor)]

    let node = SCNNode(geometry: geometry)
    node.position = position
    node.eulerAngles = eulerAngles
    return node
  }

  private func sphere(
    group: String,
    radius: CGFloat,
    position: SCNVector3,
    scale: SCNVector3 = SCNVector3(1, 1, 1),
    baseColor: UIColor
  ) -> SCNNode {
    let geometry = SCNSphere(radius: radius)
    geometry.segmentCount = 32
    geometry.materials = [material(for: group, baseColor: baseColor)]

    let node = SCNNode(geometry: geometry)
    node.position = position
    node.scale = scale
    return node
  }

  private func box(
    group: String,
    size: SCNVector3,
    position: SCNVector3,
    baseColor: UIColor
  ) -> SCNNode {
    let geometry = SCNBox(width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(size.z), chamferRadius: 0.05)
    geometry.materials = [material(for: group, baseColor: baseColor)]

    let node = SCNNode(geometry: geometry)
    node.position = position
    return node
  }

  private func material(for group: String, baseColor: UIColor) -> SCNMaterial {
    let selected = selectedGroups.contains(group)
    let material = SCNMaterial()
    material.diffuse.contents = selected ? UIColor.systemRed : baseColor
    material.emission.contents = selected ? UIColor(red: 1.0, green: 0.06, blue: 0.02, alpha: 0.42) : UIColor.clear
    material.specular.contents = UIColor.white.withAlphaComponent(selected ? 0.62 : 0.28)
    material.shininess = selected ? 0.64 : 0.36
    material.transparency = selected ? 1.0 : 0.78
    return material
  }

  private var muscleColor: UIColor {
    UIColor(red: 0.68, green: 0.20, blue: 0.16, alpha: 1)
  }

  private var deepMuscleColor: UIColor {
    UIColor(red: 0.50, green: 0.14, blue: 0.16, alpha: 1)
  }

  private var tendonColor: UIColor {
    UIColor(red: 0.83, green: 0.58, blue: 0.45, alpha: 1)
  }
}

private struct NativeSegmentedPicker: View {
  let values: [String]
  @Binding var selection: String

  var body: some View {
    HStack(spacing: 3) {
      ForEach(values, id: \.self) { value in
        Button {
          selection = value
        } label: {
          Text(value)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(selection == value ? Color.white : NativeHealthColor.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(
              selection == value ? NativeHealthColor.blue : Color.white.opacity(0.001),
              in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
        }
        .buttonStyle(.plain)
      }
    }
    .padding(3)
    .background(NativeHealthColor.subPanel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(NativeHealthColor.border.opacity(0.76), lineWidth: 1)
    )
  }
}

private struct NativeSoapTextBox: View {
  let title: String
  let subtitle: String
  let placeholder: String
  let accent: Color
  @Binding var text: String
  let focused: FocusState<Bool>.Binding

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top, spacing: 12) {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
          .fill(accent)
          .frame(width: 7, height: 46)
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(NativeHealthColor.primaryText)
          Text(subtitle)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(NativeHealthColor.secondaryText)
        }
      }

      ZStack(alignment: .topLeading) {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(NativeHealthColor.subPanel)
          .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .stroke(accent.opacity(0.20), lineWidth: 1)
          )

        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Text(placeholder)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(NativeHealthColor.secondaryText.opacity(0.74))
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
        }

        TextEditor(text: $text)
          .font(.system(size: 18, weight: .medium))
          .foregroundColor(NativeHealthColor.primaryText)
          .padding(16)
          .frame(minHeight: 340)
          .background(Color.clear)
          .focused(focused)
          .onTapGesture {
            focused.wrappedValue = true
          }
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      LinearGradient(
        colors: [Color.white.opacity(0.98), accent.opacity(0.055)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      in: RoundedRectangle(cornerRadius: 24, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(accent.opacity(0.22), lineWidth: 1)
    )
    .shadow(color: NativeHealthColor.deepBlue.opacity(0.08), radius: 18, x: 0, y: 10)
  }
}

private struct NativeSoapStepCard: View {
  let title: String
  let caption: String
  let value: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(title)
          .font(.system(size: 15, weight: .bold, design: .rounded))
          .foregroundStyle(Color.white)
          .frame(width: 30, height: 30)
          .background(color, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        Spacer()
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(caption)
          .font(.system(size: 12, weight: .bold, design: .rounded))
          .foregroundStyle(NativeHealthColor.secondaryText)
        Text(value)
          .font(.system(size: 15, weight: .bold, design: .rounded))
          .foregroundStyle(NativeHealthColor.primaryText)
          .lineLimit(1)
      }
    }
    .padding(14)
    .background(
      LinearGradient(
        colors: [Color.white.opacity(0.94), color.opacity(0.055)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      in: RoundedRectangle(cornerRadius: 18, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(color.opacity(0.18), lineWidth: 1)
    )
  }
}
private struct NativeShareLine: View {
  let title: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title)
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(NativeHealthColor.secondaryText)
      Text(value)
        .font(.system(size: 16))
        .foregroundStyle(NativeHealthColor.primaryText)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

private struct NativeProgressMetric: View {
  let title: String
  let value: String
  let progress: Double
  let color: Color

  var body: some View {
    NativeHealthCard {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(NativeHealthColor.secondaryText)
          Spacer()
          Text(value)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(color)
        }
        ProgressView(value: min(max(progress, 0), 1))
          .tint(color)
      }
    }
  }
}

private struct NativeFieldRow: View {
  let title: String
  @Binding var text: String
  let focused: FocusState<Bool>.Binding

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(title)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(NativeHealthColor.secondaryText)
      TextField(title, text: $text)
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(NativeHealthColor.primaryText)
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(NativeHealthColor.subPanel, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 13, style: .continuous)
            .stroke(NativeHealthColor.border.opacity(0.76), lineWidth: 1)
        )
        .focused(focused)
    }
  }
}

private struct NativeMetricEntryList: View {
  let title: String
  let entries: [String]
  let onAdd: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack {
        Text(title)
          .font(.system(size: 15, weight: .bold))
        Spacer()
        Button(action: onAdd) {
          Image(systemName: "plus.circle.fill")
        }
        .buttonStyle(.plain)
      }

      if entries.isEmpty {
        Text("항목 없음")
          .font(.system(size: 13))
          .foregroundStyle(NativeHealthColor.secondaryText)
      } else {
        ForEach(entries.suffix(3), id: \.self) { entry in
          HStack(spacing: 8) {
            Circle()
              .fill(NativeHealthColor.blue)
              .frame(width: 6, height: 6)
            Text(entry)
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(NativeHealthColor.secondaryText)
              .lineLimit(1)
            Spacer()
          }
        }
      }
    }
    .padding(14)
    .background(NativeHealthColor.subPanel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(NativeHealthColor.border.opacity(0.76), lineWidth: 0.8)
    )
  }
}

private struct NativeTrainerPencilCanvasView: UIViewRepresentable {
  @Binding var drawing: PKDrawing
  @Binding var selectedTool: String
  @Binding var undoSignal: Int

  func makeUIView(context: Context) -> PKCanvasView {
    let canvas = PKCanvasView()
    canvas.delegate = context.coordinator
    canvas.backgroundColor = .clear
    canvas.isOpaque = false
    canvas.drawingPolicy = .anyInput
    canvas.tool = Self.tool(for: selectedTool)
    canvas.drawing = drawing
    return canvas
  }

  func updateUIView(_ uiView: PKCanvasView, context: Context) {
    uiView.tool = Self.tool(for: selectedTool)
    if context.coordinator.lastUndoSignal != undoSignal {
      context.coordinator.lastUndoSignal = undoSignal
      if uiView.undoManager?.canUndo == true {
        uiView.undoManager?.undo()
      } else if !uiView.drawing.strokes.isEmpty {
        uiView.drawing = PKDrawing(strokes: Array(uiView.drawing.strokes.dropLast()))
      }
      drawing = uiView.drawing
      return
    }
    if uiView.drawing != drawing {
      uiView.drawing = drawing
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(drawing: $drawing, undoSignal: undoSignal)
  }

  private static func tool(for selectedTool: String) -> PKTool {
    switch selectedTool {
    case "marker":
      return PKInkingTool(.marker, color: UIColor.systemYellow.withAlphaComponent(0.85), width: 12)
    case "eraser":
      return PKEraserTool(.bitmap)
    default:
      return PKInkingTool(.pen, color: UIColor.label, width: 3)
    }
  }

  final class Coordinator: NSObject, PKCanvasViewDelegate {
    @Binding var drawing: PKDrawing
    var lastUndoSignal: Int

    init(drawing: Binding<PKDrawing>, undoSignal: Int) {
      _drawing = drawing
      lastUndoSignal = undoSignal
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
      drawing = canvasView.drawing
    }
  }
}

private struct NativePaperLines: View {
  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Color.white
        Path { path in
          let spacing: CGFloat = 36
          var y = spacing
          while y < geometry.size.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
            y += spacing
          }
        }
        .stroke(Color(hex: 0xE6E6EA), lineWidth: 1)
      }
    }
  }
}

private struct NativeStudioBackdrop: View {
  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(hex: 0xF4F8FF),
          Color(hex: 0xEEF2FF),
          Color(hex: 0xEAF1FF),
          Color(hex: 0xF7F9FF)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      RadialGradient(
        colors: [NativeHealthColor.blue.opacity(0.18), .clear],
        center: .topTrailing,
        startRadius: 20,
        endRadius: 540
      )

      RadialGradient(
        colors: [NativeHealthColor.green.opacity(0.10), .clear],
        center: .bottomLeading,
        startRadius: 20,
        endRadius: 500
      )

      RadialGradient(
        colors: [NativeHealthColor.orange.opacity(0.10), .clear],
        center: .bottomTrailing,
        startRadius: 20,
        endRadius: 520
      )
    }
  }
}

private struct NativeBlueHeroCard<Content: View>: View {
  let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    content
      .padding(26)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background {
        ZStack {
          LinearGradient(
            colors: [
              Color.white.opacity(0.98),
              Color(hex: 0xEEF3FF).opacity(0.98),
              Color(hex: 0xDDE7FF).opacity(0.92)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
          RadialGradient(
            colors: [NativeHealthColor.blue.opacity(0.18), .clear],
            center: .topTrailing,
            startRadius: 10,
            endRadius: 260
          )
          HStack {
            Rectangle()
              .fill(
                LinearGradient(
                  colors: [NativeHealthColor.blue, NativeHealthColor.deepBlue],
                  startPoint: .top,
                  endPoint: .bottom
                )
              )
              .frame(width: 7)
            Spacer()
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
      }
      .overlay(
        RoundedRectangle(cornerRadius: 30, style: .continuous)
          .stroke(NativeHealthColor.boardStroke, lineWidth: 1.1)
      )
      .shadow(color: NativeHealthColor.deepBlue.opacity(0.12), radius: 28, x: 0, y: 18)
  }
}

private struct NativeMemojiAvatar: View {
  let member: NativeTrainerMember
  let size: CGFloat

  var body: some View {
    NativeAvatarImageDataView(
      imageData: member.avatarImageData,
      fallbackName: member.name,
      fallbackSeed: member.avatarSeed,
      fallbackStatusColor: member.statusColor
    )
      .id(member.avatarSeed + (member.avatarImageData == nil ? "-fallback" : "-image"))
      .frame(width: size, height: size)
      .clipShape(Circle())
      .overlay(
        Circle()
          .stroke(Color.white.opacity(0.72), lineWidth: 1)
      )
      .transaction { transaction in
        transaction.animation = nil
      }
  }
}

private struct NativeAvatarImageDataView: View {
  let imageData: Data?
  let fallbackName: String
  let fallbackSeed: String
  var fallbackStatusColor: Color = NativeHealthColor.blue

  var body: some View {
    GeometryReader { geometry in
      let resolvedSize = min(geometry.size.width, geometry.size.height)

      ZStack {
        if let imageData,
           let uiImage = UIImage(data: imageData) {
          Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(width: resolvedSize, height: resolvedSize)
        } else {
          NativeAvatarFallback(
            name: fallbackName,
            seed: fallbackSeed,
            statusColor: fallbackStatusColor,
            size: resolvedSize
          )
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .clipped()
    }
  }
}

private struct NativeAvatarFallback: View {
  let name: String
  let seed: String
  let statusColor: Color
  let size: CGFloat

  init(member: NativeTrainerMember, size: CGFloat) {
    self.name = member.name
    self.seed = member.avatarSeed
    self.statusColor = member.statusColor
    self.size = size
  }

  init(name: String, seed: String, statusColor: Color, size: CGFloat) {
    self.name = name
    self.seed = seed
    self.statusColor = statusColor
    self.size = size
  }

  var body: some View {
    ZStack {
      Circle()
        .fill(
          LinearGradient(
            colors: [palette.backgroundTop, palette.backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )

      RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
        .fill(
          LinearGradient(
            colors: [palette.shirtTop, palette.shirtBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .frame(width: size * 0.58, height: size * 0.34)
        .offset(y: size * 0.29)

      RoundedRectangle(cornerRadius: size * 0.07, style: .continuous)
        .fill(
          LinearGradient(
            colors: [palette.skinTop, palette.skinBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .frame(width: size * 0.18, height: size * 0.18)
        .offset(y: size * 0.10)

      Circle()
        .fill(
          LinearGradient(
            colors: [palette.skinTop, palette.skinBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .frame(width: size * 0.52, height: size * 0.52)
        .offset(y: -size * 0.04)

      Circle()
        .fill(palette.hair)
        .frame(width: size * 0.56, height: size * 0.38)
        .offset(y: -size * 0.19)
        .mask(
          VStack(spacing: 0) {
            Rectangle()
              .frame(height: size * 0.24)
            Spacer(minLength: 0)
          }
        )

      Circle()
        .fill(palette.skinTop)
        .frame(width: size * 0.08, height: size * 0.10)
        .offset(x: -size * 0.28, y: -size * 0.03)
      Circle()
        .fill(palette.skinTop)
        .frame(width: size * 0.08, height: size * 0.10)
        .offset(x: size * 0.28, y: -size * 0.03)

      HStack(spacing: size * 0.16) {
        Circle()
          .fill(Color(hex: 0x232532))
          .frame(width: size * 0.045, height: size * 0.045)
        Circle()
          .fill(Color(hex: 0x232532))
          .frame(width: size * 0.045, height: size * 0.045)
      }
      .offset(y: -size * 0.055)

      HStack(spacing: size * 0.11) {
        Capsule()
          .fill(palette.hair.opacity(0.78))
          .frame(width: size * 0.10, height: size * 0.018)
          .rotationEffect(.degrees(-6))
        Capsule()
          .fill(palette.hair.opacity(0.78))
          .frame(width: size * 0.10, height: size * 0.018)
          .rotationEffect(.degrees(6))
      }
      .offset(y: -size * 0.12)

      Capsule()
        .fill(palette.skinBottom.opacity(0.80))
        .frame(width: size * 0.035, height: size * 0.075)
        .offset(y: -size * 0.005)

      Capsule()
        .fill(palette.mouth)
        .frame(width: size * 0.14, height: size * 0.028)
        .offset(y: size * 0.095)

      HStack(spacing: size * 0.22) {
        Circle()
          .fill(palette.cheek)
          .frame(width: size * 0.075, height: size * 0.045)
        Circle()
          .fill(palette.cheek)
          .frame(width: size * 0.075, height: size * 0.045)
      }
      .offset(y: size * 0.045)

      Text(initial)
        .font(.system(size: size * 0.15, weight: .bold, design: .rounded))
        .foregroundStyle(Color.white)
        .frame(width: size * 0.25, height: size * 0.18)
        .background(statusColor, in: Capsule())
        .offset(y: size * 0.37)
    }
  }

  private var initial: String {
    String(name.trimmedForDisplay.prefix(1))
  }

  private var palette: NativeAvatarPalette {
    NativeAvatarPalette(seed: seed + name)
  }
}

private struct NativeAvatarPalette {
  let backgroundTop: Color
  let backgroundBottom: Color
  let skinTop: Color
  let skinBottom: Color
  let hair: Color
  let cheek: Color
  let mouth: Color
  let shirtTop: Color
  let shirtBottom: Color

  init(seed: String) {
    let palettes: [(UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32)] = [
      (0xF4E8EF, 0xBFC7F0, 0xFFE0C2, 0xE9B98E, 0x33261F, 0xF1A99D, 0xB9545C, 0x2856B8, 0x08285D),
      (0xE7F4EF, 0xB7E0CF, 0xF6C99E, 0xD89B70, 0x191919, 0xE99A91, 0xA94955, 0x19A974, 0x0F6F50),
      (0xFFF0DD, 0xF2C57C, 0xF1B77D, 0xC67B52, 0x4A2A18, 0xE28D85, 0x9C3F4F, 0xE79A37, 0xA75E14),
      (0xEEF3FF, 0xC7D6FF, 0xF7D5B8, 0xD69F75, 0x5B3A2B, 0xF0A6A0, 0xB04D5B, 0x566CC7, 0x283C94),
      (0xF7E8EA, 0xE9BCC4, 0xE7A982, 0xB87555, 0x241A16, 0xD98280, 0x963A3A, 0xD95757, 0x963A3A),
    ]
    let index = abs(seed.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }) % palettes.count
    let palette = palettes[index]
    backgroundTop = Color(hex: palette.0)
    backgroundBottom = Color(hex: palette.1)
    skinTop = Color(hex: palette.2)
    skinBottom = Color(hex: palette.3)
    hair = Color(hex: palette.4)
    cheek = Color(hex: palette.5).opacity(0.58)
    mouth = Color(hex: palette.6)
    shirtTop = Color(hex: palette.7)
    shirtBottom = Color(hex: palette.8)
  }
}

private enum NativeAvatarImageProcessor {
  static func normalizedData(from image: UIImage) -> Data? {
    guard image.size.width > 0, image.size.height > 0 else {
      return nil
    }

    let targetSize = CGSize(width: 512, height: 512)
    let rendererFormat = UIGraphicsImageRendererFormat.default()
    rendererFormat.scale = 1

    let renderer = UIGraphicsImageRenderer(size: targetSize, format: rendererFormat)
    return renderer.pngData { _ in
      let scale = max(targetSize.width / image.size.width, targetSize.height / image.size.height)
      let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
      let drawOrigin = CGPoint(
        x: (targetSize.width - drawSize.width) / 2,
        y: (targetSize.height - drawSize.height) / 2
      )
      image.draw(in: CGRect(origin: drawOrigin, size: drawSize))
    }
  }
}

private enum NativeAutomaticMemojiAvatarProvider {
  static func avatarImageData(name: String, email: String = "") async throws -> Data {
    let seed = stableSeed(name: name, email: email)
    guard let url = URL(string: "https://www.tapback.co/api/avatar/\(seed).webp") else {
      throw URLError(.badURL)
    }

    var request = URLRequest(url: url)
    request.cachePolicy = .returnCacheDataElseLoad
    request.timeoutInterval = 8

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse,
          (200..<300).contains(httpResponse.statusCode) else {
      throw URLError(.badServerResponse)
    }

    guard let image = UIImage(data: data),
          let normalizedData = NativeAvatarImageProcessor.normalizedData(from: image) else {
      throw URLError(.cannotDecodeContentData)
    }

    return normalizedData
  }

  private static func stableSeed(name: String, email: String) -> String {
    let rawSeed = "\(name.trimmedForDisplay)|\(email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    let hash = rawSeed.unicodeScalars.reduce(UInt64(14_695_981_039_346_656_037)) { value, scalar in
      (value ^ UInt64(scalar.value)) &* 1_099_511_628_211
    }
    return String(format: "dfet-%016llx", hash)
  }
}

private struct NativeMemojiKeyboardSelectionSheet: View {
  let onSelect: (Data) -> Void
  let onError: (String) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var selectedImage: UIImage?
  @State private var selectedType: NativeMemojiCaptureImageType?
  @State private var isEditable = true
  @State private var message = "미모지 스티커를 선택하세요."

  var body: some View {
    NavigationView {
      VStack(spacing: 18) {
        VStack(spacing: 8) {
          NativeMemojiKeyboardCaptureRepresentable(
            image: $selectedImage,
            imageType: $selectedType,
            isEditable: $isEditable,
            maxLetters: 2,
            textColor: .white
          ) { image, type in
            selectedImage = image
            selectedType = type
            switch type {
            case .memoji:
              message = "선택한 미모지를 프로필로 적용할 수 있습니다."
            case .emoji:
              message = "이모지가 선택되었습니다. 미모지 스티커를 선택하면 실제 미모지 이미지로 저장됩니다."
            case .text:
              message = "텍스트가 선택되었습니다. 미모지 스티커를 선택하세요."
            }
          }
          .frame(width: 168, height: 168)
          .background(NativeHealthColor.subPanel, in: Circle())
          .overlay(
            Circle()
              .stroke(NativeHealthColor.border, lineWidth: 1)
          )

          Text(message)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(NativeHealthColor.secondaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 26)
        }

        NativeHealthCard {
          VStack(alignment: .leading, spacing: 10) {
            Label("iOS 미모지 키보드", systemImage: "face.smiling")
              .font(.system(size: 18, weight: .bold))
              .foregroundStyle(NativeHealthColor.primaryText)
            Text("원을 탭하면 iOS 키보드가 열립니다. 키보드의 Memoji 스티커를 선택하면 이미지로 변환됩니다.")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(NativeHealthColor.secondaryText)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        Spacer(minLength: 0)
      }
      .padding(24)
      .background(NativeHealthColor.background.ignoresSafeArea())
      .navigationTitle("미모지 선택")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("취소") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("적용") {
            saveSelectedImage()
          }
          .font(.system(size: 16, weight: .bold))
          .disabled(selectedImage == nil)
        }
      }
    }
  }

  private func saveSelectedImage() {
    guard let selectedImage,
          let imageData = NativeAvatarImageProcessor.normalizedData(from: selectedImage) else {
      onError("선택한 미모지 이미지를 저장할 수 없습니다.")
      return
    }

    onSelect(imageData)
    dismiss()
  }
}

private enum NativeMemojiCaptureImageType: Equatable {
  case memoji
  case emoji
  case text(count: Int, value: String)
}

private struct NativeMemojiKeyboardCaptureRepresentable: UIViewRepresentable {
  @Binding var image: UIImage?
  @Binding var imageType: NativeMemojiCaptureImageType?
  @Binding var isEditable: Bool
  let maxLetters: Int
  let textColor: UIColor?
  let onChange: (UIImage?, NativeMemojiCaptureImageType) -> Void

  func makeUIView(context: Context) -> NativeMemojiKeyboardCaptureView {
    let view = NativeMemojiKeyboardCaptureView()
    view.delegate = context.coordinator
    view.isEditable = isEditable
    view.maxLetters = maxLetters
    view.textColor = textColor
    return view
  }

  func updateUIView(_ uiView: NativeMemojiKeyboardCaptureView, context: Context) {
    uiView.image = image
    uiView.isEditable = isEditable
    uiView.maxLetters = maxLetters
    uiView.textColor = textColor
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  final class Coordinator: NSObject, NativeMemojiKeyboardCaptureViewDelegate {
    var parent: NativeMemojiKeyboardCaptureRepresentable

    init(parent: NativeMemojiKeyboardCaptureRepresentable) {
      self.parent = parent
    }

    func didUpdateImage(image: UIImage?, type: NativeMemojiCaptureImageType) {
      DispatchQueue.main.async {
        self.parent.image = image
        self.parent.imageType = type
        self.parent.onChange(image, type)
      }
    }
  }
}

private protocol NativeMemojiKeyboardCaptureViewDelegate: AnyObject {
  func didUpdateImage(image: UIImage?, type: NativeMemojiCaptureImageType)
}

private final class NativeMemojiKeyboardCaptureView: UIView, NativeMemojiCaptureTextViewDelegate {
  weak var delegate: NativeMemojiKeyboardCaptureViewDelegate?

  var isEditable: Bool = true {
    didSet {
      inputWrapper.isUserInteractionEnabled = isEditable
    }
  }

  var image: UIImage? {
    didSet {
      imageView.image = image
    }
  }

  var maxLetters: Int {
    get { inputWrapper.textView.maxLetters }
    set { inputWrapper.textView.maxLetters = newValue }
  }

  var textColor: UIColor? {
    get { inputWrapper.textView.textColor }
    set { inputWrapper.textView.textColor = newValue }
  }

  private let imageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .scaleAspectFit
    return imageView
  }()

  private let inputWrapper = NativeMemojiCaptureTextViewWrapper()

  override init(frame: CGRect) {
    super.init(frame: frame)
    commonInit()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    commonInit()
  }

  private func commonInit() {
    backgroundColor = .clear
    inputWrapper.textView.memojiDelegate = self

    addSubview(inputWrapper)
    inputWrapper.translatesAutoresizingMaskIntoConstraints = false

    addSubview(imageView)
    imageView.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      inputWrapper.leadingAnchor.constraint(equalTo: leadingAnchor),
      inputWrapper.trailingAnchor.constraint(equalTo: trailingAnchor),
      inputWrapper.topAnchor.constraint(equalTo: topAnchor),
      inputWrapper.bottomAnchor.constraint(equalTo: bottomAnchor),
      imageView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
      imageView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
      imageView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
      imageView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),
    ])
  }

  func memojiChanged(image: UIImage?, type: NativeMemojiCaptureImageType) {
    self.image = image
    delegate?.didUpdateImage(image: image, type: type)
  }
}

private final class NativeMemojiCaptureTextViewWrapper: UIView {
  let textView = NativeMemojiCaptureTextView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    commonInit()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    commonInit()
  }

  @objc private func didTapView() {
    if textView.isFirstResponder {
      textView.resignFirstResponder()
    } else {
      textView.becomeFirstResponder()
    }
  }

  private func commonInit() {
    let tap = UITapGestureRecognizer(target: self, action: #selector(didTapView))
    addGestureRecognizer(tap)
    textView.isUserInteractionEnabled = false

    addSubview(textView)
    textView.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      textView.leadingAnchor.constraint(equalTo: leadingAnchor),
      textView.trailingAnchor.constraint(equalTo: trailingAnchor),
      textView.topAnchor.constraint(equalTo: topAnchor),
      textView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }
}

private protocol NativeMemojiCaptureTextViewDelegate: AnyObject {
  func memojiChanged(image: UIImage?, type: NativeMemojiCaptureImageType)
}

// Adapted from emrearmagan/MemojiView (MIT). The core idea is to let iOS'
// emoji keyboard produce a Memoji sticker attachment, then convert that
// attachment into a UIImage for storage in the member profile.
private final class NativeMemojiCaptureTextView: UITextView {
  weak var memojiDelegate: NativeMemojiCaptureTextViewDelegate?

  var maxLetters = 2

  override var textInputMode: UITextInputMode? {
    if let emojiKeyboard = UITextInputMode.activeInputModes.first(where: { $0.primaryLanguage == "emoji" }) {
      return emojiKeyboard
    }
    return super.textInputMode
  }

  override var textInputContextIdentifier: String? {
    ""
  }

  override var textColor: UIColor? {
    get { super.textColor }
    set {
      super.textColor = .clear
      if let newValue, newValue != .clear {
        renderedTextColor = newValue
      }
    }
  }

  private var renderedTextColor: UIColor = .white
  private let memojiPasteboard = UIPasteboard(
    name: UIPasteboard.Name(rawValue: "DFETNativeMemojiPasteboard"),
    create: true
  )
  private var isInternalUpdate = false

  override init(frame: CGRect, textContainer: NSTextContainer?) {
    super.init(frame: frame, textContainer: textContainer)
    commonInit()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    commonInit()
  }

  private func commonInit() {
    delegate = self
    backgroundColor = .clear
    tintColor = .clear
    textColor = .clear
    autocorrectionType = .no
    returnKeyType = .done
    allowsEditingTextAttributes = true

    if #available(iOS 18.0, *) {
      supportsAdaptiveImageGlyph = true
    }

    if #available(iOS 14.0, *) {
      addDoneToolbar()
    }
  }

  @available(iOS 14.0, *)
  private func addDoneToolbar() {
    let toolbar = UIToolbar()
    toolbar.sizeToFit()
    let doneButton = UIBarButtonItem(
      barButtonSystemItem: .done,
      target: self,
      action: #selector(doneButtonTapped)
    )
    let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    toolbar.items = [spacer, doneButton]
    inputAccessoryView = toolbar
  }

  @objc private func doneButtonTapped() {
    resignFirstResponder()
  }

  override func paste(_ sender: Any?) {
    super.paste(sender)
    if let image = UIPasteboard.general.image {
      memojiPasteboard?.image = image
      text = ""
    }
  }

  override func caretRect(for position: UITextPosition) -> CGRect {
    .zero
  }

  override func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
    []
  }

  private func memojiImage(in attributedText: NSAttributedString?) -> UIImage? {
    if #available(iOS 18.0, *) {
      guard let attachment = firstAttachment(in: attributedText) else {
        return nil
      }

      if let image = attachment.image {
        return image
      }

      if let image = attachment.image(
        forBounds: attachment.bounds,
        textContainer: nil,
        characterIndex: 0
      ) {
        return image
      }

      if let imageData = attachment.fileWrapper?.regularFileContents {
        return UIImage(data: imageData)
      }

      return nil
    }

    return memojiPasteboard?.image
  }

  @available(iOS 18.0, *)
  private func firstAttachment(in attributedText: NSAttributedString?) -> NSTextAttachment? {
    guard let attributedText else { return nil }

    var adaptiveAttachment: NSTextAttachment?
    attributedText.enumerateAttribute(
      .adaptiveImageGlyph,
      in: NSRange(location: 0, length: attributedText.length),
      options: []
    ) { value, _, stop in
      if let glyph = value as? NSAdaptiveImageGlyph {
        let attachment = NSTextAttachment()
        attachment.image = UIImage(data: glyph.imageContent)
        adaptiveAttachment = attachment
        stop.pointee = true
      }
    }

    if let adaptiveAttachment {
      return adaptiveAttachment
    }

    var attachment: NSTextAttachment?
    attributedText.enumerateAttribute(
      .attachment,
      in: NSRange(location: 0, length: attributedText.length),
      options: []
    ) { value, _, stop in
      if let textAttachment = value as? NSTextAttachment {
        attachment = textAttachment
        stop.pointee = true
      }
    }
    return attachment
  }
}

extension NativeMemojiCaptureTextView: UITextViewDelegate {
  func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
    if text == "\n" {
      textView.resignFirstResponder()
      return false
    }

    if text.isNativeSingleEmoji {
      guard textView.text == text else {
        textView.text = ""
        return true
      }
      return false
    }

    if textView.text.isNativeSingleEmoji {
      textView.text = ""
    }

    return textView.text.utf16.count + text.utf16.count <= maxLetters
  }

  func textViewDidBeginEditing(_ textView: UITextView) {
    textView.text = ""
  }

  func textViewDidEndEditing(_ textView: UITextView) {
    textView.text = ""
  }

  func textViewDidChangeSelection(_ textView: UITextView) {
    if isInternalUpdate {
      return
    }

    guard var text = textView.text, !text.isEmpty else {
      memojiDelegate?.memojiChanged(image: nil, type: .text(count: 0, value: ""))
      return
    }

    if let memoji = memojiImage(in: textView.attributedText) {
      memojiDelegate?.memojiChanged(image: memoji, type: .memoji)
      memojiPasteboard?.image = nil
      isInternalUpdate = true
      textView.text = ""
      isInternalUpdate = false
      return
    }

    let counter = text.count
    let isSingleEmoji = text.isNativeSingleEmoji
    if counter < maxLetters, !isSingleEmoji {
      let missingLetters = maxLetters - counter
      let padding = String(repeating: " ", count: (missingLetters + 1) / 2)
      text = padding + text + padding
    }

    let image = text.nativeEmojiImage(color: renderedTextColor)
    let type: NativeMemojiCaptureImageType = isSingleEmoji ? .emoji : .text(count: counter, value: text)
    memojiDelegate?.memojiChanged(image: image, type: type)

    isInternalUpdate = true
    textView.text = ""
    isInternalUpdate = false
  }
}

private extension Character {
  var isNativeSimpleEmoji: Bool {
    guard let firstScalar = unicodeScalars.first else { return false }
    return firstScalar.properties.isEmoji && firstScalar.value > 0x238C
  }

  var isNativeCombinedEmoji: Bool {
    unicodeScalars.count > 1 && unicodeScalars.first?.properties.isEmoji == true
  }

  var isNativeEmoji: Bool {
    isNativeSimpleEmoji || isNativeCombinedEmoji
  }
}

private extension String {
  var isNativeSingleEmoji: Bool {
    count == 1 && containsNativeEmoji
  }

  var containsNativeEmoji: Bool {
    contains { $0.isNativeEmoji }
  }

  func nativeEmojiImage(size: CGFloat = 98, color: UIColor = .white) -> UIImage? {
    let nsString = self as NSString
    let font = UIFont.systemFont(ofSize: size)
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: color,
    ]
    let textSize = nsString.size(withAttributes: attributes)

    guard textSize.width > 0, textSize.height > 0 else {
      return nil
    }

    let renderer = UIGraphicsImageRenderer(size: textSize)
    return renderer.image { context in
      UIColor.clear.set()
      context.fill(CGRect(origin: .zero, size: textSize))
      nsString.draw(at: .zero, withAttributes: attributes)
    }
  }
}

private struct NativePhotoLibraryImagePicker: UIViewControllerRepresentable {
  let onImageData: (Data) -> Void
  let onError: (String) -> Void

  func makeUIViewController(context: Context) -> PHPickerViewController {
    var configuration = PHPickerConfiguration()
    configuration.filter = .images
    configuration.selectionLimit = 1
    configuration.preferredAssetRepresentationMode = .current

    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = context.coordinator
    return picker
  }

  func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  final class Coordinator: NSObject, PHPickerViewControllerDelegate {
    let parent: NativePhotoLibraryImagePicker

    init(parent: NativePhotoLibraryImagePicker) {
      self.parent = parent
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
      picker.dismiss(animated: true)

      guard let provider = results.first?.itemProvider else {
        return
      }

      guard provider.canLoadObject(ofClass: UIImage.self) else {
        parent.onError("선택한 항목에서 이미지를 읽을 수 없습니다.")
        return
      }

      provider.loadObject(ofClass: UIImage.self) { object, _ in
        DispatchQueue.main.async {
          guard let image = object as? UIImage,
                let imageData = NativeAvatarImageProcessor.normalizedData(from: image) else {
            self.parent.onError("프로필 이미지 변환에 실패했습니다.")
            return
          }
          self.parent.onImageData(imageData)
        }
      }
    }
  }
}

private struct NativeContactImagePicker: UIViewControllerRepresentable {
  let onImageData: (Data) -> Void
  let onError: (String) -> Void

  func makeUIViewController(context: Context) -> CNContactPickerViewController {
    let picker = CNContactPickerViewController()
    picker.delegate = context.coordinator
    return picker
  }

  func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  final class Coordinator: NSObject, CNContactPickerDelegate {
    let parent: NativeContactImagePicker

    init(parent: NativeContactImagePicker) {
      self.parent = parent
    }

    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
      guard let rawData = imageData(for: contact),
            let image = UIImage(data: rawData),
            let imageData = NativeAvatarImageProcessor.normalizedData(from: image) else {
        parent.onError("선택한 연락처에 가져올 프로필 이미지가 없습니다.")
        return
      }

      parent.onImageData(imageData)
    }

    private func imageData(for contact: CNContact) -> Data? {
      if contact.isKeyAvailable(CNContactImageDataKey),
         let imageData = contact.imageData {
        return imageData
      }

      if contact.isKeyAvailable(CNContactThumbnailImageDataKey),
         let thumbnailData = contact.thumbnailImageData {
        return thumbnailData
      }

      let keys: [CNKeyDescriptor] = [
        CNContactImageDataKey as CNKeyDescriptor,
        CNContactThumbnailImageDataKey as CNKeyDescriptor,
      ]

      let store = CNContactStore()
      guard let fetchedContact = try? store.unifiedContact(
        withIdentifier: contact.identifier,
        keysToFetch: keys
      ) else {
        return nil
      }

      return fetchedContact.imageData ?? fetchedContact.thumbnailImageData
    }
  }
}

private struct NativeMemberSoapGrassView: View {
  let member: NativeTrainerMember
  @Binding var selectedDate: Date
  let datesWithDrafts: Set<Date>

  private let columns = Array(repeating: GridItem(.fixed(14), spacing: 5), count: 14)

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      LazyVGrid(columns: columns, alignment: .leading, spacing: 5) {
        ForEach(timelineDates, id: \.self) { date in
          let hasDraft = datesWithDrafts.contains(Calendar.current.startOfDay(for: date))
          let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
          Button {
            selectedDate = Calendar.current.startOfDay(for: date)
          } label: {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
              .fill(cellColor(hasDraft: hasDraft, isSelected: isSelected))
              .frame(width: 14, height: 14)
              .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                  .stroke(isSelected ? NativeHealthColor.deepBlue : Color.clear, lineWidth: 1.5)
              )
          }
          .buttonStyle(.plain)
        }
      }

      HStack(spacing: 8) {
        Text("기록 없음")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(NativeHealthColor.secondaryText)
        RoundedRectangle(cornerRadius: 3).fill(NativeHealthColor.subPanel).frame(width: 14, height: 14)
        RoundedRectangle(cornerRadius: 3).fill(NativeHealthColor.green.opacity(0.42)).frame(width: 14, height: 14)
        RoundedRectangle(cornerRadius: 3).fill(NativeHealthColor.green.opacity(0.88)).frame(width: 14, height: 14)
        Text("SOAP 작성")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(NativeHealthColor.secondaryText)
      }
    }
  }

  private var timelineDates: [Date] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    return (0..<70).reversed().compactMap { offset in
      calendar.date(byAdding: .day, value: -offset, to: today)
    }
  }

  private func cellColor(hasDraft: Bool, isSelected: Bool) -> Color {
    if isSelected && hasDraft {
      return NativeHealthColor.green
    }
    if hasDraft {
      return NativeHealthColor.green.opacity(0.72)
    }
    if isSelected {
      return NativeHealthColor.blue.opacity(0.24)
    }
    return NativeHealthColor.subPanel
  }
}

private struct NativeHeroMetric: View {
  let title: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title)
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .foregroundStyle(NativeHealthColor.secondaryText)
      Text(value)
        .font(.system(size: 20, weight: .bold, design: .rounded))
        .foregroundStyle(NativeHealthColor.primaryText)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(NativeHealthColor.subPanel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(NativeHealthColor.border.opacity(0.70), lineWidth: 1)
    )
  }
}

private struct NativeBoardPanel<Content: View>: View {
  let title: String
  let subtitle: String
  let content: Content

  init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.subtitle = subtitle
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 15) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.system(size: 20, weight: .bold, design: .rounded))
          .foregroundStyle(NativeHealthColor.primaryText)
        Text(subtitle)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(NativeHealthColor.secondaryText)
      }

      content
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(
          LinearGradient(
            colors: [NativeHealthColor.panelTop, NativeHealthColor.panelBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
    }
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(NativeHealthColor.boardStroke, lineWidth: 1.1)
    )
    .shadow(color: NativeHealthColor.deepBlue.opacity(0.10), radius: 24, x: 0, y: 14)
    .shadow(color: Color.white.opacity(0.80), radius: 1, x: 0, y: -1)
  }
}

private struct NativeActionRow: View {
  let step: String
  let title: String
  let subtitle: String
  let symbol: String
  let active: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Text(step)
          .font(.system(size: 13, weight: .bold, design: .rounded))
          .foregroundStyle(active ? Color.white : NativeHealthColor.blue)
          .frame(width: 30, height: 30)
          .background(active ? NativeHealthColor.blue : NativeHealthColor.blue.opacity(0.12), in: Circle())

        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(NativeHealthColor.primaryText)
          Text(subtitle)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(NativeHealthColor.secondaryText)
            .lineLimit(1)
        }

        Spacer()

        Image(systemName: symbol)
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(active ? NativeHealthColor.blue : NativeHealthColor.secondaryText)
      }
        .padding(12)
        .background(
          active ? Color.white.opacity(0.96) : NativeHealthColor.subPanel.opacity(0.78),
          in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(active ? NativeHealthColor.blue.opacity(0.20) : NativeHealthColor.border.opacity(0.60), lineWidth: 1)
        )
    }
    .buttonStyle(.plain)
  }
}

private struct NativeSessionMetricCard: View {
  let title: String
  let value: String
  let unit: String
  let symbol: String
  var color: Color = NativeHealthColor.blue

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Image(systemName: symbol)
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(color)
          .frame(width: 38, height: 38)
          .background(
            LinearGradient(
              colors: [color.opacity(0.18), color.opacity(0.07)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
          )
        Spacer()
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(NativeHealthColor.secondaryText)
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text(value)
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundStyle(NativeHealthColor.primaryText)
          Text(unit)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(NativeHealthColor.secondaryText)
        }
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      LinearGradient(
        colors: [Color.white.opacity(0.92), color.opacity(0.055)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      in: RoundedRectangle(cornerRadius: 22, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .stroke(color.opacity(0.22), lineWidth: 1)
    )
  }
}

private struct NativeMiniTrendCard: View {
  let title: String
  let value: String
  let caption: String
  let points: [Double]
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Text(title)
          .font(.system(size: 13, weight: .bold, design: .rounded))
          .foregroundStyle(NativeHealthColor.secondaryText)
        Spacer()
        Text(value)
          .font(.system(size: 19, weight: .bold, design: .rounded))
          .foregroundStyle(NativeHealthColor.primaryText)
      }

      NativeSparkline(points: points, color: color)
        .frame(height: 54)

      Text(caption)
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundStyle(NativeHealthColor.secondaryText)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(
      LinearGradient(
        colors: [Color.white.opacity(0.92), color.opacity(0.055)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      in: RoundedRectangle(cornerRadius: 18, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(color.opacity(0.22), lineWidth: 1)
    )
  }
}

private struct NativeDecisionCard: View {
  let title: String
  let value: String
  let caption: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Circle()
          .fill(color.opacity(0.14))
          .frame(width: 34, height: 34)
          .overlay(
            Circle()
              .fill(color)
              .frame(width: 9, height: 9)
          )
        Spacer()
      }
      Text(title)
        .font(.system(size: 13, weight: .bold, design: .rounded))
        .foregroundStyle(NativeHealthColor.secondaryText)
      Text(value)
        .font(.system(size: 28, weight: .bold, design: .rounded))
        .foregroundStyle(NativeHealthColor.primaryText)
      Text(caption)
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundStyle(NativeHealthColor.secondaryText)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(
      LinearGradient(
        colors: [Color.white.opacity(0.92), color.opacity(0.06)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      in: RoundedRectangle(cornerRadius: 18, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(color.opacity(0.24), lineWidth: 1)
    )
  }
}

private struct NativeSparkline: View {
  let points: [Double]
  let color: Color

  var body: some View {
    GeometryReader { geometry in
      let rect = CGRect(origin: .zero, size: geometry.size)

      ZStack(alignment: .bottomLeading) {
        Path { path in
          path.move(to: CGPoint(x: 0, y: rect.height * 0.72))
          path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.72))
        }
        .stroke(NativeHealthColor.border, style: StrokeStyle(lineWidth: 1, dash: [4, 5]))

        sparklinePath(rect: rect)
          .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

        if let lastPoint = lastPoint(rect: rect) {
          Circle()
            .fill(Color.white)
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(color, lineWidth: 2))
            .position(lastPoint)
        }
      }
    }
  }

  private func sparklinePath(rect: CGRect) -> Path {
    var path = Path()
    guard !points.isEmpty else { return path }
    for item in points.enumerated() {
      let point = point(at: item.offset, value: item.element, count: points.count, rect: rect)
      if item.offset == 0 {
        path.move(to: point)
      } else {
        path.addLine(to: point)
      }
    }
    return path
  }

  private func lastPoint(rect: CGRect) -> CGPoint? {
    guard let last = points.last else { return nil }
    return point(at: points.count - 1, value: last, count: points.count, rect: rect)
  }

  private func point(at index: Int, value: Double, count: Int, rect: CGRect) -> CGPoint {
    let clamped = min(max(value, 0), 1)
    let x = count <= 1 ? rect.minX : rect.minX + rect.width * CGFloat(index) / CGFloat(count - 1)
    let y = rect.maxY - rect.height * CGFloat(clamped)
    return CGPoint(x: x, y: y)
  }
}

private struct NativeReadinessRow: View {
  let title: String
  let value: String
  let progress: Double

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(title)
          .font(.system(size: 14, weight: .bold, design: .rounded))
          .foregroundStyle(NativeHealthColor.primaryText)
        Spacer()
        Text(value)
          .font(.system(size: 12, weight: .bold, design: .rounded))
          .foregroundStyle(NativeHealthColor.blue)
      }

      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(NativeHealthColor.green.opacity(0.11))
          Capsule()
            .fill(
              LinearGradient(
                colors: [NativeHealthColor.green, NativeHealthColor.blue],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .frame(width: geometry.size.width * min(max(progress, 0), 1))
        }
      }
      .frame(height: 8)
    }
    .padding(12)
    .background(NativeHealthColor.subPanel, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 15, style: .continuous)
        .stroke(NativeHealthColor.border.opacity(0.72), lineWidth: 1)
    )
  }
}

private struct NativeRiskItem: View {
  let title: String
  let value: String
  let color: Color

  var body: some View {
    HStack(spacing: 10) {
      Circle()
        .fill(color.opacity(0.15))
        .frame(width: 32, height: 32)
        .overlay(
          Circle()
            .fill(color)
            .frame(width: 8, height: 8)
        )

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 13, weight: .bold, design: .rounded))
          .foregroundStyle(NativeHealthColor.primaryText)
        Text(value)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(NativeHealthColor.secondaryText)
          .lineLimit(1)
      }

      Spacer()
    }
    .padding(12)
    .background(
      LinearGradient(
        colors: [Color.white.opacity(0.92), color.opacity(0.055)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      in: RoundedRectangle(cornerRadius: 15, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 15, style: .continuous)
        .stroke(color.opacity(0.18), lineWidth: 1)
    )
  }
}

private struct NativeSessionNoteTile: View {
  let title: String
  let value: String
  let symbol: String

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Image(systemName: symbol)
        .font(.system(size: 17, weight: .bold))
        .foregroundStyle(NativeHealthColor.blue)
        .frame(width: 36, height: 36)
        .background(NativeHealthColor.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.system(size: 12, weight: .bold, design: .rounded))
          .foregroundStyle(NativeHealthColor.secondaryText)
        Text(value)
          .font(.system(size: 15, weight: .bold, design: .rounded))
          .foregroundStyle(NativeHealthColor.primaryText)
          .lineLimit(2)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(NativeHealthColor.subPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(NativeHealthColor.border.opacity(0.72), lineWidth: 1)
    )
  }
}

private struct NativeReportMemberRow: View {
  let member: NativeTrainerMember

  var body: some View {
    HStack(spacing: 12) {
      NativeMemojiAvatar(member: member, size: 42)

      VStack(alignment: .leading, spacing: 4) {
        Text(member.name)
          .font(.system(size: 15, weight: .bold, design: .rounded))
          .foregroundStyle(NativeHealthColor.primaryText)
        Text(member.signal)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(NativeHealthColor.secondaryText)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 4) {
        Text("\(member.progress)%")
          .font(.system(size: 14, weight: .bold, design: .rounded))
          .foregroundStyle(NativeHealthColor.blue)
        Text(member.riskLabel)
          .font(.system(size: 11, weight: .bold, design: .rounded))
          .foregroundStyle(member.statusColor)
      }
    }
    .padding(12)
    .background(NativeHealthColor.subPanel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(member.statusColor.opacity(0.18), lineWidth: 1)
    )
  }
}

private struct NativeHealthCard<Content: View>: View {
  let content: Content
  let padding: CGFloat

  init(padding: CGFloat = 22, @ViewBuilder content: () -> Content) {
    self.padding = padding
    self.content = content()
  }

  var body: some View {
    content
      .padding(padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        NativeHealthColor.card,
        in: RoundedRectangle(cornerRadius: 22, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .stroke(NativeHealthColor.border, lineWidth: 0.8)
      )
      .shadow(color: Color.black.opacity(0.04), radius: 18, x: 0, y: 8)
  }
}

private struct NativeMetricTile: View {
  let title: String
  let value: String
  let unit: String
  let symbol: String
  let color: Color

  var body: some View {
    NativeHealthCard {
      VStack(alignment: .leading, spacing: 18) {
        HStack {
          Image(systemName: symbol)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(color)
          Spacer()
          Circle()
            .fill(color)
            .frame(width: 8, height: 8)
        }

        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(NativeHealthColor.secondaryText)
          HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
              .font(.system(size: 34, weight: .bold))
              .foregroundStyle(NativeHealthColor.primaryText)
            if !unit.isEmpty {
              Text(unit)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(NativeHealthColor.secondaryText)
            }
          }
        }
      }
    }
  }
}

private struct NativeIconSquare: View {
  let systemName: String
  let color: Color

  var body: some View {
    Image(systemName: systemName)
      .font(.system(size: 24, weight: .semibold))
      .foregroundStyle(color)
      .frame(width: 56, height: 56)
      .background(
        LinearGradient(
          colors: [color.opacity(0.18), color.opacity(0.07)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
      )
  }

}

private struct NativeStatusCapsule: View {
  let text: String
  let color: Color

  var body: some View {
    Text(text)
      .font(.system(size: 13, weight: .bold))
      .foregroundStyle(color)
      .padding(.horizontal, 11)
      .padding(.vertical, 7)
      .background(
        LinearGradient(
          colors: [color.opacity(0.18), color.opacity(0.07)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        in: Capsule()
      )
      .overlay(
        Capsule()
          .stroke(color.opacity(0.18), lineWidth: 1)
      )
  }
}

private struct NativeLegend: View {
  let label: String
  let color: Color

  var body: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(color)
        .frame(width: 8, height: 8)
      Text(label)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(NativeHealthColor.secondaryText)
    }
  }
}

private struct NativeMemberSignalRow: View {
  let member: NativeTrainerMember

  var body: some View {
    HStack(spacing: 11) {
      NativeMemojiAvatar(member: member, size: 42)

      VStack(alignment: .leading, spacing: 3) {
        Text(member.name)
          .font(.system(size: 15, weight: .semibold))
        Text(member.signal)
          .font(.system(size: 13))
          .foregroundStyle(NativeHealthColor.secondaryText)
      }

      Spacer()

      Text(member.pain + "/10")
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(member.statusColor)
    }
  }
}

private struct NativeModeCard: View {
  let title: String
  let subtitle: String
  let symbol: String

  var body: some View {
    NativeHealthCard {
      VStack(alignment: .leading, spacing: 14) {
        Image(systemName: symbol)
          .font(.system(size: 24, weight: .semibold))
          .foregroundStyle(NativeHealthColor.blue)
        Text(title)
          .font(.system(size: 20, weight: .bold))
        Text(subtitle)
          .font(.system(size: 14))
          .foregroundStyle(NativeHealthColor.secondaryText)
      }
    }
  }
}

private struct NativeLineChart: View {
  let painPoints: [Double]
  let completionPoints: [Double]
  var labels: [String]? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 14) {
        NativeLegend(label: "통증", color: NativeHealthColor.purple)
        NativeLegend(label: "완료율", color: NativeHealthColor.blue)
        Spacer()
        Text(chartSummary)
          .font(.system(size: 12, weight: .bold, design: .rounded))
          .foregroundStyle(NativeHealthColor.deepBlue)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(NativeHealthColor.blue.opacity(0.10), in: Capsule())
      }

      GeometryReader { geometry in
        let size = geometry.size
        let plotRect = CGRect(
          x: 34,
          y: 8,
          width: max(20, size.width - 46),
          height: max(20, size.height - 34)
        )

        ZStack(alignment: .topLeading) {
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.46))
            .frame(width: plotRect.width, height: plotRect.height)
            .position(x: plotRect.midX, y: plotRect.midY)

          ForEach(0..<3, id: \.self) { index in
            let y = plotRect.minY + plotRect.height * CGFloat(index) / 2
            Path { path in
              path.move(to: CGPoint(x: plotRect.minX, y: y))
              path.addLine(to: CGPoint(x: plotRect.maxX, y: y))
            }
            .stroke(NativeHealthColor.border, lineWidth: 1)

            Text(["10", "5", "0"][index])
              .font(.system(size: 10, weight: .bold, design: .rounded))
              .foregroundStyle(NativeHealthColor.secondaryText.opacity(0.76))
              .position(x: 13, y: y)
          }

          areaPath(points: completionPoints.map { $0 / 100 }, rect: plotRect)
            .fill(
              LinearGradient(
                colors: [NativeHealthColor.blue.opacity(0.18), NativeHealthColor.blue.opacity(0.02)],
                startPoint: .top,
                endPoint: .bottom
              )
            )

          chartPath(points: completionPoints.map { $0 / 100 }, rect: plotRect)
            .stroke(NativeHealthColor.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

          chartPath(points: painPoints.map { $0 / 10 }, rect: plotRect)
            .stroke(NativeHealthColor.purple, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

          ForEach(Array(painPoints.enumerated()), id: \.offset) { item in
            let point = chartPoint(index: item.offset, value: item.element / 10, count: painPoints.count, rect: plotRect)
            Circle()
              .fill(Color.white)
              .frame(width: item.offset == painPoints.count - 1 ? 11 : 8, height: item.offset == painPoints.count - 1 ? 11 : 8)
              .overlay(Circle().stroke(NativeHealthColor.purple, lineWidth: 2))
              .position(point)
          }

          ForEach(Array(completionPoints.enumerated()), id: \.offset) { item in
            let point = chartPoint(index: item.offset, value: item.element / 100, count: completionPoints.count, rect: plotRect)
            Circle()
              .fill(NativeHealthColor.blue)
              .frame(width: item.offset == completionPoints.count - 1 ? 10 : 7, height: item.offset == completionPoints.count - 1 ? 10 : 7)
              .position(point)
          }

          ForEach(Array(chartLabels.enumerated()), id: \.offset) { item in
            Text(item.element)
              .font(.system(size: 10, weight: .semibold, design: .rounded))
              .foregroundStyle(NativeHealthColor.secondaryText.opacity(0.74))
              .position(
                x: chartPoint(index: item.offset, value: 0, count: chartLabels.count, rect: plotRect).x,
                y: plotRect.maxY + 17
              )
          }
        }
      }
    }
  }

  private var chartLabels: [String] {
    if let labels {
      return labels
    }
    let count = max(painPoints.count, completionPoints.count)
    let labels = ["3/18", "3/25", "4/1", "4/8", "4/15", "4/22", "4/29", "5/6"]
    if count <= labels.count {
      return Array(labels.suffix(count))
    }
    return (1...count).map { "\($0)회" }
  }

  private var chartSummary: String {
    guard let firstPain = painPoints.first,
          let lastPain = painPoints.last,
          let lastCompletion = completionPoints.last else {
      return "기록 없음"
    }
    let painDelta = lastPain - firstPain
    let painText = painDelta <= 0
      ? String(format: "%.1f↓", abs(painDelta))
      : String(format: "%.1f↑", painDelta)
    return "통증 \(painText) · 완료 \(Int(lastCompletion))%"
  }

  private func chartPath(points: [Double], rect: CGRect) -> Path {
    var path = Path()
    guard !points.isEmpty else { return path }
    for item in points.enumerated() {
      let point = chartPoint(index: item.offset, value: item.element, count: points.count, rect: rect)
      if item.offset == 0 {
        path.move(to: point)
      } else {
        path.addLine(to: point)
      }
    }
    return path
  }

  private func areaPath(points: [Double], rect: CGRect) -> Path {
    var path = chartPath(points: points, rect: rect)
    guard !points.isEmpty else { return path }
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.closeSubpath()
    return path
  }

  private func chartPoint(index: Int, value: Double, count: Int, rect: CGRect) -> CGPoint {
    let clamped = min(max(value, 0), 1)
    let x = count <= 1 ? rect.minX : rect.minX + rect.width * CGFloat(index) / CGFloat(count - 1)
    let y = rect.maxY - rect.height * CGFloat(clamped)
    return CGPoint(x: x, y: y)
  }
}

private struct NativeSoapAnalytics {
  struct DailyPoint {
    let date: Date
    let pain: Double
    let completion: Double
  }

  let members: [NativeTrainerMember]
  let soapDraftsByDay: [String: NativeSoapDailyDraft]

  var allDailyPoints: [DailyPoint] {
    var points: [DailyPoint] = []
    for member in members {
      points.append(contentsOf: pointsForMember(member))
    }
    return points.sorted { $0.date < $1.date }
  }

  var totalSoapCount: Int {
    allDailyPoints.count
  }

  var todaySoapCount: Int {
    let today = Calendar.current.startOfDay(for: Date())
    return allDailyPoints.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }.count
  }

  var attentionMemberCount: Int {
    members.filter { member in
      let latestPain = pointsForMember(member).last?.pain ?? Double(Int(member.pain) ?? 0)
      return latestPain >= 5 || member.riskLabel != "안정"
    }.count
  }

  var averagePainValue: Double? {
    let points = allDailyPoints
    guard !points.isEmpty else {
      return nil
    }
    return points.map(\.pain).reduce(0, +) / Double(points.count)
  }

  var averagePainValueText: String {
    guard let averagePainValue else {
      return "0"
    }
    return String(format: "%.1f", averagePainValue)
  }

  var averagePainText: String {
    guard let averagePainValue else {
      return "평균 통증 -"
    }
    return "평균 통증 \(String(format: "%.1f", averagePainValue))"
  }

  var averageCompletionPercent: Int {
    let points = allDailyPoints
    guard !points.isEmpty else {
      return 0
    }
    let average = points.map(\.completion).reduce(0, +) / Double(points.count)
    return Int(average.rounded())
  }

  var painPoints: [Double] {
    Array(allDailyPoints.suffix(8).map(\.pain))
  }

  var completionPoints: [Double] {
    Array(allDailyPoints.suffix(8).map(\.completion))
  }

  var chartLabels: [String] {
    Array(allDailyPoints.suffix(8).map { Self.chartDateFormatter.string(from: $0.date) })
  }

  func pointsForMember(_ member: NativeTrainerMember) -> [DailyPoint] {
    var pointsByDate: [Date: DailyPoint] = [:]

    for date in NativeSoapDraftStore.datesWithDrafts(for: member) {
      let key = NativeSoapDraftStore.key(member: member, date: date)
      if let draft = NativeSoapDraftStore.load(key: key), draft.hasUserContent {
        pointsByDate[Calendar.current.startOfDay(for: date)] = dailyPoint(from: draft, date: date)
      }
    }

    for key in soapDraftsByDay.keys where key.hasPrefix("\(member.avatarSeed)-") {
      guard let draft = soapDraftsByDay[key], draft.hasUserContent else {
        continue
      }
      let rawDate = String(key.dropFirst(member.avatarSeed.count + 1))
      guard let date = Self.storageDateFormatter.date(from: rawDate) else {
        continue
      }
      pointsByDate[Calendar.current.startOfDay(for: date)] = dailyPoint(from: draft, date: date)
    }

    return pointsByDate.values.sorted { $0.date < $1.date }
  }

  private func dailyPoint(from draft: NativeSoapDailyDraft, date: Date) -> DailyPoint {
    DailyPoint(
      date: Calendar.current.startOfDay(for: date),
      pain: draft.painValue,
      completion: Double(completionPercent(for: draft))
    )
  }

  private func completionPercent(for draft: NativeSoapDailyDraft) -> Int {
    var completed = 0
    if !draft.subjective.trimmedForDisplay.isEmpty { completed += 1 }
    if !draft.objective.trimmedForDisplay.isEmpty || !draft.romEntries.isEmpty || !draft.mmtEntries.isEmpty { completed += 1 }
    if !draft.assessment.trimmedForDisplay.isEmpty { completed += 1 }
    if !draft.plan.trimmedForDisplay.isEmpty { completed += 1 }
    return Int((Double(completed) / 4.0 * 100).rounded())
  }

  private static let storageDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  private static let chartDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M/d"
    return formatter
  }()
}

private enum NativeTrainerRoute: String, Identifiable, CaseIterable {
  case sessionBoard
  case summary
  case members
  case schedule
  case soap
  case program
  case reports
  case alerts
  case settings

  var id: String { rawValue }

  static let mainRoutes: [NativeTrainerRoute] = [.sessionBoard, .members, .soap, .reports]
  static let utilityRoutes: [NativeTrainerRoute] = [.settings]
  static let pendingRoutes: [NativeTrainerRoute] = [.schedule, .program, .alerts]

  var isPending: Bool {
    switch self {
    case .schedule, .program, .alerts:
      return true
    default:
      return false
    }
  }

  var title: String {
    switch self {
    case .sessionBoard: return "홈"
    case .summary: return "요약"
    case .members: return "회원 관리"
    case .schedule: return "일정"
    case .soap: return "SOAP 노트"
    case .program: return "프로그램"
    case .reports: return "리포트"
    case .alerts: return "알림"
    case .settings: return "설정"
    }
  }

  var symbol: String {
    switch self {
    case .sessionBoard: return "house.fill"
    case .summary: return "heart.fill"
    case .members: return "person.2"
    case .schedule: return "calendar"
    case .soap: return "doc.text.fill"
    case .program: return "figure.strengthtraining.traditional"
    case .reports: return "chart.bar.xaxis"
    case .alerts: return "bell"
    case .settings: return "gearshape"
    }
  }
}

private struct NativeTrainerMember: Identifiable {
  let id: UUID
  let avatarSeed: String
  let avatarImageData: Data?
  let name: String
  let email: String
  let program: String
  let bodyRegion: String
  let subjective: String
  let objective: String
  let assessment: String
  let plan: String
  let subtitle: String
  let riskLabel: String
  let signal: String
  let pain: String
  let progress: String
  let lastSoap: String
  let nextPlan: String
  let statusColor: Color

  var initial: String {
    String(name.prefix(1))
  }

  var displayBodyRegion: String {
    bodyRegion.trimmedForDisplay.isEmpty ? "부위 미지정" : bodyRegion.trimmedForDisplay
  }

  var bodyRegionItems: [String] {
    bodyRegion
      .components(separatedBy: " · ")
      .map { $0.trimmedForDisplay }
      .filter { !$0.isEmpty }
  }

  var displayProgram: String {
    program.trimmedForDisplay.isEmpty ? "프로그램 미지정" : program.trimmedForDisplay
  }

  var hasInitialSoap: Bool {
    ![subjective, objective, assessment, plan]
      .allSatisfy { $0.trimmedForDisplay.isEmpty }
  }

  var soapCompletionPercent: Int {
    let completed = [subjective, objective, assessment, plan]
      .filter { !$0.trimmedForDisplay.isEmpty }
      .count
    return Int((Double(completed) / 4.0) * 100.0)
  }

  func updatingAvatarImageData(_ imageData: Data?) -> NativeTrainerMember {
    NativeTrainerMember(
      id: id,
      avatarSeed: imageData == nil ? avatarSeed : "member-\(UUID().uuidString)",
      avatarImageData: imageData,
      name: name,
      email: email,
      program: program,
      bodyRegion: bodyRegion,
      subjective: subjective,
      objective: objective,
      assessment: assessment,
      plan: plan,
      subtitle: subtitle,
      riskLabel: riskLabel,
      signal: signal,
      pain: pain,
      progress: progress,
      lastSoap: lastSoap,
      nextPlan: nextPlan,
      statusColor: statusColor
    )
  }

  init(
    id: UUID = UUID(),
    avatarSeed: String,
    avatarImageData: Data? = nil,
    name: String,
    email: String,
    program: String,
    bodyRegion: String,
    subjective: String,
    objective: String,
    assessment: String,
    plan: String,
    subtitle: String,
    riskLabel: String,
    signal: String,
    pain: String,
    progress: String,
    lastSoap: String,
    nextPlan: String,
    statusColor: Color
  ) {
    self.id = id
    self.avatarSeed = avatarSeed
    self.avatarImageData = avatarImageData
    self.name = name
    self.email = email
    self.program = program
    self.bodyRegion = bodyRegion
    self.subjective = subjective
    self.objective = objective
    self.assessment = assessment
    self.plan = plan
    self.subtitle = subtitle
    self.riskLabel = riskLabel
    self.signal = signal
    self.pain = pain
    self.progress = progress
    self.lastSoap = lastSoap
    self.nextPlan = nextPlan
    self.statusColor = statusColor
  }

  static let emptySelectionId = UUID()

  static let emptyMember = NativeTrainerMember(
    id: emptySelectionId,
    avatarSeed: "empty",
    avatarImageData: nil,
    name: "회원 없음",
    email: "",
    program: "",
    bodyRegion: "",
    subjective: "",
    objective: "",
    assessment: "",
    plan: "",
    subtitle: "등록된 회원 없음",
    riskLabel: "대기",
    signal: "기록 없음",
    pain: "0",
    progress: "0",
    lastSoap: "-",
    nextPlan: "",
    statusColor: NativeHealthColor.secondaryText
  )

  static let samples: [NativeTrainerMember] = []

  static func registeredFromSoap(
    name: String,
    email: String,
    program: String,
    bodyRegion: String,
    pain: Int,
    subjective: String,
    objective: String,
    assessment: String,
    plan: String,
    avatarImageData: Data? = nil
  ) -> NativeTrainerMember {
    let risk = riskLabel(forPain: pain)
    let safeProgram = program.isEmpty ? "프로그램 미지정" : program
    let safeRegion = bodyRegion.isEmpty ? "부위 미지정" : bodyRegion
    let subtitle = "\(safeProgram) · \(safeRegion)"
    let signal = firstNonEmpty([subjective, assessment, objective, plan]) ?? "SOAP 작성 전"
    let completedSoapFields = [subjective, objective, assessment, plan].filter { !$0.isEmpty }.count

    return NativeTrainerMember(
      avatarSeed: "member-\(UUID().uuidString)",
      avatarImageData: avatarImageData,
      name: name,
      email: email,
      program: program,
      bodyRegion: bodyRegion,
      subjective: subjective,
      objective: objective,
      assessment: assessment,
      plan: plan,
      subtitle: subtitle,
      riskLabel: risk,
      signal: signal,
      pain: "\(pain)",
      progress: "0",
      lastSoap: completedSoapFields > 0 ? Self.registeredDateFormatter.string(from: Date()) : "-",
      nextPlan: plan,
      statusColor: statusColor(forRiskLabel: risk)
    )
  }

  static func loadStoredMembers() -> [NativeTrainerMember] {
    guard let data = UserDefaults.standard.data(forKey: storageKey),
          let payloads = try? JSONDecoder().decode([NativeTrainerMemberPayload].self, from: data) else {
      return []
    }
    return payloads.map { NativeTrainerMember(payload: $0) }
  }

  static func persist(_ members: [NativeTrainerMember]) {
    let payloads = members.map { $0.payload }
    guard let data = try? JSONEncoder().encode(payloads) else { return }
    UserDefaults.standard.set(data, forKey: storageKey)
  }

  static func riskColor(forPain pain: Int) -> Color {
    statusColor(forRiskLabel: riskLabel(forPain: pain))
  }

  private static let storageKey = "DFETNativeTrainerMembers.v1"

  private static let registeredDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "yyyy.MM.dd"
    return formatter
  }()

  private static func firstNonEmpty(_ values: [String]) -> String? {
    values.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  }

  private static func riskLabel(forPain pain: Int) -> String {
    if pain >= 8 { return "고위험" }
    if pain >= 5 { return "주의" }
    return "안정"
  }

  private static func statusColor(forRiskLabel label: String) -> Color {
    switch label {
    case "고위험":
      return NativeHealthColor.red
    case "주의", "재평가":
      return NativeHealthColor.orange
    case "안정":
      return NativeHealthColor.green
    default:
      return NativeHealthColor.secondaryText
    }
  }

  private init(payload: NativeTrainerMemberPayload) {
    let payloadProgram = payload.program ?? ""
    let payloadBodyRegion = payload.bodyRegion ?? ""
    let payloadSubjective = payload.subjective ?? ""
    let payloadObjective = payload.objective ?? ""
    let payloadAssessment = payload.assessment ?? ""
    let payloadPlan = payload.plan ?? ""
    let hasSoapPayload = ![payloadSubjective, payloadObjective, payloadAssessment, payloadPlan]
      .allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    self.id = payload.id ?? UUID()
    self.avatarSeed = payload.avatarSeed
    self.avatarImageData = payload.avatarImageData
    self.name = payload.name
    self.email = payload.email
    self.program = payloadProgram
    self.bodyRegion = payloadBodyRegion
    self.subjective = payloadSubjective
    self.objective = payloadObjective
    self.assessment = payloadAssessment
    self.plan = payloadPlan
    self.subtitle = payload.subtitle
    self.riskLabel = payload.riskLabel
    self.signal = hasSoapPayload ? payload.signal : "SOAP 작성 전"
    self.pain = payload.pain
    self.progress = payload.progress
    self.lastSoap = payload.lastSoap
    self.nextPlan = hasSoapPayload ? payload.nextPlan : ""
    self.statusColor = NativeTrainerMember.statusColor(forRiskLabel: payload.riskLabel)
  }

  private var payload: NativeTrainerMemberPayload {
    NativeTrainerMemberPayload(
      id: id,
      avatarSeed: avatarSeed,
      avatarImageData: avatarImageData,
      name: name,
      email: email,
      program: program,
      bodyRegion: bodyRegion,
      subjective: subjective,
      objective: objective,
      assessment: assessment,
      plan: plan,
      subtitle: subtitle,
      riskLabel: riskLabel,
      signal: signal,
      pain: pain,
      progress: progress,
      lastSoap: lastSoap,
      nextPlan: nextPlan
    )
  }
}

private struct NativeTrainerMemberPayload: Codable {
  let id: UUID?
  let avatarSeed: String
  let avatarImageData: Data?
  let name: String
  let email: String
  let program: String?
  let bodyRegion: String?
  let subjective: String?
  let objective: String?
  let assessment: String?
  let plan: String?
  let subtitle: String
  let riskLabel: String
  let signal: String
  let pain: String
  let progress: String
  let lastSoap: String
  let nextPlan: String
}

private enum NativeHealthColor {
  static let background = Color(hex: 0xF5F7FB)
  static let sidebar = Color(hex: 0xF8FAFE)
  static let sidebarNavy = Color(hex: 0x061E45)
  static let card = Color.white
  static let glassPanel = Color(hex: 0xFFFFFF).opacity(0.94)
  static let panelTop = Color(hex: 0xFFFFFF).opacity(0.98)
  static let panelBottom = Color(hex: 0xF8FAFE).opacity(0.96)
  static let subPanel = Color(hex: 0xF8FAFE).opacity(0.96)
  static let primaryText = Color(hex: 0x12213D)
  static let secondaryText = Color(hex: 0x657089)
  static let border = Color(hex: 0xDDE4F2).opacity(0.92)
  static let boardStroke = Color(hex: 0xD5DFF0).opacity(0.96)
  static let blue = Color(hex: 0x2856B8)
  static let green = Color(hex: 0x19A974)
  static let orange = Color(hex: 0xE79A37)
  static let red = Color(hex: 0xD95757)
  static let purple = Color(hex: 0x566CC7)
  static let deepBlue = Color(hex: 0x08285D)
}

private struct NativeSoapWorkspaceView: View {
  @Environment(\.dismiss) private var dismiss

  let onSave: ([String: Any]) -> Void
  let onCancel: () -> Void

  @FocusState private var isTextInputFocused: Bool
  @State private var selectedMode = "필기"
  @State private var selectedSoap = "S"
  @State private var selectedInkTool = "pen"
  @State private var undoSignal = 0
  @State private var memberSearchQuery = ""
  @State private var drawing = PKDrawing()
  @State private var memberName: String
  @State private var memberId: String
  @State private var memberEmail: String
  @State private var diagnosis: String
  @State private var bodyRegion: String
  @State private var painSite: String
  @State private var painValue: Double
  @State private var riskLevel: String
  @State private var subjective: String
  @State private var assessment: String
  @State private var treatmentPlan: String
  @State private var homeExercise: String
  @State private var nextPlan: String
  @State private var romEntries: [String]
  @State private var mmtEntries: [String]
  @State private var exerciseEntries: [String]
  @State private var keyboardHeight: CGFloat = 0
  @State private var isKeyboardPresented = false

  init(
    arguments: [String: Any],
    onSave: @escaping ([String: Any]) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.onSave = onSave
    self.onCancel = onCancel
    _memberName = State(initialValue: NativeSoapWorkspaceView.string(arguments["memberName"]))
    _memberId = State(initialValue: NativeSoapWorkspaceView.string(arguments["memberId"]))
    _memberEmail = State(initialValue: NativeSoapWorkspaceView.string(arguments["memberEmail"]))
    _diagnosis = State(initialValue: NativeSoapWorkspaceView.string(arguments["diagnosis"]))
    _bodyRegion = State(initialValue: NativeSoapWorkspaceView.string(arguments["bodyRegion"]))
    _painSite = State(initialValue: NativeSoapWorkspaceView.string(arguments["painSite"]))
    _painValue = State(initialValue: Double(NativeSoapWorkspaceView.int(arguments["painNow"], fallback: 0)))
    _riskLevel = State(initialValue: NativeSoapWorkspaceView.string(arguments["riskLevel"], fallback: "low"))
    _subjective = State(initialValue: NativeSoapWorkspaceView.string(arguments["subjective"]))
    _assessment = State(initialValue: NativeSoapWorkspaceView.string(arguments["assessment"]))
    _treatmentPlan = State(initialValue: NativeSoapWorkspaceView.string(arguments["treatmentPlan"]))
    _homeExercise = State(initialValue: NativeSoapWorkspaceView.string(arguments["homeExercise"]))
    _nextPlan = State(initialValue: NativeSoapWorkspaceView.string(arguments["nextPlan"]))
    _romEntries = State(initialValue: NativeSoapWorkspaceView.stringArray(arguments["nativeRomEntries"]))
    _mmtEntries = State(initialValue: NativeSoapWorkspaceView.stringArray(arguments["nativeMmtEntries"]))
    _exerciseEntries = State(initialValue: NativeSoapWorkspaceView.stringArray(arguments["nativeExerciseEntries"]))
  }

  private var displayMemberName: String {
    let trimmed = memberName.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "새 세션" : trimmed
  }

  private var displayDiagnosis: String {
    let trimmed = diagnosis.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "평가 항목 미입력" : trimmed
  }

  private var displayRegion: String {
    let region = bodyRegion.trimmingCharacters(in: .whitespacesAndNewlines)
    let site = painSite.trimmingCharacters(in: .whitespacesAndNewlines)
    if !region.isEmpty { return region }
    if !site.isEmpty { return site }
    return "부위 미입력"
  }

  private var memberMatchesSearch: Bool {
    let query = memberSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if query.isEmpty { return true }
    return [
      displayMemberName,
      displayDiagnosis,
      displayRegion,
      memberEmail
    ].joined(separator: " ").lowercased().contains(query)
  }

  private var todayLabel: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "MM.dd"
    return formatter.string(from: Date())
  }

  private var isSoapKeyboardLayoutActive: Bool {
    selectedMode == "SOAP" && (isTextInputFocused || isKeyboardPresented || keyboardHeight > 0)
  }

  private var keyboardBottomInset: CGFloat {
    guard isSoapKeyboardLayoutActive else {
      return 0
    }
    return keyboardHeight > 0 ? keyboardHeight : 0
  }

  var body: some View {
    ZStack {
      DfetColor.root.ignoresSafeArea()
      VStack(spacing: 0) {
        topToolbar
        Divider().background(DfetColor.border)
        HStack(spacing: 0) {
          if !isSoapKeyboardLayoutActive {
            sidebar
              .frame(width: 292)
            Divider().background(DfetColor.border)
          }
          workspace
          if !isSoapKeyboardLayoutActive {
            Divider().background(DfetColor.border)
            inspector
              .frame(width: 292)
          }
        }
      }
    }
    .preferredColorScheme(.light)
    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
      updateKeyboardHeight(from: notification)
    }
    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
      updateKeyboardHeight(from: notification, forceHidden: true)
    }
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("완료") {
          dismissKeyboard()
        }
      }
    }
  }

  private var topToolbar: some View {
    HStack(spacing: 14) {
      Button(action: onCancel) {
        Image(systemName: "xmark")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(DfetColor.secondaryText)
          .frame(width: 34, height: 34)
      }
      .buttonStyle(.plain)

      Text("오늘 세션")
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(DfetColor.primaryText)

      Spacer()

      SegmentedPicker(
        values: ["필기", "SOAP", "공유", "시각화"],
        selection: $selectedMode
      )
      .frame(width: 330)

      Spacer()

      HStack(spacing: 7) {
        Circle()
          .fill(DfetColor.success)
          .frame(width: 7, height: 7)
        Text("자동저장")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(DfetColor.secondaryText)
      }

      if isTextInputFocused {
        Button(action: dismissKeyboard) {
          Image(systemName: "keyboard.chevron.compact.down")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(DfetColor.secondaryText)
            .frame(width: 36, height: 36)
            .background(DfetColor.raised)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
      }

      Button("정리") {
        dismissKeyboard()
        selectedMode = "SOAP"
      }
      .buttonStyle(PrimaryButtonStyle())

      Button(action: save) {
        Image(systemName: "square.and.arrow.down")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(DfetColor.primaryText)
          .frame(width: 36, height: 36)
          .background(DfetColor.raised)
          .clipShape(RoundedRectangle(cornerRadius: 8))
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 18)
    .frame(height: 58)
    .background(DfetColor.surface)
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 8) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(DfetColor.tertiaryText)
        TextField("", text: $memberSearchQuery)
          .font(.system(size: 14))
          .foregroundStyle(DfetColor.primaryText)
          .focused($isTextInputFocused)
          .overlay(alignment: .leading) {
            if memberSearchQuery.isEmpty {
              Text("회원 검색")
                .font(.system(size: 14))
                .foregroundStyle(DfetColor.tertiaryText)
                .allowsHitTesting(false)
            }
          }
        if !memberSearchQuery.isEmpty {
          Button {
            memberSearchQuery = ""
            dismissKeyboard()
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(DfetColor.tertiaryText)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 12)
      .frame(height: 36)
      .background(DfetColor.panel)
      .clipShape(RoundedRectangle(cornerRadius: 8))

      Text("오늘")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(DfetColor.tertiaryText)

      VStack(spacing: 6) {
        if memberMatchesSearch {
          memberRow(
            name: displayMemberName,
            subtitle: displayDiagnosis,
            status: memberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "작성중" : riskLabel(riskLevel),
            selected: true
          )
        } else {
          Text("검색 결과 없음")
            .font(.system(size: 13))
            .foregroundStyle(DfetColor.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .frame(height: 52)
            .background(DfetColor.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
      }

      Spacer()

      VStack(alignment: .leading, spacing: 12) {
        Text(displayMemberName)
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(DfetColor.primaryText)
        Text(displayDiagnosis)
          .font(.system(size: 13))
          .foregroundStyle(DfetColor.secondaryText)

        VStack(spacing: 9) {
          metricMiniRow("통증", "\(Int(painValue))/10", .danger)
          metricMiniRow("부위", displayRegion, .primary)
          metricMiniRow("위험", riskLabel(riskLevel), .danger)
        }

        VStack(alignment: .leading, spacing: 7) {
          Text("이전 기록")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(DfetColor.tertiaryText)
          Text("저장 후 회원 타임라인에 추가됩니다")
            .font(.system(size: 12))
            .foregroundStyle(DfetColor.secondaryText)
        }
      }
      .padding(14)
      .background(DfetColor.panel)
      .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .padding(14)
    .background(DfetColor.sidebar)
  }

  private var workspace: some View {
    VStack(spacing: 0) {
      HStack(spacing: 14) {
        VStack(alignment: .leading, spacing: 3) {
          Text(displayMemberName)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(DfetColor.primaryText)
          Text("\(todayLabel) · \(selectedMode) · \(selectedSoap)")
            .font(.system(size: 13))
            .foregroundStyle(DfetColor.secondaryText)
        }

        Spacer()

        SegmentedPicker(values: ["S", "O", "A", "P"], selection: $selectedSoap)
          .frame(width: 180)

        StatusPill(text: "통증 \(Int(painValue))", color: .danger)
        StatusPill(text: displayRegion, color: .primary)
        StatusPill(text: riskLabel(riskLevel), color: .danger)
      }
      .padding(.horizontal, 18)
      .frame(height: 72)
      .background(DfetColor.surface)

      workspaceContent
    }
  }

  @ViewBuilder
  private var workspaceContent: some View {
    switch selectedMode {
    case "SOAP":
      if isSoapKeyboardLayoutActive {
        soapKeyboardSplitWorkspace
      } else {
        soapSummaryWorkspace
      }
    case "공유":
      shareWorkspace
    case "시각화":
      visualizationWorkspace
    default:
      handwritingWorkspace
    }
  }

  private var handwritingWorkspace: some View {
    ZStack(alignment: .bottom) {
        Color.clear
          .contentShape(Rectangle())
          .onTapGesture {
            dismissKeyboard()
          }
        PencilCanvasView(
          drawing: $drawing,
          selectedTool: $selectedInkTool,
          undoSignal: $undoSignal
        )
          .background(CanvasLines())
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .overlay(alignment: .topTrailing) {
            HStack(spacing: 5) {
              Image(systemName: "lock")
              Text("내부 메모")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(DfetColor.tertiaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DfetColor.raised.opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(14)
          }
          .padding(18)

        pencilToolbar
          .padding(.bottom, 30)
      }
      .background(DfetColor.content)
  }

  private var soapSummaryWorkspace: some View {
    ScrollView {
      legacySoapFields
        .padding(18)
    }
    .background(DfetColor.content)
  }

  private var legacySoapFields: some View {
    VStack(spacing: 12) {
      soapTextEditor(title: "S. 주관적 정보", text: $subjective, placeholder: "주호소, 통증 양상, 악화/완화 요인")
      soapTextEditor(title: "A. 평가", text: $assessment, placeholder: "문제 목록, 임상 판단, 위험도")
      soapTextEditor(title: "P. 계획", text: $treatmentPlan, placeholder: "세션 중 치료/운동 계획")
      soapTextEditor(title: "홈 운동", text: $homeExercise, placeholder: "회원에게 전달할 홈 운동")
      soapTextEditor(title: "다음 세션", text: $nextPlan, placeholder: "재평가, 다음 목표, follow-up")
    }
  }

  private var soapKeyboardSplitWorkspace: some View {
    GeometryReader { geometry in
      let availableHeight = max(210, geometry.size.height - keyboardBottomInset - 18)
      let horizontalSplit = geometry.size.width >= 760

      Group {
        if horizontalSplit {
          HStack(spacing: 14) {
            legacyKeyboardEditorPane(height: availableHeight)
              .frame(maxWidth: .infinity, maxHeight: availableHeight)
            legacyKeyboardHandwritingPane(height: availableHeight)
              .frame(maxWidth: .infinity, maxHeight: availableHeight)
          }
        } else {
          VStack(spacing: 14) {
            legacyKeyboardEditorPane(height: max(170, availableHeight / 2))
            legacyKeyboardHandwritingPane(height: max(170, availableHeight / 2))
          }
        }
      }
      .padding(14)
      .padding(.bottom, keyboardBottomInset)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .background(DfetColor.content)
      .ignoresSafeArea(.keyboard, edges: .bottom)
    }
  }

  private func legacyKeyboardEditorPane(height: CGFloat) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        StatusPill(text: "SOAP 입력", color: .primary)
        Text(todayLabel)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(DfetColor.secondaryText)
        Spacer()
        Button("완료") {
          dismissKeyboard()
        }
        .buttonStyle(PrimaryButtonStyle())
      }

      ScrollView {
        legacySoapFields
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, maxHeight: height, alignment: .top)
    .background(DfetColor.surface)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(DfetColor.border, lineWidth: 1)
    )
  }

  private func legacyKeyboardHandwritingPane(height: CGFloat) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        StatusPill(text: "필기 원본", color: .primary)
        Text(displayMemberName)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(DfetColor.secondaryText)
          .lineLimit(1)
        Spacer()
        Button("필기 편집") {
          dismissKeyboard()
          selectedMode = "필기"
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(DfetColor.primary)
        .buttonStyle(.plain)
      }

      Text("왼쪽에서 SOAP를 정리하면서 오른쪽에서 수업 중 필기한 원본을 확인합니다.")
        .font(.system(size: 12))
        .foregroundStyle(DfetColor.secondaryText)
        .lineLimit(2)

      legacyHandwritingPreviewSurface(height: max(150, height - 84))
    }
    .padding(14)
    .frame(maxWidth: .infinity, maxHeight: height, alignment: .top)
    .background(DfetColor.surface)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(DfetColor.border, lineWidth: 1)
    )
  }

  private func legacyHandwritingPreviewSurface(height: CGFloat) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 10)
        .fill(DfetColor.panel)

      if let image = legacyHandwritingSnapshotImage {
        Image(uiImage: image)
          .resizable()
          .scaledToFit()
          .padding(10)
      } else {
        VStack(spacing: 8) {
          Image(systemName: "pencil")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(DfetColor.primary)
          Text("아직 필기 없음")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(DfetColor.primaryText)
          Text("필기 탭에서 작성하면 여기에 표시됩니다.")
            .font(.system(size: 12))
            .foregroundStyle(DfetColor.secondaryText)
        }
      }
    }
    .frame(height: height)
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(DfetColor.border, lineWidth: 1)
    )
  }

  private var legacyHandwritingSnapshotImage: UIImage? {
    let bounds = drawing.bounds
    guard !bounds.isNull, !bounds.isEmpty else {
      return nil
    }
    let paddedBounds = bounds.insetBy(dx: -28, dy: -28)
    return drawing.image(from: paddedBounds, scale: UIScreen.main.scale)
  }

  private var shareWorkspace: some View {
    VStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 12) {
        Text("회원 공유 요약")
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(DfetColor.primaryText)
        shareLine("회원", displayMemberName)
        shareLine("현재 상태", "\(displayRegion) · 통증 \(Int(painValue))/10 · \(riskLabel(riskLevel))")
        shareLine("주요 평가", assessment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "평가 정리 전" : assessment)
        shareLine("실행 계획", treatmentPlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "계획 정리 전" : treatmentPlan)
        shareLine("홈 운동", homeExercise.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "미입력" : homeExercise)
      }
      .padding(18)
      .frame(maxWidth: 720, alignment: .leading)
      .background(DfetColor.panel)
      .clipShape(RoundedRectangle(cornerRadius: 10))
      Spacer()
    }
    .padding(18)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DfetColor.content)
    .contentShape(Rectangle())
    .onTapGesture {
      dismissKeyboard()
    }
  }

  private var visualizationWorkspace: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("세션 지표")
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(DfetColor.primaryText)
      HStack(spacing: 12) {
        visualMetricCard(title: "통증", value: "\(Int(painValue))/10", progress: painValue / 10, color: DfetColor.danger)
        visualMetricCard(title: "목표 진행", value: "62%", progress: 0.62, color: DfetColor.primary)
        visualMetricCard(title: "위험도", value: riskLabel(riskLevel), progress: riskLevel == "high" ? 1 : riskLevel == "medium" ? 0.6 : 0.28, color: riskLevel == "low" ? DfetColor.success : DfetColor.warning)
      }
      VStack(alignment: .leading, spacing: 8) {
        Text("타임라인")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(DfetColor.secondaryText)
        CanvasLines()
          .frame(height: 240)
          .overlay(sessionMetricPreview.padding(16))
          .clipShape(RoundedRectangle(cornerRadius: 10))
      }
      Spacer()
    }
    .padding(18)
    .background(DfetColor.content)
    .contentShape(Rectangle())
    .onTapGesture {
      dismissKeyboard()
    }
  }

  private var pencilToolbar: some View {
    HStack(spacing: 8) {
      toolButton("pencil.tip", tool: "pen")
      toolButton("highlighter", tool: "marker")
      toolButton("eraser", tool: "eraser")
      undoButton()
      toolButton("lasso", tool: "lasso")
      Divider()
        .frame(height: 24)
        .background(DfetColor.border)
        .padding(.horizontal, 4)
      quickChip("+통증", action: addPainMarker)
      quickChip("+ROM", action: addRomEntry)
      quickChip("+MMT", action: addMmtEntry)
    }
    .padding(8)
    .background(DfetColor.raised.opacity(0.96))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(DfetColor.border, lineWidth: 1)
    )
  }

  private var inspector: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("핵심 지표")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(DfetColor.primaryText)
        Spacer()
        Image(systemName: "sidebar.trailing")
          .foregroundStyle(DfetColor.tertiaryText)
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("통증")
          Spacer()
          Text("\(Int(painValue))/10")
            .foregroundStyle(DfetColor.danger)
      }
      .font(.system(size: 14, weight: .medium))
      Slider(value: $painValue, in: 0...10, step: 1)
        .tint(DfetColor.danger)
      }

      inspectorField("회원", text: $memberName)
      inspectorField("진단/이슈", text: $diagnosis)
      inspectorField("부위", text: $bodyRegion)

      VStack(alignment: .leading, spacing: 8) {
        Text("위험")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(DfetColor.tertiaryText)
        SegmentedPicker(
          values: ["low", "medium", "high"],
          labels: ["낮음", "중간", "높음"],
          selection: $riskLevel
        )
      }

      actionRow("ROM", action: "+", onTap: addRomEntry)
      compactEntryList(romEntries)
      actionRow("MMT", action: "+", onTap: addMmtEntry)
      compactEntryList(mmtEntries)
      actionRow("운동", action: "+", onTap: addExerciseEntry)
      compactEntryList(exerciseEntries)

      VStack(alignment: .leading, spacing: 7) {
        HStack {
          Text("목표")
          Spacer()
          Text("62%")
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(DfetColor.secondaryText)
        ProgressView(value: 0.62)
          .tint(DfetColor.primary)
      }

      Spacer()

      Button("세션 후 정리") {
        selectedMode = "SOAP"
      }
      .buttonStyle(PrimaryButtonStyle(fullWidth: true))

      Button("새 SOAP") {
        drawing = PKDrawing()
        memberName = ""
        memberId = ""
        memberEmail = ""
        diagnosis = ""
        bodyRegion = ""
        painSite = ""
        painValue = 0
        riskLevel = "low"
        subjective = ""
        assessment = ""
        treatmentPlan = ""
        homeExercise = ""
        nextPlan = ""
        romEntries = []
        mmtEntries = []
        exerciseEntries = []
        memberSearchQuery = ""
      }
      .buttonStyle(SecondaryButtonStyle())
    }
    .padding(16)
    .background(DfetColor.inspector)
  }

  private func save() {
    dismissKeyboard()
    let inkData = drawing.dataRepresentation().base64EncodedString()
    onSave([
      "memberName": memberName,
      "memberId": memberId,
      "memberEmail": memberEmail,
      "diagnosis": diagnosis,
      "bodyRegion": bodyRegion,
      "painNow": Int(painValue),
      "painSite": painSite.isEmpty ? bodyRegion : painSite,
      "riskLevel": riskLevel,
      "subjective": subjective,
      "assessment": assessment,
      "treatmentPlan": treatmentPlan,
      "homeExercise": homeExercise,
      "nextPlan": nextPlan,
      "nativeRomEntries": romEntries,
      "nativeMmtEntries": mmtEntries,
      "nativeExerciseEntries": exerciseEntries,
      "inkDataBase64": inkData,
      "inkStrokeCount": drawing.strokes.count
    ])
  }

  private func addPainMarker() {
    dismissKeyboard()
    painValue = min(10, painValue + 1)
    if painSite.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
       displayRegion != "부위 미입력" {
      painSite = displayRegion
    }
    riskLevel = Self.riskFromPain(Int(painValue))
    selectedMode = "필기"
  }

  private func addRomEntry() {
    dismissKeyboard()
    let label = metricLabel(prefix: "ROM", count: romEntries.count + 1)
    romEntries.append(label)
    appendAssessmentLine("\(label): 측정 필요")
    selectedMode = "시각화"
  }

  private func addMmtEntry() {
    dismissKeyboard()
    let label = metricLabel(prefix: "MMT", count: mmtEntries.count + 1)
    mmtEntries.append(label)
    appendAssessmentLine("\(label): 근력 확인 필요")
    selectedMode = "시각화"
  }

  private func addExerciseEntry() {
    dismissKeyboard()
    let label = metricLabel(prefix: "운동", count: exerciseEntries.count + 1)
    exerciseEntries.append(label)
    appendPlanLine("\(label): 다음 세션에서 진행")
    selectedMode = "SOAP"
  }

  private func metricLabel(prefix: String, count: Int) -> String {
    let region = displayRegion == "부위 미입력" ? "" : "\(displayRegion) "
    return "\(region)\(prefix) \(count)"
  }

  private func appendAssessmentLine(_ line: String) {
    let trimmed = assessment.trimmingCharacters(in: .whitespacesAndNewlines)
    assessment = trimmed.isEmpty ? line : "\(assessment)\n\(line)"
  }

  private func appendPlanLine(_ line: String) {
    let trimmed = treatmentPlan.trimmingCharacters(in: .whitespacesAndNewlines)
    treatmentPlan = trimmed.isEmpty ? line : "\(treatmentPlan)\n\(line)"
  }

  private func dismissKeyboard() {
    isTextInputFocused = false
    isKeyboardPresented = false
    keyboardHeight = 0
    UIApplication.shared.sendAction(
      #selector(UIResponder.resignFirstResponder),
      to: nil,
      from: nil,
      for: nil
    )
  }

  private func updateKeyboardHeight(from notification: Notification, forceHidden: Bool = false) {
    let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.22

    guard !forceHidden,
          let frameValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
      withAnimation(.easeOut(duration: duration)) {
        keyboardHeight = 0
        isKeyboardPresented = false
      }
      return
    }

    let keyboardFrame = frameValue.cgRectValue
    let overlap: CGFloat
    if let windowScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
       let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
      let convertedFrame = window.convert(keyboardFrame, from: nil)
      overlap = max(0, window.bounds.maxY - convertedFrame.minY)
    } else {
      let screenHeight = UIScreen.main.bounds.height
      overlap = max(0, screenHeight - keyboardFrame.minY)
    }

    withAnimation(.easeOut(duration: duration)) {
      keyboardHeight = overlap
      isKeyboardPresented = overlap > 24
    }
  }

  private func memberRow(name: String, subtitle: String, status: String, selected: Bool) -> some View {
    HStack(spacing: 10) {
      Circle()
        .fill(selected ? DfetColor.primary.opacity(0.24) : DfetColor.raised)
        .frame(width: 32, height: 32)
        .overlay(
          Text(String(name.prefix(1)))
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(selected ? DfetColor.primary : DfetColor.secondaryText)
        )
      VStack(alignment: .leading, spacing: 2) {
        Text(name)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(DfetColor.primaryText)
        Text(subtitle)
          .font(.system(size: 12))
          .foregroundStyle(DfetColor.tertiaryText)
      }
      Spacer()
      Text(status)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(status == "고위험" ? DfetColor.danger : DfetColor.secondaryText)
    }
    .padding(.horizontal, 10)
    .frame(height: 52)
    .background(selected ? DfetColor.primary.opacity(0.13) : Color.clear)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  private func metricMiniRow(_ label: String, _ value: String, _ color: DfetSemanticColor) -> some View {
    HStack {
      Text(label)
        .foregroundStyle(DfetColor.tertiaryText)
      Spacer()
      Text(value)
        .foregroundStyle(color.color)
        .font(.system(size: 13, weight: .semibold))
    }
    .font(.system(size: 13))
  }

  private func soapTextEditor(title: String, text: Binding<String>, placeholder: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(DfetColor.primaryText)
      ZStack(alignment: .topLeading) {
        if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Text(placeholder)
            .font(.system(size: 14))
            .foregroundStyle(DfetColor.tertiaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 9)
        }
        TextEditor(text: text)
          .font(.system(size: 15))
          .foregroundColor(DfetColor.primaryText)
          .frame(minHeight: 92)
          .padding(4)
          .background(Color.clear)
          .focused($isTextInputFocused)
          .onTapGesture {
            isTextInputFocused = true
          }
      }
      .background(DfetColor.panel)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(DfetColor.border, lineWidth: 1)
      )
    }
    .padding(14)
    .background(DfetColor.surface)
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }

  private func shareLine(_ title: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(DfetColor.tertiaryText)
      Text(value)
        .font(.system(size: 14))
        .foregroundStyle(DfetColor.primaryText)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func visualMetricCard(title: String, value: String, progress: Double, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(title)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(DfetColor.secondaryText)
        Spacer()
        Text(value)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(color)
      }
      ProgressView(value: progress)
        .tint(color)
    }
    .padding(14)
    .frame(maxWidth: .infinity)
    .background(DfetColor.panel)
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }

  private var sessionMetricPreview: some View {
    VStack(alignment: .leading, spacing: 10) {
      if romEntries.isEmpty && mmtEntries.isEmpty && exerciseEntries.isEmpty {
        Text("빠른 추가 버튼을 누르면 통증, ROM, MMT, 운동 항목이 여기에 쌓입니다")
          .font(.system(size: 14))
          .foregroundStyle(DfetColor.tertiaryText)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      } else {
        metricPreviewSection(title: "ROM", entries: romEntries)
        metricPreviewSection(title: "MMT", entries: mmtEntries)
        metricPreviewSection(title: "운동", entries: exerciseEntries)
        Spacer()
      }
    }
  }

  @ViewBuilder
  private func metricPreviewSection(title: String, entries: [String]) -> some View {
    if !entries.isEmpty {
      VStack(alignment: .leading, spacing: 6) {
        Text(title)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(DfetColor.tertiaryText)
        ForEach(entries, id: \.self) { entry in
          HStack {
            Circle()
              .fill(DfetColor.primary)
              .frame(width: 6, height: 6)
            Text(entry)
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(DfetColor.secondaryText)
            Spacer()
          }
        }
      }
    }
  }

  private func noteRow(_ date: String, _ title: String) -> some View {
    HStack {
      Text(date)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(DfetColor.tertiaryText)
      Text(title)
        .font(.system(size: 12))
        .foregroundStyle(DfetColor.secondaryText)
      Spacer()
    }
  }

  private func inspectorField(_ label: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(label)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(DfetColor.tertiaryText)
      TextField(label, text: text)
        .font(.system(size: 14))
        .foregroundStyle(DfetColor.primaryText)
        .focused($isTextInputFocused)
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(DfetColor.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
  }

  private func actionRow(_ title: String, action: String, onTap: @escaping () -> Void) -> some View {
    Button(action: onTap) {
      HStack {
        Text(title)
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(DfetColor.secondaryText)
        Spacer()
        Text(action)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(DfetColor.primary)
      }
      .padding(.horizontal, 10)
      .frame(height: 36)
      .background(DfetColor.panel)
      .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
  }

  private func compactEntryList(_ entries: [String]) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      ForEach(entries.suffix(2), id: \.self) { entry in
        Text(entry)
          .font(.system(size: 11))
          .foregroundStyle(DfetColor.tertiaryText)
          .lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func toolButton(_ systemName: String, tool: String) -> some View {
    Button {
      selectedInkTool = tool
    } label: {
      Image(systemName: systemName)
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(selectedInkTool == tool ? DfetColor.primary : DfetColor.secondaryText)
        .frame(width: 34, height: 34)
        .background(selectedInkTool == tool ? DfetColor.primary.opacity(0.13) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
  }

  private func undoButton() -> some View {
    Button {
      undoSignal += 1
    } label: {
      Image(systemName: "arrow.uturn.backward")
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(DfetColor.secondaryText)
        .frame(width: 34, height: 34)
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
  }

  private func quickChip(_ text: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(text)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(DfetColor.secondaryText)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(DfetColor.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
  }

  private func riskLabel(_ value: String) -> String {
    switch value {
    case "high":
      return "고위험"
    case "medium":
      return "중위험"
    default:
      return "저위험"
    }
  }

  private static func string(_ value: Any?, fallback: String = "") -> String {
    if let value = value as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return value
    }
    return fallback
  }

  private static func int(_ value: Any?, fallback: Int) -> Int {
    if let value = value as? Int {
      return value
    }
    if let value = value as? NSNumber {
      return value.intValue
    }
    if let value = value as? String, let parsed = Int(value) {
      return parsed
    }
    return fallback
  }

  private static func stringArray(_ value: Any?) -> [String] {
    guard let values = value as? [Any] else { return [] }
    return values
      .compactMap { $0 as? String }
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  private static func riskFromPain(_ pain: Int) -> String {
    if pain >= 8 { return "high" }
    if pain >= 5 { return "medium" }
    return "low"
  }
}

private struct PencilCanvasView: UIViewRepresentable {
  @Binding var drawing: PKDrawing
  @Binding var selectedTool: String
  @Binding var undoSignal: Int

  func makeUIView(context: Context) -> PKCanvasView {
    let canvas = PKCanvasView()
    canvas.delegate = context.coordinator
    canvas.backgroundColor = .clear
    canvas.isOpaque = false
    canvas.drawingPolicy = .anyInput
    canvas.tool = Self.tool(for: selectedTool)
    canvas.drawing = drawing
    return canvas
  }

  func updateUIView(_ uiView: PKCanvasView, context: Context) {
    uiView.tool = Self.tool(for: selectedTool)
    if context.coordinator.lastUndoSignal != undoSignal {
      context.coordinator.lastUndoSignal = undoSignal
      if uiView.undoManager?.canUndo == true {
        uiView.undoManager?.undo()
      } else if !uiView.drawing.strokes.isEmpty {
        uiView.drawing = PKDrawing(strokes: Array(uiView.drawing.strokes.dropLast()))
      }
      drawing = uiView.drawing
      return
    }
    if uiView.drawing != drawing {
      uiView.drawing = drawing
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(drawing: $drawing, undoSignal: undoSignal)
  }

  private static func tool(for selectedTool: String) -> PKTool {
    switch selectedTool {
    case "marker":
      return PKInkingTool(.marker, color: UIColor.systemYellow.withAlphaComponent(0.85), width: 12)
    case "eraser":
      return PKEraserTool(.bitmap)
    case "lasso":
      return PKLassoTool()
    default:
      return PKInkingTool(.pen, color: UIColor.label, width: 3)
    }
  }

  final class Coordinator: NSObject, PKCanvasViewDelegate {
    @Binding var drawing: PKDrawing
    var lastUndoSignal: Int

    init(drawing: Binding<PKDrawing>, undoSignal: Int) {
      _drawing = drawing
      lastUndoSignal = undoSignal
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
      drawing = canvasView.drawing
    }
  }
}

private struct CanvasLines: View {
  var body: some View {
    GeometryReader { geometry in
      ZStack {
        DfetColor.canvas
        Path { path in
          let spacing: CGFloat = 34
          var y = spacing
          while y < geometry.size.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
            y += spacing
          }
        }
        .stroke(DfetColor.border.opacity(0.48), lineWidth: 0.7)
      }
    }
  }
}

private struct SegmentedPicker: View {
  let values: [String]
  let labels: [String]
  @Binding var selection: String

  init(values: [String], labels: [String]? = nil, selection: Binding<String>) {
    self.values = values
    self.labels = labels ?? values
    _selection = selection
  }

  var body: some View {
    HStack(spacing: 2) {
      ForEach(Array(values.enumerated()), id: \.offset) { index, value in
        Button {
          selection = value
        } label: {
          Text(labels[index])
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(selection == value ? Color.white : DfetColor.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(selection == value ? DfetColor.primary : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
      }
    }
    .padding(3)
    .background(DfetColor.panel)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct StatusPill: View {
  let text: String
  let color: DfetSemanticColor

  var body: some View {
    Text(text)
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(color.color)
      .padding(.horizontal, 9)
      .frame(height: 28)
      .background(color.color.opacity(0.13))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(color.color.opacity(0.35), lineWidth: 1)
      )
  }
}

private struct PrimaryButtonStyle: ButtonStyle {
  var fullWidth = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 14, weight: .semibold))
      .foregroundStyle(Color.white)
      .frame(maxWidth: fullWidth ? .infinity : nil)
      .frame(height: 36)
      .padding(.horizontal, fullWidth ? 0 : 14)
      .background(DfetColor.primary.opacity(configuration.isPressed ? 0.72 : 1))
      .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct SecondaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 14, weight: .semibold))
      .foregroundStyle(DfetColor.secondaryText)
      .frame(maxWidth: .infinity)
      .frame(height: 36)
      .background(DfetColor.panel.opacity(configuration.isPressed ? 0.72 : 1))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(DfetColor.border, lineWidth: 1)
      )
  }
}

private enum DfetSemanticColor {
  case primary
  case success
  case warning
  case danger

  var color: Color {
    switch self {
    case .primary:
      return DfetColor.primary
    case .success:
      return DfetColor.success
    case .warning:
      return DfetColor.warning
    case .danger:
      return DfetColor.danger
    }
  }
}

private enum DfetColor {
  static let root = Color(hex: 0xF6F8FF)
  static let sidebar = Color(hex: 0xFBFCFF)
  static let surface = Color(hex: 0xFFFFFF)
  static let content = Color(hex: 0xF6F8FF)
  static let panel = Color(hex: 0xF8FAFF)
  static let raised = Color(hex: 0xEEF3FF)
  static let canvas = Color(hex: 0xFFFFFF)
  static let inspector = Color(hex: 0xFBFCFF)
  static let border = Color(hex: 0xCED8F1)
  static let primaryText = Color(hex: 0x191722)
  static let secondaryText = Color(hex: 0x706A7B)
  static let tertiaryText = Color(hex: 0x9A94A3)
  static let primary = Color(hex: 0x6670D5)
  static let success = Color(hex: 0x3FAF86)
  static let warning = Color(hex: 0xE79A45)
  static let danger = Color(hex: 0xD95F6A)
}

private extension Color {
  init(hex: UInt32) {
    let red = Double((hex >> 16) & 0xff) / 255
    let green = Double((hex >> 8) & 0xff) / 255
    let blue = Double(hex & 0xff) / 255
    self.init(red: red, green: green, blue: blue)
  }
}

private extension UIColor {
  convenience init(hex: UInt32) {
    let red = CGFloat((hex >> 16) & 0xff) / 255
    let green = CGFloat((hex >> 8) & 0xff) / 255
    let blue = CGFloat(hex & 0xff) / 255
    self.init(red: red, green: green, blue: blue, alpha: 1)
  }
}
