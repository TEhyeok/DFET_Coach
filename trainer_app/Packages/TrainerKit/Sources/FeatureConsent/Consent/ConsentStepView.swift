import DesignSystem
import SwiftUI
import TrainerContracts
import TrainerDomain

/// TR-14 동의 받기 (DF-110 MVP, F-PRIV-01.1): the member answers ①②③ one by one on the trainer's iPad. No answer is
/// preselected and there is no 'agree to all' (AC-DF-110.2). A refusal leaves no record; ① refused records nothing and,
/// for a pending member, offers '등록 취소' (`tr02.menu.cancelPending`, confirmed with `tr02.cancelPending.confirm`,
/// then `tr14.consent.requiredRefusedPending`, AC-DF-110.5). Copy is the V1-12 deck's (`tr14.consent.*`,
/// `consent.type.*`); the MVP shows no legal document text (G-04).
public struct ConsentStepView: View {
  @State private var model: ConsentStepModel
  @State private var confirmingCancel = false
  private let onClose: () -> Void
  private let localize = Localizer.main

  public init(model: ConsentStepModel, onClose: @escaping () -> Void) {
    _model = State(initialValue: model)
    self.onClose = onClose
  }

  public var body: some View {
    NavigationStack {
      content
        .navigationTitle(Text("tr14.consent.title", bundle: .main))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button { onClose() } label: { Text("common.close", bundle: .main) }
              .disabled(model.phase == .saving)  // a save in progress finishes first
              .accessibilityIdentifier("common.close")
          }
        }
    }
    // V1-07 §3.2: `.consent` is `sheet(.large, interactiveDismissDisabled)`.
    .interactiveDismissDisabled()
    .alert(Text("tr02.menu.cancelPending", bundle: .main), isPresented: $confirmingCancel) {
      Button(role: .destructive) {
        Task { await model.cancelRegistration() }
      } label: {
        Text("tr02.menu.cancelPending", bundle: .main)
      }
      .accessibilityIdentifier("tr14.consent.cancelRegistration.confirm")
      Button(role: .cancel) {} label: { Text("common.cancel", bundle: .main) }
    } message: {
      Text("tr02.cancelPending.confirm", bundle: .main)
    }
    .task { await model.load() }
    .task { await model.watchConsent() }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("tr14.consent.root")
    // A random pending ID, not personal data; UI tests read it (AC-DF-108.4).
    .accessibilityValue(model.member.id)
  }

  @ViewBuilder
  private var content: some View {
    switch model.phase {
    case .loading:
      ProgressView { Text("common.loading", bundle: .main) }
        .accessibilityIdentifier("common.loading")
    case let .loadFailed(onlineRequired):
      VStack(spacing: TrainerSpacing.m) {
        Text(localize(onlineRequired ? "common.onlineRequired" : "common.loadFailed"))
          .accessibilityIdentifier(onlineRequired ? "common.onlineRequired" : "common.loadFailed")
        Button { Task { await model.load() } } label: { Text("common.retry", bundle: .main) }
          .buttonStyle(.bordered)
          .frame(minHeight: TrainerSpacing.minTapTarget)
          .accessibilityIdentifier("common.retry")
      }
      .padding(TrainerSpacing.xl)
    case .documentMissing:
      Text("tr14.consent.documentMissing", bundle: .main)
        .multilineTextAlignment(.center)
        .padding(TrainerSpacing.xl)
        .accessibilityIdentifier("tr14.consent.documentMissing")
    case .choosing, .saving:
      cards
    case .saved:
      result
    case .registrationCancelled:
      Text("tr14.consent.requiredRefusedPending", bundle: .main)
        .font(.title3)
        .multilineTextAlignment(.center)
        .padding(TrainerSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("tr14.consent.requiredRefusedPending")
    }
  }

  private var cards: some View {
    Form {
      Section {
        Text("tr14.consent.handToMember", bundle: .main)
          .font(.title3)
          .accessibilityIdentifier("tr14.consent.handToMember")
      }
      ForEach(model.types, id: \.self) { type in
        Section {
          ConsentCard(type: type, version: model.documents[type]?.version, choice: model.choices[type],
                      localize: localize) { choice in model.choose(choice, for: type) }
          if type == .required, model.requiredRefused {
            // Right under ①, where the answer was given: nothing can be recorded without it (V1-06 V8).
            Text("consent.requiredFirst", bundle: .main)
              .foregroundStyle(TrainerColor.danger)
              .accessibilityIdentifier("consent.requiredFirst")
            if model.canCancelRegistration {
              // AC-DF-110.5: a pending member without ① cannot stay registered; the trainer confirms first.
              Button(role: .destructive) { confirmingCancel = true } label: {
                Text("tr02.menu.cancelPending", bundle: .main)
                  .frame(minHeight: TrainerSpacing.minTapTarget)
              }
              .accessibilityIdentifier("tr14.consent.cancelRegistration")
            }
          }
        }
      }
      if model.saveFailed {
        Section {
          Text("common.devDefect", bundle: .main)
            .foregroundStyle(TrainerColor.danger)
            .accessibilityIdentifier("tr14.consent.saveFailed")
        }
      }
      Section {
        Button {
          Task { await model.submit() }
        } label: {
          Text("tr14.consent.submit", bundle: .main)
            .frame(maxWidth: .infinity, minHeight: TrainerSpacing.minTapTarget)
        }
        .buttonStyle(.borderedProminent)
        .tint(TrainerColor.brandBlueFill)
        .disabled(!model.canSubmit)
        .accessibilityIdentifier("tr14.consent.submit")
      }
    }
    .onChange(of: model.requiredRefused) { _, refused in
      guard refused else { return }
      AccessibilityNotification.Announcement(localize("consent.requiredFirst")).post()
    }
  }

  private var result: some View {
    VStack(spacing: TrainerSpacing.xl) {
      Text("tr14.consent.returnToTrainer", bundle: .main)
        .font(.title2.weight(.semibold))
        .multilineTextAlignment(.center)
        .accessibilityIdentifier("tr14.consent.returnToTrainer")
      if let chip = model.chip {
        // The same DesignSystem chip as TR-02's rows (DF-113).
        ConsentChip(state: chip, style: .result, localize: localize)
          .accessibilityIdentifier("tr14.consent.result")
      } else {
        ProgressView()
      }
    }
    .padding(TrainerSpacing.xl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// One consent type: its name, the published version, and the two answers (checkmark marks the choice, not colour
/// alone). Each button's VoiceOver label carries the type name (AC-DF-110.9).
private struct ConsentCard: View {
  let type: ConsentType
  let version: String?
  let choice: ConsentChoice?
  let localize: Localizer
  let choose: (ConsentChoice) -> Void

  /// Keys are built as `String`s first (SE-0213: an interpolated literal would become a format key).
  private var typeName: String {
    let key = "consent.type." + type.rawValue
    return localize(key)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: TrainerSpacing.s) {
      Text(typeName)
        .font(.title3.weight(.semibold))
        .accessibilityAddTraits(.isHeader)
      if let version {
        Text(localize.format("tr14.consent.version", version))
          .font(.footnote)
          .foregroundStyle(TrainerColor.neutral600)
      }
      ViewThatFits(in: .horizontal) {
        HStack(spacing: TrainerSpacing.s) { buttons }
        VStack(alignment: .leading, spacing: TrainerSpacing.s) { buttons }
      }
    }
    .padding(.vertical, TrainerSpacing.xs)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("tr14.consent.card." + type.rawValue)
  }

  private var buttons: some View {
    ForEach(ConsentChoice.allCases, id: \.self) { option in
      let selected = choice == option
      let key = option == .grant ? "tr14.consent.grant" : "tr14.consent.refuse"
      Button {
        choose(option)
      } label: {
        Label {
          Text(localize(key))
        } icon: {
          Image(systemName: selected ? "checkmark.circle.fill" : "circle")
        }
        .font(.title3)
        .frame(minWidth: TrainerSpacing.minTapTarget, minHeight: TrainerSpacing.minTapTarget)
        .padding(.horizontal, TrainerSpacing.s)
      }
      .buttonStyle(.bordered)
      .tint(selected ? TrainerColor.brandBlue : TrainerColor.neutral600)
      .accessibilityLabel(Text(typeName + " " + localize(key)))
      .accessibilityAddTraits(selected ? .isSelected : [])
      .accessibilityIdentifier(key + "." + type.rawValue)
    }
  }
}
