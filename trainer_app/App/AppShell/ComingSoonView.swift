import DesignSystem
import SwiftUI

/// `common.comingSoon` screen for entry points whose flag is on but whose screen does not exist yet (AC-DF-017.5),
/// drawn with DesignSystem's `ComingSoonLabel` (DF-016).
struct ComingSoonView: View {
  var body: some View {
    ComingSoonLabel()
      .padding(24)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

#Preview {
  ComingSoonView()
}
