import DesignSystem
import SwiftUI
import TrainerContracts
import TrainerDomain

/// TR-11 신체조성 입력, new-record mode (DF-127, V1-07 §4.11): a sheet from TR-03 '측정 입력 > 신체조성'.
///
/// - Values with their units; a blank field is unmeasured and stores no key (F-BC-03.1). A comma is a decimal point.
/// - Required meta: the device (this iPad's list, '기기 추가'), when it was measured (default now, editable) and fasting
///   yes/no with no default ('모름' only in the secondary menu). The time of day is shown, never edited.
/// - The height row only with consent ②; BMI is derived from it or '미측정'.
/// - Range errors under their field, cross-consistency warnings that still allow saving, and saving off (with the
///   reasons) until the meta, a value and consent ② are there.
/// - With the `bodyComposition` flag turned off while it is open, the fields are locked under `flag.disabled`, and
///   what was typed stays (V1-07 §3.6, ASM-07-06).
public struct BodyCompositionEntryView: View {
  @Bindable private var model: BodyCompositionEntryModel
  private let localize: Localizer
  private let onCancel: () -> Void
  @State private var addingDevice = false
  @State private var newDeviceName = ""

  /// Once saved, `model.savedRecordId` is set and the sheet shows the record.
  public init(model: BodyCompositionEntryModel, localize: Localizer = .main, onCancel: @escaping () -> Void) {
    self.model = model
    self.localize = localize
    self.onCancel = onCancel
  }

  public var body: some View {
    Form {
      if !model.isFeatureOn {
        Section {
          Label { Text(localize("flag.disabled")) } icon: { Image(systemName: "nosign") }
            .foregroundStyle(TrainerColor.danger)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("tr11.flagDisabled")
        }
      }
      if model.showsConsentNeeded {
        Section {
          Label { Text(localize(BodyCompositionCopy.consentNeeded)) } icon: { Image(systemName: "lock") }
            .foregroundStyle(TrainerColor.danger)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("tr11.consentNeeded")
        }
      } else if model.savesLocallyOnly {
        Section {
          Text(localize("consent.state.awaiting"))
            .accessibilityIdentifier("tr11.awaitingConsent")
        }
      }
      Group {
        metaSection
        valuesSection
        bmiSection
      }
      .disabled(!model.isFeatureOn)
      if model.hasWarnings {
        Section {
          ForEach(model.warningMessages, id: \.self) { message in
            Label { Text(message) } icon: { Image(systemName: "exclamationmark.triangle") }
              .foregroundStyle(TrainerColor.caution)
              .accessibilityElement(children: .combine)
          }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tr11.warnings")
      }
      if !model.missingMessages.isEmpty {
        Section {
          ForEach(model.missingMessages, id: \.self) { message in
            Text(message)
              .font(.footnote)
              .foregroundStyle(TrainerColor.neutral600)
          }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tr11.missing")
      }
      if model.saveFailed {
        Section {
          Text(localize("common.devDefect"))
            .foregroundStyle(TrainerColor.danger)
            .accessibilityIdentifier("tr11.saveFailed")
        }
      }
    }
    .navigationTitle(localize("tr11.title"))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button(localize("common.cancel")) { onCancel() }
          .disabled(model.isSaving)
          .accessibilityIdentifier("tr11.cancel")
      }
      ToolbarItem(placement: .confirmationAction) {
        // With a cross-consistency warning the trainer confirms by saving anyway (F-BC-03.3).
        Button(localize(model.hasWarnings ? "tr11.saveAnyway" : "common.saveAction")) {
          Task { _ = await model.save() }
        }
        .disabled(!model.canSave)
        .accessibilityIdentifier("tr11.save")
      }
    }
    .task { await model.prepare() }
    .alert(localize("tr11.deviceModel.add"), isPresented: $addingDevice) {
      TextField(localize("tr11.deviceModel"), text: $newDeviceName)
        .accessibilityIdentifier("tr11.deviceModel.newName")
      Button(localize("tr11.deviceModel.add")) {
        let name = newDeviceName
        Task { await model.addDevice(name) }
      }
      .accessibilityIdentifier("tr11.deviceModel.confirmAdd")
      Button(localize("common.cancel"), role: .cancel) {}
    }
    .accessibilityIdentifier("tr11.root")
  }

  // MARK: - Sections

  private var metaSection: some View {
    Section {
      DeviceModelPicker(
        selection: $model.draft.deviceModel, names: model.deviceModels, localize: localize,
        onAdd: {
          newDeviceName = ""
          addingDevice = true
        })
      if model.showsDeviceChanged {
        Label { Text(localize(BodyCompositionCopy.deviceChanged)) } icon: { Image(systemName: "arrow.left.arrow.right") }
          .font(.footnote)
          .foregroundStyle(TrainerColor.caution)
          .accessibilityElement(children: .combine)
          .accessibilityIdentifier("tr11.deviceChanged")
      }
      DatePicker(selection: $model.draft.measuredAt, in: ...Date().addingTimeInterval(BodyCompositionValidator.futureTolerance),
                 displayedComponents: [.date, .hourAndMinute]) {
        Text(localize("tr11.measuredAt"))
      }
      .accessibilityIdentifier("tr11.measuredAt")
      if let message = model.measuredAtMessage {
        FieldMessage(text: message)
      }
      FastingChoice(selection: $model.draft.fasting, localize: localize)
      LabeledContent {
        Text(model.timeOfDayText)
          .foregroundStyle(TrainerColor.neutral700)
      } label: {
        Text(localize("tr11.timeOfDayBand"))
      }
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("tr11.timeOfDayBand")
    }
  }

  private var valuesSection: some View {
    Section {
      ForEach(BodyCompositionKey.allCases.filter(\.isPrimary), id: \.self) { key in
        valueField(key)
      }
      DisclosureGroup(isExpanded: $model.showsMoreValues) {
        ForEach(BodyCompositionKey.allCases.filter { !$0.isPrimary }, id: \.self) { key in
          valueField(key)
        }
      } label: {
        Text(localize("tr11.more"))
      }
      .accessibilityIdentifier("tr11.more")
    }
  }

  private var bmiSection: some View {
    Section {
      if model.showsHeight {
        NumericField(
          name: localize("tr11.height"), unit: localize("unit.cm"), placeholder: localize(BodyCompositionCopy.unmeasured),
          text: Binding(get: { model.draft.heightCmInput ?? "" }, set: { model.setHeight($0) }),
          message: model.errorMessage(for: .height), identifier: "tr11.height")
      }
      LabeledContent {
        HStack(spacing: TrainerSpacing.s) {
          Text(model.bmiText)
            .font(.body.monospacedDigit())
          if model.hasBMI {
            SourceGradeChip(grade: .derived, localize: localize)
          }
        }
      } label: {
        Text(localize(BodyCompositionCopy.bmiName))
      }
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("tr11.bmi")
      if model.showsHeight, !model.hasBMI {
        Text(localize("tr11.bmi.needsHeight"))
          .font(.footnote)
          .foregroundStyle(TrainerColor.neutral600)
      }
    }
  }

  private func valueField(_ key: BodyCompositionKey) -> some View {
    NumericField(
      name: localize(key.nameCopyKey), unit: localize("unit." + key.unit.rawValue),
      placeholder: localize(BodyCompositionCopy.unmeasured),
      text: Binding(get: { model.draft.values[key] ?? "" }, set: { model.draft.values[key] = $0 }),
      message: model.errorMessage(for: .value(key)), identifier: "tr11.value." + key.rawValue)
  }
}

/// A labelled decimal field with its unit and the message under it (V1-07 §3.12 `NumericField`). Blank is '미측정'.
/// At accessibility text sizes the label goes above the field so nothing is cut (AC-A11Y-02).
struct NumericField: View {
  let name: String
  let unit: String
  let placeholder: String
  @Binding var text: String
  let message: String?
  let identifier: String

  var body: some View {
    VStack(alignment: .leading, spacing: TrainerSpacing.xs) {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: TrainerSpacing.m) {
          Text(name)
          Spacer(minLength: TrainerSpacing.s)
          field
            .frame(maxWidth: 180)
          Text(unit)
            .foregroundStyle(TrainerColor.neutral600)
        }
        VStack(alignment: .leading, spacing: TrainerSpacing.xs) {
          Text(name)
          HStack(spacing: TrainerSpacing.s) {
            field
            Text(unit)
              .foregroundStyle(TrainerColor.neutral600)
          }
        }
      }
      if let message {
        FieldMessage(text: message)
      }
    }
    .frame(minHeight: TrainerSpacing.minTapTarget)
  }

  private var field: some View {
    TextField(text: $text, prompt: Text(placeholder)) { Text(name) }
      .keyboardType(.decimalPad)
      .multilineTextAlignment(.trailing)
      .font(.body.monospacedDigit())
      .accessibilityValue(message.map { text.isEmpty ? $0 : text + ", " + $0 } ?? text)
      .accessibilityIdentifier(identifier)
  }
}

/// A field's error, in the danger colour with an icon (not colour alone).
struct FieldMessage: View {
  let text: String

  var body: some View {
    Label { Text(text) } icon: { Image(systemName: "exclamationmark.circle") }
      .font(.footnote)
      .foregroundStyle(TrainerColor.danger)
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityElement(children: .combine)
  }
}

/// Fasting: '공복' / '공복 아님', nothing chosen at first; '모름' only in the ⋯ menu (AC-DF-127.9). A checkmark marks
/// the choice, not colour alone.
struct FastingChoice: View {
  @Binding var selection: Fasting?
  let localize: Localizer

  var body: some View {
    VStack(alignment: .leading, spacing: TrainerSpacing.s) {
      Text(localize("tr11.fasting"))
      ViewThatFits(in: .horizontal) {
        HStack(spacing: TrainerSpacing.s) { options }
        VStack(alignment: .leading, spacing: TrainerSpacing.s) { options }
      }
    }
    .padding(.vertical, TrainerSpacing.xs)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("tr11.fasting")
  }

  @ViewBuilder
  private var options: some View {
    ForEach(Fasting.primaryChoices, id: \.self) { value in
      choice(value)
    }
    if selection == .unknown {
      choice(.unknown)
    }
    Menu {
      Button(localize(Fasting.unknown.copyKey)) { selection = .unknown }
        .accessibilityIdentifier("tr11.fasting.unknown")
    } label: {
      Image(systemName: "ellipsis.circle")
        .frame(minWidth: TrainerSpacing.minTapTarget, minHeight: TrainerSpacing.minTapTarget)
    }
    .accessibilityLabel(localize("tr11.fasting.more"))
    .accessibilityIdentifier("tr11.fasting.more")
  }

  private func choice(_ value: Fasting) -> some View {
    let selected = selection == value
    return Button {
      selection = value
    } label: {
      Label {
        Text(localize(value.copyKey))
      } icon: {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
      }
      .frame(minWidth: TrainerSpacing.minTapTarget, minHeight: TrainerSpacing.minTapTarget)
      .padding(.horizontal, TrainerSpacing.s)
    }
    .buttonStyle(.bordered)
    .tint(selected ? .accentColor : .secondary)
    .accessibilityAddTraits(selected ? .isSelected : [])
    .accessibilityIdentifier("tr11.fasting." + value.rawValue)
  }
}
