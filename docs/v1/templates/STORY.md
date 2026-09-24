# 스토리 템플릿

| 항목 | 내용 |
|---|---|
| 문서 ID | V1-T01 |
| 버전 | v1.0 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | §0.5 ID 체계, §6.0.4 요구사항·수용 기준 형식, §12.1 |
| 관련 에픽·스토리 | 모든 DF-001~549 스토리. 예시 DF-003 |
| 변경 규칙 | [문서 변경](../01_AGILE_WORKING_AGREEMENT.md#문서-변경) |

## 목차

- [사용법](#사용법)
- [작성 규칙](#작성-규칙)
- [백로그 문서용 템플릿](#백로그-문서용-템플릿)
- [이슈 JSON 대응](#이슈-json-대응)
- [예시: DF-003](#예시-df-003)
- [변경 이력](#변경-이력)

## 사용법

- 스토리 정본은 `docs/v1/backlog/<단계>.md`의 절 하나와 `tool/backlog/issues.json`의 객체 하나다. JSON은 `node tool/backlog/build_issues.mjs`가 색인·카드에서 다시 만들므로 카드와 [02 §8 색인](../02_PRODUCT_BACKLOG.md#8-전체-스토리-색인)을 **같은 PR에서** 고치고 생성물을 함께 커밋한다.
- GitHub 이슈는 소유자가 `tool/backlog/create_backlog.sh`로 JSON에서 만든다. 손으로 만들 때는 이슈 폼 [story.yml](../../../.github/ISSUE_TEMPLATE/story.yml)(GH-03)을 쓴다. 두 경로의 필드는 같다.
- 스파이크는 [V1-T02](SPIKE_REPORT.md), 버그는 [V1-T13](BUG_REPORT.md), 소유자 행동은 [V1-T07](GATE_EVIDENCE.md)을 함께 쓴다.

## 작성 규칙

1. 제목은 `[DF-NNN] 동사형 제목`이다(예: "…를 구현한다", "…를 작성한다").
2. **PRD ID는 인용만** 한다. 새 F-/AC- ID를 만들지 않는다. 스토리 전용 기준은 `AC-DF-NNN.k`다.
3. 수용 기준마다 테스트 종류를 하나 붙인다: 단위, 규칙 에뮬레이터, Functions e2e, 교차 픽스처, UI(XCUITest·위젯), 스냅샷, 실기기, 수동.
4. 크기는 1·2·3·5점만. 8점이면 나눈다([V1-01 추정과 속도](../01_AGILE_WORKING_AGREEMENT.md#추정과-속도)).
5. 외부 게이트는 '의존'에 적지 않는다. 대신 '게이트 영향' 칸에 무엇이 막히는지(플래그 개방, 실데이터, 배포)를 적는다.
6. 배경은 PRD를 복사하지 않고 절 링크와 2~3줄 요지만 쓴다.

## 백로그 문서용 템플릿

````markdown
### DF-NNN <동사형 제목>

| 필드 | 값 |
|---|---|
| 에픽 | EP-NN <에픽 이름> |
| 유형 | story \| spike \| chore \| bug \| migration |
| 단계 | P0 \| P1a \| P1b \| P2 \| P3 \| V2 |
| 우선순위 | must \| should \| could \| wont |
| 점수 | <1\|2\|3\|5> (size/<XS\|S\|M\|L>) |
| 영역 | <trainer-app \| member-app \| admin-web \| functions \| rules \| storage \| contracts \| bodypath \| ci \| design \| privacy \| analytics \| docs> |
| 플래그 | 없음 \| soapV2 \| bodyComposition \| bodyAssessment \| memberShare \| lidarBeta |
| 스프린트(잠정) | SNN |
| 의존 | DF-..., DF-... |
| 게이트 영향 | 없음 \| <G-NN: 막히는 것> |
| 에이전트 | claude \| codex \| human |
| 위험 라벨 | 없음 \| rules-change, schema-change, regulatory, privacy-impact, freeze-exception, needs-device-test |
| PRD 추적 | <F-..., AC-..., NFR-..., TR-..., R-..., S-..., MIG-...> |

**배경**
<PRD §x.y 링크와 요지 2~3줄. 왜 지금 필요한지>

**범위**
- <만들 것 1>
- <만들 것 2>

**비범위**
- <하지 않을 것과 담당 스토리(DF-...)>

**수정 경로(예상)**
- <path/new_file> (신규)
- <path/existing_file> (수정)

**인터페이스·데이터**
- <타입·함수 시그니처 또는 V1-05/V1-06 절 링크>
- <JSON 예시(합성)>

**수용 기준**

| ID | 기준 | 테스트 종류 | 테스트 위치·이름 |
|---|---|---|---|
| AC-XXX-NN.k | <PRD 원문> | <종류> | <path>::<AC ID가 들어간 테스트 이름> |
| AC-DF-NNN.1 | <추가 기준> | <종류> | <...> |

**테스트 데이터(합성)**
- <가상 회원·픽스처 경로. 실데이터 금지>

**테스트 명령**
- `<이 스토리에서 추가로 돌릴 명령. area별 기본 명령은 생성기가 넣는다>`

**에이전트 브리프** — <에이전트 배정 스토리만. V1-T08의 1절(목표), 3절(컨텍스트 팩: 읽을 문서·절), 4절(수정 허용·금지 경로. '수정 경로(예상)'를 확정본으로), 5절(인터페이스: 위 '인터페이스·데이터' 링크로 대신 가능), 7절(구현 메모: 원본 줄 범위·반례·시작 순서) 요지를 3~6줄로. 나머지 절은 `node tool/backlog/brief.mjs DF-NNN`이 채운다([V1-T08 사용법](AGENT_BRIEF.md#사용법))>

**DoR**
- [ ] R1 PRD 추적 ID
- [ ] R2 검증 가능한 수용 기준과 테스트 종류
- [ ] R3 선행 스토리 Done 또는 앞순서
- [ ] R4 5점 이하
- [ ] R5 단계·플래그·영역·우선순위 라벨
- [ ] R6 수정 경로 확정, 병행 스토리와 비중첩
- [ ] R7 스키마·규칙·계약·문구 영향 표시
- [ ] R8 합성 데이터 계획
- [ ] R9 (에이전트 배정 시) 이 카드의 '에이전트 브리프' 절 작성 + `node tool/backlog/brief.mjs DF-NNN` 생성 지시서를 이슈 코멘트로 부착
- [ ] R10 실기기·서명·콘솔 부분 분리

**DoD**
- 공통 D1~D12 + 영역 DoD(<영역>) — [V1-01 완료 정의](../01_AGILE_WORKING_AGREEMENT.md#완료-정의dod)

**코드 근거**
- <dfet:경로:줄 — 파일을 열어 확인한 것만>
````

## 이슈 JSON 대응

`tool/backlog/issue.schema.json`(TL-04) 필드와의 대응이다. 백로그 문서의 표와 JSON은 같은 값을 가져야 한다(`validate_backlog.mjs`가 비교).

| 백로그 문서 | JSON 키 | 비고 |
|---|---|---|
| 제목 | `key`, `title` | `title`은 `[DF-NNN] …` 전체 |
| 유형 | `type` | 라벨 `type/<값>` |
| 에픽 | `epic` | `EP-NN` |
| 단계 | `phase` | 라벨 `phase/<값>`, 마일스톤 결정 |
| 우선순위 | `prio` | 라벨 `prio/<값>` |
| 점수 | `size` | 숫자. 라벨 `size/<XS…XL>` 파생 |
| 영역·플래그·위험 라벨·에이전트 | `labels[]` | `area/…`, `flag/…`, 위험 라벨, `agent/…` |
| 마일스톤 | `milestone` | 단계 마일스톤 제목 |
| PRD 추적 | `trace[]` | PRD에 존재해야 함 |
| 수용 기준 | `acceptance[]` | `{id, text, testType}` |
| 의존 | `dependsOn[]` | DF 키 |
| (소유자 행동 여부) | `ownerAction` | DF-9xx는 true |
| 배경·범위·비범위·수정 경로 | `body` | 마크다운 |

```json
{
  "key": "DF-003",
  "title": "[DF-003] metric-catalog.v1.json과 vocab.v1.json을 부록 A·B에서 작성한다",
  "type": "story",
  "epic": "EP-02",
  "phase": "P0",
  "prio": "must",
  "size": 2,
  "labels": ["type/story", "area/contracts", "phase/P0", "prio/must", "size/S", "schema-change", "agent/codex"],
  "milestone": "P0 정리·기반",
  "trace": ["F-SOAP-06.1", "AC-SOAP-02.2"],
  "acceptance": [
    {"id": "AC-DF-003.1", "text": "부록 A.1의 모든 metricCode가 metricCode·unit·sideRule·allowedSourceGrades·reliabilityTier 필드를 가진다", "testType": "unit"},
    {"id": "AC-DF-003.2", "text": "부록 A.5~A.7 어휘는 초안 표시를 가진다(DF-916에서 해제)", "testType": "unit"},
    {"id": "AC-DF-003.3", "text": "metricCode 중복 0", "testType": "unit"}
  ],
  "dependsOn": ["DF-901"],
  "ownerAction": false,
  "body": "배경: PRD 부록 A 운영 규칙… (본문 마크다운)"
}
```

## 예시: DF-003

````markdown
### DF-003 metric-catalog.v1.json과 vocab.v1.json을 부록 A·B에서 작성한다

| 필드 | 값 |
|---|---|
| 에픽 | EP-02 계약·어휘 단일 원본 |
| 유형 | story |
| 단계 | P0 |
| 우선순위 | must |
| 점수 | 2 (size/S) |
| 영역 | contracts |
| 플래그 | 없음 |
| 스프린트(잠정) | S01 |
| 의존 | DF-901 |
| 게이트 영향 | 없음(A.5~A.7 확정은 소유자 행동 DF-916, 코딩 비차단) |
| 에이전트 | codex |
| 위험 라벨 | schema-change |
| PRD 추적 | F-SOAP-06.1, 부록 A.1~A.7, 부록 B, AC-SOAP-02.2 |

**배경**
PRD 부록 A는 metricCode의 정본이고, 어휘가 클라이언트마다 따로 적혀 있는 문제(PRD §2.2)를 contracts/ 단일 원본으로 푼다(ADR-005). 이 스토리는 JSON 원본만 만들고 생성기는 DF-004가 만든다.

**범위**
- contracts/metric-catalog.v1.json: 부록 A.1·A.2의 metricCode 1:1
- contracts/vocab.v1.json: 부록 A.3(landmarkCode), A.5(joint·motion), A.6(muscleGroup), A.7(regionCode), 부록 B의 enum(consentType, sourceGrade, reasonCode, changeStatus, syncState)

**비범위**
- 생성기와 CI(DF-004), 메타 스키마 ajv 검증(DF-004), 플래그 키(DF-027), 금지어(DF-010), 분석 이벤트(DF-033)

**수정 경로(예상)**
- contracts/metric-catalog.v1.json (신규)
- contracts/vocab.v1.json (신규)
- contracts/README.md (신규, 원본 규칙 한 문단)

**인터페이스·데이터**
- 필드 정의는 [V1-05 contracts JSON 스키마](../05_DATA_MODEL_AND_RULES.md) 절을 따른다.
- metric-catalog 항목 필드: metricCode, nameKo, family, unit, sideRule, allowedSourceGrades[], reliabilityTier, improvementDirection, conditionKeys[], availability
- MDC 수치는 넣지 않는다(판정 정책은 insightPolicyVersions, ADR-009).

**수용 기준**

| ID | 기준 | 테스트 종류 | 테스트 위치·이름 |
|---|---|---|---|
| AC-SOAP-02.2 | O 행 metricCode 선택지가 부록 A enum과 일치하고 카탈로그 밖 코드는 저장할 수 없다. (이 스토리는 enum 원본 제공분만, 선택지·저장 차단은 DF-121) | 단위 | tool/contracts/test/catalog.test.mjs::AC-SOAP-02.2 부록 A.1 코드 집합 일치 |
| AC-DF-003.1 | 부록 A.1의 모든 metricCode가 필수 필드를 가진다 | 단위 | tool/contracts/test/catalog.test.mjs::AC-DF-003.1 |
| AC-DF-003.2 | A.5~A.7 어휘는 초안 표시를 가진다 | 단위 | ...::AC-DF-003.2 |
| AC-DF-003.3 | metricCode 중복 0 | 단위 | ...::AC-DF-003.3 |

**테스트 데이터(합성)**
- 없음(어휘 원본만)

**코드 근거**
- 기존 스키마 폴더: dfet:schemas/feature-flags.example.json
- 부록 A 운영 규칙: PRD 부록 A 첫 문단
````

## 변경 이력

| 버전 | 날짜 | 변경 요지 | PR | PRD 영향 |
|---|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성 | — | 없음 |
| v1.0(릴리스 편집) | 2026-09-24 | 이슈 JSON 정본을 `tool/backlog/issues.json`(생성물)으로 고침 | — | 없음 |
