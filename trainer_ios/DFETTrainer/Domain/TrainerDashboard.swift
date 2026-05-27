import Foundation
import SwiftUI

enum TrainerAccent: String, Codable {
  case healthRed
  case blue
  case green
  case orange
  case red
  case purple

  var color: Color {
    switch self {
    case .healthRed: return TrainerColor.healthRed
    case .blue: return TrainerColor.blue
    case .green: return TrainerColor.green
    case .orange: return TrainerColor.orange
    case .red: return TrainerColor.red
    case .purple: return TrainerColor.purple
    }
  }
}

struct TrainerTrend: Identifiable, Hashable, Codable {
  var id: String
  var title: String
  var subtitle: String
  var symbol: String
  var accent: TrainerAccent
  var value: String
}

struct TrainerDashboardSummary: Hashable, Codable {
  var todaySessionCount: Int
  var completedSessionCount: Int
  var plannedSessionCount: Int
  var managedMemberCount: Int
  var attentionMemberCount: Int
  var soapTodoCount: Int
  var averagePain: Double
  var stableGoalPercent: Int
  var soapCompletionPercent: Int
  var homeExercisePercent: Int
  var painTrend: [Double]
  var completionTrend: [Double]
  var trends: [TrainerTrend]
}
