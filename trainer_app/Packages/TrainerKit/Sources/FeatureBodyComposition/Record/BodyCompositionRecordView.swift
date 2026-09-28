import DesignSystem
import SwiftUI
import TrainerContracts
import TrainerDomain

/// TR-11 기록 보기 (DF-127, DF-130; V1-07 §4.11 '보기' mode): one saved record read-only (its save result badge, values
/// with source and date, BMI or '미측정', the meta) and the member's mini trend, where the record is a point as soon as
/// it is saved. A record measured before the trend window is shown from the saved entry with a note that the trend
/// does not have it. DF-128 adds the report photo panel and '정정' here.
public struct BodyCompositionRecordView: View {
  private let model: BodyCompositionMemberModel
  private let recordId: String
  private let localize: Localizer
  private let onClose: () -> Void

  public init(model: BodyCompositionMemberModel, recordId: String, localize: Localizer = .main,
              onClose: @escaping () -> Void) {
    self.model = model
    self.recordId = recordId
    self.localize = localize
    self.onClose = onClose
  }

  public var body: some View {
    // A plain stack, not a lazy List: the record and its trend are one short page, all of it in the tree at once.
    ScrollView {
      VStack(alignment: .leading, spacing: TrainerSpacing.xl) {
        if let record = model.record(id: recordId) {
          card {
            // V1-07 §6 'TR-11 저장 직후': the save result. No state is the server's copy with nothing waiting here.
            SyncStateBadge(state: record.syncState ?? .synced, localize: localize)
            BodyCompositionValueRows(record: record, keys: BodyCompositionKey.allCases, localize: localize)
            if let derived = record.derived {
              MetricRow(
                metric: MetricRowModel(code: .bmi, value: derived.bmi, sourceGrade: .derived, measuredAt: record.measuredAt),
                localize: localize)
            } else {
              meta(BodyCompositionCopy.bmiName, value: localize(BodyCompositionCopy.unmeasured))
            }
          }
          card {
            meta("tr11.deviceModel", value: record.deviceModel)
            meta("tr11.measuredAt", value: Self.dateTimeText(record.measuredAt))
            if let fasting = record.fasting { meta("tr11.fasting", value: localize(fasting.copyKey)) }
            if let band = record.timeOfDayBand { meta("tr11.timeOfDayBand", value: localize(band.copyKey)) }
          }
        } else {
          LoadingLine(localize: localize)
        }
        card {
          if let record = model.record(id: recordId), !model.isInTrendWindow(record) {
            Label { Text(localize("tr11.record.outsideTrend")) } icon: { Image(systemName: "calendar.badge.exclamationmark") }
              .font(.footnote)
              .foregroundStyle(TrainerColor.neutral700)
              .fixedSize(horizontal: false, vertical: true)
              .accessibilityElement(children: .combine)
              .accessibilityIdentifier("tr11.record.outsideTrend")
          }
          BodyCompositionMiniTrend(model: model, localize: localize)
        }
      }
      .padding(TrainerSpacing.xl)
    }
    .background(TrainerColor.neutral50)
    .navigationTitle(localize("tr11.record.title"))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button(localize("common.close")) { onClose() }
          .accessibilityIdentifier("tr11.close")
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("tr11.record")
  }

  private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: TrainerSpacing.s) {
      content()
    }
    .padding(TrainerSpacing.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(TrainerColor.neutral100, in: RoundedRectangle(cornerRadius: TrainerSpacing.cornerRadius))
  }

  /// `yyyy.MM.dd HH:mm` on this iPad's clock (V1-12 §2.6 trainer date format).
  static func dateTimeText(_ date: Date, timeZone: TimeZone = .current) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let parts = calendar.dateComponents([.hour, .minute], from: date)
    return MetricRow.dateText(date, timeZone: timeZone) + String(format: " %02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
  }

  private func meta(_ key: String, value: String) -> some View {
    LabeledContent {
      Text(verbatim: value)
        .foregroundStyle(TrainerColor.neutral800)
    } label: {
      Text(localize(key))
    }
    .frame(minHeight: TrainerSpacing.minTapTarget)
    .accessibilityElement(children: .combine)
  }
}

/// The measured values of a record as `MetricRow`s (value, unit, '기기 측정 · {device}', date), in key order. Keys the
/// record did not measure have no row: nothing is filled in (F-BC-03.1).
struct BodyCompositionValueRows: View {
  let record: BodyCompositionRecord
  let keys: [BodyCompositionKey]
  let localize: Localizer

  var body: some View {
    ForEach(keys.filter { record.values[$0] != nil }, id: \.self) { key in
      MetricRow(
        metric: MetricRowModel(
          code: key.metricCode, value: record.values[key] ?? 0, sourceGrade: record.sourceGrade,
          deviceModel: record.deviceModel, measuredAt: record.measuredAt),
        localize: localize)
    }
  }
}
