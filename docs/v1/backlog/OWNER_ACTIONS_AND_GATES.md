# 소유자 행동·외부 게이트 트랙

| 항목 | 내용 |
|---|---|
| 문서 ID | V1-02-OA |
| 버전 | v1.1 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | [PRD_V1](../../PRD_V1.md) §11.2 MIG-01·MIG-02, §12.1 단계, §12.2 게이트 카탈로그 G-01~G-10, §12.3 플래그 개방 순서, §12.6 연구 트랙, §12.7 단계 종료 검토, §13 열린 질문(Q-04, Q-05, Q-07, Q-08, Q-09, Q-10, Q-21, Q-22, Q-24) |
| 관련 에픽·스토리 | EP-00 / DF-901~DF-939·DF-942(채택 40건), 추가 제안 DF-940·DF-941(채택 대기) |
| 변경 규칙 | [문서 변경](../01_AGILE_WORKING_AGREEMENT.md#문서-변경) |

## 목차

- [0. 읽는 법](#0-읽는-법)
- [1. 게이트 카탈로그와 담당 항목](#1-게이트-카탈로그와-담당-항목)
- [2. 스프린트별 한눈에 보기](#2-스프린트별-한눈에-보기)
- [3. 카드](#3-카드)
  - P0: [DF-901](#df-901), [DF-902](#df-902), [DF-903](#df-903), [DF-904](#df-904), [DF-905](#df-905), [DF-906](#df-906), [DF-907](#df-907), [DF-908](#df-908), [DF-909](#df-909), [DF-910](#df-910), [DF-911](#df-911), [DF-913](#df-913), [DF-916](#df-916), [DF-926](#df-926), [DF-930](#df-930), [DF-942](#df-942)
  - P1a: [DF-912](#df-912), [DF-914](#df-914), [DF-922](#df-922), [DF-924](#df-924), [DF-925](#df-925), [DF-927](#df-927), [DF-931](#df-931), [DF-932](#df-932), [DF-933](#df-933)
  - P1b: [DF-915](#df-915), [DF-928](#df-928), [DF-929](#df-929)
  - P2: [DF-917](#df-917), [DF-918](#df-918), [DF-919](#df-919), [DF-923](#df-923), [DF-934](#df-934), [DF-935](#df-935), [DF-936](#df-936), [DF-939](#df-939), 제안 [DF-940](#df-940), [DF-941](#df-941)
  - P3: [DF-920](#df-920), [DF-921](#df-921), [DF-937](#df-937), [DF-938](#df-938)
- [4. 가정(ASM-OA-NN)](#4-가정asm-oa-nn)
- [5. 변경 이력](#5-변경-이력)

## 0. 읽는 법

- 이 문서는 EP-00 항목(DF-900~999)의 카드 정본이다. 키·제목·단계·스프린트·점수·우선순위·의존의 정본은 [02 §8.7](../02_PRODUCT_BACKLOG.md#8-전체-스토리-색인) 색인이고, 이 문서는 그 값을 그대로 옮긴다.
- **소유자만 실행한다.** AI 에이전트는 이 문서의 항목을 실행하지 않는다. 콘솔 설정, 운영 배포, 이관 실행, 법률·식약처·IRB 제출, 스토어 제출, 플래그 개방이 모두 여기에 속한다. 에이전트는 초안 작성(예: 의뢰서 초안, 체크리스트)까지만 돕는다.
- **외부 게이트는 코딩을 막지 않는다.** 막는 것은 단계 전환, 실데이터 투입, 플래그 개방뿐이다. 늦어지면 합성 데이터와 에뮬레이터로 개발을 계속한다. 카드의 '코딩 차단' 줄이 '예'인 항목만 해당 스토리 브랜치를 막는다.
- **점수.** owner-action은 0~1점이다. 1점은 소유자 작업 시간이 반나절 이상인 항목이다. 이 점수는 스프린트 약속과 속도에 포함한다([01 ASM-01-16](../01_AGILE_WORKING_AGREEMENT.md#가정과-스파인-차이-기록), 02 §4.3). 실제 시간은 V1-T05 "소유자 시간" 표에 따로 적는다.
- **증빙.** 게이트 증빙은 [게이트 증빙 템플릿](../templates/GATE_EVIDENCE.md)(V1-T07)으로 `docs/v1/evidence/<게이트 ID>.md`에, 플래그 개방 체크리스트는 `docs/v1/evidence/flags-<키>.md`에, 이관 실행 기록은 [V1-T10](../templates/MIGRATION_RUN_RECORD.md)으로 `docs/v1/migrations/`에, 단계 종료 검토는 [V1-T06](../templates/PHASE_EXIT_REVIEW.md)으로 `docs/v1/reviews/`에 둔다. 앱 ID·키·서비스 계정 값·회원 정보는 증빙에 적지 않는다.
- **라벨.** 모든 항목에 `type/task`, `owner-action`, `agent/human`을 붙이고, PRD 추적에 G-NN이 있으면 `gate/G-NN`을 붙인다. 0점 항목은 `size/` 라벨이 없다.
- 리드타임과 최신 착수일은 [03 §5.2](../03_RELEASE_AND_SPRINT_PLAN.md#52-트랙별-리드타임과-최신-착수일)가 정본이다. 카드의 '늦을 때'는 그 표를 요약한 것이다.

## 1. 게이트 카탈로그와 담당 항목

정의는 PRD §12.2 요약이다. 판정 시점과 증빙 위치는 [03 §5.3](../03_RELEASE_AND_SPRINT_PLAN.md#53-게이트-판정-일정단계-종료와-연결)과 같다.

| 게이트 | 내용(PRD §12.2 요약) | 막는 것 | 담당 항목 | 코드 쪽 증빙 스토리 | 판정 스프린트 |
|---|---|---|---|---|---|
| G-01 | 미커밋 87개 정리(MIG-01): 분류표, 보관 브랜치와 tip 해시, CI 4 job, 자격증명 미포함 | P0 종료, 모든 에이전트 브랜치 기준선 | DF-901, DF-930 | — | S01 |
| G-02 | 트레이너 앱 Firebase 등록, ASC 레코드·배포 이력(Q-22), plist 관리 방식, claim 계정 로그인·memberIds 로드(가상 회원) | P0 종료 | DF-903, DF-904, DF-905 | DF-008, DF-012, DF-013, DF-034 | S05 |
| G-03 | R-01~R-31·S-01~S-09 에뮬레이터 통과, Storage 교차 조회 권한 부여와 실환경 확인 | P0 종료, 이후 매 PR | DF-906, DF-931 | DF-022, DF-035, DF-023, DF-038 | S05 |
| G-04 | 동의 5종 published(보유기간 N·④ 수령자), 보존·파기 정책, 처리 주체 모델(Q-21), 만 14세 기준, 대기 회원 최소 정보 근거, 법률 의견서(Q-07) | P1a 진입, 실데이터 | DF-908 | DF-032 | S08 수령, S09 판정 |
| G-05a | 식약처 품목 분류·사전 확인 요청 제출(출시 앱 문구 정리 후) | P1a 진입 | DF-910, DF-911 | DF-028, DF-029 | S05 제출 |
| G-05b | 식약처 결과(웰니스) 또는 규제 자문 의견. 웰니스가 아니면 P2 진입 금지 | P2 진입, memberShare | DF-919 | — | S19 |
| G-06 | 자세 재검사 연구(IRB 승인·면제 후 시작). ICC·SEM·MDC95 보고서 또는 '문헌값 유지' 결정 | G-08(P3 진입 전) | DF-912, DF-939 | DF-212, DF-326 | S26 |
| G-07a | BodyPath 로드맵 1~2, 결과 패키지 v1, BodyPathResult 패키지 테스트 | lidarBeta 개방(P2) | DF-917, DF-923 | DF-300~DF-303 | S25-S26 |
| G-07 | LiDAR 실측 대조 예비 결과(IRB 후) | P2 종료, 베타 유지·해제 | DF-918 | DF-322 | S27 이후(03 차이 D-3) |
| G-08 | 변화 판정 정책 승인 여부(선행 G-06) | P3 진입 | DF-920 | DF-380, DF-384 | S27-S29 |
| G-09 | 처리방침 게시, 리전·위탁·국외이전 확인(Q-08). 리전은 DEC-19로 서울 `asia-northeast3` | P1a 진입(G-04와 묶음) | DF-909, DF-942 | DF-043 | S08 수령, S09 판정 |
| G-10 | 표시·광고 문구 금지어 수동 검수 | P3 진입(1.0) | DF-921 | DF-040 | S30-S32 |

플래그 개방 항목(§12.3 순서): 순서 1 DF-925(soapV2·bodyComposition), 순서 2 DF-929(bodyAssessment), 순서 3 DF-934(memberShare), 순서 4 DF-935(lidarBeta), 복귀 DF-389(개발 스토리). 단계 종료 검토: DF-926(P0), DF-927(P1a), DF-928(P1b), DF-936(P2), DF-938(P3·GA).

## 2. 스프린트별 한눈에 보기

| 스프린트 | 항목(점수) | 합계 |
|---|---|---|
| S01 | DF-901(1), DF-902(0), DF-903(1), DF-904(0), DF-913(0), DF-930(0), DF-942(1) | 3 |
| S02 | DF-905(0) | 0 |
| S03 | DF-906(0), DF-908(1, 보류로 S01에서 이동), DF-909(1) | 2 |
| S04 | DF-907(0), DF-911(0), DF-916(0) | 0 |
| S05 | DF-910(1), DF-926(0) | 1 |
| S06 | DF-912(1), DF-914(0) | 1 |
| S08 | DF-922(0), DF-931(1), DF-932(0) | 1 |
| S09 | DF-924(1), DF-925(0) | 1 |
| S12 | DF-933(0) | 0 |
| S13 | DF-915(1) | 1 |
| S15 | DF-927(0) | 0 |
| S17 | DF-929(0) | 0 |
| S18 | DF-928(0) | 0 |
| S19-S20 | DF-919(0) | 0 |
| S21-S22 | DF-918(1), 제안 DF-941(0) | 1 |
| S23-S24 | DF-923(0), DF-934(0), 제안 DF-940(1) | 0(제안 채택 시 1) |
| S25-S26 | DF-917(0), DF-935(0), DF-936(0), DF-939(1) | 1 |
| S27-S29 | DF-920(1), DF-937(1) | 2 |
| S30-S32 | DF-921(1), DF-938(0) | 1 |
| 합계 | 채택 40건 | 15 |

## 3. 카드

카드 공통 사항: Epic은 EP-00 소유자 행동·외부 게이트 트랙, Type은 owner-action이다. '코딩 차단'이 '아니요'면 의존 스토리는 합성 데이터·에뮬레이터·기본값으로 계속한다.

---

<a id="df-901"></a>
### DF-901 MIG-01 미커밋 87개를 A·B·C로 분류해 A를 main에 병합하고 B를 보관한다(G-01)

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P0 |
| Sprint | S01(1일차 09-28 오전 착수, 화 12:00 병합) |
| Points | 1(size/XS) |
| Priority | must |
| Area | ci |
| Gate | G-01 |
| Labels | `type/task` `owner-action` `area/ci` `phase/P0` `prio/must` `size/XS` `gate/G-01` `agent/human` |
| Depends on | - |
| PRD refs | MIG-01, D13, G-01, RISK-04 |

**할 일.** PRD §11.2 체크리스트 #1~#7을 실행한다. 정리 전 작업 트리를 저장소 밖에 보존하고, 파일마다 A(보안·백엔드·테스트)·B(트레이너 UI)·C(보고서 생성기·`output/`·`tmp/`)로 분류한다. 혼재 파일 3개는 hunk로 나눠 A만 커밋한다. B는 `archive/trainer-ui-2026-09`에 보관하고 tip 해시를 이식 기준선으로 기록한다. A만 main에 병합하고 `feature/integrated-care-2026`을 삭제한다. 이어서 main 보호 규칙을 건다. 절차 정본은 [V1-11 §3](../11_MIGRATION_RUNBOOK.md#3-mig-01-미커밋-정리)과 [SPRINT_01 §7.1](../sprints/SPRINT_01.md#71-df-901-mig-01-기준선-정리소유자-1점)이다.

**막는 것 / 막지 않는 것.** 모든 에이전트 브랜치(DF-001, DF-002, DF-003, DF-008, DF-020, DF-037, DF-039)의 분기 기준선. **코딩 차단: 예**(기준선이 없으면 브랜치를 열지 않는다).

**완료 증빙.** `docs/v1/evidence/G-01.md`: 88줄 분류표(경로·분류·커밋 주제), 보관 브랜치 tip 해시, CI 4 job(flutter, functions-and-rules, admin-web, ios-no-codesign) 초록 링크, 자격증명 미스테이징 확인, 운영 규칙의 `trainerWorkspaces` 배포 상태. C분류는 커밋하지 않는다. tip 해시는 [00_README](../00_README.md#이식-기준선)에도 옮긴다.

**늦을 때.** 화요일 오전까지 병합이 안 되면 에이전트 브랜치는 로컬에서만 준비하고 PR은 병합 뒤 main으로 rebase한다. DF-008은 브랜치 준비까지만 한다.

---

<a id="df-902"></a>
### DF-902 라벨·마일스톤·Projects·이슈 생성 스크립트를 실행한다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P0 |
| Sprint | S01(금 10-02) |
| Points | 0 |
| Priority | must |
| Area | docs |
| Gate | - |
| Labels | `type/task` `owner-action` `area/docs` `phase/P0` `prio/must` `agent/human` |
| Depends on | DF-002 |
| PRD refs | §12.1 |

**할 일.** DF-002가 병합된 main에서 다음 순서로 실행한다. 사용법 정본은 [tool/backlog/README.md](../../../tool/backlog/README.md)(TL-01)다.
1. `gh auth refresh -s project,read:project`
2. `bash tool/backlog/create_github_issues.sh`(기본 dry-run, 네트워크 호출 없음)로 계획 확인
3. `bash tool/backlog/create_github_issues.sh --apply --only labels,milestones`
4. Projects 보드 'D-FET Coach v1'을 만들고(`--create-project` 또는 웹) 번호를 `PROJECT_NUMBER`로 둔 뒤 `--apply --only project`로 필드(Points, Sprint, Phase)를 만든다.
5. `PROJECT_NUMBER=<n> bash tool/backlog/create_github_issues.sh --apply --only issues --phase P0 --owner-actions`
6. 같은 명령을 다시 실행해 '생성 0건'을 확인한다.

P1a 이후 스토리 이슈는 각 단계 첫 계획 회의에서 `--phase <단계>`로 추가한다(SPRINT_01 ASM-S01-11).

**막는 것 / 막지 않는 것.** Projects 보드 운영(S02부터). **코딩 차단: 아니요.**

**완료 증빙.** 라벨·마일스톤·보드 존재, 중복 이슈 0건(두 번째 실행 '생성 0건' 출력).

**늦을 때.** S02 계획 회의 전까지. 그 전에는 [02 §8](../02_PRODUCT_BACKLOG.md#8-전체-스토리-색인) 색인으로 계획한다.

---

<a id="df-903"></a>
### DF-903 kr.co.dfet.trainer를 dfetmanage에 등록하고 plist·App Attest를 설정한다(G-02)

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P0 |
| Sprint | S01(수 09-30) |
| Points | 1(size/XS) |
| Priority | must |
| Area | ci |
| Gate | G-02 |
| Labels | `type/task` `owner-action` `area/ci` `phase/P0` `prio/must` `size/XS` `gate/G-02` `agent/human` |
| Depends on | - |
| PRD refs | §10.2.4, G-02, NFR-02, NFR-09 |

**할 일.** Firebase 콘솔 `dfetmanage`에 iOS 앱(번들 `kr.co.dfet.trainer`, 팀 MT27Z7369H)을 등록한다. `GoogleService-Info.plist`는 저장소 밖에 보관하고 내용은 어디에도 붙여 넣지 않는다(ADR-019). App Check에 App Attest 공급자를 등록하되 강제는 끈다(강제는 P3 DF-386). plist 관리 방식(비추적 + CI 시크릿 주입)을 확정해 ADR-019에 기록한다.

**막는 것 / 막지 않는 것.** DF-034(S02 시크릿 주입), DF-012(S04 실계정 확인), DF-905. **코딩 차단: 아니요**(plist가 없으면 preview 구성으로 빌드하고 에뮬레이터로 진행).

**완료 증빙.** `docs/v1/evidence/G-02.md`: '등록됨'과 일시, App Attest 등록 확인, plist 관리 방식 결정. 앱 ID·API 키 값은 적지 않는다.

**늦을 때.** 최신 10-02. 늦으면 DF-034·DF-012가 같은 폭으로 밀린다.

---

<a id="df-904"></a>
### DF-904 App Store Connect 레코드와 iPhone 배포 이력을 확인한다(Q-22)

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P0 |
| Sprint | S01(수 09-30) |
| Points | 0 |
| Priority | must |
| Area | docs |
| Gate | - |
| Labels | `type/task` `owner-action` `area/docs` `phase/P0` `prio/must` `agent/human` |
| Depends on | - |
| PRD refs | Q-22, NFR-01, AS-27 |

**할 일.** App Store Connect에서 `kr.co.dfet.trainer` 앱 레코드 유무, 빌드 이력, iPhone 지원 빌드의 배포 이력을 확인한다.

**막는 것 / 막지 않는 것.** DF-008의 `TARGETED_DEVICE_FAMILY` 확정, DF-922. **코딩 차단: 아니요**(결과 전에는 "2", iPad 전용으로 진행).

**완료 증빙.** G-02.md에 결과 기록. Universal로 나오면 [03 §11 T-07](../03_RELEASE_AND_SPRINT_PLAN.md#11-재계획-트리거)에 따라 S02에 `project.yml` 한 줄 수정 PR을 연다.

**늦을 때.** 최신 10-01.

---

<a id="df-905"></a>
### DF-905 claim 테스트 계정과 가상 회원 시드를 준비한다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P0 |
| Sprint | S02 |
| Points | 0 |
| Priority | must |
| Area | ci |
| Gate | G-02 |
| Labels | `type/task` `owner-action` `area/ci` `phase/P0` `prio/must` `gate/G-02` `agent/human` |
| Depends on | DF-903, DF-942 |
| PRD refs | G-02, §10.2.4 |

**할 일.** 운영 프로젝트에 trainer claim을 가진 테스트 계정 1개와, 그 계정의 `trainers/{uid}.memberIds`에 연결된 가상 회원(실존 인물이 아닌 계정)을 만든다. 에뮬레이터용 시드는 이 항목이 아니다(추가 제안 DF-042 또는 DF-012 범위). 가상 회원 문서는 서울에 다시 만든 `(default)`(DF-942)에 만든다. 먼저 만들면 DB 삭제와 함께 사라진다.

**막는 것 / 막지 않는 것.** G-02 증빙(DF-012·DF-013의 실계정 확인). **코딩 차단: 아니요.**

**완료 증빙.** G-02.md에 '가상 담당 관계 준비됨'. 계정 이메일·uid는 적지 않는다.

---

<a id="df-906"></a>
### DF-906 Storage 서비스 계정에 Firestore 교차 조회 권한을 부여한다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P0 |
| Sprint | S03(첫날 10-12) |
| Points | 0 |
| Priority | must |
| Area | storage |
| Gate | G-03 |
| Labels | `type/task` `owner-action` `area/storage` `phase/P0` `prio/must` `gate/G-03` `agent/human` |
| Depends on | DF-942 |
| PRD refs | §9.5, S-09, G-03 |

**할 일.** storage.rules의 `firestore.get` 교차 조회가 동작하도록 Storage 서비스 에이전트에 Firestore 읽기 권한을 부여한다(콘솔 안내 절차). 대상은 서울 버킷과 서울 `(default)`다(DF-942, DEC-19).

**막는 것 / 막지 않는 것.** DF-038(S-09 실환경 확인), DF-023의 운영 동작. **코딩 차단: 아니요**(에뮬레이터 S-01~S-08은 권한 없이 동작).

**완료 증빙.** G-03.md에 부여 일시. 실패 시 대안은 DF-038이 ADR-007에 기록한다.

---

<a id="df-907"></a>
### DF-907 MIG-02 실사 스크립트를 운영에서 읽기 전용으로 실행한다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P0 |
| Sprint | S04 |
| Points | 0 |
| Priority | must |
| Area | functions |
| Gate | - |
| Labels | `type/task` `owner-action` `area/functions` `phase/P0` `prio/must` `agent/human` |
| Depends on | DF-030 |
| PRD refs | MIG-02 |

**할 일.** DF-030 스크립트를 ADC 로그인 상태에서 `--confirm-readonly-prod`로 실행한다. 절차는 [V1-11 §4.3](../11_MIGRATION_RUNBOOK.md#43-실행소유자-df-907-s04)이다. 결과 JSON은 커밋하지 않고 수량만 옮긴다.

**막는 것 / 막지 않는 것.** DF-026(관리자 판정 설계), DF-031의 '해당 없음' 판정, DF-924. **코딩 차단: 아니요.**

**완료 증빙.** `docs/v1/migrations/MIG-02-YYYYMMDD-<runId>.md`(V1-T10): 수량·분포만. 0건 항목은 '해당 없음'으로 기록. 이메일·uid 패턴 0건 확인(V1-11 §4.4).

---

<a id="df-908"></a>
### DF-908 법률 자문을 의뢰하고 G-04 의견을 받는다(Q-04, Q-05, Q-07, Q-21, Q-24)

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P0 |
| Sprint | S03 발송 계획(소유자 보류 2026-09-25, 원래 S01 금 10-02), 최신 발송 10-30(금) |
| Points | 1(size/XS) |
| Priority | must |
| Area | privacy |
| Gate | G-04 |
| Labels | `type/task` `owner-action` `area/privacy` `phase/P0` `prio/must` `size/XS` `gate/G-04` `agent/human` `privacy-impact` |
| Depends on | - |
| PRD refs | G-04, Q-04, Q-05, Q-07, Q-21, Q-24, AS-22, AS-31 |

**보류(소유자 2026-09-25).** 의뢰서 작성·발송을 뒤로 미뤘다. 발송이 10-08(목표 기준 최신)을 넘기면 P1a 플래그 개방(DF-925) 목표 11-27을 지키기 어렵고, 10-30(한계 기준 최신)을 넘기면 한계 12-18도 넘겨 P1a 자체 사용과 P1a 종료 검토가 밀린다([03 §5.2](../03_RELEASE_AND_SPRINT_PLAN.md#52-트랙별-리드타임과-최신-착수일)). 매주 수요일 게이트 점검에서 발송일을 다시 정한다.

**할 일.** 의뢰서를 작성해 발송한다. 운영 DB·Storage가 서울 `asia-northeast3`(DEC-19)이고 Auth·분석 SDK만 국외(미국) 처리(AS-19)라는 사실을 질문 전제로 적는다. 질문: Q-04(동의 ④ 범위), Q-05(대기 회원 민감정보), Q-07(동의 증빙 보존), Q-21(프리랜서 트레이너의 처리자 지위), **Q-24(코칭 기록 최대 보유기간 N)**, AS-22(만 14세), AS-31(처리 주체 모델), 대기 회원 최소 정보의 근거, 동의 5종 고지 항목 초안, 국외이전 고지(AS-19). 첨부는 PRD 발췌만 한다. 특허 공개 범위(Q-17) 때문에 PRD 전문과 LiDAR 방법은 보내지 않는다. 회원 실데이터는 넣지 않는다.

**막는 것 / 막지 않는 것.** G-04, G-09(DF-909), DF-925(P1a 플래그 개방), DF-133의 운영 매개변수(N), DF-937. **코딩 차단: 아니요.** DF-133은 N 미설정(파기 분기 비활성)으로 개발한다.

**완료 증빙.** `docs/v1/evidence/G-04.md`: 질문 목록, 발송일, 회신 예정일, 회신 요지, 확정된 N. **N 확정 없이는 G-04 미통과**(PRD Q-24).

**늦을 때.** 목표 기준 최신 발송 10-08(보류로 넘길 가능성이 크다), **한계 10-30**. S03(10-16) 발송이면 개방은 12-04 무렵(목표보다 약 1주 늦음, 한계 안). 12-18까지 개방하지 못하면 P1a 종료 검토를 주 단위로 연기한다(03 §11).

---

<a id="df-909"></a>
### DF-909 처리방침을 게시하고 리전·위탁·국외이전을 확인한다(G-09)

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P0 |
| Sprint | S03 착수, 목표 S08 |
| Points | 1(size/XS) |
| Priority | must |
| Area | privacy |
| Gate | G-09 |
| Labels | `type/task` `owner-action` `area/privacy` `phase/P0` `prio/must` `size/XS` `gate/G-09` `agent/human` `privacy-impact` |
| Depends on | DF-908, DF-942 |
| PRD refs | G-09, Q-08, AS-19, §9.7 백업·리전 |

**할 일.** DF-942 결과(Firestore `(default)`·Storage 버킷 서울 `asia-northeast3`, DEC-19)를 G-09.md 리전 절에서 확인한다(Q-08). 처리방침 초안(처리 목적·항목·보유기간, 수탁자 Google LLC(Firebase), 리전 선택이 불가한 서비스의 국외 이전 국가·업체·시기·방법·근거)을 만들어 G-04 법률 검토와 함께 확정·게시한다. 동의 문서가 처리방침 버전을 참조하게 한다(DF-032).

**막는 것 / 막지 않는 것.** DF-925, DF-126의 실제 분석 전송 전환(ADR-015). 트리거 리전은 DEC-19로 확정돼 더는 막지 않는다. **코딩 차단: 아니요**(분석은 DebugSink, 리전은 asia-northeast3).

**완료 증빙.** `docs/v1/evidence/G-09.md`: 리전 기록, 처리방침 URL, 버전.

**늦을 때.** 초안 확정 최신 11-13. DF-908이 S04~S05로 밀리면([V1-00 K-19](../00_README.md#알려진-차이와-남은-일) 되돌림 ②) 리전 기록(DF-942 결과 확인)만 S03에 하고, 처리방침 확정·게시는 DF-908 회신을 따른다. DF-909→DF-908 의존은 게시 단계에만 적용한다.

---

<a id="df-910"></a>
### DF-910 식약처 사전 확인 요청을 제출한다(G-05a)

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P0 |
| Sprint | S05 |
| Points | 1(size/XS) |
| Priority | must |
| Area | docs |
| Gate | G-05a |
| Labels | `type/task` `owner-action` `area/docs` `phase/P0` `prio/must` `size/XS` `gate/G-05a` `agent/human` `regulatory` |
| Depends on | DF-911 |
| PRD refs | G-05a, §3.1, MIG-04 |

**할 일.** 출시 앱 문구 수정 릴리스(DF-911)가 배포된 뒤 품목 분류·사전 확인을 요청한다. 기능 설명에 각도 측정, MDC 기반 4상태 판정, 통증 NRS·바디맵 추이, 회원 리포트를 명시하고 사용목적 문구(§3.1)를 쓴다.

**막는 것 / 막지 않는 것.** DF-925, G-05b(DF-919)의 회신 시계. **코딩 차단: 아니요.**

**완료 증빙.** `docs/v1/evidence/G-05a.md`: 접수 증빙, 제출 기능 설명, MIG-04 완료 기록.

**늦을 때.** 회신 90일 보수 가정에서 최신 제출일은 10-30(여유 0일). 12-18까지 회신이 없으면 S12에 규제 자문을 병행 의뢰한다(03 §5.2).

---

<a id="df-911"></a>
### DF-911 출시 앱 문구 수정 릴리스를 스토어에 제출한다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P0 |
| Sprint | S04 |
| Points | 0 |
| Priority | must |
| Area | member-app |
| Gate | G-05a |
| Labels | `type/task` `owner-action` `area/member-app` `phase/P0` `prio/must` `gate/G-05a` `agent/human` `regulatory` |
| Depends on | DF-028, DF-029 |
| PRD refs | MIG-04, G-05a |

**할 일.** DF-028(Runner 트레이너 규제 문구·diagnosis 자동 채움 제거)과 DF-029(회원 앱 4개 파일)를 포함한 회원 앱 릴리스를 `member-vX.Y.Z` 태그로 스토어에 제출한다.

**막는 것 / 막지 않는 것.** DF-910. **코딩 차단: 아니요.**

**완료 증빙.** G-05a.md에 제출·배포 일시와 태그. 심사 1~3일 가정(03 ASM-03-04).

**늦을 때.** 반려 시 즉시 재제출. DF-910도 같은 폭으로 밀린다.

---

<a id="df-912"></a>
### DF-912 자세 재검사 연구 IRB를 신청한다(G-06 시작 조건)

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P1a |
| Sprint | S06 |
| Points | 1(size/XS) |
| Priority | must |
| Area | privacy |
| Gate | G-06 |
| Labels | `type/task` `owner-action` `area/privacy` `phase/P1a` `prio/must` `size/XS` `gate/G-06` `agent/human` `privacy-impact` |
| Depends on | - |
| PRD refs | G-06, §12.6, Q-02, RISK-11 |

**할 일.** 자세 재검사 연구(PRD §7.3.3, §12.6) IRB를 신청한다. 연구참여 동의서와 가명정보 처리대장을 함께 준비한다.

**막는 것 / 막지 않는 것.** 실제 재검사 촬영·연구 데이터 수집. DF-212 코드와 합성 테스트는 막지 않는다. **코딩 차단: 아니요.**

**완료 증빙.** `docs/v1/evidence/G-06.md`: 신청일, 승인·면제 확인서(목표 S14), 동의서 버전, 처리대장.

**늦을 때.** 최신 신청 11-23(심의 8주 가정). 수집이 부족하면 DF-939에서 '문헌값 유지·회원 배지 없음'으로 결정한다. P3는 막히지 않는다.

---

<a id="df-913"></a>
### DF-913 Q-09(2026 과업지시서와의 관계)를 결정한다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P0 |
| Sprint | S01(목 10-01) |
| Points | 0 |
| Priority | must |
| Area | docs |
| Gate | - |
| Labels | `type/task` `owner-action` `area/docs` `phase/P0` `prio/must` `agent/human` |
| Depends on | - |
| PRD refs | Q-09 |

**할 일.** v1 개발이 2026 과업지시서의 산출물 양식을 따라야 하는지 결정한다. 결정 전 기본값은 '자체 제품 로드맵, 과업 산출물 양식 미적용'이다.

**막는 것 / 막지 않는 것.** PRD §13.3 기한 'P0 진입'. **코딩 차단: 아니요.**

**완료 증빙.** [00_README §결정 기록](../00_README.md#결정-기록)에 결과. PRD 반영은 소유자가 PRD 변경 이력과 함께 직접 한다.

---

<a id="df-914"></a>
### DF-914 Q-10 트레이너 앱 디자인 토큰을 결정한다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P1a |
| Sprint | S06 |
| Points | 0 |
| Priority | should |
| Area | design |
| Gate | - |
| Labels | `type/task` `owner-action` `area/design` `phase/P1a` `prio/should` `agent/human` |
| Depends on | - |
| PRD refs | Q-10, §8.5 |

**할 일.** 트레이너 앱 색·서체 토큰을 결정한다. 결정 전 기본값은 중립 회색 + 브랜드 블루, 초록은 저장·완료 상태 전용이다.

**막는 것 / 막지 않는 것.** 없음. 결정이 나면 DF-016·DF-117·DF-130의 토큰만 교체한다. **코딩 차단: 아니요.**

**완료 증빙.** 00_README 결정 기록과 [V1-07](../07_TRAINER_APP_SPEC.md) 토큰 절 갱신 PR.

---

<a id="df-915"></a>
### DF-915 촬영 프로토콜 v1 수치(높이·거리·허용 범위·발 간격)를 확정한다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P1b |
| Sprint | S13 |
| Points | 1(size/XS) |
| Priority | must |
| Area | docs |
| Gate | - |
| Labels | `type/task` `owner-action` `area/docs` `phase/P1b` `prio/must` `size/XS` `agent/human` |
| Depends on | - |
| PRD refs | F-ASM-01.2, F-ASM-06.2 |

**할 일.** 스테이션 카메라 높이·거리, roll·pitch 허용 범위, 발 간격, 줄자 기준점 문구를 확정해 protocolVersion 1로 문서화한다.

**막는 것 / 막지 않는 것.** `contracts/posture-protocol.v1.json`의 초안 표시 해제, 실사용 촬영. DF-203·DF-204 코딩은 기본값으로 진행한다. **코딩 차단: 아니요.**

**완료 증빙.** 프로토콜 v1 문서와 contracts 갱신 PR 링크.

---

<a id="df-916"></a>
### DF-916 부록 A.5~A.7(관절·근육군·통증 부위 코드)을 확정한다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P0 |
| Sprint | S04 |
| Points | 0 |
| Priority | must |
| Area | contracts |
| Gate | - |
| Labels | `type/task` `owner-action` `area/contracts` `phase/P0` `prio/must` `agent/human` `schema-change` |
| Depends on | DF-003 |
| PRD refs | 부록 A.5, 부록 A.6, 부록 A.7 |

**할 일.** DF-003이 초안으로 표시한 관절·근육군·통증 부위 코드 목록을 검토해 확정한다.

**막는 것 / 막지 않는 것.** DF-003 초안 표시 해제, DF-117(바디맵), DF-121(O 행). **코딩 차단: 아니요**(초안 코드로 개발, 확정 시 contracts와 생성물만 갱신).

**완료 증빙.** contracts `vocab.v1.json` 초안 표시를 해제하는 PR 승인.

---

<a id="df-917"></a>
### DF-917 G-07a 증빙(로드맵 1~2, 결과 패키지, 패키지 테스트)을 기록한다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P2 |
| Sprint | S25-S26 |
| Points | 0 |
| Priority | must |
| Area | bodypath |
| Gate | G-07a |
| Labels | `type/task` `owner-action` `area/bodypath` `phase/P2` `prio/must` `gate/G-07a` `agent/human` |
| Depends on | DF-301, DF-302 |
| PRD refs | G-07a |

**할 일.** BodyPath 로드맵 단계 1~2 완료(DF-303), 결과 패키지 v1 내보내기와 스키마 문서(DF-301), `BodyPathResult`·`BodyPathCoreUI` swift test 통과와 태그(DF-300, DF-302)를 확인해 기록한다.

**막는 것 / 막지 않는 것.** DF-935(lidarBeta 개방). **코딩 차단: 아니요.**

**완료 증빙.** `docs/v1/evidence/G-07a.md`. 미충족이면 lidarBeta를 P3 이후로 연기하고 DF-320~DF-323, DF-935를 V2 대기열로 옮긴다(03 §5.2).

---

<a id="df-918"></a>
### DF-918 LiDAR 줄자 대조 연구 IRB를 신청하고 G-07 예비 결과를 받는다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P2 |
| Sprint | S21-S22(03 권고: IRB 신청은 S17) |
| Points | 1(size/XS) |
| Priority | should |
| Area | privacy |
| Gate | G-07 |
| Labels | `type/task` `owner-action` `area/privacy` `phase/P2` `prio/should` `size/XS` `gate/G-07` `agent/human` `privacy-impact` |
| Depends on | - |
| PRD refs | G-07, F-LIDAR-03.3, §12.6 |

**할 일.** IRB 승인·면제 뒤에만 줄자 대조 수집을 시작하고 예비 보고서(부위별 차이, 반복 차이, 실패율)를 받는다.

**막는 것 / 막지 않는 것.** P2 종료 판단, P3 lidarBeta 결정(DF-389). DF-322 코드는 막지 않는다. **코딩 차단: 아니요.**

**완료 증빙.** `docs/v1/evidence/G-07.md`: IRB 확인서, 예비 보고서, 베타 유지·해제 기록.

**늦을 때.** 스파인 배치(S21-S22)로는 P2 종료(03-26)까지 예비 결과가 나오기 어렵다(03 §14.2 차이 D-3). IRB 신청을 S17로 앞당기는 것을 권고한다. 늦으면 P2 종료 검토에 우회 결정을 기록하고 P3 진입 때 lidarBeta를 false로 되돌린다.

---

<a id="df-919"></a>
### DF-919 식약처 결과 또는 규제 자문 의견을 받는다(G-05b)

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P2 |
| Sprint | S19-S20 |
| Points | 0 |
| Priority | must |
| Area | docs |
| Gate | G-05b |
| Labels | `type/task` `owner-action` `area/docs` `phase/P2` `prio/must` `gate/G-05b` `agent/human` `regulatory` |
| Depends on | DF-910 |
| PRD refs | G-05b, Q-01, Q-23 |

**할 일.** 식약처 회신 또는 규제 자문 의견서를 받는다. PROM·MMT 트레이너 기록 범위 검토(Q-23)를 포함한다.

**막는 것 / 막지 않는 것.** P2 진입, DF-934(memberShare 개방). **코딩 차단: 아니요**(P2 코딩과 에뮬레이터 테스트는 S19부터 진행).

**완료 증빙.** `docs/v1/evidence/G-05b.md`. **웰니스가 아니면 P2 진입 금지와 PRD 개정(Q-01).**

**늦을 때.** 02-01까지 없으면 P2 코딩은 계속하고 DF-934·DF-306 배포만 연기한다.

---

<a id="df-920"></a>
### DF-920 변화 판정 정책 승인 여부를 결정한다(G-08)

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P3 |
| Sprint | S27-S29 |
| Points | 1(size/XS) |
| Priority | must |
| Area | admin-web |
| Gate | G-08 |
| Labels | `type/task` `owner-action` `area/admin-web` `phase/P3` `prio/must` `size/XS` `gate/G-08` `gate/G-06` `agent/human` |
| Depends on | DF-384, DF-939 |
| PRD refs | G-08, G-06, Q-13 |

**할 일.** G-06 결과(DF-939)를 근거로 bodyChange 정책을 AD-04에서 승인하거나 '미승인 출시'를 결정한다. 승인 주체는 Q-13을 따른다.

**막는 것 / 막지 않는 것.** P3 진입, 판정 표시. **코딩 차단: 아니요.**

**완료 증빙.** `docs/v1/evidence/G-08.md`: 승인본(approvedBy) 또는 '미승인 출시' 결정 문서. 미승인이면 판정 표시는 '산정 준비 중'을 유지한다.

---

<a id="df-921"></a>
### DF-921 표시·광고 문구 금지어를 수동 검수한다(G-10)

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P3 |
| Sprint | S30-S32 |
| Points | 1(size/XS) |
| Priority | must |
| Area | docs |
| Gate | G-10 |
| Labels | `type/task` `owner-action` `area/docs` `phase/P3` `prio/must` `size/XS` `gate/G-10` `agent/human` `regulatory` |
| Depends on | - |
| PRD refs | G-10, 부록 C, Q-17 |

**할 일.** 스토어 메타데이터, 마케팅, IR 자료, 영업 자료, 특허 관련 홍보를 부록 C 기준으로 수동 검수한다. 체크리스트는 [V1-12](../12_COPY_ANALYTICS_AND_LINT.md)의 G-10 절을 쓴다. 특허 공개 범위(Q-17)를 먼저 확인한다.

**막는 것 / 막지 않는 것.** P3 진입, 1.0 출시. **코딩 차단: 아니요.**

**완료 증빙.** `docs/v1/evidence/G-10.md`: 린트 결과 링크와 수동 체크리스트.

---

<a id="df-922"></a>
### DF-922 TestFlight 내부 그룹과 App Store Connect 설정을 마친다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P1a |
| Sprint | S08 |
| Points | 0 |
| Priority | must |
| Area | ci |
| Gate | - |
| Labels | `type/task` `owner-action` `area/ci` `phase/P1a` `prio/must` `agent/human` |
| Depends on | DF-904 |
| PRD refs | §12.1, AS-DEV-08 |

**할 일.** App Store Connect 앱 레코드, TestFlight 내부 그룹, 배포 인증서, App Store Connect API 키를 준비하고 서명 인증서·API 키·plist를 GitHub Secrets에 등록한다. 값은 로그와 문서에 남기지 않는다.

**막는 것 / 막지 않는 것.** DF-139(trainer-testflight 워크플로), DF-387. **코딩 차단: 아니요.**

**완료 증빙.** 시크릿 이름 목록(값 없음)과 내부 그룹 존재 확인.

**늦을 때.** 최신 11-30. 늦으면 0.2를 Xcode 직접 설치로 대체한다(03 ASM-03-09).

---

<a id="df-923"></a>
### DF-923 BodyPath 패키지 CI 읽기 자격을 설정한다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P2 |
| Sprint | S23-S24 |
| Points | 0 |
| Priority | must |
| Area | ci |
| Gate | - |
| Labels | `type/task` `owner-action` `area/ci` `phase/P2` `prio/must` `agent/human` |
| Depends on | - |
| PRD refs | §10.4.2, AS-DEV-03 |

**할 일.** BodyPath 저장소가 비공개이면 DFET_Coach CI가 SPM 원격 의존을 해석할 수 있도록 읽기 전용 토큰(또는 배포 키)을 GitHub Secrets에 등록한다.

**막는 것 / 막지 않는 것.** DF-300, 트레이너 앱 CI의 원격 패키지 해석(DF-320). **코딩 차단: 아니요**(로컬에서는 소유자 자격으로 해석).

**완료 증빙.** 시크릿 이름과 등록일. 값은 로그에 출력하지 않는다.

---

<a id="df-924"></a>
### DF-924 MIG-03~06 적용과 MIG-07 기기 확인을 운영에서 실행한다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P1a |
| Sprint | S09 |
| Points | 1(size/XS) |
| Priority | must |
| Area | functions |
| Gate | - |
| Labels | `type/task` `owner-action` `area/functions` `area/rules` `phase/P1a` `prio/must` `size/XS` `agent/human` `rules-change` `schema-change` |
| Depends on | DF-100, DF-907, DF-931 |
| PRD refs | MIG-03~MIG-07, MIG-11, R-21 |

**할 일.** [V1-11 §5.8](../11_MIGRATION_RUNBOOK.md#58-운영-적용-절차df-924-s09)의 T-7일 공지, T-1일 리허설, T0 11단계를 실행한다. 관리형 내보내기 백업 → DF-100 스위치 PR 병합과 v1 쓰기 영구 차단 규칙 배포 → dry-run → apply → 재실행(멱등) → verify → 샘플 렌더 → 태그 `mig03-apply-YYYYMMDD` 순서다. MIG-07 기기 확인(V1-11 §9)도 함께 한다. Q-06은 기본값을 따른다.

**막는 것 / 막지 않는 것.** DF-925. **코딩 차단: 아니요.**

**완료 증빙.** `docs/v1/migrations/MIG-03-YYYYMMDD-<runId>.md`(V1-T10): dry-run·apply·verify 수량, 태그, 롤백 여부. 실데이터 값은 적지 않는다.

**늦을 때.** DF-925도 같은 폭으로 밀린다. 롤백은 MIG-11을 따르며 **v1 쓰기 차단 규칙은 되돌리지 않는다.**

---

<a id="df-925"></a>
### DF-925 soapV2·bodyComposition 플래그를 연다(P1a 진입)

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P1a |
| Sprint | S09(한계 S12, 12-18) |
| Points | 0 |
| Priority | must |
| Area | admin-web |
| Gate | G-04, G-09, G-05a, G-03 |
| Labels | `type/task` `owner-action` `area/admin-web` `phase/P1a` `prio/must` `gate/G-03` `gate/G-04` `gate/G-05a` `gate/G-09` `flag/soapV2` `flag/bodyComposition` `agent/human` |
| Depends on | DF-908, DF-909, DF-910, DF-924, DF-038 |
| PRD refs | §12.3 순서 1, G-04, G-09, G-05a, G-03 |

**할 일.** 전제(G-04·G-09 통과, G-05a 제출, MIG-03 적용, G-03)를 모두 확인한 뒤 AD-07에서 `soapV2`와 `bodyComposition`을 켠다. 이날이 P1a 자체 사용(2주 이상)의 시작점이다.

**막는 것 / 막지 않는 것.** 실데이터 입력과 자체 사용 시작. **코딩 차단: 아니요.**

**완료 증빙.** `docs/v1/evidence/flags-soapV2.md`, `flags-bodyComposition.md`: 전제 확인 체크리스트와 개방 일시.

**늦을 때.** 게이트가 미충족이면 연기하고 합성 데이터 개발을 계속한다. 자체 사용 시작일과 P1a 종료 검토(DF-927)를 같은 폭만큼 민다.

---

<a id="df-926"></a>
### DF-926 P0 단계 종료 검토를 한다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P0 |
| Sprint | S05(금 10-30) |
| Points | 0 |
| Priority | must |
| Area | docs |
| Gate | G-01, G-02, G-03 |
| Labels | `type/task` `owner-action` `area/docs` `phase/P0` `prio/must` `gate/G-01` `gate/G-02` `gate/G-03` `agent/human` |
| Depends on | DF-901, DF-903, DF-904, DF-905, DF-906, DF-907, DF-007, DF-009, DF-012, DF-013, DF-022, DF-023, DF-027, DF-031, DF-035, DF-038, DF-040 |
| PRD refs | §12.7, G-01, G-02, G-03 |

**할 일.** V1-T06으로 P0 종료를 검토한다. 기준: G-01·G-02·G-03 증빙, SOAP v2 Dart↔Swift 교차 왕복 CI, copy-lint 차단 모드, MIG-02 보고서, MIG-03 dry-run 멱등, 플래그 5키 false 배포.

**막는 것 / 막지 않는 것.** P1a 진입. **코딩 차단: 아니요**(P1a 기반 스토리 S06 착수는 검토 결과와 병행).

**완료 증빙.** `docs/v1/reviews/PHASE_P0_EXIT.md`.

---

<a id="df-927"></a>
### DF-927 P1a 단계 종료 검토를 한다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P1a |
| Sprint | S15(금 2027-01-08) |
| Points | 0 |
| Priority | must |
| Area | docs |
| Gate | - |
| Labels | `type/task` `owner-action` `area/docs` `phase/P1a` `prio/must` `agent/human` |
| Depends on | DF-141, DF-140, DF-142, DF-107, DF-925 |
| PRD refs | §12.1 P1a 종료, M-01, M-02, M-08, M-11, M-G1, M-G3 |

**할 일.** V1-T06으로 검토한다. 기준: 2주 이상 자체 사용, M-01 텍스트 평균 10초 미만(30초 초과 비율 보고), M-02·M-08·M-11, 유실 0·알리지 않은 저장 실패 0·금지어 노출 0, trainer-app-emulator-it 초록, trainer_ios 삭제, NFR-15(P1a).

**막는 것 / 막지 않는 것.** P1b 공식 진입, DF-929. P1b 코딩은 막지 않는다. **코딩 차단: 아니요.**

**완료 증빙.** `docs/v1/reviews/PHASE_P1a_EXIT.md`. M-01 미달이면 03 §11 T-10, 자체 사용 부족이면 1주 연기.

---

<a id="df-928"></a>
### DF-928 P1b 단계 종료 검토를 한다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P1b |
| Sprint | S18(금 2027-01-29) |
| Points | 0 |
| Priority | must |
| Area | docs |
| Gate | - |
| Labels | `type/task` `owner-action` `area/docs` `phase/P1b` `prio/must` `agent/human` |
| Depends on | DF-223, DF-226 |
| PRD refs | §12.1 P1b 종료, M-03, M-04a, M-04b, M-05, M-G5 |

**할 일.** V1-T06으로 검토한다. 기준: TR-07~TR-10과 O 자동 불러오기 동작, M-04a/b·M-03·M-05(조건 사유), M-G5, 실기기 촬영 기록(V1-T09), 유실 0.

**막는 것 / 막지 않는 것.** P2 진입. **코딩 차단: 아니요.**

**완료 증빙.** `docs/v1/reviews/PHASE_P1b_EXIT.md`. M-G5 초과 시 PRD §6.4.4 축소 절차.

---

<a id="df-929"></a>
### DF-929 bodyAssessment 플래그를 연다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P1b |
| Sprint | S17 |
| Points | 0 |
| Priority | must |
| Area | admin-web |
| Gate | - |
| Labels | `type/task` `owner-action` `area/admin-web` `phase/P1b` `prio/must` `flag/bodyAssessment` `agent/human` |
| Depends on | DF-927, DF-209 |
| PRD refs | §12.3 순서 2 |

**할 일.** P1a 종료(DF-927)와 TR-07~TR-09 동작(DF-209) 확인 뒤 AD-07에서 `bodyAssessment`를 켠다.

**막는 것 / 막지 않는 것.** 운영에서의 체형 촬영. **코딩 차단: 아니요**(미개방 시 P1b 기능은 DEBUG 오버라이드로 검증).

**완료 증빙.** `docs/v1/evidence/flags-bodyAssessment.md`.

---

<a id="df-930"></a>
### DF-930 Runner 내장 트레이너 동결을 선언한다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P0 |
| Sprint | S01(수 09-30) |
| Points | 0 |
| Priority | must |
| Area | docs |
| Gate | G-01 |
| Labels | `type/task` `owner-action` `area/docs` `phase/P0` `prio/must` `gate/G-01` `agent/human` `freeze-exception` |
| Depends on | - |
| PRD refs | MIG-09, D2 |

**할 일.** Runner 내장 트레이너(`ios/Runner/AppDelegate.swift`)와 `trainer_ios/`의 동결을 선언한다. 이후 두 영역을 바꾸는 PR은 `freeze-exception` 라벨과 사유가 필요하다. DF-902 전이면 `freeze-exception` 라벨 하나만 먼저 만든다. CODEOWNERS에 두 경로가 있는지 확인한다. 절차는 [V1-11 §11.2](../11_MIGRATION_RUNBOOK.md#112-동결-선언df-930-s01)다.

**막는 것 / 막지 않는 것.** DF-028(동결 예외 PR). **코딩 차단: 아니요.**

**완료 증빙.** G-01.md '동결 선언' 절([기록 2026-09-25](../evidence/G-01.md#동결-선언)).

---

<a id="df-931"></a>
### DF-931 규칙·Storage 규칙·인덱스·Functions를 태그 기준으로 운영에 배포한다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P1a |
| Sprint | S08 |
| Points | 1(size/XS) |
| Priority | must |
| Area | rules |
| Gate | G-03 |
| Labels | `type/task` `owner-action` `area/rules` `area/storage` `area/functions` `phase/P1a` `prio/must` `size/XS` `gate/G-03` `agent/human` `rules-change` |
| Depends on | DF-022, DF-035, DF-023, DF-024, DF-025, DF-043 |
| PRD refs | G-03, ADR-014 |

**할 일.** `rules-YYYYMMDD-N`, `functions-YYYYMMDD-N` 태그를 체크아웃한 상태에서 규칙·인덱스·Storage 규칙과 새 함수(이름 지정)를 배포한다. 명령 형식은 [03 §9.3](../03_RELEASE_AND_SPRINT_PLAN.md#93-규칙인덱스functionsadmin_web)이다. v1 쓰기 차단 스위치는 **아직 끈 상태**로 배포하고 DF-924에서 켠다. 기존 callable 이름·리전은 바꾸지 않는다(NFR-16). Storage 규칙은 `firebase.json`이 가리키는 서울 버킷(DF-043)에, Firestore 규칙·인덱스는 서울 `(default)`(DF-942)에 간다. 배포 전 `firebase.json`의 대상 버킷과 콘솔의 버킷 위치가 서울인지 확인한다(DEC-19).

**막는 것 / 막지 않는 것.** 운영에서의 P1a 기능 동작 전체, DF-924. **코딩 차단: 아니요**(개발은 에뮬레이터).

**완료 증빙.** G-03.md에 태그, R·S 100% CI 링크, 배포 체크리스트.

---

<a id="df-932"></a>
### DF-932 Firestore·Storage Data Access 감사 로그를 켠다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P1a |
| Sprint | S08 |
| Points | 0 |
| Priority | must |
| Area | privacy |
| Gate | - |
| Labels | `type/task` `owner-action` `area/privacy` `phase/P1a` `prio/must` `agent/human` `privacy-impact` |
| Depends on | - |
| PRD refs | F-PRIV-05.3, AC-PRIV-05.2 |

**할 일.** Cloud Audit Logs에서 Firestore·Storage의 Data Access 로그를 켜고 보존 기간(2년)을 확인한다.

**막는 것 / 막지 않는 것.** AC-PRIV-05.2의 1차 증빙(DF-115는 보조 기록). **코딩 차단: 아니요.**

**완료 증빙.** 설정 스크린숏 또는 설정 내보내기(프로젝트 식별자 외 값 없음), 보존 기간.

---

<a id="df-933"></a>
### DF-933 로그 기반 알림 정책(이메일)을 설정한다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P1a |
| Sprint | S12 |
| Points | 0 |
| Priority | should |
| Area | functions |
| Gate | - |
| Labels | `type/task` `owner-action` `area/functions` `phase/P1a` `prio/should` `agent/human` |
| Depends on | DF-134 |
| PRD refs | F-PRIV-04.4, F-PRIV-07.4, AS-DEV-13 |

**할 일.** DF-134의 구조화 로그(기한 초과 권리 요청, 삭제 실패, 재정렬 실패)에 Cloud Logging 로그 기반 알림 정책을 만들어 소유자 이메일로 받는다.

**막는 것 / 막지 않는 것.** DF-134 경보 수신. **코딩 차단: 아니요.**

**완료 증빙.** 테스트 알림 수신 기록(수신 주소는 적지 않는다).

---

<a id="df-934"></a>
### DF-934 memberShare 플래그를 연다(P2)

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P2 |
| Sprint | S23-S24 |
| Points | 0 |
| Priority | must |
| Area | admin-web |
| Gate | G-05b |
| Labels | `type/task` `owner-action` `area/admin-web` `phase/P2` `prio/must` `gate/G-05b` `flag/memberShare` `agent/human` |
| Depends on | DF-919, DF-306, DF-307, DF-316 |
| PRD refs | §12.3 순서 3, G-05b |

**할 일.** G-05b 통과와 회원 앱 P2 릴리스(MB-05·MB-06) 스토어 반영을 확인한 뒤 `memberShare`를 켠다. 추가 제안 DF-940이 채택되면 의존에 DF-940을 더한다.

**막는 것 / 막지 않는 것.** 실사용 공유. **코딩 차단: 아니요**(공유 기능 병합은 계속).

**완료 증빙.** `docs/v1/evidence/flags-memberShare.md`.

---

<a id="df-935"></a>
### DF-935 lidarBeta를 내부 트레이너 대상으로 연다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P2 |
| Sprint | S25-S26 |
| Points | 0 |
| Priority | should |
| Area | admin-web |
| Gate | G-07a |
| Labels | `type/task` `owner-action` `area/admin-web` `phase/P2` `prio/should` `gate/G-07a` `flag/lidarBeta` `agent/human` |
| Depends on | DF-917, DF-321 |
| PRD refs | §12.3 순서 4, G-07a, NFR-13 |

**할 일.** G-07a(DF-917)와 기기 능력(NFR-13), 대상 회원의 동의 ②③을 확인한 뒤 내부 트레이너만 쓰는 조건으로 `lidarBeta`를 켠다. 플래그는 전역 불리언이므로(ADR-010) '내부 트레이너만'은 TestFlight 배포 대상으로 통제한다.

**막는 것 / 막지 않는 것.** TR-13 실사용. **코딩 차단: 아니요.**

**완료 증빙.** `docs/v1/evidence/flags-lidarBeta.md`. G-07a 미충족이면 P3 이후로 연기한다.

---

<a id="df-936"></a>
### DF-936 P2 단계 종료 검토를 한다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P2 |
| Sprint | S25-S26(금 2027-03-26) |
| Points | 0 |
| Priority | must |
| Area | docs |
| Gate | - |
| Labels | `type/task` `owner-action` `area/docs` `phase/P2` `prio/must` `agent/human` |
| Depends on | DF-332 |
| PRD refs | §12.1 P2 종료, M-06, M-07, M-09, M-10 |

**할 일.** V1-T06으로 검토한다. 기준: 공유·해제 E2E, 담당 변경·④ 인계·탈퇴 연쇄, M-06·M-07·M-09·M-10, trainerWorkspaces 0건, G-07 상태와 베타 유지·해제 판단. 추가 제안 DF-335·DF-338이 채택되면 의존에 더한다.

**막는 것 / 막지 않는 것.** P3 진입. **코딩 차단: 아니요.**

**완료 증빙.** `docs/v1/reviews/PHASE_P2_EXIT.md`. G-07 미완이면 우회 결정 문서(03 차이 D-3).

---

<a id="df-937"></a>
### DF-937 센터 위탁계약과 센터 명의 처리방침·동의 문서를 준비한다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P3 |
| Sprint | S27-S29 |
| Points | 1(size/XS) |
| Priority | must |
| Area | privacy |
| Gate | G-04 |
| Labels | `type/task` `owner-action` `area/privacy` `phase/P3` `prio/must` `size/XS` `gate/G-04` `agent/human` `privacy-impact` |
| Depends on | DF-908 |
| PRD refs | §6.7.0, AS-31, Q-21 |

**할 일.** 처리 주체 모델(§6.7.0, Q-21 결과)에 따라 센터와 위탁계약을 맺고, 센터 명의 처리방침과 새 동의 문서 버전을 AD-03으로 게시한다. 수탁자를 공개한다.

**막는 것 / 막지 않는 것.** 센터 실사용. **코딩 차단: 아니요.**

**완료 증빙.** G-04.md 갱신(P3), 새 동의 문서 버전 ID.

---

<a id="df-938"></a>
### DF-938 GA 검토를 하고 PRD v1.1을 발행한다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P3 |
| Sprint | S30-S32(1.0 05-07, GA 판정 2027-06-04) |
| Points | 0 |
| Priority | must |
| Area | docs |
| Gate | - |
| Labels | `type/task` `owner-action` `area/docs` `phase/P3` `prio/must` `agent/human` |
| Depends on | DF-390 |
| PRD refs | §12.1 P3 종료, §12.7 |

**할 일.** V1-T06으로 P3 종료를 검토하고, 가설 목표가 4주 유지되는지 확인한 뒤 GA를 판정한다. 결과를 반영해 PRD v1.1을 발행한다(PRD 수정은 소유자만).

**막는 것 / 막지 않는 것.** v1 종료. **코딩 차단: 아니요.**

**완료 증빙.** `docs/v1/reviews/PHASE_P3_EXIT.md`, PRD v1.1 변경 이력.

---

<a id="df-939"></a>
### DF-939 G-06 재검사 연구 보고서 또는 '문헌값 유지' 결정 문서를 작성한다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P2 |
| Sprint | S25-S26 |
| Points | 1(size/XS) |
| Priority | must |
| Area | privacy |
| Gate | G-06 |
| Labels | `type/task` `owner-action` `area/privacy` `phase/P2` `prio/must` `size/XS` `gate/G-06` `agent/human` `privacy-impact` |
| Depends on | DF-912, DF-326 |
| PRD refs | G-06, §7.3.3, RISK-11 |

**할 일.** 재검사 데이터(가명 데이터셋, DF-326)로 ICC 유형·SEM·MDC95를 산출해 보고서를 쓰거나, 수집 미달이면 '문헌값 유지·회원 배지 없음' 결정 문서를 쓴다.

**막는 것 / 막지 않는 것.** G-08(DF-920). **코딩 차단: 아니요.**

**완료 증빙.** `docs/v1/evidence/G-06.md` 갱신: 보고서 또는 결정 사유, 가명처리 확인.

---

<a id="df-940"></a>
### DF-940 (추가 제안·채택 대기) 회원 앱 P2 릴리스(MB-01~MB-06)를 스토어에 제출한다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P2 |
| Sprint | S23-S24(제안) |
| Points | 1(size/XS) |
| Priority | must |
| Area | member-app |
| Gate | - |
| Labels | `type/task` `owner-action` `area/member-app` `phase/P2` `prio/must` `size/XS` `agent/human` `status/needs-decision` |
| Depends on | DF-306, DF-307, DF-315, DF-316 |
| PRD refs | §12.3 순서 3, §10.5, MB-05, MB-06 |

**할 일.** MB-01~MB-06을 플래그 false 상태로 포함한 회원 앱 릴리스를 `member-vX.Y.Z` 태그로 제출한다.

**왜 제안인가.** DF-934가 'MB-05·MB-06 배포 확인'에 의존하는데 제출 행동 자체가 백로그에 없다([P2_P3 §2](P2_P3.md)). 결정 시점은 P2 진입 계획(S19)이다. 채택하면 DF-934 의존에 DF-940을 더한다.

**코딩 차단.** 아니요.

---

<a id="df-941"></a>
### DF-941 (추가 제안·채택 대기) Functions 런타임 서비스 계정에 서명 URL 발급 권한을 부여한다

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P2 |
| Sprint | S21-S22(제안) |
| Points | 0 |
| Priority | must |
| Area | functions |
| Gate | - |
| Labels | `type/task` `owner-action` `area/functions` `phase/P2` `prio/must` `agent/human` `status/needs-decision` |
| Depends on | - |
| PRD refs | F-LINK-05.6, §9.5 |

**할 일.** `getSharedPhotoUrl`(DF-314)과 `exportMemberData`(DF-135)가 v4 서명 URL을 만들 수 있도록 Functions 런타임 서비스 계정에 서명 권한(`iam.serviceAccounts.signBlob`)을 부여한다. DF-135 운영 배포 때 이미 부여했다면 확인만 한다.

**왜 제안인가.** Cloud Functions 기본 서비스 계정에는 서명 권한이 기본으로 없다([P2_P3 §2](P2_P3.md)). 결정 시점은 P2 진입 계획(S19)이다. 채택하면 DF-314 의존에 DF-941을 더한다.

**코딩 차단.** 아니요(코딩은 가짜 서명기로 진행하고 운영 확인만 막힌다).

---

<a id="df-942"></a>
### DF-942 운영 데이터를 서울(asia-northeast3)로 옮긴다: nam5 (default) 삭제·재생성, 서울 Storage 버킷 생성·연결, 앱 구성 재확인

| 항목 | 값 |
|---|---|
| Epic | EP-00 소유자 행동·외부 게이트 트랙 |
| Type | owner-action |
| Phase | P0 |
| Sprint | S01(화 09-29) |
| Points | 1(size/XS) |
| Priority | must |
| Area | privacy |
| Gate | G-09 |
| Labels | `type/task` `owner-action` `area/privacy` `area/storage` `phase/P0` `prio/must` `size/XS` `gate/G-09` `agent/human` `privacy-impact` |
| Depends on | - |
| PRD refs | G-09, Q-08, AS-19, §9.7 |

**할 일.** 소유자 결정 DEC-19([V1-00 결정 기록](../00_README.md#결정-기록))를 실행하는 운영 작업이다. 소유자가 승인하고 직접 한다. 에이전트는 실행하지 않는다.
1. 사전 확인: 운영 `(default)`(`nam5`)에 테스트 데이터만 있음을 다시 확인한다(컬렉션 이름과 문서 수만 본다). 운영 규칙이 전부 거부라 회원 앱 클라이언트가 읽고 쓰는 데이터는 없다([G-01 후속 1](../evidence/G-01.md#후속-조치)). 테스트 데이터라 내보내기로 보존하지 않는다. **삭제 전에** 같은 ID `(default)`를 `asia-northeast3`에 다시 만들 수 있는지 확인한다: 프로젝트에 위치를 묶는 설정(레거시 App Engine 앱, 기본 GCP 리소스 위치)이 있는지, 삭제한 데이터베이스 ID를 다시 쓰기 전 대기 시간이 있는지를 콘솔·공식 문서로 본다. 묶여 있거나 불확실하면 삭제하지 않고 멈춘다(아래 중단 규칙).
2. Firestore: 삭제 보호를 끄고 `(default)`를 삭제한 뒤, 같은 ID `(default)`를 `asia-northeast3`, 기존과 같은 Standard 에디션으로 다시 만든다. 삭제 보호를 다시 켠다. 규칙은 기본 전부 거부 그대로 둔다(첫 배포는 DF-931).
   - **중단 규칙**: 1의 사전 확인에서 막히거나, 재생성이 거부되거나(위치 고정, ID 재사용 대기 등) `asia-northeast3` 외 위치만 허용되면 **이름 있는 새 DB를 만들지 않는다**. DF-043은 '코드의 DB 참조(`(default)`)는 바뀌지 않는다'를 전제로 하므로, 이름 있는 DB로 가면 DF-043 범위와 규칙·에뮬레이터·Functions 트리거 설정이 모두 바뀐다. 이 단계에서 멈추고 결과(거부 메시지 요지)를 G-09.md에 적은 뒤 DEC-19와 DF-043을 다시 열어 DB ID를 소유자가 명시적으로 정한다. 대기 시간 때문이면 기다린 뒤 다시 만들고, 늦은 만큼 DF-043·DF-905 일정을 조정한다.
3. Storage: `asia-northeast3` 단일 리전 버킷을 만들고 Firebase Storage에 연결한다(콘솔 '버킷 추가'). 규칙은 전부 거부로 둔다. 기본 버킷은 위치를 바꿀 수 없어 그대로 남는다.
4. 앱 구성 재확인: 서울 버킷은 기본 버킷이 아니므로 `GoogleService-Info.plist`·`google-services.json`·`lib/firebase_options.dart`의 `storageBucket`은 바뀌지 않는다. 구성 파일을 다시 받아(FlutterFire 재구성 포함) 저장소 파일과 차이가 없는지만 확인하고, 차이가 있으면 DF-043에 알린다. 서울 버킷 이름을 DF-043에 넘긴다. admin_web 운영 환경 변수 `NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET`을 서울 버킷으로 바꾼다(값은 저장소에 적지 않는다). DF-903 뒤에 하면 트레이너 앱 plist도 같은 방식으로 확인한다.
5. 기록: `docs/v1/evidence/G-09.md`(V1-T07, 없으면 이때 만든다)에 리전 절을 쓴다.

**막는 것 / 막지 않는 것.** DF-043(버킷 이름), DF-905(가상 회원은 새 DB에), DF-906·DF-038(S-09 실환경 확인은 서울 버킷·새 DB에서), DF-909(리전 기록), DF-931(첫 규칙 배포), 모든 실데이터 투입. **코딩 차단: 아니요**(개발은 에뮬레이터와 합성 데이터).

**완료 증빙.** G-09.md 리전 절: Firestore `(default)` 위치 `asia-northeast3`와 생성 일시, 삭제한 `nam5` DB에 테스트 데이터만 있었다는 확인(수량만), 서울 버킷 이름·위치·Firebase 연결 일시, 앱 구성 재확인 결과. 앱 ID·API 키·서비스 계정 값은 적지 않는다.

**늦을 때.** 최신 10-02(S01 금). 늦으면 DF-043(S02)과 DF-905가 같이 밀린다. 실데이터가 들어간 뒤에는 DB 위치를 바꿀 수 없으므로 DF-038 프로브(S03)와 DF-931(S08) 전에 반드시 끝낸다.

**남은 소유자 결정.** 미사용 Enterprise DB 2개(`default`, `dfet`, `asia-east1`)의 유지·삭제(비용), 미국 기본 버킷의 테스트 파일 정리([V1-00 K-17](../00_README.md#알려진-차이와-남은-일)). 운영 DB가 비게 되므로 MIG-02 실사(DF-907)와 MIG-03~07 적용(DF-924)의 운영 대상 범위를 S04 계획 전에 다시 본다.

## 4. 가정(ASM-OA-NN)

| ID | 가정 | 근거 | 틀리면 |
|---|---|---|---|
| ASM-OA-01 | owner-action 이슈의 GitHub 유형 라벨은 `type/task`이고 `owner-action` 라벨로 구분한다 | 02 ASM-02-01 | 라벨 체계에 `type/owner-action` 추가 |
| ASM-OA-02 | 모든 owner-action에 `agent/human`을 붙여 에이전트 배정 대상에서 뺀다 | 01 에이전트 금지 행동 | 라벨만 제거 |
| ASM-OA-03 | P1a 종료 검토(DF-927)의 의존에 DF-925를 넣어 '2주 자체 사용'의 시작점을 명시한다 | 02 §8.7 보강 | 의존에서 제거하고 검토 입력으로만 둔다 |
| ASM-OA-04 | 이관·게이트 증빙 폴더(`docs/v1/evidence/`, `docs/v1/migrations/`, `docs/v1/reviews/`)는 첫 증빙 PR에서 만든다. 헤더 표준 린트 대상이다 | 01 ASM-01-11, 03 ASM-03-11 | 폴더 이름만 조정 |
| ASM-OA-05 | owner-action 점수(0~1)는 스프린트 약속·속도에 포함한다(R1 결정 2026-09-24). 예상·실제 소유자 시간은 V1-T05 "소유자 시간" 표에 따로 적는다 | 01 ASM-01-16, 02 §4.3, SPRINT_01 약속 18 = 개발 15 + 소유자 3 | 속도 계산에서 빼고 01·02·SPRINT_01을 함께 고친다 |

## 5. 변경 이력

| 버전 | 날짜 | 작성 | 내용 |
|---|---|---|---|
| v1.0 | 2026-09-24 | CJH(AI 에이전트 초안) | 최초 작성. 02 §8.7 색인, 03 §5 게이트 트랙, SPRINT_01 §7.1·§7.8, V1-11 MIG-01·02·03 절차에서 카드 41건(채택 39, 제안 2)을 옮김 |
| v1.0(정합 패스 2) | 2026-09-24 | CJH(AI 에이전트) | 속도 포함 규칙(R1), 가정 ID 참조(R10) |
| v1.0.1 | 2026-09-24 | CJH(AI 에이전트) | 교차 정합성 조정: §0 점수 줄에 owner-action 점수의 약속·속도 포함 명시(R1), ASM-OA-04 근거를 01 ASM-01-11로 정정(R10), ASM-OA-05 추가 |
| v1.1 | 2026-09-25 | CJH(AI 에이전트, 소유자 결정 기록) | 소유자 결정 2026-09-25 반영: DEC-19 서울 리전 전환 [DF-942](#df-942) 카드 추가(S01, 1점), DF-905·DF-906·DF-909 의존에 DF-942, DF-931 의존에 DF-043, DF-908 보류(S03 발송 계획, 최신 10-30), DF-930 증빙 링크, §1·§2 표 갱신. DF-942에 재생성 사전 확인과 중단 규칙(이름 있는 DB 금지, DEC-19·DF-043 재개), DF-909 늦을 때에 DF-908 이월 시 분리 |
