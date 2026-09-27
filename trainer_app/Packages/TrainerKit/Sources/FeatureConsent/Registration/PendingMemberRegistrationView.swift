import SwiftUI
import TrainerDomain

/// TR-14 회원 등록 (DF-108, F-LINK-01.1): display name, sex, birth year and the age-14 confirmation, nothing else. No
/// phone, email or address field, no height (F-LINK-01.4, R-30). Copy is the V1-12 deck's `tr14.register.*`.
public struct PendingMemberRegistrationView: View {
  @State private var model: PendingMemberRegistrationModel
  private let onRegistered: (MemberKey) -> Void
  private let onCancel: () -> Void

  public init(model: PendingMemberRegistrationModel, onRegistered: @escaping (MemberKey) -> Void,
              onCancel: @escaping () -> Void) {
    _model = State(initialValue: model)
    self.onRegistered = onRegistered
    self.onCancel = onCancel
  }

  public var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField(text: $model.draft.displayName) { Text("tr14.register.displayName", bundle: .main) }
            .textContentType(.name)
            .accessibilityIdentifier("tr14.register.displayName")
        }
        Section {
          SexChoice(selection: $model.draft.sex)
        } header: {
          Text("tr14.register.sex", bundle: .main).accessibilityAddTraits(.isHeader)
        }
        Section {
          Picker(selection: $model.draft.birthYear) {
            Text(verbatim: "—").tag(Int?.none)
            ForEach(model.years, id: \.self) { year in
              Text(verbatim: String(year)).tag(Int?.some(year))
            }
          } label: {
            Text("tr14.register.birthYear", bundle: .main)
          }
          .pickerStyle(.menu)
          .accessibilityIdentifier("tr14.register.birthYear")
          if model.showsUnder14Block {
            Text("tr14.register.under14Blocked", bundle: .main)
              .foregroundStyle(.red)
              .accessibilityIdentifier("tr14.register.under14Blocked")
          }
        }
        Section {
          Toggle(isOn: $model.draft.ageConfirmed14) { Text("tr14.register.age14Confirm", bundle: .main) }
            .accessibilityIdentifier("tr14.register.age14Confirm")
        }
        if model.saveFailed {
          Section {
            Text("common.devDefect", bundle: .main)
              .foregroundStyle(.red)
              .accessibilityIdentifier("tr14.register.saveFailed")
          }
        }
      }
      .navigationTitle(Text("tr14.register.title", bundle: .main))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button { onCancel() } label: { Text("common.cancel", bundle: .main) }
            .disabled(model.isSaving)  // a save in progress would open the consent sheet after the form closed
            .accessibilityIdentifier("tr14.register.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button {
            Task { if let member = await model.save() { onRegistered(member) } }
          } label: {
            Text("tr14.register.next", bundle: .main)
          }
          .disabled(!model.canSave)
          .accessibilityIdentifier("tr14.register.next")
        }
      }
    }
    // A swipe must not drop a save in progress or one already made (V1-07 §3.2).
    .interactiveDismissDisabled(model.isSaving || model.didSave)
    .onChange(of: model.showsUnder14Block) { _, blocked in
      guard blocked else { return }
      AccessibilityNotification.Announcement(
        String(localized: String.LocalizationValue("tr14.register.under14Blocked"), bundle: .main)).post()
    }
    .accessibilityIdentifier("tr14.register.root")
  }
}

/// Female / male / unspecified, nothing chosen at first (AC-DF-108.1). A checkmark marks the choice, not colour alone.
private struct SexChoice: View {
  @Binding var selection: Sex?

  /// The key is built as a `String` first: an interpolated literal passed to `LocalizationValue` would become the
  /// format key `tr14.register.sex.%@` (SE-0213) and show the raw key.
  static func label(_ sex: Sex) -> String {
    let key = "tr14.register.sex." + sex.rawValue
    return String(localized: String.LocalizationValue(key), bundle: .main)
  }

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 8) { options }
      VStack(alignment: .leading, spacing: 8) { options }
    }
  }

  private var options: some View {
    ForEach(Sex.allCases, id: \.self) { sex in
      let selected = selection == sex
      Button {
        selection = sex
      } label: {
        Label {
          // One line each: at iPhone width the row then no longer fits and the options stack (ViewThatFits),
          // instead of breaking '여성' into '여/성'.
          Text(Self.label(sex)).lineLimit(1).fixedSize()
        } icon: {
          Image(systemName: selected ? "checkmark.circle.fill" : "circle")
        }
        .frame(minWidth: 44, minHeight: 44)
        .padding(.horizontal, 8)
      }
      .buttonStyle(.bordered)
      .tint(selected ? .accentColor : .secondary)
      .accessibilityAddTraits(selected ? .isSelected : [])
      .accessibilityIdentifier("tr14.register.sex.\(sex.rawValue)")
    }
  }
}
