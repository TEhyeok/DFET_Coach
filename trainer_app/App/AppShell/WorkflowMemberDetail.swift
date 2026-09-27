import FeatureBodyComposition
import SwiftUI
import TrainerDomain

/// The useful part of TR-03 for DF-113/127/130: identity, consent and entry/return paths to measured records.
struct WorkflowMemberDetail: View {
  let member: MemberKey
  let name: String
  let flags: FeatureFlags
  let consent: (any ConsentService)?
  let measurements: (any MeasurementStore)?
  let openConsent: () -> Void
  let openMeasurement: () -> Void
  let openOther: (EntryPoint) -> Void
  @State private var effective = EffectiveConsent.none
  @State private var records: [BodyCompositionRecord] = []
  @State private var loadFailed = false
  @State private var reload = 0

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        if !name.isEmpty { Text(verbatim: name).font(.title2.bold()).accessibilityIdentifier("tr03.memberName") }
        Text(String(localized: String.LocalizationValue(effective.chipState.copyKey)))
          .font(.subheadline).accessibilityIdentifier("tr03.consent")
        if case .pending = member {
          Button(String(localized: "tr14.consent.title"), action: openConsent)
            .buttonStyle(.bordered).accessibilityIdentifier("tr03.openConsent")
        }
        if flags.bodyComposition {
          Menu {
            Button(String(localized: "tr03.measureMenu.bodyComposition"), action: openMeasurement)
              .accessibilityIdentifier("tr03.entry.bodyComposition")
          } label: {
            Label(String(localized: "tr03.measureMenu"), systemImage: "plus.circle")
              .frame(minHeight: 44)
          }
          .buttonStyle(.borderedProminent).accessibilityIdentifier("tr03.measureMenu")
          if loadFailed {
            Text("tr11.records.loadFailed")
            Button(String(localized: "common.retry")) { reload += 1 }
          } else {
            BodyCompositionHistoryView(records: records)
          }
        }
        ForEach(FlagGate.visibleEntries(on: .memberDetail, flags: flags).filter { $0 != .bodyComposition }) { entry in
          Button(String(localized: String.LocalizationValue(entry.titleKey))) { openOther(entry) }
            .buttonStyle(.bordered).accessibilityIdentifier(entry.accessibilityID)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading).padding(24)
    }
    .task(id: member) {
      guard let consent else { return }
      for await state in consent.observe(member: member) { effective = state }
    }
    .task(id: "\(member.id)-\(flags.bodyComposition)-\(reload)") {
      guard flags.bodyComposition, let measurements else { return }
      loadFailed = false
      records = []
      do {
        for try await values in measurements.observeBodyCompositionRecords(member: member, since: .distantPast) {
          records = values
        }
      } catch { if !Task.isCancelled { loadFailed = true } }
    }
  }
}
