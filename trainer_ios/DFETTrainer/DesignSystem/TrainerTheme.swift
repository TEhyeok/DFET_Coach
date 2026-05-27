import SwiftUI

enum TrainerColor {
  static let background = Color(hex: 0xF6F8FF)
  static let sidebar = Color(hex: 0xFBFCFF)
  static let card = Color(hex: 0xFFFFFF)
  static let primaryText = Color(hex: 0x191722)
  static let secondaryText = Color(hex: 0x706A7B)
  static let tertiaryText = Color(hex: 0x9A94A3)
  static let inverseText = Color.white
  static let inverseSecondaryText = Color.white.opacity(0.72)
  static let inverseTertiaryText = Color.white.opacity(0.56)
  static let border = Color(hex: 0xDDE3F4).opacity(0.72)
  static let healthRed = Color(hex: 0x6670D5)
  static let blue = Color(hex: 0x6670D5)
  static let green = Color(hex: 0x6E86E8)
  static let orange = Color(hex: 0x8C83E8)
  static let red = Color(hex: 0x7464D9)
  static let purple = Color(hex: 0x8675D8)
  static let deepBlue = Color(hex: 0x17235F)
  static let hotOrange = Color(hex: 0x8EA0F8)
  static let darkInk = Color(hex: 0x11131A)
  static let quietFill = Color.black.opacity(0.035)
  static let controlFill = Color.black.opacity(0.06)
  static let inverseControlFill = Color.white.opacity(0.14)
  static let glassPanel = Color.white.opacity(0.80)
  static let tonalLavender = Color(hex: 0xDDDFF8)
  static let tonalBlush = Color(hex: 0xE5E7FB)
  static let tonalSage = Color(hex: 0xEAF0FF)
  static let tonalSand = Color(hex: 0xEEF2FF)
}

extension Color {
  init(hex: UInt, alpha: Double = 1) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255,
      opacity: alpha
    )
  }
}

enum TrainerFont {
  static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
    .system(size: size, weight: weight, design: .rounded)
  }

  static func title(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
    .system(size: size, weight: weight, design: .rounded)
  }

  static func label(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
    .system(size: size, weight: weight, design: .rounded)
  }

  static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight, design: .default)
  }
}

enum TrainerSymbol {
  static let board = "rectangle.grid.2x2"
  static let summary = "rectangle.stack"
  static let members = "person.crop.rectangle.stack"
  static let member = "person.crop.circle"
  static let soap = "note.text"
  static let reports = "chart.line.uptrend.xyaxis"
  static let settings = "slider.horizontal.3"
  static let pencil = "pencil.tip"
  static let save = "arrow.down.doc"
  static let share = "paperplane"
  static let confirm = "checkmark.circle"
  static let openDocument = "doc.text"
  static let calendar = "calendar"
  static let target = "scope"
  static let pain = "waveform.path.ecg"
  static let warning = "exclamationmark.triangle"
  static let add = "plus.circle"
  static let delete = "trash"
  static let chevron = "chevron.right"
  static let undo = "arrow.uturn.backward"
  static let login = "person.crop.circle.badge.checkmark"
  static let signOut = "rectangle.portrait.and.arrow.forward"
  static let refresh = "arrow.clockwise"
  static let checklist = "list.bullet.rectangle"
  static let protectedShare = "person.crop.circle.badge.checkmark"
  static let lock = "lock.shield"
  static let exercise = "figure.strengthtraining.traditional"
  static let checkedList = "checklist.checked"
  static let highlighter = "highlighter"
  static let eraser = "eraser"
  static let pause = "pause.fill"
  static let play = "play.fill"
  static let prepare = "checklist"
  static let timer = "timer"
}

enum TrainerGradient {
  static let actionBlue = LinearGradient(
    colors: [Color(hex: 0x7F8AF2), Color(hex: 0x5360CF)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  static let actionBlueSoft = LinearGradient(
    colors: [Color(hex: 0xEEF0FF), Color(hex: 0xDADDF8)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  static let avatarBlue = LinearGradient(
    colors: [Color(hex: 0xF4E8EF), Color(hex: 0xDEE3FA), Color(hex: 0xBFC7F0)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )
}

struct TrainerAvatar: View {
  let initial: String
  let tint: Color
  let imageURL: URL?
  let accessibilityName: String
  var size: CGFloat = 48

  init(
    initial: String,
    tint: Color,
    size: CGFloat = 48,
    imageURL: URL? = nil,
    accessibilityName: String = "회원 아바타"
  ) {
    self.initial = initial
    self.tint = tint
    self.size = size
    self.imageURL = imageURL
    self.accessibilityName = accessibilityName
  }

  init(member: TrainerMember, size: CGFloat = 48) {
    self.initial = member.initial
    self.tint = member.risk.color
    self.size = size
    self.imageURL = member.avatarURL
    self.accessibilityName = "\(member.name) 회원 아바타"
  }

  var body: some View {
    Group {
      if let imageURL {
        AsyncImage(
          url: imageURL,
          transaction: Transaction(animation: .easeInOut(duration: 0.18))
        ) { phase in
          switch phase {
          case .success(let image):
            image
              .resizable()
              .scaledToFill()
              .background(TrainerGradient.avatarBlue)
              .transition(.opacity)
          case .failure:
            fallbackAvatar
          case .empty:
            fallbackAvatar
              .opacity(0.72)
          @unknown default:
            fallbackAvatar
          }
        }
      } else {
        fallbackAvatar
      }
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
    .overlay(
      Circle()
        .stroke(TrainerColor.inverseText.opacity(0.68), lineWidth: 1)
    )
    .shadow(color: TrainerColor.blue.opacity(0.16), radius: size * 0.18, x: 0, y: size * 0.08)
    .accessibilityLabel(accessibilityName)
  }

  private var fallbackAvatar: some View {
    ZStack {
      Circle()
        .fill(TrainerGradient.avatarBlue)
        .overlay(
          Circle()
            .fill(tint.opacity(0.10))
        )

      Circle()
        .fill(
          LinearGradient(
            colors: [Color(hex: 0xFFF7F2), Color(hex: 0xE9D0C8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .frame(width: size * 0.34, height: size * 0.34)
        .offset(y: -size * 0.12)
        .shadow(color: TrainerColor.darkInk.opacity(0.08), radius: size * 0.05, x: 0, y: size * 0.03)

      RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
        .fill(
          LinearGradient(
            colors: [TrainerColor.blue.opacity(0.96), TrainerColor.deepBlue.opacity(0.82)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .frame(width: size * 0.50, height: size * 0.28)
        .offset(y: size * 0.20)

      Circle()
        .fill(TrainerColor.inverseText.opacity(0.42))
        .frame(width: size * 0.16, height: size * 0.16)
        .blur(radius: size * 0.045)
        .offset(x: -size * 0.17, y: -size * 0.21)

      Text(initial)
        .font(TrainerFont.label(size * 0.22, weight: .bold))
        .foregroundStyle(tint)
        .frame(width: size * 0.34, height: size * 0.24)
        .background(TrainerColor.card.opacity(0.72), in: Capsule())
        .offset(y: size * 0.31)
    }
    .frame(width: size, height: size)
  }
}

struct TrainerPrimaryButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(TrainerFont.label(15, weight: .bold))
      .foregroundStyle(TrainerColor.inverseText)
      .frame(maxWidth: .infinity)
      .frame(height: 48)
      .background(TrainerGradient.actionBlue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      .opacity(isEnabled ? 1 : 0.46)
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(TrainerColor.inverseText.opacity(configuration.isPressed ? 0.18 : 0.32), lineWidth: 1)
      )
      .shadow(color: TrainerColor.blue.opacity(configuration.isPressed ? 0.10 : 0.22), radius: configuration.isPressed ? 8 : 18, x: 0, y: configuration.isPressed ? 4 : 10)
      .scaleEffect(configuration.isPressed ? 0.985 : 1)
  }
}

struct TrainerSecondaryButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(TrainerFont.label(15, weight: .bold))
      .foregroundStyle(TrainerColor.blue)
      .frame(maxWidth: .infinity)
      .frame(height: 48)
      .background(TrainerGradient.actionBlueSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      .opacity(isEnabled ? 1 : 0.46)
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(TrainerColor.blue.opacity(configuration.isPressed ? 0.22 : 0.34), lineWidth: 1)
      )
      .scaleEffect(configuration.isPressed ? 0.985 : 1)
  }
}

struct TrainerCompactPrimaryButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(TrainerFont.label(14, weight: .bold))
      .foregroundStyle(TrainerColor.inverseText)
      .padding(.horizontal, 16)
      .frame(height: 42)
      .background(TrainerGradient.actionBlue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(TrainerColor.inverseText.opacity(configuration.isPressed ? 0.18 : 0.30), lineWidth: 1)
      )
      .opacity(isEnabled ? 1 : 0.46)
      .shadow(color: TrainerColor.blue.opacity(configuration.isPressed ? 0.08 : 0.18), radius: configuration.isPressed ? 6 : 14, x: 0, y: configuration.isPressed ? 3 : 8)
      .scaleEffect(configuration.isPressed ? 0.985 : 1)
  }
}

struct TrainerCompactSecondaryButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(TrainerFont.label(14, weight: .bold))
      .foregroundStyle(TrainerColor.blue)
      .padding(.horizontal, 16)
      .frame(height: 42)
      .background(TrainerGradient.actionBlueSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(TrainerColor.blue.opacity(configuration.isPressed ? 0.20 : 0.32), lineWidth: 1)
      )
      .opacity(isEnabled ? 1 : 0.46)
      .scaleEffect(configuration.isPressed ? 0.985 : 1)
  }
}

struct TrainerDestructiveButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(TrainerFont.label(15, weight: .bold))
      .foregroundStyle(TrainerColor.red)
      .frame(maxWidth: .infinity)
      .frame(height: 48)
      .background(TrainerColor.tonalBlush.opacity(0.74), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(TrainerColor.red.opacity(configuration.isPressed ? 0.20 : 0.32), lineWidth: 1)
      )
      .opacity(isEnabled ? 1 : 0.42)
      .scaleEffect(configuration.isPressed ? 0.985 : 1)
  }
}

struct HealthCard<Content: View>: View {
  let padding: CGFloat
  let content: Content

  init(padding: CGFloat = 22, @ViewBuilder content: () -> Content) {
    self.padding = padding
    self.content = content()
  }

  var body: some View {
    content
      .padding(padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        TrainerColor.card.opacity(0.82),
        in: RoundedRectangle(cornerRadius: 24, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .stroke(TrainerColor.border, lineWidth: 1)
      )
      .shadow(color: Color.black.opacity(0.055), radius: 20, x: 0, y: 10)
  }
}

struct StudioBackdrop: View {
  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(hex: 0xF8FAFF),
          Color(hex: 0xF2F1FF),
          Color(hex: 0xEEF5FF),
          Color(hex: 0xF9FBFF)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      RadialGradient(
        colors: [TrainerColor.blue.opacity(0.16), .clear],
        center: .center,
        startRadius: 20,
        endRadius: 540
      )
      RadialGradient(
        colors: [TrainerColor.purple.opacity(0.12), .clear],
        center: .bottomTrailing,
        startRadius: 20,
        endRadius: 520
      )
    }
  }
}

struct StudioHeroCard<Content: View>: View {
  let content: Content
  let label: String?

  init(label: String? = nil, @ViewBuilder content: () -> Content) {
    self.label = label
    self.content = content()
  }

  var body: some View {
    content
      .padding(24)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background {
        ZStack {
          LinearGradient(
            colors: [TrainerColor.deepBlue, TrainerColor.blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
          RadialGradient(
            colors: [TrainerColor.inverseText.opacity(0.20), .clear],
            center: .topTrailing,
            startRadius: 20,
            endRadius: 340
          )
          RadialGradient(
            colors: [TrainerColor.purple.opacity(0.16), .clear],
            center: .bottomLeading,
            startRadius: 20,
            endRadius: 360
          )
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
      }
      .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
      .shadow(color: TrainerColor.blue.opacity(0.16), radius: 30, x: 0, y: 16)
      .trainerLabel(label)
  }
}

private struct TrainerWidgetLabelModifier: ViewModifier {
  let label: String?
  let alignment: Alignment

  /// 디자인 QA용 라벨은 `--design-labels` 실행 인자가 있을 때만 노출.
  /// 평소(시뮬레이터 실행, 사용자 빌드)에는 숨겨서 콘텐츠를 가리지 않는다.
  private static let isEnabled = ProcessInfo.processInfo.arguments.contains("--design-labels")

  func body(content: Content) -> some View {
    content.overlay(alignment: alignment) {
      if Self.isEnabled, let label, !label.isEmpty {
        Text(label)
          .font(.system(size: 10, weight: .heavy, design: .monospaced))
          .foregroundStyle(TrainerColor.inverseText)
          .lineLimit(1)
          .frame(maxWidth: 180, alignment: .leading)
          .padding(.horizontal, 7)
          .padding(.vertical, 4)
          .background(
            Capsule()
              .fill(TrainerColor.darkInk.opacity(0.84))
          )
          .overlay(
            Capsule()
              .stroke(TrainerColor.inverseText.opacity(0.35), lineWidth: 0.7)
          )
          .shadow(color: Color.black.opacity(0.18), radius: 5, x: 0, y: 2)
          .padding(6)
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }
    }
  }
}

extension View {
  func trainerLabel(_ label: String?, alignment: Alignment = .topLeading) -> some View {
    modifier(TrainerWidgetLabelModifier(label: label, alignment: alignment))
  }
}

struct IconTile: View {
  let symbol: String
  let color: Color

  var body: some View {
    Image(systemName: symbol)
      .font(TrainerFont.title(23, weight: .semibold))
      .foregroundStyle(color)
      .frame(width: 50, height: 50)
      .background(
        color.opacity(0.11),
        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
      )
  }
}

struct StatusCapsule: View {
  let text: String
  let color: Color

  var body: some View {
    Text(text)
      .font(TrainerFont.label(13, weight: .bold))
      .foregroundStyle(color)
      .padding(.horizontal, 11)
      .padding(.vertical, 7)
      .background(color.opacity(0.12), in: Capsule())
  }
}

struct NativeSegmentedControl: View {
  let values: [String]
  @Binding var selection: String
  var label: String? = nil

  var body: some View {
    HStack(spacing: 3) {
      ForEach(values, id: \.self) { value in
        Button {
          selection = value
        } label: {
          Text(value)
            .font(TrainerFont.label(13, weight: .semibold))
            .foregroundStyle(selection == value ? TrainerColor.inverseText : TrainerColor.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(
              selection == value ? TrainerColor.blue : Color.clear,
              in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
        }
        .buttonStyle(.plain)
      }
    }
    .padding(3)
    .background(
      TrainerColor.controlFill,
      in: RoundedRectangle(cornerRadius: 12, style: .continuous)
    )
    .trainerLabel(label)
  }
}

struct MetricTile: View {
  let title: String
  let value: String
  let unit: String
  let symbol: String
  let color: Color

  var body: some View {
    HealthCard(padding: 18) {
      HStack(alignment: .top, spacing: 14) {
        IconTile(symbol: symbol, color: color)
        VStack(alignment: .leading, spacing: 7) {
          Text(title)
            .font(TrainerFont.label(14, weight: .semibold))
            .foregroundStyle(color)
          HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
              .font(TrainerFont.display(30, weight: .bold))
              .foregroundStyle(TrainerColor.primaryText)
            if !unit.isEmpty {
              Text(unit)
                .font(TrainerFont.label(14, weight: .semibold))
                .foregroundStyle(TrainerColor.secondaryText)
            }
          }
        }
        Spacer(minLength: 0)
      }
    }
  }
}

struct HealthSectionHeader: View {
  let title: String
  var actionTitle: String? = nil
  var label: String? = nil
  var action: (() -> Void)? = nil

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(title)
        .font(TrainerFont.title(22, weight: .bold))
        .foregroundStyle(TrainerColor.primaryText)
      Spacer()
      if let actionTitle, let action {
        Button(actionTitle, action: action)
          .font(TrainerFont.label(15, weight: .semibold))
          .foregroundStyle(TrainerColor.blue)
          .buttonStyle(.plain)
          .trainerLabel(label.map { "\($0)-ACTION" }, alignment: .topTrailing)
      }
    }
    .trainerLabel(label)
  }
}

struct HealthFavoriteTile: View {
  let title: String
  let value: String
  let unit: String
  let symbol: String
  let color: Color
  var footnote: String = ""
  var label: String? = nil

  var body: some View {
    HealthCard(padding: 16) {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 8) {
          Image(systemName: symbol)
            .font(TrainerFont.label(16, weight: .bold))
            .foregroundStyle(color)
          Text(title)
            .font(TrainerFont.label(14, weight: .bold))
            .foregroundStyle(color)
          Spacer()
        }

        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text(value)
            .font(TrainerFont.display(31, weight: .bold))
            .foregroundStyle(TrainerColor.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
          if !unit.isEmpty {
              Text(unit)
                .font(TrainerFont.label(14, weight: .semibold))
              .foregroundStyle(TrainerColor.secondaryText)
          }
        }

        if !footnote.isEmpty {
          Text(footnote)
            .font(TrainerFont.body(13, weight: .medium))
            .foregroundStyle(TrainerColor.secondaryText)
            .lineLimit(1)
        }
      }
    }
    .trainerLabel(label)
  }
}

struct HealthTrendRow: View {
  let title: String
  let subtitle: String
  let symbol: String
  let color: Color
  let value: String
  var label: String? = nil

  var body: some View {
    HStack(spacing: 13) {
      IconTile(symbol: symbol, color: color)
        .scaleEffect(0.84)
        .frame(width: 42, height: 42)
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(TrainerFont.label(16, weight: .semibold))
          .foregroundStyle(TrainerColor.primaryText)
        Text(subtitle)
          .font(TrainerFont.body(13, weight: .medium))
          .foregroundStyle(TrainerColor.secondaryText)
          .lineLimit(1)
      }
      Spacer()
      Text(value)
        .font(TrainerFont.label(15, weight: .bold))
        .foregroundStyle(color)
      Image(systemName: TrainerSymbol.chevron)
        .font(TrainerFont.label(12, weight: .semibold))
        .foregroundStyle(TrainerColor.tertiaryText)
    }
    .padding(.vertical, 10)
    .trainerLabel(label)
  }
}
