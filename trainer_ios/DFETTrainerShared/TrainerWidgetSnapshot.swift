import Foundation

struct TrainerWidgetSnapshot: Codable, Equatable {
  var todaySessions: Int
  var soapTodoCount: Int
  var reassessmentCount: Int
  var averagePain: Double
  var generatedAtLabel: String

  static let placeholder = TrainerWidgetSnapshot(
    todaySessions: 6,
    soapTodoCount: 3,
    reassessmentCount: 2,
    averagePain: 5.0,
    generatedAtLabel: "샘플"
  )
}

enum TrainerWidgetSnapshotStore {
  static let appGroupID = "group.kr.co.dfet.trainer"
  private static let key = "trainer.widget.snapshot"

  static func load() -> TrainerWidgetSnapshot {
    guard
      let data = defaults.data(forKey: key),
      let snapshot = try? JSONDecoder().decode(TrainerWidgetSnapshot.self, from: data)
    else {
      return .placeholder
    }
    return snapshot
  }

  static func save(_ snapshot: TrainerWidgetSnapshot) {
    guard let data = try? JSONEncoder().encode(snapshot) else { return }
    defaults.set(data, forKey: key)
  }

  private static var defaults: UserDefaults {
    UserDefaults(suiteName: appGroupID) ?? .standard
  }
}
