import SwiftUI
import TrainerDomain

/// TR-14 MVP: hand to the member → independent ①②③ answers → local capture → return to the trainer.
/// Signature, ④⑤, withdrawal, reconsent and analytics are deferred by DEC-22.
public struct ConsentFlowView: View {
  @State private var model: ConsentFlowModel
  private let onComplete: () -> Void
  private let onCancel: () -> Void

  public init(model: ConsentFlowModel, onComplete: @escaping () -> Void, onCancel: @escaping () -> Void) {
    _model = State(initialValue: model)
    self.onComplete = onComplete
    self.onCancel = onCancel
  }

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          content
          if model.saveFailed {
            Text("common.devDefect", bundle: .main)
              .foregroundStyle(.red)
              .accessibilityIdentifier("tr14.consent.saveFailed")
          }
        }
        .frame(maxWidth: 720, alignment: .leading)
        .padding(20)
        .frame(maxWidth: .infinity)
      }
      .navigationTitle(Text("tr14.consent.title", bundle: .main))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        if model.stage == .handoff || model.stage == .choices {
          ToolbarItem(placement: .cancellationAction) {
            Button { onCancel() } label: { Text("common.cancel", bundle: .main) }
              .disabled(model.isSaving)
              .accessibilityIdentifier("tr14.consent.cancel")
          }
        }
      }
      .alert(Text("tr14.consent.requiredRefusalConfirm", bundle: .main),
             isPresented: $model.showsRequiredRefusalConfirmation) {
        Button(role: .destructive) { Task { await model.confirmRequiredRefusal() } } label: {
          Text("common.confirm", bundle: .main)
        }
        Button(role: .cancel) {} label: { Text("common.cancel", bundle: .main) }
      }
    }
    .interactiveDismissDisabled(model.isSaving)
    .task { await model.start() }
    .onDisappear { model.stop() }
    .accessibilityIdentifier("tr14.consent.root")
  }

  @ViewBuilder private var content: some View {
    switch model.stage {
    case .finished:
      Text("tr14.consent.returnToTrainer", bundle: .main)
        .font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
      Text(LocalizedStringKey(model.effectiveConsent.chipState.copyKey), bundle: .main)
        .accessibilityIdentifier("tr14.consent.resultState")
      if model.didCapture {
        Text("tr14.consent.savedLocally", bundle: .main).foregroundStyle(.secondary)
      }
      completeButton
    case .cancelled:
      Text("tr14.consent.requiredRefusedPending", bundle: .main)
        .accessibilityIdentifier("tr14.consent.registrationCancelled")
      completeButton
    case .handoff, .choices:
      documentContent
    }
  }

  @ViewBuilder private var documentContent: some View {
    switch model.documentState {
    case .loading:
      ProgressView { Text("common.loading", bundle: .main) }
    case .missing:
      Text("tr14.consent.documentMissing", bundle: .main)
        .accessibilityIdentifier("tr14.consent.documentMissing")
      retryDocuments
    case .failed:
      Text("common.loadFailed.detail", bundle: .main)
        .accessibilityIdentifier("tr14.consent.loadFailed")
      retryDocuments
    case .ready:
      if model.stage == .handoff {
        Text("tr14.consent.handToMember", bundle: .main)
          .font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
        Button { model.beginChoices() } label: { Text("common.next", bundle: .main) }
          .buttonStyle(.borderedProminent)
          .accessibilityIdentifier("tr14.handoff.start")
      } else {
        ForEach(ConsentFlowRules.coreTypes, id: \.self) { type in
          if let document = model.documents[type] {
            ConsentCardView(document: document, selection: model.selections[type],
                            effective: model.effectiveConsent[type], isEnabled: !model.isSaving) {
              model.choose(type, granted: $0)
            }
          }
        }
        Button { Task { await model.submit() } } label: {
          HStack {
            if model.isSaving { ProgressView() }
            Text("tr14.consent.submit", bundle: .main)
          }
          .frame(minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!model.canSubmit)
        .accessibilityIdentifier("tr14.consent.submit")
      }
    }
  }

  private var retryDocuments: some View {
    Button { Task { await model.reloadDocuments() } } label: { Text("common.retry", bundle: .main) }
      .accessibilityIdentifier("tr14.consent.retryDocuments")
  }

  private var completeButton: some View {
    Button { model.stage == .cancelled ? onCancel() : onComplete() } label: { Text("common.confirm", bundle: .main) }
      .buttonStyle(.borderedProminent)
      .accessibilityIdentifier("tr14.consent.complete")
  }
}
