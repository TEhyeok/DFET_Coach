import SwiftUI
import TrainerDomain

/// TR-15 설정 (DF-018): account, the upload queue, app version with the §3.1 notice, logout, and (DEBUG only) the
/// local flag override. Copy is the V1-12 deck (`tr15.*`, `sync.*`, `common.*`).
public struct SettingsView: View {
  @State private var model: SettingsViewModel
  /// The environment's flags before the DEBUG override; the override screen starts from them.
  private let baseFlags: FeatureFlags

  public init(model: SettingsViewModel, baseFlags: FeatureFlags) {
    _model = State(initialValue: model)
    self.baseFlags = baseFlags
  }

  public var body: some View {
    List {
      if let account = model.accountName {
        Section {
          Text(verbatim: account)
            .accessibilityIdentifier("tr15.account.name")
        } header: {
          Text(localized("tr15.account"))
        }
      }
      Section {
        NavigationLink {
          SyncQueueView(model: model)
        } label: {
          LabeledContent(localized("tr15.queue.title"), value: formatted("sync.pendingCount", model.pendingCount))
        }
        .accessibilityIdentifier("tr15.queue")
      }
      #if DEBUG
      Section {
        NavigationLink(localized("tr15.debug.flagOverride")) { DebugFlagOverrideView(baseFlags: baseFlags) }
          .accessibilityIdentifier("tr15.debug.flagOverride")
      }
      #endif
      Section {
        Text(formatted("tr15.version", model.version))
          .accessibilityIdentifier("tr15.version")
        Text(localized("common.disclaimer.short"))
          .font(.footnote)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("tr15.notice")
      }
      Section {
        Button(role: .destructive) {
          model.requestSignOut()
        } label: {
          if model.isSigningOut {
            ProgressView()
          } else {
            Text(localized("tr15.signOut"))
          }
        }
        .disabled(model.isSigningOut)
        .accessibilityIdentifier("tr15.logout")
        if model.signOutFailed {
          Text(localized("common.devDefect"))
            .foregroundStyle(.red)
            .accessibilityIdentifier("tr15.logout.failed")
        }
      }
    }
    .navigationTitle(localized("tr15.title"))
    .task { model.start() }
    .alert(localized("tr15.signOut.question"), isPresented: isPresented(.confirm)) {
      Button(localized("tr15.signOut"), role: .destructive) { Task { await model.signOut() } }
      Button(localized("common.cancel"), role: .cancel) {}
    }
    .alert(formatted("tr15.signOut.unsyncedWarning", model.pendingCount), isPresented: isPresented(.unsynced)) {
      Button(localized("tr15.signOut.syncNow")) { Task { await model.syncNow() } }
      Button(localized("tr15.signOut.confirm"), role: .destructive) { Task { await model.signOut() } }
      Button(localized("common.cancel"), role: .cancel) {}
    }
  }

  private func isPresented(_ prompt: SettingsViewModel.SignOutPrompt) -> Binding<Bool> {
    Binding(get: { model.prompt == prompt }, set: { if !$0, model.prompt == prompt { model.prompt = nil } })
  }
}

/// A deck key's text from the app catalog. The key is a `String` value, never an interpolated literal (SE-0213).
func localized(_ key: String) -> String {
  String(localized: String.LocalizationValue(key), bundle: .main)
}

/// A one-argument deck key (`%lld` for counts, `%@` otherwise, V1-12 §4.3).
func formatted(_ key: String, _ count: Int) -> String {
  String(format: localized(key), count)
}

func formatted(_ key: String, _ text: String) -> String {
  String(format: localized(key), text)
}
