import DesignSystem
import SwiftUI
import TrainerContracts
import TrainerDomain

/// The TR-11 sheet TR-03 opens from '측정 입력 > 신체조성' (AC-DF-127.11): the entry form, then, once saved, the record
/// read-only with the mini trend that already has it (DF-130). A save in progress cannot be swiped away.
public struct BodyCompositionSheet: View {
  private let memberModel: BodyCompositionMemberModel
  private let localize: Localizer
  private let onClose: () -> Void
  @State private var entry: BodyCompositionEntryModel
  @State private var savedId: String?

  public init(memberModel: BodyCompositionMemberModel, localize: Localizer = .main, onClose: @escaping () -> Void) {
    self.memberModel = memberModel
    self.localize = localize
    self.onClose = onClose
    _entry = State(initialValue: memberModel.makeEntryModel(localize: localize))
  }

  public var body: some View {
    NavigationStack {
      if let savedId {
        BodyCompositionRecordView(model: memberModel, recordId: savedId, localize: localize, onClose: onClose)
      } else {
        BodyCompositionEntryView(model: entry, localize: localize, onCancel: onClose) { id in savedId = id }
      }
    }
    .interactiveDismissDisabled(entry.isSaving)
    .pageSizedSheet()  // V1-07 §4.11: sheet(.large), room for the form and the trend
    .onAppear { memberModel.start() }
  }
}

private extension View {
  /// The page size on iPadOS 18+; the default form sheet before.
  @ViewBuilder
  func pageSizedSheet() -> some View {
    if #available(iOS 18.0, *) {
      presentationSizing(.page)
    } else {
      self
    }
  }
}

/// TR-03's body composition part (flag `bodyComposition`): the latest weight, body fat % and skeletal muscle mass,
/// each from the latest active record that measured it with that record's source, date and, unless synced, its sync
/// state (a refused save stays here as '동기화 실패', V1-07 §6), and the mini trend. Loading, empty ('아직 기록이 없어요')
/// and failed ('불러오기 실패', '다시 시도') are separate states. DF-114's timeline replaces the record list around it,
/// not this summary.
public struct BodyCompositionSection: View {
  private let model: BodyCompositionMemberModel
  private let localize: Localizer

  public init(model: BodyCompositionMemberModel, localize: Localizer = .main) {
    self.model = model
    self.localize = localize
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: TrainerSpacing.m) {
      Text(localize("tr03.section.bodyComposition"))
        .font(.title3.weight(.semibold))
        .accessibilityAddTraits(.isHeader)
      switch model.records {
      case .loading:
        LoadingLine(localize: localize)
      case .failed:
        LoadFailed(localize: localize) { model.retry() }
      case .loaded:
        if model.hasActiveRecords {
          VStack(alignment: .leading, spacing: TrainerSpacing.xs) {
            ForEach(model.latestValues) { latest in
              LatestValueRow(value: latest, localize: localize)
            }
          }
          .accessibilityElement(children: .contain)
          .accessibilityIdentifier("tr03.bodyComposition.latest")
          BodyCompositionMiniTrend(model: model, localize: localize)
        } else {
          Text(localize("tr03.empty"))
            .foregroundStyle(TrainerColor.neutral600)
            .accessibilityIdentifier("tr03.bodyComposition.empty")
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .onAppear { model.start() }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("tr03.bodyComposition")
  }
}

/// One TR-03 row: the metric's value from its own record, with that record's device and date, and a small sync badge
/// unless the record is synced (V1-07 §6: synced rows have no badge, ASM-07-36).
private struct LatestValueRow: View {
  let value: BodyCompositionMemberModel.LatestValue
  let localize: Localizer

  var body: some View {
    VStack(alignment: .leading, spacing: TrainerSpacing.xxs) {
      BodyCompositionValueRows(record: value.record, keys: [value.key], localize: localize)
      if let state = value.record.syncState, state != .synced {
        SyncStateBadge(state: state, localize: localize)
      }
    }
  }
}
