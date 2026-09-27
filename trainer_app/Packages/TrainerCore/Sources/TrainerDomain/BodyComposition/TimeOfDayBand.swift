import Foundation
import TrainerContracts

extension TimeOfDayBand {
  /// The band of `measuredAt` on the Asia/Seoul wall clock (V1-09 §1.3, §10.3), whatever the device time zone:
  /// before 11:00 morning, 11:00 to before 17:00 midday, from 17:00 evening. Computed, never edited (AC-DF-127.9).
  public init(measuredAt: Date) {
    let parts = Self.seoulCalendar.dateComponents([.hour, .minute], from: measuredAt)
    let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    if minutes < 11 * 60 {
      self = .morning
    } else if minutes < 17 * 60 {
      self = .midday
    } else {
      self = .evening
    }
  }

  /// `timeOfDay.morning` etc.
  public var copyKey: String { "timeOfDay.\(rawValue)" }

  /// Asia/Seoul (UTC+9, no daylight saving), never the device's zone (V1-09 §1.3).
  private static let seoulCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    return calendar
  }()
}

extension Fasting {
  /// The segmented choice; `unknown` is only in the secondary menu (F-BC-01.2). There is no default.
  public static let primaryChoices: [Fasting] = [.yes, .no]

  /// `tr11.fasting.yes` etc.
  public var copyKey: String { "tr11.fasting.\(rawValue)" }
}
