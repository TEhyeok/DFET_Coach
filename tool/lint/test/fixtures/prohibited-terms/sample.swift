// 진단 (line comment: not checked)
/// 치료 (doc comment: not checked)
/* 재활 /* nested 처방 */ still comment 진료 */
import SwiftUI

struct Sample: View {
  let name = "회원"
  var body: some View {
    VStack {
      Text("체형 교정")
      Text("회원 \(name) 진단 기록")
      Text("진\(name)단")
      Text("\(name.isEmpty ? "치료계획" : "운동 계획")")
      Text(#"재활 "트레이닝""#)
      Text("""
        여러 줄 문자열
        예방 안내
        """)
      Text("홈운동 기록") // 교정 in a trailing comment
      Text("diagnosis")
    }
  }
}
