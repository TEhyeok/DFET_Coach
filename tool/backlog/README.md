# 백로그 도구(tool/backlog)

| 항목 | 내용 |
|---|---|
| 문서 ID | TL-01 |
| 버전 | v1.1.1 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24(개정 2026-09-25) |
| 소유자 | CJH |
| 근거 PRD 절 | §0.5 ID 체계, §12.1 단계 |
| 관련 에픽·스토리 | EP-01 / DF-002(도구 검증·작업 지시서 생성기), DF-902(소유자 실행) |
| 변경 규칙 | [문서 변경](../../docs/v1/01_AGILE_WORKING_AGREEMENT.md#문서-변경) |

## 목차

- [1. 무엇이 있나](#1-무엇이-있나)
- [2. 데이터 흐름](#2-데이터-흐름)
- [3. 소유자 실행 순서](#3-소유자-실행-순서)
- [4. 옵션](#4-옵션)
- [5. 멱등성과 안전장치](#5-멱등성과-안전장치)
- [6. 테스트와 CI](#6-테스트와-ci)
- [6a. 작업 지시서 생성기(brief.mjs)](#6a-작업-지시서-생성기briefmjs)
- [7. 백로그를 바꿀 때](#7-백로그를-바꿀-때)
- [8. 문제 해결](#8-문제-해결)
- [변경 이력](#변경-이력)

## 1. 무엇이 있나

| ID | 파일 | 역할 |
|---|---|---|
| TL-01 | `README.md` | 이 안내 |
| TL-02 | `labels.json` | 라벨 67개(이름·색·설명·그룹). 적용 규칙은 [02 §3](../../docs/v1/02_PRODUCT_BACKLOG.md#3-라벨-체계) |
| TL-03 | `milestones.json` | 단계 마일스톤 6개와 게이트 추적 마일스톤 3개(`trackingOnly`, 이슈 미배정). 목표일은 [03 §4.1](../../docs/v1/03_RELEASE_AND_SPRINT_PLAN.md#41-단계-요약) |
| TL-04 | `issue.schema.json` | 이슈 항목 스키마 |
| TL-05 | `issues.json` | **생성물.** 에픽 24개 + 항목 208개(채택 192, 추가 제안 16). 손으로 고치지 않는다 |
| TL-11 | `create_github_issues.sh` | gh CLI로 라벨·마일스톤·보드 필드·이슈를 만든다. 기본 dry-run |
| TL-11 | `create_backlog.sh` | 호환 진입점. 문서에 적힌 이름을 유지하려고 두며 `create_github_issues.sh`를 그대로 부른다 |
| TL-12 | `validate_backlog.mjs` | 스키마·키·라벨·마일스톤·의존 순환·PRD trace·카드/색인/스프린트 교차 검사 |
| TL-13 | `brief.mjs` | 카드와 `issues.json`에서 AI 에이전트 작업 지시서(V1-T08)를 만든다(ASM-01-17). 파일만 읽는다 |
| TL-14 | `build_issues.mjs` | 색인·카드에서 `issues.json`을 만든다. `--check`는 드리프트 검사 |
| — | `test/fake-gh.sh`, `test/run.sh` | 네트워크 없는 가짜 gh 시나리오 테스트. node:test와 shellcheck도 여기서 돈다 |
| — | `test/validate_backlog.test.mjs`, `test/brief.test.mjs` | 검증기 검출 테스트(TC-DF002-03), 지시서 생성기 테스트(node:test) |

기술 스파인은 이슈 데이터를 단계별 파일(`issues/P0.json` 등 TL-05~TL-10)로 나누도록 제안했다. 단일 파일 `issues.json`과 `--phase`·`--owner-actions` 선택 옵션으로 바꿨다. 한 파일이어야 생성기 하나로 드리프트를 막을 수 있고, 단계별 생성은 옵션으로 같은 결과를 낸다.

## 2. 데이터 흐름

```
docs/v1/02_PRODUCT_BACKLOG.md §6 에픽, §8 색인   ← 키·제목·유형·에픽·영역·단계·스프린트·점수·우선·의존·PRD 추적(정본)
docs/v1/backlog/*.md 카드                        ← 사용자 스토리·수용 기준·구현 노트·테스트·라벨(본문 정본)
        │ node tool/backlog/build_issues.mjs
        ▼
tool/backlog/issues.json ── validate_backlog.mjs ──▶ CI(docs-and-backlog)
        │ bash tool/backlog/create_github_issues.sh --apply (소유자만)
        ▼
GitHub TEhyeok/DFET_Coach: 라벨, 마일스톤, 이슈, Projects 'D-FET Coach v1'
```

- 라벨 계산: `type/`·`area/`·`phase/`·`prio/`·`size/`는 색인 값에서 만든다(0점은 size 없음). 소유자 행동은 `type/task` + `owner-action` + `agent/human` + PRD 추적의 `gate/G-NN`. 카드 Labels 줄의 나머지(`agent/`, `flag/`, `gate/`, 위험 표시)를 더한다. 추가 제안은 `status/needs-decision`, V2는 `status/blocked`.
- 마일스톤: 단계와 같다. 단, P0 키 중 S06 이후 배정 8건(DF-014·015·016·018·026·032·033·039)은 'P1a 알파-기록'이다(02 ASM-02-02).
- 의존: `deps`는 색인 값(정본). 카드가 더한 의존 중 같은/앞선 스프린트인 것은 색인에 반영했다(02 ASM-02-15). `cardDeps`에는 채택 대기 제안 키 의존만 남는다. 스프린트가 역전되는 의존은 카드 본문에 참고(soft)로만 적고 `Depends on` 칸에 넣지 않는다. 이슈 본문에는 둘 다 보이고, 제안 키는 '(제안)'으로 표시한다.
- 본문: 머리말(키·유형·에픽·단계·스프린트·점수·우선, 원본 카드와 색인 링크) + 링크 블록 + PRD 추적 + 카드 전문. 카드 안 상대 링크는 `https://github.com/TEhyeok/DFET_Coach/blob/main/...` 절대 링크로 바꾼다.

## 3. 소유자 실행 순서

DF-002가 병합된 main에서 실행한다(DF-902, S01 금요일). 에이전트는 `--apply`를 실행하지 않는다.

```bash
# 0) 권한: 보드를 쓰려면 project 범위가 필요하다
gh auth refresh -s project,read:project

# 1) 계획 확인(네트워크 호출 없음)
bash tool/backlog/create_github_issues.sh

# 2) 라벨·마일스톤
bash tool/backlog/create_github_issues.sh --apply --only labels,milestones

# 3) 보드(이미 있으면 번호만 쓴다) → 필드 Points·Sprint·Phase
bash tool/backlog/create_github_issues.sh --apply --only project --create-project   # 출력된 번호를 기억
export PROJECT_NUMBER=<번호>
bash tool/backlog/create_github_issues.sh --apply --only project

# 4) S01 범위 이슈: 에픽 24개 + P0 + 소유자 행동(추가 제안은 결정 뒤)
bash tool/backlog/create_github_issues.sh --apply --only issues --phase P0 --owner-actions --exclude-proposals

# 5) 같은 명령을 다시 실행해 'created 0'을 확인한다
bash tool/backlog/create_github_issues.sh --apply --only issues --phase P0 --owner-actions --exclude-proposals

# 이후 각 단계 첫 계획 회의에서
bash tool/backlog/create_github_issues.sh --apply --only issues --phase P1a --exclude-proposals
```

- Projects의 1주 Iteration 필드는 gh CLI로 만들 수 없어 웹에서 만든다. 스크립트는 텍스트 필드 `Sprint`에 색인의 스프린트 값(S01, S19-S20 등)을 넣는다.
- 추가 제안을 채택하면 02 §8.8 절차대로 색인·카드를 고치고 `build_issues.mjs`를 다시 돌린 뒤 `--keys DF-041`처럼 만든다. 채택 전에 만들고 싶으면 `--exclude-proposals` 없이 실행한다(`status/needs-decision` 라벨이 붙는다).

## 4. 옵션

| 옵션 | 뜻 | 기본 |
|---|---|---|
| `--dry-run` | 계획만 출력. gh를 부르지 않는다 | 기본 |
| `--apply` | 실제 실행 | — |
| `--offline` | dry-run 별칭(문서 호환). `--apply`와 함께 쓰면 오류 | — |
| `--only` | `labels,milestones,project,issues,relink` 중 쉼표 목록 | 전부 |
| `--phase` / `--sprint` / `--keys` / `--owner-actions` | 선택(합집합). 아무것도 없으면 전체 | 전체 |
| `--exclude-proposals` | 추가 제안 제외 | 포함 |
| `--no-epics` | 에픽 이슈 제외 | 포함 |
| `--repo` | 대상 저장소 | `TEhyeok/DFET_Coach` |
| `--files` | 이슈 JSON | `tool/backlog/issues.json` |
| `--project-owner`, `--project-number`(또는 `PROJECT_NUMBER`) | 보드 | owner=저장소 소유자 |
| `--create-project` | 보드 'D-FET Coach v1' 생성 | — |
| `--skip-tracking-milestones` | 게이트 추적 마일스톤 생략 | 생성 |
| `--delay <초>` | 이슈 생성 간격(보조 속도 제한 회피) | 1 |

필요 도구: bash 3.2 이상, jq. `--apply`에는 gh와 `repo` 범위, 보드를 쓰면 `project`·`read:project` 범위가 필요하다.

## 5. 멱등성과 안전장치

- **dry-run은 네트워크를 쓰지 않는다.** gh를 한 번도 부르지 않으므로 이미 있는 이슈 여부는 `--apply`에서만 확인한다.
- **중복 방지.** `--apply`는 시작할 때 `gh issue list --state all --limit 3000`으로 제목을 한 번 모두 읽어 `[DF-NNN]`·`[EP-NN]` 접두로 맵을 만든다. 검색 API(`--search`)는 색인 지연과 대괄호 무시 때문에 쓰지 않는다(P0 DF-002 카드). 3000건 이상이면 멈춘다. 만든 이슈는 즉시 맵에 넣어 같은 실행 안의 중복도 막는다.
- **라벨** `--force`로 색·설명만 갱신한다. **마일스톤**은 제목으로 찾아 없으면 만들고, 목표일·설명이 다르면 고친다. 목표일은 KST 23:59:59(= 14:59:59Z)로 보낸다.
- **링크 블록.** 본문의 `<!-- df-links:start -->`~`<!-- df-links:end -->` 사이만 다시 쓴다. 이번 실행에서 만든 이슈와 그 에픽은 끝에 자동으로 #번호로 바꾼다. 나머지는 `--only relink`로 바꾼다. 블록 밖 본문은 건드리지 않는다.
- **에픽 하위 항목**은 `- [ ] #번호` 작업 목록이라 GitHub가 진행률을 보여 준다. 의존은 `- #번호 DF-NNN` 목록이다.
- 보드 추가(`item-add`)는 이미 있는 항목에도 안전하다. 에픽은 보드에만 넣고 Points를 채우지 않는다(속도 합계 오염 방지).

## 6. 테스트와 CI

```bash
node tool/backlog/build_issues.mjs --check                       # issues.json 드리프트
node tool/backlog/validate_backlog.mjs --prd docs/PRD_V1.md       # 검증기
bash tool/backlog/test/run.sh                                     # node:test + shellcheck + 가짜 gh 시나리오 + 검증기
bash tool/backlog/create_backlog.sh --dry-run --offline > /dev/null
```

docs-and-backlog CI job(DF-001)이 위 네 명령을 실행한다. DF-002는 `ci.yml`을 고치지 않는다(SPRINT_01 §7.6 002-4). P0 DF-002 카드 AC-DF-002.5의 `node --test tool/backlog/test/`와 `shellcheck`는 `test/run.sh` 안에서 돈다.

`test/run.sh`가 확인하는 것:

| 단계 | 내용 | 수용 기준 |
|---|---|---|
| 0a | `node --test tool/backlog/test/*.test.mjs`(Node 22는 디렉터리 인자를 펼치지 않아 glob으로 부른다) | AC-DF-002.3·.4, TC-DF002-03 |
| 0b | `shellcheck tool/backlog/*.sh tool/backlog/test/*.sh`. 설치돼 있지 않으면 로컬에서는 `skip`을 출력하고, `CI=true`면 실패한다(러너 이미지가 바뀌어도 조용히 빠지지 않게) | AC-DF-002.5, TC-DF002-05 |
| 1 | 가짜 gh를 PATH 맨 앞에 두고 `create_backlog.sh`를 인자 없이, 그리고 `--dry-run --offline`으로 실행. gh 호출 0건(변경 호출 0건 포함), 끝 줄 `== plan: labels 67, milestones 9, issues 232` | AC-DF-002.1, TC-DF002-01·05 |
| 2 | 기존 이슈 `#1 [DF-001]`을 심고 `create_backlog.sh --apply --repo TEhyeok/DFET_Coach`(P0 + 소유자 행동, 제안 제외)를 두 번 실행. DF-001 `issue create` 0건, 다른 키는 첫 실행에 한 번씩(102건), 두 번째 0건, 실행마다 `issue list --state all --limit 3000 --json number,title` 1회, `--search` 0건, 마일스톤 9개 | AC-DF-002.2, TC-DF002-02 |
| 3 | 에픽 하위 항목·의존 링크의 #번호 치환(기존 DF-001은 `#1`), 다음 단계 추가 뒤 기존 에픽 목록 갱신 | — |
| 4·5 | 검증기(`PRD` 환경 변수, 기본 `docs/PRD_V1.md`. PRD가 없으면 로컬은 skip, `CI=true`면 실패), `build_issues.mjs --check` | AC-DF-002.3 |

`test/validate_backlog.test.mjs`는 실제 `issues.json`을 임시 폴더에 같은 이름으로 복사해 한 곳만 바꾼 뒤 검증기가 exit 1과 `issues.json: <KEY> <메시지>`를 내는지 본다: 없는 trace(`F-SOAP-99`와 PRD 접두 14종), 범위 양 끝, 없는 §, 중복 키, 없는 라벨·마일스톤·에픽·의존 대상, `deps`·`cardDeps` 순환, 스키마 required·type·enum.

## 6a. 작업 지시서 생성기(brief.mjs)

[V1-T08](../../docs/v1/templates/AGENT_BRIEF.md) '사용법'과 [01 작업 지시서 규칙](../../docs/v1/01_AGILE_WORKING_AGREEMENT.md#작업-지시서-규칙)의 생성기다(ASM-01-17, 00_README K-04). 카드(`docs/v1/backlog/*.md`), `issues.json`, 스프린트 문서(`docs/v1/sprints/SPRINT_NN.md`)만 읽고 표준 출력으로 Markdown을 낸다. gh·git·네트워크를 쓰지 않는다.

```bash
node tool/backlog/brief.mjs DF-011 > brief.md                  # 목요일 다듬기
node tool/backlog/brief.mjs DF-011 --sprint S03 > brief.md     # 월요일 계획: 같은 스프린트의 다른 에이전트 작업을 4절에 덧붙인다
node tool/backlog/brief.mjs DF-005 --agent claude --slug soap-fixtures   # 배정 에이전트·브랜치 이름을 바꿀 때
```

| 절 | 원천 |
|---|---|
| 0·10·11 | 고정문(V1-T08 템플릿) |
| 1 목표 | 카드 '사용자 스토리' |
| 2 추적 | `issues.json`의 key·epic·phase·sprint·points·prio·`flag/` 라벨·trace, 카드 안 ADR 언급 |
| 3 컨텍스트 팩 | 카드 링크, 01 DoD(area별), 13 §7, 13 §6 area별 필독, trace의 PRD §, 스프린트 문서 '필독' |
| 4 작업 범위 | 스프린트 문서의 수정 허용·금지 경로(§8 지시서 표 → §8.4 요약 표 → §5 레인 표 순), 카드 '에이전트 브리프'. `--sprint`면 같은 스프린트의 다른 `agent/claude`·`agent/codex` 스토리와 그 경로 |
| 5 인터페이스 계약 | 카드 '구현 노트' 원문 |
| 6 수용 기준 | 카드 '수용 기준'과 '테스트' 원문(바꿔 쓰지 않는다) |
| 7 구현 메모 | 카드 '배경·맥락', '비고·가정', 'DoR' |
| 8 검증 명령 | area별 기본 명령(01 영역별 DoD, 13 §4) + 수정 경로별 명령 + 스프린트 문서·카드의 인라인 명령. `--apply`, `firebase deploy`, gh 쓰기, 자리 표시자(`<…>`, `DF-NNN`)가 든 명령은 넣지 않는다. 수용 기준·테스트 중 '소유자가' 실행하는 줄의 명령, 에뮬레이터(`firebase emulators:exec`, `--emulator`) 밖의 `functions/scripts/(migrations\|research)/`, `$GITHUB_*`를 쓰는 CI 전용 줄, `--check` 없는 `tool/contracts/generate.mjs`, cwd 기준 `test/` 경로, 실행 파일 뒤에 공백·인자가 없는 낱말(`node:test`, `swift-snapshot-testing`, 맨 `flutter`)도 뺀다 |
| 9 브랜치·커밋 | 브랜치는 스프린트 문서 → `--slug` → 제목의 영문 낱말 순. 에이전트는 `--agent` → (`--sprint`를 줬으면) 스프린트 문서 레인·브랜치 → `agent/` 라벨 순. 스프린트 문서와 라벨이 다르면 stderr에 경고한다(예: DF-005, 문서는 Claude 레인 C, 라벨은 `agent/codex`). 커밋 type은 이슈 type, scope는 area. footer `Refs`·`Trace` |

- 종료 코드: 0 성공, 1 대상 아님(없는 키, 소유자 행동·`agent/human`만 있는 항목, 에이전트 라벨 없음 → `--agent`로 지정, 카드 없음), 2 사용법 오류.
- 카드 안 상대 링크는 `https://github.com/TEhyeok/DFET_Coach/blob/main/...` 절대 링크로 바꾼다(이슈 코멘트에서 상대 링크가 깨진다). `build_issues.mjs`와 같은 규칙이다.
- 지시서를 이슈 코멘트로 붙이는 일은 소유자가 한다(01 다듬기 3번). 생성기는 GitHub에 쓰지 않는다.

## 7. 백로그를 바꿀 때

1. [02 §8 색인](../../docs/v1/02_PRODUCT_BACKLOG.md#8-전체-스토리-색인)과 단계 카드를 같은 PR에서 고친다(02 §5.2).
2. `node tool/backlog/build_issues.mjs`로 `issues.json`을 다시 만든다.
3. `node tool/backlog/validate_backlog.mjs --prd docs/PRD_V1.md`가 통과해야 한다.
4. 이미 만든 GitHub 이슈의 제목·라벨·본문은 스크립트가 **고치지 않는다**(링크 블록만 예외). 바뀐 내용은 소유자가 이슈에서 직접 고치거나 카드 링크로 대신한다.

## 8. 문제 해결

| 증상 | 원인·조치 |
|---|---|
| `milestone ... not found`로 이슈 생성 실패 | `--only milestones`를 먼저 실행 |
| `could not add label` | `--only labels`를 먼저 실행 |
| 보드 명령 권한 오류 | `gh auth refresh -s project,read:project` |
| 보조 속도 제한(secondary rate limit) | `--delay 3`으로 다시 실행. 이미 만든 이슈는 건너뛴다 |
| `issues.json is stale` | `node tool/backlog/build_issues.mjs` 후 커밋 |
| 검증기 `trace ... not found in PRD` | 색인의 PRD 추적 값을 PRD 원문 ID로 고친다. 새 PRD ID는 만들지 않는다 |

## 변경 이력

| 버전 | 날짜 | 요약 |
|---|---|---|
| v1.1.1 | 2026-09-25 | 소유자 결정 2026-09-25(DEC-19 서울 리전 전환 DF-043·DF-942 추가)로 이슈 수 갱신: 항목 208개(채택 192), dry-run 계획 232건, P0 + 소유자 행동 apply 102건. 로직 변경 없음 |
| v1.1.0 | 2026-09-25 | DF-002: TL-13 `brief.mjs`(작업 지시서 생성기)와 §6a 추가. `test/run.sh`가 node:test·shellcheck와 AC-DF-002.1·.2 시나리오(인자 없는 dry-run, 기존 `[DF-001]` 이슈를 둔 두 번 apply)를 그대로 돌리도록 §6 갱신. dry-run 끝에 계획 요약 줄. 검토 반영: §8 검증 명령에서 소유자 실행·운영 데이터 스크립트·비명령 낱말을 빼고, 스프린트 문서와 에이전트 라벨 불일치를 경고하며, `run.sh`가 CI에서 shellcheck·PRD 누락 시 실패 |
| v1.0.1 | 2026-09-24 | 교차 정합성 조정: §2 의존 설명을 R3에 맞춤(카드가 더한 같은/앞선 스프린트 의존은 색인 반영, `cardDeps`는 제안 키 의존만, 스프린트 역전 의존은 카드 참고(soft)) |
