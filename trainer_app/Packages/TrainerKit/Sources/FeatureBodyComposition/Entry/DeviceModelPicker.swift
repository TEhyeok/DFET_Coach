import DesignSystem
import SwiftUI

/// The TR-11 device choice (F-BC-01.2, ASM-P1a-14): this iPad's device list, most recently used first, and
/// '기기 추가'. Nothing chosen shows '기기 모델을 골라 주세요' through the form's missing list.
struct DeviceModelPicker: View {
  @Binding var selection: String?
  let names: [String]
  let localize: Localizer
  let onAdd: () -> Void

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: TrainerSpacing.m) {
        picker
        addButton
      }
      VStack(alignment: .leading, spacing: TrainerSpacing.s) {
        picker
        addButton
      }
    }
  }

  private var picker: some View {
    Picker(selection: $selection) {
      Text(verbatim: "—").tag(String?.none)
      ForEach(names, id: \.self) { name in
        Text(verbatim: name).tag(String?.some(name))
      }
    } label: {
      Text(localize("tr11.deviceModel"))
    }
    .pickerStyle(.menu)
    .accessibilityIdentifier("tr11.device")
  }

  private var addButton: some View {
    Button {
      onAdd()
    } label: {
      Label(localize("tr11.deviceModel.add"), systemImage: "plus")
        .frame(minHeight: TrainerSpacing.minTapTarget)
    }
    .buttonStyle(.bordered)
    .accessibilityIdentifier("tr11.deviceModel.add")
  }
}
