import SwiftUI
import TrainerContracts
import TrainerDomain

/// One published card, with two equally available explicit answers (AC-DF-110.1/.2/.9).
public struct ConsentCardView: View {
  public let document: ConsentDocumentVersion
  public let selection: Bool?
  public let effective: EffectiveConsentValue
  public let isEnabled: Bool
  public let onSelect: (Bool) -> Void

  public init(document: ConsentDocumentVersion, selection: Bool?, effective: EffectiveConsentValue,
              isEnabled: Bool = true, onSelect: @escaping (Bool) -> Void) {
    self.document = document
    self.selection = selection
    self.effective = effective
    self.isEnabled = isEnabled
    self.onSelect = onSelect
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(document.title).font(.title3.weight(.semibold)).accessibilityAddTraits(.isHeader)
      Text(versionLabel).font(.caption).foregroundStyle(.secondary)
      disclosure("tr14.consent.purpose", text: document.purpose)
      disclosure("tr14.consent.items", text: document.items.joined(separator: ", "))
      disclosure("tr14.consent.retention", text: document.retention)
      disclosure("tr14.consent.refusal", text: document.refusalNotice)
      if effective == .granted || effective == .awaitingConsent {
        Label {
          Text(effective == .granted ? "tr14.consent.grant" : "consent.state.awaiting", bundle: .main)
        } icon: {
          Image(systemName: effective == .granted ? "checkmark.circle" : "clock")
        }
        .font(.subheadline.weight(.semibold))
        .accessibilityIdentifier("tr14.card.\(document.consentType.rawValue).state")
      } else {
        ViewThatFits(in: .horizontal) {
          HStack(spacing: 12) { choices }
          VStack(alignment: .leading, spacing: 12) { choices }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .background(.background, in: RoundedRectangle(cornerRadius: 16))
    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.secondary.opacity(0.25)))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("tr14.card.\(document.consentType.rawValue)")
  }

  private var versionLabel: String {
    String(format: localized("tr14.consent.version"), document.version)
  }

  private func disclosure(_ key: String, text: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(LocalizedStringKey(key), bundle: .main).font(.subheadline.weight(.semibold))
      Text(text).font(.body).fixedSize(horizontal: false, vertical: true)
    }
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder private var choices: some View {
    answer(true, key: "tr14.consent.grant", identifier: "agree")
    answer(false, key: "tr14.consent.refuse", identifier: "disagree")
  }

  private func answer(_ granted: Bool, key: String, identifier: String) -> some View {
    let selected = selection == granted
    return Button { onSelect(granted) } label: {
      Label {
        Text(LocalizedStringKey(key), bundle: .main).fixedSize(horizontal: true, vertical: false)
      } icon: {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
      }
      .frame(minHeight: 44)
      .padding(.horizontal, 8)
    }
    .buttonStyle(.bordered)
    .tint(selected ? .accentColor : .secondary)
    .disabled(!isEnabled)
    .accessibilityLabel(localized("consent.type." + document.consentType.rawValue) + " " + localized(key))
    .accessibilityAddTraits(selected ? .isSelected : [])
    .accessibilityIdentifier("tr14.card.\(document.consentType.rawValue).\(identifier)")
  }

  private func localized(_ key: String) -> String {
    String(localized: String.LocalizationValue(key), bundle: .main)
  }
}
