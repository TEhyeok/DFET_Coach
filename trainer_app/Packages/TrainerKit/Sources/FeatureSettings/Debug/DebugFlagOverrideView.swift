#if DEBUG
import Observation
import SwiftUI
import TrainerDomain

/// DEBUG-only local flag override (AC-DF-018.4, ADR-010 §3-6). Values live in memory only and change the client's
/// entry points; the rules still read `appConfig/features`. Release builds contain none of this.
@MainActor
@Observable
public final class DebugFlagOverrides {
  public static let shared = DebugFlagOverrides()
  public var values: [FeatureFlags.Key: Bool] = [:]

  public func apply(to flags: FeatureFlags) -> FeatureFlags {
    var result = flags
    for (key, value) in values { result[key] = value }
    return result
  }
}

struct DebugFlagOverrideView: View {
  let baseFlags: FeatureFlags
  @State private var overrides = DebugFlagOverrides.shared

  var body: some View {
    List(FeatureFlags.Key.allCases, id: \.self) { key in
      Toggle(isOn: Binding(get: { overrides.values[key] ?? baseFlags[key] }, set: { overrides.values[key] = $0 })) {
        Text(verbatim: key.rawValue)  // DEBUG tool, not copy
      }
      .accessibilityIdentifier("tr15.debug.flag.\(key.rawValue)")
    }
    .navigationTitle(Text(verbatim: "Flags"))
  }
}
#endif
