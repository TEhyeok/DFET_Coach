# 스프린트 01 (2026-09-28 ~ 10-02)

| 항목 | 값 |
|---|---|
| 문서 ID | V1-03-S01 |
| 버전 | v1.0.1 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | §11.2(MIG-01), §9.3, 부록 A·B, §10.2.1, §12.1 P0, §12.2(G-01·G-02·G-04), §13.3(Q-09, Q-22, Q-24) |
| 관련 에픽·스토리 | EP-00(DF-901, DF-902, DF-903, DF-904, DF-908, DF-913, DF-930), EP-01(DF-001, DF-002), EP-02(DF-003, DF-004, DF-005), EP-05(DF-008) |
| 변경 규칙 | [문서 변경](../01_AGILE_WORKING_AGREEMENT.md#문서-변경) |

## 목차

1. [기간·휴일·의식](#1-기간휴일의식)
2. [스프린트 목표와 성공 기준](#2-스프린트-목표와-성공-기준)
3. [용량](#3-용량)
4. [약속 항목](#4-약속-항목)
5. [레인 배정과 경로 소유](#5-레인-배정과-경로-소유)
6. [일자별 계획](#6-일자별-계획)
7. [작업 분해](#7-작업-분해)
8. [먼저 실행할 에이전트 작업 지시서](#8-먼저-실행할-에이전트-작업-지시서)
9. [이번 주 소유자 행동](#9-이번-주-소유자-행동)
10. [DoD 점검](#10-dod-점검)
11. [금요일 데모 스크립트](#11-금요일-데모-스크립트)
12. [위험과 대응](#12-위험과-대응)
13. [가정(ASM)](#13-가정asm)
14. [회고 질문과 다음 스프린트 준비](#14-회고-질문과-다음-스프린트-준비)
15. [변경 이력](#15-변경-이력)

---

## 1. 기간·휴일·의식

- 기간: 2026-09-28(월) ~ 10-02(금), 작업일 5일. 추석 연휴(09-24~26) 직후라 스프린트 0은 없다.
- 다음 스프린트 S02의 첫 작업일은 **10-06(화)**다(10-05 개천절 대체공휴일, 10-09 한글날). S02 계획 회의는 10-06 오전으로 옮긴다.
- 형식은 [스프린트 계획 템플릿](../templates/SPRINT_PLAN.md)(V1-T04)을 따르고, 전체 달력과 버퍼 정책은 [03_RELEASE_AND_SPRINT_PLAN](../03_RELEASE_AND_SPRINT_PLAN.md)을 따른다.

| 의식 | 일시 | 시간 | 산출물 |
|---|---|---|---|
| 계획 | 09-28(월) 09:30 | 45분 | 이 문서 확정, 레인 배정 확인. DF-901 착수 직전에 한다 |
| 일일 기록 | 매일 18:00 | 비동기 | 각 스토리 이슈(또는 DF-902 전에는 PR) 코멘트: 한 일·막힘·다음 |
| 게이트 점검 | 09-30(수) 16:00 | 15분 | G-01·G-02·Q-22·G-04 의뢰서 상태, [03 §5.2](../03_RELEASE_AND_SPRINT_PLAN.md#5-게이트-타임라인과-소유자-병렬-트랙) 표 갱신 |
| 리뷰·데모 | 10-02(금) 15:00 | 20분 | §11 스크립트 수행 기록 |
| 회고 | 10-02(금) 15:20 | 10분 | [V1-T11](../templates/RETRO.md) 기록 |

## 2. 스프린트 목표와 성공 기준

**목표:** 기준선(G-01)을 확정하고, 계약 단일 원본·생성기·SOAP 픽스처·trainer_app 골격을 CI에서 초록으로 만든다.

| # | 성공 기준 | 확인 방법 |
|---|---|---|
| 1 | G-01 증빙 완료: A 분류가 main에 병합되고 기존 CI 4개 job(flutter, functions-and-rules, admin-web, ios-no-codesign)이 초록이다. 보관 브랜치 `archive/trainer-ui-2026-09`의 tip 해시가 기록됐다 | `docs/v1/evidence/G-01.md`, GitHub Actions |
| 2 | `node tool/contracts/generate.mjs --check`가 CI `contracts` job에서 통과한다 | ci.yml `contracts` job |
| 3 | `trainer-app` 워크플로가 초록이다: 재생성 diff 0, macOS `swift test --package-path trainer_app/Packages/TrainerCore`, iPad 시뮬레이터 빌드·UI 스모크, plist 없는 Release no-codesign 빌드. 경로에 해당하지 않는 PR에서는 '건너뜀 = 통과'로 보고된다 | `.github/workflows/trainer-app.yml` |
| 4 | SOAP 픽스처(v2 5개, 레거시 6개, [P0 픽스처 규약](../backlog/P0.md#fixture-contract))가 `contracts/fixtures/`에 있고 픽스처 테스트가 통과한다 | `node --test tool/contracts/test/` |
| 5 | `docs/v1/**`가 main에 있고 헤더 린트가 통과한다. 백로그 dry-run이 통과하고, 소유자가 라벨·마일스톤·Projects를 만들었다 | ci.yml `docs-and-backlog` job, `gh label list` |
| 6 | 소유자 행동: Firebase 앱 등록(DF-903), Q-22 확인(DF-904), 법률 자문 의뢰 발송(DF-908), Q-09 결정(DF-913), Runner 동결 선언(DF-930) | 각 증빙 문서 |

## 3. 용량

| 항목 | 값 | 근거 |
|---|---|---|
| 작업일 | 5 | 09-28 ~ 10-02 |
| 용량 | 20점 | AS-DEV-09 |
| 약속 한도 | 18점(90%) | [03 §3.2](../03_RELEASE_AND_SPRINT_PLAN.md#3-달력-휴일과-스프린트-용량) |
| 약속 | **18점** = 개발 15 + 소유자 행동 3 | §4. owner-action 점수는 약속과 속도에 포함(ASM-S01-13) |
| 버퍼 | 2점 | 쓰는 순서는 03 §10.1 |
| 소유자 실제 시간 예상 | DF-901 약 1.5일(ASM-S01-01), PR 검토 약 7.5시간(개발 15점 × 30분), 법률 의뢰서 반나절, 콘솔·ASC 1.5시간 | 5작업일 안에 들어간다 |
| 동시 에이전트 브랜치 | 최대 3개 | [01 에이전트 규약](../01_AGILE_WORKING_AGREEMENT.md) |

## 4. 약속 항목

| DF | 제목(요지) | 점수 | 유형 | 레인·담당 | 주 경로 | 의존 | 우선순위 |
|---|---|---|---|---|---|---|---|
| DF-901 | MIG-01: 미커밋 87개 A·B·C 분류, A를 main에 병합, B 보관(G-01) | 1 | owner-action | 소유자 | 저장소 전체(분류), `docs/v1/evidence/G-01.md` | — | must |
| DF-003 | metric-catalog.v1.json·vocab.v1.json 작성(부록 A·B) | 2 | story | A · codex | `contracts/*.v1.json`, `contracts/README.md` | DF-901 | must |
| DF-004 | contracts 생성기와 `--check` CI(Swift·Dart·Functions·admin_web) | 3 | story | A · codex | `tool/contracts/**`, `tool/package.json`·`tool/package-lock.json`(이 스토리가 만든다), `schemas/contracts-meta.schema.json`, 생성물 4곳, `.github/workflows/ci.yml`(`contracts` job, 순서 차례 2번) | DF-003 | must |
| DF-008 | trainer_app 골격(XcodeGen, TrainerCore·TrainerKit, App Check)과 trainer-app CI | 5 | story | B · claude | `trainer_app/**`, `.github/workflows/trainer-app.yml`, `.github/workflows/ci.yml`(`ios-no-codesign`에 NFR-01 grep step 1개, 순서 차례 3번) | DF-901 | must |
| DF-001 | docs/v1 병합, AGENTS.md·CLAUDE.md에 v1 절 링크 | 1 | chore | C · claude | `docs/v1/**`, `.github/ISSUE_TEMPLATE/**`, `.github/pull_request_template.md`, `.github/CODEOWNERS`, `tool/lint/doc-headers.mjs`, `tool/lint/test/**`, `.github/workflows/ci.yml`(`changes-ci`·`docs-and-backlog` job, 순서 차례 1번), `AGENTS.md`, `CLAUDE.md` | DF-901 | must |
| DF-002 | 백로그 도구 dry-run 검증 | 2 | chore | C · claude | `tool/backlog/**`(ci.yml은 고치지 않는다. DF-001이 조건부 단계를 미리 넣는다) | DF-901 | must |
| DF-005 | SOAP v2·레거시 교차 픽스처 | 2 | story | C · claude | `contracts/fixtures/**`, `tool/contracts/test/fixtures.test.mjs` | DF-003 | must |
| DF-903 | kr.co.dfet.trainer Firebase 등록, plist, App Attest(G-02) | 1 | owner-action | 소유자 | 콘솔, `docs/v1/evidence/G-02.md` | — | must |
| DF-908 | 법률 자문 의뢰(G-04: Q-04, Q-05, Q-07, Q-21, Q-24) | 1 | owner-action | 소유자 | `docs/v1/evidence/G-04.md` | — | must |
| DF-904 | App Store Connect 레코드·iPhone 배포 이력 확인(Q-22) | 0 | owner-action | 소유자 | `docs/v1/evidence/G-02.md` | — | must |
| DF-913 | Q-09(2026 과업지시서와의 관계) 결정 | 0 | owner-action | 소유자 | [00_README](../00_README.md) 결정 기록 | — | must |
| DF-930 | Runner 내장 트레이너 동결 선언 | 0 | owner-action | 소유자 | `docs/v1/evidence/G-01.md` '동결 선언' 절, `freeze-exception` 라벨. CODEOWNERS 반영은 DF-001 병합 뒤 확인만 한다 | — | must |
| DF-902 | 라벨·마일스톤·Projects·이슈 생성 스크립트 실행 | 0 | owner-action | 소유자 | GitHub 설정 | DF-002 | must |
| **합계** | | **18** | | | | | |

- 의존 열은 [02 색인](../02_PRODUCT_BACKLOG.md)·P0 카드의 `Depends on`과 같다. 같은 레인 안의 **작업 순서**(DF-001 → DF-002 → DF-005, DF-003 → DF-004)는 의존이 아니라 §5의 배정 순서다.

당김 후보(버퍼가 남을 때만, 목요일 오전까지 판단): 없음. DF-010(3점)은 버퍼(2점)를 넘으므로 S02에 그대로 둔다([03 §14.2 D-2](../03_RELEASE_AND_SPRINT_PLAN.md#14-가정asm과-스파인prd와의-차이)).

## 5. 레인 배정과 경로 소유

동시 에이전트 브랜치는 3개다. 경로가 겹치지 않도록 레인마다 쓰기 가능한 경로를 고정한다.

| 레인 | 에이전트 | 순서 | 브랜치 | 쓰기 허용 경로 | 쓰기 금지 경로 |
|---|---|---|---|---|---|
| A | Codex | DF-003 → DF-004 | `codex/DF-003-metric-catalog-vocab`, `codex/DF-004-contracts-generator` | `contracts/*.v1.json`, `contracts/README.md`, `tool/contracts/**`(단 `tool/contracts/test/fixtures.test.mjs` 제외), `tool/package.json`, `tool/package-lock.json`, `schemas/contracts-meta.schema.json`, `trainer_app/Packages/TrainerCore/Sources/TrainerContracts/Generated/**`, `lib/contracts/generated/**`, `functions/src/shared/generated/**`, `admin_web/lib/generated/**`, `.github/workflows/ci.yml`(`contracts` job 추가만, 순서 차례 2번) | `trainer_app/`의 그 밖의 경로, `contracts/fixtures/**`, `docs/**` |
| B | Claude | DF-008 | `claude/DF-008-trainer-app-skeleton` | `trainer_app/**`(단, `trainer_app/Packages/TrainerCore/Sources/TrainerContracts/Generated/**` 제외), `.github/workflows/trainer-app.yml`, `.github/workflows/ci.yml`(`ios-no-codesign` job에 NFR-01 grep step 1개만, 순서 차례 3번) | `trainer_ios/**`(읽기만), `ios/**`(grep으로 읽기만), `contracts/**` |
| C | Claude | DF-001 → DF-002 → DF-005 | `docs/DF-001-v1-docs`, `claude/DF-002-backlog-tooling`, `claude/DF-005-soap-fixtures` | `docs/v1/**`, `.github/ISSUE_TEMPLATE/**`, `.github/pull_request_template.md`, `.github/CODEOWNERS`, `.github/workflows/ci.yml`(DF-001의 `changes-ci`·`docs-and-backlog` job만, 순서 차례 1번), `tool/lint/**`, `tool/backlog/**`, `AGENTS.md`, `CLAUDE.md`(v1 절 추가만), `contracts/fixtures/**`, `tool/contracts/test/fixtures.test.mjs` | `docs/PRD_V1.md`, `contracts/*.v1.json`, `tool/package.json` |

병합 순서 규칙:
- DF-901(소유자)이 main에 병합되기 전에는 에이전트 PR을 병합하지 않는다. 새 경로(`contracts/`, `trainer_app/`, `tool/contracts/`, `docs/v1/`)만 건드리는 작업은 **착수만** 먼저 할 수 있다(ASM-S01-01).
- `tool/package.json`(`ajv`, `ajv-formats`)은 DF-004가 만든다(P0 DF-004 카드). `tool/lint/doc-headers.mjs`와 `tool/backlog/validate_backlog.mjs`는 Node 내장 모듈만 써서 이 파일이 필요 없다(ASM-S01-03). 그래서 DF-001·DF-002는 `tool/package.json`을 기다리지 않는다.
- **`.github/workflows/ci.yml` 순서 차례**: 세 레인이 서로 다른 job·step을 더하지만 한 파일이므로 동시에 고치지 않는다. 차례는 ① DF-001(`changes-ci`·`docs-and-backlog` job, 화 오전 병합) → ② DF-004(`contracts` job, 목 병합) → ③ DF-008(`ios-no-codesign`에 NFR-01 grep step 1개, 금 병합)이다. 각 스토리는 앞 차례가 main에 병합된 뒤 rebase하고, `ci.yml` 변경을 **PR의 마지막 커밋**으로 넣는다. 그 전 커밋에는 `ci.yml`이 없어야 한다. DF-002는 `ci.yml`을 고치지 않는다(DF-001이 조건부 단계를 미리 넣는다, §7.5).
- 필수 체크가 될 job(`docs-and-backlog`, `contracts`, `trainer-app`)은 워크플로 수준 `paths` 필터를 쓰지 않는다. 경로 조건은 `changes-*` job 출력과 job 수준 `if`로 건다(ASM-S01-05).
- DF-004와 DF-008은 순서와 무관하게 병합할 수 있어야 한다. DF-008은 `trainer_app/Packages/TrainerCore/Sources/TrainerContracts/TrainerContracts.swift`(비생성) 자리 표시만 두고, DF-004는 `Generated/` 아래에만 쓴다.
- `tool/contracts/test/`는 DF-004(레인 A)가 만들고, DF-005(레인 C)는 DF-004 병합 뒤 `fixtures.test.mjs` 한 파일만 더한다.

## 6. 일자별 계획

| 일자 | 오전 | 오후 | 그날 병합 목표 |
|---|---|---|---|
| 09-28(월) | 계획 회의. DF-901 보존·분류(901-1~901-3) | DF-901 A 커밋·B 보관(901-4, 901-5). 에이전트 레인 A·B·C 착수: DF-003, DF-008(008-1 TrainerCore 패키지부터), DF-001 | — |
| 09-29(화) | DF-901 PR·CI·병합(901-6), 브랜치 보호(901-7). DF-001·DF-003 PR 검토 | DF-001 병합(ci.yml 차례 1번) → DF-003 병합. 레인 A는 DF-004, 레인 C는 DF-002 착수. 소유자: DF-908 의뢰서 초안(908-1) | DF-901, DF-001, DF-003 |
| 09-30(수) | 소유자: DF-903 콘솔 등록(903-1~903-3), DF-904 ASC 확인 | DF-930 동결 선언. 게이트 점검 16:00. DF-008 중간 검토(Package.swift·project.yml) | — |
| 10-01(목) | DF-002 PR 검토·병합. DF-004 PR 검토 | DF-004 병합(ci.yml 차례 2번). 레인 B는 rebase 뒤 ci.yml grep step을 마지막 커밋으로 추가(008-8). 레인 C는 DF-005 착수. DF-008 PR 검토. 소유자: DF-913 결정 | DF-002, DF-004 |
| 10-02(금) | DF-008 병합(ci.yml 차례 3번), DF-005 PR 검토·병합. DF-902 실행. DF-908 의뢰서 발송 | 15:00 데모, 15:20 회고. main 필수 체크에 `contracts`·`trainer-app`·`docs-and-backlog` 추가(902-2 사전 확인 뒤) | DF-008, DF-005 |

## 7. 작업 분해

- 작업 ID는 `<DF 번호>-<순번>`이다. 모든 작업은 반나절(0.5일) 이하로 잘랐다.
- 명령은 저장소 루트(`dfet_coach/dfet_coach`, `pubspec.yaml`이 있는 폴더)에서 실행한다.
- 코드·설정 예시는 착수 기준 초안이다. 필드 정본은 [05_DATA_MODEL_AND_RULES](../05_DATA_MODEL_AND_RULES.md)(contracts JSON 스키마), [04_ARCHITECTURE](../04_ARCHITECTURE.md)(저장소 배치), [ADR-001](../adr/ADR-001-independent-trainer-app.md), [ADR-005](../adr/ADR-005-soap-schema-v2-contracts.md)이며, 다르면 그 문서를 따른다.

### 7.1 DF-901 MIG-01 기준선 정리(소유자, 1점)

근거: PRD §11.2 체크리스트 #1~#7, [11_MIGRATION_RUNBOOK](../11_MIGRATION_RUNBOOK.md) MIG-01. 이 작업은 AI 에이전트에게 맡기지 않는다. `output/`, `tmp/`, 비밀 파일은 소유자만 다루고 내용을 어떤 문서에도 옮기지 않는다.

| 작업 | 시간 | 내용 | 파일·명령 | 완료 조건 |
|---|---|---|---|---|
| 901-1 | 월 오전 1h | 정리 전 작업 트리 보존(#1). 저장소 밖 폴더에 둔다 | `mkdir -p ../mig01 && git status --short > ../mig01/status-2026-09-28.txt && git diff --binary HEAD > ../mig01/tracked-2026-09-28.patch && git ls-files --others --exclude-standard > ../mig01/untracked-2026-09-28.txt` | 세 파일 존재, `git apply --check ../mig01/tracked-2026-09-28.patch`가 깨끗한 HEAD 사본에서 통과 |
| 901-2 | 월 오전 2h | 파일마다 A·B·C 분류표 작성(#2). 기준은 PRD §11.2 분류표. 혼재 파일 3개는 hunk 분리 대상으로 표시(#3): `firestore.rules`(posts 강화 대 trainerWorkspaces 블록), `functions/test/firestore-rules.test.js`(커뮤니티 대 작업공간), `lib/services/firestore_service.dart`(hydration 대 trainerWorkspaces) | `docs/v1/evidence/G-01.md`([V1-T07](../templates/GATE_EVIDENCE.md) 형식)에 `경로 / 분류 / 커밋 주제 / 비고` 표 | 88줄(`git status --short` 기준, 미추적 `docs/PRD_V1.md` 포함) 모두 분류됨 |
| 901-3 | 월 오전 30m | 운영 배포 상태 확인(#4)과 자격증명 미스테이징 확인(#5) | 콘솔에서 배포된 규칙에 `trainerWorkspaces` match가 있는지 확인. `git check-ignore -v functions/service-account-key.json functions/.secret.local`(dfet:.gitignore:49-51가 덮는지). 커밋 직전마다 `git diff --cached --name-only \| grep -E 'GoogleService-Info\|\.env\|secret\|service-account'` 결과가 비어야 함 | G-01.md에 배포 상태와 확인 결과 기록 |
| 901-4 | 월 오후 3h | A 분류를 주제별로 커밋(#2, #3). 혼재 파일은 `git add -p`로 hunk만 스테이징 | 제안 커밋: `fix(rules): harden posts field validation and server counters`, `feat(functions): add v2 onCall adapter, deleteOwnAccount and community callables`, `test(functions): add community rules cases and clinical emulator e2e`, `ci: run functions e2e on emulators`, `feat(admin): add admins, analytics, user detail and ingestion evidence pages`, `docs(reports): add build and audit reports`, `docs(prd): add PRD_V1 v1.0-draft`, `chore: ignore output and tmp`(소유자 판단, ASM-S01-10) | `git status --short`에 B·C만 남음 |
| 901-5 | 월 오후 1h | B 분류를 보관 브랜치로(#7) | `git switch -c archive/trainer-ui-2026-09 && git add <B 파일 목록> && git commit -m "chore(archive): snapshot trainer UI WIP (MIG-01 B)" && git push -u origin archive/trainer-ui-2026-09 && git rev-parse HEAD` → 해시를 G-01.md에 기록. `git switch feature/integrated-care-2026` | 보관 브랜치 원격 존재, tip 해시 기록, 작업 트리에는 C만 남음 |
| 901-6 | 화 오전 2h | A를 main에 병합(#6). 브랜치는 main보다 커밋 18개 앞서 있고 main 쪽 새 커밋은 없다(2026-09-24 확인) | `git push -u origin feature/integrated-care-2026 && gh pr create --base main --head feature/integrated-care-2026 --title "chore: MIG-01 A-class baseline (DF-901)" --body-file ../mig01/pr-body.md` → CI 4 job 확인 → rebase 병합(ASM-S01-07) → `git push origin --delete feature/integrated-care-2026` | CI 4 job 초록. `git grep -n trainerWorkspaces origin/main -- lib test functions/test`가 0건(#4 예외는 기록). G-01.md에 CI 링크 |
| 901-7 | 화 오전 30m | main 보호 규칙 설정(ADR-014) | `gh api -X PUT repos/TEhyeok/DFET_Coach/branches/main/protection --input ../mig01/protection.json`. JSON: `required_status_checks.strict=true`, `contexts=["flutter","functions-and-rules","admin-web","ios-no-codesign"]`, `required_pull_request_reviews.required_approving_review_count=0`, `required_linear_history=true`, `allow_force_pushes=false`, `enforce_admins=false`, `restrictions=null` | `gh api repos/TEhyeok/DFET_Coach/branches/main/protection`로 확인. 금요일에 새 필수 체크 3개 추가 |

증빙 문서(`docs/v1/evidence/G-01.md`, 이후 G-02.md·G-04.md)는 소유자가 로컬에서 먼저 작성해 두고, DF-001 병합(화) 뒤 별도 PR `docs/DF-901-gate-evidence`로 올린다. 이때부터 헤더 표준 린트를 받는다. 금요일에 G-02.md·G-04.md 갱신분을 같은 방식으로 한 번 더 올린다.

C 분류(`tool/generate_*report*.py` 등 7개, `output/`, `tmp/`)는 커밋하지 않고 작업 트리에 그대로 둔다. 내용 확인은 소유자가 별도로 하며 이번 스프린트 범위가 아니다.

### 7.2 DF-003 metric-catalog·vocab(레인 A, 2점)

Trace: F-SOAP-06.1, 부록 A.1~A.7, 부록 B, AC-SOAP-02.2.

| 작업 | 시간 | 내용 | 파일·명령 | 완료 조건 |
|---|---|---|---|---|
| 003-1 | 월 오후 3h | 부록 A.1·A.2의 22개 지표를 옮긴다. MDC 값은 넣지 않는다(ADR-009: 클라이언트에 MDC 상수 금지). 부록 A.4의 예약·제외 코드는 `excludedMetricCodes`에 둔다 | `contracts/metric-catalog.v1.json` | 22개, 중복 0, `excludedMetricCodes` 3개 |
| 003-2 | 화 오전 2h | 어휘 목록을 옮긴다. A.5~A.7은 `"status": "draft"`로 표시한다(DF-916에서 `confirmed`로 바꿈) | `contracts/vocab.v1.json` | V1-05 §13.2 enum 33개 전부, 각 `values` 중복 0 |
| 003-3 | 화 오전 1h | 출처 대응표와 수정 규칙 | `contracts/README.md`: 파일별 PRD 절 대응, "부록 A를 먼저 고치고 같은 PR에서 contracts와 생성물을 고친다", "생성물은 손으로 고치지 않는다", 버전 규칙(호환 깨짐 → `v2` 새 파일) | 소유자 검토 통과 |
| 003-4 | 화 오전 30m | 자체 검증 결과를 PR에 붙인다 | `jq '.metrics \| length' contracts/metric-catalog.v1.json`(22), `jq -r '.metrics[].metricCode' contracts/metric-catalog.v1.json \| sort \| uniq -d`(빈 출력), `jq empty contracts/*.json` | PR 본문에 출력 첨부 |

값·형식 정본은 [V1-05 §13.1·§13.2](../05_DATA_MODEL_AND_RULES.md)다(최상위 `contract`·`version`·`revision`·`source`, 제외 코드 `excludedMetricCodes` 3개, family 5개, unit 9개, sideRule `magnitudeWith*` 계열, conditionKeys 필드 경로(예외 `stationProfile`·`nrsScale`), vocab enum 33개 `{status: confirmed|draft, …}`, landmarkCode 9개). 이 절은 작업 순서만 적는다.

### 7.3 DF-004 contracts 생성기와 CI(레인 A, 3점)

Trace: F-SOAP-06.4, §9.3 변경 절차. ADR-005.

| 작업 | 시간 | 내용 | 파일·명령 | 완료 조건 |
|---|---|---|---|---|
| 004-1 | 화 오후 3h | 메타 스키마(draft 2020-12). `$defs.metricCatalog`, `$defs.vocab`. 열거형은 [V1-05 §13.2](../05_DATA_MODEL_AND_RULES.md) 표 | `schemas/contracts-meta.schema.json` | `jq empty schemas/*.json` 통과(기존 CI 단계, dfet:.github/workflows/ci.yml:51) |
| 004-2 | 수 오전 4h | 생성기 본체: 입력 검증(ajv) → 교차 검증(중복 metricCode, `excludedMetricCodes`와 겹침, `allowedSourceGrades ⊂ vocab.sourceGrade`) → 4개 소비자 출력(정렬 고정, 결정적) → `--check`는 메모리 생성 결과와 디스크 파일을 비교해 다르면 파일 목록을 출력하고 종료 코드 1 | `tool/contracts/generate.mjs`(Node 22 ESM), `tool/package.json`(`"private": true`, `"type": "module"`, devDependencies `ajv@^8`·`ajv-formats@^3`만)과 `tool/package-lock.json`(이 스토리가 만든다, ASM-S01-03). `contracts/fixtures`를 복사하는 emitter는 두지 않는다([03 ASM-03-13](../03_RELEASE_AND_SPRINT_PLAN.md#141-가정)) | `node tool/contracts/generate.mjs` 두 번 실행 시 diff 0 |
| 004-3 | 수 오후 3h | 소비자별 템플릿과 생성물 커밋. 모든 파일 첫 줄에 `GENERATED by tool/contracts/generate.mjs from <입력 파일> sha256:<해시> — DO NOT EDIT` | Swift `trainer_app/Packages/TrainerCore/Sources/TrainerContracts/Generated/{MetricCatalog,Vocab}.swift`(ADR-001 경로), Dart `lib/contracts/generated/{metric_catalog,vocab}.g.dart`, Functions `functions/src/shared/generated/{metricCatalog,vocab}.js`(CommonJS, `'use strict'`), admin_web `admin_web/lib/generated/contracts.ts` | `npm --prefix functions run lint`(생성 JS 포함, dfet:functions/package.json:7), `flutter analyze lib/contracts`, `npm --prefix admin_web run typecheck` 통과 |
| 004-4 | 목 오전 2h | 테스트(node:test): 중복 코드 거부, `excludedMetricCodes` 코드 사용 거부, 모르는 sourceGrade 거부, `--check` 드리프트 탐지, 출력 결정성 | `tool/contracts/test/generate.test.mjs`, `tool/contracts/test/fixtures/bad-*.json` | `node --test tool/contracts/test/` 통과 |
| 004-5 | 목 오전 1h | CI job 추가(**ci.yml 순서 차례 2번**: DF-001 병합 뒤 rebase, 마지막 커밋) | `.github/workflows/ci.yml`에 `contracts` job(워크플로 수준 `paths` 없음, 항상 실행): `ubuntu-latest`, `actions/setup-node@v4`(node 22, cache-dependency-path `tool/package-lock.json`), `npm ci --prefix tool`, `node --test tool/contracts/test/`, `node tool/contracts/generate.mjs --check` | PR에서 초록. 일부러 생성물 한 줄을 고친 커밋에서 빨강(증빙 스크린샷 후 되돌림) |

생성물 형태(요지):

```swift
// GENERATED ... DO NOT EDIT
public enum MetricCode: String, CaseIterable, Codable, Sendable {
  case craniovertebralAngle, headTiltFrontal, shoulderTiltAngle /* ... 22개 */
}
public struct MetricDefinition: Sendable {
  public let code: MetricCode
  public let unit: String
  public let allowedSourceGrades: [SourceGrade]
  // ...
}
public enum MetricCatalog {
  public static let all: [MetricCode: MetricDefinition] = [ /* ... */ ]
}
```

```dart
// GENERATED ... DO NOT EDIT
enum MetricCode {
  craniovertebralAngle('craniovertebralAngle'),
  // ...
  ;
  const MetricCode(this.wire);
  final String wire;
  static MetricCode? fromWire(String value) =>
      MetricCode.values.where((c) => c.wire == value).firstOrNull;
}
```

```js
// GENERATED ... DO NOT EDIT
'use strict';
const METRIC_CODES = Object.freeze(['craniovertebralAngle' /* ... */]);
module.exports = { METRIC_CODES /* , METRIC_CATALOG, SOURCE_GRADES, ... */ };
```

```ts
// GENERATED ... DO NOT EDIT
export const METRIC_CODES = ['craniovertebralAngle' /* ... */] as const;
export type MetricCode = (typeof METRIC_CODES)[number];
```

알 수 없는 코드를 원문으로 보존하는 처리(`fromWire`가 null일 때)는 생성물이 아니라 코덱 스토리(DF-007 Dart, DF-009 Swift)에서 한다.

### 7.4 DF-008 trainer_app 골격과 trainer-app CI(레인 B, 5점)

Trace: D2, NFR-01, NFR-03, NFR-09, NFR-14, §10.2.1. ADR-001, ADR-019.

- **정본은 [P0 DF-008 카드](../backlog/P0.md#df-008)**다. 수용 기준(AC-DF-008.1~.6), 패키지 두 개(`TrainerCore`·`TrainerKit`)의 `Package.swift`, 앱 시작 판정(`LaunchConfiguration`)은 카드와 [V1-04 §6.3·§8.1](../04_ARCHITECTURE.md#63-패키지프로젝트-사양)을 그대로 따른다. 이 절은 그 카드를 **요일별 작업으로 나눈 것**이며, 카드와 다르게 정하는 값은 없다.
- 패키지 구성은 [ADR-001](../adr/ADR-001-independent-trainer-app.md)(Accepted)에서 이미 정했다. 한 패키지에 UIKit 타깃이 있으면 macOS `swift test`가 실패한다는 것은 2026-09-24 로컬에서 확인됐다([V1-04 §6.2](../04_ARCHITECTURE.md#62-패키지-두-개로-나누는-이유)). 그래서 이번 스프린트에는 구성 스파이크를 두지 않는다(ASM-S01-02).
- 제품(product)은 **타깃마다 하나씩** 선언한다(V1-04 §6.3의 `TrainerCore` products 목록, `TrainerKit`도 같은 방식). App 타깃은 필요한 제품만 링크하고, 테스트 타깃은 자기 대상만 링크한다.

| 작업 | 시간 | 내용 | 파일·명령 | 완료 조건 |
|---|---|---|---|---|
| 008-1 | 월 오후 3h | TrainerCore 패키지. 다섯 타깃(`TrainerContracts`, `TrainerDomain`, `PostureMath`, `SyncEngine`, `TrainerAnalytics`)과 타깃별 제품, 테스트 타깃 다섯 개. 타깃마다 한 줄 파일 `public enum <Target>Module {}`, 테스트마다 스모크 1개. 테스트 타깃에 `Fixtures/` 리소스를 두지 않는다. 픽스처·벡터는 `TrainerDomainTests/Support/FixtureLoader.swift`가 `#filePath`로 저장소 루트 `contracts/`를 직접 읽는다(복사 단계 없음, V1-04 §6.3, [03 ASM-03-13](../03_RELEASE_AND_SPRINT_PLAN.md#141-가정)) | `trainer_app/Packages/TrainerCore/Package.swift`(swift-tools-version 5.10, `platforms: [.iOS(.v17), .macOS(.v14)]`), `Sources/<Target>/<Target>.swift`, `Sources/TrainerContracts/TrainerContracts.swift`(비생성 네임스페이스), `Tests/<Target>Tests/<Target>SmokeTests.swift` | `swift test --package-path trainer_app/Packages/TrainerCore` 통과. `grep -REn "^import (UIKit\|SwiftUI\|SwiftData\|Firebase)" trainer_app/Packages/TrainerCore/Sources` 0건(AC-DF-008.3) |
| 008-2 | 화 오전 3h | TrainerKit 패키지(iOS 전용). `LocalStore`, `FirebaseData`, `PostureVision`, `DesignSystem`, Feature 11개와 타깃별 제품. Firebase 제품(`FirebaseAuth`·`FirebaseFirestore`·`FirebaseStorage`·`FirebaseFunctions`·`FirebaseAppCheck`)은 `FirebaseData`에만 의존시킨다. `FirebaseData`에 공개 API `FirebaseBootstrap.configure(_:)` 자리 표시를 둔다 | `trainer_app/Packages/TrainerKit/Package.swift`(swift-tools-version 5.10, `platforms: [.iOS(.v17)]`, `.package(path: "../TrainerCore")`, firebase-ios-sdk `from: "11.0.0"`, ASM-S01-06), `Sources/<Target>/<Target>.swift`, `Sources/FirebaseData/FirebaseBootstrap.swift` | iPad 시뮬레이터 `xcodebuild build`(008-6 뒤) 통과. 부정 테스트: `FeatureSettings`에 `import FirebaseFirestore`를 넣으면 컴파일 실패(스크린샷 후 되돌림, AC-DF-008.2) |
| 008-3 | 화 오후 3h | XcodeGen 명세와 구성 파일(아래 초안). trainer_ios 골격(dfet:trainer_ios/project.yml:1-13, :34)을 참고하되 배포 대상 17.0, iPad 전용, 위젯 없음 | `trainer_app/project.yml`, `trainer_app/.xcodegen-version`(`2.44.1`, ASM-S01-09), `trainer_app/Config/{Debug,Release}.xcconfig`, `trainer_app/App/Resources/{Info.plist, DFETTrainer.entitlements, Assets.xcassets, Localizable.xcstrings}` | `xcodegen generate --spec trainer_app/project.yml --project trainer_app` 성공 |
| 008-4 | 수 오전 3h | 앱 진입점과 환경 판정. `--preview-*` 판정과 App Check 구성은 trainer_ios(dfet:trainer_ios/DFETTrainer/App/DFETTrainerApp.swift:32-55)를 참고하되, App 타깃은 Firebase를 import하지 않고 `FirebaseBootstrap.configure(.production)`만 부른다(V1-04 ASM-04-03). plist가 없으면 `.misconfigured(reason: "missingPlist")`로 구성 없음 화면을 보인다(Preview로 떨어지지 않음) | `App/DFETTrainerApp.swift`, `App/AppDelegate.swift`, `App/Composition/LaunchConfiguration.swift`(`resolve(arguments:bundle:)`와 순수 오버로드 `resolve(arguments:isDebug:plistPresent:) -> LaunchMode`), `App/AppShell/RootPlaceholderView.swift`(식별자 `app.root`, DF-017이 교체), `App/AppShell/ConfigurationMissingView.swift`(식별자 `app.configMissing`) | TC-DF008-05 표 기반 6케이스 통과. `--preview-empty` 실행 시 `app.root` |
| 008-5 | 수 오후 2h | 프로젝트 생성·커밋과 무시 규칙 | `xcodegen generate --spec trainer_app/project.yml --project trainer_app` 후 `trainer_app/DFETTrainer.xcodeproj` 커밋(`project.xcworkspace/xcshareddata/swiftpm/Package.resolved` 포함). `trainer_app/.gitignore`: `DerivedData/`, `.spm/`, `build/`, `Config/GoogleService-Info.plist`(DF-034가 CI 주입을 마저 한다) | 재생성 두 번 뒤 `git status` 깨끗함. 재생성이 `Package.resolved`를 지우거나 바꾸는지 PR에 기록 |
| 008-6 | 수 오후 2h | UI 스모크와 시뮬레이터 선택 스크립트 | `trainer_app/UITests/LaunchSmokeTests.swift`(`testPreviewEmptyLaunch`: `app.launchArguments = ["--preview-empty"]`, `app.otherElements["app.root"].waitForExistence(timeout: 5)`), `trainer_app/scripts/ci_pick_ipad.sh`(사용 가능한 iPad 시뮬레이터 UDID 하나 출력) | iPad 시뮬레이터에서 통과 |
| 008-7 | 목 오전 3h | CI 워크플로(아래 초안). 워크플로 수준 `paths` 필터를 두지 않는다(ASM-S01-05) | `.github/workflows/trainer-app.yml` | PR에서 초록. 일부러 `project.yml`만 바꾼 커밋에서 diff 단계가 빨강(증빙 후 되돌림). `docs/**`만 바꾼 PR에서 `trainer-app`이 '건너뜀 = 통과'로 보고됨 |
| 008-8 | 목 오후 1h | **ci.yml 순서 차례(§5)**: DF-004 병합 뒤 rebase하고, 마지막 커밋으로 `ios-no-codesign` job에 NFR-01 grep step 하나만 추가(AC-DF-008.6) | `.github/workflows/ci.yml`: `- name: Runner has no trainer packages (NFR-01)` / `run: "! grep -REn \"TrainerCore\|TrainerKit\|BodyPathCore\" ios/Podfile ios/Runner.xcodeproj/project.pbxproj"` | `ios-no-codesign` 초록 |
| 008-9 | 목 오후 1h | 문서와 증빙 | `trainer_app/README.md`(생성·빌드·테스트 명령, 동결 원본 trainer_ios와의 관계, plist 규칙), PR 본문에 명령 출력과 시뮬레이터 스크린샷(합성 화면만) | 소유자 검토 통과 |

`trainer_app/project.yml` 초안. [V1-04 §6.3](../04_ARCHITECTURE.md#63-패키지프로젝트-사양) 요지와 같고, **plist 처리만 P0 DF-008 카드 방식**(참조하지 않고 빌드 후 복사)을 따른다. 2026-09-24 로컬 검증(XcodeGen 2.44.1, Xcode 26.0, 합성 프로브 프로젝트) 결과는 다음과 같다(ASM-S01-12).

- `optional: true` 소스로 plist를 참조하면 생성물은 plist 유무와 관계없이 같다. 하지만 plist가 없는 환경(CI, 에이전트)에서는 `Build input file cannot be found: .../Config/GoogleService-Info.plist`로 빌드가 실패한다. 그래서 AC-DF-008.4(plist 없이 Release 빌드 성공)를 만족하지 못한다.
- 아래 `postBuildScripts` 방식은 생성물이 plist 유무와 관계없이 같고, plist가 없으면 빌드가 성공하며, 있으면 앱 번들에 복사된다.

```yaml
name: DFETTrainer
options:
  minimumXcodeGenVersion: 2.44.1
  deploymentTarget: { iOS: "17.0" }
  createIntermediateGroups: true
settings:
  base:
    SWIFT_VERSION: "5.0"
    DEVELOPMENT_TEAM: MT27Z7369H
    MARKETING_VERSION: 0.1.0
    CURRENT_PROJECT_VERSION: 1
    CODE_SIGN_STYLE: Automatic
packages:
  TrainerCore: { path: Packages/TrainerCore }
  TrainerKit:  { path: Packages/TrainerKit }
targets:
  DFETTrainer:
    type: application
    platform: iOS
    configFiles: { Debug: Config/Debug.xcconfig, Release: Config/Release.xcconfig }
    sources:
      - path: App            # plist는 소스로 참조하지 않는다(ASM-S01-12)
    dependencies:
      - { package: TrainerCore, product: TrainerContracts }
      - { package: TrainerCore, product: TrainerDomain }
      - { package: TrainerKit, product: FirebaseData }
      - { package: TrainerKit, product: FeatureSettings }
      # 나머지 Feature*·LocalStore·DesignSystem·PostureVision 제품은 DF-017(AppShell)이 라우트와 함께 추가한다
    postBuildScripts:
      - name: Copy Firebase config if present
        basedOnDependencyAnalysis: false
        script: |
          if [ -f "$SRCROOT/Config/GoogleService-Info.plist" ]; then
            cp "$SRCROOT/Config/GoogleService-Info.plist" "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/"
          fi
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: kr.co.dfet.trainer
        PRODUCT_NAME: D-FET Trainer
        TARGETED_DEVICE_FAMILY: "2"          # Q-22 결과가 Universal이면 "1,2"(03 T-07)
        INFOPLIST_FILE: App/Resources/Info.plist
        CODE_SIGN_ENTITLEMENTS: App/Resources/DFETTrainer.entitlements
        OTHER_LDFLAGS: ["$(inherited)", "-ObjC"]
        ENABLE_USER_SCRIPT_SANDBOXING: NO    # 위 스크립트가 선언하지 않은 파일을 읽는다. 값은 출력하지 않는다
  DFETTrainerIntegrationTests:
    type: bundle.unit-test
    platform: iOS
    sources: [IntegrationTests]
    dependencies: [{ target: DFETTrainer }]
  DFETTrainerUITests:
    type: bundle.ui-testing
    platform: iOS
    sources: [UITests]
    dependencies: [{ target: DFETTrainer }]
schemes:
  DFETTrainer:
    build: { targets: { DFETTrainer: all } }
    test: { targets: [DFETTrainerIntegrationTests, DFETTrainerUITests] }
```

- `IntegrationTests/`에는 이번 스토리에서 빈 자리 표시 테스트 하나만 둔다(에뮬레이터 연동은 DF-107).
- App 타깃이 링크하는 제품이 위 네 개뿐인 것은 이번 스토리의 자리 표시 화면 기준이다. V1-04 §6.3의 `package: TrainerKit`(전체) 표기와 결과는 같고, 제품을 타깃마다 선언했기 때문에 필요한 것만 고를 수 있다.

`.github/workflows/trainer-app.yml` 초안. 구조는 [10_TEST_PLAN §19](../10_TEST_PLAN.md)의 `changes-trainer` + job 수준 `if` 방식과 같다. 워크플로 자체는 모든 PR에서 뜨고, 경로에 해당하지 않으면 `trainer-app` job이 조건으로 건너뛰어져 필수 체크가 '통과'로 보고된다. 워크플로 수준 `paths` 필터를 쓰면 체크가 아예 보고되지 않아 'Expected — waiting'으로 병합이 막힌다(ASM-S01-05).

```yaml
name: trainer-app
on:
  pull_request:
  push:
    branches: [main]
  workflow_dispatch:
concurrency:
  group: trainer-app-${{ github.ref }}
  cancel-in-progress: true
jobs:
  changes-trainer:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    outputs:
      app: ${{ steps.diff.outputs.app }}
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - id: diff
        shell: bash
        run: |
          if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then echo "app=true" >> "$GITHUB_OUTPUT"; exit 0; fi
          if [ "${{ github.event_name }}" = "pull_request" ]; then base="${{ github.event.pull_request.base.sha }}"; else base="${{ github.event.before }}"; fi
          if ! files=$(git diff --name-only "$base" "${{ github.sha }}" 2>/dev/null); then echo "app=true" >> "$GITHUB_OUTPUT"; exit 0; fi
          if printf '%s\n' "$files" | grep -Eq '^(trainer_app/|contracts/|\.github/workflows/trainer-app\.yml)'; then
            echo "app=true" >> "$GITHUB_OUTPUT"
          else
            echo "app=false" >> "$GITHUB_OUTPUT"
          fi

  trainer-app:                      # 필수 체크 이름. 건너뛰면 GitHub가 통과로 취급한다
    needs: changes-trainer
    if: needs.changes-trainer.outputs.app == 'true'
    runs-on: macos-15
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@v4
      - run: xcodebuild -version && swift --version
      - name: Install pinned XcodeGen (ASM-S01-09)
        run: |
          V=$(cat trainer_app/.xcodegen-version)
          curl -fsSL -o "$RUNNER_TEMP/xcodegen.zip" "https://github.com/yonaskolb/XcodeGen/releases/download/${V}/xcodegen.zip"
          echo "a2e905fb68446e9bb4008cdfe2e13e3f176d0cbcca828b71770f8e53fca91b73  $RUNNER_TEMP/xcodegen.zip" | shasum -a 256 -c -
          unzip -q "$RUNNER_TEMP/xcodegen.zip" -d "$RUNNER_TEMP/xcodegen"
          echo "$RUNNER_TEMP/xcodegen/xcodegen/bin" >> "$GITHUB_PATH"
      - name: Generated project is current (ADR-001)
        run: |
          xcodegen version
          xcodegen generate --spec trainer_app/project.yml --project trainer_app
          git diff --exit-code -- trainer_app/DFETTrainer.xcodeproj
      - name: Pure targets on macOS (TrainerCore)
        run: swift test --package-path trainer_app/Packages/TrainerCore
      - uses: actions/cache@v4
        with:
          path: trainer_app/.spm
          key: spm-${{ hashFiles('trainer_app/**/Package.resolved') }}
      - name: iPad simulator tests (TrainerKit build + UI smoke)
        run: |
          set -o pipefail
          UDID=$(bash trainer_app/scripts/ci_pick_ipad.sh)
          xcodebuild test -project trainer_app/DFETTrainer.xcodeproj -scheme DFETTrainer \
            -destination "id=${UDID}" -clonedSourcePackagesDirPath trainer_app/.spm \
            -only-testing:DFETTrainerUITests CODE_SIGNING_ALLOWED=NO
      - name: Release build without plist (AC-DF-008.4)
        run: |
          set -o pipefail
          xcodebuild build -project trainer_app/DFETTrainer.xcodeproj -scheme DFETTrainer \
            -configuration Release -destination 'generic/platform=iOS' \
            -clonedSourcePackagesDirPath trainer_app/.spm CODE_SIGNING_ALLOWED=NO
```

- 해시는 2026-09-24에 `xcodegen.zip`(2.44.1)을 내려받아 계산한 값이다. `.xcodegen-version`을 올리는 PR은 같은 PR에서 해시를 바꾼다.
- plist 시크릿 주입 단계와 `-testPlan CI`, iPad 11형 캔버스 스모크는 [10_TEST_PLAN §19](../10_TEST_PLAN.md) 최종형에 있고, 각각 DF-034(S02)와 해당 스토리가 추가한다. 이번 스토리의 job 이름·트리거 구조는 그 최종형과 같아 이후 스토리는 step만 더한다.

### 7.5 DF-001 docs/v1 병합(레인 C, 1점)

Trace: PRD §0.3, §13.4. 정본은 [P0 DF-001 카드](../backlog/P0.md#df-001)다.

| 작업 | 시간 | 내용 | 파일·명령 | 완료 조건 |
|---|---|---|---|---|
| 001-1 | 월 오후 2h | 문서 작성 단계 산출물 묶음을 저장소에 넣는다. `tool/backlog/**`는 DF-002 범위라 제외 | `docs/v1/**`(00~13, `adr/`, `backlog/`, `sprints/`, `templates/`), `.github/ISSUE_TEMPLATE/{config,epic,story,task,bug,spike,owner_action}.yml`, `.github/pull_request_template.md`, `.github/CODEOWNERS` | 파일 수가 00_README의 문서 지도와 일치 |
| 001-2 | 월 오후 2h | 헤더·링크 린트. **Node 22 내장 모듈만 쓰고 `tool/package.json`을 만들지 않는다**(P0 DF-001 카드, ASM-S01-03). 검사 항목: 첫 줄 `# `, 헤더 표에 8개 행(문서 ID, 버전, 상태, 작성일, 소유자, 근거 PRD 절, 관련 에픽·스토리, 변경 규칙), 표 다음 `## 목차`, `01_AGILE_WORKING_AGREEMENT.md`에 `## 문서 변경`, `--links`일 때 상대 링크 대상 파일 존재(앵커는 검사하지 않음, ASM-P0-23) | `tool/lint/doc-headers.mjs`, `tool/lint/test/doc-headers.test.mjs`, `tool/lint/test/fixtures/{good,missing-toc,bad-link}.md` | `node tool/lint/doc-headers.mjs --links docs/v1` 종료 코드 0, `node --test tool/lint/test/doc-headers.test.mjs` 통과 |
| 001-3 | 화 오전 1h | **ci.yml 순서 차례 1번(§5)**: `ci.yml`에 `changes-ci` job(출력 `docs`만)과 `docs-and-backlog` job을 추가한다. 구조는 [10_TEST_PLAN §19.3](../10_TEST_PLAN.md#193-ciyml-개정-초안) 최종형과 같다. 워크플로 수준 `paths` 필터는 쓰지 않는다(ASM-S01-05). DF-002의 단계는 파일이 있을 때만 도는 조건으로 **미리 넣어 둔다**. 그래서 DF-002는 `ci.yml`을 고치지 않는다 | `.github/workflows/ci.yml`(아래 초안) | PR에서 `docs-and-backlog` 초록. `contracts/**`만 바꾼 임시 커밋에서 '건너뜀 = 통과'(증빙 후 되돌림) |
| 001-4 | 화 오전 1h | 에이전트 진입 문서에 v1 절 추가. 기존 내용은 바꾸지 않고 끝에 붙인다. 절 본문은 P0 DF-001 카드의 `## D-FET Coach v1 개발` 블록을 그대로 쓴다 | `AGENTS.md`, `CLAUDE.md` | 링크 린트 통과(AC-DF-001.2) |
| 001-5 | 화 오전 30m | PRD 무변경 확인 | `git diff --exit-code origin/main -- docs/PRD_V1.md` | 종료 코드 0(AC-DF-001.3) |

`ci.yml`에 추가할 부분(001-3). 기존 네 job은 건드리지 않는다.

```yaml
  changes-ci:                  # DF-001. DF-031(S05)이 migrations 출력을 더한다
    runs-on: ubuntu-latest
    timeout-minutes: 5
    outputs:
      docs: ${{ steps.diff.outputs.docs }}
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - id: diff
        shell: bash
        run: |
          if [ "${{ github.event_name }}" = "pull_request" ]; then base="${{ github.event.pull_request.base.sha }}"; else base="${{ github.event.before }}"; fi
          if ! files=$(git diff --name-only "$base" "${{ github.sha }}" 2>/dev/null); then echo "docs=true" >> "$GITHUB_OUTPUT"; exit 0; fi
          if printf '%s\n' "$files" | grep -Eq '^(docs/|tool/backlog/|tool/lint/doc-headers|\.github/workflows/ci\.yml)'; then
            echo "docs=true" >> "$GITHUB_OUTPUT"
          else
            echo "docs=false" >> "$GITHUB_OUTPUT"
          fi

  docs-and-backlog:            # DF-001, DF-002. 필수 체크 이름. 건너뛰면 통과로 취급된다
    needs: changes-ci
    if: needs.changes-ci.outputs.docs == 'true'
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: "22" }
      - run: node --test tool/lint/test/doc-headers.test.mjs
      - run: node tool/lint/doc-headers.mjs --links docs/v1
      - name: Backlog validation (DF-002)
        if: hashFiles('tool/backlog/validate_backlog.mjs') != ''
        run: node tool/backlog/validate_backlog.mjs
      - name: Backlog script scenarios with fake gh (DF-002)
        if: hashFiles('tool/backlog/test/run.sh') != ''
        run: bash tool/backlog/test/run.sh
```

### 7.6 DF-002 백로그 도구(레인 C, 2점)

Trace: PRD §0.5, §12.1. 이 스토리는 도구를 만들고 dry-run으로 검증하는 것까지다. 실제 생성은 소유자(DF-902)만 한다.

| 작업 | 시간 | 내용 | 파일·명령 | 완료 조건 |
|---|---|---|---|---|
| 002-1 | 화 오후 3h | 정의 파일. 마일스톤 목표일은 [03 §4.1](../03_RELEASE_AND_SPRINT_PLAN.md#4-릴리스-로드맵p0p3-v2)을 따른다: 'P0 정리·기반' 2026-10-30, 'P1a 알파-기록' 2027-01-08, 'P1b 알파-평가' 2027-01-29, 'P2 베타' 2027-03-26, 'P3 센터 출시' 2027-05-07, 'V2(보류)' 목표일 없음 | `tool/backlog/labels.json`(type/, area/, phase/, prio/, size/, owner-action, gate/, flag/, agent/, status/, 위험 표시 라벨 전체), `tool/backlog/milestones.json`, `tool/backlog/issue.schema.json`(TL-04 필드), `tool/backlog/issues.json`(문서 묶음에 포함된 TL-05~TL-10) | JSON이 스키마 통과 |
| 002-2 | 수 오전 4h | 검증기(Node 22 내장 모듈만, `required`·`type`·`enum`만 해석하는 최소 스키마 검증, P0 DF-002 카드). 검사: 스키마, DF 키 유일성, 라벨·마일스톤 존재, `epic` 존재, `dependsOn` 대상 존재와 순환 없음, trace ID가 `docs/PRD_V1.md`에 존재(범위 표기 `R-01~R-31`, `F-SOAP-06.1~06.4`는 양 끝을 확인, `§` 참조는 제목 존재 확인, `AC-DF-*`는 제외) | `tool/backlog/validate_backlog.mjs`, 실행 `node tool/backlog/validate_backlog.mjs --prd docs/PRD_V1.md tool/backlog/issues.json` | 현재 이슈 JSON 전체 통과 |
| 002-3 | 수 오후 3h | 생성 스크립트. `set -euo pipefail`, 기본 `--dry-run`, 실행은 `--apply`, `--repo`(기본 TEhyeok/DFET_Coach), `--only labels\|milestones\|project\|issues\|relink`, `--files <issues json>`, 선택 `--phase`·`--sprint`·`--keys`·`--owner-actions`, CI용 `--offline`(dry-run 별칭. dry-run은 gh를 전혀 호출하지 않는다). 이슈는 실행 시작 때 `gh issue list --state all --limit 3000 --json number,title`로 제목을 한 번 모두 읽어 `[DF-NNN]` 접두로 찾고, 있으면 건너뛴다(검색 API 미사용, P0 DF-002 카드). 스테이징 구현은 `create_github_issues.sh`이고 `create_backlog.sh`는 호환 진입점이다. 필요 권한 `repo`, `project` | `tool/backlog/create_backlog.sh`, `tool/backlog/README.md`(TL-01 순서: dry-run → 라벨 → 마일스톤 → Projects → 이슈) | `bash tool/backlog/create_backlog.sh --dry-run --offline`이 계획을 출력하고 종료 코드 0, `shellcheck` 경고 0 |
| 002-4 | 목 오전 2h | 테스트와 CI 진입점. **`ci.yml`은 고치지 않는다**: DF-001이 넣어 둔 조건부 단계가 `tool/backlog/validate_backlog.mjs`와 `tool/backlog/test/run.sh`가 생기면 자동으로 돈다(§7.5) | `tool/backlog/test/validate_backlog.test.mjs`(중복 키, 모르는 라벨, 없는 마일스톤, 순환 의존, 없는 trace ID가 각각 실패하고 정상 묶음은 통과), `tool/backlog/test/fake-gh.sh`, `tool/backlog/test/run.sh`(`set -euo pipefail`; `node --test tool/backlog/test/`, 가짜 gh로 AC-DF-002.1·.2 시나리오, `bash tool/backlog/create_backlog.sh --dry-run --offline > /dev/null`, `shellcheck`가 있으면 `shellcheck tool/backlog/*.sh tool/backlog/test/*.sh`) | PR에서 `docs-and-backlog`의 두 조건부 단계가 실행되고 초록(AC-DF-002.5) |

### 7.7 DF-005 SOAP 교차 픽스처(레인 C, 2점)

Trace: F-SOAP-06, AC-SOAP-06.1~06.3, MIG-03, §9.3 변경 절차 3. 모든 값은 가상 회원 합성 데이터다. 픽스처 경로는 금지어 린트 예외 경로다(부록 C.3).

봉투(`_fixture`·`path`·`data`), 타입 태그(`$ts`·`$serverTimestamp`·`$bytes`·`$int`), 합성 식별자 규칙, 파일 목록(v2 5개, 레거시 6개)의 **정본은 [P0 DF-005 '픽스처 규약'](../backlog/P0.md#fixture-contract)**이다. 아래 작업은 그 규약을 요일별로 나눈 것이며, 다르면 P0 카드를 따른다(ASM-S01-04).

| 작업 | 시간 | 내용 | 파일·명령 | 완료 조건 |
|---|---|---|---|---|
| 005-1 | 목 오후 1h | 규약 1~4번 전문과 추가 절차를 README로 옮긴다 | `contracts/fixtures/README.md` | 소유자 검토 |
| 005-2 | 목 오후 3h | v2 입력 5개(규약 4번 표 이름 그대로): `finalized_no_metrics`, `draft_rom_mmt_pain`, `pending_member_draft`(`memberUid: null`, `memberId` 없음, `pendingMemberId: "fx-pending-001"`), `refs_snapshots_pending_policy`, `forward_compat_unknown_code`(`futureMetricX` 1행 + 정상 1행) | `contracts/fixtures/soap_v2/*.json` | 각 파일 `_fixture.expect` 명시(AC-DF-005.1) |
| 005-3 | 금 오전 2h | 레거시 입력 6개: 네 어휘, 두 status·두 category 표기, 인라인 필기를 모두 덮는다(PRD §11.4). `native_bridge_label_only.json`은 ID `native_fx_20260928`, `memberId: "member-00000000-0000-4000-8000-000000000001"`, `diagnosis` 자동 채움 합성 문자열, `structured.subjective.nativeInkDataBase64`(64바이트 합성), `isSharedWithMember: true` | `contracts/fixtures/soap_legacy/{flutter_rom_mmt_test_general, native_bridge_label_only, schema_doc_vocab, trainer_ios_korean_enum, status_shared_korean, drawing_data_bytes}.json` | 각 파일 `_fixture.expect.legacyMetricCount` 명시(AC-DF-005.2) |
| 005-4 | 금 오전 1h | 픽스처 검사 테스트 TC-DF005-01~04: 파일 목록, 봉투 키 3개, `_fixture` 필수 키, 합성 규칙(`@example.invalid`, `fx-`와 두 레거시 예외), v2 `data`에 `diagnosis`·`structured`·`drawingData`·`nativeInkDataBase64` 없음, 태그 네 가지 외 0, v2 `metricCode`가 카탈로그에 있음(`expect.uninterpretable` 행 제외) | `tool/contracts/test/fixtures.test.mjs` | `node --test tool/contracts/test/` 통과(contracts job이 자동 실행) |

MIG-03 기대 v2 문서(`contracts/fixtures/soap_legacy/expected_v2/<입력과 같은 이름>.json`)는 이관 스토리 DF-031(S05)이 만든다. 이번 스토리 범위가 아니다.

v2 픽스처 예시(`soap_v2/finalized_no_metrics.json`, P0 규약 1번과 같음):

```json
{
  "_fixture": {
    "id": "soap_v2/finalized_no_metrics",
    "description": "확정 최소 요건(회원·날짜·한 줄·다음 계획)만 채운 v2 노트",
    "writer": "synthetic",
    "prdRefs": ["AC-SOAP-06.3", "§6.4.4"],
    "expect": { "roundTrip": "identical", "metricCount": 0, "uninterpretable": 0 }
  },
  "path": "soap_notes/fx-note-v2-001",
  "data": {
    "schemaVersion": 2,
    "trainerId": "fx-trainer-001",
    "authorUid": "fx-trainer-001",
    "memberUid": "fx-member-001",
    "memberId": "fx-member-001",
    "pendingMemberId": null,
    "sessionDate": { "$ts": "2026-09-28T01:00:00Z" },
    "status": "finalized",
    "quickNote": "가상 회원 A, 오른쪽 어깨가 뻐근하다고 말함",
    "objective": {
      "metrics": [],
      "refs": { "postureAssessmentIds": [], "bodyCompositionRecordIds": [], "circumferenceMeasurementIds": [], "bodyScanIds": [] },
      "snapshots": []
    },
    "plan": { "nextSession": "어깨 가동성 운동 이어서 진행", "homeExercise": "" },
    "legalNature": "coachingRecord",
    "isSharedWithMember": false,
    "finalizedAt": { "$ts": "2026-09-28T02:00:00Z" },
    "createdAt": { "$ts": "2026-09-28T01:00:05Z" },
    "updatedAt": { "$ts": "2026-09-28T02:00:00Z" }
  }
}
```

### 7.8 소유자 행동 작업

| 작업 | 일시 | 내용 | 기록 위치 | 완료 조건 |
|---|---|---|---|---|
| 903-1 | 수 오전 30m | Firebase 콘솔 `dfetmanage` → 프로젝트 설정 → iOS 앱 추가: 번들 `kr.co.dfet.trainer`, 닉네임 'D-FET Trainer', 팀 MT27Z7369H | `docs/v1/evidence/G-02.md`('등록됨', 일시). 앱 ID·키 값은 적지 않는다 | 콘솔에 앱 존재 |
| 903-2 | 수 오전 15m | `GoogleService-Info.plist`를 받아 **저장소 밖**에 둔다(예: `~/secure/dfet/trainer/`, ASM-S01-08). 내용은 어디에도 붙여 넣지 않는다 | — | DF-034(S02)에서 CI 시크릿 등록 |
| 903-3 | 수 오전 30m | App Check에 앱 등록, 공급자 App Attest(강제는 끔, NFR-09 강제는 DF-386). Apple Developer에서 App ID `kr.co.dfet.trainer`의 App Attest 기능 확인 | G-02.md | 등록 확인 |
| 904-1 | 수 오전 30m | App Store Connect에서 `kr.co.dfet.trainer` 앱 레코드 유무, 빌드 이력, iPhone 지원 빌드 배포 이력 확인(Q-22) | G-02.md, 결과가 Universal이면 [03 §11 T-07](../03_RELEASE_AND_SPRINT_PLAN.md#11-재계획-트리거) | 기록 완료. DF-008의 `TARGETED_DEVICE_FAMILY` 확정 |
| 908-1 | 화 오후 3h | 법률 자문 의뢰서 초안. 질문: Q-04(동의 ④ 범위), Q-05(대기 회원 민감정보), Q-07(동의 증빙 보존), Q-21(프리랜서 트레이너 지위), **Q-24(코칭 기록 최대 보유기간 N)**, AS-22(만 14세), AS-31(처리 주체 모델), 대기 회원 최소 정보의 근거, 동의 5종 고지 항목 초안, 국외이전 고지(AS-19). 첨부는 PRD 발췌(§6.6 F-LINK-01, §6.7, §9.7, 부록 B.5)만 한다. 특허 공개 범위(Q-17) 때문에 PRD 전문과 LiDAR 방법은 보내지 않는다. 회원 실데이터는 넣지 않는다 | `docs/v1/evidence/G-04.md`(질문 목록, 발송일, 회신 예정일) | 초안 완료 |
| 908-2 | 금 오전 30m | 의뢰서 발송, 자문사에 회신 예정일 요청(ASM-03-01 검증) | G-04.md | 발송일 10-02 기록. 최신 발송일은 10-08([03 §5.2](../03_RELEASE_AND_SPRINT_PLAN.md#5-게이트-타임라인과-소유자-병렬-트랙)) |
| 913-1 | 목 오후 30m | Q-09 결정. 결정 전 기본값은 '자체 제품 로드맵, 과업 산출물 양식 미적용' | [00_README](../00_README.md) 결정 기록. PRD §13.3 반영은 소유자가 직접 PRD 변경 이력과 함께 한다(에이전트는 PRD를 고치지 않는다) | 결정 기록 |
| 930-1 | 수 오후 30m | Runner 내장 트레이너와 trainer_ios 동결 선언. 이후 두 영역의 수정 PR은 `freeze-exception` 라벨과 사유가 필요하다(MIG-09). DF-902 전이면 라벨 하나만 먼저 만든다 | `gh label create freeze-exception --color B60205 --description "동결 영역 예외 수정(MIG-09)" --repo TEhyeok/DFET_Coach`. 선언문은 G-01.md '동결 선언' 절. DF-001이 화요일에 병합되면 CODEOWNERS에 `ios/Runner/AppDelegate.swift`, `trainer_ios/**`가 있는지 확인만 한다(없으면 DF-001 PR에 수정 요청). 선언 자체는 DF-001을 기다리지 않는다 | 선언 기록 |
| 902-1 | 금 오전 1h | 백로그 생성 실행(DF-002 병합 뒤) | `gh auth refresh -s project,read:project` → `bash tool/backlog/create_backlog.sh --dry-run` 확인 → `bash tool/backlog/create_backlog.sh --apply --only labels,milestones` → `--apply --only project --create-project`로 보드를 만들고 `export PROJECT_NUMBER=<번호>` → `bash tool/backlog/create_backlog.sh --apply --only project` → `bash tool/backlog/create_backlog.sh --apply --only issues --phase P0 --owner-actions --exclude-proposals` → 같은 dry-run을 다시 돌려 '생성 0건' 확인 | 라벨·마일스톤·Projects 존재, 중복 이슈 0. P1a 이후 이슈는 각 단계 계획 때 같은 방식으로 추가(ASM-S01-11) |
| 902-2 | 금 오후 15m | main 필수 체크에 `contracts`, `trainer-app`, `docs-and-backlog` 추가. 사전 확인: 세 체크 모두 워크플로 수준 `paths` 필터가 없고, `docs/**`만 바꾼 PR(예: 소유자 증빙 PR)에서 `trainer-app`이, `trainer_app/**`만 바꾼 PR에서 `docs-and-backlog`가 '건너뜀'으로 **보고되는지** Checks 탭에서 본다. 'Expected — waiting'이 보이면 추가하지 않고 원인 PR을 고친다(ASM-S01-05) | 901-7의 보호 규칙 JSON 수정 | 보호 규칙에 7개 체크, 문서만 바꾼 PR이 병합 가능 |

## 8. 먼저 실행할 에이전트 작업 지시서

[AI 에이전트 작업 지시서 템플릿](../templates/AGENT_BRIEF.md)(V1-T08) 형식이다. 월요일 오후에 아래 세 지시서로 레인 A·B·C를 연다. 화·목에 여는 DF-004·DF-002·DF-005 지시서는 §8.4에 요약했고, 착수 직전에 같은 형식으로 이슈에 붙인다.

공통 금지 행동(모든 지시서에 적용):
- main 직접 푸시, PR 병합, 자동 병합 설정, 배포(`firebase deploy` 등), 운영 프로젝트 접근
- 비밀 파일 열람·출력: `.env*`, `.secret.local`, `service-account*.json`, `GoogleService-Info.plist`, 키 파일
- `output/`, `tmp/`, 회원 데이터·내보내기 열람
- GitHub 이슈·라벨·마일스톤 생성
- `docs/PRD_V1.md` 수정(수정 제안은 PR 본문 'PRD 제안' 절에만)
- 허용 경로 밖 파일 수정, 실데이터 사용

공통 완료 보고 형식(PR 본문, [PR 템플릿](../../../.github/pull_request_template.md) GH-08 기준): `Refs: DF-NNN`, `Trace: <PRD ID>`, 변경 파일 목록, 실행한 명령과 결과(마지막 20줄), 수용 기준별 증빙, 남은 질문(AS-DEV·Q-DEV 제안), '에이전트 작성' 표시.

### 8.1 DF-003 (레인 A · Codex)

| 항목 | 내용 |
|---|---|
| 스토리 | [DF-003] metric-catalog.v1.json과 vocab.v1.json을 부록 A·B에서 작성한다 |
| 목표 | 지표·어휘의 단일 원본 JSON 두 개를 만든다 |
| 필독 | `docs/PRD_V1.md` 부록 A(A.1~A.7), 부록 B.4·B.5, §9.3 / [05_DATA_MODEL_AND_RULES §13](../05_DATA_MODEL_AND_RULES.md) contracts JSON 형식 / [ADR-005](../adr/ADR-005-soap-schema-v2-contracts.md), [ADR-009](../adr/ADR-009-server-only-change-evaluation.md) / 이 문서 §7.2 |
| 브랜치 | `codex/DF-003-metric-catalog-vocab` (main에서 분기. DF-901 병합 전이면 병합 뒤 rebase) |
| 수정 허용 경로 | `contracts/metric-catalog.v1.json`, `contracts/vocab.v1.json`, `contracts/README.md` |
| 수용 기준 | 필드 완비([V1-05 §13.1](../05_DATA_MODEL_AND_RULES.md) `metrics[]` 항목 필드 표 전부). 22개 지표, 중복 0. vocab enum 33개(V1-05 §13.2), draft enum은 `status: draft`와 `confirmBy`. MDC 값 없음. `excludedMetricCodes` 3개 |
| 실행할 명령 | `jq empty contracts/*.json`, `jq '.metrics \| length' contracts/metric-catalog.v1.json`, `jq -r '.metrics[].metricCode' contracts/metric-catalog.v1.json \| sort \| uniq -d` |
| 산출물 | PR 1개(생성물 없음) |

### 8.2 DF-008 (레인 B · Claude)

| 항목 | 내용 |
|---|---|
| 스토리 | [DF-008] trainer_app 골격(XcodeGen, TrainerCore·TrainerKit 타깃, App Check)과 trainer-app CI를 만든다 |
| 목표 | 새 정본 트레이너 앱 폴더를 만들고, 생성 프로젝트 일치·macOS 패키지 테스트·iPad 시뮬레이터 스모크를 CI에서 초록으로 만든다 |
| 필독 | [P0 DF-008 카드](../backlog/P0.md#df-008)(정본) / [04_ARCHITECTURE](../04_ARCHITECTURE.md) §6.2·§6.3·§8.1 / [ADR-001](../adr/ADR-001-independent-trainer-app.md), [ADR-019](../adr/ADR-019-config-and-secrets.md) / [10_TEST_PLAN §19.4](../10_TEST_PLAN.md) / [13 플레이북](../13_DEV_ENVIRONMENT_AND_AGENT_PLAYBOOK.md) 도구 버전 / 이 문서 §5 ci.yml 순서 차례, §7.4 / 참고(읽기만): `trainer_ios/project.yml`, `trainer_ios/DFETTrainer/App/DFETTrainerApp.swift` |
| 브랜치 | `claude/DF-008-trainer-app-skeleton` |
| 수정 허용 경로 | `trainer_app/**`(단 `trainer_app/Packages/TrainerCore/Sources/TrainerContracts/Generated/**` 제외), `.github/workflows/trainer-app.yml`, `.github/workflows/ci.yml`(`ios-no-codesign` job에 NFR-01 grep step 1개, DF-004 병합 뒤 마지막 커밋으로만) |
| 금지 경로(추가) | `trainer_ios/**` 수정, `ios/**` 수정(grep으로 읽기만), `contracts/**`, 루트 `.gitignore`, `trainer_app/Config/GoogleService-Info.plist` 생성·커밋 |
| 수용 기준 | AC-DF-008.1~.6(P0 카드): iOS 17.0, `TARGETED_DEVICE_FAMILY "2"`, 번들 `kr.co.dfet.trainer`, 재생성 diff 0, macOS `swift test`(TrainerCore) 초록과 TrainerCore의 UIKit·SwiftUI·SwiftData·Firebase import 0, iPad 시뮬레이터 빌드·UI 스모크 초록, plist 없이 Release 빌드 성공(`.misconfigured` 화면), Firebase 제품 의존은 `FirebaseData`만, Runner grep 통과 |
| 실행할 명령 | `xcodegen version`(2.44.1이어야 함), `xcodegen generate --spec trainer_app/project.yml --project trainer_app && git diff --exit-code -- trainer_app/DFETTrainer.xcodeproj`, `swift test --package-path trainer_app/Packages/TrainerCore`, §7.4 워크플로의 `xcodebuild test`·`xcodebuild build -configuration Release` 명령 |
| 첫 작업 | 008-1(TrainerCore 패키지와 macOS `swift test`). 구성 스파이크는 없다(ASM-S01-02) |
| 산출물 | PR 1개. 재생성이 `Package.resolved`에 주는 영향(008-5)과 plist 유무별 빌드 결과를 PR 본문에 적는다 |

### 8.3 DF-001 (레인 C · Claude)

| 항목 | 내용 |
|---|---|
| 스토리 | [DF-001] docs/v1 문서군을 병합하고 AGENTS.md·CLAUDE.md에 v1 절을 링크한다 |
| 목표 | 개발 문서군과 GitHub 템플릿을 저장소에 넣고, 헤더 표준을 CI로 검사한다 |
| 필독 | [P0 DF-001 카드](../backlog/P0.md#df-001)(정본), [00_README](../00_README.md), [01_AGILE_WORKING_AGREEMENT](../01_AGILE_WORKING_AGREEMENT.md) 문서 변경 절, [10_TEST_PLAN §19.3](../10_TEST_PLAN.md#193-ciyml-개정-초안), 이 문서 §5·§7.5 |
| 브랜치 | `docs/DF-001-v1-docs` |
| 수정 허용 경로 | `docs/v1/**`, `.github/ISSUE_TEMPLATE/**`, `.github/pull_request_template.md`, `.github/CODEOWNERS`, `.github/workflows/ci.yml`(`changes-ci`·`docs-and-backlog` job 추가만, 순서 차례 1번), `tool/lint/doc-headers.mjs`, `tool/lint/test/**`, `AGENTS.md`·`CLAUDE.md`(끝에 절 추가만) |
| 수용 기준 | AC-DF-001.1~.5: `docs/v1/**` 헤더 표준·상대 링크 통과, 에이전트 진입 문서에서 V1-00·V1-13 링크, `docs/PRD_V1.md` 변경 없음, 이슈 폼 7종 렌더. 추가: `docs-and-backlog`가 경로 밖 PR에서 '건너뜀 = 통과'로 보고됨 |
| 실행할 명령 | `node tool/lint/doc-headers.mjs --links docs/v1`, `node --test tool/lint/test/doc-headers.test.mjs`, `git diff --exit-code origin/main -- docs/PRD_V1.md` |
| 산출물 | PR 1개. 화요일 오전 병합 목표(ci.yml 순서 차례 1번이라 DF-004·DF-008의 ci.yml 커밋이 이 병합을 기다린다) |

### 8.4 뒤이어 여는 지시서(요약)

| DF | 에이전트·착수 | 필독 | 수정 허용 경로 | 실행할 명령 |
|---|---|---|---|---|
| DF-004 | Codex, 화 오후(DF-003 병합 뒤. ci.yml 커밋은 DF-001 병합 뒤 마지막에) | [P0 DF-004 카드](../backlog/P0.md), ADR-005, 05 contracts 절, §7.3 | §5 레인 A 경로 | `npm ci --prefix tool`, `node tool/contracts/generate.mjs`, `node tool/contracts/generate.mjs --check`, `node --test tool/contracts/test/`, `npm --prefix functions run lint`, `flutter analyze lib/contracts`, `npm --prefix admin_web run typecheck` |
| DF-002 | Claude, 화 오후(레인 C 순서상 DF-001 다음) | [P0 DF-002 카드](../backlog/P0.md#df-002), [tool/backlog/README.md](../../../tool/backlog/README.md)(TL-01), 01 라벨·마일스톤 절, §7.6 | `tool/backlog/**`만(ci.yml 금지) | `node tool/backlog/validate_backlog.mjs --prd docs/PRD_V1.md tool/backlog/issues.json`, `bash tool/backlog/test/run.sh`, `bash tool/backlog/create_backlog.sh --dry-run --offline` |
| DF-005 | Claude, 목 오후(DF-003 병합 뒤, DF-004 병합 뒤 rebase) | [P0 픽스처 규약](../backlog/P0.md#fixture-contract), PRD §9.3, §11.4~§11.7, §7.7 | `contracts/fixtures/**`, `tool/contracts/test/fixtures.test.mjs` | `jq empty contracts/fixtures/*/*.json`, `node --test tool/contracts/test/` |

## 9. 이번 주 소유자 행동

| DF | 마감 | 소요 | 막는 것 | 상태 기록 |
|---|---|---|---|---|
| DF-901 MIG-01(G-01) | 화 12:00 병합 | 약 1.5일 | 모든 에이전트 PR 병합, 이식 기준선 | `docs/v1/evidence/G-01.md` |
| DF-903 Firebase 등록·App Attest | 수 | 1.5시간 | DF-034(S02), DF-012(S04), G-02 | `docs/v1/evidence/G-02.md` |
| DF-904 Q-22 | 수 | 30분 | DF-008 기기군 확정, T-07 | G-02.md |
| DF-930 동결 선언 | 수 | 30분 | 동결 예외 절차(DF-028, S04) | G-01.md |
| DF-913 Q-09 | 목 | 30분 | P0 진입 조건(PRD §13.3 기한 'P0 진입') | 00_README 결정 기록 |
| DF-908 법률 자문 의뢰 | 금 발송 | 반나절 | G-04, G-09(DF-909, S03), P1a 개방 | `docs/v1/evidence/G-04.md` |
| DF-902 백로그 생성 | 금 | 1시간 | Projects 보드 운영(S02부터) | GitHub |

다음 주 이후 미리 볼 소유자 일정: DF-905(S02, claim 테스트 계정·가상 회원 시드), DF-906·DF-909(S03), DF-911·DF-907·DF-916(S04), DF-910(S05, G-05b 보수 가정의 최신 제출일 10-30).

## 10. DoD 점검

공통 DoD는 [01_AGILE_WORKING_AGREEMENT](../01_AGILE_WORKING_AGREEMENT.md)가 정본이다. 이번 스프린트에서 확인할 항목만 적는다.

| 점검 | DF-001 | DF-002 | DF-003 | DF-004 | DF-005 | DF-008 |
|---|---|---|---|---|---|---|
| 필수 CI 초록(기존 4 job + 해당 신규 job). 경로 밖 신규 job은 '건너뜀 = 통과'로 보고됨 | ● | ● | ● | ● | ● | ● |
| `ci.yml` 변경은 순서 차례를 지켜 마지막 커밋에만 있음(§5) | ● | — | — | ● | — | ● |
| 수용 기준별 증빙이 PR 본문에 있음 | ● | ● | ● | ● | ● | ● |
| 커밋 footer `Refs: DF-NNN`, `Trace: …` | ● | ● | ● | ● | ● | ● |
| 생성물이 최신(`generate.mjs --check`) | — | — | — | ● | ● | ●(TrainerContracts 컴파일) |
| 재생성 diff 0(`xcodegen`) | — | — | — | — | — | ● |
| 같은 PR 동시 갱신: 어휘 변경 시 contracts와 생성물 | — | — | ● | ● | — | — |
| 합성 데이터만, 비밀·`output/`·`tmp/` 미포함 | ● | ● | ● | ● | ● | ● |
| 금지어: 새 사용자 문자열 없음(린트는 S02 DF-010 보고 모드부터) | ● | — | ● | ● | 예외 경로 | ● |
| 문서 헤더 표준 | ● | ●(README는 docs/v1 밖이라 비대상) | — | — | — | — |
| `docs/PRD_V1.md` 무변경 | ● | ● | ● | ● | ● | ● |
| 소유자 검토 완료 체크(GH-08) 후 소유자가 병합 | ● | ● | ● | ● | ● | ● |

소유자 행동의 완료 조건은 해당 증빙 문서가 [V1-T07](../templates/GATE_EVIDENCE.md) 형식으로 채워진 것이다. G-01은 이번 주에 '판정: 충족'까지 기록한다. G-02는 '진행 중'(S05 판정)이다.

## 11. 금요일 데모 스크립트

10-02(금) 15:00, 20분. 소유자가 직접 실행하고 결과를 [V1-T05](../templates/SPRINT_REVIEW.md)에 붙인다. 화면에는 합성 데이터와 공개 가능한 정보만 띄운다.

| 순서 | 시간 | 보여 줄 것 | 명령·화면 | 기대 결과 |
|---|---|---|---|---|
| 1 | 2분 | 기준선(G-01) | `git log --oneline -5 origin/main`, `git ls-remote origin archive/trainer-ui-2026-09`, `docs/v1/evidence/G-01.md` | A 커밋이 main에 있고, 보관 브랜치 해시가 증빙과 같다 |
| 2 | 2분 | main 보호와 CI | GitHub → Settings → Branches, Actions 최근 실행, 문서만 바꾼 증빙 PR의 Checks 탭 | 필수 체크 7개, 최근 main 실행 모두 초록, 증빙 PR에서 `trainer-app`이 '건너뜀'으로 보고되고 병합 가능 |
| 3 | 3분 | 계약 단일 원본 | `jq '.metrics \| length' contracts/metric-catalog.v1.json` → `node tool/contracts/generate.mjs --check` | 22, 종료 코드 0 |
| 4 | 2분 | 드리프트 차단 | `sed -i '' 's/"unit": "deg"/"unit": "cm"/' contracts/metric-catalog.v1.json` 한 곳 수정 → `node tool/contracts/generate.mjs --check` → `git checkout -- contracts/` | 종료 코드 1과 바뀐 생성물 목록, 되돌린 뒤 0 |
| 5 | 2분 | 픽스처 | `ls contracts/fixtures/soap_v2 contracts/fixtures/soap_legacy`, `node --test tool/contracts/test/` | v2 5개, 레거시 6개(P0 규약 4번 이름), 테스트 통과 |
| 6 | 4분 | 트레이너 앱 골격 | `xcodegen generate --spec trainer_app/project.yml && git diff --exit-code -- trainer_app/DFETTrainer.xcodeproj`, `swift test --package-path trainer_app/Packages/TrainerCore`, 시뮬레이터에서 `--preview-empty` 실행 | diff 0, 테스트 통과, iPad 시뮬레이터에 자리 표시 루트 화면 |
| 7 | 2분 | 문서·백로그 | `node tool/lint/doc-headers.mjs --links docs/v1`, `bash tool/backlog/create_backlog.sh --dry-run`, GitHub Projects 'D-FET Coach v1' 보드 | 린트 0건, dry-run '생성 0건'(이미 생성됨), 보드에 P0 이슈와 소유자 행동 이슈 |
| 8 | 3분 | 게이트 트랙 | G-02.md(등록·Q-22), G-04.md(발송일), 00_README 결정 기록(Q-09), [03 §5.2](../03_RELEASE_AND_SPRINT_PLAN.md#5-게이트-타임라인과-소유자-병렬-트랙) 여유 열 | 모든 트랙 초록 또는 노랑. 빨강이면 T-02 조치 기록 |

데모에서 보여 주지 않는 것: 콘솔의 키·앱 ID 값, plist 내용, 법률 의뢰서 본문, 실회원 정보.

## 12. 위험과 대응

| 위험 | 가능성 | 영향 | 신호 | 대응 |
|---|---|---|---|---|
| DF-901이 화요일 정오를 넘긴다(hunk 분리 난도, CI 실패) | 중 | 상: 모든 병합 지연 | 월 18:00 기준 A 커밋 미완 | 새 경로 작업은 계속 진행(병합만 대기). 수요일 정오까지 안 되면 DF-005를 S02로 넘기고 DF-002·DF-004 병합을 목·금으로 민다 |
| B 분류 코드가 main에 섞인다 | 하 | 상: 이식 기준선 오염, 규칙에 로컬 UUID 경로 잔존 | `git grep trainerWorkspaces origin/main` 결과 | PR 병합 전 901-6의 grep 확인 필수. 섞였으면 되돌림 커밋 |
| C 분류 파일(`output/`, `tmp/`)이 실수로 스테이징된다 | 중 | 상: 개인정보 노출 가능 | `git diff --cached --name-only`에 해당 경로 | 커밋 직전 확인 명령(901-3), `.gitignore` 추가(ASM-S01-10) |
| 필수 체크가 경로 밖 PR에서 보고되지 않아 병합이 막힌다('Expected — waiting') | 중 | 상: S02 PR(DF-006·007·010) 전체 병합 불가 | 문서만 바꾼 PR의 Checks 탭 | 워크플로 수준 `paths` 금지, `changes-*` job + job 수준 `if`(ASM-S01-05). 902-2 사전 확인 뒤에만 필수 체크 추가 |
| TrainerCore 소스에 UIKit·SwiftUI가 섞여 macOS `swift test`가 깨진다 | 중 | 중 | CI `swift test` 실패 | AC-DF-008.3 import grep, UIKit 코드는 TrainerKit에 둔다(ADR-001) |
| XcodeGen 버전 차이로 재생성 diff가 난다 | 중 | 중 | CI diff 단계 실패 | `.xcodegen-version` 고정(2.44.1)과 릴리스 zip SHA-256 대조(ASM-S01-09). 2026-09-24 기준 Homebrew 안정판은 2.46.0이라 `brew install`은 고정이 되지 않는다. 로컬도 `xcodegen version`이 2.44.1인지 확인 |
| Firebase SPM 해석·빌드가 느려 CI 45분을 넘긴다 | 중 | 중 | trainer-app job 시간 | `.spm` 캐시, `-clonedSourcePackagesDirPath` 고정. 넘으면 UI 스모크를 야간으로 분리 제안 |
| `.github/workflows/ci.yml` 동시 수정 충돌 | 중 | 하 | DF-004·DF-008 rebase 충돌 | ci.yml 순서 차례(§5): DF-001 → DF-004 → DF-008, 각자 마지막 커밋에만 변경 |
| plist 없는 환경에서 앱 빌드가 실패한다 | 하 | 중: AC-DF-008.4 실패, 에이전트 로컬 빌드 불가 | `Build input file cannot be found` | plist를 소스로 참조하지 않고 빌드 후 복사 스크립트 사용(ASM-S01-12) |
| plist가 저장소에 들어간다 | 하 | 상 | `git status`에 `GoogleService-Info.plist` | 저장소 밖 보관(ASM-S01-08), `trainer_app/.gitignore`(008-5), 커밋 직전 grep |
| 법률 의뢰서에 특허 관련 내용이 섞인다(Q-17) | 하 | 중 | 첨부 목록 | 첨부는 §7.8 908-1의 발췌만 |
| Q-22 결과가 Universal | 하 | 중 | ASC 빌드 이력 | T-07: S02에 project.yml 한 줄 수정 PR, compact 제한 기능 스토리 추가 |
| 소유자 검토 대기로 에이전트가 쉰다 | 중 | 하 | PR 대기 1일 초과 | 주경로 PR(DF-003·004·008) 당일 검토 원칙, 다른 PR은 다음 날 오전 |

## 13. 가정(ASM)

이 문서의 가정은 문서 접두 번호 ASM-S01-NN(현재 ASM-S01-01~ASM-S01-13)을 쓴다. 03 문서는 ASM-03-NN, P0 백로그는 ASM-P0-NN이다.

| ID | 가정 | 관련 PRD·스파인 | 검증 |
|---|---|---|---|
| ASM-S01-01 | DF-901은 반나절에 끝나지 않고 약 1.5일(월 전일 + 화 오전)이 걸린다. 그동안 에이전트는 기존 미커밋 파일과 겹치지 않는 새 경로 작업만 착수하고, 병합은 DF-901 뒤에 한다 | MIG-01, D13, RISK-04. 백로그 스파인 '1일차 오전 완료'와 다름([03 D-4](../03_RELEASE_AND_SPRINT_PLAN.md#14-가정asm과-스파인prd와의-차이)) | S01 회고에서 실측 |
| ASM-S01-02 | DF-008의 패키지 구성은 ADR-001(Accepted)·V1-04 §6.2~§6.3·P0 DF-008 카드의 두 패키지(`TrainerCore` 순수 5타깃, `TrainerKit` iOS 전용)이고, 제품은 타깃마다 하나씩 선언한다. 한 패키지에 UIKit 타깃이 있으면 macOS `swift test`가 실패한다는 것은 2026-09-24에 이미 확인됐으므로(V1-04 ASM-04-01) 이번 스프린트에 구성 스파이크를 두지 않는다 | NFR-03, ADR-001, 기술 스파인 repoLayout(TrainerKit 단일 패키지와 다름) | DF-008 CI |
| ASM-S01-03 | 저장소 루트 Node 도구의 공용 `tool/package.json`은 DF-004가 만들고 의존성은 `ajv@^8`, `ajv-formats@^3`뿐이다. `tool/lint/doc-headers.mjs`(DF-001), `tool/backlog/validate_backlog.mjs`(DF-002), `tool/lint/prohibited-terms.mjs`(DF-010)는 Node 22 내장 모듈만 쓴다(각 P0 카드) | ADR-005, ADR-017(새 의존성 규칙은 functions 기준) | DF-004 검토 |
| ASM-S01-04 | 픽스처 표기는 [P0 DF-005 픽스처 규약](../backlog/P0.md#fixture-contract)을 따른다: 봉투 `_fixture`·`path`·`data`, 태그 `$ts`·`$serverTimestamp`·`$bytes`·`$int`, 합성 ID `fx-`(레거시 예외 `native_fx_<yyyymmdd>`, `member-00000000-0000-4000-8000-00000000000N`). 이 문서의 초안에 있던 `$timestamp` 표기는 쓰지 않는다 | F-SOAP-06, §9.3 변경 절차 3, ASM-P0-01 | DF-005, DF-007·DF-009(S02) |
| ASM-S01-05 | 필수 체크가 되는 job은 워크플로 수준 `on.*.paths` 필터를 쓰지 않는다. 경로 조건은 항상 도는 `changes-*` job의 출력과 job 수준 `if`로 건다. GitHub는 조건으로 건너뛴 job을 필수 체크 '통과'로 보고하지만, `paths` 필터로 워크플로가 뜨지 않으면 체크가 'Expected — waiting'으로 남아 병합이 막힌다. `docs-and-backlog`는 기술 스파인·[10 §19.2](../10_TEST_PLAN.md)대로 `ci.yml` 안의 job이고(`changes-ci` 사용), `trainer-app`은 `trainer-app.yml` 안에서 `changes-trainer`를 쓴다 | 기술 스파인 ciJobs, 10 ASM-10-14 | DF-001·DF-008 PR에서 경로 밖 PR의 체크 보고 확인(902-2) |
| ASM-S01-06 | Firebase iOS SDK는 trainer_ios와 같은 `from: 11.0.0` 범위를 쓰고(dfet:trainer_ios/project.yml:10-13), `TrainerKit/Package.swift`에서만 선언한다(V1-04 ASM-04-11). 해석 결과는 `trainer_app/DFETTrainer.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`를 커밋해 고정한다 | NFR-14, ADR-001 | DF-008(008-5) |
| ASM-S01-07 | DF-901 PR은 주제별 커밋을 보존하려고 스쿼시가 아닌 rebase 병합을 쓴다(선형 이력 규칙과 양립). 이후 PR은 스쿼시 병합 원칙을 따른다 | ADR-014 | DF-901 |
| ASM-S01-08 | `GoogleService-Info.plist`는 DF-034(S02)에서 CI 시크릿 주입이 준비될 때까지 저장소 밖에 둔다 | ADR-019, G-02, AS-DEV-04 | DF-034 |
| ASM-S01-09 | XcodeGen 버전은 로컬 설치본 2.44.1(2026-09-24 확인)로 고정한다. CI는 GitHub 릴리스 `xcodegen.zip`(SHA-256 `a2e905fb68446e9bb4008cdfe2e13e3f176d0cbcca828b71770f8e53fca91b73`, 압축 안 경로 `xcodegen/bin/xcodegen`, 2026-09-24 확인)을 내려받아 쓴다. 같은 날 Homebrew 안정판은 2.46.0이라 `brew install xcodegen`은 버전이 고정되지 않는다. 10_TEST_PLAN §19.4와 P0 DF-008 카드의 설치 단계도 이 방식으로 맞출 것을 제안한다 | ADR-001(`.xcodegen-version` 고정), AS-DEV-06 | DF-008 CI |
| ASM-S01-10 | `output/`, `tmp/`는 현재 `.gitignore`에 없다(2026-09-24 확인). 소유자가 MIG-01 A 커밋에서 무시 규칙에 추가할지 결정한다 | MIG-01 C 분류, PRD §11.2 '.gitignore 검토' | DF-901 |
| ASM-S01-11 | 이슈는 단계별로 나눠 만든다: S01에 P0와 소유자 행동, 이후 각 단계 첫 계획 회의에서 해당 단계 JSON. 이를 위해 `create_backlog.sh`(구현 `create_github_issues.sh`)에 `--only`, `--phase`, `--owner-actions` 옵션을 둔다 | 기술 스파인 TL-11 | DF-002 |
| ASM-S01-12 | 트레이너 앱의 `GoogleService-Info.plist`는 `project.yml` 소스로 참조하지 않고, 앱 타깃 `postBuildScripts`로 있을 때만 번들에 복사한다(`ENABLE_USER_SCRIPT_SANDBOXING: NO`). 2026-09-24 로컬 검증(XcodeGen 2.44.1, Xcode 26.0, 합성 프로브): `optional: true` 참조는 생성물이 plist 유무와 무관하게 같지만 plist가 없으면 `Build input file cannot be found`로 빌드가 실패했다. 복사 스크립트 방식은 생성물이 같고 plist 없이 빌드가 성공했으며, plist가 있으면 번들에 들어갔다. 따라서 P0 DF-008 카드의 방식이 맞고, V1-04 §6.3 `project.yml` 요지의 `optional: true` 항목과 P0 카드의 사유 문장('생성물이 달라진다')은 이 결과로 고칠 것을 제안한다 | ADR-019, G-02, AC-DF-008.4 | DF-008 PR에서 plist 유무별 빌드 결과 첨부 |
| ASM-S01-13 | owner-action·스파이크 점수는 약속과 속도에 포함한다(R1, [02 §4.3](../02_PRODUCT_BACKLOG.md#43-용량과-보정), [01 ASM-01-16](../01_AGILE_WORKING_AGREEMENT.md#가정과-스파인-차이-기록)). 그래서 이번 약속은 18점 = 개발 15 + 소유자 행동 3이고, S01 완료 점수에도 소유자 행동 점수를 넣는다. 소유자 실제 시간은 V1-T05 '소유자 시간' 표에 따로 적는다 | AS-DEV-09, 백로그 스파인 velocity | S01 리뷰에서 완료 점수 기록 |

## 14. 회고 질문과 다음 스프린트 준비

회고 질문(10분):
1. DF-901 실제 소요 시간과 ASM-S01-01의 차이는? MIG-01 절차에서 11_MIGRATION_RUNBOOK에 반영할 점은?
2. 에이전트 PR 6개 중 반려·재작업이 있었나? 원인이 지시서(필독·허용 경로) 부족이었나?
3. TrainerCore·TrainerKit 분리, plist 복사 스크립트, 고정 XcodeGen 설치가 로컬과 CI에서 문제없었나? 10_TEST_PLAN §19·V1-04 §6.3에 반영할 차이는?
4. 소유자 검토가 하루 이상 걸린 PR이 있었나? S02(3일)에서 같은 일이 생기지 않으려면?
5. 게이트 트랙에서 노랑·빨강이 생겼나?

S02 준비(10-06 화 오전 계획 회의 전까지):
- S02 약속(11점): DF-006, DF-007, DF-009, DF-010, DF-034, DF-905. 모두 이번 주 산출물(DF-003·004·005·008)에 의존하므로, 금요일에 이 넷이 병합되지 않으면 S02 약속을 줄인다.
- S01 완료 점수를 기록한다. 속도 보정은 S02 종료 뒤 S03 계획(10-12)에서 8작업일 기준으로 한다([03 §3.2](../03_RELEASE_AND_SPRINT_PLAN.md#3-달력-휴일과-스프린트-용량)).
- `docs/v1/sprints/SPRINT_02.md`를 [V1-T04](../templates/SPRINT_PLAN.md)로 만든다. S02의 쓰기 경로 분리(`generate.mjs`는 DF-010만, 메타 스키마는 DF-006만, DF-009는 `#filePath`로 픽스처 직접 읽기)는 [03 §6.1 S02 행](../03_RELEASE_AND_SPRINT_PLAN.md#61-p0p1b-주-단위)을 따른다.

## 15. 변경 이력

| 버전 | 날짜 | 변경 요지 | PR | PRD 영향 |
|---|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성 | — | 없음 |
| v1.0(검토 반영) | 2026-09-24 | 필수 체크 워크플로 `paths` 제거(changes-* job), §7.4 DF-008을 TrainerCore·TrainerKit·postBuildScripts·XcodeGen zip으로 재작성, ci.yml 직렬 순서, DF-005 픽스처 규약 정렬, 구 가정 번호 51~61 → ASM-S01-01~12 | — | 없음 |
| v1.0(정합 패스 2) | 2026-09-24 | §7.2를 V1-05 §13 링크로 축소(R5), 속도 포함 규칙 기록(R1, ASM-S01-13) | — | 없음 |
| v1.0.1 | 2026-09-24 | 교차 정합성 조정: §7.2·§7.3·§8.1의 contracts 값을 V1-05 §13 정본(`excludedMetricCodes`, `confirmed`, enum 33개)으로 맞추고 ASM-S01-13(R1) 추가 | — | 없음 |
