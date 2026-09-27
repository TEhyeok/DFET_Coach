import SwiftUI
import TrainerDomain

/// TR-15 upload queue (AC-DF-018.3): each failed item's kind and reason, '다시 시도', and '모두 다시 시도'. No member
/// name and no path.
struct SyncQueueView: View {
  let model: SettingsViewModel

  var body: some View {
    List {
      if model.failedItems.isEmpty {
        Text(localized("tr15.queue.empty"))
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("tr15.queue.empty")
      }
      ForEach(Array(model.failedItems.enumerated()), id: \.element.id) { index, item in
        HStack(spacing: 12) {
          VStack(alignment: .leading, spacing: 4) {
            Text(localized(SyncQueueLabels.kindKey(item)))
              .font(.body.weight(.semibold))
            Text(localized(SyncQueueLabels.reasonKey(item)))
              .font(.footnote)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer(minLength: 8)
          Button(localized("common.retry")) { Task { await model.retry(item.id) } }
            .buttonStyle(.bordered)
            .controlSize(.large)  // the capsule itself is the tap target: at least 44pt tall
            .accessibilityIdentifier("tr15.queue.retry.\(index)")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tr15.queue.item.\(index)")
      }
    }
    .navigationTitle(localized("tr15.queue.title"))
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button(localized("tr15.queue.retryAll")) { Task { await model.retryAll() } }
          .disabled(model.failedItems.isEmpty)
          .accessibilityIdentifier("tr15.queue.retryAll")
      }
    }
  }
}
