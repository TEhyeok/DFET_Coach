import Foundation
import SwiftUI

enum RiskLevel: String, CaseIterable, Codable, Identifiable {
  case stable = "안정"
  case attention = "주의"
  case high = "고위험"

  var id: String { rawValue }

  var color: Color {
    switch self {
    case .stable: return TrainerColor.blue
    case .attention: return TrainerColor.purple
    case .high: return TrainerColor.deepBlue
    }
  }
}

struct TrainerMember: Identifiable, Hashable, Codable {
  let id: String
  var name: String
  var email: String
  var program: String
  var region: String
  var pain: Int
  var risk: RiskLevel
  var progress: Int
  var lastSoap: String
  var nextPlan: String
  var painSeries: [Double]
  var completionSeries: [Double]

  var initial: String {
    String(name.prefix(1))
  }

  var avatarSeed: String {
    let fallbackSeed = name.isEmpty ? "dfet-member" : name
    return id.isEmpty ? fallbackSeed : id
  }

  var avatarURL: URL? {
    let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.~"))
    guard let encodedSeed = avatarSeed.addingPercentEncoding(withAllowedCharacters: allowedCharacters) else {
      return nil
    }
    return URL(string: "https://www.tapback.co/api/avatar/\(encodedSeed).webp")
  }

  var subtitle: String {
    "\(program) · \(region)"
  }

  var signal: String {
    switch risk {
    case .stable:
      return "목표 진행 안정"
    case .attention:
      return "재평가일 도래"
    case .high:
      return "통증 상승 확인"
    }
  }

  /// 회원 목록이 비어있을 때 UI 크래시를 방지하기 위한 빈 placeholder.
  static let placeholder = TrainerMember(
    id: "",
    name: "회원 없음",
    email: "",
    program: "",
    region: "",
    pain: 0,
    risk: .stable,
    progress: 0,
    lastSoap: "",
    nextPlan: "",
    painSeries: [],
    completionSeries: []
  )
}
