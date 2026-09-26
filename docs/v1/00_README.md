# D-FET Coach v1 개발 문서 안내

| 항목 | 내용 |
|---|---|
| 문서 ID | V1-00 |
| 버전 | v1.3.1 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | [PRD_V1](../PRD_V1.md) 전체. 특히 §0.3 문서 관계, §0.5 ID 체계, §12 단계·게이트, §13 열린 질문·가정 |
| 관련 에픽·스토리 | EP-00~EP-23 / DF-001(문서 병합), DF-002·DF-902(백로그 생성), DF-901(이식 기준선), DF-913(Q-09 결정), DF-930(동결 선언), DF-942·DF-043(서울 리전 전환, DEC-19) |
| 변경 규칙 | [문서 변경](01_AGILE_WORKING_AGREEMENT.md#문서-변경) |

## 목차

- [이 문서군은 무엇인가](#이-문서군은-무엇인가)
- [저장소 공개 상태 주의](#저장소-공개-상태-주의)
- [PRD_V1과의 관계](#prd_v1과의-관계)
- [역할별 읽기 순서](#역할별-읽기-순서)
- [문서 지도](#문서-지도)
- [ID 체계와 헤더 표준 요약](#id-체계와-헤더-표준-요약)
- [스프린트 1 시작 체크리스트](#스프린트-1-시작-체크리스트)
- [결정 기록](#결정-기록)
- [소유자 대기 목록](#소유자-대기-목록)
- [이식 기준선](#이식-기준선)
- [개발 가정(AS-DEV)](#개발-가정as-dev)
- [개발 열린 질문(Q-DEV)](#개발-열린-질문q-dev)
- [알려진 차이와 남은 일](#알려진-차이와-남은-일)
- [규모 요약](#규모-요약)
- [용어 빠른 참조](#용어-빠른-참조)
- [변경 이력](#변경-이력)

## 이 문서군은 무엇인가

D-FET Coach v1을 **바로 개발에 들어갈 수 있는 상태**로 만든 개발 문서 묶음이다. PRD가 '무엇을, 왜'를 정하면, 이 문서군은 '어떻게, 누가, 언제, 어떤 순서로'를 정한다.

- 팀 전제: 소유자 1명(제품 책임자 겸 개발자·리뷰어·게이트 책임자) + AI 코딩 에이전트(Claude, Codex). 구현 대부분은 에이전트가 하고 소유자는 검토·병합·외부 게이트를 맡는다.
- 방식: 1주 스프린트(월~금), GitHub Issues + GitHub Projects 'D-FET Coach v1'로 백로그를 운영한다. 트렁크(main) 기반, 미완성 기능은 플래그 false로 병합한다.
- 첫 스프린트: S01 = 2026-09-28(월) ~ 10-02(금). 추석 연휴(09-24~26) 직후라 스프린트 0은 두지 않는다.
- 외부 게이트(법률 G-04·G-09, 식약처 G-05a/b, IRB G-06·G-07)는 **단계 전환·실데이터·플래그 개방만** 막는다. 합성 데이터 코딩은 막지 않는다.
- 이 문서군은 스테이징에서 작성했고, DF-001이 저장소 `docs/v1/`로 옮긴다. 스테이징 작성 과정에서 저장소는 읽기만 했다.

## 저장소 공개 상태 주의

- `TEhyeok/DFET_Coach`는 **PUBLIC**이다(2026-09-24 확인).
- **결정(DEC-09, 2026-09-25): 공개 유지.** 소유자가 PRD·개발 문서의 공개를 결정했다. 공개 전에 PRD에서 특허 제안서 파일명, 외부 공개 뷰어 URL, 로컬 절대경로를 가렸다. 트레이너 UI 보관 브랜치(`archive/trainer-ui-2026-09`)는 원격에 올리지 않는다.
- 이유: 특허 신규성과 PRD 공개 범위(PRD Q-17, RISK-09), 규제 전략(식약처 G-05a/b 제출 전 표현·범위 노출). 비공개 전환 또는 문서 전용 비공개 저장소 분리를 결정한 뒤 병합한다.
- `.github/**`, `tool/backlog/**`도 같은 PR(DF-001·DF-002)로 들어가므로 같은 제약을 따른다. `create_github_issues.sh --apply`(DF-902)도 이슈 본문에 카드 전문이 들어가므로 공개 범위 결정 뒤에 실행한다.

## PRD_V1과의 관계

1. **PRD(`docs/PRD_V1.md`)가 정본이다.** 범위, 요구사항, 수용 기준과 ID(F-, AC-, C-, NFR-, G-, M-, MIG-, TR-, MB-, AD-, R-, S-, T-, RISK-, AS-, Q-, D)는 PRD에만 있다. 이 문서군은 PRD ID를 **인용만** 하고 새로 만들지 않는다.
2. PRD와 이 문서군이 어긋나면 PRD가 우선한다. 어긋남을 발견하면 PRD를 고치지 말고 이 문서군을 고치거나, PRD 개정이 필요하면 소유자에게 제안한다(PRD 수정은 소유자만).
3. PRD가 모호한 곳은 개발 가정(AS-DEV-NN)이나 각 문서의 가정(ASM-<문서>-NN)으로 적고 관련 PRD Q-·AS-를 함께 적는다. PRD로 올릴 때는 PRD §13.4에 따라 AS-34, Q-25, RISK-12부터 새 번호를 받는다.
4. 코드 근거는 파일을 직접 열어 확인한 뒤 `dfet:경로:줄`, `bodypath:경로:줄`로 적었다. 줄 번호는 2026-09-24 작업 트리 기준이다(예외 규칙은 [P0 읽는 법](backlog/P0.md#0-읽는-법)).
5. 결정 D1~D4(포지셔닝, 앱 정본, 체형평가 범위, 4축 분리)에 영향을 주는 변경은 소유자가 다시 확정한다([01 문서 변경](01_AGILE_WORKING_AGREEMENT.md#문서-변경)).

## 역할별 읽기 순서

| 독자 | 먼저 | 다음 | 필요할 때 |
|---|---|---|---|
| 소유자(PO·개발·리뷰) | 이 문서의 [체크리스트](#스프린트-1-시작-체크리스트)와 [결정 필요 항목](#알려진-차이와-남은-일) → [SPRINT_01](sprints/SPRINT_01.md) → [소유자 행동·게이트](backlog/OWNER_ACTIONS_AND_GATES.md) | [01 작업 합의](01_AGILE_WORKING_AGREEMENT.md)(DoR·DoD·PR·에이전트 규약) → [03 릴리스·스프린트 계획](03_RELEASE_AND_SPRINT_PLAN.md)(게이트 타임라인) → [02 백로그 총괄](02_PRODUCT_BACKLOG.md) §7·§10 | [11 이관 런북](11_MIGRATION_RUNBOOK.md)(MIG-01은 S01 1일차), [tool/backlog/README](../../tool/backlog/README.md) |
| AI 에이전트(스토리 구현) | 이슈에 붙은 작업 지시서([V1-T08](templates/AGENT_BRIEF.md)) → 해당 스토리 카드(`backlog/<단계>.md#df-NNN`) | [13 개발 환경·에이전트 플레이북](13_DEV_ENVIRONMENT_AND_AGENT_PLAYBOOK.md)(명령·컨텍스트 팩·금지 행동) → 지시서가 가리키는 04~12 문서의 절 | [01 에이전트 권한 경계](01_AGILE_WORKING_AGREEMENT.md#에이전트-권한-경계), ADR |
| 리뷰어(PR 검토) | [PR 템플릿](../../.github/pull_request_template.md) → [01 완료 정의(DoD)](01_AGILE_WORKING_AGREEMENT.md#완료-정의dod) → [01 소유자 검토 체크](01_AGILE_WORKING_AGREEMENT.md#소유자-검토-체크위험-라벨별) | 스토리 카드의 수용 기준 → [10 테스트 계획](10_TEST_PLAN.md) §18 수용 기준→테스트 | 위험 라벨별: 규칙 [05](05_DATA_MODEL_AND_RULES.md), 문구 [12](12_COPY_ANALYTICS_AND_LINT.md), 개인정보 [ADR-011](adr/ADR-011-consent-model.md)·[ADR-015](adr/ADR-015-analytics-privacy.md) |
| Windows/GPU 협업자 | [ADR-012 BodyPathCore](adr/ADR-012-bodypath-result-package.md) → [P2·P3 백로그](backlog/P2_P3.md) EP-19 | [04 아키텍처](04_ARCHITECTURE.md)의 BodyPath 결과 전달 | P0~P1b에는 배정 항목이 없다 |
| 디자이너(향후) | [07 트레이너 앱 명세](07_TRAINER_APP_SPEC.md) → [08 회원 앱·관리자](08_MEMBER_APP_AND_ADMIN_SPEC.md) | [12 문구·린트](12_COPY_ANALYTICS_AND_LINT.md), `data/copy_ko.json` | Q-10 디자인 토큰(DF-914) |

## 문서 지도

모든 문서의 상태는 '개발 착수 기준(Ready)', 버전 v1.0, 작성일 2026-09-24다. 줄 수는 스테이징 기준이다.

### 핵심 문서

| 문서 ID | 파일 | 범위 | 줄 수 |
|---|---|---|---|
| V1-00 | [00_README.md](00_README.md) | 이 안내. 읽기 순서, 문서 지도, S01 체크리스트, 결정 기록, 이식 기준선, AS-DEV·Q-DEV | 324 |
| V1-01 | [01_AGILE_WORKING_AGREEMENT.md](01_AGILE_WORKING_AGREEMENT.md) | 1인 PO·개발 + AI 에이전트 작업 합의: 역할, 스프린트 리듬·달력, DoR·DoD, 추정·WIP, 브랜치·커밋·PR, 에이전트 작업 흐름, 게이트 편입, 동결 예외, Projects, 문서 변경 | 744 |
| V1-02 | [02_PRODUCT_BACKLOG.md](02_PRODUCT_BACKLOG.md) | 백로그 총괄: 에픽 24개, 전체 스토리 색인(키·점수·스프린트·의존의 정본), PRD 추적 매트릭스, 임계 경로 | 1,573 |
| V1-02-P0 | [backlog/P0.md](backlog/P0.md) | P0 정리·기반 스토리 카드(DF-001~043) | 4,271 |
| V1-02-P1a | [backlog/P1a.md](backlog/P1a.md) | P1a 알파-기록 카드(DF-100~144) | 3,042 |
| V1-02-P1b | [backlog/P1b.md](backlog/P1b.md) | P1b 알파-평가 카드(DF-200~227) | 2,014 |
| V1-02-P2P3 | [backlog/P2_P3.md](backlog/P2_P3.md) | P2 베타·P3 센터 출시 카드(DF-300~391) | 3,068 |
| V1-02-V2 | [backlog/V2.md](backlog/V2.md) | V2 보류 항목과 재검토 조건(DF-500~508) | 452 |
| V1-02-OA | [backlog/OWNER_ACTIONS_AND_GATES.md](backlog/OWNER_ACTIONS_AND_GATES.md) | 소유자 행동·외부 게이트 카드(DF-901~942), 게이트 카탈로그 | 1,162 |
| V1-03 | [03_RELEASE_AND_SPRINT_PLAN.md](03_RELEASE_AND_SPRINT_PLAN.md) | 달력·용량, 단계 로드맵, 게이트 타임라인, 스프린트별 계획, 주경로, 플래그 개방, 릴리스 열차, 버퍼·재계획·롤백 | 447 |
| V1-03-S01 | [sprints/SPRINT_01.md](sprints/SPRINT_01.md) | 스프린트 01 계획(레인 배정, 일자별 계획, 작업 분해, 첫 작업 지시서, 데모·위험) | 735 |
| V1-04 | [04_ARCHITECTURE.md](04_ARCHITECTURE.md) | 구성도, 저장소 배치, TrainerCore·TrainerKit 모듈과 의존, 이식 대응, 데이터 흐름, 로컬 우선 저장, 인증·권한, 환경, NFR 대응, ADR 색인 | 1,275 |
| V1-05 | [05_DATA_MODEL_AND_RULES.md](05_DATA_MODEL_AND_RULES.md) | 컬렉션 필드, 규칙 설계, R/S 테스트 설계, 인덱스, Storage, 보존·삭제, 로컬 SwiftData, contracts 스키마 | 2,872 |
| V1-06 | [06_API_SPEC.md](06_API_SPEC.md) | Functions callable·트리거·스케줄 계약, admin_web 라우트, Swift·Dart 계약, 쿼리 카탈로그 | 2,634 |
| V1-07 | [07_TRAINER_APP_SPEC.md](07_TRAINER_APP_SPEC.md) | TR-01~TR-15 화면 명세, 상태 매트릭스, syncState 표시, 오프라인 시나리오, 토큰 | 2,093 |
| V1-08 | [08_MEMBER_APP_AND_ADMIN_SPEC.md](08_MEMBER_APP_AND_ADMIN_SPEC.md) | MB-01~MB-06, AD-01~AD-07, Runner 동결과 규제 문구 수정 목록 | 1,899 |
| V1-09 | [09_ALGORITHMS_SPEC.md](09_ALGORITHMS_SPEC.md) | 자세 산식, 확정 요건, BMI·줄자, seriesBreak, O 불러오기, 판정 의사코드와 T01~T25, 금지어 매칭 | 1,941 |
| V1-10 | [10_TEST_PLAN.md](10_TEST_PLAN.md) | 테스트 층·환경·데이터 정책, 계약·규칙·Functions·앱 테스트, 실기기, 성능, 접근성, CI 워크플로 초안, 단계별 종료 기준 | 1,963 |
| V1-11 | [11_MIGRATION_RUNBOOK.md](11_MIGRATION_RUNBOOK.md) | MIG-01~MIG-11 소유자 실행 절차, dry-run, 보고서, 롤백 | 1,646 |
| V1-12 | [12_COPY_ANALYTICS_AND_LINT.md](12_COPY_ANALYTICS_AND_LINT.md) | 사용목적 문구, 금지어 구조와 린트, 회원 문장, 분석 이벤트·audit action, G-10 체크리스트 | 2,172 |
| V1-13 | [13_DEV_ENVIRONMENT_AND_AGENT_PLAYBOOK.md](13_DEV_ENVIRONMENT_AND_AGENT_PLAYBOOK.md) | 도구 버전, 로컬 준비, 명령 모음, 에이전트 진입 문서, 컨텍스트 팩, 금지 행동, 흔한 실패 | 196 |

### ADR(모두 Accepted)

| ID | 파일 | 결정 |
|---|---|---|
| ADR-001 | [adr/ADR-001-independent-trainer-app.md](adr/ADR-001-independent-trainer-app.md) | 독립 트레이너 앱 `trainer_app/` + XcodeGen + TrainerCore·TrainerKit 로컬 패키지 |
| ADR-002 | [adr/ADR-002-local-first-swiftdata-outbox.md](adr/ADR-002-local-first-swiftdata-outbox.md) | SwiftData 편집 원본 + Outbox + Firestore 투영 |
| ADR-003 | [adr/ADR-003-uid-identity-pending-members.md](adr/ADR-003-uid-identity-pending-members.md) | uid 단일 진실원, 대기 회원, 파생 접근 키 trainerId |
| ADR-004 | [adr/ADR-004-root-collections-snapshots.md](adr/ADR-004-root-collections-snapshots.md) | 루트 컬렉션 + ID 참조 + 스냅샷 |
| ADR-005 | [adr/ADR-005-soap-schema-v2-contracts.md](adr/ADR-005-soap-schema-v2-contracts.md) | SOAP 스키마 v2와 contracts 단일 원본 |
| ADR-006 | [adr/ADR-006-member-summaries.md](adr/ADR-006-member-summaries.md) | 서버 생성 소비자본 memberSummaries |
| ADR-007 | [adr/ADR-007-storage-binaries-lidar-local.md](adr/ADR-007-storage-binaries-lidar-local.md) | Storage 바이너리(부모 문서 권한), LiDAR 원본 기기 로컬 |
| ADR-008 | [adr/ADR-008-apple-vision-landmarks.md](adr/ADR-008-apple-vision-landmarks.md) | Apple Vision 2D 랜드마크 엔진 |
| ADR-009 | [adr/ADR-009-server-only-change-evaluation.md](adr/ADR-009-server-only-change-evaluation.md) | 변화 판정 서버 단일 구현(P3), 그 전 pendingPolicy |
| ADR-010 | [adr/ADR-010-feature-flags.md](adr/ADR-010-feature-flags.md) | 기능 플래그 5키 + 규칙 featureOn |
| ADR-011 | [adr/ADR-011-consent-model.md](adr/ADR-011-consent-model.md) | 동의 5종, append-only 기록 + 서버 파생 상태 |
| ADR-012 | [adr/ADR-012-bodypath-result-package.md](adr/ADR-012-bodypath-result-package.md) | BodyPathCore 단계적 패키지(v1: 결과 DTO + 단면 그래프) |
| ADR-013 | [adr/ADR-013-testing-strategy.md](adr/ADR-013-testing-strategy.md) | 계약 픽스처 + 에뮬레이터 + 합성 데이터 |
| ADR-014 | [adr/ADR-014-branching-release.md](adr/ADR-014-branching-release.md) | 트렁크 기반 + 플래그 + 소유자 수동 배포 |
| ADR-015 | [adr/ADR-015-analytics-privacy.md](adr/ADR-015-analytics-privacy.md) | 허용 목록 분석 이벤트 + 서버 집계 |
| ADR-016 | [adr/ADR-016-regulatory-copy-lint.md](adr/ADR-016-regulatory-copy-lint.md) | 금지어 단일 원본 + CI 린트 + 서버 거부 |
| ADR-017 | [adr/ADR-017-functions-structure.md](adr/ADR-017-functions-structure.md) | Functions 구조·리전·런타임 |
| ADR-018 | [adr/ADR-018-admin-claim-unification.md](adr/ADR-018-admin-claim-unification.md) | 관리자 판정을 custom claim admin으로 통일 |
| ADR-019 | [adr/ADR-019-config-and-secrets.md](adr/ADR-019-config-and-secrets.md) | Firebase 구성 파일·비밀 관리 |

### 템플릿·데이터

| ID | 파일 | 용도 |
|---|---|---|
| V1-T01 | [templates/STORY.md](templates/STORY.md) | 스토리 카드 |
| V1-T02 | [templates/SPIKE_REPORT.md](templates/SPIKE_REPORT.md) | 스파이크 보고서 |
| V1-T03 | [templates/ADR.md](templates/ADR.md) | ADR |
| V1-T04 | [templates/SPRINT_PLAN.md](templates/SPRINT_PLAN.md) | 스프린트 계획 |
| V1-T05 | [templates/SPRINT_REVIEW.md](templates/SPRINT_REVIEW.md) | 스프린트 리뷰 |
| V1-T06 | [templates/PHASE_EXIT_REVIEW.md](templates/PHASE_EXIT_REVIEW.md) | 단계 종료 검토 |
| V1-T07 | [templates/GATE_EVIDENCE.md](templates/GATE_EVIDENCE.md) | 게이트 증빙 |
| V1-T08 | [templates/AGENT_BRIEF.md](templates/AGENT_BRIEF.md) | AI 에이전트 작업 지시서 |
| V1-T09 | [templates/DEVICE_TEST_RECORD.md](templates/DEVICE_TEST_RECORD.md) | 실기기 테스트 기록 |
| V1-T10 | [templates/MIGRATION_RUN_RECORD.md](templates/MIGRATION_RUN_RECORD.md) | 이관 실행 기록 |
| V1-T11 | [templates/RETRO.md](templates/RETRO.md) | 회고 |
| V1-T12 | [templates/DAILY_LOG.md](templates/DAILY_LOG.md) | 일일 비동기 기록 |
| V1-T13 | [templates/BUG_REPORT.md](templates/BUG_REPORT.md) | 버그 보고 |
| V1-T14 | [templates/RELEASE_CHECKLIST.md](templates/RELEASE_CHECKLIST.md) | 릴리스 체크리스트 |
| V1-12-D1 | `data/forbidden_terms.json` | 금지어·대체어 규칙(부록 C 기계 판독본) |
| V1-12-D2 | `data/analytics_events.json` | 분석 이벤트 허용 목록 |
| V1-12-D3 | `data/copy_ko.json` | 문구 덱(ko) |

템플릿 이름은 기술 스파인의 `*_TEMPLATE.md` 대신 짧은 이름을 쓴다(01 ASM-01-13).

### GitHub 설정과 백로그 도구(저장소 루트 기준)

| ID | 파일 | 용도 |
|---|---|---|
| GH-01~GH-07 | `.github/ISSUE_TEMPLATE/{config,epic,story,task,bug,spike,owner_action}.yml` | 이슈 폼 |
| GH-08 | `.github/pull_request_template.md` | PR 템플릿 |
| GH-09 | `.github/CODEOWNERS` | 소유자 정독 경로 표시 |
| TL-01 | [tool/backlog/README.md](../../tool/backlog/README.md) | 백로그 도구 사용법 |
| TL-02 | `tool/backlog/labels.json` | 라벨 70개(`scope/mvp`·`scope/carryover`·`scope/deferred` 포함) |
| TL-03 | `tool/backlog/milestones.json` | 마일스톤 9개(단계 6, 게이트 추적 3) |
| TL-04 | `tool/backlog/issue.schema.json` | 이슈 항목 스키마 |
| TL-05 | `tool/backlog/issues.json` | 이슈 데이터(생성물): 에픽 24 + 항목 206 |
| TL-11 | `tool/backlog/create_github_issues.sh`(호환 진입점 `create_backlog.sh`) | gh 생성 스크립트, 기본 dry-run |
| TL-12 | `tool/backlog/validate_backlog.mjs` | 검증기 |
| TL-14 | `tool/backlog/build_issues.mjs` | 색인·카드 → issues.json 생성기 |

## ID 체계와 헤더 표준 요약

| 종류 | 형식 | 정의 위치 |
|---|---|---|
| PRD ID | F-, AC-, C-, NFR-, G-, M-, MIG-, TR-, MB-, AD-, R-, S-, T-, RISK-, AS-, Q-, D | PRD(인용만) |
| 에픽 | EP-00~EP-23(EP-00은 소유자 행동·외부 게이트) | [02 §6](02_PRODUCT_BACKLOG.md#6-에픽) |
| 스토리 | DF-NNN. P0 001~099, P1a 100~199, P1b 200~299, P2 300~379, P3 380~449, V2 500~549, 소유자 행동 900~999 | [02 §8](02_PRODUCT_BACKLOG.md#8-전체-스토리-색인) |
| 스토리 전용 수용 기준 | AC-DF-NNN.k | 스토리 카드 |
| 개발 가정·질문 | AS-DEV-NN, Q-DEV-NN(문서 한정은 Q-DEV-<문서>-NN) | 이 문서 |
| 문서별 가정 | ASM-<문서>-NN(예: ASM-P0-10, ASM-03-01, ASM-01-16, ASM-06-04, ASM-P2P3-12, ASM-V2-01, ASM-S01-01) | 각 문서 가정 절 |
| 문서 로컬 충돌 | CF-<문서>-NN(예: CF-05-07, CF-P0-05, CF-11-02), 12는 X-NN, 07·08·09는 C-07~09-NN. 접두 없는 C-01~C-06은 PRD 공통 규칙 | 각 문서 충돌 절 |
| 문서 | V1-00~V1-13, 하위 V1-02-P0·V1-03-S01, ADR-NNN, 템플릿 V1-T01~T14, GH-01~09, TL-01~14 | 이 문서 지도 |

헤더 표준(모든 `docs/v1/**/*.md`): 첫 줄 `# 제목` → 표(문서 ID, 버전 v1.0, 상태 '개발 착수 기준(Ready)', 작성일 2026-09-24, 소유자 CJH, 근거 PRD 절, 관련 에픽·스토리, 변경 규칙 링크) → `## 목차`. 본문은 한국어, 식별자·코드·JSON 키는 영문이다. 검사는 `tool/lint/doc-headers.mjs`(DF-001)가 한다.

## 스프린트 1 시작 체크리스트

S01은 2026-09-28(월)에 시작한다. 상세 계획은 [SPRINT_01](sprints/SPRINT_01.md)이다.

### 시작 전(09-24~09-27, 연휴 중 소유자 확인)

- [ ] **저장소 공개 범위 결정(D-MIG01-1).** 조사 시점에 `TEhyeok/DFET_Coach`는 PUBLIC이었다. 공개 상태에서 PRD·이 문서군·보관 브랜치를 푸시하면 특허 공개 범위(Q-17) 문제가 생긴다. 권고는 비공개 전환이며, 그 경우 macOS 러너 비용을 03 용량 계획에 반영한다([V1-11 §3.4](11_MIGRATION_RUNBOOK.md#34-실행-절차소유자-s01-1일차-2026-09-28-오전)).
- [x] 이 문서의 [결정 기록](#결정-기록) 중 남은 '확인 필요' 항목(DEC-09 저장소 공개 범위)을 확정한다(2026-09-25, 공개 유지).
- [ ] 도구 설치 확인: Xcode 16.x, XcodeGen 2.44.1(릴리스 zip, SHA-256 확인. brew 금지), Node 22, Java 21, Flutter 3.38.2, firebase-tools 15.x 이상, jq, gh([V1-13 §2](13_DEV_ENVIRONMENT_AND_AGENT_PLAYBOOK.md#2-도구와-버전)).
- [ ] `gh auth refresh -s project,read:project`로 보드 권한을 준비한다(DF-902용).
- [ ] **운영 데이터 리전 = 서울(DEC-19).** DF-942(소유자, S01 화): 942-1에서 서울 지정과 '`nam5` `(default)`에는 테스트 데이터만 있다'는 전제를 소유자가 확인하고, 내보내기를 받은 뒤 `(default)`를 지우고 `asia-northeast3`에 다시 만들고, 서울 Storage 버킷을 만들어 연결한다. 코드 쪽 버킷 명시는 DF-043(S02). 실데이터와 첫 규칙 배포(DF-038 프로브, DF-931)는 이 둘 뒤에만 한다.
- [ ] 스테이징 문서군을 저장소로 옮길 준비: DF-001 브랜치에서 `devdocs/`를 저장소 루트 기준 같은 경로로 복사한다(`docs/v1/**`, `.github/**`, `tool/backlog/**`).

### 1일차(09-28 월)

- [ ] 09:30 스프린트 계획 45분: [SPRINT_01 §4](sprints/SPRINT_01.md#4-약속-항목) 약속 18점 확정, 레인 A(Codex: DF-003→DF-004)·B(Claude: DF-008)·C(Claude: DF-001→DF-002→DF-005) 확인.
- [ ] DF-901 MIG-01 착수: 작업 트리 보존 → A·B·C 분류 → A 커밋 → B 보관 브랜치와 tip 해시 기록([V1-11 §3](11_MIGRATION_RUNBOOK.md#3-mig-01-미커밋-정리)). 자격증명 미스테이징을 커밋마다 확인한다.
- [ ] 오후: 레인 A·B·C 작업 지시서([SPRINT_01 §8](sprints/SPRINT_01.md#8-먼저-실행할-에이전트-작업-지시서))로 에이전트 브랜치를 연다. DF-901 병합 전에는 새 경로 착수만 하고 병합하지 않는다.

### 주중

- [ ] 화: DF-901 PR·CI 4 job·병합, main 보호 규칙. DF-001·DF-003 병합. DF-942 운영 DB·Storage 서울 전환(DEC-19). DF-908 법률 의뢰서는 소유자 보류(2026-09-25): S03 발송 계획, 최신 10-30.
- [ ] 수: DF-903 Firebase 앱 등록·App Attest, DF-904 Q-22 확인, 16:00 게이트 점검. DF-930 동결 선언은 2026-09-25 [G-01 증빙](evidence/G-01.md#동결-선언)에 기록했다.
- [ ] 목: DF-002·DF-004 병합, DF-913 Q-09 결정(이 문서 [결정 기록](#결정-기록)에 기록).
- [ ] 금: DF-008·DF-005 병합, DF-902 백로그 생성([TL-01 §3](../../tool/backlog/README.md#3-소유자-실행-순서)), 필수 체크 추가, 15:00 데모·15:20 회고.

### S01 완료 기준(요지)

G-01 증빙, contracts `--check` 초록, trainer-app 워크플로 초록, SOAP 픽스처, docs/v1 병합과 헤더 린트, 백로그 생성, 소유자 행동 5건 기록(DF-908 대신 DF-942)([SPRINT_01 §2](sprints/SPRINT_01.md#2-스프린트-목표와-성공-기준)).

## 결정 기록

소유자 결정과 이 문서군이 전제로 삼은 값을 적는다. '확인 필요'는 소유자가 S01 계획 회의 전에 확정한다. 결정이 바뀌면 이 표와 영향 문서를 같은 PR에서 고친다.

| ID | 결정 | 상태 | 날짜 | 근거·영향 |
|---|---|---|---|---|
| DEC-01 | 팀 구성: 소유자 1명(PO + 개발자) + AI 코딩 에이전트(Claude, Codex)가 구현 대부분 | 결정(소유자 확인 2026-09-24) | 2026-09-24 | [01 역할](01_AGILE_WORKING_AGREEMENT.md#역할과-책임) |
| DEC-02 | 스프린트 1주(월~금), 휴일 비례 용량 | 결정(소유자 확인 2026-09-24) | 2026-09-24 | [03 §3](03_RELEASE_AND_SPRINT_PLAN.md#3-달력-휴일과-스프린트-용량), AS-DEV-01·09 |
| DEC-03 | 백로그는 GitHub Issues + Projects(`TEhyeok/DFET_Coach`). 문서 단계에서는 템플릿·라벨·마일스톤·이슈 JSON·gh 스크립트만 준비하고 이슈는 만들지 않는다. 생성은 DF-902에서 소유자가 한다 | 결정(소유자 확인 2026-09-24) | 2026-09-24 | [TL-01](../../tool/backlog/README.md), AS-DEV-10 |
| DEC-04 | PRD의 P1a(기록)·P1b(평가) 분할 유지 | 결정(유지, 소유자 확인 2026-09-24) | 2026-09-24 | 02·03 전체 일정이 이 분할을 전제로 한다 |
| DEC-05 | BodyPathCore 단계적 이식: v1은 결과 DTO(BodyPathResult)와 단면 그래프(BodyPathCoreUI)만 | 결정(단계적 이식 유지, 소유자 확인 2026-09-24) | 2026-09-24 | [ADR-012](adr/ADR-012-bodypath-result-package.md) |
| DEC-06 | 마일스톤 목표일은 속도 기반 일정(P0 10-30, P1a 01-08, P1b 01-29, P2 03-26, P3 05-07)을 따른다 | 전제 | 2026-09-24 | [03 §14.2 D-1](03_RELEASE_AND_SPRINT_PLAN.md#14-가정asm과-스파인prd와의-차이), `milestones.json` |
| DEC-07 | 이슈 데이터는 단계별 파일 대신 단일 `issues.json`(생성물) + `--phase` 옵션 | 전제(도구 설계) | 2026-09-24 | [TL-01 §1](../../tool/backlog/README.md#1-무엇이-있나) |
| DEC-08 | owner-action·스파이크 점수는 스프린트 약속과 속도(완료 점수)에 포함한다. 소유자 실제 시간은 V1-T05 "소유자 시간" 표에 따로 적는다 | 결정 | 2026-09-24 | 02 §4.3(정본), 01 ASM-01-16, SPRINT_01 약속 18 = 개발 15 + 소유자 3 |
| DEC-09 | 저장소 공개 범위(D-MIG01-1): **공개 유지**. PRD_V1(특허 파일명·외부 뷰어 URL·로컬 절대경로 가림)과 docs/v1·이슈 키트를 공개 저장소에 올린다. 트레이너 UI 보관 브랜치는 원격에 푸시하지 않는다 | 결정(소유자 2026-09-25) | 2026-09-25 | [V1-11 §3.4](11_MIGRATION_RUNBOOK.md#34-실행-절차소유자-s01-1일차-2026-09-28-오전), Q-17 |
| DEC-10 | 에뮬레이터 시드 정본 = `functions/scripts/dev/seed-emulator.js` + `functions/test/fixtures/emulator-seed.v1.json`(변형 `.no-consent.v1.json`, `.consent-fail.v1.json`), 프로젝트 `demo-dfet`, ID `synthTrainerA`·`synthMember0001`·`SYNTHpending00000001` | 결정 | 2026-09-24 | [V1-10 §5.2~§5.4](10_TEST_PLAN.md#5-테스트-데이터픽스처-정책). `tool/emulator/seed.mjs`와 이전 ID 체계는 쓰지 않는다(K-05) |
| DEC-11 | 02 §8 색인이 의존 정본이며 카드가 더한 의존은 같은/앞선 스프린트일 때만 색인에 넣고, 아니면 카드에 '참고(soft)'로 둔다 | 결정 | 2026-09-24 | [02 §8](02_PRODUCT_BACKLOG.md#8-전체-스토리-색인), `issues.json` 원천 데이터(K-02) |
| DEC-12 | 트레이너 앱 패키지 둘: `trainer_app/Packages/TrainerCore`(순수, macOS `swift test`)와 `trainer_app/Packages/TrainerKit`(iOS 전용). 픽스처는 `#filePath`로 저장소 루트 `contracts/`를 직접 읽고 복사하지 않으며(픽스처 로더는 `Packages/TrainerCore/Tests`), project.yml에 `optional: true` plist 항목을 두지 않는다(plist는 postBuildScripts 복사) | 결정 | 2026-09-24 | [ADR-001](adr/ADR-001-independent-trainer-app.md), V1-04, K-08 |
| DEC-13 | 데이터 정본은 V1-05(로컬 SwiftData·Outbox 상태·TodayListEntry §12, contracts·vocab §13, consentDocumentVersions ID `{consentType}--{version}`, recordConsent 멱등 키 `clientCaptureId`, `markSummaryViewed`는 DF-335 소유·MB-02·MB-04 호출, `FilterPreference`, `LocalPendingMemberDraft`, 인덱스 소유 §10.2) | 결정 | 2026-09-24 | [V1-05](05_DATA_MODEL_AND_RULES.md). 다른 문서와 다르면 V1-05를 따른다 |
| DEC-14 | 게이트 증빙 폴더는 `docs/v1/evidence/` | 결정 | 2026-09-24 | [V1-02-OA](backlog/OWNER_ACTIONS_AND_GATES.md), [이식 기준선](#이식-기준선) |
| DEC-15 | 배포 명령은 항상 `firebase deploy --project dfetmanage --only …` | 결정 | 2026-09-24 | ADR-014, V1-11 |
| DEC-16 | XcodeGen은 2.44.1 릴리스 zip(SHA-256 확인)으로 설치하고 brew를 쓰지 않는다 | 결정 | 2026-09-24 | [V1-13 §2](13_DEV_ENVIRONMENT_AND_AGENT_PLAYBOOK.md#2-도구와-버전), SPRINT_01 ASM-S01-09 |
| DEC-17 | 추가 제안(`status/needs-decision`)은 채택 전까지 스프린트 합계에서 뺀다 | 결정 | 2026-09-24 | [02 §8.8.2](02_PRODUCT_BACKLOG.md#882-채택-시-적재-영향미리-계산), K-03 |
| DEC-18 | 문서별 가정 ID는 `ASM-<문서>-NN`(ASM-01-NN, ASM-06-NN, ASM-P2P3-NN, ASM-V2-NN 등), 문서 로컬 충돌 ID는 PRD C-01~C-06과 겹치지 않게 `CF-<문서>-NN`(또는 이미 쓰는 X-NN·CF-NN·C-07~09-NN) | 결정 | 2026-09-24 | [ID 체계와 헤더 표준 요약](#id-체계와-헤더-표준-요약) |
| DEC-19 | 운영 데이터 리전 = **아시아 리전**(소유자 지시 2026-09-25 '아시아 리전으로 운영'). 구체 위치 **서울 `asia-northeast3`**는 NFR-16·ADR-017(Functions 리전)에 맞춘 해석이며, DF-942 실행 전(942-1, 늦어도 09-28 S01 계획) 소유자가 확인한다. 운영 Firestore `(default)`(현재 `nam5` 미국 멀티 리전)는 위치를 바꿀 수 없으므로 소유자가 지우고 같은 ID `(default)`를 `asia-northeast3`에 다시 만든다(소유자 승인 운영 작업, 에이전트는 하지 않는다: DF-942). **'`(default)`에는 테스트 데이터만 있다'는 결정이 아니라 전제다.** 소유자는 실사용 여부에 아직 답하지 않았고, 규칙이 전부 거부여도 Admin SDK 경로(Functions·admin_web)는 규칙을 우회하므로 실데이터가 없다는 증거가 되지 않는다. 942-1에서 소유자가 확인하고, 삭제 전에는 항상 같은 프로젝트 버킷으로 `gcloud firestore export`를 받는다. 테스트 데이터로 분명하지 않은 컬렉션·문서 수가 있으면 삭제하지 않고 다시 정한다. Storage 기본 버킷은 위치를 바꿀 수 없으므로 서울 버킷을 새로 만들어 Firebase에 연결하고, 앱·admin_web·Functions·`firebase.json`이 그 버킷을 명시하게 한다(DF-043, 트레이너 앱은 DF-104). 미사용 Enterprise DB 2개(`asia-east1`)의 유지·삭제는 소유자 결정으로 남긴다 | 결정(소유자 2026-09-25: 아시아 리전 → 서울 `asia-northeast3` 선택, 기존 `(default)`는 테스트 데이터뿐이라고 답변). 삭제 전 확인·내보내기 단계는 DF-942 절차대로 소유자가 판단 | 2026-09-25 | K-17 해소. PRD Q-08의 답(Firestore·Storage 서울, Auth·분석 SDK는 AS-19대로 국외 전제)이며 PRD 반영은 소유자가 직접 한다. Firestore 트리거 리전(P0 ASM-P0-10, ADR-017 `FIRESTORE_TRIGGER_REGION`, Q-DEV-04-01) = `asia-northeast3`. 실데이터와 첫 규칙 배포(DF-038 프로브, DF-931)는 DF-942·DF-043 뒤 |
| DEC-20 | 스프린트 PR은 **CI 필수 체크가 초록이고 적대적 리뷰가 승인하면 AI가 rebase 병합한다**(2026-09-25 오케스트레이션 작업 지시에 적힌 소유자 위임. 소유자 요청 원문에는 병합 위임 문구가 없어 소유자 확인이 필요하다). 구현 에이전트는 자기 PR을 병합하지 않는다. 운영 배포, `create_github_issues.sh --apply`, 이관 `--apply`, PRD 수정, D1~D4 변경, 권한 경계를 바꾸는 PR의 병합(01 '병합' 행 금지 열)은 계속 소유자만 한다. **이 결정을 기록한 PR(#113)은 병합 담당 AI가 아니라 소유자가 병합하며, DEC-20은 소유자가 그 PR을 병합한 때부터 발효한다.** 첫 AI 병합 전에 소유자가 `main` 브랜치 보호에 필수 체크를 등록한다(K-18 ③) | 결정(소유자 확정 2026-09-25: 대화에서 '모든 결정은 너가해서 전체 다 만들어'라고 위임하고, PR #113 병합과 DEC-20~22 확정을 직접 선택). 권한 경계를 바꾸는 PR은 계속 소유자 확인 뒤 병합한다 | 2026-09-25 | [01 에이전트 권한 경계](01_AGILE_WORKING_AGREEMENT.md#에이전트-권한-경계), 01 PR 규칙·DoD D12. ADR-014(스쿼시)·AGENTS.md·CLAUDE.md 문구와의 차이는 K-18 |
| DEC-21 | **AI가 정한 결정(작업 지시의 위임 근거)**. ① DF-009(Swift SOAP v2 코덱)는 Claude가 맡는다. Codex 브랜치는 대체하며 가져오지 않는다 ② 02 §8.8.1 추가 제안: MVP에 필요한 DF-042(에뮬레이터 시드)만 채택(S03, 1점, DF-012 의존 추가, K-12 해소). 나머지 15건(DF-041·143·144·227·333·335~338·391·506~508·940·941)은 'MVP 뒤 결정'(상태 `채택 대기` 유지) ③ PRD §13.3 열린 질문: 외부 판단이 필요한 것은 **미결 유지**(Q-01 식약처, Q-02 IRB, Q-04·Q-05·Q-07·Q-21·Q-24 법률, Q-17 변리, Q-23 규제·법률). 나머지는 PRD의 '결정 전 기본값'을 문서화된 기본값으로 쓴다: Q-03(BodyPath iPhone 촬영 뒤 가져오기, LiDAR는 MVP 밖), Q-06(자동 이관 없음), Q-09(자체 제품 로드맵, 과업 양식 미적용. DF-913 대체), Q-10(중립 회색 + 브랜드 블루. DF-914 대체), Q-11(트레이너 설정), Q-12(v1 불가), Q-13(P3), Q-14(V2), Q-15(내부만), Q-16(enum 예약, 렌더 안 함), Q-18(Apple Vision 2D), Q-19(두지 않음), Q-20(전역 불리언), Q-22(iPad 전용. 스토어 이력 확인 DF-904는 배포 전까지 남김). **Q-08은 해소**: Firestore·Storage 서울 `asia-northeast3`(DEC-19) ④ 개발 열린 질문 Q-DEV-01~06은 표의 '결정 전 기본값'으로 진행한다(모두 MVP 밖 기능이거나 G-09 뒤) ⑤ MVP 동안 카드가 기다리던 소유자 확정값은 문서의 초안으로 진행한다: 부록 A.5~A.7 코드(DF-916), 촬영 프로토콜 v1 초안 수치(DF-915). 소유자 확정은 실회원 전 | 결정(AI 결정, 소유자 확정 2026-09-25). 법률·식약처·IRB·특허 판단은 외부 미결로 남는다 | 2026-09-25 | [02 §8.8.1](02_PRODUCT_BACKLOG.md#881-제안-목록), [P0 DF-042](backlog/P0.md#df-042), PRD §13.3. PRD 수정은 하지 않는다(PRD 반영은 소유자) |
| DEC-22 | **MVP 범위 = '1인 알파 MVP'**: 소유자(트레이너) 혼자 독립 iPad 트레이너 앱으로 **테스트 회원**(트레이너가 만든 대기 회원. 회원 앱·초대·공유 없음)에게 네 흐름을 쓴다. ① SOAP: 세션 중 Live 한 줄·Pencil → Review에서 S/O/A/P 구조화 → 확정·addendum ② 신체조성(수기 + 결과지 사진)과 줄자 둘레 ③ 정면·측면 체형 사진 → Apple Vision 자동 랜드마크 + 수동 보정 → 체형 지표(CVA, 어깨 높이 차. 나머지는 참고) ④ 회원별 타임라인과 추이 차트(출처 등급 칩, 추이 끊김. 변화 판정은 '산정 준비 중'만, MDC 엔진 없음). 데이터는 기기 로컬 우선 + Firebase(서울, DEC-19) 동기화, 쓰는 컬렉션의 Firestore·Storage 규칙 포함. 항목 목록은 [03 MVP 계획](03_RELEASE_AND_SPRINT_PLAN.md#mvp-계획dec-22)과 라벨 `scope/mvp`(67건·191점, 02 §7.4). **MVP 뒤로 연기**: 회원 앱 기능과 공유·초대·memberSummaries(P2), 동의 5종 전체·권리 행사·보유기간 파기·감사·opsMetrics(MVP는 대기 회원 ①②③ 기록만), 규제 게이트(법률 G-04·G-09, 식약처 G-05, IRB G-06·G-07), Runner 문구 수정과 copy-lint 차단 모드(DF-028·029·040·041. 문구 수정 릴리스 DF-911과 식약처 사전 확인 DF-910은 규제 게이트 G-05에 둔다), 레거시 이관 MIG-02~MIG-08(운영 DB를 새로 만들어 레거시 데이터 없음), 트레이너 앱에 꼭 필요한 것 밖의 admin_web 정책·플래그 화면(AD-03·AD-05·AD-07 확장), LiDAR 베타, 판정 엔진·배지, P3, V2. 트레이너 앱은 iPad 전용이고 지금은 시뮬레이터로 확인한다(실기기 iPad 연결 뒤 실기기 확인). **실회원 데이터는 MVP에 넣지 않는다**: 원래 게이트(G-03·G-04·G-05a·G-09)는 실데이터 전에 그대로 필요하다. '테스트 회원' 데이터는 합성 데이터, 출처·라이선스를 기록한 합성·공개 샘플 이미지(DF-200과 같은 기준), 또는 소유자 본인 데이터만이다. 직원·지인 등 제3자의 사진·신체 데이터는 G-04·G-09 증빙 전에는 서울 프로젝트에도 에뮬레이터에도 넣지 않는다(개발 데이터 취급 규칙이며 법률 판단이 아니다, [03 MVP 공통 규칙](03_RELEASE_AND_SPRINT_PLAN.md#mvp-공통-규칙)) | 결정(소유자 선택 '1인 알파 MVP만', 확정 2026-09-25). 운영 플래그를 테스트 회원용으로 켜는 일(DF-925·DF-929 MVP 범위)은 소유자 대기 목록에서 소유자가 실행한다 | 2026-09-25 | [02 §7.4](02_PRODUCT_BACKLOG.md#74-mvp-적재dec-22), [03 MVP 계획](03_RELEASE_AND_SPRINT_PLAN.md#mvp-계획dec-22), 카드별 `### MVP 범위(DEC-22)`. 소유자 작업은 [소유자 대기 목록](#소유자-대기-목록) |
| Q-09 | 2026 과업지시서와의 관계 | 기본값 채택(DEC-21 ③, 소유자 확정 2026-09-25). 원래: 미결(DF-913, S01 목). 결정 전 기본값: 자체 제품 로드맵, 과업 산출물 양식 미적용 | — | PRD §13.3. PRD 반영은 소유자가 직접 |
| Q-10 | 트레이너 앱 디자인 토큰 | 기본값 채택(DEC-21 ③, 소유자 확정 2026-09-25). 원래: 미결(DF-914, S06). 기본값: 중립 회색 + 브랜드 블루, 초록은 저장·완료 상태 전용 | — | PRD §8.5 |
| Q-22 | 트레이너 앱 번들의 iPhone 배포 이력 | MVP는 iPad 전용(DEC-21 ③). 스토어 이력 확인(DF-904)은 배포 전까지 미결. 기본값: iPad 전용(`TARGETED_DEVICE_FAMILY "2"`) | — | ADR-001, 03 T-07 |
| Q-24 | 코칭 기록 최대 보유기간 N | 미결(DF-908 법률 자문, 소유자 보류 2026-09-25: S03 발송 계획, 최신 10-30). 결정 없이는 G-04 미통과 | — | PRD Q-24, DF-133은 N 미설정 시 파기 분기 비활성 |

## 소유자 대기 목록

에이전트가 할 수 없는 운영·콘솔 작업이다(01 에이전트 권한 경계, DEC-15). 위에서부터 순서대로 한다. 값(앱 ID, 키, 서비스 계정 값, 이메일, uid)은 저장소·PR·이슈에 적지 않는다. 서울 버킷 이름은 비밀이 아니므로(기본 버킷 이름도 이미 앱 구성 파일에 커밋돼 있다) DF-043·DF-104의 코드 상수, `firebase.json`, `admin_web/.env.example`, G-09.md에 적는다. MVP 흐름의 서울 확인은 이 목록이 끝나야 할 수 있고, 그 전에는 에뮬레이터로 개발·확인한다(코딩 차단 아님).

| 순서 | 키 | 할 일 | 명령·위치 | 필요한 때 |
|---|---|---|---|---|
| 1 | DF-942 | **942-1 사전 확인**: 서울 지정 확인, 운영 `(default)`(`nam5`)의 컬렉션·문서 수가 테스트 데이터뿐인지 확인. 테스트 데이터로 분명하지 않으면 **여기서 멈춘다** | Firebase 콘솔 → Firestore | 지금(S01 기한 10-02 지남 위험) |
| 2 | DF-942 | **삭제 전 내보내기(항상)** | `gcloud firestore export gs://<같은 프로젝트 버킷>/firestore-export-<날짜> --database='(default)' --project=dfetmanage` | 1 뒤 |
| 3 | DF-942 | 재생성 가능 확인(위치 고정 설정, ID 재사용 대기). 막히면 이름 있는 DB를 만들지 말고 멈춘다 | 콘솔·공식 문서([카드](backlog/OWNER_ACTIONS_AND_GATES.md#df-942) 1·2단계) | 2 뒤 |
| 4 | DF-942 | 삭제 보호 해제(켜져 있으면) → 삭제 → 서울에 같은 ID로 재생성 | `gcloud firestore databases update --database='(default)' --no-delete-protection --project=dfetmanage`<br>`firebase firestore:databases:delete "(default)" --project dfetmanage --force`<br>`firebase firestore:databases:create "(default)" --location asia-northeast3 --delete-protection ENABLED --project dfetmanage` | 3 뒤 |
| 5 | DF-942 | 서울 Storage 버킷(`asia-northeast3`, 단일 리전) 생성·Firebase 연결, 규칙은 전부 거부 그대로. 버킷 이름을 DF-043에 알림. admin_web 운영 `NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET` 교체. G-09.md 리전 절 기록 | Firebase 콘솔 → Storage → 버킷 추가 | 4 뒤 |
| 6 | DF-903 | 트레이너 앱 iOS 앱 등록, plist는 저장소 밖 보관(DF-034가 CI 주입). 팀 ID(MT27Z7369H)·App Attest는 콘솔에서 | `firebase apps:create IOS "D-FET Trainer" --bundle-id kr.co.dfet.trainer --project dfetmanage` | 지금(DF-034·DF-012 실계정 확인 전) |
| 7 | DF-905(MVP 범위) | 서울 DB 재생성 뒤 소유자 계정 하나에 claim `trainer: true`와 `trainers/{uid}`(`memberIds: []`). 운영 가상 회원 시드는 MVP에서 하지 않는다(테스트 회원은 앱에서 만든다) | ① 소유자 계정으로 Auth 사용자 생성 → 콘솔에서 `users/{uid}.role = "trainer"`<br>② `cd functions && npm ci`(스크립트가 `firebase-admin`을 쓴다)<br>③ 콘솔에서 받은 서비스 계정 키를 `functions/service-account-key.json`에 둔다. 스크립트가 `require('../service-account-key.json')`로 이 경로만 읽는다. `.gitignore`(`functions/service-account-key.json`, `**/service-account*.json`)가 막지만 커밋·PR·로그에 내용을 붙이지 않는다<br>④ `functions`에서 `node scripts/migrate_trainers.js`(dry-run, 대상 1명 확인) → `node scripts/migrate_trainers.js --apply`<br>⑤ 키 파일을 지우고 콘솔에서 그 키를 폐기한다 | S04(DF-012) 전 |
| 8 | DF-906 | Storage 서비스 에이전트에 Firestore 교차 조회 권한(Storage 규칙이 `firestore.get`을 쓴다) | 첫 `storage` 배포 때 CLI가 묻는 권한 부여에 동의하거나 `gcloud projects add-iam-policy-binding dfetmanage --member=serviceAccount:service-<프로젝트 번호>@gcp-sa-firebasestorage.iam.gserviceaccount.com --role=roles/firebaserules.firestoreServiceAgent` | 9와 함께 |
| 9 | DF-931(MVP 범위) | 규칙·인덱스·Storage 규칙·`recordConsent`를 태그 기준으로 서울에 배포 | `firebase deploy --project dfetmanage --only firestore:rules,firestore:indexes,storage,functions:recordConsent` | S07(DF-022·023·024·035·109 병합 뒤) |
| 10 | DF-109(MVP 범위) | 서울에 테스트용 동의 문서 버전 게시 | DF-109가 만드는 게시 스크립트(기본 dry-run). `--apply --project dfetmanage`는 소유자만 | 9 뒤 |
| 11 | DF-925·DF-929(MVP 범위) | **소유자 결정 필요**: 테스트 회원만 쓰는 동안 서울 `appConfig/features`의 `soapV2`·`bodyComposition`(S07), `bodyAssessment`(S11)를 true로. 나머지 키 false. 실회원 데이터는 넣지 않는다 | Firebase 콘솔 → Firestore → `appConfig/features` | 켜지 않으면 서울 확인만 막히고 에뮬레이터 확인은 된다 |
| 12 | DF-931(MVP 범위) 재배포 | S07 뒤 병합된 MVP 변경(DF-114 `circumferenceMeasurements` 인덱스 2개, DF-206·DF-209 규칙 보강이 넘어오면 그것)을 MVP 종료 규칙·Functions 태그 기준으로 서울에 다시 배포. 인덱스 빌드가 모두 끝날 때까지 기다린다 | `firebase deploy --project dfetmanage --only firestore:rules,firestore:indexes,storage,functions:recordConsent` → 콘솔 Firestore → 색인에서 빌드 완료 확인 | S12 끝, 늦어도 S13 첫날(데모 체크리스트 B 전) |

- DF-906은 Storage 교차 서비스 규칙이 MVP에 들어 있어서 필요하다(DF-023·DF-038). 
- 미사용 `asia-east1` Enterprise DB 2개의 유지·삭제와 미국 기본 버킷 정리는 남은 소유자 결정이다(K-17 ③). 비용 판단이며 MVP를 막지 않는다.
- MVP 밖으로 미룬 소유자 행동(DF-904, DF-907~DF-913, DF-914~DF-916의 확정, DF-918~DF-924, DF-926~DF-928, DF-930 외 단계 종료 검토·게이트)은 MVP 종료 검토 뒤 다시 계획한다. DF-930 동결 선언은 이 PR에 기록돼 있다.

## 이식 기준선

DF-901(MIG-01)에서 채우고 DF-039에서 다시 확인했다. 이식 스토리는 이 해시의 파일을 원본으로 삼는다. `main`의 동결 파일(`ios/Runner/AppDelegate.swift` 8,800줄 등)은 이식 원본이 아니다.

| 항목 | 값 | 기록일 |
|---|---|---|
| 보관 브랜치 | `archive/trainer-ui-2026-09`(로컬 전용 + 번들 백업, 원격 없음. DEC-09) | 2026-09-25(DF-901 생성) |
| tip 커밋 해시 | `82c6ee9b4c95e9622fc1c44111ddc20ee9f68941`(로컬 전용, 공개 저장소라 원격에 푸시하지 않음) | 2026-09-25 |
| 이식 기준선 확인(DF-039) | tip `82c6ee9`의 `ios/Runner/AppDelegate.swift` 9,657줄. 최상위 선언 줄 99개(`@main`·`@objc class`·타입·프로토콜·확장) 경계와 반례 줄을 다시 확인했고 2026-09-24 작업 트리 판과 줄 번호가 같다. 모듈별 줄 범위는 [V1-07 §7.1](07_TRAINER_APP_SPEC.md#71-dfetiosrunnerappdelegateswift--트레이너-앱모듈별-책임과-이식-원본-줄-범위), 반례는 [V1-07 §7.4](07_TRAINER_APP_SPEC.md#74-옮기지-않을-결함prd-103646--이-문서-추가), 스토리별 필독 범위는 [V1-13 §6.1](13_DEV_ENVIRONMENT_AND_AGENT_PLAYBOOK.md#61-이식-스토리-필독-원본-줄-범위df-039) | 2026-09-26 |
| main 병합 커밋(A분류) | `6b50fbf`([PR #1](https://github.com/TEhyeok/DFET_Coach/pull/1) rebase 병합, `3ef5b79..6b50fbf` 37개 커밋) | 2026-09-25 |
| trainer_ios 보존 태그 | `archive/trainer_ios-final`(DF-142, P1a S13) | — |

기입은 소유자가 G-01 증빙(`docs/v1/evidence/G-01.md`)과 함께 한다. PRD 변경 이력에도 같은 해시를 적는다(소유자 편집).

## 개발 가정(AS-DEV)

PRD에 없는 개발 운영 가정이다. PRD로 올릴 때는 AS-34부터 새 번호를 받는다.

| ID | 가정 | 틀리면 |
|---|---|---|
| AS-DEV-01 | 개천절(10-03, 토)의 대체공휴일 10-05(월)가 적용된다. S02는 3작업일(10-06~10-08) | S02 용량을 16점으로 다시 계산 |
| AS-DEV-02 | v1에는 스테이징 Firebase 프로젝트가 없다. 개발은 에뮬레이터와 합성 데이터로 하고 운영 배포는 소유자가 수동으로 한다 | 스테이징 프로젝트를 만들면 ADR-013·ADR-014 개정 |
| AS-DEV-03 | BodyPath 저장소는 비공개다(2026-09-24 확인, ADR-012). SPM 읽기 자격 DF-923이 S23 전에 필요하다(P2) | 공개로 바뀌면 DF-923 불필요 |
| AS-DEV-04 | `GoogleService-Info.plist`는 추적하지 않고 CI 시크릿으로 주입한다(G-02에서 확정) | ADR-019 개정 |
| AS-DEV-05 | 위젯 확장은 v1에서 제외한다 | 별도 스토리와 PRD 확인 |
| AS-DEV-06 | 개발 환경은 Xcode 16.x, Swift 5 언어 모드, macos-15 러너다 | 러너·도구 버전 갱신 PR |
| AS-DEV-07 | 분석 제공자는 Firebase Analytics이며 G-09 공개 전에는 DebugSink만 쓴다 | 자체 수집(Q-DEV-01)으로 전환 |
| AS-DEV-08 | P1a~P2 배포는 TestFlight 내부 그룹이다. P3 배포 채널은 Q-DEV-02 | 03 릴리스 열차 개정 |
| AS-DEV-09 | 초기 용량은 5작업일 스프린트당 20점(약속 18점)이다. S02 종료 뒤 실측으로 보정 | S03부터 보정값 |
| AS-DEV-10 | GitHub Projects v2를 쓴다 | 보드 대체 도구 선정 |
| AS-DEV-11 | v1 작업은 main에서 분기한다(`feature/integrated-care-2026`은 DF-901 뒤 삭제) | 01 브랜치 규칙 개정 |
| AS-DEV-12 | Functions는 JavaScript CommonJS와 node:test를 유지한다 | TypeScript 전환 ADR |
| AS-DEV-13 | 관리자 알림은 Cloud Logging 로그 기반 알림(이메일)으로 한다(새 컬렉션 없음) | 알림 채널 결정 |

## 개발 열린 질문(Q-DEV)

전역 질문(Q-DEV-01~06)은 여기서 관리한다. 문서 한정 질문(Q-DEV-<문서>-NN)은 각 문서의 표가 정본이고 아래는 색인이다. 결정되면 '결정 기록'에 옮긴다.

| ID | 질문 | 결정 전 기본값 | 기한 | 출처 |
|---|---|---|---|---|
| Q-DEV-01 | G-09에서 국외 이전 공개가 어렵다면 분석을 자체 Firestore 이벤트 수집으로 바꿀 것인가 | Firebase Analytics(G-09 전 DebugSink) | G-09 | [ADR-015](adr/ADR-015-analytics-privacy.md) |
| Q-DEV-02 | P3 트레이너 앱 배포 채널(App Store 공개, 비공개 배포 등) | 미정. P2까지 TestFlight 내부 | P3 진입 | AS-DEV-08, [03 §9.1](03_RELEASE_AND_SPRINT_PLAN.md#91-트레이너-앱d-fet-trainer) |
| Q-DEV-03 | 공유 알림(F-SOAP-05.12)을 어떤 수단으로 보낼 것인가 | 앱 내 목록 갱신만, 푸시 없음 | P2 진입 | [06 §14.3](06_API_SPEC.md) |
| Q-DEV-04 | `markSummaryViewed`와 `firstViewedAt`(M-06·M-07 서버 기록)을 승인하는가 | 미구현, M-06·M-07은 null | P2 진입 | [06 §14.3](06_API_SPEC.md), 추가 제안 DF-335 |
| Q-DEV-05 | 동의 상태 문서가 없는 레거시 회원 기록의 트레이너 열람을 언제 끊는가 | 끊지 않음(06 ASM-06-31) | G-04 | [06 §14.3](06_API_SPEC.md) |
| Q-DEV-06 | 트레이너 계정 탈퇴·정리 절차 | 자기 삭제 거부(06 ASM-06-16) | P3 진입 | [06 §14.3](06_API_SPEC.md) |
| Q-DEV-04-01·02 | 트리거 리전, 공용 iPad 다중 트레이너 | 04 표 참조. 트리거 리전(04-01)은 DEC-19로 `asia-northeast3`(DF-942 뒤) | Q-08·G-09 | [04](04_ARCHITECTURE.md) |
| Q-DEV-08-01~05 | 회원 앱 분석 SDK, 재확인 기한 경과, 열람 결과 전달, 기존 금지어 정리, P3 역할 claim | 08 표 참조 | S04~P3 | [08](08_MEMBER_APP_AND_ADMIN_SPEC.md) |
| Q-DEV-11-01~03 | 위생 처리 v1 문서 파기, freeze-exception CI 강제, 적용일 공지 채널 | 11 표 참조 | DF-924 등 | [11](11_MIGRATION_RUNBOOK.md) |
| Q-DEV-12-01~06 | M-02 해석, 회원 앱 분석 SDK, M-G2 대조 스크립트, B.8 문장 추가, 4축 부정문 고지, 공유 알림 경로 | 12 표 참조 | S04~P3 | [12](12_COPY_ANALYTICS_AND_LINT.md) |

중복: Q-DEV-03과 Q-DEV-12-06(공유 알림), Q-DEV-08-01과 Q-DEV-12-02(회원 앱 분석 SDK)는 같은 질문이다. 결정은 Q-DEV-03, Q-DEV-08-01에 한 번만 기록하고 다른 쪽은 그 결정을 따른다.

## 알려진 차이와 남은 일

릴리스 편집 단계(2026-09-24)에서 확인한 문서 간 차이와 남은 일이다. '결정'은 소유자, '작업'은 담당 스토리가 처리한다.

| ID | 내용 | 처리 |
|---|---|---|
| K-01 | owner-action 점수의 속도 포함 여부가 문서마다 달랐다. 01 ASM-01-16과 01 게이트 편입 절은 '표시용, 속도에서 뺀다', 02 §4.3과 백로그 스파인은 '포함한다'. SPRINT_01은 약속 18점 = 개발 15 + 소유자 3으로 적었다 | 해소(DEC-08, R1): owner-action·스파이크 점수를 약속·속도에 포함한다. 01 ASM-01-16, 02 §4.3·ASM-02-14, SPRINT_01 ASM-S01-13, OA ASM-OA-05, V1-T04·T05를 맞췄다. 스프린트 적재 합계(§규모 요약, 02 §7.3, 03 §6)는 소유자 점수를 포함한 값이다 |
| K-02 | 02 §8 색인의 의존은 스파인 값을 유지하고, 카드가 의존을 더 적은 경우가 있다(예: DF-109←DF-107, DF-114←DF-113·DF-116, DF-116←DF-113, DF-127←DF-121·DF-114, DF-309←DF-033·DF-037, DF-316←DF-315). 이슈 본문에는 '카드가 더한 의존'으로 함께 보인다 | 해소(DEC-11): 같은/앞선 스프린트 의존 6건(DF-109←107, DF-114←113·116, DF-116←113, DF-127←121·114, DF-309←033·037, DF-316←315)을 02 §8에 반영. DF-336←DF-320은 스프린트 역전이라 카드에 참고(soft)로 둠. 남은 카드 의존은 제안 키(DF-042·041·941)뿐이며 채택 시 반영 |
| K-03 | 추가 제안 16건(20점, DF-041·042·143·144·227·333·335~338·391·506~508·940·941)은 채택 대기다. 이슈 데이터에는 `status/needs-decision`으로 들어 있고 합계에서 뺐다 | 결정(DEC-21, 2026-09-25): DF-042 채택(S03). 나머지 15건(19점)은 MVP 뒤 결정(상태 `채택 대기` 유지) |
| K-04 | 작업 지시서 생성기 `tool/backlog/brief.mjs`(01 ASM-01-17, TL-13 후보)는 아직 없다. S01 지시서는 SPRINT_01 §8에 손으로 조립돼 있다 | 해결(2026-09-25): DF-002(PR #109)가 `tool/backlog/brief.mjs`(TL-13)를 병합했다. 남은 것: 지시서 고정문(0·9·11절의 draft PR·병합 금지·스쿼시 제목)이 V1-T08 템플릿에서 와서 DEC-20과 다르다. 템플릿을 고친 뒤 다시 생성한다(DEC-20 발효 뒤 문서 레인) |
| K-05 | 에뮬레이터 시드 스크립트 경로와 합성 ID 체계가 문서마다 달랐다(V1-05 `tool/emulator/seed.mjs` vs V1-10 `functions/scripts/dev/seed-emulator.js`) | 해소(DEC-10, R2): 정본은 `functions/scripts/dev/seed-emulator.js` + `functions/test/fixtures/emulator-seed.v1.json`(`.no-consent.v1.json`, `.consent-fail.v1.json`), 프로젝트 `demo-dfet`, ID `synthTrainerA`·`synthMember0001`·`SYNTHpending00000001`(V1-10 §5.2). `tool/emulator/seed.mjs`와 옛 ID(`member-synth-…`, `synthMember01`, `synthAdmin01`)는 변경 이력·충돌 기록에만 남는다 |
| K-06 | G-07 IRB(DF-918)가 S21-S22에 있으면 P2 종료(03-26)까지 예비 결과가 나올 수 없다(03 차이 D-3) | 결정: IRB 신청을 S17로 앞당길지 |
| K-07 | `shellcheck`가 스테이징 환경에 없어 `tool/backlog/*.sh`는 `bash -n`과 가짜 gh 시나리오 테스트로만 검증했다 | 작업: DF-002 CI에서 shellcheck 실행 |
| K-08 | 스테이징 편집 단계에서 기술 스파인 경로 `Packages/TrainerKit/...`(순수 타깃)을 V1-04의 두 패키지 구조에 맞춰 `Packages/TrainerCore/...`로 고쳤다(01, 06, 09, 10, P1a, P1b, PR 템플릿). 남은 `TrainerKit` 경로는 iOS 전용 타깃이다 | 완료 |
| K-09 | GitHub의 1주 Iteration 필드는 gh CLI로 만들 수 없다. 스크립트는 텍스트 필드 `Sprint`에 값을 넣는다 | 소유자가 웹에서 Iteration 필드를 만들지 결정 |
| K-10 | P1b DF-209 `DefaultAssessmentLifecycle`(TrainerDomain)이 PostureMath·LocalStore·SyncEngine을 호출해 모듈 경계·순환을 만든다 | 결정: 구현을 SyncEngine으로 옮기고 PostureMath를 TrainerDomain 프로토콜로 주입할지, 스파인에 SyncEngine→PostureMath 의존을 추가할지(S14 전) |
| K-11 | P1b 카드 인용 문구 키 약 77개가 덱에 없다(P1a는 §5.3 표로 정리) | 작업: P1b 다듬기에서 P1a와 같은 방식으로 정리 |
| K-12 | DF-042(시드 스토리) 채택 여부에 따라 `seed-emulator.js`·`firebase.json` auth/functions 항목을 만드는 스토리가 DF-042(S03) 또는 DF-012(S04)로 갈린다 | 해소(DEC-21): DF-042 채택. 시드 스크립트·`firebase.json` auth/functions 항목은 DF-042(S03) |
| K-13 | 대기 회원 입력 구조체 `PendingMemberDraft`의 필드 선택성이 다르다: V1-06 §8(`sex: Sex`, `birthYear: Int` 필수) vs P1a DF-108(`sex: Sex?`, `birthYear: Int?`). SwiftData 엔티티 `LocalPendingMemberDraft`(V1-05 §12)는 일치한다 | 작업: DF-108 착수 전(S07) PRD F-LINK-01 최소 정보 기준으로 한쪽에 맞춘다 |
| K-14 | BodyPath 결과 패키지 UTType 식별자 `com.<소유자 계정명>.bodyscan.result-package`(P2_P3 DF-301·DF-320, ASM-P2P3-03)는 BodyPath 실제 `bundleIdPrefix`에서 왔고 소유자 개인 이름 로마자 표기를 포함한다. 공개 저장소 문서·앱 Info.plist에 그대로 노출된다 | 결정: DF-301(S23-S24) 전에 식별자를 조직 접두(예: `kr.co.dfet`)로 바꿀지. 바꾸면 BodyPath 앱의 export 선언도 같이 바꾼다 |
| K-15 | V1-03 §14.2의 문서 로컬 차이 ID `D-1`~`D-7`이 PRD 결정 ID(D1~D4 등)와 모양이 비슷하다. R10 범위(ASM-NN·C-NN)는 아니어서 두었다 | 작업(낮음): 다음 03 개정 때 `CF-03-NN`으로 바꿀지 |
| K-16 | Flutter 3.47 전환(기술부채). PR #1 CI에서 최신 stable(3.47)로 돌리자 ① `SizeTransition.axisAlignment` deprecation으로 `flutter analyze` 실패(`lib/screens/dashboard/today_signal_screen.dart:426`, 대체값 `alignment: AlignmentDirectional.topStart`) ② 위젯 테스트 다수 실패(`protein_foods_dialog_test`, `clinical_demo_app_test` 등) ③ iOS SPM 기본 활성화로 FlutterFire 플러그인 버전 혼재 충돌(`firebase_auth` 6.1.0 ↔ `firebase_storage` 13.0.4). 그래서 CI·로컬을 3.38.2로 고정하고 iOS는 CocoaPods로 빌드한다. 전환 시 FlutterFire 전체를 같은 릴리스로 올리고(현재 `firebase_core` 4.2.1, 최신 4.15) SPM 설정을 다시 켠다 | 작업: 백로그 기술부채 후보로 소유자가 스토리 채택(2026-09-25 기록) |
| K-17 | 운영 Firebase 상태(2026-09-25 읽기 전용 조회, [G-01 후속 1](evidence/G-01.md#후속-조치)): 코드가 쓰는 Firestore `(default)` 위치가 `nam5`(미국)이고, Firestore·Storage 운영 규칙이 전부 거부다. 미사용 Enterprise DB 2개(`asia-east1`)가 있다 | 결정(DEC-19, 2026-09-25): ① **전제(소유자 확인 필요)**: 운영 `(default)`에는 테스트 데이터만 있다. 소유자는 실사용 여부에 아직 답하지 않았고 Admin SDK 경로는 규칙을 우회하므로, DF-942 942-1에서 소유자가 확인하고 삭제 전 내보내기를 받는다. 테스트 데이터로 분명하지 않은 것이 있으면 삭제하지 않는다. 규칙 첫 배포는 계획대로 G-03 뒤(DF-038 프로브 S03, DF-931 S08) ② 국외이전 고지 대신 서울 리전으로 옮긴다: DF-942(소유자, S01)가 `(default)` 재생성·서울 버킷을, DF-043(S02)이 버킷 명시를 맡는다. Auth·분석 SDK의 국외 처리 고지(G-09, AS-19)는 그대로 필요하다 ③ **남은 소유자 결정**: 미사용 `asia-east1` Enterprise DB 2개의 유지·삭제(비용), 기존 미국 기본 버킷의 테스트 파일 정리. 후속 작업: 운영 DB가 비게 되므로 MIG-02 실사(DF-907, S04)와 MIG-03~07 적용(DF-924, S09)의 운영 대상 범위를 S04 계획 전에 다시 본다 |
| K-18 | DEC-20(AI rebase 병합)이 기존 문구와 다르다: ADR-014 '병합은 스쿼시', `AGENTS.md`·`CLAUDE.md` v1 절('main 직접 푸시·병합·배포' 금지. 병합 담당 AI에게는 01 '병합' 행이 예외), V1-11 스위치 PR `gh pr merge --squash` | 작업: 01(DoD D3·D12, 커밋·PR 규칙, 권한 경계)·02 §2.1·V1-13 §7·SPRINT_01 ASM-S01-07·PR 템플릿(머리말, '병합 전 확인' 절)은 이 PR(2026-09-25)에서 맞췄다. 남은 것: ① `AGENTS.md`·`CLAUDE.md` v1 절의 병합 문구를 '구현 에이전트의 main 직접 푸시·자기 PR 병합 금지, 병합은 01 병합 행'으로 고친다. 에이전트 세션이 읽는 설정 파일이라 **소유자**가 고치고, 목표는 DEC-20 첫 AI 병합 전(S01 월 09-28). 그 전까지 병합 담당 AI는 01 '병합' 행을 정본으로 따른다 ② ADR-014를 대체하는 새 ADR(병합 방식·병합 주체)과 V1-11 `--squash` 정리: 후속 문서 PR(문서 레인 C), 목표 10-02(S01 금) ③ `main` 브랜치 보호의 필수 체크 등록(소유자, 01 필수 체크 활성화 표). 2026-09-25 현재 `main`은 보호되지 않아 DEC-20 조건 ①은 병합 담당 AI가 확인해서만 지켜진다. 소유자는 DEC-20 첫 AI 병합 전에 필수 체크를 등록한다. `.github/CODEOWNERS` 검토도 브랜치 보호가 '코드 소유자 검토 필수'를 요구해야 강제되며, 그 전까지는 부분 동결 파일(`lib/router/app_router.dart`, `lib/services/firestore_service.dart`)과 함께 G-01 수동 확인으로만 지켜진다 |
| K-19 | 2026-09-25 결정 반영 뒤 S02(12/11)와 S03(19/18)이 약속 한도를 1점씩 넘는다(P0 합 85 / 한도 83). [03 §10.1](03_RELEASE_AND_SPRINT_PLAN.md#101-스프린트-버퍼)은 버퍼(10%)를 미리 배정하지 않으므로 이 배치는 §10.1의 **예외**다. S01~S14가 모두 한도까지 차 있어 다른 항목을 밀지 않고는 한도 안에 둘 수 없다 | 결정(소유자 확인 필요, S01 계획 09-28): 예외를 받아들일지. 되돌림 규칙: ① S02: DF-942가 S01(10-02)에 끝나지 않거나 S02 진행이 밀리면 DF-043을 S03 첫날로 옮겨 DF-038과 함께 처리한다(DF-038이 DF-043에 의존) ② S03: 보정 용량이 18 미만이거나 ①로 DF-043이 들어오면 DF-908 발송을 S04~S05(최신 10-30)로 옮긴다. 이때 DF-909는 리전 기록(DF-942 결과 확인)만 S03에 하고, 법률 검토가 필요한 처리방침 확정·게시는 DF-908 회신을 따른다(DF-909→DF-908 의존은 게시 단계에만 적용) DEC-22(2026-09-25) 뒤: DF-908·DF-909가 MVP 밖으로 빠져 S03은 MVP 17 + 진행 중 DF-011 1 = 18(한도 안)이 됐다(되돌림 ② 해당 없음). S02는 12/11 그대로다(MVP 7 + 진행 중 MVP 외 DF-007·DF-010 5). 02 §7.4 |

## 규모 요약

`tool/backlog/issues.json` 합계(채택 항목 기준, 추가 제안 제외)다. 정본은 [02 §7](02_PRODUCT_BACKLOG.md#7-단계마일스톤스프린트-적재-요약)이다.

| 구분 | 건수 | 점수 |
|---|---|---|
| 에픽 | 24 | — |
| 채택 항목 전체 | 193(story 131, chore 18, spike 4, owner-action 40) | 465 |
| P0 | 56 | 107 |
| P1a | 48 | 124 |
| P1b | 27 | 79 |
| P2 | 41 | 116 |
| P3 | 15 | 39 |
| V2(미추정) | 6 | 0 |
| 추가 제안(채택 대기) | 15 | 19 |
| **MVP 범위(`scope/mvp`, DEC-22)** | 67(완료 8, S01 소유자 대기 2, S02~S12 57) | 191(완료 18, 남은 171) |

마일스톤 배정(채택 항목, DEC-22 이전 계획): P0 48건 86점(S01~S05), P1a 56건 145점(S06~S15, P0 키 8건 포함), P1b 27건 79점(S14~S18), P2 41건 116점, P3 15건 39점, V2 6건. 스프린트는 S01~S18이 1주 단위이고 S19 이후는 2~3주 묶음 창(잠정)이다.

## 용어 빠른 참조

정본 용어집은 PRD 부록 B다. 개발 문서에서 자주 쓰는 말만 적는다.

| 용어 | 뜻 | 정본 |
|---|---|---|
| syncState | 로컬 항목의 동기화 상태 5종: localSaved, syncing, synced, syncFailed, awaitingConsent. synced는 서버 확인 뒤에만 | PRD §6.0.3, ADR-002 |
| sourceGrade | 수치의 출처 등급. 없으면 표시하지 않는다 | PRD 부록 A, C-01 |
| pendingPolicy | 승인된 판정 정책이 없어 '산정 준비 중'으로 두는 상태(P3 전 기본) | PRD §7, ADR-009 |
| MemberKey | 회원 키. memberUid 또는 pendingMemberId(로컬 UUID 금지) | ADR-003 |
| 대기 회원 | 앱 가입 전 현장에서 최소 정보로 등록한 회원(pendingMembers) | PRD F-LINK-01 |
| 소비자본(memberSummaries) | 회원이 읽을 수 있는 유일한 공유 문서. 서버가 만든다 | ADR-006 |
| 동의 ①~⑤ | required, healthData, bodyImaging, sharing, research | PRD F-PRIV-01, ADR-011 |
| 게이트(G-NN) | 단계 전환·실데이터·플래그 개방 조건. 코딩은 막지 않는다 | PRD §12.2, [OWNER_ACTIONS_AND_GATES](backlog/OWNER_ACTIONS_AND_GATES.md) |
| owner-action | 소유자만 실행하는 항목(DF-9NN) | [01](01_AGILE_WORKING_AGREEMENT.md#게이트와-소유자-행동의-스프린트-편입) |
| 동결 | Runner 내장 트레이너와 `trainer_ios/`는 규제·크래시 수정만(freeze-exception) | MIG-09, [01 동결 예외 절차](01_AGILE_WORKING_AGREEMENT.md#동결-예외-절차) |
| 합성 데이터 | 가상 회원·가상 사진만 쓰는 개발·테스트 데이터 | ADR-013, [V1-10 §5](10_TEST_PLAN.md#5-테스트-데이터픽스처-정책) |

## 변경 이력

| 버전 | 날짜 | 작성 | 내용 |
|---|---|---|---|
| v1.0 | 2026-09-24 | CJH(AI 에이전트 초안, 릴리스 편집) | 최초 작성. 문서 지도, 읽기 순서, S01 체크리스트, 결정 기록, 이식 기준선 자리, AS-DEV-01~13, Q-DEV 색인, 알려진 차이 K-01~K-09. 같은 편집에서 OWNER_ACTIONS_AND_GATES(V1-02-OA), 13 플레이북(V1-13), CODEOWNERS(GH-09), 백로그 도구(TL-01~05, TL-11·12·14)를 추가하고 문서 참조를 단일 `issues.json`·`create_github_issues.sh`·`TrainerCore` 경로에 맞춤 |
| v1.0.1(정합 패스 2) | 2026-09-24 | CJH(AI 에이전트, 정합 편집) | 교차 정합성 조정. 소유자 결정(DEC-01~05) 반영, DEC-10~18(R2~R10) 기록, DEC-08 확정(R1), K-01·K-02·K-05 해소, K-10~K-12 추가, AS-DEV-03 확인, 가정·충돌 ID 네임스페이스 규칙 |
| v1.0.2 | 2026-09-25 | CJH(AI 에이전트, MIG-01 실행) | 이식 기준선 tip 해시 기입, 공개 범위 결정(DEC-09: 공개 유지, PRD·문서 공개, 보관 브랜치 비푸시) 반영은 [G-01 증빙](evidence/G-01.md) |
| v1.0.1 | 2026-09-24 | CJH(AI 에이전트, 릴리스 검증) | 릴리스 검증 패스: `issues.json` 재생성·검증기·가짜 gh 테스트 통과, 헤더·링크·스테일 패턴·스토리 정합·용량·개인정보 점검. K-01·K-02·K-05 해소 내용 구체화, K-13~K-15 추가, '저장소 공개 상태 주의' 절 추가. 기계적 수정: S19-S20 작업일 8일·용량 32 반영(01·02·03), 순수 타깃 경로 TrainerCore(12, P1a DF-126), 합성 ID(08, 09, P2_P3), 픽스처 복사 문구(SPRINT_01), TodayListEntry 필드(P1a DF-125), bare ASM 참조(09 ASM-111→ASM-P1a-11, 12·analytics_events.json ASM-140→ASM-P1a-40, build_issues.mjs ASM-17→ASM-01-17), 07 로컬 절대 경로 제거 |
| v1.1 | 2026-09-25 | CJH(AI 에이전트, 소유자 결정 기록) | 소유자 결정 2026-09-25 기록: DEC-19(운영 데이터 리전 서울 `asia-northeast3`, K-17 해소, DF-942·DF-043 추가), DEC-20(스프린트 PR은 CI 초록 + 적대적 리뷰 승인 시 AI가 rebase 병합. 소유자 확인 필요, 이 PR을 소유자가 병합하면 발효), DEC-19의 서울 지정·테스트 데이터 전제는 942-1 소유자 확인, DF-908 법률 의뢰 보류(S03 발송 계획, 최신 10-30), DF-930 동결 선언 기록. S01 체크리스트, Q-24·Q-DEV-04-01, 규모 요약(192건·464점) 갱신, K-18(병합 문구 차이·후속 담당과 기한) 추가, K-19(S02·S03 약속 한도 +1 예외와 되돌림 규칙) 추가 |
| v1.2 | 2026-09-25 | CJH(AI 에이전트, 작업 지시의 결정 기록) | DEC-21(AI 결정: DF-009 Claude, DF-042 채택·나머지 제안 MVP 뒤, PRD §13.3 기본값 문서화와 외부 판단 미결 유지, Q-08 해소)과 DEC-22(1인 알파 MVP 범위, `scope/mvp` 65건·185점, 연기 목록) 추가. 둘 다 소유자 확인 필요(PR #113 소유자 병합). DEC-20은 소유자 문장이 아니라서 '소유자 확인 필요' 유지. '소유자 대기 목록' 절(DF-942 내보내기 먼저, DF-903, DF-905·DF-906·DF-931·DF-925·DF-929 MVP 범위). K-03·K-12 해소, K-04 해결(brief.mjs), K-19 DEC-22 뒤 적재, 규모 요약·TL-02 갱신. 리뷰 반영: DEC-22에 테스트 회원 데이터 정의(합성·공개 샘플 또는 소유자 본인, 제3자 없음), 소유자 대기 7번(DF-905) 실행 절차를 스크립트에 맞춤(`npm ci`, 키 위치 `functions/service-account-key.json`, 실행 후 키 삭제·폐기), TL-02 라벨 70개 리뷰 반영 2: 소유자 대기 목록 12(DF-931 MVP 재배포), 버킷 이름은 비밀이 아니라 코드 상수·예시 파일에 적는다, DEC-22 연기 목록의 Runner 문구 항목(DF-028·029·040·041, DF-910·911은 G-05), DEC-19 트레이너 앱 버킷 DF-104. |
| v1.3 | 2026-09-25 | CJH(소유자 확정, 메인 세션 편집) | 소유자가 대화에서 DEC-20~22 확정과 PR #113 병합을 직접 선택. DEC-19~22와 Q-09·Q-10 상태를 '결정/소유자 확정'으로 변경 |
| v1.2.1 | 2026-09-25 | CJH(AI 에이전트, 리뷰 반영) | MVP 합계 정정: DEC-22 행 안의 건수와 규모 요약 MVP 행을 67건·191점(완료 8건·18점, S01 소유자 대기 2, S02~S12 57건, 남은 171점)으로 맞춤(02 §7.4, 03 MVP 계획, `issues.json` `totals.byScope`와 같다). DEC 행의 상태 칸은 바꾸지 않음 |
| v1.3.1 | 2026-09-26 | CJH(AI 에이전트, DF-039) | 이식 기준선 절에 보관 브랜치 기록일과 DF-039 확인 행(tip `82c6ee9`, AppDelegate 9,657줄, 확인 일자 2026-09-26, V1-07 §7.1·§7.4와 V1-13 §6.1 링크) 추가 |
