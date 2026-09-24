# 애자일 작업 합의 (1인 PO·개발 + AI 에이전트)

| 항목 | 내용 |
|---|---|
| 문서 ID | V1-01 |
| 버전 | v1.0 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | §0.5 ID 체계, §6.0.3 공통 상태 표기, §6.0.5 C-05·C-06, §10.8 NFR-03·NFR-06·NFR-10, §11.2 MIG-01, §11.10 MIG-09, §12.1~§12.7, §13.4 |
| 관련 에픽·스토리 | EP-00(DF-901~939), EP-01(DF-001, DF-002, DF-011, DF-034, DF-107, DF-139), EP-06(DF-010, DF-040) |
| 변경 규칙 | [문서 변경](01_AGILE_WORKING_AGREEMENT.md#문서-변경) |

## 목차

- [목적과 적용 범위](#목적과-적용-범위)
- [역할과 책임](#역할과-책임)
- [스프린트 리듬](#스프린트-리듬)
- [스프린트 달력](#스프린트-달력)
- [백로그 구조와 다듬기](#백로그-구조와-다듬기)
- [준비 완료 정의(DoR)](#준비-완료-정의dor)
- [완료 정의(DoD)](#완료-정의dod)
- [추정과 속도](#추정과-속도)
- [WIP 제한](#wip-제한)
- [브랜치·커밋·PR 규칙](#브랜치커밋pr-규칙)
- [AI 에이전트 작업 흐름](#ai-에이전트-작업-흐름)
- [게이트와 소유자 행동의 스프린트 편입](#게이트와-소유자-행동의-스프린트-편입)
- [버그·스파이크·기술 부채](#버그스파이크기술-부채)
- [동결 예외 절차](#동결-예외-절차)
- [GitHub Projects 보드](#github-projects-보드)
- [단계 종료 검토](#단계-종료-검토)
- [문서 변경](#문서-변경)
- [가정과 스파인 차이 기록](#가정과-스파인-차이-기록)
- [변경 이력](#변경-이력)

---

## 목적과 적용 범위

이 문서는 D-FET Coach v1을 **1인 소유자(PO 겸 개발자) + AI 코딩 에이전트(Claude, Codex)** 체제로 개발할 때의 작업 합의다. 스프린트 운영, 백로그, 품질 기준(DoR·DoD), 브랜치·PR 규칙, 에이전트 작업 규약, 외부 게이트 편입 방식을 정한다.

- 적용 대상: 저장소 `TEhyeok/DFET_Coach`(트렁크 `main`)의 모든 v1 작업과, P2부터 `TEhyeok/BodyPath`의 BodyPathCore 작업(DF-300~303).
- 정본 순서: [PRD v1](../PRD_V1.md) > 이 문서군(docs/v1) > 이슈 본문. 이 문서가 PRD와 충돌하면 PRD가 이긴다. 이 문서는 PRD ID(F-, AC-, NFR-, G-, MIG-, TR-, R-, S- 등)를 **인용만** 하고 새로 만들지 않는다(PRD §0.5).
- 관련 문서: 백로그 총괄 [V1-02](02_PRODUCT_BACKLOG.md), 릴리스·스프린트 계획 [V1-03](03_RELEASE_AND_SPRINT_PLAN.md), 브랜칭·릴리스 결정 [ADR-014](adr/ADR-014-branching-release.md), 테스트 전략 [ADR-013](adr/ADR-013-testing-strategy.md), 개발 환경·에이전트 플레이북 [V1-13](13_DEV_ENVIRONMENT_AND_AGENT_PLAYBOOK.md), 템플릿 [templates/](templates/).

**세 가지 기본 원칙**

1. **게이트가 달력보다 우선한다**(PRD §12). 날짜는 잠정이고, 단계 전환·실데이터 투입·플래그 개방은 게이트 증빙이 있어야만 한다.
2. **외부 게이트는 코딩을 막지 않는다.** 법률(G-04, G-09), 식약처(G-05a/b), IRB(G-06, G-07)가 늦어져도 합성 데이터와 에뮬레이터로 개발은 계속한다. 막히는 것은 단계 전환, 실데이터, 플래그 개방뿐이다.
3. **검토 역량이 속도의 상한이다.** 에이전트는 코드를 빨리 만들지만, 병합 판단과 규칙·개인정보 경로 검토는 소유자 한 사람이 한다. 모든 추정·WIP 규칙은 소유자 검토 시간을 기준으로 잡는다.

---

## 역할과 책임

### 역할 정의

| 역할 | 담당 | 책임 | 권한 |
|---|---|---|---|
| PO(제품 책임자) | 소유자 CJH | 백로그 우선순위, 스토리 수용·반려, 단계 종료 판정, PRD 개정 | PRD 수정, 우선순위 결정, 플래그 개방 |
| 개발자·통합자 | 소유자 CJH | 에이전트 작업 지시서 작성, 통합, 실기기 확인, 에이전트가 못 하는 작업(서명, 콘솔, 실기기) | 모든 경로 쓰기 |
| 리뷰어·병합자 | 소유자 CJH | 모든 PR 검토, 민감 경로 diff 직접 읽기, 스쿼시 병합 | `main` 병합(유일) |
| 게이트 책임자 | 소유자 CJH | G-01~G-10 증빙 수집, 외부 기관 접수, EP-00 트랙 운영 | 게이트 판정 기록 |
| 배포자·이관 실행자 | 소유자 CJH | 규칙·인덱스·Functions 배포, TestFlight 업로드, MIG-02~10 운영 실행 | `firebase deploy`, 운영 데이터 접근 |
| 구현 에이전트 | Claude Code, Codex | 작업 지시서 범위 안의 구현, 테스트 작성·실행, PR 초안 작성, 완료 보고 | 자기 브랜치 푸시, draft PR 생성 |
| 외부 자문 | 법률 자문, 규제 자문, IRB, 변리 자문 | G-04·G-05b·G-06·G-07·Q-17 의견 | — (소유자가 결과를 기록) |
| 협업자 | Windows/GPU 협업자 | BodyPath 재구성 서버·연구 트랙 협업. v1 런타임은 GPU 경로에 의존하지 않는다(PRD §0.1) | 가명 처리 데이터만, 서면 약정 후(PRD §12.6) |

1인 체제라 한 사람이 여러 역할을 겸한다. 그래서 **역할 전환을 의식에 묶는다**: 월요일 계획은 PO, 화~목은 개발자·리뷰어, 수요일 15분은 게이트 책임자, 금요일은 PO(수용 판정)로 일한다.

### 에이전트 권한 경계

| 구분 | 허용 | 금지 |
|---|---|---|
| Git | `claude/DF-NNN-<slug>`·`codex/DF-NNN-<slug>` 브랜치(스프린트 문서 초안은 `claude/sprint-NN`·`codex/sprint-NN`) 생성·푸시, draft PR 생성 | `main` 직접 푸시, 병합, 자동 병합 설정, force-push to `main`, 태그 생성 |
| GitHub | 할당된 이슈에 완료 보고 코멘트 | **이슈 생성**, 라벨·마일스톤·Projects 수정, 저장소 설정 변경 |
| 파일 | 작업 지시서의 '수정 허용 경로' | 지시서 밖 경로, `docs/PRD_V1.md`(수정 제안만), `trainer_ios/`(동결, DF-142 삭제 전까지 읽기만), `ios/Runner/AppDelegate.swift`(freeze-exception 지시서가 있을 때만) |
| 비밀 | — | `.env*`, `functions/.secret.local`, `GoogleService-Info.plist` 값, 서명 인증서, API 키, 서비스 계정 키 **열람·출력·커밋**(ADR-019) |
| 데이터 | 합성 가상 회원, `contracts/fixtures/**`, 에뮬레이터 | 운영 Firestore·Storage 접근, `output/`·`tmp/`·내보내기 파일·회원 데이터 열람 |
| 실행 | 단위 테스트, 에뮬레이터, 시뮬레이터, 린트, 생성기 | `firebase deploy`, 이관 스크립트 `--apply`, TestFlight 업로드, 운영 프로젝트를 가리키는 모든 명령 |
| 의존성 | 지시서가 허용한 것만 | 새 npm·SPM·pub 의존성 추가(ADR 없이). Functions는 ADR-017, Swift 스냅샷 도구는 ADR-013에 정한 것만 |

위반을 발견하면 해당 PR은 내용과 무관하게 닫고, 원인을 회고(V1-T11)에 기록한 뒤 지시서를 고친다.

---

## 스프린트 리듬

스프린트는 **1주(월~금)**다. 모든 의식은 짧게 유지하고, 결과는 GitHub(이슈·Projects)와 `docs/v1/sprints/SPRINT_NN.md`에 남긴다.

| 의식 | 시점 | 시간 | 역할 | 입력 | 산출물 | 템플릿 |
|---|---|---|---|---|---|---|
| 스프린트 계획 | 월 09:30 | 45분 | PO | 직전 리뷰, 속도, Ready 이슈, 게이트 트랙, 금요일에 에이전트가 만든 `SPRINT_NN.md` 초안 | `SPRINT_NN.md` 확정(목표, 약속 표, 에이전트 배정), Projects Iteration 지정 | [V1-T04](templates/SPRINT_PLAN.md) |
| 일일 비동기 기록 | 작업일 18:00 | 5분 | 소유자 | 당일 병합·검토·차단 | 스프린트 추적 이슈에 코멘트 1건 | [V1-T12](templates/DAILY_LOG.md) |
| 게이트 트랙 점검 | 수 16:00 | 15분 | 게이트 책임자 | [OWNER_ACTIONS_AND_GATES](backlog/OWNER_ACTIONS_AND_GATES.md), 외부 회신 | Gate 필드 갱신, 지연 시 대안 결정 | [V1-T07](templates/GATE_EVIDENCE.md) |
| 백로그 다듬기 | 목 14:00 | 60분 | PO·개발자 | 다음 2개 스프린트 후보(약 10~12개) | DoR 점검, 분할, 카드의 '에이전트 브리프' 작성, `brief.mjs`로 지시서 생성·부착 | [V1-T01](templates/STORY.md), [V1-T08](templates/AGENT_BRIEF.md) |
| 스프린트 리뷰·데모 | 금 15:00 | 20분 | PO | 완료·이월, 데모 증빙, 속도, 소유자 시간 | `SPRINT_NN.md` 리뷰 절 | [V1-T05](templates/SPRINT_REVIEW.md) |
| 회고 | 금 15:20 | 10분 | PO | 일일 기록, 반려 사유, CI 실패 | 개선 행동 1~2개 | [V1-T11](templates/RETRO.md) |
| 다음 스프린트 초안 | 금 회고 뒤(비동기) | 소유자 0분 | 에이전트 | `tool/backlog/issues.json`, Projects 내보내기, 이번 리뷰의 이월 | `SPRINT_NN+1.md` 초안(draft PR, 약 1쪽, 약속 표의 점수·경로는 소유자가 확정) | [V1-T04](templates/SPRINT_PLAN.md) |
| 단계 종료 검토 | 단계 마지막 스프린트 금 13:30 | 60분 | PO·게이트 책임자 | M-01~M-11, M-G1~M-G5, NFR-15, 게이트 증빙 | 검토 기록, 가설 목표 재설정 | [V1-T06](templates/PHASE_EXIT_REVIEW.md) |

이 표가 의식 시각의 정본이다. 스프린트 문서(`SPRINT_NN.md`)는 이 시각을 따르고, 다르게 잡을 때만 그 주 사유를 적는다.

**스프린트 문서 분량**: `SPRINT_NN.md`는 [V1-T04](templates/SPRINT_PLAN.md) 형식으로 **약 1쪽**(약속 표, 에이전트 배정, 소유자 행동, 위험, 데모 기준)에 맞춘다. 일자별 명령 수준의 계획은 쓰지 않는다. 스토리별 세부는 카드와 작업 지시서에 있다. 금요일 회고 뒤 에이전트가 이슈 JSON과 이월 목록에서 초안을 만들고(브랜치 `claude/sprint-NN` 또는 `codex/sprint-NN`, draft PR), 소유자는 월요일 계획에서 고쳐 확정한다. [SPRINT_01](sprints/SPRINT_01.md)은 첫 주라 예외적으로 자세히 썼다([ASM-01-18](#가정과-스파인-차이-기록)).

**휴일 주 이동 규칙**: 계획은 그 주 첫 작업일, 리뷰·회고는 마지막 작업일로 옮긴다. 수요일 점검이 휴일이면 다음 작업일로 옮긴다. 휴일 주의 의식 시간은 줄이지 않는다(짧은 주일수록 계획이 중요하다).

**스프린트 추적 이슈**: 스프린트마다 소유자가 `[S01] 진행 기록` 이슈(type/chore)를 하나 만들어 일일 기록을 코멘트로 모은다. 에이전트는 이 이슈에 쓰지 않는다([ASM-01-10](#가정과-스파인-차이-기록)).

**S01 1~2일차 순서(2026-09-28 월 ~ 09-29 화)**

DF-901은 약 1.5일 걸린다고 본다([SPRINT_01 ASM-S01-01](sprints/SPRINT_01.md), [V1-03 D-4](03_RELEASE_AND_SPRINT_PLAN.md)). 백로그 스파인의 '1일차 오전 완료'보다 현실적인 이 계획이 정본이다.

1. 월 09:30 계획 45분(S01 약속 확정).
2. 월 전일 ~ 화 오전: 소유자가 DF-901(MIG-01, G-01)을 한다. 88줄 분류, hunk 분리, A분류 커밋, B분류를 `archive/trainer-ui-2026-09`에 보관하고 tip 해시를 기록한다. 절차는 [V1-11](11_MIGRATION_RUNBOOK.md) MIG-01.
3. **화 12:00까지** DF-901 PR을 CI 초록으로 `main`에 병합하고 브랜치 보호를 켠다.
4. 월 오후부터 에이전트는 **기존 미커밋 파일과 겹치지 않는 새 경로**(`contracts/`, `trainer_app/`, `tool/contracts/`, `docs/v1/` 등 저장소에 아직 없는 경로)에서만 브랜치를 만들고 푸시·draft PR까지 할 수 있다. 기존 파일(`firestore.rules`, `functions/**`, `lib/**`, `ios/**`, 기존 `.github/workflows/ci.yml` 등)을 고치는 작업은 DF-901 병합 뒤에 시작한다.
5. DF-901 병합 전에는 **어떤 에이전트 PR도 병합하지 않는다.** 병합 뒤 각 브랜치를 `main`에 rebase하고 CI를 다시 돌린 다음 병합한다.

---

## 스프린트 달력

오늘(2026-09-24, 목)은 추석 연휴(09-24~26) 중이므로 스프린트 0은 두지 않는다. S01은 2026-09-28(월)에 시작한다. 단계 배치는 [백로그 스파인](02_PRODUCT_BACKLOG.md)의 속도 기반 배치를 따른다. S19 이후는 잠정이며 2주 묶음으로 계획하고 스프린트 계획은 여전히 1주 단위로 한다.

**휴일**: 추석 연휴 2026-09-24~26, 개천절 10-03(토)의 대체공휴일 10-05(월)(AS-DEV-01), 한글날 10-09(금), 성탄절 12-25(금), 신정 2027-01-01(금), 2027 설 연휴(고시 확인 전 추정, [ASM-01-03](#가정과-스파인-차이-기록)), 삼일절 2027-03-01(월), 어린이날 2027-05-05(수).

| 스프린트 | 기간 | 작업일 | 용량 / 약속(점) | 단계 | 휴일 주 의식 이동 | 주요 목표(요지) |
|---|---|---|---|---|---|---|
| S01 | 2026-09-28 ~ 10-02 | 5 | 20 / 18 | P0 | — | G-01, 계약 단일 원본, trainer_app 골격 CI |
| S02 | 10-05 ~ 10-09 | 3 | 12 / 11 | P0 | 계획 화 10-06, 리뷰 목 10-08 | Dart·Swift 코덱 교차 왕복, 금지어 린트 보고 모드 |
| S03 | 10-12 ~ 10-16 | 5 | 보정값 / ×0.9 | P0 | 월 계획에서 S01~S02 속도 보정 | 규칙 v2 초안, Functions 공통 구조, AppShell |
| S04 | 10-19 ~ 10-23 | 5 | 20 / 18 | P0 | — | R·S 규칙 테스트, claim 로그인, 출시 앱 문구 정리 |
| S05 | 10-26 ~ 10-30 | 5 | 20 / 18 | P0 종료 | 금 단계 종료 검토(DF-926) | syncRecordAccessKeys, 담당 회원 로드, 차단 모드 |
| S06 | 11-02 ~ 11-06 | 5 | 20 / 18 | P1a | — | LocalStore·DesignSystem·FirebaseData, AD-03 |
| S07 | 11-09 ~ 11-13 | 5 | 20 / 18 | P1a | — | SyncEngine, 에뮬레이터 통합 CI, recordConsent |
| S08 | 11-16 ~ 11-20 | 5 | 20 / 18 | P1a | — | TR-14 현장 동의, TR-04 Live, 운영 배포 |
| S09 | 11-23 ~ 11-27 | 5 | 20 / 18 | P1a | — | MIG-03 적용, P1a 플래그 개방(게이트 충족 시) |
| S10 | 11-30 ~ 12-04 | 5 | 20 / 18 | P1a | — | Review·확정·addendum |
| S11 | 12-07 ~ 12-11 | 5 | 20 / 18 | P1a | — | TR-01, TR-11, TR-03, TestFlight 0.2 |
| S12 | 12-14 ~ 12-18 | 5 | 20 / 18 | P1a | — | TR-12, 공통 차트, 삭제 연쇄 |
| S13 | 12-21 ~ 12-24 | 4 | 16 / 14 | P1a | 리뷰 목 12-24 | 권리 요청, 파기, P1a 실기기 |
| S14 | 12-28 ~ 12-31 | 4 | 16 / 14(계획 13) | P1a·P1b | 리뷰 목 12-31 | P1a 기능 완성, PostureMath 착수 |
| S15 | 2027-01-04 ~ 01-08 | 5 | 20 / 18 | P1a 종료·P1b | 금 단계 종료 검토(DF-927) | 촬영 스테이션, Vision 어댑터 |
| S16 | 01-11 ~ 01-15 | 5 | 20 / 18 | P1b | — | EXIF·얼굴 가림, TR-08 |
| S17 | 01-18 ~ 01-22 | 5 | 20 / 18 | P1b | — | 확정·기준선, TR-09·TR-10 |
| S18 | 01-25 ~ 01-29 | 5 | 20 / 18 | P1b 종료 | 금 단계 종료 검토(DF-928) | 추이, O 자동 불러오기 |
| S19-S20 | 02-01 ~ 02-12 | 8(설 추정) | 32 / 28(계획 24, 잠정) | P2 | 설 주 이동 규칙 적용 | 초대·승격, soapNote 공유 |
| S21-S22 | 02-15 ~ 02-26 | 10 | 계획 30(잠정) | P2 | — | MB-01~06, bodyReport |
| S23-S24 | 03-02 ~ 03-12 | 9 | 계획 28(잠정) | P2 | S23 계획 화 03-02 | BodyPathCore, memberShare 개방 |
| S25-S26 | 03-15 ~ 03-26 | 10 | 계획 34(잠정) | P2 종료 | 금 단계 종료 검토(DF-936) | TR-13 LiDAR 베타, P2 E2E |
| S27-S29 | 03-29 ~ 04-16 | 15 | 계획 23(잠정) | P3 | — | 판정 엔진, AD-04, G-08 |
| S30-S32 | 04-19 ~ 05-07 | 14 | 계획 16(잠정) | P3 종료 | S32 수요일 점검 목 05-06 | 역할 분리, Runner 트레이너 제거, 1.0 |

마일스톤 목표일(게이트 우선, 잠정): P0 2026-10-30(S05), P1a 2027-01-08(S15, 기능 완성 S14 12-31), P1b 2027-01-29(S18), P2 2027-03-26(S26), P3 2027-05-07(S32). 스프린트별 약속 항목은 [V1-03](03_RELEASE_AND_SPRINT_PLAN.md)과 `docs/v1/sprints/`에 둔다.

---

## 백로그 구조와 다듬기

### 계층과 정본

| 층 | 키 | 정본 위치 | GitHub 표현 |
|---|---|---|---|
| 에픽 | EP-00~EP-23 | [V1-02](02_PRODUCT_BACKLOG.md) | 이슈(type/epic) + 본문 체크리스트로 하위 스토리 연결 |
| 스토리·스파이크·버그·잡무 | DF-NNN | `docs/v1/backlog/{P0,P1a,P1b,P2_P3,V2}.md` ↔ `tool/backlog/issues.json` | 이슈 `[DF-NNN] 동사형 제목` |
| 소유자 행동·게이트 증빙 | DF-900~999 | [OWNER_ACTIONS_AND_GATES](backlog/OWNER_ACTIONS_AND_GATES.md) ↔ `tool/backlog/issues.json` | 이슈(owner-action, gate/G-NN) |
| 하위 작업 | — | 스토리 이슈 본문의 체크리스트 | 필요하면 type/task 이슈(GH-04) |

- 키 대역: P0 DF-001~099, P1a DF-100~199, P1b DF-200~299, P2 DF-300~379, P3 DF-380~449, V2 DF-500~549, 소유자 행동 DF-900~999. DF-019는 쓰지 않는다.
- 스토리 전용 추가 수용 기준은 `AC-DF-NNN.k`다. PRD AC를 대체하지 않고 보탠다.
- **백로그 변경은 문서와 JSON을 같은 PR에서** 고친다. `node tool/backlog/validate_backlog.mjs`가 DF 키 유일성, 라벨·마일스톤 존재, trace ID의 PRD 존재, 의존 순환을 검사한다(docs-and-backlog CI).
- **이슈 생성은 소유자만** `tool/backlog/create_backlog.sh`로 한다. 기본은 `--dry-run`(gh 호출 없음)이며 기존 이슈 제목의 `[DF-NNN]` 키로 중복을 막는다([TL-01](../../tool/backlog/README.md)). 구현은 `create_github_issues.sh`이고 `create_backlog.sh`는 같은 스크립트를 부르는 호환 진입점이다. 에이전트는 이슈를 만들지 않는다.

### 우선순위 원칙

1. 게이트 선행 작업(G-01~G-03 코드 측, 게이트 증빙에 필요한 스토리)이 먼저다.
2. 규제·개인정보(regulatory, privacy-impact) 스토리가 같은 단계의 기능 스토리보다 먼저다. 예: DF-028·029·010은 P0 안에 끝낸다(PRD §3.4-8).
3. 그다음 MoSCoW(`prio/must` → `should` → `could`). `prio/wont`와 V2는 스프린트에 넣지 않는다.
4. 같은 우선순위에서는 의존 그래프의 앞쪽(다른 스토리를 막는 것)을 먼저 한다.

### 다듬기(목요일 60분)

범위는 **다음 2개 스프린트**의 후보(약 10~12개)다. 스토리 하나에 평균 5분이다. 지시서를 처음부터 쓰지 않고 카드와 생성기로 만들기 때문에 이 시간 안에 들어간다([작업 지시서 규칙](#작업-지시서-규칙)).

1. 후보 스토리마다 [DoR](#준비-완료-정의dor)을 점검하고 `status/ready` 라벨을 붙인다. 못 붙이면 사유를 적고 `status/needs-decision` 또는 `status/blocked`를 붙인다.
2. `size/XL`(8점)은 반드시 나눈다. 5점 스토리도 지시서 작성이 어렵다면 나눈다.
3. 에이전트가 맡을 스토리는 카드의 '에이전트 브리프' 절을 채운 뒤 `node tool/backlog/brief.mjs DF-NNN`으로 작업 지시서([V1-T08](templates/AGENT_BRIEF.md))를 생성해 이슈 코멘트로 붙인다.
4. PRD가 모호한 곳을 발견하면 스토리를 막지 말고 `AS-DEV-NN`(가정) 또는 `Q-DEV-NN`(질문)으로 기록하고 관련 PRD Q-/AS-를 참조한다. 목록은 [V1-00](00_README.md)에 있다. PRD로 올릴 때는 PRD §13.4에 따라 AS-34, Q-25부터 번호를 새로 받는다.
5. 새 요구가 PRD 범위 밖이면 백로그에 넣지 않는다. PRD 개정 제안으로 돌리거나 V2 자리 표시(DF-500~549)에 재검토 조건과 함께 적는다.

---

## 준비 완료 정의(DoR)

스토리는 아래를 **모두** 만족해야 스프린트 계획에 넣을 수 있다. 이슈 폼(GH-03)의 체크박스와 같다.

| # | 항목 | 확인 방법 |
|---|---|---|
| R1 | PRD 추적 ID가 하나 이상 있다(F-/AC-/NFR-/TR-/MB-/AD-/R-/S-/MIG-/G-) | validate_backlog.mjs가 PRD 존재 확인 |
| R2 | 수용 기준이 검증 가능하다. PRD AC를 인용하고, 모자라면 AC-DF-NNN.k로 보탠다. 각 기준에 테스트 종류(단위, 규칙 에뮬레이터, e2e, UI, 실기기, 수동)를 붙였다 | 스토리 본문 |
| R3 | 선행 스토리가 Done이거나 같은 스프린트 앞순서다. 외부 게이트는 코딩 선행이 아니다(단 플래그 개방·실데이터·배포 스토리는 예외) | deps 필드 |
| R4 | 크기가 5점 이하다 | size 라벨, Points 필드 |
| R5 | 단계·플래그·area·prio 라벨이 있다 | 이슈 라벨 |
| R6 | 수정 경로가 정해졌고, 같은 스프린트의 다른 에이전트 스토리와 겹치지 않는다(TrainerCore·TrainerKit 타깃 단위) | 작업 지시서 '수정 허용 경로' |
| R7 | 스키마·규칙·계약·문구 영향 여부를 표시했다(schema-change, rules-change, regulatory, privacy-impact 라벨) | 라벨 |
| R8 | 합성 데이터 계획이 있다(필요한 가상 회원·픽스처) | 스토리 본문 '테스트 데이터' |
| R9 | 에이전트 배정 스토리는 (a) 카드에 '에이전트 브리프' 절(V1-T08의 1·3·4·5·7절 요지)이 있고 (b) `tool/backlog/brief.mjs DF-NNN`이 생성한 지시서가 이슈 코멘트로 붙어 있다. 생성기가 0·2·6·8·9·10·11절을 카드와 이슈 JSON에서 채우므로 소유자가 손으로 쓰는 것은 (a)뿐이다 | 카드, 이슈 코멘트 |
| R10 | 실기기·서명·콘솔이 필요한 부분이 분리됐다(needs-device-test 또는 owner-action 하위 항목) | 라벨 |

스파이크는 R2 대신 '질문·성공 기준·타임박스'가 있으면 된다([V1-T02](templates/SPIKE_REPORT.md)). 소유자 행동은 R2 대신 '증빙 목록'이 있으면 된다([V1-T07](templates/GATE_EVIDENCE.md)).

---

## 완료 정의(DoD)

스토리는 **공통 DoD + 해당 영역 DoD**를 모두 만족해야 Done이다. PR 템플릿([GH-08](../../.github/pull_request_template.md))이 같은 체크리스트를 쓴다. 테스트 이름에는 수용 기준 ID를 넣는다(예: JS `test('AC-SOAP-04.1 finalized 문서 수정 거부', ...)`, Swift `func test_AC_SOAP_04_1_finalizedIsImmutable()`, Dart `test('AC-SOAP-06.1 v2 왕복 무손실', ...)`). 추적성 매트릭스를 grep으로 만들 수 있게 하기 위해서다.

### 공통 DoD

| # | 항목 |
|---|---|
| D1 | 모든 수용 기준(PRD AC + AC-DF)이 충족됐고, PR 본문 '수용 기준별 증빙' 표에 테스트 이름·CI 링크·스크린샷·수동 기록 중 하나가 기준마다 연결돼 있다 |
| D2 | **PR을 만든 시점에** 아래 [필수 체크 활성화 표](#필수-체크-활성화-표)에서 활성인 체크가 모두 초록이다. 아직 만들어지지 않은 체크는 요구하지 않는다. 보고 모드 체크는 항상 통과하므로 위반 요약을 PR 본문에 붙인다. PR 템플릿에 그 시점에 활성인 체크를 적는다 |
| D3 | 커밋 footer에 `Refs: DF-NNN`과 `Trace: <PRD ID 목록>`이 있고, 스쿼시 제목이 `<type>(<scope>): <요약> (DF-NNN)`이다 |
| D4 | 같은 PR 동시 갱신 규칙을 지켰다: 스키마 → `docs/firestore_schema.md`·[V1-05](05_DATA_MODEL_AND_RULES.md)·Swift·Dart 매핑·픽스처·규칙 테스트 / 규칙 → 규칙 테스트 / 어휘 → `contracts/`와 생성물 / 화면 → [V1-07](07_TRAINER_APP_SPEC.md) 또는 [V1-08](08_MEMBER_APP_AND_ADMIN_SPEC.md) |
| D5 | 생성물이 최신이다: `node tool/contracts/generate.mjs --check`, 트레이너 앱은 xcodegen 재생성 diff 0 |
| D6 | 금지어 린트 통과(`node tool/lint/prohibited-terms.mjs`). 사용자 노출 문자열은 카탈로그(Swift `Localizable.xcstrings`, Flutter 기존 문자열 위치)에 있다. 회원 노출 문자열은 회원 규칙 세트(PRD 부록 C.3)도 통과 |
| D7 | 개인정보: 실데이터 0, 비밀 0, `output/`·`tmp/` 내용 0. 로그·분석 이벤트에 NFR-10 금지 항목 0. 새 분석 이벤트·속성은 `contracts/analytics-events.v1.json`에 먼저 등록 |
| D8 | 미완성 기능은 해당 플래그가 false일 때 진입점이 없다(AC-IA-02). 플래그 기본값은 false |
| D9 | 저장이 있는 기능은 syncState를 PRD §6.0.3 문구대로만 표시하고, 오류 주입 테스트에서 `synced`가 거짓으로 뜨지 않는다(C-05, NFR-06). '저장됨' 단독 문구 0 |
| D10 | UI 변경은 접근성 식별자·VoiceOver 라벨(A-03)·44pt 탭 대상·회색조 구분(AC-A11Y-03)을 지켰고, PRD §8.4 상태 매트릭스의 O 칸 상태를 모두 구현했다 |
| D11 | 쿼리·권한 오류를 빈 목록으로 삼키지 않고 '불러오기 실패'와 재시도를 보인다(PRD §8.4, §9.6) |
| D12 | 소유자가 검토하고 스쿼시 병합했다. 이슈는 Done, Projects 필드(Status, Points, Sprint)가 최신이다 |

### 필수 체크 활성화 표

체크는 그것을 만드는 스토리가 병합된 뒤 소유자가 브랜치 보호의 필수 체크에 등록한 날부터 요구한다. 날짜는 스프린트 계획의 목표일이고, 실제 등록일은 소유자가 일일 기록과 이 표의 '실제' 열에 적는다(문서 변경 규칙의 오탈자급 갱신, 버전 유지).

| 체크(job) | 만드는 스토리 | 필수 시작(목표) | 실제 | 모드 | 실행 조건 |
|---|---|---|---|---|---|
| `flutter`, `functions-and-rules`, `admin-web`, `ios-no-codesign` | 기존(dfet:.github/workflows/ci.yml:13-81). 필수 등록은 DF-901 | 2026-09-29(화, S01, DF-901 병합·브랜치 보호) | | 차단 | 항상 |
| `contracts` | DF-004 | 2026-10-02(금, S01) | | 차단 | 항상 |
| `trainer-app` | DF-008 | 2026-10-02(금, S01) | | 차단 | 경로 조건부(건너뜀 = 통과) |
| `docs-and-backlog` | DF-001(헤더), DF-002(백로그 검증) | 2026-10-02(금, S01) | | 차단 | 경로 조건부 |
| `copy-lint` | DF-010 | 2026-10-08(목, S02) | | **보고**(exit 0, 위반 요약 출력) | 항상 |
| `copy-lint` 차단 전환 | DF-040 | 2026-10-30(금, S05, P0 종료 게이트) | | 차단 | 항상 |
| `static-guards` | DF-011 | 2026-10-16(금, S03) | | 차단(기준선 고정, ASM-01-15) | 항상 |
| `migrations` | DF-031 | 2026-10-30(금, S05) | | 차단 | 경로 조건부 |
| `trainer-app-emulator-it` | DF-107 | 2026-11-13(금, S07) | | 차단 | 경로 조건부 + 야간 |

- 체크를 만드는 스토리 자신은 자기 체크가 PR에서 초록이어야 한다(등록 전이라도).
- 목표일보다 늦게 병합되면 그 체크는 병합일부터 요구한다. 계획은 바꾸지 않고 리뷰에 기록한다.
- job 이름과 러너·트리거의 정본은 [V1-10](10_TEST_PLAN.md) CI 절이다.

### 영역별 DoD

**트레이너 iOS (`trainer_app/`)**

- `xcodegen generate --spec trainer_app/project.yml` 후 `git diff --exit-code -- trainer_app/DFETTrainer.xcodeproj` 통과(ADR-001).
- 순수 타깃 `swift test --package-path trainer_app/Packages/TrainerCore` 통과(TrainerContracts, TrainerDomain, PostureMath, SyncEngine, TrainerAnalytics. V1-04 §6.2).
- 시뮬레이터 `xcodebuild test -project trainer_app/DFETTrainer.xcodeproj -scheme DFETTrainer -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'` 통과([ASM-01-07](#가정과-스파인-차이-기록)).
- `import Firebase*`는 `FirebaseData` 타깃과 App 타깃에만 있다(NFR-03, static-guards). Data·Sync에는 강제 언래핑·`print(` 0, 로그는 `os.Logger` + `privacy: .private`.
- 새 화면 파일 첫 줄에 `/// TR-NN` 문서 주석, 접근성 식별자는 `trNN.<element>` 형식(예: `tr04.recordComplete`).
- 사용자 문자열은 `trainer_app/App/Localizable.xcstrings`에만 둔다.
- 상태 매트릭스 스냅샷(swift-snapshot-testing, 테스트 타깃 전용)이 추가·갱신됐고 diff를 소유자가 봤다.
- 1/3 Split View에서 잘림 없음(NFR-12) 스크린샷 1장을 PR에 첨부했다(레이아웃 변경 시).
- `needs-device-test` 라벨이 있으면 실기기 기록([V1-T09](templates/DEVICE_TEST_RECORD.md))을 첨부한 뒤에만 병합한다.
- 이식 코드는 지시서의 원본 줄 범위와 반례 목록(V1-04, DF-039)을 따랐고 반례 패턴(로컬 UUID, `native_` ID, base64 필기, `isSharedWithMember: true`, tapback.co) 0.

**Flutter 회원 앱 (`lib/`, `test/`)**

- `flutter analyze` 0건, `flutter test` 통과.
- 골든 변경 시 `flutter test --update-goldens`로 갱신하고 `test/goldens/` 이미지 diff를 소유자가 봤다.
- `ios-no-codesign`(iOS 15.5) 통과, Runner 의존성에 TrainerCore·TrainerKit·BodyPathCore 없음(NFR-01).
- 회원 앱은 원 기록 컬렉션(soap_notes, postureAssessments 등)을 직접 조회하지 않는다(AC-VIZ-06.1, static-guards).
- 4탭 구조 유지(PRD §8.2), 새 문자열은 회원 규칙 세트 통과, 회원 문장은 PRD 부록 B.8만 사용.
- `textScaler` 200%와 `meetsGuideline` 점검(A-01, AC-A11Y-01).

**Functions (`functions/`)**

- `npm --prefix functions run lint`, `npm --prefix functions test`(단위), `firebase emulators:exec --only functions,firestore,storage --project dfet-e2e "npm --prefix functions run test:e2e"` 통과([ASM-01-08](#가정과-스파인-차이-기록)).
- 신규 함수는 `asia-northeast3`, Node 22, v2 onCall이고 `functions/src/<domain>/<functionName>.js`에 handler와 순수 core를 분리해 export한다. 기존 callable의 이름·리전은 바꾸지 않는다(NFR-16, ADR-017).
- 오류 코드는 invalid-argument, permission-denied, failed-precondition, not-found, already-exists, resource-exhausted 중 하나이고 성공 응답은 `{ok: true, ...}`다.
- 쓰기는 트랜잭션·배치로 하고 감사 기록(`auditLogs`)을 함께 남긴다. action은 `contracts/audit-actions.v1.json`에 있는 것만, metadata에 건강 수치·이름 없음.
- 멱등 테스트(같은 입력 2회 → 결과 동일, 중복 문서 0)가 있다.
- 새 npm 의존성 없음(있으면 ADR 선행).

**보안 규칙·Storage·인덱스 (`firestore.rules`, `storage.rules`, `firestore.indexes.json`)**

- `firebase emulators:exec --only firestore,storage --project dfet-rules-test "npm --prefix functions run test:rules"` 100% 통과(M-G4). 근거: dfet:.github/workflows/ci.yml:53.
- 테스트 제목에 PRD 규칙 테스트 ID(R-NN, S-NN)가 들어 있고, 변경한 규칙마다 허용 1건 + 거부 1건 이상이 있다.
- 새 쿼리를 추가하면 규칙이 그 쿼리를 증명할 수 있는지(`trainerId == request.auth.uid` 포함) 에뮬레이터 쿼리 테스트로 확인했고, 필요한 복합 인덱스를 같은 PR에 넣었다(PRD §9.6).
- 소유자가 diff를 **직접 한 줄씩** 읽었다(rules-change 라벨). 운영 배포는 PR에서 하지 않는다(DF-931, 소유자 수동).

**관리자 웹 (`admin_web/`)**

- `npm --prefix admin_web run lint`, `run typecheck`, `test`, `run build` 통과.
- zod 스키마는 `admin_web/lib/generated/contracts.ts`에서 가져온다(손으로 enum 작성 금지).
- 원 기록 열람 경로는 `recordHealthRead`를 호출한다(F-PRIV-05.1). 관리자 판정은 custom claim `admin == true`(ADR-018). Admin SDK는 서버 라우트에서만 쓴다.

**계약 (`contracts/`, `schemas/`, `tool/contracts/`)**

- `node tool/contracts/generate.mjs --check` 통과, ajv 메타 스키마 검증 통과, `jq empty schemas/*.json` 통과.
- 픽스처는 합성 데이터만 쓴다(가상 회원 이름 `가상회원A` 등, 실제 이메일·uid 형식 값 금지).
- 파괴적 변경은 `.v2.json` 새 파일로 만들고 `.v1`은 유지한다. metricCode를 추가하면 PRD 부록 A가 먼저 바뀌어 있어야 한다(부록 A 운영 규칙).

**이관 스크립트 (`functions/scripts/migrations/`)**

- 기본 동작이 dry-run이고, `--apply`는 소유자만 실행한다. 보고서는 수량만 담는다.
- 에뮬레이터에서 레거시 픽스처 → 기대 v2 비교, 2회 실행 동일(멱등), 적용 → 롤백 → 재적용 리허설 통과(`migrations` CI).
- 실행 기록 양식([V1-T10](templates/MIGRATION_RUN_RECORD.md))을 PR에 링크했다.

**문서 (`docs/v1/**`, `tool/backlog/**`)**

- 헤더 표준 통과(`node tool/lint/doc-headers.mjs`), 링크 확인, `node tool/backlog/validate_backlog.mjs` 통과.
- 코드 근거는 파일을 직접 열어 확인한 `dfet:경로:줄` 또는 `bodypath:경로:줄`로 적었다.
- `docs/PRD_V1.md`를 수정하지 않았다(개정은 소유자가 별도 PR로).

**소유자 행동 (DF-9xx)**

- 증빙 목록([V1-T07](templates/GATE_EVIDENCE.md))을 채웠고, 저장소에는 **증빙의 존재·날짜·파일명만** 적었다. 법률 의견서, 식약처 회신, IRB 승인서, 계정 화면 원본은 저장소에 올리지 않는다.
- Projects의 Gate 필드와 [OWNER_ACTIONS_AND_GATES](backlog/OWNER_ACTIONS_AND_GATES.md) 상태를 갱신했다.

---

## 추정과 속도

### 점수 척도

점수는 **소유자의 검토·통합·실기기 확인 노력**이다. 에이전트의 코딩 시간이 아니다. 1점은 에이전트 PR 하나를 소유자가 30분 안에 검토·통합하는 규모다([ASM-01-02](#가정과-스파인-차이-기록)).

| 점수 | size 라벨 | 기준 | 예(백로그) |
|---|---|---|---|
| 0 | (없음) | 소유자 행동 중 반나절 미만(아래 참고) | DF-904 ASC 이력 확인 |
| 1 | size/XS | PR 1개, 검토 30분, 규칙·개인정보 경로 아님. 또는 소유자 행동 반나절 이상 | DF-011 static-guards, DF-901 MIG-01 |
| 2 | size/S | PR 1개, 검토 1시간, 테스트 한 종류 | DF-005 SOAP 픽스처 |
| 3 | size/M | PR 1~2개, 교차 테스트 또는 에뮬레이터 포함 | DF-004 생성기, DF-022 규칙 테스트 |
| 5 | size/L | 여러 타깃, 규칙·개인정보 diff 정독, 실기기 또는 시뮬레이터 UI 확인 | DF-008 골격, DF-116 TR-04 Live |
| 8 | size/XL | **계획 금지.** 다듬기에서 반드시 나눈다 | — |

- rules-change·privacy-impact 라벨 스토리는 같은 코드량이라도 한 단계 높게 잡는다(소유자가 diff를 직접 읽어야 하기 때문).
- 소유자 행동(owner-action)은 0~1점(백로그 스파인 값)이며 약속과 속도에 포함한다([ASM-01-16](#가정과-스파인-차이-기록)). 실제 부담은 예상 시간으로 카드와 계획의 "소유자 시간" 열에 함께 적는다. 예: DF-901은 1점이지만 약 12시간(SPRINT_01 ASM-S01-01)이다.
- V2 자리 표시(DF-500~505)는 추정하지 않는다(0점, 'V2-backlog').

### 용량과 속도

- 초기 용량(AS-DEV-09): 5작업일 스프린트당 **20점**, 약속은 **18점**. 남는 2점(10%)은 결함·리뷰 반려·게이트 대응 버퍼다. 약속 18점은 owner-action 점수를 포함한 값이다(예: S01 18 = 개발 15 + 소유자 3).
- 휴일 주: 용량 = 20 × 작업일/5, 약속 = 용량의 90%. S02 12/11, S13·S14 16/14.
- 보정: S03 계획(10-12 월)에서 S01~S02 실적으로 계산한다. `작업일당 완료점수 = 완료 점수 합 / 8작업일`(이월·미병합 PR은 0점). S03 용량 = `round(작업일당 완료점수 × 5)`, 단 한 번에 ±25%(15~25점)까지만 바꾼다.
- S04부터는 직전 3개 스프린트 이동평균을 쓴다(작업일 수로 정규화).
- **완료 점수에는 스토리·스파이크·버그·잡무·owner-action 점수를 모두 넣는다**([ASM-01-16](#가정과-스파인-차이-기록)). 소유자 행동은 [V1-T05](templates/SPRINT_REVIEW.md)의 '소유자 시간' 표에 예상·실제 시간으로 따로 적는다. S03 보정 때 'S01~S02 주당 소유자 행동 실제 시간'도 함께 계산해, 이후 계획에서 소유자 행동 예상 시간이 그 값을 크게 넘는 주는 개발 약속을 줄일지 계획 회의에서 판단한다.
- **감속 규칙**: 속도가 2스프린트 연속 16점 미만이면 다음 계획에서 `could`(DF-224, DF-137 일부, DF-327)를 먼저 이월하고, 그래도 부족하면 마일스톤을 1주 밀어 단계 종료 검토(PRD §12.7)에 기록한다.
- 회고 기록 항목: 완료 점수, 이월 점수, 에이전트별 PR 수와 반려율(변경 요청 횟수 / PR 수), 버그 유입 점수.

---

## WIP 제한

| 대상 | 한도 | 이유·규칙 |
|---|---|---|
| 동시 에이전트 브랜치 | **3개 이하** | 소유자 검토 병목. TrainerCore·TrainerKit 타깃·functions 도메인 폴더가 겹치지 않게 배정한다 |
| Status = In review | **3개 이하** | 3개가 차면 새 에이전트 작업을 배정하지 않고 검토부터 한다('검토 먼저' 규칙) |
| Status = In progress(소유자 직접) | 1개 | 소유자 구현은 에이전트가 못 하는 일(서명, 실기기, 콘솔)에 한정 |
| rules-change·privacy-impact PR | 동시 1개 | 규칙 diff 정독은 한 번에 하나만 한다 |
| 브랜치 수명 | 3작업일 | 넘으면 스토리를 나누거나 PR을 닫고 다시 지시한다. 장기 기능 브랜치 금지(ADR-014) |
| 동시 외부 게이트 접수 | 제한 없음 | 외부 대기 시간은 소유자 노력이 아니다. 다만 수요일 점검에서 모두 추적한다 |

---

## 브랜치·커밋·PR 규칙

결정 배경은 [ADR-014](adr/ADR-014-branching-release.md)다.

### 브랜치

- `main`이 트렁크다. 보호 규칙: PR 필수, 필수 체크 통과, force-push 금지, 선형 이력, 필수 승인 수 0([ASM-01-05](#가정과-스파인-차이-기록)).
- 작업 브랜치: `<type>/DF-NNN-<kebab-slug>`. type은 `feat|fix|docs|chore|refactor|test|mig|spike`. 예: `feat/DF-116-tr04-live`.
- 에이전트 브랜치: `claude/DF-NNN-<slug>`, `codex/DF-NNN-<slug>`(BodyPath의 `codex/…` 관례와 같다). 예: `codex/DF-003-metric-catalog`.
- 브랜치 하나 = 스토리 하나(또는 하위 작업 하나).
- 보관 브랜치 `archive/trainer-ui-2026-09`(MIG-01 B분류)는 병합하지 않는다. tip 해시는 이식 기준선으로 [V1-00](00_README.md)과 PRD 변경 이력에 기록한다.
- `feature/integrated-care-2026`은 DF-901에서 A분류만 `main`에 병합한 뒤 삭제한다. 이후 v1 작업은 모두 `main`에서 분기한다(AS-DEV-11). 기존 CI의 `push: branches: [main, "feature/**"]`(dfet:.github/workflows/ci.yml:4-6)는 그대로 두어도 된다.
- 태그(소유자만): `trainer-vX.Y.Z`, `member-vX.Y.Z`, `rules-YYYYMMDD-N`, `functions-YYYYMMDD-N`, `mig03-apply-YYYYMMDD`, `archive/trainer_ios-final`, BodyPath는 `bodypathcore-vX.Y.Z`.

### 커밋

기존 이력의 Conventional Commits 관례(`feat:`/`fix:`/`docs:`/`chore:`, 예: `d841412 feat: unify clinical evidence experience`)를 잇는다.

```
<type>(<scope>): <요약, 72자 이하>

<본문: 무엇을 왜. 선택>

Refs: DF-003
Trace: F-SOAP-06.1, AC-SOAP-02.2
Co-Authored-By: <에이전트 트레일러>
```

- scope(선택): `trainer|member|admin|functions|rules|storage|contracts|bodypath|ci|docs|mig`.
- 에이전트 커밋은 도구가 붙이는 Co-Authored-By 트레일러를 유지한다.
- 스쿼시 제목: `<type>(<scope>): <요약> (DF-NNN)`. 예: `feat(contracts): add metric catalog v1 (DF-003)`.

### PR

- PR 하나 = 스토리 하나. 생성물을 뺀 변경은 400줄 이하 권장.
- 템플릿([GH-08](../../.github/pull_request_template.md))을 모두 채운다. 에이전트는 draft로 연다. 소유자가 검토를 시작할 때 Ready로 바꾼다.
- 본문 첫 줄에 `Closes #<이슈 번호>`를 넣어 병합 시 이슈가 닫히게 한다.
- 필수 체크: [필수 체크 활성화 표](#필수-체크-활성화-표)에서 PR 생성 시점에 활성인 것. 모두 활성화된 뒤(S07 이후)의 목록은 `flutter`, `functions-and-rules`, `admin-web`, `ios-no-codesign`, `trainer-app`, `contracts`, `copy-lint`, `static-guards`, 경로 조건부 `migrations`, `docs-and-backlog`, `trainer-app-emulator-it`이다.
- **소유자 정독 경로**(라벨 rules-change, schema-change, regulatory, privacy-impact): `firestore.rules`, `storage.rules`, `functions/src/{access,consent,privacy,summaries}/**`, `functions/scripts/migrations/**`, `contracts/prohibited-terms.v1.json`, 회원 노출 문구. 이 경로는 CODEOWNERS(GH-09)로 표시한다.
- 병합은 소유자만, 스쿼시로 한다. 자동 병합 금지.
- PR에 넣지 않는 것: 실데이터, 비밀, `output/`·`tmp/` 내용, 공개 URL, 배포 명령 실행 결과(배포 로그는 소유자 기록에만).

---

## AI 에이전트 작업 흐름

### 흐름

```
[1 다듬기]  스토리 DoR 충족 → 작업 지시서(V1-T08) 작성 → 이슈 코멘트로 부착 → agent/claude|codex 라벨
     │
[2 배정]    월 계획에서 경로 충돌 없는 스토리만 동시에 배정(최대 3)
     │
[3 실행]    에이전트: main에서 브랜치 → 컨텍스트 팩 읽기 → 구현 → 지시서의 테스트 명령 실행
     │       → 자가 DoD 점검 → draft PR(템플릿 작성) → 이슈에 완료 보고
     │
[4 자동 검증] CI 필수 체크 초록. 실패 시 에이전트가 같은 브랜치에서 수정(최대 2회)
     │
[5 소유자 검토] 위험 라벨별 정독 → 로컬 또는 시뮬레이터 확인 → (needs-device-test) 실기기 기록
     │        ├─ 변경 요청 → 지시서에 '검토 피드백' 절 추가 → 같은 에이전트 재실행(3으로)
     │        └─ 2회 반려 → 스토리 분할 또는 소유자 직접 처리, 회고에 원인 기록
     │
[6 병합]    소유자 스쿼시 병합 → 이슈 Done → Projects 갱신 → 일일 기록
```

### 작업 지시서 규칙

- 지시서([V1-T08](templates/AGENT_BRIEF.md))는 **그 자체로 완결된 프롬프트**다. 에이전트가 질문 없이 구현할 수 있도록 다음을 반드시 담는다: 목표, 컨텍스트 팩(읽을 문서의 절 단위 링크), 수정 허용 경로와 금지 경로, 인터페이스 시그니처, 수용 기준 원문, 실행할 테스트 명령, 금지 행동, 완료 보고 형식.
- **지시서 = 카드 + 카드의 '에이전트 브리프' 절 + 생성기 출력**이다. 소유자는 지시서를 처음부터 쓰지 않는다.
  - 소유자가 쓰는 것: 백로그 카드([V1-T01](templates/STORY.md))와 그 안의 '에이전트 브리프' 절. 여기에 V1-T08의 1절(목표), 3절(컨텍스트 팩), 4절(수정 허용·금지 경로, 같은 스프린트의 다른 작업), 5절(인터페이스 계약, 카드의 설계 절 링크로 대신 가능), 7절(구현 메모) 요지를 적는다.
  - 생성기가 채우는 것: `node tool/backlog/brief.mjs DF-NNN [--sprint SNN] > brief.md`가 카드(`docs/v1/backlog/*.md`)와 이슈 JSON(`tool/backlog/issues.json`)을 읽어 V1-T08 전체를 만든다. 0절(절대 규칙, 고정문), 2절(추적: epic·phase·flag·trace), 6절(수용 기준: 카드의 PRD AC 원문과 AC-DF), 8절(검증 명령: area별 기본 명령 + 카드의 테스트 명령), 9절(브랜치 `<agent>/DF-NNN-<slug>`, 커밋 footer), 10·11절(고정문)을 채운다. `--sprint`를 주면 같은 스프린트의 다른 에이전트 스토리와 그 경로를 4절에 덧붙인다.
  - 생성기는 백로그 도구의 하나(TL-13 후보)이며 DF-002 범위에서 만든다([ASM-01-17](#가정과-스파인-차이-기록)). 생성기가 생기기 전(S01)에는 소유자가 같은 규칙으로 손으로 조립한다.
- 컨텍스트 팩은 영역별 필독 목록([V1-13](13_DEV_ENVIRONMENT_AND_AGENT_PLAYBOOK.md))에서 고르고, PRD는 절 번호로 좁혀 준다(3,834줄 전체를 읽히지 않는다).
- 이식 스토리는 원본 줄 범위와 반례 목록을 지시서에 적는다(원본: 보관 브랜치 tip 기준, DF-039).
- PRD가 모호하면 에이전트는 추측하지 말고 PR 본문 '가정' 절에 `AS-DEV-후보`로 적고 가장 보수적인 해석(기능 숨김, 저장 안 함, 판정 안 함)을 택한다.

### 에이전트 배정 규칙

| 작업 영역 | 우선 배정 | 이유 |
|---|---|---|
| `trainer_app/` UI·시뮬레이터 테스트 | Claude Code(소유자 Mac, 로컬) | xcodebuild·시뮬레이터가 필요하다 |
| `trainer_app/Packages/TrainerCore` 순수 타깃 | Claude 또는 Codex | `swift test`(macOS). Codex 클라우드에서 macOS 검증이 불가하면 CI 결과를 증빙으로 쓴다([ASM-01-09](#가정과-스파인-차이-기록)) |
| `functions/`, 규칙 테스트, `contracts/`, `tool/` | Claude 또는 Codex | Node·에뮬레이터로 검증 가능 |
| `lib/`(Flutter) | Claude 또는 Codex | flutter test |
| `admin_web/` | Claude 또는 Codex | Node |
| BodyPath 저장소(P2) | Codex(기존 관례) 또는 Claude | `codex/…` 브랜치 관례 |

- 같은 스프린트에서 동시에 도는 에이전트 스토리는 **수정 경로 교집합이 없어야** 한다. TrainerCore·TrainerKit은 타깃 단위, functions는 `src/<domain>` 단위, 규칙은 파일 단위로 본다(`firestore.rules`는 한 번에 한 스토리만).
- 생성물(`*/generated/**`, `DFETTrainer.xcodeproj`)을 건드리는 스토리가 동시에 둘이면 뒤에 병합되는 쪽이 재생성 후 다시 푸시한다.

### 완료 보고 형식(에이전트 → 이슈 코멘트)

```
## 완료 보고 DF-NNN
- 브랜치 / PR: codex/DF-NNN-slug / #PR
- 수용 기준: AC-...: 통과(test 이름) | AC-...: 수동 확인 필요(사유)
- 실행한 명령과 결과: `...` → pass (n tests)
- 수정한 경로: (지시서 허용 경로 안인지 표시)
- 가정(AS-DEV-후보): 없음 | ...
- 남은 위험·후속: ...
- 비밀·실데이터 접근: 없음
```

### 소유자 검토 체크(위험 라벨별)

| 라벨 | 검토 방식 |
|---|---|
| rules-change | 규칙 diff 한 줄씩 정독, 허용·거부 테스트 쌍 확인, 쿼리-규칙 정합 확인 |
| schema-change | 같은 PR 동시 갱신(D4) 확인, 픽스처 왕복 결과 확인 |
| privacy-impact | 로그·분석·감사 metadata에 금지 항목 없음, 삭제 범위표(PRD §9.7) 반영 |
| regulatory | 사용자 노출 문자열 전부 읽기, 부록 C 대체어 적용, 회원 문장 B.8 |
| needs-device-test | 실기기 기록(V1-T09) 확인 후 병합 |
| freeze-exception | [동결 예외 절차](#동결-예외-절차) 충족 확인 |

---

## 게이트와 소유자 행동의 스프린트 편입

### 운영 방식

- 소유자 행동은 DF-900~999 이슈(owner-action, gate/G-NN 라벨)로 만들고, 스프린트 계획의 '소유자 행동·게이트' 표에 **점수(0~1)와 예상 시간**으로 넣는다. 이 점수는 약속과 속도에 포함한다([추정과 속도](#추정과-속도)). 목록과 선후 관계는 [OWNER_ACTIONS_AND_GATES](backlog/OWNER_ACTIONS_AND_GATES.md)에 있다.
- 외부 대기(법률 자문 회신, 식약처 회신, IRB 심의)는 스토리가 아니다. '의뢰·제출'과 '수령·기록'을 각각 소유자 행동으로 잡고, 대기 기간에는 Status를 Blocked가 아니라 In progress로 두되 Gate 필드에 '대기'를 적는다.
- 매주 수요일 15분 점검에서 게이트별 상태(미착수/진행/대기/충족/실패)를 갱신하고, 목표 스프린트를 넘긴 게이트는 대안을 정한다.
- 게이트 증빙은 [V1-T07](templates/GATE_EVIDENCE.md) 형식으로 `docs/v1/evidence/<게이트 ID>.md`(예: `G-01.md`, `G-05a.md`)에 남긴다. 플래그 개방 체크리스트는 `docs/v1/evidence/flags-<키>.md`다([ASM-01-11](#가정과-스파인-차이-기록), [V1-03 ASM-03-11](03_RELEASE_AND_SPRINT_PLAN.md)). 원본 문서는 저장소 밖에 보관하고 파일명·날짜·판정만 적는다.

### 게이트가 막는 것과 막지 않는 것

| 게이트 | 막는 것 | 막지 않는 것(계속 진행) | 목표 시점 |
|---|---|---|---|
| G-01 (DF-901) | 모든 에이전트 PR **병합**(기준선 필요). 기존 파일을 고치는 작업 착수 | 새 경로(저장소에 아직 없는 경로)의 브랜치 푸시·draft PR | S01 2일차(09-29 화) 12:00([ASM-01-18](#가정과-스파인-차이-기록)) |
| G-02 (DF-903·904·905) | 실계정 로그인 증빙, P0 종료 | 에뮬레이터 claim 계정 개발(DF-012) | S01~S02 |
| G-03 (DF-022·035·023·038·906) | P0 종료, 운영 규칙 배포(DF-931) | 규칙 작성·테스트 | S04~S05 |
| G-04 + G-09 (DF-908·909) | 실데이터 투입, soapV2·bodyComposition 개방(DF-925), P1a 진입 | P1a 스토리 전체 합성 데이터 개발 | 수령 목표 S08 |
| G-05a (DF-910·911) | P1a 진입, 플래그 개방 | 개발 | 제출 S05 |
| G-05b (DF-919) | P2 진입, memberShare 개방(DF-934) | P2 스토리 합성 데이터 개발 | S19-S20 |
| G-06 (DF-912·939) | G-08(P3 진입) | P1b 재검사 태깅 개발, P3 판정 엔진 개발(합성 벡터) | 시작 S14~S15, 완료 S25-S26 |
| G-07a (DF-917) | lidarBeta 개방(DF-935) | BodyPathCore 개발 | S25-S26 |
| G-07 (DF-918) | P2 종료의 베타 유지 판단 | — | P2 종료 |
| G-08 (DF-920) | P3의 판정 표시(정책 활성) | evaluateChange 구현·벡터 테스트 | S27-S29 |
| G-10 (DF-921) | P3 진입(스토어·마케팅 문구) | 개발 | S30-S32 |

### 지연 시 기본 대응

- **G-04·G-09가 S09까지 없으면**: DF-925(플래그 개방)를 다음 스프린트로 옮기고 자체 사용 시작일과 P1a 종료 검토(2주 이상 자체 사용)도 함께 민다. 개발 스토리는 그대로 진행한다. 리뷰에서 마일스톤 변경을 기록한다.
- **G-05b가 웰니스가 아니면**: P2 진입 금지, PRD 개정(Q-01). 백로그는 PRD 개정 후 다시 다듬는다.
- **G-06이 미달이면**: '문헌값 유지·회원 배지 없음' 결정 문서(DF-939)로 P3를 진행한다(PRD §12.6).
- **G-07a 미충족이면**: DF-320~323, DF-935를 P3 이후로 옮긴다.
- 우회 결정은 모두 사유와 함께 단계 종료 검토 기록에 남긴다(PRD §12.7).

---

## 버그·스파이크·기술 부채

### 버그

이슈 폼은 [GH-05](../../.github/ISSUE_TEMPLATE/bug.yml), 상세 기록은 [V1-T13](templates/BUG_REPORT.md)이다. 재현은 합성 데이터로만 한다.

| 심각도 | 정의(PRD 근거) | 처리 |
|---|---|---|
| S1 치명 | 데이터 유실, 알리지 않은 저장 실패(M-G3), 비인가 열람·공유, 동의 없는 민감정보 저장(M-G2), 금지어 회원 노출(M-G1), 실데이터·비밀 유출 | 즉시 스프린트 중단 가능. PRD §12.4 롤백 표에 따라 플래그 off·출시 중지 먼저, 수정은 다음. 24시간 안에 원인 기록 |
| S2 중대 | 기능 사용 불가, syncState 오표시, 규칙 테스트 실패, 크래시 | 현재 스프린트 버퍼(2점)로 처리. 넘치면 가장 낮은 우선순위 스토리를 이월 |
| S3 보통 | 우회 가능한 기능 결함, 레이아웃 잘림 | 다음 스프린트 다듬기에서 우선순위 결정 |
| S4 경미 | 표기·정렬 등 | 백로그 |

- 같은 스프린트에서 병합한 스토리의 결함은 새 버그가 아니라 스토리 재개(reopen)로 처리하고 점수를 다시 받지 않는다.
- 버그 수정 PR에는 재현 테스트(실패 → 통과)가 반드시 들어간다.
- 동결 앱(Runner 내장 트레이너, `trainer_ios/`)의 버그는 규제 수정과 크래시 수정만 받는다([동결 예외 절차](#동결-예외-절차)).

### 스파이크

- 질문 하나, 타임박스(1~2점 = 1~2작업일), 성공 기준, 산출물(ADR 또는 AS-DEV)을 정한다. 이슈 폼 [GH-06](../../.github/ISSUE_TEMPLATE/spike.yml), 보고서 [V1-T02](templates/SPIKE_REPORT.md).
- 스파이크 브랜치(`spike/DF-NNN-…`)의 시제품 코드는 병합하지 않는다. 병합하는 것은 보고서, ADR·AS-DEV 갱신, 재사용할 테스트 하네스뿐이다.
- 타임박스가 끝나면 결론이 없어도 끝낸다. '결론 없음'이면 다음 행동(추가 스파이크, 기본값 유지)을 적는다.
- 백로그의 스파이크: DF-026(claim 통일 설계), DF-038(Storage 교차 조회 실환경), DF-039(AppDelegate 이식 지도), DF-200(Vision 2D 확인).

### 기술 부채

- 부채는 type/chore 이슈로 만들고 제목을 `[DF-NNN] 부채: …`로 시작한다. 본문에 발생 원인(스토리 키), 영향, 상환 조건을 적는다([ASM-01-12](#가정과-스파인-차이-기록)).
- 부채 상환은 스프린트 버퍼 2점 안에서 한다. 버퍼를 넘기려면 PO가 스토리로 승격해 우선순위를 받는다.
- 동결 코드(`trainer_ios/`, Runner 내장 트레이너)는 부채 상환 대상이 아니다. 고치지 않고 이식·삭제한다(DF-142, DF-387).
- 에이전트가 PR에서 '범위 밖이지만 고치고 싶은 것'을 발견하면 고치지 말고 완료 보고의 '남은 위험·후속'에 적는다. 소유자가 부채 이슈로 만든다.

---

## 동결 예외 절차

Runner 내장 트레이너(`ios/Runner/AppDelegate.swift`의 트레이너 영역)와 `trainer_ios/`는 DF-930(동결 선언) 이후 동결이다(D2, MIG-09).

1. 허용 사유는 두 가지뿐이다: **규제 수정**(PRD §3.4-3·4·8, MIG-04)과 **크래시 수정**.
2. PR에 `freeze-exception` 라벨과 본문 '동결 예외 사유'(허용 사유, 대상 줄, 대체 동작)를 적는다.
3. 수정은 최소 diff로 한다. 리팩터링·기능 추가·스타일 정리는 금지다.
4. 소유자가 diff를 정독하고 `copy-lint`에서 해당 위반이 0인지 확인한다.
5. 대표 사례: DF-028(diagnosis 자동 채움 dfet:ios/Runner/AppDelegate.swift:3844 제거와 규제 문구 대체어), DF-029(회원 앱 4개 파일 문구).

---

## GitHub Projects 보드

프로젝트 이름: **D-FET Coach v1**(GitHub Projects v2, 저장소 `TEhyeok/DFET_Coach` 소속, AS-DEV-10). 생성은 소유자가 DF-902에서 한다.

### 필드

| 필드 | 종류 | 값 | 채우는 사람·시점 |
|---|---|---|---|
| Status | 단일 선택 | Backlog, Ready, In progress, In review, Done, Blocked | 아래 상태 정의 |
| Sprint | Iteration | 1주, 월요일 시작, 첫 반복 S01 = 2026-09-28. 이름 `S01`~ | 월 계획 |
| Points | 숫자 | 0, 1, 2, 3, 5(8은 금지) | 다듬기 |
| Phase | 단일 선택 | P0, P1a, P1b, P2, P3, V2 | 생성 시(스크립트) |
| Area | 단일 선택 | trainer-app, member-app, admin-web, functions, rules, storage, contracts, bodypath, ci, design, privacy, analytics, docs | 생성 시 |
| Priority | 단일 선택 | must, should, could, wont | 생성 시, 다듬기에서 조정 |
| Agent | 단일 선택 | claude, codex, human | 월 계획 |
| Gate | 단일 선택 | 없음, G-01, G-02, G-03, G-04, G-05a, G-05b, G-06, G-07a, G-07, G-08, G-09, G-10 | owner-action 생성 시 |
| Epic | 텍스트 | EP-00~EP-23 | 생성 시 |

- 라벨과 필드는 같은 값을 가진다(phase/, area/, prio/, agent/, gate/). 필드는 보드 정렬용, 라벨은 검색·CI용이다. 불일치하면 라벨이 이긴다.
- size 라벨은 Points에서 파생한다(1=XS, 2=S, 3=M, 5=L, 8=XL). 0점은 size 라벨이 없다.

### 상태 정의

| Status | 들어가는 조건 | 나가는 조건 |
|---|---|---|
| Backlog | 이슈 생성 | DoR 충족 |
| Ready | DoR 충족, `status/ready` | 월 계획에서 Sprint 지정과 착수 |
| In progress | 브랜치 생성(에이전트 실행 중) 또는 소유자 착수. 외부 대기 중인 소유자 행동도 여기(Gate 필드에 대기 표시) | draft PR이 CI 초록이고 Ready for review |
| In review | PR Ready for review | 병합(→ Done) 또는 변경 요청(→ In progress) |
| Done | PR 병합, 소유자 행동은 증빙 기록 완료 | — |
| Blocked | 내부 선행 미완, 결정 필요(`status/needs-decision`), 환경 문제. 사유 코멘트 필수 | 차단 해소 |

### 보기(View)

| 보기 | 레이아웃 | 필터·그룹 |
|---|---|---|
| 스프린트 보드 | Board(Status 열) | Sprint = 현재 반복 |
| 백로그 | Table | Status in (Backlog, Ready), Phase별 그룹, Priority·의존 순 정렬 |
| 게이트 트랙 | Table | label:owner-action, Gate별 그룹 |
| 에이전트 부하 | Board(Agent 열) | Status in (In progress, In review) — WIP 한도 확인 |
| 로드맵 | Roadmap | Sprint 기준, Phase별 색 |

기본 자동화(GitHub 내장 워크플로): 항목 추가 → Backlog, PR 병합 → Done, 이슈 닫힘 → Done, 이슈 다시 열림 → In progress.

---

## 단계 종료 검토

각 단계 마지막 스프린트 금요일에 60분 검토를 한다([V1-T06](templates/PHASE_EXIT_REVIEW.md)). 소유자 행동 DF-926(P0), DF-927(P1a), DF-928(P1b), DF-936(P2), DF-938(P3 GA)로 추적한다.

- 입력: PRD §12.1 종료 게이트, M-01~M-11, M-G1~M-G5, NFR-15 측정값, 게이트 증빙, 열린 질문(Q-, Q-DEV) 상태, 속도 추이.
- 판정: 통과 / 조건부 통과(미충족 항목과 기한) / 불통과. 불통과면 다음 단계로 넘어가지 않는다(PRD §12.7).
- M-G5가 목표를 넘으면 PRD §6.4.4 권장 항목·O 입력 항목 축소를 먼저 검토한다.
- 결정(D1~D14)에 영향이 있으면 PRD 개정 PR을 소유자가 연다. D1~D4는 소유자 재확정이 필요하다.

---

## 문서 변경

이 절은 docs/v1 모든 문서 헤더의 '변경 규칙' 링크가 가리키는 정본이다.

### 절차

1. **변경은 PR로만** 한다. 브랜치 `docs/DF-NNN-<slug>`(스토리와 함께 바뀌면 그 스토리 브랜치), 라벨 `type/docs`, `area/docs`.
2. 헤더의 **버전**을 올린다.
   - 오탈자·링크·서식: 버전 유지, 변경 이력만 추가.
   - 내용 추가·수정(규칙, 표, 명세 값): 소수 버전 증가(v1.0 → v1.1).
   - 구조 변경, 결정 뒤집기, 문서 분할·통합: 주 버전 증가(v1.x → v2.0).
3. 문서 끝 '변경 이력' 표에 `버전 | 날짜 | 변경 요지 | PR | PRD 영향`을 한 줄 추가한다.
4. **PRD 영향 판정**을 PR 본문에 적는다.
   - 없음: 파생 문서 안의 상세화.
   - 가정·질문 추가: `AS-DEV-NN`/`Q-DEV-NN`을 [V1-00](00_README.md)에 등록한다. PRD로 올릴 때는 PRD §13.4에 따라 AS-34, Q-25, RISK-12부터 새 번호를 받는다.
   - PRD 개정 필요: 이 문서군이 PRD와 달라지는 변경이다. 소유자가 PRD 개정 PR을 먼저(또는 같은 PR에서) 병합해야 한다. 에이전트는 PRD를 직접 고치지 않고 제안만 한다.
   - 결정 D1~D4 영향: 소유자 재확정 기록이 있어야 병합한다.
5. 헤더 **상태** 값은 `초안`, `개발 착수 기준(Ready)`, `개정 중`, `대체됨(→ 문서 ID)` 중 하나다. `대체됨` 문서는 지우지 않고 대체 문서 링크를 남긴다.
6. `docs-and-backlog` CI(헤더 표준, 링크, 백로그 검증)가 초록이어야 한다.

### 같은 PR에서 함께 고칠 문서

| 바뀐 것 | 함께 고칠 문서 |
|---|---|
| Firestore 스키마·컬렉션 | `docs/firestore_schema.md`, [V1-05](05_DATA_MODEL_AND_RULES.md), 픽스처, 매핑 코드 |
| callable·트리거·쿼리 | [V1-06](06_API_SPEC.md) |
| 트레이너 화면·상태 | [V1-07](07_TRAINER_APP_SPEC.md) |
| 회원 앱·관리자 | [V1-08](08_MEMBER_APP_AND_ADMIN_SPEC.md) |
| 산식·판정·매칭 규칙 | [V1-09](09_ALGORITHMS_SPEC.md), `contracts/vectors/**` |
| 테스트 층·CI job | [V1-10](10_TEST_PLAN.md), [ADR-013](adr/ADR-013-testing-strategy.md) |
| 이관 절차 | [V1-11](11_MIGRATION_RUNBOOK.md) |
| 문구·이벤트·금지어 | [V1-12](12_COPY_ANALYTICS_AND_LINT.md), `contracts/*.json` |
| 스프린트 배치·마일스톤 | [V1-03](03_RELEASE_AND_SPRINT_PLAN.md), `tool/backlog/milestones.json` |
| 작업 합의(이 문서) | 영향받는 템플릿(`templates/`), PR 템플릿, 이슈 폼 |

### ADR

- 되돌리기 어려운 기술 결정(의존성 추가, 저장 방식, 모듈 경계, 배포 방식)은 ADR([V1-T03](templates/ADR.md))로 남긴다. 파일은 `docs/v1/adr/ADR-NNN-kebab-title.md`.
- Accepted ADR은 수정하지 않는다. 바꿀 때는 새 ADR을 만들고 이전 ADR 상태를 `Superseded by ADR-NNN`으로 바꾼다.

---

## 가정과 스파인 차이 기록

이 문서와 템플릿에서 새로 둔 가정이다(문서 범위 ID, V1-00의 AS-DEV 목록에 통합할 후보).

| ID | 가정 | 관련 PRD·개발 가정 | 틀리면 |
|---|---|---|---|
| ASM-01-01 | 의식 시각은 [스프린트 리듬](#스프린트-리듬) 표가 정본이다: 월 09:30 계획 45분(기술 스파인 관례), 수 16:00 게이트 점검 15분, 목 14:00 다듬기 60분, 금 15:00 리뷰·데모 20분 + 15:20 회고 10분. [SPRINT_01](sprints/SPRINT_01.md)의 일정과 같다. 다듬기는 지시서 생성기(ASM-01-17)를 전제로 60분이다 | AS-DEV-09 | 다듬기가 넘치면 다음 스프린트 후보를 1개 스프린트분으로 줄인다 |
| ASM-01-02 | 1점 = 소유자 검토·통합 30분 규모의 에이전트 PR 1개. 20점 ≈ 주 10시간 검토 + 통합·실기기 | AS-DEV-09 | S03 보정에서 조정 |
| ASM-01-03 | 2027 설 연휴 날짜는 정부 고시 전 추정이다. S19-S20의 작업일을 약 8일로 잡는다(백로그 스파인은 02-05·02-08~02-09로 추정). 고시 확인 뒤 S19·S20 용량을 다시 계산한다 | AS-DEV-01 | 용량 재계산, P2 마일스톤 영향 없음(2주 묶음 안에서 흡수) |
| ASM-01-04 | Projects v2의 Iteration 필드로 1주 스프린트를 표현하고 휴일은 반복을 쪼개지 않는다(작업일 수는 SPRINT_NN.md에 적음) | AS-DEV-10 | 휴일 주를 별도 반복으로 쪼갬 |
| ASM-01-05 | 1인 체제라 브랜치 보호의 필수 승인 수는 0이다. 대신 PR 템플릿의 '소유자 검토 완료' 체크와 CODEOWNERS 표시로 대신한다 | ADR-014 | 협업자가 생기면 필수 승인 1로 올린다 |
| ASM-01-06 | 이슈 템플릿 config의 보안 신고 링크는 GitHub 비공개 취약점 신고(Private vulnerability reporting)를 켠다는 전제다 | NFR-10, RISK-06 | 소유자 이메일 안내로 대체(저장소에 이메일 원문은 적지 않음) |
| ASM-01-07 | 트레이너 앱 스킴 이름은 `DFETTrainer`, 기본 시뮬레이터는 `iPad Pro 13-inch (M4)`다. 최종값은 DF-008에서 정하고 이 문서와 V1-13을 갱신한다 | ADR-001, AS-DEV-06 | DoD 명령만 바꾼다 |
| ASM-01-08 | `npm --prefix functions test`는 현재 `test/clinical.test.js`만 실행한다(dfet:functions/package.json:8). DF-037에서 `test/unit/**`와 새 도메인 테스트를 포함하도록 스크립트를 확장한다 | ADR-017, AS-DEV-12 | DoD의 Functions 명령을 개별 경로로 바꾼다 |
| ASM-01-09 | Codex 클라우드 환경에서는 macOS 전용 검증(xcodebuild, 시뮬레이터)을 못 한다고 본다. 그래서 trainer_app UI 스토리는 Claude Code(소유자 Mac)에 우선 배정한다 | ADR-001 근거 2 | 배정 규칙만 바꾼다 |
| ASM-01-10 | 일일 기록은 스프린트마다 소유자가 만드는 `[SNN] 진행 기록` 이슈 코멘트로 남긴다. 이 이슈는 DF 키가 없는 운영 이슈다 | — | `SPRINT_NN.md`의 일일 절로 옮긴다 |
| ASM-01-11 | 게이트 증빙은 `docs/v1/evidence/<게이트 ID>.md`, 플래그 개방 체크리스트는 `docs/v1/evidence/flags-<키>.md`에 둔다(기술 스파인 문서 목록에 없는 폴더). [V1-03 ASM-03-11](03_RELEASE_AND_SPRINT_PLAN.md)·[SPRINT_01](sprints/SPRINT_01.md)과 같은 경로이며, 초안에 있던 별도 게이트 폴더는 쓰지 않는다. 원본 문서는 저장소 밖에 둔다 | G-04, G-09, RISK-06 | OWNER_ACTIONS_AND_GATES.md 안의 절로 합친다 |
| ASM-01-12 | 기술 부채는 별도 라벨 없이 type/chore + 제목 접두 '부채:'로 표시한다(labels.json에 새 라벨을 만들지 않기 위해) | — | labels.json에 `tech-debt` 라벨을 추가 |
| ASM-01-13 | 템플릿 파일 이름은 이 문서가 정한 짧은 이름을 쓴다(STORY.md 등). 기술 스파인 목록의 `*_TEMPLATE.md` 이름과 문서 ID 대응은 아래 표와 같다 | — | 다른 문서의 템플릿 링크를 아래 표 기준으로 고친다 |
| ASM-01-14 | 스프린트 운영 문서(`docs/v1/sprints/SPRINT_NN.md`)와 운영 이슈(`[SNN] 진행 기록`, `[릴리스] <태그>`)는 DF 키 없이 만든다. 브랜치는 `docs/sprint-NN` | — | 운영용 DF 키 대역을 따로 받는다 |
| ASM-01-15 | `static-guards`의 기존 위반(회원 앱의 `soap_notes` 조회 dfet:lib/services/firestore_service.dart:19, `isSharedWithMember: true` dfet:lib/widgets/shells/trainer_shell.dart:565, `getDownloadURL` dfet:lib/screens/create_request_screen.dart:100·dfet:lib/services/community_service.dart:45)은 기준선 허용 목록으로 고정하고 제거 스토리(DF-315, DF-387)에 연결한다. requests/·posts/의 getDownloadURL은 제거 스토리가 없어 Q-DEV 후보다 | PRD §9.5 링크 정책, AC-VIZ-06.1, AC-SOAP-05.8 | 기준선 없이 켜면 DF-011 병합 즉시 CI가 실패한다 |
| ASM-01-16 | owner-action 점수(0~1)와 스파이크 점수는 스프린트 약속과 속도(완료 점수)에 포함한다(02 §4.3 정본, 백로그 스파인, SPRINT_01 약속 18 = 개발 15 + 소유자 3). 1점 척도와 소유자 실제 시간(예: DF-901 약 12시간)이 다르므로 소유자 행동의 예상·실제 시간은 V1-T05 "소유자 시간" 표에 따로 적고 S03 보정 때 참고한다. R1 결정 2026-09-24 | AS-DEV-09, 백로그 스파인 velocity | 스파인 방식으로 되돌리려면 owner-action을 30분=1점으로 다시 매긴다(DF-901 약 24점이 되어 S01 약속을 다시 짜야 함) |
| ASM-01-17 | 작업 지시서 생성기 `tool/backlog/brief.mjs`(TL-13 후보, 기술 스파인 문서 목록에 없음)를 DF-002(백로그 도구) 범위에 넣는다. 입력은 카드와 이슈 JSON, 출력은 V1-T08 형식 Markdown이다. 새 npm 의존성 없이 Node 22 표준 라이브러리만 쓴다 | AS-DEV-09, 기술 스파인 TL-01~TL-12 | DF-002가 넘치면 별도 잡무 스토리(P0 대역)로 떼어 S02에 넣고, 그 전까지 소유자가 손으로 조립한다 |
| ASM-01-18 | DF-901(MIG-01, G-01)은 약 1.5일 걸려 2026-09-29(화) 12:00까지 병합한다. 그동안 에이전트는 새 경로에서 착수·푸시·draft PR까지 할 수 있고, 병합은 DF-901 뒤에 한다. `SPRINT_NN.md`는 S02부터 약 1쪽으로 제한하고 금요일에 에이전트가 초안을 만든다(SPRINT_01만 예외) | MIG-01, D13, RISK-04, [SPRINT_01 ASM-S01-01](sprints/SPRINT_01.md), [V1-03 D-4](03_RELEASE_AND_SPRINT_PLAN.md) | S01 회고에서 실측으로 조정 |
| ASM-01-19 | 가정 ID는 이 문서 범위 `ASM-01-NN`이다(이전 표기 ASM-NN, R10). 게이트 증빙 폴더는 `docs/v1/evidence/`(ASM-01-11, R6) | — | 다른 문서의 참조를 새 ID로 고친다 |

**기록 위치(ASM-01-10·11·14)**

| 기록 | 위치 | 템플릿 |
|---|---|---|
| 스프린트 계획·리뷰·회고 | `docs/v1/sprints/SPRINT_NN.md` | V1-T04, V1-T05, V1-T11 |
| 일일 기록 | 운영 이슈 `[SNN] 진행 기록` 코멘트 | V1-T12 |
| 작업 지시서, 완료 보고 | 스토리 이슈 코멘트 | V1-T08 |
| 스파이크 결과(표·데이터) | `docs/v1/spikes/DF-NNN-<slug>.md` | V1-T02 |
| ADR | `docs/v1/adr/ADR-NNN-<slug>.md` | V1-T03 |
| 게이트 증빙 | `docs/v1/evidence/<게이트 ID>.md` | V1-T07 |
| 플래그 개방 체크리스트 | `docs/v1/evidence/flags-<키>.md` | V1-T07 |
| 단계 종료 검토 | `docs/v1/reviews/PHASE_<단계>_EXIT.md` | V1-T06 |
| 실기기 기록 | PR 코멘트, 단계 검증 스토리는 `docs/v1/device-tests/DF-NNN.md` | V1-T09 |
| 이관 실행 | `docs/v1/migrations/MIG-NN-YYYYMMDD-<runId>.md` | V1-T10 |
| 릴리스 | 운영 이슈 `[릴리스] <태그>` | V1-T14 |
| 버그 | 이슈(bug.yml), S1 사후 검토는 이슈 코멘트 | V1-T13 |

**템플릿 문서 ID 대응(ASM-01-13)**

| 문서 ID | 파일 | 기술 스파인의 예정 이름 |
|---|---|---|
| V1-T01 | [templates/STORY.md](templates/STORY.md) | STORY_TEMPLATE.md |
| V1-T02 | [templates/SPIKE_REPORT.md](templates/SPIKE_REPORT.md) | SPIKE_TEMPLATE.md |
| V1-T03 | [templates/ADR.md](templates/ADR.md) | ADR_TEMPLATE.md |
| V1-T04 | [templates/SPRINT_PLAN.md](templates/SPRINT_PLAN.md) | SPRINT_PLAN_TEMPLATE.md |
| V1-T05 | [templates/SPRINT_REVIEW.md](templates/SPRINT_REVIEW.md) | SPRINT_REVIEW_RETRO_TEMPLATE.md(리뷰 부분) |
| V1-T06 | [templates/PHASE_EXIT_REVIEW.md](templates/PHASE_EXIT_REVIEW.md) | PHASE_EXIT_REVIEW_TEMPLATE.md |
| V1-T07 | [templates/GATE_EVIDENCE.md](templates/GATE_EVIDENCE.md) | GATE_EVIDENCE_TEMPLATE.md |
| V1-T08 | [templates/AGENT_BRIEF.md](templates/AGENT_BRIEF.md) | AGENT_TASK_BRIEF_TEMPLATE.md |
| V1-T09 | [templates/DEVICE_TEST_RECORD.md](templates/DEVICE_TEST_RECORD.md) | DEVICE_TEST_RECORD_TEMPLATE.md |
| V1-T10 | [templates/MIGRATION_RUN_RECORD.md](templates/MIGRATION_RUN_RECORD.md) | MIGRATION_RUN_RECORD_TEMPLATE.md |
| V1-T11 | [templates/RETRO.md](templates/RETRO.md) | (SPRINT_REVIEW_RETRO_TEMPLATE.md의 회고 부분) |
| V1-T12 | [templates/DAILY_LOG.md](templates/DAILY_LOG.md) | (신규) |
| V1-T13 | [templates/BUG_REPORT.md](templates/BUG_REPORT.md) | (신규) |
| V1-T14 | [templates/RELEASE_CHECKLIST.md](templates/RELEASE_CHECKLIST.md) | (신규) |

GitHub 템플릿: GH-01 [config.yml](../../.github/ISSUE_TEMPLATE/config.yml), GH-02 [epic.yml](../../.github/ISSUE_TEMPLATE/epic.yml), GH-03 [story.yml](../../.github/ISSUE_TEMPLATE/story.yml), GH-04 [task.yml](../../.github/ISSUE_TEMPLATE/task.yml), GH-05 [bug.yml](../../.github/ISSUE_TEMPLATE/bug.yml), GH-06 [spike.yml](../../.github/ISSUE_TEMPLATE/spike.yml), GH-07 [owner_action.yml](../../.github/ISSUE_TEMPLATE/owner_action.yml), GH-08 [pull_request_template.md](../../.github/pull_request_template.md).

**스파인과 달리 정한 것**

- 스프린트 달력·마일스톤 날짜는 백로그 스파인(P0 10-30, P1a 01-08, P1b 01-29, P2 03-26, P3 05-07)을 따른다. 기술 스파인 관례 8)의 날짜(10-23, 12-04, 01-15, 03-12, 04-23)는 속도 반영 전 초안이다. `tool/backlog/milestones.json`은 백로그 스파인 날짜를 써야 한다.
- Projects 필드는 기술 스파인(Status, Iteration, Phase, Size, Area, Agent, Gate)과 과제 지시(Status, Sprint, Points, Phase, Area, Priority)를 합쳤다. Size는 라벨로만 두고 필드는 Points로 통일했다.
- S02 속도 계산 시점: 백로그 스파인은 'S02 종료 금요일(10-09)'이라고 적었지만 10-09는 한글날이다. S02 리뷰는 10-08(목), 보정 계산은 S03 계획(10-12 월)에서 한다.
- DF-901 완료 시점: 백로그 스파인은 'S01 1일차 오전 완료 후 에이전트 브랜치 개설'이지만, 이 문서는 SPRINT_01·V1-03 D-4와 같이 '화 12:00 병합, 새 경로 선착수 허용, 병합은 그 뒤'로 정한다(ASM-01-18).

---

## 변경 이력

| 버전 | 날짜 | 변경 요지 | PR | PRD 영향 |
|---|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성 | — | 없음 |
| v1.0(릴리스 편집) | 2026-09-24 | 백로그 도구 참조를 단일 `tool/backlog/issues.json`과 `create_github_issues.sh`(호환 진입점 `create_backlog.sh`)에 맞춤. 순수 타깃 `swift test` 경로를 `Packages/TrainerCore`로 고침(V1-04 §6.2). owner-action 속도 포함 여부 충돌은 00_README K-01로 이관 | — | 없음 |
| v1.0.1(정합 패스 2) | 2026-09-24 | 교차 정합성 조정: owner-action·스파이크 점수를 약속·속도에 포함(ASM-01-16 재작성, R1), 가정 ID를 ASM-01-NN으로 변경(R10), SPRINT_01·V1-03 가정 참조 갱신, 순수 타깃 패키지 표기를 TrainerCore로 정정(R4) | — | 없음 |
