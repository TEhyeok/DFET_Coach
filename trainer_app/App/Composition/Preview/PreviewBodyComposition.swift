#if DEBUG
import FeatureBodyComposition
import Foundation
import LocalStore
import TrainerContracts
import TrainerDomain

/// DEBUG preview body composition (DF-127, DF-130): the real `LocalMeasurementStore` on an in-memory LocalStore, whose
/// Outbox sends nothing, over synthetic "server" records. SYN-0001 has six records in the last five months with a
/// device change (InBody 570 → InBody 970), so `--preview-members --preview-flags=bodyComposition` shows a real trend
/// with a break; a record saved in TR-11 joins it at once. Every preview member has consent ①②③. Synthetic values
/// only; nothing leaves the device.
enum PreviewBodyComposition {
  static let trainerUid = "syn-trainer"
  static let memberWithRecords = MemberKey.uid("syn-0001")

  static func services(now: Date = Date()) -> BodyCompositionServices {
    let consent = ServerEffectiveConsentSource(states: PreviewConsentStates())
    guard let container = try? LocalStoreContainer.make(inMemory: true) else {
      return SessionRuntime.UnavailableMeasurements.services(consent: consent)
    }
    let outbox = LocalOutboxStore(container: container, trainerUid: trainerUid, binaries: nil)
    let store = LocalMeasurementStore(
      outbox: outbox, trainerUid: trainerUid, enqueue: { _ in }, server: PreviewBodyCompositionRecords(now: now),
      consent: { member in await EffectiveConsent.current(from: consent, member: member) })
    return BodyCompositionServices(store: store, devices: store, consent: consent)
  }
}

/// ①②③ granted for every preview member.
struct PreviewConsentStates: ConsentStateSource {
  func observe(member: MemberKey) -> AsyncStream<ConsentState?> {
    let granted = ConsentStateEntry(granted: true, documentVersion: "syn-v1")
    return AsyncStream { continuation in
      continuation.yield(ConsentState(entries: [.required: granted, .healthData: granted, .bodyImaging: granted]))
    }
  }
}

/// SYN-0001's synthetic server records, dated relative to the launch so they stay inside the 12-month trend.
struct PreviewBodyCompositionRecords: BodyCompositionRecordSource {
  let now: Date

  func observeRecords(member: MemberKey, since: Date) -> AsyncThrowingStream<[BodyCompositionRecord], Error> {
    let records = member == PreviewBodyComposition.memberWithRecords ? Self.records(now: now) : []
    return AsyncThrowingStream { continuation in
      continuation.yield(records.filter { $0.measuredAt >= since })
    }
  }

  /// (days ago, device, weight kg, body fat %, skeletal muscle kg, height cm for BMI)
  private static let rows: [(Int, String, Double, Double, Double, Double?)] = [
    (150, "InBody 570", 68.2, 27.1, 26.0, nil),
    (120, "InBody 570", 67.5, 26.6, 26.2, nil),
    (90, "InBody 570", 66.9, 26.0, 26.3, nil),
    (60, "InBody 970", 66.4, 25.4, 26.5, 170),
    (30, "InBody 970", 65.8, 24.9, 26.7, 170),
    (10, "InBody 970", 65.1, 24.3, 26.9, 170),
  ]

  static func records(now: Date) -> [BodyCompositionRecord] {
    var seoul = Calendar(identifier: .gregorian)
    seoul.timeZone = TimeZone(identifier: "Asia/Seoul")!
    return rows.enumerated().compactMap { index, row in
      let (daysAgo, device, weight, fatPercent, muscle, height) = row
      guard let day = seoul.date(byAdding: .day, value: -daysAgo, to: now),
        let measuredAt = seoul.date(bySettingHour: 8, minute: 30, second: 0, of: day)
      else { return nil }
      let derived = height.flatMap { height in
        BMICalculator.bmi(weightKg: weight, heightCm: height).map {
          DerivedBMI(bmi: $0, heightCmUsed: height, heightMeasuredAt: measuredAt)
        }
      }
      return BodyCompositionRecord(
        id: String(format: "SynBodyComp%09d", index + 1), member: PreviewBodyComposition.memberWithRecords,
        deviceModel: device, measuredAt: measuredAt, fasting: .yes, timeOfDayBand: TimeOfDayBand(measuredAt: measuredAt),
        source: "manualEntry", sourceGrade: .device,
        values: [.weightKg: weight, .bodyFatPercent: fatPercent, .skeletalMuscleMassKg: muscle], derived: derived,
        status: .active, createdAt: measuredAt)
    }
  }
}
#endif
