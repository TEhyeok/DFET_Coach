# D-FET 통합 케어 빌드·자동 검증 보고서

검증일: 2026-08-10

브랜치: `feature/integrated-care-2026`

범위: Flutter 모바일, Firebase Functions/Rules, Next.js 관리자, Signal Path 리포트 UX

## 결과 요약

| 계층 | 명령 | 결과 |
|---|---|---|
| Flutter 정적 분석 | `flutter analyze` | 통과, 이슈 0건 |
| Flutter 전체 테스트 | `flutter test` | 통과, 72개 |
| Functions 문법 | `npm --prefix functions run lint` | 통과 |
| Functions 단위 | `npm --prefix functions test` | 통과, 15개 |
| Firestore/Storage Rules | `firebase emulators:exec ... test:rules` | 통과, 15개 |
| 관리자 lint/typecheck | `npm --prefix admin_web run lint`, `typecheck` | 통과 |
| 관리자 계약 테스트 | `npm --prefix admin_web test` | 통과, 2개 |
| 관리자 production build | `npm --prefix admin_web run build` | 통과, 운영·임상·설정·API 라우트 생성 |
| Android | `flutter build apk --debug` | 통과, `build/app/outputs/flutter-apk/app-debug.apk` |
| iOS Simulator | `tool/ios_simulator.sh build` | 통과, `build/ios/iphonesimulator/Runner.app` |

## 이번 변경 검증

- `DfetEvidenceLabel`: neutral/pending/restricted 상태를 light/dark에서 구분한다.
- `DfetMetricValue`: 값·단위와 `산정 준비 중` 상태를 IBM Plex Mono로 표시한다.
- `DfetEvidenceRibbon`: 탭해 비진단·검토·누락 처리 설명을 펼치고 다시 접을 수 있다.
- 장 16S, 혈액 POCT, 4축 인사이트의 허브·상세가 같은 리포트 헤더와 근거 위계를 사용한다.
- 승인된 장 정책의 참조집단 평균과 생활가이드만 소비자 리포트에 노출하고, 미승인 시 두 항목을 비활성화한다.
- 혈액 추이에는 정상범위 밴드를 표시하며, 4축 누락 시 레이더 차트가 누락 축을 0점으로 채우지 않는다.
- 320px, 글자 배율 2.0에서 새 원자에 RenderFlex/overflow 예외가 없다.
- 합성 데이터 탐색에서 장 alpha/expert, 혈액 13종, 통합 전후 비교 라우트가 유지된다.
- OS 동작 줄이기 설정에서 리포트 헤더 진입 모션은 즉시 완료된다.

## 보안 회귀 결과

Rules 테스트는 다음 경계를 자동 확인했다.

- 회원은 본인 소비자 리포트만 읽고 전문가본은 읽지 못한다.
- 담당 트레이너만 배정 회원의 전문가본을 읽는다.
- 비담당 트레이너와 `lab_operator`의 회원·전문가본 접근을 거부한다.
- 관리자 클라이언트를 포함한 모든 임상 리포트 직접 쓰기를 거부하고 서버 처리만 허용한다.
- 회원의 자기 역할 승격과 관리자 신청자의 자기 승인을 거부한다.
- 임상 원본 Storage는 관리자 읽기·서버 쓰기로 제한한다.

로컬 Docker의 8080 점유와 충돌하지 않도록 Firestore/Storage Emulator를 각각 18080/19199로 고정했다.

## 자동 검증과 별개인 운영 게이트

다음 항목은 코드 성공으로 완료 처리하지 않는다.

- 별도 staging Firebase/App Hosting 배포와 검사기관 샌드박스 계약 테스트
- 기관 승인 정상범위·가중치·생활가이드 등록
- 실제 건강데이터 동의·보존·삭제 정책 승인
- 실기기 카메라·QR/UDI·VoiceOver/TalkBack UAT
- iOS/Android 서명·스토어 심사와 production 점진 활성화

수동 인수 항목은 [`manual_test_checklist.md`](manual_test_checklist.md)에 기록한다.
