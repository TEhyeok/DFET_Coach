import SwiftUI
import TrainerDomain

/// Trainer login (DF-012). Email and password only (ASM-P0-15). Copy comes from the app's string catalog
/// (`App/Resources/Localizable.xcstrings`); SwiftUI looks keys up in the main bundle.
public struct LoginView: View {
  @Bindable private var model: LoginViewModel
  private let lock: AuthLockReason?
  @FocusState private var focused: Field?

  private enum Field { case email, password }

  public init(model: LoginViewModel, lock: AuthLockReason? = nil) {
    self.model = model
    self.lock = lock
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("login.title")
        .font(.largeTitle.weight(.semibold))
        .accessibilityAddTraits(.isHeader)

      if let lock {
        Text(LocalizedStringKey(lock.messageKey))
          .font(.callout)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("auth.locked")
      }

      VStack(spacing: 12) {
        TextField("login.email", text: $model.email)
          .textContentType(.username)
          .keyboardType(.emailAddress)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .focused($focused, equals: .email)
          .submitLabel(.next)
          .onSubmit { focused = .password }
          .accessibilityIdentifier("auth.email")
        SecureField("login.password", text: $model.password)
          .textContentType(.password)
          .focused($focused, equals: .password)
          .submitLabel(.go)
          .onSubmit(submit)
          .accessibilityIdentifier("auth.password")
      }
      .textFieldStyle(.roundedBorder)

      if let key = model.errorKey {
        Text(LocalizedStringKey(key))
          .font(.callout)
          .foregroundStyle(.red)
          .accessibilityIdentifier("auth.error")
      }

      Button(action: submit) {
        HStack {
          if model.phase == .signingIn { ProgressView() }
          Text("login.submit")
        }
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(!model.canSubmit)
      .accessibilityIdentifier("auth.submit")
    }
    .frame(maxWidth: 440)
    .padding(32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("login.root")
  }

  private func submit() {
    Task { await model.submit() }
  }
}

/// Puts the login screen in front of `content` until a trainer session exists, and returns to it when the
/// claim is revoked (AC-DF-012.1, .3). Re-checks the claim whenever the app becomes active (NFR-08).
public struct AuthGate<Content: View>: View {
  @State private var gate: AuthGateModel
  @State private var login: LoginViewModel
  @Environment(\.scenePhase) private var scenePhase
  private let content: (TrainerSession, AuthGateModel) -> Content

  /// `content` also gets the gate, so a logout the trainer asks for goes through `AuthGateModel.signOut` and never
  /// shows the claim-revoked notice (DF-018).
  public init(auth: any AuthService, @ViewBuilder content: @escaping (TrainerSession, AuthGateModel) -> Content) {
    _gate = State(initialValue: AuthGateModel(auth: auth))
    _login = State(initialValue: LoginViewModel(auth: auth))
    self.content = content
  }

  public init(auth: any AuthService, @ViewBuilder content: @escaping (TrainerSession) -> Content) {
    self.init(auth: auth) { session, _ in content(session) }
  }

  public var body: some View {
    Group {
      switch gate.state {
      case .checking:
        ProgressView()
          .accessibilityIdentifier("auth.checking")
      case let .signedOut(lock):
        LoginView(model: login, lock: lock)
      case let .signedIn(session):
        content(session, gate)
      }
    }
    .task { await gate.observe() }
    .onChange(of: scenePhase, initial: true) { _, phase in
      if phase == .active {
        Task { await gate.refreshClaims() }
      }
    }
  }
}
