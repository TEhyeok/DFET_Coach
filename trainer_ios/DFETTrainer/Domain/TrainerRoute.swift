import Foundation

enum TrainerRoute: String, CaseIterable, Identifiable {
  case productivityExample
  case summary
  case members
  case soap
  case reports
  case settings

  var id: String { rawValue }

  var title: String {
    switch self {
    case .summary: return "요약"
    case .members: return "회원"
    case .soap: return "SOAP"
    case .reports: return "리포트"
    case .productivityExample: return "세션 보드"
    case .settings: return "설정"
    }
  }

  var symbol: String {
    switch self {
    case .summary: return TrainerSymbol.summary
    case .members: return TrainerSymbol.members
    case .soap: return TrainerSymbol.soap
    case .reports: return TrainerSymbol.reports
    case .productivityExample: return TrainerSymbol.board
    case .settings: return TrainerSymbol.settings
    }
  }
}
