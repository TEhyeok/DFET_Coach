# D-FET 한글·데이터 폰트 결정서

조사일: 2026-08-09

최종 결정: **B · Human Signal**

대상: Flutter 회원 앱, 트레이너 iPad 호환 화면, Next.js 관리자 웹

## 1. 확정 스택

| 역할 | 글꼴 | 사용 범위 |
|---|---|---|
| Primary UI | **IBM Plex Sans KR** | 한글 본문·버튼·탭·임상 설명 |
| Human Display | **Gowun Batang Bold** | 변화 헤드라인·오늘 행동·리포트 핵심 제목 |
| Clinical Data | **IBM Plex Mono** | 점수·변화량·바이오마커 코드·검사값·단위·기술 레이블 |
| Fallback | 시스템 sans-serif | 미지원 문자·특수문자 |

세 글꼴은 앱에 직접 번들하므로 네트워크와 플랫폼 기본 한글 폰트에 의존하지 않는다. Material과 Cupertino의 기본 UI 글꼴은 IBM Plex Sans KR로 통일한다.

## 2. 선택 이유

- IBM Plex Sans KR는 작은 임상 설명과 긴 검사명에서 중립적이고 안정적이다.
- Gowun Batang은 모든 제목이 아니라 사용자의 변화·행동을 말하는 한 문장에만 사용해 효능감의 감정적 위계를 만든다.
- IBM Plex Mono는 `ALT`, `HDL-C`, `mg/dL`, 소수점, 전후 변화의 자릿수를 정렬한다.
- 세 계열의 대비가 “사람의 변화 문장 / 서비스 안내 / 측정 근거”를 글꼴만으로도 구분한다.
- 이모지나 장식 아이콘에 의존하지 않고 타이포그래피와 축별 자산이 브랜드 인상을 만든다.

## 3. 검토한 초기 후보

초기 프로토타입은 SUIT Variable, Wanted Sans Std Variable, Pretendard Variable을 비교했다. 비교 이미지는 [`05_typography_comparison.png`](prototypes/ui_ux_redesign/05_typography_comparison.png)에 보존한다.

| 후보 | 강점 | 최종 판단 |
|---|---|---|
| SUIT Variable | 작은 한글 UI의 안정성, 비교적 작은 용량 | 정돈됐지만 Human Signal의 서사 대비가 약해 최종안에서 제외 |
| Wanted Sans Std | 큰 라틴 수치의 개성, OpenType 기능 | 숫자 정렬과 기술 인상에서 IBM Plex Mono가 최종 방향에 더 적합 |
| Pretendard Variable | 익숙하고 안전한 크로스플랫폼 UI | 널리 사용된 인상이 강해 브랜드 고유성 목표와 거리 있음 |

초기 SUIT/Wanted 자산과 비교 기록은 연구 근거로 보존하지만 현재 `pubspec.yaml`이나 테마에서는 사용하지 않는다.

## 4. 타이포그래피 계약

| 토큰 역할 | 패밀리 | 크기/굵기 | 용도 |
|---|---|---|---|
| Human display | Gowun Batang | 24–40 / 700 | 변화 문장, 오늘의 한 가지, 리포트 핵심 제목 |
| Screen title | IBM Plex Sans KR | 22–28 / 700 | 일반 화면 제목 |
| Section title | IBM Plex Sans KR | 17–20 / 700 | 카드·섹션 제목 |
| Body | IBM Plex Sans KR | 14–17 / 400–500 | 본문과 설명 |
| Label | IBM Plex Sans KR | 11–14 / 600–700 | 탭·버튼·상태 |
| Metric | IBM Plex Mono | 24–64 / 600–700 | 점수·검사 핵심값 |
| Biomarker | IBM Plex Mono | 14–18 / 600–700 | ALT, HDL-C, mg/dL |
| Technical label | IBM Plex Mono | 9–11 / 600–700 | Evidence eyebrow·정책·출처 |

Gowun Batang을 긴 설명·작은 레이블·표에 사용하지 않는다. Display 사용 범위를 제한해 임상 정보 가독성과 감성적 헤드라인의 대비를 유지한다.

## 5. 수치·단위 규칙

- 시계열·비교표·점수에는 `FontFeature.tabularFigures()`를 적용한다.
- 음수 부호, 소수점, 단위 간격은 화면별 문자열 조합 대신 `DfetMetricValue`가 관리한다.
- 숫자와 단위를 같은 크기로 쓰지 않는다. 단위는 숫자의 40–65% 크기로 낮춘다.
- 값이 없으면 `0`을 만들지 않고 `산정 준비 중`을 표시한다.
- 범위 `12–35 U/L`에는 하이픈 대신 en dash를 사용한다.
- `0/O`, `1/I`, `5/S`, `μmol/L`, `+9.0`, `-12.5` 표본을 시각 검수한다.

## 6. 구현 위치

- 패밀리와 tabular style: `lib/theme/d_fet_typography.dart`
- Material 테마: `lib/theme/app_theme.dart`
- Cupertino 테마: `lib/theme/ios_theme.dart`
- 자산 등록: `pubspec.yaml`
- 원본·고지: `assets/fonts/README.md`, `assets/fonts/licenses/`
- 적용 원자: `DfetMetricValue`, `DfetReportHeader`, `ScoreGauge`, `BiomarkerRow`, `DfetSignalRail`

번들 파일은 다음과 같다.

- `IBMPlexSansKR-Regular.ttf`
- `IBMPlexSansKR-Medium.ttf`
- `IBMPlexSansKR-SemiBold.ttf`
- `IBMPlexSansKR-Bold.ttf`
- `GowunBatang-Bold.ttf`
- `IBMPlexMono-SemiBold.ttf`
- `IBMPlexMono-Bold.ttf`

## 7. 자동·수동 인수 기준

- Material/Cupertino 기본 TextTheme의 family가 IBM Plex Sans KR다.
- Human display가 필요한 핵심 문장만 Gowun Batang을 사용한다.
- 점수와 검사값은 IBM Plex Mono와 tabular figures를 사용한다.
- 320px·글자 배율 2.0에서 CTA·수치·정책 레이블이 잘리지 않는다.
- light/dark에서 텍스트 토큰 대비가 4.5:1 이상이다.
- iOS와 Android에서 핵심 문장의 줄바꿈 차이가 1줄을 넘지 않는다.
- 앱이 오프라인이어도 같은 폰트가 렌더링된다.
- OFL 원문과 저작권 고지가 배포물에 포함된다.

관련 자동 검증은 `test/d_fet_typography_test.dart`, `test/d_fet_evidence_test.dart`, `test/clinical_widgets_golden_test.dart`에서 수행한다.
