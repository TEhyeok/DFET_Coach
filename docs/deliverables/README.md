# D-FET 통합 케어 산출물

기준일: 2026-08-02
구현 브랜치: `feature/integrated-care-2026`

이 폴더는 과업지시서에 대응하는 코드 기준 산출물이다.

1. [WBS 및 인수 게이트](01_WBS.md)
2. [IA·라우트·화면설계](02_IA_AND_SCREENS.md)
3. [기능명세](03_FUNCTIONAL_SPEC.md)
4. [DB·권한 설계](04_DATA_AND_SECURITY.md)
5. [API·JSON 인터페이스](05_API_INTERFACE.md)
6. [테스트·출시·롤백](06_TEST_AND_RELEASE.md)
7. [디자인 토큰·컴포넌트 규칙](07_DESIGN_SYSTEM.md)

JSON Schema 원본은 `/schemas`에 있다. 임상 승인 설정, 실제 검사 데이터, 운영 비밀키는 저장소에 포함하지 않는다.

## 현재 완료 범위

- Flutter 모바일: 케어유형, 4탭 라우팅, 테마, 장·혈액·4축 리포트
- Firebase: Node.js 22 수집 API, HMAC, 정규화, 정책형 산정, 소비자/전문가 분리, 감사·스냅샷, Rules 테스트
- Next.js 관리자: 세션 쿠키, 역할별 화면, 기존 운영 기능, 검사 수집·작업·리포트·정책·감사·기능 플래그
- 빌드 복구: iOS 15.5, arm64 시뮬레이터 우회 패키지, Android Firebase 등록

## 외부 승인 또는 운영 환경이 필요한 잔여 게이트

- 별도 staging Firebase 프로젝트 생성과 App Hosting 연결
- 기관 승인 정상범위·가중치·생활가이드 등록
- 실제 건강데이터 보존·삭제·동의 정책 승인
- 기관 UAT, 스토어 서명·심사, production 기능 플래그 활성화

위 게이트 전에는 임상 점수와 판정이 생성되지 않으며 모바일에는 `산정 준비 중`이 표시된다.
