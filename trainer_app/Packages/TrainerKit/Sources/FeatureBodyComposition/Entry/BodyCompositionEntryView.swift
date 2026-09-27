import DesignSystem
import SwiftUI
import TrainerContracts
import TrainerDomain

/// TR-11: manual measurement input, local-save feedback, and a live record history/mini trend.
public struct BodyCompositionEntryView: View {
  @State private var model: BodyCompositionEntryModel
  @State private var recordReload = 0
  private let onSaved: (String) -> Void
  private let onClose: () -> Void
  private let onRequestConsent: (() -> Void)?
  private let localize: Localizer

  public init(
    member: MemberKey, measurements: any MeasurementStore, consentSource: any EffectiveConsentSource,
    initialHeightCm: Double? = nil, initialHeightMeasuredAt: Date? = nil,
    deviceNames: [String] = [], defaultDeviceModel: String? = nil,
    onSaved: @escaping (String) -> Void = { _ in }, onClose: @escaping () -> Void,
    onRequestConsent: (() -> Void)? = nil, localize: Localizer = .main
  ) {
    self.init(model: BodyCompositionEntryModel(
      member: member, measurements: measurements, consentSource: consentSource,
      initialHeightCm: initialHeightCm, initialHeightMeasuredAt: initialHeightMeasuredAt,
      deviceNames: deviceNames, defaultDeviceModel: defaultDeviceModel),
      onSaved: onSaved, onClose: onClose, onRequestConsent: onRequestConsent, localize: localize)
  }

  public init(
    model: BodyCompositionEntryModel, onSaved: @escaping (String) -> Void = { _ in },
    onClose: @escaping () -> Void, onRequestConsent: (() -> Void)? = nil, localize: Localizer = .main
  ) {
    _model = State(initialValue: model)
    self.onSaved = onSaved
    self.onClose = onClose
    self.onRequestConsent = onRequestConsent
    self.localize = localize
  }

  public var body: some View {
    NavigationStack {
      Form {
        consentSection
        Group {
          metadataSection
          valuesSection
          if model.allowsHeightEntry { heightSection }
          issuesSection
        }
        .disabled(model.isSaving || model.savedRecordID != nil)
        resultSection
        historySection
      }
      .scrollDismissesKeyboard(.interactively)
      .navigationTitle(localize("tr11.title"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(action: onClose) { Text(localize("common.close")) }
            .disabled(model.isSaving)
            .accessibilityIdentifier("tr11.close")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button {
            Task { if let id = await model.save() { onSaved(id) } }
          } label: {
            if model.isSaving {
              ProgressView().accessibilityLabel(localize("tr11.saving"))
            } else {
              Text(localize("common.saveAction"))
            }
          }
          .disabled(!model.canSave)
          .accessibilityIdentifier("tr11.save")
        }
      }
    }
    .interactiveDismissDisabled(model.isSaving)
    .task { await model.observeConsent() }
    .task(id: model.savedRecordID) { await model.observeSavedState() }
    .task(id: recordReload) { await model.observeRecords() }
    .accessibilityIdentifier("tr11.root")
  }

  @ViewBuilder private var consentSection: some View {
    if !model.consent.canSaveHealthRecord {
      Section {
        Text(localize("tr11.consentNeeded"))
          .foregroundStyle(TrainerColor.caution)
          .accessibilityIdentifier("tr11.consentNeeded")
        if let onRequestConsent {
          Button(action: onRequestConsent) { Text(localize("tr11.openConsent")) }
        }
      }
    } else if model.consent.healthData == .awaitingConsent {
      Section { SyncStateBadge(state: .awaitingConsent, localize: localize) }
    }
  }

  private var metadataSection: some View {
    Section {
      VStack(alignment: .leading, spacing: TrainerSpacing.xs) {
        Text(localize("tr11.deviceModel")).font(.subheadline)
        TextField(localize("tr11.deviceModel"), text: Binding(
          get: { model.draft.deviceModel ?? "" }, set: model.setDevice))
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .accessibilityIdentifier("tr11.device")
        if !model.deviceNames.isEmpty {
          Menu {
            ForEach(model.deviceNames, id: \.self) { name in
              Button(name) { model.setDevice(name) }
            }
          } label: { Text(localize("tr11.deviceModel.recent")) }
          .accessibilityIdentifier("tr11.device.recent")
        }
      }
      DatePicker(selection: $model.draft.measuredAt, displayedComponents: [.date, .hourAndMinute]) {
        Text(localize("tr11.measuredAt"))
      }
      .accessibilityIdentifier("tr11.measuredAt")
      VStack(alignment: .leading, spacing: TrainerSpacing.s) {
        Text(localize("tr11.fasting")).font(.subheadline)
          .accessibilityIdentifier("tr11.fasting")
        ViewThatFits(in: .horizontal) {
          HStack { fastingChoices }
          VStack(alignment: .leading) { fastingChoices }
        }
        Menu {
          Button { model.draft.fasting = .unknown } label: { Text(localize("tr11.fasting.unknown")) }
        } label: {
          Label(localize("tr11.fasting.more"), systemImage: "ellipsis.circle")
        }
        .accessibilityIdentifier("tr11.fasting.more")
        if model.draft.fasting == .unknown {
          Text(localize("tr11.fasting.unknown")).font(.footnote)
        }
      }
      LabeledContent(localize("tr11.timeOfDayBand"), value: localize(model.validation.timeOfDayBand.copyKey))
    }
  }

  private var fastingChoices: some View {
    ForEach(Fasting.primaryChoices, id: \.self) { choice in
      let selected = model.draft.fasting == choice
      Button { model.draft.fasting = choice } label: {
        Label(localize(choice.copyKey), systemImage: selected ? "checkmark.circle.fill" : "circle")
          .labelStyle(.titleAndIcon)
          .fixedSize(horizontal: true, vertical: false)
          .frame(minHeight: TrainerSpacing.minTapTarget)
      }
      .buttonStyle(.bordered)
      .tint(selected ? TrainerColor.brandBlue : TrainerColor.neutral600)
      .accessibilityAddTraits(selected ? .isSelected : [])
      .accessibilityIdentifier("tr11.fasting.\(choice.rawValue)")
    }
  }

  private var valuesSection: some View {
    Section {
      ForEach(BodyCompositionKey.allCases.filter(\.isPrimary), id: \.self) { key in valueField(key) }
      DisclosureGroup(localize("tr11.more")) {
        ForEach(BodyCompositionKey.allCases.filter { !$0.isPrimary }, id: \.self) { key in valueField(key) }
      }
    } header: { Text(localize("tr11.values")) }
  }

  private func valueField(_ key: BodyCompositionKey) -> some View {
    NumericMeasurementField(
      label: localize(key.nameCopyKey), unit: localize("unit.\(key.unit.rawValue)"),
      text: Binding(get: { model.draft.values[key] ?? "" }, set: { model.draft.values[key] = $0 }),
      issues: model.validation.errors.filter { $0.field == .value(key) }, localize: localize,
      identifier: "tr11.value.\(key.rawValue)")
  }

  private var heightSection: some View {
    Section {
      NumericMeasurementField(
        label: localize("tr11.height"), unit: localize("unit.cm"),
        text: Binding(get: { model.draft.heightCmInput ?? "" }, set: model.setHeight),
        issues: model.validation.errors.filter { $0.field == .height }, localize: localize, identifier: "tr11.height")
      VStack(alignment: .leading, spacing: TrainerSpacing.xs) {
        LabeledContent(localize("metric.bmi.name")) {
          Text(model.validation.bmi.map { MetricRow.valueText($0, code: .bmi) } ?? localize("common.unmeasured"))
            .monospacedDigit()
        }
        SourceGradeChip(grade: .derived, localize: localize)
      }
      .accessibilityIdentifier("tr11.bmi")
    }
  }

  @ViewBuilder private var issuesSection: some View {
    let issues = model.validation.issues.filter { $0.field == nil }
    if !issues.isEmpty {
      Section {
        ForEach(issues, id: \.self) { issue in
          Label(BodyCompositionIssueText.text(issue, localize: localize),
                systemImage: issue.severity == .warning ? "exclamationmark.triangle" : "info.circle")
            .font(.footnote)
            .foregroundStyle(issue.severity == .warning ? TrainerColor.caution : TrainerColor.neutral600)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }

  @ViewBuilder private var resultSection: some View {
    if model.savedRecordID != nil {
      Section {
        SyncStateBadge(state: model.savedState, localize: localize)
        Button { model.beginNewEntry() } label: { Text(localize("tr11.newEntry")) }
          .accessibilityIdentifier("tr11.newEntry")
      }
    }
    if let errorKey = model.saveErrorKey {
      Section {
        Text(localize(errorKey)).foregroundStyle(TrainerColor.danger)
          .accessibilityIdentifier("tr11.saveFailed")
      }
    }
  }

  private var historySection: some View {
    Section {
      if model.isLoadingRecords {
        ProgressView().accessibilityLabel(localize("common.loading"))
      } else if model.recordsFailed {
        Text(localize("tr11.records.loadFailed")).foregroundStyle(TrainerColor.danger)
        Button { recordReload += 1 } label: { Text(localize("common.retry")) }
          .accessibilityIdentifier("tr11.records.retry")
      } else {
        BodyCompositionHistoryView(records: model.records, now: model.currentDate, localize: localize)
      }
    }
  }
}

enum BodyCompositionIssueText {
  static func text(_ issue: BodyCompositionIssue, localize: Localizer) -> String {
    guard let range = issue.range else { return localize(issue.copyKey) }
    return localize.format(issue.copyKey, range.minText, range.maxText, localize(range.unitCopyKey))
  }
}

private struct NumericMeasurementField: View {
  let label: String
  let unit: String
  @Binding var text: String
  let issues: [BodyCompositionIssue]
  let localize: Localizer
  let identifier: String

  var body: some View {
    VStack(alignment: .leading, spacing: TrainerSpacing.xs) {
      Text(label).font(.subheadline)
      HStack(alignment: .firstTextBaseline) {
        TextField(label, text: $text)
          .keyboardType(.decimalPad)
          .monospacedDigit()
          .accessibilityIdentifier(identifier)
          .accessibilityHint(issues.map { BodyCompositionIssueText.text($0, localize: localize) }.joined(separator: ", "))
        Text(unit).foregroundStyle(.secondary)
      }
      ForEach(issues, id: \.self) { issue in
        Text(BodyCompositionIssueText.text(issue, localize: localize))
          .font(.footnote)
          .foregroundStyle(TrainerColor.danger)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}
