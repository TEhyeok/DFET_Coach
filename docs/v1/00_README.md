# D-FET Coach v1 개발 문서 안내

| 항목 | 내용 |
|---|---|
| 문서 ID | V1-00 |
| 버전 | v1.0.2 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | [PRD_V1](../PRD_V1.md) 전체. 특히 §0.3 문서 관계, §0.5 ID 체계, §12 단계·게이트, §13 열린 질문·가정 |
| 관련 에픽·스토리 | EP-00~EP-23 / DF-001(문서 병합), DF-002·DF-902(백로그 생성), DF-901(이식 기준선), DF-913(Q-09 결정) |
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
| V1-02-P0 | [backlog/P0.md](backlog/P0.md) | P0 정리·기반 스토리 카드(DF-001~042) | 4,271 |
| V1-02-P1a | [backlog/P1a.md](backlog/P1a.md) | P1a 알파-기록 카드(DF-100~144) | 3,042 |
| V1-02-P1b | [backlog/P1b.md](backlog/P1b.md) | P1b 알파-평가 카드(DF-200~227) | 2,014 |
| V1-02-P2P3 | [backlog/P2_P3.md](backlog/P2_P3.md) | P2 베타·P3 센터 출시 카드(DF-300~391) | 3,068 |
| V1-02-V2 | [backlog/V2.md](backlog/V2.md) | V2 보류 항목과 재검토 조건(DF-500~508) | 452 |
| V1-02-OA | [backlog/OWNER_ACTIONS_AND_GATES.md](backlog/OWNER_ACTIONS_AND_GATES.md) | 소유자 행동·외부 게이트 카드(DF-901~941), 게이트 카탈로그 | 1,162 |
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
| TL-02 | `tool/backlog/labels.json` | 라벨 67개 |
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
- [ ] 도구 설치 확인: Xcode 16.x, XcodeGen 2.44.1(릴리스 zip, SHA-256 확인. brew 금지), Node 22, Java 21, Flutter stable, firebase-tools, jq, gh([V1-13 §2](13_DEV_ENVIRONMENT_AND_AGENT_PLAYBOOK.md#2-도구와-버전)).
- [ ] `gh auth refresh -s project,read:project`로 보드 권한을 준비한다(DF-902용).
- [ ] 스테이징 문서군을 저장소로 옮길 준비: DF-001 브랜치에서 `devdocs/`를 저장소 루트 기준 같은 경로로 복사한다(`docs/v1/**`, `.github/**`, `tool/backlog/**`).

### 1일차(09-28 월)

- [ ] 09:30 스프린트 계획 45분: [SPRINT_01 §4](sprints/SPRINT_01.md#4-약속-항목) 약속 18점 확정, 레인 A(Codex: DF-003→DF-004)·B(Claude: DF-008)·C(Claude: DF-001→DF-002→DF-005) 확인.
- [ ] DF-901 MIG-01 착수: 작업 트리 보존 → A·B·C 분류 → A 커밋 → B 보관 브랜치와 tip 해시 기록([V1-11 §3](11_MIGRATION_RUNBOOK.md#3-mig-01-미커밋-정리)). 자격증명 미스테이징을 커밋마다 확인한다.
- [ ] 오후: 레인 A·B·C 작업 지시서([SPRINT_01 §8](sprints/SPRINT_01.md#8-먼저-실행할-에이전트-작업-지시서))로 에이전트 브랜치를 연다. DF-901 병합 전에는 새 경로 착수만 하고 병합하지 않는다.

### 주중

- [ ] 화: DF-901 PR·CI 4 job·병합, main 보호 규칙. DF-001·DF-003 병합. DF-908 법률 의뢰서 초안.
- [ ] 수: DF-903 Firebase 앱 등록·App Attest, DF-904 Q-22 확인, DF-930 동결 선언, 16:00 게이트 점검.
- [ ] 목: DF-002·DF-004 병합, DF-913 Q-09 결정(이 문서 [결정 기록](#결정-기록)에 기록).
- [ ] 금: DF-008·DF-005 병합, DF-908 발송(최신 10-08), DF-902 백로그 생성([TL-01 §3](../../tool/backlog/README.md#3-소유자-실행-순서)), 필수 체크 추가, 15:00 데모·15:20 회고.

### S01 완료 기준(요지)

G-01 증빙, contracts `--check` 초록, trainer-app 워크플로 초록, SOAP 픽스처, docs/v1 병합과 헤더 린트, 백로그 생성, 소유자 행동 5건 기록([SPRINT_01 §2](sprints/SPRINT_01.md#2-스프린트-목표와-성공-기준)).

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
| Q-09 | 2026 과업지시서와의 관계 | 미결(DF-913, S01 목). 결정 전 기본값: 자체 제품 로드맵, 과업 산출물 양식 미적용 | — | PRD §13.3. PRD 반영은 소유자가 직접 |
| Q-10 | 트레이너 앱 디자인 토큰 | 미결(DF-914, S06). 기본값: 중립 회색 + 브랜드 블루, 초록은 저장·완료 상태 전용 | — | PRD §8.5 |
| Q-22 | 트레이너 앱 번들의 iPhone 배포 이력 | 미결(DF-904, S01 수). 기본값: iPad 전용(`TARGETED_DEVICE_FAMILY "2"`) | — | ADR-001, 03 T-07 |
| Q-24 | 코칭 기록 최대 보유기간 N | 미결(DF-908 법률 자문). 결정 없이는 G-04 미통과 | — | PRD Q-24, DF-133은 N 미설정 시 파기 분기 비활성 |

## 이식 기준선

DF-901(MIG-01)에서 채운다. 이식 스토리(DF-039 등)는 이 해시의 작업 트리를 원본으로 삼는다.

| 항목 | 값 | 기록일 |
|---|---|---|
| 보관 브랜치 | `archive/trainer-ui-2026-09` | — |
| tip 커밋 해시 | `82c6ee9b4c95e9622fc1c44111ddc20ee9f68941`(로컬 전용, 공개 저장소라 원격에 푸시하지 않음) | 2026-09-25 |
| main 병합 커밋(A분류) | 기준 브랜치 `chore/DF-901-mig01-baseline` PR 병합 뒤 기입(rebase 병합이라 해시가 바뀐다) | — |
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
| Q-DEV-04-01·02 | 트리거 리전, 공용 iPad 다중 트레이너 | 04 표 참조 | Q-08·G-09 | [04](04_ARCHITECTURE.md) |
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
| K-03 | 추가 제안 16건(20점, DF-041·042·143·144·227·333·335~338·391·506~508·940·941)은 채택 대기다. 이슈 데이터에는 `status/needs-decision`으로 들어 있고 합계에서 뺐다 | 결정 시점: DF-041·042는 S03 계획(10-12), 나머지는 02 §8.8.1 표 |
| K-04 | 작업 지시서 생성기 `tool/backlog/brief.mjs`(01 ASM-01-17, TL-13 후보)는 아직 없다. S01 지시서는 SPRINT_01 §8에 손으로 조립돼 있다 | 작업: DF-002 범위(01 ASM-01-17) |
| K-05 | 에뮬레이터 시드 스크립트 경로와 합성 ID 체계가 문서마다 달랐다(V1-05 `tool/emulator/seed.mjs` vs V1-10 `functions/scripts/dev/seed-emulator.js`) | 해소(DEC-10, R2): 정본은 `functions/scripts/dev/seed-emulator.js` + `functions/test/fixtures/emulator-seed.v1.json`(`.no-consent.v1.json`, `.consent-fail.v1.json`), 프로젝트 `demo-dfet`, ID `synthTrainerA`·`synthMember0001`·`SYNTHpending00000001`(V1-10 §5.2). `tool/emulator/seed.mjs`와 옛 ID(`member-synth-…`, `synthMember01`, `synthAdmin01`)는 변경 이력·충돌 기록에만 남는다 |
| K-06 | G-07 IRB(DF-918)가 S21-S22에 있으면 P2 종료(03-26)까지 예비 결과가 나올 수 없다(03 차이 D-3) | 결정: IRB 신청을 S17로 앞당길지 |
| K-07 | `shellcheck`가 스테이징 환경에 없어 `tool/backlog/*.sh`는 `bash -n`과 가짜 gh 시나리오 테스트로만 검증했다 | 작업: DF-002 CI에서 shellcheck 실행 |
| K-08 | 스테이징 편집 단계에서 기술 스파인 경로 `Packages/TrainerKit/...`(순수 타깃)을 V1-04의 두 패키지 구조에 맞춰 `Packages/TrainerCore/...`로 고쳤다(01, 06, 09, 10, P1a, P1b, PR 템플릿). 남은 `TrainerKit` 경로는 iOS 전용 타깃이다 | 완료 |
| K-09 | GitHub의 1주 Iteration 필드는 gh CLI로 만들 수 없다. 스크립트는 텍스트 필드 `Sprint`에 값을 넣는다 | 소유자가 웹에서 Iteration 필드를 만들지 결정 |
| K-10 | P1b DF-209 `DefaultAssessmentLifecycle`(TrainerDomain)이 PostureMath·LocalStore·SyncEngine을 호출해 모듈 경계·순환을 만든다 | 결정: 구현을 SyncEngine으로 옮기고 PostureMath를 TrainerDomain 프로토콜로 주입할지, 스파인에 SyncEngine→PostureMath 의존을 추가할지(S14 전) |
| K-11 | P1b 카드 인용 문구 키 약 77개가 덱에 없다(P1a는 §5.3 표로 정리) | 작업: P1b 다듬기에서 P1a와 같은 방식으로 정리 |
| K-12 | DF-042(시드 스토리) 채택 여부에 따라 `seed-emulator.js`·`firebase.json` auth/functions 항목을 만드는 스토리가 DF-042(S03) 또는 DF-012(S04)로 갈린다 | 결정: S03 계획(10-12) |
| K-13 | 대기 회원 입력 구조체 `PendingMemberDraft`의 필드 선택성이 다르다: V1-06 §8(`sex: Sex`, `birthYear: Int` 필수) vs P1a DF-108(`sex: Sex?`, `birthYear: Int?`). SwiftData 엔티티 `LocalPendingMemberDraft`(V1-05 §12)는 일치한다 | 작업: DF-108 착수 전(S07) PRD F-LINK-01 최소 정보 기준으로 한쪽에 맞춘다 |
| K-14 | BodyPath 결과 패키지 UTType 식별자 `com.<소유자 계정명>.bodyscan.result-package`(P2_P3 DF-301·DF-320, ASM-P2P3-03)는 BodyPath 실제 `bundleIdPrefix`에서 왔고 소유자 개인 이름 로마자 표기를 포함한다. 공개 저장소 문서·앱 Info.plist에 그대로 노출된다 | 결정: DF-301(S23-S24) 전에 식별자를 조직 접두(예: `kr.co.dfet`)로 바꿀지. 바꾸면 BodyPath 앱의 export 선언도 같이 바꾼다 |
| K-15 | V1-03 §14.2의 문서 로컬 차이 ID `D-1`~`D-7`이 PRD 결정 ID(D1~D4 등)와 모양이 비슷하다. R10 범위(ASM-NN·C-NN)는 아니어서 두었다 | 작업(낮음): 다음 03 개정 때 `CF-03-NN`으로 바꿀지 |

## 규모 요약

`tool/backlog/issues.json` 합계(채택 항목 기준, 추가 제안 제외)다. 정본은 [02 §7](02_PRODUCT_BACKLOG.md#7-단계마일스톤스프린트-적재-요약)이다.

| 구분 | 건수 | 점수 |
|---|---|---|
| 에픽 | 24 | — |
| 채택 항목 전체 | 190(story 131, chore 16, spike 4, owner-action 39) | 462 |
| P0 | 53 | 104 |
| P1a | 48 | 124 |
| P1b | 27 | 79 |
| P2 | 41 | 116 |
| P3 | 15 | 39 |
| V2(미추정) | 6 | 0 |
| 추가 제안(채택 대기) | 16 | 20 |

마일스톤 배정(채택 항목): P0 45건 83점(S01~S05), P1a 56건 145점(S06~S15, P0 키 8건 포함), P1b 27건 79점(S14~S18), P2 41건 116점, P3 15건 39점, V2 6건. 스프린트는 S01~S18이 1주 단위이고 S19 이후는 2~3주 묶음 창(잠정)이다.

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
