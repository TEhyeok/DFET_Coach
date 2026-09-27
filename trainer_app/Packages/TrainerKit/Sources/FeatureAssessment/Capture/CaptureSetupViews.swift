import SwiftUI
import TrainerContracts
import TrainerDomain

/// TR-07 top line in the DEC-22 MVP: the station's name and camera values, so the trainer sets the camera to them
/// (DF-203). The default station's name is a catalog key that says the values are a draft. No edit button in the MVP.
public struct StationSummaryView: View {
  private let station: StationProfileValue

  public init(station: StationProfileValue) {
    self.station = station
  }

  public var body: some View {
    Text(Self.summary(station))
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .accessibilityIdentifier("tr07.station.summary")
  }

  /// `tr07.station.defaultSummary` with one decimal for both values (V1-12 §2.6: `100.0cm`, not `100cm`). The
  /// default station's name is a catalog key; a trainer's own station name is shown as typed.
  static func summary(
    _ station: StationProfileValue,
    localize: (String) -> String = { String(localized: String.LocalizationValue($0), bundle: .main) }
  ) -> String {
    let name = station.name == DefaultStation.nameKey ? localize(DefaultStation.nameKey) : station.name
    return String(
      format: localize("tr07.station.defaultSummary"),
      name, oneDecimal(station.cameraHeightCm), oneDecimal(station.cameraDistanceM))
  }

  static func oneDecimal(_ value: Double) -> String {
    String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
  }
}

/// TR-07 clothing row: one of the protocol's options, nothing preselected, chosen again for every new draft
/// (DF-203 MVP; clothing is a comparison key, V1-05 §7.4). Labels are the deck's `clothing.<value>` keys.
public struct ClothingPicker: View {
  @Binding private var selection: Clothing?

  public init(selection: Binding<Clothing?>) {
    _selection = selection
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("tr07.checklist.clothing", bundle: .main)
        .font(.subheadline.weight(.semibold))
        .accessibilityAddTraits(.isHeader)
      // Side by side while the labels fit; stacked at large Dynamic Type sizes in the narrow side panel.
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 8) { options }
        VStack(alignment: .leading, spacing: 8) { options }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("tr07.checklist.clothing")
  }

  private var options: some View {
    ForEach(PostureProtocolV1.clothingOptions, id: \.self) { option in
      let selected = selection == option
      Button {
        selection = option
      } label: {
        // A checkmark as well as the fill, so the choice does not rest on colour alone.
        Label {
          Text(String(localized: String.LocalizationValue("clothing.\(option.rawValue)"), bundle: .main))
        } icon: {
          Image(systemName: selected ? "checkmark.circle.fill" : "circle")
        }
        .frame(minWidth: 44, minHeight: 44)
        .padding(.horizontal, 12)
      }
      .modifier(ClothingButtonStyle(selected: selected))
      .accessibilityAddTraits(selected ? .isSelected : [])
      .accessibilityIdentifier("tr07.clothing.\(option.rawValue)")
    }
  }
}

private struct ClothingButtonStyle: ViewModifier {
  let selected: Bool

  func body(content: Content) -> some View {
    if selected {
      content.buttonStyle(.borderedProminent)
    } else {
      content.buttonStyle(.bordered).tint(.secondary)
    }
  }
}
