import SwiftUI
import FirebaseAuth

struct LoginView: View {
  @EnvironmentObject private var store: TrainerStore
  @State private var email = ""
  @State private var password = ""
  @State private var isPasswordVisible = false
  @State private var isSigningIn = false
  @State private var errorMessage: String?
  @FocusState private var focusedField: Field?
  var onContinue: (() -> Void)? = nil

  enum Field {
    case email
    case password
  }

  var body: some View {
    GeometryReader { geometry in
      let wide = geometry.size.width >= 980

      ZStack {
        StudioBackdrop().ignoresSafeArea()

        if wide {
          HStack(alignment: .center, spacing: 56) {
            brandPanel
              .frame(maxWidth: .infinity, alignment: .leading)
              .trainerLabel("TR-LOGIN-01")
            loginPanel
              .frame(width: 430)
              .trainerLabel("TR-LOGIN-02")
          }
          .padding(.horizontal, 72)
          .frame(maxWidth: 1180)
          .offset(y: -44)
        } else {
          ScrollView {
            VStack(alignment: .leading, spacing: 28) {
              brandPanel
                .trainerLabel("TR-LOGIN-01")
              loginPanel
                .trainerLabel("TR-LOGIN-02")
            }
            .padding(28)
            .frame(maxWidth: 560)
          }
        }
      }
    }
    .preferredColorScheme(.light)
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("완료") {
          focusedField = nil
        }
      }
    }
  }

  private var brandPanel: some View {
    VStack(alignment: .leading, spacing: 30) {
      HStack(spacing: 12) {
        Image(systemName: TrainerSymbol.board)
          .font(TrainerFont.title(27, weight: .bold))
          .foregroundStyle(TrainerColor.inverseText)
          .frame(width: 54, height: 54)
          .background(TrainerGradient.actionBlue, in: RoundedRectangle(cornerRadius: 17, style: .continuous))

        VStack(alignment: .leading, spacing: 2) {
          Text("D-FET")
            .font(TrainerFont.display(34, weight: .bold))
            .foregroundStyle(TrainerColor.primaryText)
          Text("Trainer")
            .font(TrainerFont.label(15, weight: .bold))
            .foregroundStyle(TrainerColor.blue)
        }
      }

      VStack(alignment: .leading, spacing: 12) {
        Text("트레이너를 위한 iPad 작업 공간")
          .font(TrainerFont.display(50, weight: .bold))
          .foregroundStyle(TrainerColor.primaryText)
          .lineLimit(2)
          .minimumScaleFactor(0.72)
        Text("회원 확인, 세션 필기, SOAP 정리, 리포트까지 한 흐름으로 관리합니다.")
          .font(TrainerFont.body(19, weight: .medium))
          .foregroundStyle(TrainerColor.secondaryText)
          .lineSpacing(4)
          .frame(maxWidth: 560, alignment: .leading)
      }

      VStack(alignment: .leading, spacing: 10) {
        LoginFlowRow(step: "01", title: "회원 선택", caption: "오늘 볼 회원과 위험 신호 확인")
        LoginFlowRow(step: "02", title: "세션 기록", caption: "Pencil 필기와 빠른 수치 입력")
        LoginFlowRow(step: "03", title: "SOAP 공유", caption: "회원에게 보낼 요약 정리")
      }
      .padding(18)
      .background(TrainerColor.card.opacity(0.78), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 26, style: .continuous)
          .stroke(TrainerColor.border, lineWidth: 1)
      )
      .frame(maxWidth: 520)
    }
  }

  private var loginPanel: some View {
    VStack(alignment: .leading, spacing: 22) {
      VStack(alignment: .leading, spacing: 8) {
        Text("로그인")
          .font(TrainerFont.display(36, weight: .bold))
          .foregroundStyle(TrainerColor.primaryText)
        Text("트레이너 계정 또는 게스트 모드로 시작합니다.")
          .font(TrainerFont.body(15, weight: .medium))
          .foregroundStyle(TrainerColor.secondaryText)
      }

      VStack(spacing: 13) {
        field(title: "이메일", text: $email, field: .email, keyboard: .emailAddress)
          .trainerLabel("TR-LOGIN-03")
        secureField
          .trainerLabel("TR-LOGIN-04")
      }

      VStack(spacing: 11) {
        Button {
          focusedField = nil
          Task { await signInTrainer() }
        } label: {
          HStack {
            if isSigningIn {
              ProgressView().tint(TrainerColor.inverseText)
            } else {
              Label("트레이너 로그인", systemImage: TrainerSymbol.login)
            }
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(TrainerPrimaryButtonStyle())
        .disabled(isSigningIn || !canSubmit)
        .trainerLabel("TR-LOGIN-05")

        Button {
          focusedField = nil
          store.signInGuestTrainer()
          onContinue?()
        } label: {
          Text("게스트로 둘러보기")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(TrainerSecondaryButtonStyle())
        .disabled(isSigningIn)
        .trainerLabel("TR-LOGIN-06")
      }

      if let errorMessage {
        Text(errorMessage)
          .font(TrainerFont.body(13, weight: .medium))
          .foregroundStyle(TrainerColor.healthRed)
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(TrainerColor.healthRed.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
      }

      HStack(spacing: 10) {
        Image(systemName: TrainerSymbol.lock)
          .foregroundStyle(TrainerColor.blue)
        Text("게스트 데이터는 세션 동안만 유지됩니다.")
          .font(TrainerFont.body(13, weight: .medium))
          .foregroundStyle(TrainerColor.secondaryText)
          .lineLimit(2)
      }
      .padding(14)
      .background(TrainerColor.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

    }
    .padding(28)
    .background(TrainerColor.card.opacity(0.90), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .stroke(TrainerColor.border, lineWidth: 1)
    )
    .shadow(color: Color.black.opacity(0.06), radius: 24, x: 0, y: 12)
  }

  private func field(
    title: String,
    text: Binding<String>,
    field: Field,
    keyboard: UIKeyboardType
  ) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(title)
        .font(TrainerFont.label(13, weight: .semibold))
        .foregroundStyle(TrainerColor.secondaryText)
      TextField(title, text: text)
        .keyboardType(keyboard)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .textContentType(.username)
        .submitLabel(.next)
        .onSubmit { focusedField = .password }
        .font(TrainerFont.body(17, weight: .medium))
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(TrainerColor.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(focusedField == field ? TrainerColor.blue.opacity(0.45) : TrainerColor.border, lineWidth: 1)
        )
        .focused($focusedField, equals: field)
        .disabled(isSigningIn)
    }
  }

  private var canSubmit: Bool {
    !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !password.isEmpty
  }

  @MainActor
  private func signInTrainer() async {
    errorMessage = nil
    isSigningIn = true
    defer { isSigningIn = false }

    do {
      let result = try await Auth.auth().signIn(withEmail: email, password: password)
      let token = try await result.user.getIDTokenResult(forcingRefresh: true)
      let isTrainer = (token.claims["trainer"] as? Bool) == true

      guard isTrainer else {
        // 트레이너 권한이 없는 계정 → 즉시 로그아웃 + 에러
        try? Auth.auth().signOut()
        errorMessage = "트레이너 권한이 없는 계정입니다. 관리자에게 권한 부여를 요청하세요."
        return
      }

      let trainerName = result.user.displayName ?? email
      store.signInDemoTrainer(email: trainerName)
      store.connect(to: FirebaseTrainerRepository(trainerUid: result.user.uid))
      onContinue?()
    } catch {
      errorMessage = Self.authErrorMessage(error)
    }
  }

  private static func authErrorMessage(_ error: Error) -> String {
    let nsError = error as NSError
    if let code = AuthErrorCode(rawValue: nsError.code) {
      switch code {
      case .wrongPassword, .invalidCredential:
        return "이메일 또는 비밀번호가 올바르지 않습니다."
      case .userNotFound:
        return "등록되지 않은 이메일입니다."
      case .invalidEmail:
        return "올바른 이메일 형식을 입력해주세요."
      case .networkError:
        return "네트워크 오류입니다. 잠시 후 다시 시도해주세요."
      case .tooManyRequests:
        return "잠시 후 다시 시도해주세요."
      default:
        return nsError.localizedDescription
      }
    }
    return error.localizedDescription
  }

  private var secureField: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text("비밀번호")
        .font(TrainerFont.label(13, weight: .semibold))
        .foregroundStyle(TrainerColor.secondaryText)

      HStack(spacing: 8) {
        Group {
          if isPasswordVisible {
            TextField("비밀번호", text: $password)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
          } else {
            SecureField("비밀번호", text: $password)
          }
        }
        .font(TrainerFont.body(17, weight: .medium))
        .textContentType(.password)
        .submitLabel(.go)
        .onSubmit {
          if canSubmit {
            Task { await signInTrainer() }
          }
        }
        .focused($focusedField, equals: .password)

        Button {
          isPasswordVisible.toggle()
        } label: {
          Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(TrainerColor.secondaryText)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPasswordVisible ? "비밀번호 숨기기" : "비밀번호 표시")
      }
      .padding(.horizontal, 14)
      .frame(height: 52)
      .background(TrainerColor.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(focusedField == .password ? TrainerColor.blue.opacity(0.45) : TrainerColor.border, lineWidth: 1)
      )
      .disabled(isSigningIn)
    }
  }
}

private struct LoginFlowRow: View {
  let step: String
  let title: String
  let caption: String

  var body: some View {
    HStack(spacing: 12) {
      Text(step)
        .font(TrainerFont.label(12, weight: .bold))
        .foregroundStyle(TrainerColor.inverseText)
        .frame(width: 34, height: 34)
        .background(TrainerColor.blue, in: Circle())

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(TrainerFont.label(15, weight: .bold))
          .foregroundStyle(TrainerColor.primaryText)
        Text(caption)
          .font(TrainerFont.body(13, weight: .medium))
          .foregroundStyle(TrainerColor.secondaryText)
      }

      Spacer()
    }
    .padding(12)
    .background(TrainerColor.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    .trainerLabel("TR-LOGIN-FLOW-\(step)")
  }
}
