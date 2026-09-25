# P1b 백로그: 알파-평가

| 항목 | 값 |
|---|---|
| 문서 ID | V1-02-P1b |
| 버전 | v1.1 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | §6.1(F-ASM-01~05), §6.4 F-SOAP-03, §6.5(F-VIZ-01~04, F-VIZ-05, F-VIZ-07), §7.1~§7.8, §8.1(TR-07~TR-10), §8.3(AD-05), §8.4, §8.6, §9.2, §9.4~§9.6, §10.7, §10.8(NFR-05·06·12·15·17), §12.1 P1b, §12.3, §12.5, §12.6, 부록 A.1~A.3, 부록 C |
| 관련 에픽·스토리 | EP-07, EP-12, EP-14, EP-15 / DF-200~DF-226, 추가 제안 DF-227 / 소유자 행동 DF-912, DF-915, DF-927, DF-928, DF-929 |
| 변경 규칙 | [문서 변경](../01_AGILE_WORKING_AGREEMENT.md#문서-변경) |

## 목차

1. [이 문서의 범위와 읽는 법](#1-이-문서의-범위와-읽는-법)
2. [추가 제안](#2-추가-제안)
3. [P1b 개요: 게이트·플래그·스프린트·의존](#3-p1b-개요-게이트플래그스프린트의존)
4. [P1b 공통 구현 기준](#4-p1b-공통-구현-기준)
5. [가정(ASM-P1b-NN)](#5-가정asm-p1b-nn)
6. [스토리 카드](#6-스토리-카드)
   - S12: DF-200
   - S14: DF-201
   - S15: DF-203, DF-207, DF-216, DF-204, DF-220
   - S16: DF-205, DF-206, DF-208, DF-221, DF-211, DF-219, (제안) DF-227
   - S17: DF-209, DF-210, DF-214, DF-212, DF-225
   - S18: DF-215, DF-217, DF-218, DF-223, DF-224, DF-226
7. [관련 소유자 행동·게이트](#7-관련-소유자-행동게이트)
8. [추적성: PRD 요구사항 → 스토리](#8-추적성-prd-요구사항--스토리)
9. [변경 이력](#9-변경-이력)

---

> **DEC-22(2026-09-25) 범위 안내.** 카드 Labels에 `scope/mvp`가 있는 카드만 지금 만든다(카드의 `### MVP 범위(DEC-22)` 절이 범위를 정한다). `scope/carryover`는 이미 PR이 열려 있어 마치는 MVP 밖 항목이다. 둘 다 없는 카드는 **연기(DEC-22), MVP 뒤 재계획**이다: 카드 Sprint 값은 DEC-22 이전 계획이고, `issues.json`에서는 `scope/deferred`·스프린트 'MVP 뒤'가 되며 `brief.mjs`는 작업 지시서를 만들지 않는다. 정본은 [03 MVP 계획](../03_RELEASE_AND_SPRINT_PLAN.md#mvp-계획dec-22)이다.

## 1 이 문서의 범위와 읽는 법

- P1b(알파-평가) 단계의 스토리 카드 전문이다. 키, 제목, 점수, 스프린트, 의존은 백로그 스파인과 같다. 스파인에 없던 세부(파일 경로, 타입, 문구 키, 테스트)만 보탰다. 스파인과 다른 제안은 [2 추가 제안](#2-추가-제안)에 모았고, 카드 본문은 제안이 채택되지 않아도 구현할 수 있게 썼다.
- 카드 구조는 [V1-T01 스토리 템플릿](../templates/STORY.md)을 따른다: 메타 표 → 사용자 스토리 → 배경·맥락 → 수용 기준(Given/When/Then) → 구현 노트 → 테스트 → 비고·가정 → DoR 체크 → 에이전트 브리프.
- 수용 기준 번호는 `AC-DF-NNN.k`다. PRD 수용 기준을 그대로 검증하는 항목은 괄호 안에 PRD ID를 적었다. 테스트 함수 이름에는 AC ID를 넣는다(예: `test_AC_ASM_03_1_cvaVector()`, [V1-01 완료 정의](../01_AGILE_WORKING_AGREEMENT.md)).
- 정본 관계: 요구사항 의미는 [PRD](../../PRD_V1.md), 필드·규칙은 [V1-05](../05_DATA_MODEL_AND_RULES.md), 인터페이스는 [V1-06](../06_API_SPEC.md), 화면은 [V1-07](../07_TRAINER_APP_SPEC.md), 관리자 화면은 [V1-08](../08_MEMBER_APP_AND_ADMIN_SPEC.md), 산식·판정 규칙은 [V1-09](../09_ALGORITHMS_SPEC.md), 테스트 층은 [V1-10](../10_TEST_PLAN.md), 문구·이벤트는 [V1-12](../12_COPY_ANALYTICS_AND_LINT.md), 에이전트 운영은 [V1-13](../13_DEV_ENVIRONMENT_AND_AGENT_PLAYBOOK.md)이다. 이 문서와 충돌하면 그 문서가 우선이고, PRD와 충돌하면 PRD가 우선한다.
- 코드 근거는 `dfet:경로:줄`(DFET_Coach 저장소, 브랜치 `feature/integrated-care-2026`, 2026-09-24 작업 트리)로 적었고 모두 파일을 열어 확인했다. `trainer_app/`은 아직 없는 폴더라 경로는 기술 스파인 저장소 배치([V1-04](../04_ARCHITECTURE.md))의 **생성 예정 경로**다.
- 테스트 데이터는 전부 합성(가상 회원 `synthMember0001` 등, [V1-05](../05_DATA_MODEL_AND_RULES.md) 예시와 같은 표기)이다. 실데이터, `output/`, `tmp/`, 비밀 파일은 열지 않는다.

---

## 2 추가 제안

스파인을 검토하다 찾은 빈틈과 충돌이다. 소유자가 스프린트 계획(월요일)에서 채택 여부를 정한다. 채택 전에는 각 카드의 '대안' 문장대로 진행한다.

### 2.1 새 스토리 DF-227 (다음 빈 키)

| 키 | 제목 | 점수 | 제안 스프린트 | 이유 |
|---|---|---|---|---|
| DF-227 | 체형평가 원격 조회 저장소와 사진 바이트 캐시를 구현한다(동의 ③ 게이트, 철회 시 로컬 삭제) | 2 | S16 | 스파인 P1b 스토리는 쓰기 쪽(DF-206)과 화면(DF-214, DF-225)만 있고, ① `postureAssessments` 목록 조회 저장소, ② Storage 바이트 다운로드와 로컬 캐시(NFR-17, `getDownloadURL` 금지), ③ 동의 ③ 철회 시 기기에 남은 체형 사진 삭제(NFR-17 수용 기준, F-PRIV-02.3 ③ 행)를 맡는 스토리가 없다. DF-112(P1a)는 체형 사진이 생기기 전 단계라 이 경로를 검증할 수 없다 |

**용량 영향과 재배치 제안:** S16 약속이 18점에서 20점으로 는다. 스파인 속도 규칙(could 먼저 이월)에 따라 DF-224(could, S18)를 P2 첫 묶음(S19-S20)으로 넘기고 DF-211(should, S16)을 S18로 옮기면 S16 18점, S18 18점이 된다. 채택하지 않으면 DF-227 범위를 DF-214(원격 조회·사진 로드)와 DF-206(철회 시 로컬 삭제)에 나눠 넣는다(각 카드 '대안' 참조).

### 2.2 스파인·다른 문서와의 충돌·보강 요청

| # | 내용 | 영향 스토리 | 제안 |
|---|---|---|---|
| G-P1b-1 | 기술 스파인의 `contracts/` 목록에 **촬영 프로토콜 허용값**과 **seriesBreak 벡터** 파일이 없다 | DF-203, DF-204, DF-216, DF-224 | `contracts/posture-protocol.v1.json`(ASM-P1b-05)과 `contracts/vectors/series-break.v1.json`(ASM-P1b-19)을 추가하고 DF-004의 메타 스키마(`schemas/contracts-meta.schema.json`)가 두 파일을 받게 한다 |
| G-P1b-2 | Storage 규칙(PRD §9.5, DF-023)은 체형 사진 쓰기를 '부모 draft'로만 허용한다. 그래서 **voided 이전 버전의 사진 삭제**(F-ASM-01.9 '이전 버전 사진을 파기')를 클라이언트가 할 수 없다 | DF-211 | DF-023 규칙에 `allow delete: if 부모 trainerId==uid && 부모 status in ['draft','voided']`를 추가한다(생성·덮어쓰기는 계속 draft만). 채택 전에는 DF-211의 확정본 경로를 '서버 삭제 대기' 상태로 두고 소유자가 Admin SDK로 지운다(ASM-P1b-11) |
| G-P1b-3 | Storage 규칙이 **동의 ③을 확인하지 않는다.** F-PRIV-02.3의 ③ 철회 즉시 '업로드 거부'가 클라이언트 검사에만 기댄다 | DF-206 | DF-023에 `firestore.get(memberConsentStates/{key}).data.bodyImaging.granted == true` 조건을 체형 사진 쓰기에 추가한다(교차 조회 2건). 채택 전에는 SyncEngine이 업로드 직전에 서버 동의 상태를 확인한다(ASM-P1b-12) |
| G-P1b-4 | PRD §9.6 인덱스가 **대기 회원 키(`pendingMemberId`) 기준 조회**를 다루지 않는다. 대기 회원도 동의 ②③이 있으면 체형평가 대상이다 | DF-214, DF-215, DF-217, DF-227 | DF-024 보강: `postureAssessments(trainerId, pendingMemberId, capturedAt↓)`, `bodyCompositionRecords(trainerId, pendingMemberId, measuredAt↓)`, `circumferenceMeasurements(trainerId, pendingMemberId, metricCode, measuredAt↓)`, `soap_notes(trainerId, pendingMemberId, sessionDate↓)`(ASM-P1b-27) |
| G-P1b-5 | 스파인은 F-VIZ-01 편위 표 렌더러를 FeatureInsights에 두지만, 스파인 모듈 의존에서 FeatureAssessment(TR-09)는 FeatureInsights를 import할 수 없다 | DF-210 | 렌더러 뷰는 `DesignSystem/PostureDeviationTable`, 행 조립 로직은 `TrainerDomain/Posture/DeviationRowBuilder`에 둔다(ASM-P1b-38) |
| G-P1b-6 | PRD §9.2 예시 `landmarkEngine.version`은 `"iOS17.4"`인데 F-ASM-02.1은 '엔진 이름·리비전·OS 버전'을 기록하라고 한다. 맵 키는 `{name, version}` 두 개뿐이다 | DF-207 | `version`에 `"iOS17.4-r1"`처럼 OS와 요청 리비전을 함께 적는다(ASM-P1b-04). V1-05 예시와 형식이 다르므로 V1-05 담당이 맞춘다 |
| G-P1b-7 | 스파인 달력 판단은 'P1b 약속량 81점'이라고 적었지만 스파인 P1b 스토리 점수 합은 78점이다(소유자 행동 DF-915 1점을 더하면 79점). 스프린트별 합계(S15 17, S16 18, S17 18, S18 18)는 스파인 표와 같다 | — | 달력 판단에는 영향 없음. 02_PRODUCT_BACKLOG의 합계만 78점(+DF-227 제안 2점)으로 고친다 |
| G-P1b-8 | S17의 DF-210, DF-212, DF-214, DF-225가 모두 같은 스프린트의 DF-209(5점)에 의존한다 | S17 전체 | DF-209가 1일차에 `AssessmentLifecycle` 프로토콜과 가짜 구현을 먼저 병합하고(작은 PR), 의존 스토리는 그 프로토콜 위에서 작업한다. 3일차까지 DF-209 본체가 병합되지 않으면 DF-212를 S18로 넘긴다 |
| G-P1b-9 | DF-209 `Sources/TrainerDomain/Posture/DefaultAssessmentLifecycle.swift`가 PostureMath·LocalStore·SyncEngine Outbox를 호출해 TrainerDomain 경계를 깨고 PostureMath→TrainerDomain 순환을 만든다 | DF-209, DF-210, DF-212, DF-214, DF-225 | 결정 대기([V1-00 K-10](../00_README.md)): 구현을 SyncEngine으로 옮기고 PostureMath를 TrainerDomain 프로토콜로 주입하거나, 스파인에 SyncEngine→PostureMath 의존 추가(S14 전, ASM-P1b-43) |

---

## 3 P1b 개요: 게이트·플래그·스프린트·의존

### 3.1 단계 정의(PRD §12.1)

| 항목 | 내용 |
|---|---|
| 참여 인원 | 트레이너 1명(소유자) |
| 범위 | 체형 촬영·보정·지표·저장(F-ASM-01~04), 재검사 태깅(F-ASM-05.1~05.3), O 자동 불러오기(F-SOAP-03), 편위 표·오버레이·추이(F-VIZ-01~03, 판정 없이 '산정 준비 중'), NRS 추이(F-VIZ-04.4), 타임라인 체형 이벤트(F-VIZ-05.1), AD-05, 정책 kind 검증(§10.7) |
| 진입 게이트 | P1a 종료(DF-927, 목표 S15 2027-01-08). 코딩은 P1a 기간(S12·S14)에 먼저 시작한다. 외부 게이트는 합성 데이터 코딩을 막지 않는다 |
| 플래그 | `bodyAssessment`(기본 false). 소유자가 DF-929에서 연다(S17, TR-07~TR-09 동작 확인 뒤, PRD §12.3 순서 2). 개발·테스트는 에뮬레이터 시드(`appConfig/features.bodyAssessment=true`)와 DEBUG 로컬 오버라이드로 한다 |
| 종료 게이트(MS-P1b, S18 2027-01-29) | M-04a/b·M-03·M-05(조건 사유) 측정, M-G5 검토(초과하면 PRD §6.4.4 축소 절차), 데이터 유실 0건, 실기기 촬영 프로토콜 기록(DF-223), 상태 매트릭스·접근성(DF-226), V1-T06 검토(DF-928) |
| 병렬 트랙 | G-06 자세 재검사 연구: IRB(DF-912) 승인 뒤에만 실제 재검사 데이터를 모은다. DF-212 코드는 합성 데이터로 먼저 만든다 |

### 3.2 스프린트 배치(스파인과 같음)

| 스프린트 | 기간 | 약속 | 스토리(점수) | 목표 |
|---|---|---|---|---|
| S12 | 2026-12-14~12-18 | (P1a 18 중 2) | DF-200(2) | Vision 2D 선행 스파이크(타임박스 2일) |
| S14 | 2026-12-28~12-31 | (P1a 13 중 5) | DF-201(5) | PostureMath 산식·벡터 |
| S15 | 2027-01-04~01-08 | 17 | DF-203(3), DF-207(3), DF-216(3), DF-204(5), DF-220(3), DF-927(0) | 스테이션·촬영, 제안 어댑터, seriesBreak 공통 규칙, AD-05 |
| S16 | 2027-01-11~01-15 | 18(+2 제안) | DF-205(3), DF-206(3), DF-208(5), DF-221(3), DF-211(2), DF-219(2), (제안) DF-227(2) | 사진 보호, 오프라인 큐, TR-08 보정, 정책 kind 검증 |
| S17 | 2027-01-18~01-22 | 18 | DF-209(5), DF-210(3), DF-214(5), DF-212(3), DF-225(2), DF-929(0) | 확정·버전·기준선, TR-09, TR-10 비교, 재검사, 타임라인 |
| S18 | 2027-01-25~01-29 | 18 | DF-215(5), DF-217(5), DF-218(2), DF-223(2), DF-224(2), DF-226(2), DF-928(0) | 추이, O 자동 불러오기, 실기기·성능, 상태 스냅샷, P1b 종료 |

### 3.3 의존 그래프(P1b 안쪽)

```
DF-008 ─▶ DF-200 ─┐
DF-003,009 ─▶ DF-201 ─┼─▶ DF-207 ─▶ DF-208 ─▶ DF-209 ─┬─▶ DF-210 (+DF-130)
                    │                           ▲     ├─▶ DF-212
                    └─▶ DF-216 ─────────────────┼─────┼─▶ DF-214 ─┐
DF-014,915 ─▶ DF-203 ─▶ DF-204 ─┬─▶ DF-205      │     ├─▶ DF-225   ├─▶ DF-226
            (DF-110) ────┘      ├─▶ DF-206 ─────┘     ├─▶ DF-215 ─┘
                                │      └─▶ DF-211     ├─▶ DF-217 ─▶ DF-218
                                │      └─▶ (DF-227)   └─▶ DF-223
DF-004 ─▶ DF-220, DF-221          DF-130,117 ─▶ DF-219     DF-137,216 ─▶ DF-224
```

### 3.4 에이전트 레인(동시 브랜치 3개 이하, TrainerKit 타깃 비중복)

[V1-01 ASM-01-09](../01_AGILE_WORKING_AGREEMENT.md)에 따라 macOS·시뮬레이터 검증이 필요한 `trainer_app/` 스토리는 Claude(소유자 Mac), admin_web·functions·Dart만 있는 스토리는 Codex에 배정한다.

| 스프린트 | 레인 A (claude) | 레인 B (claude) | 레인 C (codex, 또는 표에 적은 경우 claude) |
|---|---|---|---|
| S15 | DF-203(LocalStore·FeatureSettings·FeatureAssessment/Capture) → DF-204(FeatureAssessment/Capture·PostureVision/Capture) | DF-207(PostureVision/Landmarks·PostureMath/Mapping) 먼저 병합 → DF-216(TrainerDomain/Series + Dart) | DF-220(admin_web) |
| S16 | DF-208(FeatureAssessment/Calibration·DesignSystem/Overlay) | DF-206(SyncEngine·FirebaseData/Posture·LocalStore) → DF-205(PostureVision/Privacy) → (DF-227) | DF-221(admin_web) ; DF-219·DF-211은 레인 A·B가 끝난 뒤 |
| S17 | DF-209(TrainerDomain/Posture·FeatureAssessment/Lifecycle) → DF-212 | DF-214(FeatureInsights/Compare) → DF-225(FeatureMembers/Timeline) | (claude, 세 번째 브랜치) DF-210(FeatureAssessment/Result·DesignSystem/Posture) — DF-209의 프로토콜 PR 병합 직후 시작 |
| S18 | DF-217(FeatureSOAP/Objective·TrainerDomain/Objective·SyncEngine/Objective) → DF-218 | DF-215(FeatureInsights/Trend) → DF-226(UITests) | DF-224(functions/ops) ; DF-223은 소유자 실기기 |

---

## 4 P1b 공통 구현 기준

모든 P1b 카드에 적용한다. 카드에는 이 절과 다른 점만 적었다.

- **DoR 추가(문구 키).** 카드가 인용한 문구 키는 `data/copy_ko.json`에 있어야 한다([P1a §5.3](P1a.md) 규칙). P1b 카드의 덱 밖 키 약 77개는 S14 전 다듬기에서 정리한다([V1-00 K-11](../00_README.md)).

### 4.1 모듈과 경로

| 모듈(TrainerCore·TrainerKit 타깃, 패키지는 아래 경로 접두어) | P1b에서 만드는 폴더 | 주 스토리 |
|---|---|---|
| `TrainerContracts` | `Generated/PostureProtocol.swift`(생성물) | DF-203 |
| `TrainerDomain` | `Posture/`(엔티티·수명주기·기준선·재검사 필터), `Series/`(conditionKey·seriesBreak), `Objective/`(O 후보 선택 규칙·`ObjectiveSource` 프로토콜·스냅샷, 순수) | DF-209, DF-212, DF-216, DF-217 |
| `PostureMath` | `Geometry/`, `Metrics/`, `Requirements/`, `Mapping/` | DF-201, DF-207 |
| `PostureVision` | `Capture/`, `Landmarks/`, `Privacy/` | DF-204, DF-205, DF-207 |
| `LocalStore` | `Models/StationProfile.swift`, `Models/LocalAssessmentDraft.swift` | DF-203, DF-204 |
| `SyncEngine` | `Plans/PostureOutboxPlan.swift`, `Objective/`(O 후보 구체 원천), `Stores/SoapNoteStoreImpl+Objective.swift` | DF-206, DF-217 |
| `FirebaseData` | `Posture/`(매퍼·리더·사진 바이트) | DF-206, DF-227 |
| `DesignSystem` | `Posture/PostureOverlayCanvas.swift`, `Posture/PostureDeviationTable.swift` | DF-208, DF-210 |
| `FeatureAssessment` | `Capture/`(TR-07), `Calibration/`(TR-08), `Result/`(TR-09) | DF-204, DF-208, DF-209, DF-210 |
| `FeatureInsights` | `Compare/`(TR-10 나란히·겹쳐), `Trend/`(TR-10 추이·NRS) | DF-214, DF-215, DF-219 |
| `FeatureSOAP` | `Review/Objective/` | DF-217, DF-218 |
| `FeatureMembers` | `Timeline/PostureTimelineRow.swift` | DF-225 |
| `FeatureSettings` | `StationProfiles/` | DF-203 |

- 경로 접두어: 순수 타깃(TrainerContracts, TrainerDomain, PostureMath, SyncEngine, TrainerAnalytics)은 `trainer_app/Packages/TrainerCore/Sources/<Target>/…`·`…/TrainerCore/Tests/<Target>Tests/…`, iOS 타깃(PostureVision, LocalStore, FirebaseData, DesignSystem, Feature*)은 `trainer_app/Packages/TrainerKit/Sources/<Target>/…`·`…/TrainerKit/Tests/<Target>Tests/…`, UI 테스트는 `trainer_app/UITests/`, 에뮬레이터 연동 테스트는 `trainer_app/IntegrationTests/`.
- 순수 타깃(TrainerContracts, TrainerDomain, PostureMath, SyncEngine, TrainerAnalytics)은 `swift test --package-path trainer_app/Packages/TrainerCore`(macOS, V1-04 §6.2)로 돈다. `PostureVision`과 Feature 타깃은 iPad 시뮬레이터 `xcodebuild test`다.
- Firebase import는 `FirebaseData`와 App 타깃뿐이다(NFR-03, static-guards).

### 4.2 데이터 계약

- `postureAssessments` 필드·예시·상태 전이·수정 가능 키: [V1-05 §4.6](../05_DATA_MODEL_AND_RULES.md). `views[].maskedThumbPath`와 `captureConditions.clothing` enum(`fitted|regular|unknown`)은 V1-05의 가정(ASM-05-04, ASM-05-05)을 그대로 쓴다.
- 문서 ID는 클라이언트 자동 ID(20자, 오프라인에서도 확정)다. `native_` 접두어 금지(R-24).
- 측정 시각 `capturedAt`은 **정면·측면 가운데 먼저 누른 셔터 시각**이다(ASM-P1b-35). 저장 시각 `createdAt`, `updatedAt`은 `serverTimestamp()`다.
- 지표 저장값은 0.1° 반올림(ASM-P1b-03). 단위 문자열은 `"deg"`.
- P1b의 모든 변화 판정 자리는 `pendingPolicy`('산정 준비 중')다. 트레이너 앱은 P1b에서 `insightPolicyVersions`를 읽지 않는다(ASM-P1b-28, ADR-009).

### 4.3 동의·플래그 게이트

| 동작 | 필요 조건(클라이언트) | 서버 강제 |
|---|---|---|
| TR-07 진입·촬영·로컬 draft 생성 | `bodyAssessment` 플래그, 서버 확인된 ②`healthData` **그리고** ③`bodyImaging`(`awaitingConsent` 아님) | create 규칙 `hasConsent(②)·hasConsent(③)·featureOn`(R-15) |
| 재검사 모드(`retestGroupId`) | 위 + ⑤`research` | create 규칙 R-16 |
| 사진 표시·다운로드(TR-08~TR-10, TR-03 썸네일) | 서버 확인된 ③ | 읽기 규칙은 동의를 보지 않는다 → 클라이언트 게이트(G-P1b-3) |
| O 자동 불러오기(TR-05) | `soapV2` 플래그. 원 기록 종류별 플래그는 후보 노출에만 적용 | soap update 규칙 |

- 동의 상태는 `ConsentService.observeState(member:)`(P1a DF-109·DF-110) 하나로 읽는다. 로컬 캡처만 있고 서버 확인 전이면 '동의 확인 대기'로 막는다(F-PRIV-03.7).
- 플래그가 false면 TR-07 진입점, TR-10 진입점, TR-09 '새 버전'·'재검사' 버튼이 없다(AC-IA-02). 이미 저장된 기록의 열람(TR-09 읽기, TR-03 타임라인)은 유지한다(AS-18, ASM-P1b-26).

### 4.4 저장 상태와 오프라인

- 체형 draft의 편집 원본은 SwiftData `LocalAssessmentDraft`다(ADR-002). Outbox 순서는 [DF-206](#df-206-체형-draft-오프라인-저장과-사진-업로드-큐확정-대기-표시를-구현한다)의 표가 정본이다.
- 표시는 `SyncStateBadge`(DF-016)만 쓴다. 로컬에서 확정했지만 서버 반영 전이면 노트 상태 라벨 '확정 대기'와 syncState '동기화 중'을 함께 보인다(AC-ASM-04.5).
- 모든 쿼리는 `trainerId == uid`와 회원 키(`memberUid` 또는 `pendingMemberId`)를 함께 건다. 오류는 '불러오기 실패'와 재시도로 드러낸다(§9.6, D11).

### 4.5 문구와 접근성

- 사용자 문자열은 `trainer_app/App/Localizable.xcstrings`에 키로 넣는다. 키 규칙은 `<화면>.<영역>.<의미>`(예: `tr07.gate.consentMissing`), 공통은 `common.*`. 카드의 문구 표는 초안이고 [V1-12](../12_COPY_ANALYTICS_AND_LINT.md)가 정본이다.
- 금지 표현(PRD 부록 C): '거북목', '교정', '진단', '치료', '재활', '정상/비정상', '체형 점수' 등. 관찰 문구만 쓴다(F-ASM-03.7). copy-lint 트레이너 세트를 통과해야 한다.
- 접근성 식별자는 `tr07.shutter`처럼 소문자 화면 ID로 시작한다. VoiceOver 문장은 PRD §8.6 A-03 템플릿을 따른다.

### 4.6 분석 이벤트(P1b 신규)

`contracts/analytics-events.v1.json`(DF-033)에 이미 등록된 §5.5 초안을 쓴다. 속성 값은 구간·개수만 보낸다.

| 이벤트 | 속성 | 보내는 시점 | 지표 | 스토리 |
|---|---|---|---|---|
| `posture_capture_started` | `session_id` | TR-07 진입 후 게이트 통과(카메라 미리보기 표시) | M-04a | DF-204 |
| `posture_capture_done` | `session_id`, `views_count`, `retake_count_band`, `elapsed_band` | 정면·측면 두 장이 모두 로컬 저장된 순간 | M-04a | DF-204 |
| `posture_landmarks_confirmed` | `manual_adjust_count_band`, `engine_version`, `elapsed_band` | 평가 `confirmed` 로컬 저장 성공(보정 시작부터) | M-04b | DF-208(측정 시작), DF-209(전송) |
| `soap_review_finalized` | 기존 + `auto_ref_count_band` | 기존(DF-122) | M-11 | DF-217(값 채움: `SoapNoteStoreImpl+Finalize.swift`의 `autoRefCount` 인자 한 줄) |
| `change_status_rendered` | `surface=trainer` | 변화 칸이 화면에 처음 그려질 때(값·상태 없음) | 노출 빈도 | DF-210, DF-215 |

### 4.7 공통 테스트 데이터

- 합성 회원: `synthMember0001`(가입, ②③ 있음), `synthMember0002`(가입, ②만), `synthMember0003`(가입, ②③⑤), `SYNTHpending00000001`(대기, ②③). 담당 트레이너 `synthTrainerA`, 비담당 `synthTrainerB`. 시드는 정본 스크립트 `functions/scripts/dev/seed-emulator.js`로 `functions/test/fixtures/emulator-seed.v1.json`(변형 `.no-consent.v1.json`·`.consent-fail.v1.json`, 프로젝트 `demo-dfet`)을 적재하며, P1b 데이터는 P1a DF-107이 확장한 같은 시드 파일에 더한다(R2, [V1-05 ASM-05-43](../05_DATA_MODEL_AND_RULES.md)).
- 합성 사진: DF-200이 정한 라이선스 확인 이미지나 마네킹 사진만 쓴다(ASM-P1b-39). 저장소에 넣는 이미지는 `…/Tests/PostureVisionTests/Fixtures/`와 `LICENSES.md`에 출처를 적는다.
- 벡터: `contracts/vectors/posture-metrics.v1.json`(DF-201), `contracts/vectors/series-break.v1.json`(DF-216).

---

## 5 가정(ASM-P1b-NN)

문서 범위 ID다. 채택되면 V1-00의 AS-DEV 목록으로 옮긴다([V1-01 가정과 스파인 차이 기록](../01_AGILE_WORKING_AGREEMENT.md)).

| ID | 가정 | 관련 PRD | 틀리면 |
|---|---|---|---|
| ASM-P1b-01 | `sagittalLeft`는 대상자의 **왼쪽 옆면이 카메라를 향한** 사진이고, 보이는 이주는 `tragusLeft`다 | 부록 A.3 '보이는 쪽', F-ASM-02.7 | 매핑 표(DF-207)와 벡터만 바꾼다 |
| ASM-P1b-02 | `imageRotationDeg`는 셔터 시점 `levelDeg`에서 구한다. 부호(반시계 양수)와 `levelDeg`와의 관계는 V1-09가 정본이고, DF-201의 합성 수평선 테스트와 DF-200 실기기 확인으로 고정한다 | F-ASM-03.2, §9.2 | V1-09와 벡터를 고친다(저장 데이터가 생기기 전 P1b 안에 확정) |
| ASM-P1b-03 | 0.1° 반올림은 '0에서 먼 쪽 반올림'(half away from zero)이다. Swift `.toNearestOrAwayFromZero`, Dart `round()`, JS는 `Math.sign(v)*Math.round(Math.abs(v)*10)/10` | F-ASM-03.6, §7.5 | 벡터 기대값만 바뀐다 |
| ASM-P1b-04 | `landmarkEngine.version` = `"iOS{major.minor}-r{요청 리비전}"`(예 `"iOS17.4-r1"`) | F-ASM-02.1, Q-18, AS-12 | 필드 형식만 바꾼다. 분석 속성 `engine_version`도 같다 |
| ASM-P1b-05 | 촬영 프로토콜 v1 수치(roll·pitch 허용 범위, 카메라 높이·거리 범위, 복장 선택지, 발 간격)는 `contracts/posture-protocol.v1.json`에 두고 생성기가 Swift 상수로 만든다. 값은 DF-915(소유자)가 정한다. 그 전 기본값: roll ±1.0°, pitch ±2.0°, 높이 90~110cm, 거리 2.5~3.5m | F-ASM-01.2, F-ASM-01.4, §7.4 | 파일 값만 바꾸고 `protocolVersion`을 올린다 |
| ASM-P1b-06 | draft 동안 지표는 화면에서 즉시 계산해 보여 주고 문서에는 **확정할 때** 저장한다 | F-ASM-04.1, §9.2 `metrics` ○(draft) | draft 저장 시에도 `metrics`를 쓰도록 DF-206 매퍼만 바꾼다 |
| ASM-P1b-07 | confirmed 문서의 지표는 모두 `photoManual`이다(확정 전제가 필수 랜드마크 전부 confirmed이므로). `photoAuto`는 draft 미리보기(TR-09 '확정 전')에만 나타난다 | F-ASM-03.5, F-ASM-04.2, AS-30 | TR-09·스냅샷에서 photoAuto 칩 경로를 켠다(렌더러는 이미 지원) |
| ASM-P1b-08 | 회원 × 측면 방향의 **첫 확정**이면 TR-09 '기준선' 토글이 켜진 상태로 제시된다(트레이너가 끌 수 있음) | F-ASM-04.4, AS-33 | 기본값만 끈다 |
| ASM-P1b-09 | 기준선 문서를 새 버전으로 대체하면 새 버전이 `isBaseline=true`를 물려받고, 이전 문서는 같은 update에서 `status=voided`, `isBaseline=false`가 된다(규칙이 confirmed에서 두 키 변경을 허용) | F-ASM-04.3, F-ASM-04.4 | 기준선 재지정을 트레이너에게 요구 |
| ASM-P1b-10 | 새 버전(재보정)은 경로가 기록 ID 기준이므로 사진 바이트를 **새 assessmentId 경로에 다시 올린다**(로컬 원본 또는 캐시, 없으면 SDK 바이트 다운로드) | §9.5 '기록 ID 기준 경로', F-ASM-04.3 | 서버 복사 함수로 바꾼다(P2) |
| ASM-P1b-11 | voided 이전 버전 사진의 삭제는 G-P1b-2 규칙 보강이 필요하다. 채택 전에는 앱이 '서버 삭제 대기'로 표시하고 소유자가 Admin SDK 스크립트로 지운다 | F-ASM-01.9, AC-ASM-01.7 | — |
| ASM-P1b-12 | ③ 철회 뒤 업로드 차단은 SyncEngine이 업로드 직전에 서버 동의 상태(`memberConsentStates`)를 한 번 더 읽어 보장한다(G-P1b-3 채택 전) | F-PRIV-02.3, NFR-17 | 규칙 보강 후에도 클라이언트 검사는 유지 |
| ASM-P1b-13 | 얼굴 가림 썸네일: `VNDetectFaceRectanglesRequest` 사각형을 30% 넓혀 **단색 채움**(블러 아님)한다. 얼굴을 못 찾으면 확정 시점에 귀·이주 랜드마크 중심의 머리 상자(이미지 높이의 18% 정사각형)로 채운다. 둘 다 불가하면 가림본을 만들지 않고 `maskedThumbPath=null`(P2 공유 불가) | F-ASM-01.10 | 가림 방식만 바꾼다 |
| ASM-P1b-14 | 업로드 사진은 JPEG(품질 0.85, 긴 변 ≤ 4032px, ≤ 10MB), 썸네일·가림본은 긴 변 480px, 품질 0.7(≤ 512KB) | §9.5 크기 제안값 | 인코딩 상수만 바꾼다 |
| ASM-P1b-15 | 사진 업로드는 draft 문서가 서버에 반영된 뒤 뷰별로 큐에 넣는다. 재촬영하면 대기 중인 업로드 작업을 취소하고, 이미 올라갔으면 Storage 삭제 작업을 넣는다(draft라 규칙 허용) | F-ASM-01.6, NFR-05 | — |
| ASM-P1b-16 | 재검사 묶음의 '첫 확정 기록'은 묶음 안 confirmed 문서 가운데 `capturedAt`이 가장 이른 것(같으면 `createdAt`)이다 | F-ASM-05.3 | 필터 함수만 바꾼다 |
| ASM-P1b-17 | 기울기 지표(`headTiltFrontal`, `shoulderTiltAngle`, `pelvicTiltFrontal`)의 추이는 부호 있는 한 선(side=right → +θ, left → −θ, none → 0)과 0 기준선으로 그린다. 좌우가 별도 시리즈인 지표(허벅지 등 둘레)는 L/R 두 선이다 | F-ASM-03.4 '오른쪽=+', F-VIZ-03.8 | 기울기도 L/R 두 선으로 바꾼다 |
| ASM-P1b-18 | 자세 조건 비교에서 카메라 높이·거리는 **프로토콜 허용 범위 안이면 같다**고 본다. `stationProfileId` 자체는 비교하지 않는다 | §7.4 | 비교 키에 프로필 ID 추가 |
| ASM-P1b-19 | seriesBreak 벡터 파일 `contracts/vectors/series-break.v1.json`을 새로 둔다(G-P1b-1) | §7.4, ADR-009 | 기존 벡터 파일에 합친다 |
| ASM-P1b-20 | Dart 공통 규칙 위치는 `lib/models/series_point.dart`와 `lib/utils/series_segmenter.dart`다 | 기술 스파인 Flutter 폴더 규칙 | 경로만 바꾼다 |
| ASM-P1b-21 | O 자동 불러오기 후보에는 아직 동기화되지 않은 로컬 기록(LocalStore)도 syncState 칩과 함께 포함한다. 오프라인이면 Firestore 캐시와 로컬 기록으로만 후보를 만든다 | F-SOAP-03.1, NFR-04 | 서버 확인 기록만 후보로 |
| ASM-P1b-22 | 줄자 스냅샷은 **반복값 문서마다 하나**(`refId`=measurementId)씩 저장하고 Review는 부위·측면별 평균과 개별값을 묶어 보인다. '종류별 최근 1건'에서 줄자 1건은 **가장 최근 측정일의 줄자 기록 묶음**이다 | F-SOAP-03.2, F-SOAP-03.3, F-ASM-06.4, AS-23 | 대표값 스냅샷 1개로 바꾼다 |
| ASM-P1b-23 | '같은 날'은 기기 시간대(Asia/Seoul) 달력일로 `sessionDate`와 측정 시각을 비교한다 | F-SOAP-03.2 | 센터 시간대 설정 도입 |
| ASM-P1b-24 | '원본 변경됨'의 기준 시각: finalized 노트는 `finalizedAt`, draft 노트는 로컬 `LocalSoapDraft.snapshotsAppliedAt`(Firestore에 쓰지 않음) | F-SOAP-03.6, §9.3 스냅샷 필드 고정 | 스냅샷 원소에 시각 필드 추가(PRD 개정 필요) |
| ASM-P1b-25 | 통증 NRS 추이는 **finalized** 노트의 `subjective.painNrs`만, x축은 `sessionDate`다 | F-VIZ-04.4, F-VIZ-03.1 | draft 포함으로 바꾼다 |
| ASM-P1b-26 | `bodyAssessment=false`여도 이미 저장된 체형평가는 TR-03 타임라인과 TR-09(읽기 전용)에 보인다. 생성·수정 진입점만 숨긴다 | AS-18, AC-IA-02, F-VIZ-05.1 플래그 열 | 타임라인에서 체형 이벤트를 숨긴다 |
| ASM-P1b-27 | 대기 회원 키 조회용 복합 인덱스가 추가된다(G-P1b-4) | §9.6 | 대기 회원은 체형 비교·추이를 승격 뒤에만 제공 |
| ASM-P1b-28 | P1b 트레이너 앱은 bodyChange 정책을 읽지 않고 모든 변화 칸을 '산정 준비 중'으로 둔다. P1b에 관리자가 정책을 활성화해도 표시는 같다 | §7 도입부, F-VIZ-01.3, ADR-009 | — |
| ASM-P1b-29 | M-05 비교 쌍: 자세는 이번 주 confirmed 기록 × 같은 회원·측면 방향 기준선, 신체조성·줄자는 이번 주 active 기록 × 같은 시리즈 직전 active 기록. 분모에서 `reference`·`beta` 지표는 뺀다. `noMdc`는 정책 없이 알 수 없으므로 빼지 않는다 | M-05, §7.4, §7.5 | 집계 정의만 바꾼다 |
| ASM-P1b-30 | admin_web 순수 검증기(TS) 테스트는 Node 22 `--experimental-strip-types`로 `node:test`에서 직접 import한다(새 npm 의존성 없음). 검증기 파일은 `@/` 경로 별칭을 쓰지 않는다 | ADR-017 원칙(새 의존성은 ADR 필요) | 검증기를 `.mjs`로 두고 TS 타입 선언을 분리 |
| ASM-P1b-31 | bodyChange 승인본은 모든 지표에 `mdcReference`(literature는 http(s) URL, inHouse는 연구 보고서 참조 문자열)를 요구하고, `improvementDirection`·`conditionKeys`가 카탈로그와 어긋나면 거부한다. 사진 계열 지표는 `protocolVersion`이 필수다 | §7.3.1, §7.6, §10.7 | 카탈로그 일치 검사를 경고로 낮춘다 |
| ASM-P1b-32 | AD-05 경로는 `admin_web/app/(console)/metric-catalog/page.tsx`, 사이드바 '설정' 구역 '지표 카탈로그'다 | §8.3, 기술 스파인 repoLayout | 경로만 바꾼다 |
| ASM-P1b-33 | Vision 관절 신뢰도 0.3 미만은 제안하지 않고 슬롯을 '지정 필요'로 둔다 | F-ASM-02.6 | 임계값은 DF-200 결과로 조정 |
| ASM-P1b-34 | UI 테스트·스냅샷의 상태 주입 인자는 `--preview-state=<화면>.<상태>`(예 `--preview-state=tr09.pendingPolicy`)다. 기존 `--preview-*` 관례(dfet:trainer_ios/DFETTrainer/App/DFETTrainerApp.swift:12, :35)를 잇는다 | AC-IA-01 | V1-07 규칙으로 맞춘다 |
| ASM-P1b-35 | `capturedAt`은 한 세션의 첫 셔터 시각이다(두 뷰 공통) | F-ASM-04.6, §9.2 '셔터 시각' | 뷰별 시각 필드 추가(PRD 개정) |
| ASM-P1b-36 | 회원 요청 사진 한 장 삭제 시 그 뷰의 랜드마크 좌표는 새 버전에 남긴다(지표 유지). ③ 철회와 달리 좌표 파기 대상이 아니다 | F-ASM-01.9, F-PRIV-02.3 | 좌표도 지우고 지표만 남긴다 |
| ASM-P1b-37 | 재검사 묶음은 같은 날 안에서만 이어진다. 첫 촬영 때 `retestGroupId`(UUID)를 만들고 '재검사 종료'나 날짜가 바뀌면 닫는다. 묶음 안 기록은 첫 기록만 기준선 후보다 | F-ASM-05.1, F-ASM-05.3 | — |
| ASM-P1b-38 | 편위 표 렌더러는 DesignSystem, 행 조립은 TrainerDomain에 둔다(G-P1b-5) | 기술 스파인 FeatureInsights | 모듈 의존을 바꾼다 |
| ASM-P1b-39 | 개발용 인물 사진은 ① 사진 라이선스가 확인된 공개 전신 이미지 ② 마네킹 ③ 소유자 본인 자기 촬영(저장소 커밋 금지, 테스트 후 삭제) 중에서 DF-200이 고른다. 회원 사진은 쓰지 않는다 | ADR-013 합성 데이터 원칙 | — |
| ASM-P1b-40 | iPad 멀티태스킹(Split View·Stage Manager) 중 카메라가 중단되면 TR-07은 '전체 화면에서 촬영할 수 있어요' 상태를 보인다. 멀티태스킹 카메라 사용(`isMultitaskingCameraAccessEnabled`)과 필요한 권한(entitlement)은 DF-200에서 확인한다 | NFR-12 | 확인 결과에 따라 TR-07 멀티태스킹 지원을 켠다 |
| ASM-P1b-41 | 체형 사진 다운로드 캐시 상한은 200MB이고 최근 사용 순으로 지운다(V1-07이 값을 정하기 전 기본값) | NFR-17 | 상수만 바꾼다 |
| ASM-P1b-42 | O 자동 불러오기는 선택 규칙(`ObjectiveCandidateSelector`, `SnapshotBuilder`)과 `ObjectiveSource` 프로토콜을 TrainerDomain에, LocalStore·원격 저장소를 읽는 구체 원천과 `SoapNoteStore` 구현을 SyncEngine에 둔다. 스파인의 TrainerDomain 의존(TrainerContracts만)과 P1a `SyncEngine/Stores/SoapNoteStoreImpl*` 배치를 따른다 | NFR-03, 기술 스파인 trainerModules, AS-23 | 별도 `ObjectiveLoading` 타깃을 만들고 같은 파일을 옮긴다 |
| ASM-P1b-43 | DF-209 수명주기 구현의 위치는 V1-00 K-10 결정 전까지 미정이다(G-P1b-9). 카드의 `TrainerDomain/Posture/DefaultAssessmentLifecycle.swift` 경로는 잠정이며, 결정에 따라 구현을 SyncEngine으로 옮기고 PostureMath를 TrainerDomain 프로토콜로 주입하거나 스파인에 SyncEngine→PostureMath 의존을 추가한다 | §7, 기술 스파인 trainerModules | 파일 위치와 import만 바꾼다 |
| ASM-P1b-44 | 리드 결정(교차 정합 v1.0.1): 패키지는 `trainer_app/Packages/TrainerCore`(순수, macOS `swift test`)와 `trainer_app/Packages/TrainerKit`(iOS 전용) 두 개다(R4). 에뮬레이터 시드는 `functions/scripts/dev/seed-emulator.js`·`functions/test/fixtures/emulator-seed.v1.json`·`demo-dfet`·`synthTrainerA`/`synthMember0001`/`SYNTHpending00000001`이다(R2). 가정 ID는 문서별 네임스페이스(`ASM-01-NN` 등)로 참조한다(R10) | V1-04 §6.2, V1-05 ASM-05-43, V1-00 | 경로·ID 문자열만 바꾼다 |

---

## 6 스토리 카드

### DF-200 Apple Vision 2D 랜드마크를 대상 iPad에서 정확도·좌우 매핑·지연으로 확인한다

| 항목 | 값 |
|---|---|
| Epic | EP-14 체형평가(정적 2D) |
| Type | spike |
| Phase | P1b(P1a 기간 선행) |
| Sprint | S08(MVP 계획, DEC-22, [03 MVP 계획](../03_RELEASE_AND_SPRINT_PLAN.md#mvp-계획dec-22)). 원래 계획: S12 (2026-12-14~12-18), 타임박스 2작업일 |
| Points | 2 (size/S) |
| Priority | must |
| Area | trainer-app |
| Labels | `type/spike` `area/trainer-app` `phase/P1b` `prio/must` `size/S` `flag/bodyAssessment` `agent/human` `needs-device-test` `scope/mvp` |
| Depends on | DF-008 |
| PRD refs | F-ASM-02.1, F-ASM-02.2, F-ASM-02.7, AC-ASM-02.3, Q-18, AS-12, NFR-12, NFR-15, RISK-02 |

**사용자 스토리**
소유자(개발자)로서, Apple Vision 2D 제안이 대상 iPad에서 해부학적 좌우를 맞게 돌려주는지, 한 장에 얼마나 걸리는지, 어떤 사진에서 실패하는지 먼저 확인하고 싶다. 그래야 DF-207·DF-208을 ADR-008 가정 위에서 되돌림 없이 시작할 수 있다.

**배경·맥락**
- PRD는 기본 엔진을 Apple Vision `VNDetectHumanBodyPoseRequest`로 **가정**한다(Q-18, 검증 시점 P1b 진입). ML Kit iOS SDK는 CocoaPods 전용이고 이득이 없다(F-ASM-02.1, ADR-008).
- Vision의 정규화 좌표는 **왼쪽 아래 원점**이다. 저장 규약은 왼쪽 위 원점이므로(§9.2) y 반전과 EXIF 방향 전달이 빠지면 좌우·상하가 틀어진다. 이 스파이크가 변환 규칙을 확정한다.
- 대상 iPad에서 제안 1장 2초 이하(NFR-15, 가설 목표)를 처음 측정한다.
- iPad 멀티태스킹 중 카메라 사용 가능 여부(ASM-P1b-40)도 함께 확인한다.

**질문과 성공 기준(스파이크)**

| # | 질문 | 성공 기준 | 결과 기록 위치 |
|---|---|---|---|
| Q1 | Vision `leftShoulder`·`leftEar`가 대상자의 왼쪽인가, 이미지 왼쪽인가 | 대상자 오른쪽 어깨에 표식이 있는 정면 사진에서 `rightShoulder` 제안의 왼쪽 위 원점 x가 0.5 미만(AC-ASM-02.3) | ADR-008 '검증 결과' 절 |
| Q2 | 좌표 변환(y 반전, `CGImagePropertyOrientation` 전달)이 세로·가로 촬영 모두에서 맞는가 | 4방향 촬영 사진 각각에서 귀 제안이 실제 귀 위치 ±3% 안 | 같은 절 |
| Q3 | 대상 iPad에서 제안 지연 | 20장 연속 실행 p95 ≤ 2초(os_signpost `LandmarkSuggest`) | V1-T09 기록 |
| Q4 | 측면 사진에서 반대쪽 귀가 제안되는가 | 측면 사진에서 보이는 쪽 귀만 신뢰도 0.3 이상인지 확인, 기준 확정(ASM-P1b-33) | ADR-008 |
| Q5 | Split View·Stage Manager에서 카메라가 동작하는가, 권한(entitlement)이 필요한가 | 동작 여부와 필요한 설정 목록 | ASM-P1b-40 갱신 |
| Q6 | 개발용 인물 사진을 무엇으로 쓸 것인가 | ASM-P1b-39의 세 가지 중 선택, 라이선스 기록 | `…/Fixtures/LICENSES.md` 초안 |

**수용 기준**
1. **AC-DF-200.1** (AC-ASM-02.3) Given 대상자 오른쪽 어깨에 표식을 붙인 정면 테스트 사진, When 스파이크 하네스가 Vision 요청을 실행하고 좌표를 왼쪽 위 원점으로 바꾸면, Then `rightShoulder` 제안 x < 0.5다. — 실기기·시뮬레이터
2. **AC-DF-200.2** (NFR-15) Given 소유자 보유 대상 iPad, When 같은 해상도 사진 20장에 제안을 실행하면, Then p50·p95 지연이 V1-T09 양식에 기록되고 p95가 2초를 넘으면 ADR-008 재검토 항목이 생긴다. — 실기기
3. **AC-DF-200.3** (Q-18) 스파이크 보고서(V1-T02)가 'ADR-008 유지' 또는 '재검토' 결론, 좌표 변환 규칙, 신뢰도 임계값, 멀티태스킹 결론을 담고 PR로 병합된다. — 문서

**구현 노트**
- 브랜치 `spike/DF-200-vision-pose`. 하네스는 `trainer_app/Spikes/VisionPoseSpike/`(앱 타깃에 링크하지 않는 별도 스킴)에 두고 **main에는 보고서와 픽스처만 병합**한다. 하네스 코드는 DF-207이 필요한 부분만 다시 쓴다.
- 확인할 API: `VNDetectHumanBodyPoseRequest`(revision 값 기록), `VNImageRequestHandler(cgImage:orientation:)`, `VNHumanBodyPoseObservation.recognizedPoints(.all)`, `VNRecognizedPoint.location`(왼쪽 아래 원점), `confidence`.
- 산출물: `docs/v1/adr/ADR-008-apple-vision-landmarks.md`에 '검증 결과(DF-200)' 절 추가, `docs/v1/spikes/DF-200-vision-pose.md`(V1-T02 [SPIKE_REPORT](../templates/SPIKE_REPORT.md)), 픽스처 후보 `trainer_app/Packages/TrainerKit/Tests/PostureVisionTests/Fixtures/`(라이선스 확인분만).

**테스트**
- 스파이크라 자동 테스트는 병합하지 않는다. 측정 기록은 [V1-T09](../templates/DEVICE_TEST_RECORD.md) 양식으로 남긴다.

**비고·가정**
- ASM-P1b-01(측면 방향 정의), ASM-P1b-33(신뢰도 0.3), ASM-P1b-39(사진 출처), ASM-P1b-40(멀티태스킹)을 이 스파이크 결과로 확정하거나 고친다.
- 결과가 '재검토'여도 P1b 일정은 유지한다. 엔진은 `LandmarkSuggester` 프로토콜 뒤에 있어(DF-207) 교체 비용이 제한된다.

**DoR 체크**
- [x] R1 추적 ID · [x] R2 질문·성공 기준·타임박스 · [x] R3 DF-008(P0) · [x] R4 2점 · [x] R5 라벨 · [x] R6 경로(Spikes/, docs) · [x] R7 영향 없음 · [x] R8 사진 출처 후보(ASM-P1b-39) · [ ] R9 지시서(소유자 직접 수행이므로 생략 가능) · [x] R10 needs-device-test

**에이전트 브리프**
소유자가 직접 수행하고 Claude는 하네스 초안만 돕는다. 먼저 `VisionPoseSpike` 스킴에 사진 한 장을 넣어 원시 좌표(왼쪽 아래 원점)와 변환 좌표를 나란히 출력하는 화면을 만든다. `TrainerKit` 타깃, `project.yml`의 앱 타깃, `contracts/`는 건드리지 않는다. 회원 사진과 실데이터는 쓰지 않는다.

### MVP 범위(DEC-22)

- MVP 스프린트: S08(원래 계획 S12). 상태: 할 일
- 왜 필요한가: Apple Vision 2D 랜드마크 가능성 확인. 체형 흐름의 자동 랜드마크 전제
- 지금 만든다: 합성·공개 샘플 사진(ASM-P1b-39, 실제 인물 사진 없음)으로 좌표 변환·좌우 매핑(Q1·Q2·Q4)을 iPad 시뮬레이터에서 확인한다. 시뮬레이터에서 `VNDetectHumanBodyPoseRequest`가 결과를 내지 않거나 오류면(시뮬레이터·CI 러너 제약), 같은 하네스(`trainer_app/Spikes/VisionPoseSpike/`, 트레이너 앱 아님)를 연결된 iPhone 15 Pro Max에서 돌려 Q1·Q2·Q4를 확인하고 결과를 스파이크 보고서에 적는다. iPhone 지연 값은 참고로만 적는다(Q3 판정은 iPad)
- MVP 뒤로 미룬다: 대상 iPad 실기기 측정(iPad 연결 뒤)
- Vision이 시뮬레이터에서 돌지 않을 때(대비책): DF-207 자동 테스트는 매퍼 단위 테스트(AC-DF-207.1~207.5·207.7, macOS)와 DF-200이 iPhone에서 기록한 관절 픽스처로 돌리고, AC-DF-207.6은 iPhone 하네스 기록으로 대신한다. 데모 체크리스트 A의 체형 흐름은 DF-208 '지정 필요'(AC-DF-208.2) 수동 지정으로 한다

---

### DF-201 PostureMath 산식과 posture-metrics.v1 벡터를 구현한다

| 항목 | 값 |
|---|---|
| Epic | EP-14 체형평가(정적 2D) |
| Type | story |
| Phase | P1b |
| Sprint | S09(MVP 계획, DEC-22, [03 MVP 계획](../03_RELEASE_AND_SPRINT_PLAN.md#mvp-계획dec-22)). 원래 계획: S14 (2026-12-28~12-31) |
| Points | 5 (size/L) |
| Priority | must |
| Area | trainer-app |
| Labels | `type/story` `area/trainer-app` `area/contracts` `phase/P1b` `prio/must` `size/L` `flag/bodyAssessment` `agent/claude` `scope/mvp` |
| Depends on | DF-003, DF-009 |
| PRD refs | F-ASM-02.5, F-ASM-03.1~03.6, F-ASM-04.2, AC-ASM-02.1(도메인), AC-ASM-02.4, AC-ASM-02.5, AC-ASM-03.1~03.4, AC-ASM-03.6, AC-ASM-04.1(도메인), 부록 A.1~A.3 |

**사용자 스토리**
트레이너로서, 내가 확정한 랜드마크로 계산한 CVA·어깨 높이차가 언제 다시 계산해도 소수 첫째 자리까지 같기를 원한다. 그래야 지난 기록과 오늘 기록을 같은 기준으로 비교할 수 있다.

**배경·맥락**
- 자세 지표 산출은 새로 구현한다(BodyPath·회원 앱에 해당 코드 없음, PRD §6.1 현재 상태).
- 흔한 결함은 정규화 좌표를 픽셀로 바꾸지 않고 각도를 재는 것이다. 가로세로 비율이 1이 아니면 각도가 틀린다(AC-ASM-03.4).
- 산식·좌표 규약·반올림은 [V1-09](../09_ALGORITHMS_SPEC.md)가 정본이고, 이 스토리가 그 규칙을 **실행 가능한 벡터**로 고정한다.

**수용 기준**
1. **AC-DF-201.1** (AC-ASM-03.1) Given 2000×2000 이미지, 회전 0, C7(1000,1000)·이주(1100,900)px에 해당하는 정규화 좌표, When `computeMetrics`, Then `craniovertebralAngle`=45.0, `side=none`. Given 견봉 좌(1200,800)·우(800,820)px, Then `shoulderTiltAngle`=2.9, `side=left`. — 단위(macOS)
2. **AC-DF-201.2** (AC-ASM-03.2) Given 똑바른 기준 좌표 Q와 Q를 이미지 중심 기준 −2° 돌려 만든 좌표 P, When P를 `imageRotationDeg=+2`로, Q를 `0`으로 계산하면, Then 두 결과가 반올림 후 같다. — 단위
3. **AC-DF-201.3** (AC-ASM-03.4) Given 1600×1200 이미지에서 C7(800,600)·이주(900,480)px, When 계산하면, Then CVA=50.2다(정규화 좌표를 그대로 쓰면 58.0이 나오므로 회귀를 잡는다). — 단위
4. **AC-DF-201.4** (AC-ASM-03.3, F-ASM-03.5) Given 어깨 계산에 쓰는 `acromionRight`가 `confirmed=false`, When 계산하면, Then `shoulderTiltAngle`만 `sourceGrade=photoAuto`이고 CVA는 `photoManual`이다. — 단위
5. **AC-DF-201.5** (AC-ASM-03.6) Given 기본 `MetricOptions`, When 계산하면, Then 결과에 `pelvicTiltFrontal`이 없다. `includePelvicTilt=true`이고 ASIS 한쪽이 없으면 결과에 없고(0이 아님) 오류도 아니다(F-ASM-04.2 '미산출'). — 단위
6. **AC-DF-201.6** (F-ASM-03.4) Given 좌우 높이 차가 1픽셀 미만, Then 값 0.0, `side=none`. Given 이주가 C7보다 아래, Then CVA는 음수(예 −26.6)다. — 단위
7. **AC-DF-201.7** (AC-ASM-02.1, AC-ASM-04.1 도메인) Given `c7`·`acromion*`·`asis*`(켰을 때) 가운데 하나가 `origin=auto`, When `confirmability`, Then `canConfirm=false`이고 `blockingLandmarks`에 그 코드가 있다. 모든 필수 랜드마크가 `confirmed=true`이고 수동 필수 코드가 `origin=manual`이면 `canConfirm=true`. — 단위
8. **AC-DF-201.8** (AC-ASM-02.4, AC-ASM-02.5) Given 저장 좌표(0~1)와 `imageRotationDeg`, When 같은 입력으로 두 번 계산하면, Then 값이 완전히 같고, 0~1 밖 좌표는 `PostureMathError.coordinateOutOfRange`로 거부된다. — 단위
9. **AC-DF-201.9** `contracts/vectors/posture-metrics.v1.json`의 모든 사례가 통과하고, 파일이 `contracts` CI 메타 스키마 검사를 통과한다. — CI

**구현 노트**
- 새 파일(`trainer_app/Packages/TrainerCore/Sources/PostureMath/`)
  - `Geometry/PixelGeometry.swift`: `toPixel(_:in:)`, `rotateAboutCenter(_:degrees:in:)`(반시계 양수, y 아래 좌표계: `x' = cx + dx·cosθ + dy·sinθ`, `y' = cy − dx·sinθ + dy·cosθ`)
  - `Metrics/PostureMetricCalculator.swift`: `computeMetrics(view:imageSize:imageRotationDeg:landmarks:options:) throws -> [PostureMetricResult]`
  - `Metrics/Rounding.swift`: `roundTenth(_:)`(ASM-P1b-03)
  - `Requirements/LandmarkRequirements.swift`: 지표별 필수 코드와 `manualRequired` 집합(부록 A.3)
  - `Requirements/Confirmability.swift`: `confirmability(views:options:) -> Confirmability`
- 타입(공개 API)

```swift
public struct NormalizedPoint: Codable, Hashable, Sendable { public var x: Double; public var y: Double }  // 0...1, 왼쪽 위 원점
public struct PixelSize: Sendable { public var width: Double; public var height: Double }
public enum LandmarkOrigin: String, Codable, Sendable { case auto, manual }
public struct LandmarkValue: Codable, Hashable, Sendable {
  public var code: LandmarkCode            // TrainerContracts 생성 enum(부록 A.3)
  public var point: NormalizedPoint
  public var origin: LandmarkOrigin
  public var confirmed: Bool
  public var suggested: SuggestedPoint?    // {x, y, confidence}
}
public struct MetricOptions: Sendable { public var includePelvicTilt = false }
public struct PostureMetricResult: Equatable, Sendable {
  public var metricCode: MetricCode; public var value: Double   // 0.1 반올림
  public var unit: String = "deg"; public var side: Side; public var sourceGrade: SourceGrade  // photoManual | photoAuto
}
public struct Confirmability: Equatable, Sendable {
  public var canConfirm: Bool
  public var missing: [LandmarkCode]            // 지정 필요
  public var blockingLandmarks: [LandmarkCode]  // auto로 남은 수동 필수, 미확정
}
public enum PostureMathError: Error { case coordinateOutOfRange(LandmarkCode), zeroImageSize }
```

- 산식은 PRD F-ASM-03.3 표 그대로다. CVA: `v = tragus − c7`(보정 후 픽셀), `atan2(−v.y, |v.x|)`. 기울기: `atan(|Δy|/|Δx|)`, `side`는 머리 기울기=낮은 쪽, 어깨·골반=높은 쪽(보정 후 y가 작은 쪽이 높다). 좌우는 해부학적 좌우(코드 접미사 기준).
- 측면 CVA의 이주 코드는 view로 정한다: `sagittalLeft`→`tragusLeft`, `sagittalRight`→`tragusRight`(ASM-P1b-01).
- 벡터 파일 `contracts/vectors/posture-metrics.v1.json`(새 파일)

```json
{
  "schemaVersion": 1,
  "rounding": "halfAwayFromZero",
  "cases": [
    {
      "id": "PM-01", "trace": ["AC-ASM-03.1"], "view": "sagittalLeft",
      "image": {"width": 2000, "height": 2000}, "imageRotationDeg": 0,
      "options": {"includePelvicTilt": false},
      "landmarks": [
        {"code": "c7", "x": 0.5, "y": 0.5, "origin": "manual", "confirmed": true},
        {"code": "tragusLeft", "x": 0.55, "y": 0.45, "origin": "manual", "confirmed": true}
      ],
      "expected": [{"metricCode": "craniovertebralAngle", "value": 45.0, "unit": "deg", "side": "none", "sourceGrade": "photoManual"}]
    },
    {
      "id": "PM-02", "trace": ["AC-ASM-03.1"], "view": "front",
      "image": {"width": 2000, "height": 2000}, "imageRotationDeg": 0,
      "landmarks": [
        {"code": "acromionLeft", "x": 0.6, "y": 0.4, "origin": "manual", "confirmed": true},
        {"code": "acromionRight", "x": 0.4, "y": 0.41, "origin": "manual", "confirmed": true}
      ],
      "expected": [{"metricCode": "shoulderTiltAngle", "value": 2.9, "unit": "deg", "side": "left", "sourceGrade": "photoManual"}]
    },
    {
      "id": "PM-03", "trace": ["AC-ASM-03.4"], "view": "sagittalLeft",
      "image": {"width": 1600, "height": 1200}, "imageRotationDeg": 0,
      "landmarks": [
        {"code": "c7", "x": 0.5, "y": 0.5, "origin": "manual", "confirmed": true},
        {"code": "tragusLeft", "x": 0.5625, "y": 0.4, "origin": "manual", "confirmed": true}
      ],
      "expected": [{"metricCode": "craniovertebralAngle", "value": 50.2, "unit": "deg", "side": "none", "sourceGrade": "photoManual"}]
    }
  ]
}
```

  나머지 사례(모두 포함 필수): PM-04 회전 동치(AC-ASM-03.2, 기대값 45.0), PM-05 음수 CVA(C7(1000,1000)·이주(1100,1050) → −26.6), PM-06 머리 기울기(귀 좌(1150,700)·우(850,690) → 1.9, `side=left`), PM-07 1px 미만 → 0.0·`none`, PM-08 미확정 견봉 → 어깨만 `photoAuto`, PM-09 골반 기본 꺼짐 → 결과 없음, PM-10 골반 켬·ASIS 한쪽 없음 → 결과 없음, PM-11 반올림 경계(`roundTenth` 직접 사례: 이진수로 정확히 표현되는 2.25 → 2.3, −2.25 → −2.3. 2.85처럼 이진 표현이 부정확한 값은 경계 사례로 쓰지 않는다).
- 테스트에서 벡터 읽기: `URL(fileURLWithPath: #filePath)`에서 저장소 루트를 찾아 `contracts/vectors/posture-metrics.v1.json`을 연다(생성기 변경 없음).
- `Package.swift`: `PostureMath` 타깃(의존 `TrainerContracts`, `TrainerDomain`), 플랫폼 iOS 17·macOS 14, `swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]`(순수 타깃 규칙).
- `schemas/contracts-meta.schema.json`에 `postureMetricVectors` 정의를 추가한다(DF-004 메타 스키마 확장).

**테스트**
- `PostureMathTests/PostureMetricVectorTests.swift`: `test_AC_ASM_03_1_cvaAndShoulderVector()`, `test_AC_ASM_03_2_rotationEquivalence()`, `test_AC_ASM_03_4_pixelConversionRegression()`, `test_AC_ASM_03_3_unconfirmedLandmarkMakesPhotoAuto()`, `test_AC_ASM_03_6_pelvicTiltOffByDefault()`, `test_AC_DF_201_9_allVectorCasesPass()`(벡터 전체 루프)
- `PostureMathTests/ConfirmabilityTests.swift`: `test_AC_ASM_02_1_manualRequiredAutoBlocksConfirm()`, `test_AC_ASM_04_1_allRequiredConfirmedAllowsConfirm()`, `test_F_ASM_04_2_pelvicUnavailableStillConfirmable()`
- `PostureMathTests/GeometryTests.swift`: `test_AC_ASM_02_4_outOfRangeRejected()`, `test_AC_ASM_02_5_recomputeIsDeterministic()`, `test_roundTenth_halfAwayFromZero()`
- CI: `contracts` job이 새 벡터 파일을 메타 스키마로 검증한다.

**비고·가정**
- ASM-P1b-01, ASM-P1b-02(회전 부호는 V1-09·합성 수평선 테스트로 고정), ASM-P1b-03.
- 좌표 변환 규칙이 DF-200 결과와 다르면 이 스토리 병합 전에 V1-09를 먼저 고친다.

**DoR 체크**
- [x] R1 · [x] R2(모든 AC 단위 테스트) · [x] R3 DF-003·DF-009(P0) · [x] R4 5점 · [x] R5 · [x] R6 `PostureMath/`, `contracts/vectors/`, `schemas/contracts-meta.schema.json` · [x] R7 `schema-change`(contracts) · [x] R8 벡터가 합성 데이터 · [x] R9 지시서 첨부 예정 · [x] R10 해당 없음

**에이전트 브리프**
먼저 `contracts/vectors/posture-metrics.v1.json`을 위 사례로 쓰고, 벡터를 읽어 실패하는 테스트를 만든 뒤 산식을 채운다(테스트 우선). V1-09와 PRD F-ASM-03.3 외의 산식을 만들지 않는다. `TrainerDomain`의 기존 타입을 바꾸지 말고, 필요한 enum(`LandmarkCode`, `MetricCode`, `Side`, `SourceGrade`)은 `TrainerContracts` 생성물을 쓴다. 생성물을 손으로 고치지 않는다. UI·Vision·Firebase 코드는 이 스토리 범위가 아니다.

### MVP 범위(DEC-22)

- MVP 스프린트: S09(원래 계획 S14). 상태: 할 일
- 왜 필요한가: 흐름 3: PostureMath 산식(CVA, 어깨 높이 차 등)
- 지금 만든다: posture-metrics.v1 산식과 벡터 테스트 전체
- MVP 뒤로 미룬다: 화면 강조는 CVA·어깨 높이 차만. 나머지 지표는 '참고'로만 표시(DEC-22)

---
### DF-203 스테이션 프로필과 회차 체크리스트 4항목을 구현한다

| 항목 | 값 |
|---|---|
| Epic | EP-14 체형평가(정적 2D) |
| Type | story |
| Phase | P1b |
| Sprint | S10(MVP 계획, DEC-22, [03 MVP 계획](../03_RELEASE_AND_SPRINT_PLAN.md#mvp-계획dec-22), 최소 조각만). 원래 계획: S15 (2027-01-04~01-08) |
| Points | 3 (size/M) |
| Priority | must |
| Area | trainer-app |
| Labels | `type/story` `area/trainer-app` `area/contracts` `phase/P1b` `prio/must` `size/M` `flag/bodyAssessment` `agent/claude` `schema-change` `scope/mvp` |
| Depends on | DF-014, DF-915 |
| PRD refs | F-ASM-01.2, F-ASM-01.3, AC-ASM-01.2(체크리스트), AC-ASM-01.3(기록 필드), §7.4, §9.2 `captureConditions`·`stationProfileId`, TR-07, TR-15 |

**사용자 스토리**
트레이너로서, 촬영 방·기기마다 카메라 높이와 거리를 한 번만 등록해 두고 회차마다 네 가지만 확인하고 싶다. 그래야 매번 같은 조건으로 찍었다는 기록이 남고 세션 흐름이 느려지지 않는다.

**배경·맥락**
- 촬영 조건이 다르면 비교 판정을 하지 않고 추이선을 끊는다(§7.4). 조건 기록이 없으면 끊을 근거도 없다.
- 프로토콜 수치(높이·거리·허용 범위·발 간격)는 소유자가 촬영 프로토콜 v1 문서로 정한다(DF-915, S13). 값은 코드 상수가 아니라 `contracts/posture-protocol.v1.json`에 둔다(ASM-P1b-05, G-P1b-1).
- 스테이션 프로필은 기기 로컬 데이터다. PRD에 서버 컬렉션이 없고, 문서에는 `stationProfileId`와 그 시점 값(`captureConditions.cameraHeightCm` 등)만 남긴다.

**수용 기준**
1. **AC-DF-203.1** (F-ASM-01.2) Given 프로필이 없는 기기, When TR-15 '스테이션 프로필'에서 이름·카메라 높이(cm)·거리(m)·발 표시 메모·배경/조명 메모를 저장하면, Then SwiftData `StationProfile`이 생기고 앱을 다시 켜도 남는다. 높이·거리가 프로토콜 범위를 벗어나면 저장 버튼이 비활성이고 범위 안내가 보인다. — 단위·UI
2. **AC-DF-203.2** (F-ASM-01.2) Given 프로필 1개 이상, When TR-07을 열면, Then 마지막에 쓴 프로필이 기본 선택되고 세션마다 값을 다시 입력하지 않는다. 프로필이 없으면 TR-07은 '스테이션 프로필 등록' 빈 상태와 TR-15 이동 버튼만 보인다. — UI
3. **AC-DF-203.3** (AC-ASM-01.2) Given 체크리스트 4항목(복장, 맨발, 머리카락·귀·마커, 회원 확인) 중 하나라도 미확인, When 셔터 게이트를 평가하면, Then `ShutterGate.canShoot == false`이고 미확인 항목 이름이 보인다. 새 세션(새 draft)을 시작하면 체크가 모두 풀린다. — 단위
4. **AC-DF-203.4** (AC-ASM-01.3) Given 체크리스트 완료와 프로필 선택, When `CaptureConditionsBuilder.build`를 호출하면, Then `clothing`(프로토콜 선택지 중 하나), `barefoot`, `markersPlaced`, `verbalConsentCheck`, `cameraHeightCm`, `cameraDistanceM`가 채워지고, `protocolVersion`은 `contracts/posture-protocol.v1.json`의 값(`"posture-v1"`)이다. `levelDeg`·`pitchDeg`는 DF-204가 셔터 시점에 채운다. — 단위
5. **AC-DF-203.5** 체크리스트 문구는 '편하게 서 주세요' 같은 표준 지시만 쓰고 자세를 고치라는 지시가 없다(F-ASM-01.3). 금지어 린트 통과. — CI

**구현 노트**
- `contracts/posture-protocol.v1.json`(새 파일, 값은 DF-915가 확정할 때까지 ASM-P1b-05 기본값):

```json
{
  "protocolVersion": "posture-v1",
  "levelToleranceDeg": 1.0,
  "pitchToleranceDeg": 2.0,
  "cameraHeightCm": {"min": 90, "max": 110},
  "cameraDistanceM": {"min": 2.5, "max": 3.5},
  "clothingOptions": ["fitted", "regular", "unknown"],
  "standardInstructionKey": "tr07.instruction.standard",
  "status": "draft-until-DF-915"
}
```

- `tool/contracts/generate.mjs`에 이 파일의 Swift 생성(`TrainerContracts/Generated/PostureProtocol.swift`, `public enum PostureProtocolV1 { static let protocolVersion = "posture-v1"; static let levelToleranceDeg = 1.0 … }`)과 Dart·JS 생성(DF-216·DF-224가 허용 범위 비교에 씀)을 추가한다. `--check`가 드리프트를 잡는다.
- LocalStore(`trainer_app/Packages/TrainerKit/Sources/LocalStore/Models/StationProfile.swift`): `@Model final class StationProfile { @Attribute(.unique) var id: String; var name: String; var cameraHeightCm: Double; var cameraDistanceM: Double; var footMarkNote: String; var backgroundNote: String; var lightingNote: String; var deviceModel: String; var protocolVersion: String; var lastUsedAt: Date?; var createdAt: Date; var updatedAt: Date }`. DF-014 스키마가 이 엔티티를 이미 가졌으면 재사용하고, 없으면 `VersionedSchema` 다음 버전과 `SchemaMigrationPlan` 경량 이관을 추가한다([V1-05 §12](../05_DATA_MODEL_AND_RULES.md)).
- `id`는 `UUID().uuidString`의 앞 16자(문서 필드 `stationProfileId` 1~64자). 서버로 보내지 않는 메모(발 표시·배경·조명)는 문서에 쓰지 않는다.
- TrainerDomain(`Sources/TrainerDomain/Posture/`): `CaptureChecklist`(4 Bool + `clothing: ClothingOption`), `ShutterGate`(체크리스트·수평 입력을 받아 `canShoot`, `reasons: [ShutterBlockReason]`), `CaptureConditionsBuilder`.
- UI: `FeatureSettings/StationProfiles/StationProfileListView.swift`, `StationProfileEditView.swift`(TR-15 행), `FeatureAssessment/Capture/CaptureChecklistView.swift`(TR-07 측면 패널, 4개 토글 + 복장 선택).
- 문구 키(초안)

| 키 | 문구 |
|---|---|
| `tr15.station.title` | 스테이션 프로필 |
| `tr15.station.outOfRange` | 프로토콜 범위({min}~{max}{unit}) 안으로 입력해 주세요 |
| `tr07.empty.noStation` | 스테이션 프로필을 먼저 등록해 주세요 |
| `tr07.checklist.clothing` | 복장: 몸 윤곽과 기준점이 보이는 옷 |
| `tr07.checklist.barefoot` | 맨발 |
| `tr07.checklist.markers` | 이주·귀가 보이고 C7·ASIS 마커를 붙였어요 |
| `tr07.checklist.verbalConsent` | 분리된 공간이고 촬영 직전 회원에게 구두로 다시 확인했어요 |
| `tr07.instruction.standard` | 편하게 서 주세요 |

- 접근성 식별자: `tr15.station.save`, `tr07.checklist.clothing`, `tr07.checklist.barefoot`, `tr07.checklist.markers`, `tr07.checklist.verbalConsent`.

**테스트**
- `TrainerDomainTests/ShutterGateTests.swift`: `test_AC_ASM_01_2_checklistIncompleteBlocksShutter()`, `test_AC_DF_203_3_newSessionResetsChecklist()`
- `TrainerDomainTests/CaptureConditionsBuilderTests.swift`: `test_AC_ASM_01_3_conditionsHaveRequiredKeys()`, `test_AC_DF_203_4_protocolVersionFromContracts()`
- `LocalStoreTests/StationProfileTests.swift`: `test_AC_DF_203_1_profilePersistsAcrossContainerReload()`, `test_AC_DF_203_1_outOfRangeRejected()`
- UI(`UITests/TR07ChecklistUITests.swift`, `--preview-state=tr07.noStation`): `test_AC_DF_203_2_emptyStateWhenNoProfile()`
- `contracts` CI: `posture-protocol.v1.json` 스키마 검증, `generate.mjs --check`.

**비고·가정**
- ASM-P1b-05. DF-915 전에는 `status: "draft-until-DF-915"`를 두고, 소유자가 값을 확정하면 같은 PR에서 `status`를 지우고 V1-09의 프로토콜 절을 갱신한다.
- 복장 enum은 V1-05 ASM-05-04와 같다.

**DoR 체크**
- [x] R1 · [x] R2 · [ ] R3 **DF-915(소유자, S13) 필요**: 미완료면 기본값으로 진행하고 값 확정 PR을 따로 둔다(코딩 비차단) · [x] R4 3점 · [x] R5 · [x] R6 `LocalStore/Models`, `TrainerDomain/Posture`, `FeatureSettings/StationProfiles`, `FeatureAssessment/Capture/CaptureChecklistView.swift`, `contracts/posture-protocol.v1.json`, `tool/contracts/generate.mjs` · [x] R7 `schema-change` · [x] R8 합성 프로필 · [x] R9 · [x] R10 해당 없음

**에이전트 브리프**
`contracts/posture-protocol.v1.json`과 생성기 변경을 첫 커밋으로 올리고 `generate.mjs --check`가 통과하는지 먼저 본다. 그다음 `ShutterGate`·`CaptureConditionsBuilder` 단위 테스트, 마지막에 화면을 만든다. 카메라·모션(DF-204)과 Firestore 저장(DF-206)은 건드리지 않는다. 프로토콜 수치를 코드에 하드코딩하지 않는다.

### MVP 범위(DEC-22)

- MVP 스프린트: S10(원래 계획 S15). 상태: 할 일. 카드 전체가 아니라 **최소 조각**(기본 스테이션 하나와 촬영 조건 기록)이다. 같은 스프린트의 DF-204보다 먼저 병합한다
- 왜 필요한가: `postureAssessments`는 `protocolVersion`(1~32자), `stationProfileId`(1~64자), `captureConditions`(키 8개)가 필수다([V1-05 §4.6](../05_DATA_MODEL_AND_RULES.md), 규칙 `validPostureBody`). DF-204 `AssessmentStore.createDraft(member:stationProfile:captureConditions:)`, DF-206 Outbox #1 create, DF-216 카메라 높이·거리 허용 범위(`PostureProtocolV1`)가 이 카드의 산출물을 쓴다. 없으면 체형 문서가 규칙에서 거부된다
- 지금 만든다:
  1. `contracts/posture-protocol.v1.json`: 구현 노트의 값 그대로(`"status": "draft-until-DF-915"`, DEC-21 ⑤ 초안 값)와 `tool/contracts/generate.mjs` 생성·`--check`. Swift `PostureProtocolV1`은 필수다. 생성기가 대상마다 같은 규칙으로 만들면 Dart·JS 생성물도 함께 두되 쓰는 곳(DF-216 Dart, DF-224)은 MVP 뒤다
  2. LocalStore `StationProfile`(V1-05 §12 필드). DF-014 스키마에 없으면 `VersionedSchema` 다음 버전과 경량 이관을 더한다
  3. `StationProfileStore.ensureDefault(trainerUid:)`: 프로필이 없으면 **기본 프로필 하나**를 만들고, 있으면 그대로 돌려준다(멱등, 앱 재시작 뒤에도 같은 문서). 기본값: `id = "default-v1"`(= 문서 `stationProfileId`), `name` = 문구 키 `tr07.station.default`('기본 스테이션(프로토콜 v1 초안)'), `cameraHeightCm = 100`, `cameraDistanceM = 3.0`(초안 범위 90~110cm·2.5~3.5m의 가운데), `protocolVersion = PostureProtocolV1.protocolVersion`(`"posture-v1"`). TR-07 진입 때 부르고 `lastUsedAt`을 갱신한다. 값은 생성물에서 계산하고 코드 상수로 두지 않는다
  4. TR-07 상단 한 줄 `tr07.station.defaultSummary`('기본 스테이션 · 카메라 높이 {height}cm · 거리 {distance}m'): 트레이너가 카메라를 이 값에 맞춰 둔다. 편집 버튼은 없다
  5. **복장 선택 한 줄**(`fitted`·`regular`·`unknown`, 미리 선택 없음, 회차마다 새로 고름. 문구 키 `tr07.checklist.clothing`과 선택지 3개). 체크리스트 네 항목 가운데 이것만 MVP에 넣는다. 복장은 §7.4 비교 키라 `unknown`만 쓰면 체형 기록끼리 모두 비교 불가가 되고(DF-216 AC-DF-216.2) TR-09 기준선 비교(AC-DF-210.5)와 TR-10 체형 추이(DF-215)가 점마다 끊긴다
  6. `CaptureConditionsBuilder.build(profile:clothing:)`(MVP 형태): `clothing`은 고른 값, `cameraHeightCm`·`cameraDistanceM`는 기본 프로필 값, `barefoot`·`markersPlaced`·`verbalConsentCheck`는 **`false`**(체크리스트가 없어 확인하지 않았다는 뜻. `true`로 쓰지 않는다). `levelDeg`·`pitchDeg`는 DF-204가 셔터 시점에 채운다. `ShutterGate`는 복장 미선택이면 `canShoot == false`(사유 `clothingNotSelected`)이고, 수평 조건은 DF-204가 더한다
  7. 테스트: `StationProfileTests`(`ensureDefault` 멱등·컨테이너 재적재 뒤 유지), `CaptureConditionsBuilderTests`(키가 규칙 `hasOnly` 목록 안, 세 불리언 `false`, `protocolVersion`이 생성물 값, 높이·거리가 생성물 범위 안), `ShutterGateTests`(복장 미선택 차단, 새 draft에서 복장 선택 초기화), contracts `--check`
- MVP 뒤로 미룬다: TR-15 스테이션 프로필 목록·편집·범위 검사(AC-DF-203.1), 여러 프로필 가운데 선택과 '스테이션 프로필 등록' 빈 상태(AC-DF-203.2. MVP에서는 기본 프로필이 늘 있어 빈 상태가 나오지 않는다), 체크리스트의 맨발·머리카락·귀·마커·회원 확인 세 토글과 그 셔터 차단(AC-DF-203.3의 나머지, [V1-09](../09_ALGORITHMS_SPEC.md)의 '셔터 시점에 모두 true'), AC-DF-203.4의 세 불리언 `true` 기록, 체크리스트 문구 린트(AC-DF-203.5 중 복장 문구 외). 실회원 전에는 체크리스트 전체가 필요하다
- MVP에서 기다리지 않는 의존: DF-915(소유자 수치 확정). DEC-21 ⑤대로 초안 값으로 진행하고, 확정되면 같은 PR에서 `status`를 지운다. 확정 범위가 초안과 달라 기본 프로필 값이 바뀌면 기본 ID를 `default-v2`로 올려 새 프로필을 만든다(기기에 이미 있는 `default-v1`과 그 ID로 기록된 문서의 뜻은 바뀌지 않는다)

---

### DF-207 PostureVision LandmarkSuggester(Vision 2D) 어댑터와 엔진 기록을 구현한다

| 항목 | 값 |
|---|---|
| Epic | EP-14 체형평가(정적 2D) |
| Type | story |
| Phase | P1b |
| Sprint | S11(MVP 계획, DEC-22, [03 MVP 계획](../03_RELEASE_AND_SPRINT_PLAN.md#mvp-계획dec-22)). 원래 계획: S15 (2027-01-04~01-08) — 레인 B 첫 작업(DF-204보다 먼저 병합) |
| Points | 3 (size/M) |
| Priority | must |
| Area | trainer-app |
| Labels | `type/story` `area/trainer-app` `phase/P1b` `prio/must` `size/M` `flag/bodyAssessment` `agent/claude` `scope/mvp` |
| Depends on | DF-200, DF-201 |
| PRD refs | F-ASM-02.1, F-ASM-02.2, F-ASM-02.5, F-ASM-02.6, F-ASM-02.7, AC-ASM-02.3, AC-ASM-01.3(`landmarkEngine`), NFR-15, Q-18, AS-12 |

**사용자 스토리**
트레이너로서, 사진을 찍으면 귀와 어깨 위치가 먼저 제안되기를 원한다. 그래야 C7·견봉·ASIS 같은 수동 필수 점에만 시간을 쓸 수 있다.

**배경·맥락**
- 제안은 확정 전까지 측정 근거가 아니다(`photoAuto`, F-ASM-02.2). 엔진 관절점('neck', 어깨 중심)은 C7·견봉과 정의가 다르므로 초기 위치로만 쓴다(부록 A.3).
- 엔진 정보는 모든 문서에 남기고, 엔진이 바뀌어도 기존 기록을 다시 계산하지 않는다(F-ASM-02.1). 이 구조를 위해 엔진을 프로토콜 뒤에 둔다(ADR-008).

**수용 기준**
1. **AC-DF-207.1** (AC-ASM-02.3, F-ASM-02.7) Given Vision 관절 사전(좌표는 왼쪽 아래 원점) `rightShoulder=(0.35, 0.72, conf 0.9)`, When `JointSuggestionMapper.map(view: .front, joints:)`, Then `acromionRight` 제안이 `(0.35, 0.28)`(y 반전)이고 x < 0.5다. — 단위(macOS)
2. **AC-DF-207.2** (부록 A.3) Given 정면, Then 제안 대상은 `earLeft`, `earRight`, `acromionLeft`, `acromionRight`뿐이다. Given `sagittalLeft`, Then `tragusLeft`만(`leftEar` 관절에서). `c7`, `asisLeft`, `asisRight`는 어떤 경우에도 제안하지 않는다. — 단위
3. **AC-DF-207.3** (F-ASM-02.6, ASM-P1b-33) Given 신뢰도 0.3 미만 관절 또는 사람 미검출, Then 해당 코드 제안이 없고 오류를 던지지 않으며, 결과 `LandmarkSuggestionResult.personDetected == false`로 화면이 '지정 필요'를 보일 수 있다. — 단위
4. **AC-DF-207.4** (AC-ASM-01.3, ASM-P1b-04) Given 아무 사진, When 제안을 실행하면, Then 결과에 `engine == LandmarkEngineInfo(name: "appleVision2D", version: "iOS<major.minor>-r<revision>")`가 있고 이 값이 draft의 `landmarkEngine`에 저장된다. — 단위(가짜 OS 버전 주입)
5. **AC-DF-207.5** (F-ASM-02.5) 제안은 `LandmarkValue(origin: .auto, confirmed: false, suggested: nil)`로 draft에 들어간다. 트레이너가 옮기면(DF-208) 원 위치가 `suggested {x, y, confidence}`로 보존된다 — 이 스토리는 `LandmarkValue.moved(to:)`가 `suggested`를 채우는지만 검증한다. — 단위
6. **AC-DF-207.6** (NFR-15) Given 픽스처 사진(DF-200 선정), When iPad 시뮬레이터에서 `VisionLandmarkSuggester.suggest`를 실행하면, Then 결과가 매퍼 기대와 같고, `os_signpost` 구간 `LandmarkSuggest`가 기록된다(지연 판정은 DF-223 실기기). — 시뮬레이터
7. **AC-DF-207.7** (F-ASM-02.1) 엔진 정보가 다른 기존 draft를 다시 열어도 제안을 다시 실행하지 않는다(뷰마다 1회, `suggestionsGeneratedAt` 로컬 표시). — 단위

**구현 노트**
- 프로토콜(`Sources/TrainerDomain/Posture/LandmarkSuggester.swift`)

```swift
public struct LandmarkEngineInfo: Codable, Equatable, Sendable { public var name: String; public var version: String }
public struct LandmarkSuggestion: Equatable, Sendable { public var code: LandmarkCode; public var point: NormalizedPoint; public var confidence: Double }
public struct LandmarkSuggestionResult: Sendable { public var engine: LandmarkEngineInfo; public var personDetected: Bool; public var suggestions: [LandmarkSuggestion] }
public protocol LandmarkSuggester: Sendable {
  func suggest(imageURL: URL, orientation: ImageOrientation, view: PostureView) async throws -> LandmarkSuggestionResult
}
```

- 순수 매퍼(`Sources/PostureMath/Mapping/JointSuggestionMapper.swift`): 입력 `[VisionJoint: RawJoint]`(`VisionJoint`는 `leftEar, rightEar, leftShoulder, rightShoulder, neck, leftHip, rightHip` 문자열 enum, `RawJoint {x, y, confidence}` 왼쪽 아래 원점). 매핑 표:

| view | Vision 관절 | 제안 코드 |
|---|---|---|
| `front` | `leftEar` / `rightEar` | `earLeft` / `earRight` |
| `front` | `leftShoulder` / `rightShoulder` | `acromionLeft` / `acromionRight`(초기 위치, 수동 필수) |
| `sagittalLeft` | `leftEar` | `tragusLeft` |
| `sagittalRight` | `rightEar` | `tragusRight` |

- Vision 어댑터(`Sources/PostureVision/Landmarks/VisionLandmarkSuggester.swift`): `VNImageRequestHandler(cgImage:orientation:)` + `VNDetectHumanBodyPoseRequest`, `request.revision` 기록, `observation.recognizedPoints(.all)` → `RawJoint`. 사진은 DF-205 정규화 뒤에는 방향이 `.up`이므로 `orientation`은 보통 `.up`이다. 사람 여러 명이면 `observations`의 가장 큰 경계 상자 하나만 쓴다(인물 1명 안내는 DF-204).
- 엔진 버전 문자열: `"iOS\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion).\(minorVersion)-r\(request.revision)"`. 테스트는 `OSVersionProvider` 주입으로 고정한다.
- 성능 계측: `OSSignposter(subsystem: "kr.co.dfet.trainer", category: "Posture")`의 `LandmarkSuggest` 구간. 로그에 좌표·이미지 경로를 남기지 않는다(NFR-10).
- DF-200 픽스처가 있으면 `Tests/PostureVisionTests/Fixtures/`에서 쓰고, 라이선스는 `LICENSES.md`.

**테스트**
- `PostureMathTests/JointSuggestionMapperTests.swift`: `test_AC_ASM_02_3_rightShoulderLandsOnImageLeft()`, `test_AC_DF_207_2_noSuggestionForManualOnlyCodes()`, `test_AC_DF_207_2_sagittalLeftUsesLeftEarAsTragus()`, `test_AC_DF_207_3_lowConfidenceDropped()`
- `TrainerDomainTests/LandmarkValueTests.swift`: `test_AC_DF_207_5_movePreservesSuggested()`
- `PostureVisionTests/VisionLandmarkSuggesterTests.swift`(시뮬레이터): `test_AC_DF_207_6_fixtureProducesMappedSuggestions()`, `test_AC_DF_207_4_engineVersionFormat()`
- `TrainerDomainTests/SuggestionOnceTests.swift`: `test_AC_DF_207_7_existingDraftNotReSuggested()`

**비고·가정**
- ASM-P1b-01, ASM-P1b-04, ASM-P1b-33. DF-200이 좌우 규칙을 다르게 확인하면 매핑 표만 바꾼다(벡터·산식은 해부학 코드 기준이라 영향 없음).

**DoR 체크**
- [x] R1 · [x] R2 · [x] R3 DF-200(S12), DF-201(S14) · [x] R4 3점 · [x] R5 · [x] R6 `TrainerDomain/Posture/LandmarkSuggester.swift`, `PostureMath/Mapping`, `PostureVision/Landmarks` · [x] R7 없음 · [x] R8 DF-200 픽스처 · [x] R9 · [x] R10 지연 판정은 DF-223으로 분리

**에이전트 브리프**
순수 매퍼와 단위 테스트를 먼저 병합(macOS `swift test`)한 뒤 Vision 어댑터를 붙인다. 매핑 표 밖 코드를 제안하지 않는다(C7·견봉 정의 차이 때문). `PostureVision/Capture/`(DF-204 영역)와 FeatureAssessment 화면은 건드리지 않는다. Vision 좌표의 원점 차이를 매퍼 안에서만 처리하고 다른 곳에 y 반전을 흩뜨리지 않는다.

### MVP 범위(DEC-22)

- MVP 스프린트: S11(원래 계획 S15). 상태: 할 일
- 왜 필요한가: 흐름 3: Vision 2D 랜드마크 어댑터
- 지금 만든다: 카드 전체 범위
- 대비책(DF-200 결과에 따름): 시뮬레이터에서 Vision이 결과를 내지 않으면 AC-DF-207.6을 DF-200 iPhone 하네스 기록으로 대신하고, `VisionLandmarkSuggester`는 사람 미검출(`personDetected=false`)로 끝나 화면이 '지정 필요'를 보인다(AC-DF-207.3). 테스트를 skip하지 않고 조건을 PR에 적는다

---

### DF-216 conditionKey 비교와 seriesBreak·seriesKey 분할을 Swift·Dart 공통 규칙으로 구현한다

| 항목 | 값 |
|---|---|
| Epic | EP-15 O 자동 불러오기·비교·추이 |
| Type | story |
| Phase | P1b |
| Sprint | S11(MVP 계획, DEC-22, [03 MVP 계획](../03_RELEASE_AND_SPRINT_PLAN.md#mvp-계획dec-22)). 원래 계획: S15 (2027-01-04~01-08) |
| Points | 3 (size/M) |
| Priority | must |
| Area | contracts |
| Labels | `type/story` `area/contracts` `area/trainer-app` `area/member-app` `phase/P1b` `prio/must` `size/M` `agent/claude` `schema-change` `scope/mvp` |
| Depends on | DF-201, DF-003 |
| PRD refs | §7.4, F-VIZ-03.3, F-VIZ-03.2, F-BC-03.4, C-02, AC-C-02.1, ADR-009 |

**사용자 스토리**
트레이너로서, 기기·프로토콜·측정 조건이 바뀐 지점에서 추이선이 끊기고 이유가 적혀 있기를 원한다. 그래야 조건 차이를 변화로 오해하지 않는다.

**배경·맥락**
- 두 기록은 조건 키가 **모두 같을 때만** 비교한다. 하나라도 다르거나 `unknown`이면 판정 불가이고 그 지점에서 선을 끊는다(§7.4).
- 이 규칙은 **표시 규칙**이라 클라이언트에 둔다. 변화 판정(MDC)은 서버 한 곳(P3)이다(ADR-009). 그래서 이 모듈에는 MDC 상수와 판정 결과 enum 대입이 있으면 안 된다.
- 같은 규칙을 Swift(TR-10·TR-11 추이), Dart(P2 회원 리포트), JS(DF-224 M-05 집계)가 쓰므로 공유 벡터로 검증한다(ASM-P1b-19).

**수용 기준**
1. **AC-DF-216.1** (AC-VIZ-03.1 도메인) Given `bodyFatPercent` 3점(같은 `source`, `fasting=yes`, `timeOfDayBand=morning`)이고 3번째만 `deviceModel`이 다름, When `segment`, Then 세그먼트 2개, 두 번째 세그먼트 `breakBefore.reason == .deviceChanged`, `detail == .device(from:"InBody 570", to:"InBody 270")`. — 단위(Swift·Dart)
2. **AC-DF-216.2** (§7.4) Given 두 점 모두 `fasting=unknown`, Then `conditionMismatch`로 끊긴다(`unknown`은 같은 값이어도 불일치). — 단위
3. **AC-DF-216.3** (§7.5 순서) Given 프로토콜과 기기가 함께 바뀜, Then 사유는 `protocolChanged` 하나다(순서: 프로토콜 → 기기 → 조건). — 단위
4. **AC-DF-216.4** (§7.4, ASM-P1b-18) Given 자세 두 기록의 카메라 높이 98cm·104cm(허용 범위 90~110 안), 다른 키 동일, Then 끊지 않는다. 한쪽이 범위 밖(115)이면 `conditionMismatch`. `view`가 `sagittalLeft`→`sagittalRight`면 `conditionMismatch`(T06 대응). — 단위
5. **AC-DF-216.5** (C-02, AC-C-02.1, F-VIZ-03.2) Given 같은 `metricCode`에 `tape`와 `observedSection`이 섞인 입력, Then 서로 다른 시리즈 식별자로 나뉘고 하나의 세그먼트로 이어지지 않는다. 좌우(`side`)가 다른 둘레도 별도 시리즈다. — 단위
6. **AC-DF-216.6** (C-04) 누락 회차(값 없음)는 점을 만들지 않고 보간값이 생기지 않는다(입력에 없는 점은 출력에도 없다). — 단위
7. **AC-DF-216.7** `contracts/vectors/series-break.v1.json`의 모든 사례를 Swift(`swift test`)와 Dart(`flutter test`)가 통과한다. — CI
8. **AC-DF-216.8** (ADR-009) `tool/lint/static-guards.sh`에 추가한 검사: `TrainerDomain/Series/`와 `lib/utils/series_segmenter.dart`에 `mdc`, `meaningfulImprovement`, `meaningfulDecline`, `withinError` 문자열 0건. — CI

**구현 노트**
- 벡터 `contracts/vectors/series-break.v1.json`(새 파일, ASM-P1b-19)

```json
{
  "schemaVersion": 1,
  "toleranceSource": "contracts/posture-protocol.v1.json",
  "cases": [
    {
      "id": "SB-01", "trace": ["AC-VIZ-03.1"], "family": "bodyComposition",
      "points": [
        {"refId": "SYNTHbc01", "metricCode": "bodyFatPercent", "sourceGrade": "device", "side": "none", "value": 25.0, "measuredAt": "2027-01-04T07:30:00+09:00",
         "conditions": {"source": "manualEntry", "deviceKey": "InBody 570", "fasting": "yes", "timeOfDayBand": "morning"}},
        {"refId": "SYNTHbc02", "metricCode": "bodyFatPercent", "sourceGrade": "device", "side": "none", "value": 24.6, "measuredAt": "2027-02-03T07:40:00+09:00",
         "conditions": {"source": "manualEntry", "deviceKey": "InBody 570", "fasting": "yes", "timeOfDayBand": "morning"}},
        {"refId": "SYNTHbc03", "metricCode": "bodyFatPercent", "sourceGrade": "device", "side": "none", "value": 22.0, "measuredAt": "2027-02-05T07:35:00+09:00",
         "conditions": {"source": "manualEntry", "deviceKey": "InBody 270", "fasting": "yes", "timeOfDayBand": "morning"}}
      ],
      "expected": {"series": [{"segments": [["SYNTHbc01", "SYNTHbc02"], ["SYNTHbc03"]], "breaks": [{"beforeRefId": "SYNTHbc03", "reason": "deviceChanged"}]}]}
    }
  ]
}
```

  필수 사례: SB-01 기기 변경, SB-02 공복 unknown, SB-03 프로토콜+기기 동시(프로토콜만), SB-04 카메라 높이 범위 안(끊김 없음), SB-05 범위 밖, SB-06 측면 방향 변경, SB-07 복장 변경, SB-08 줄자 `protocolId` 변경, SB-09 tape·observedSection 분리, SB-10 좌우 분리, SB-11 painNrs(조건 없음, 끊김 없음), SB-12 누락 회차, SB-13 `timeOfDayBand` 변경, SB-14 날짜 역순 입력(정렬 후 분할).
- Swift(`Sources/TrainerDomain/Series/`)

```swift
public enum SeriesFamily: String, Codable, Sendable { case posture, bodyComposition, tape, lidar, pain }
public struct ConditionSnapshot: Codable, Equatable, Sendable {
  public var protocolVersion: String?; public var protocolId: String?; public var algorithmVersion: String?
  public var view: String?; public var clothing: String?; public var cameraHeightCm: Double?; public var cameraDistanceM: Double?
  public var deviceKey: String?; public var fasting: String?; public var timeOfDayBand: String?; public var source: String?
}
public struct SeriesPoint: Equatable, Sendable {
  public var refId: String; public var metricCode: MetricCode; public var sourceGrade: SourceGrade; public var side: Side
  public var value: Double; public var unit: String; public var measuredAt: Date; public var family: SeriesFamily; public var conditions: ConditionSnapshot
}
public struct SeriesIdentity: Hashable, Sendable { public var metricCode: MetricCode; public var sourceGrade: SourceGrade; public var side: Side; public var source: String? }
public enum BreakReason: String, Codable, Sendable { case protocolChanged, deviceChanged, conditionMismatch }
public enum BreakDetail: Equatable, Sendable { case device(from: String, to: String), protocolVersion(from: String, to: String), condition(key: String) }
public struct SeriesSegment: Equatable, Sendable { public var id: String; public var points: [SeriesPoint]; public var breakBefore: (reason: BreakReason, detail: BreakDetail)? }
public enum SeriesSegmenter {
  public static func identity(of p: SeriesPoint) -> SeriesIdentity
  public static func compare(_ a: ConditionSnapshot, _ b: ConditionSnapshot, family: SeriesFamily) -> (BreakReason, BreakDetail)?
  public static func segment(_ points: [SeriesPoint]) -> [SeriesIdentity: [SeriesSegment]]
  public static func seriesKey(identity: SeriesIdentity, firstPointConditions: ConditionSnapshot) -> String  // SHA-256 hex 앞 16자, P2 highlights용
}
```

  (`breakBefore`는 Equatable을 위해 실제 구현에서 별도 struct `SeriesBreak`로 둔다.) 가족별 비교 키는 §7.4 표 그대로다: 자세 `protocolVersion`·`view`·`clothing`·카메라 높이/거리(허용 범위)·`deviceKey=device.model`, 신체조성 `fasting`·`timeOfDayBand`·`deviceKey=deviceModel`(시리즈 구분에 `source`), 줄자 `protocolId`·`protocolVersion`, LiDAR 줄자 키 + `algorithmVersion`·`deviceKey`, 통증 없음. 허용 범위는 `PostureProtocolV1`(DF-203 생성물).
- Dart(ASM-P1b-20): `lib/models/series_point.dart`(`SeriesPoint`, `ConditionSnapshot`, `SeriesSegment`, `BreakReason`), `lib/utils/series_segmenter.dart`(`SeriesSegmenter.segment` 등 같은 이름), 상수는 `lib/contracts/generated/`의 생성물을 쓴다. 테스트는 `test/series_segmenter_test.dart`가 `File('contracts/vectors/series-break.v1.json')`을 읽는다(flutter test 작업 디렉터리는 저장소 루트).
- `seriesKey`는 P1b에서 저장하지 않는다. P2 `createMemberSummary`가 쓰도록 규칙만 고정한다(해시 입력 문자열 규칙은 V1-09).
- static-guards 추가 줄(`tool/lint/static-guards.sh`): `rg -n 'mdc|meaningfulImprovement|meaningfulDecline|withinError' trainer_app/Packages/TrainerCore/Sources/TrainerDomain/Series lib/utils/series_segmenter.dart && exit 1`.

**테스트**
- `TrainerDomainTests/SeriesSegmenterVectorTests.swift`: `test_AC_DF_216_7_allSeriesBreakVectorsPass()`, `test_AC_VIZ_03_1_deviceChangeBreaks()`, `test_AC_DF_216_2_unknownFastingAlwaysBreaks()`, `test_AC_DF_216_3_protocolReasonWins()`, `test_AC_DF_216_4_cameraToleranceWithinRange()`, `test_AC_C_02_1_tapeAndObservedSectionSeparated()`, `test_AC_C_04_1_missingPointNotInterpolated()`
- `test/series_segmenter_test.dart`: `test('AC-DF-216.7 series-break 벡터 전체 통과', …)`, `test('AC-VIZ-03.1 기기 변경 끊김', …)`
- CI `static-guards`: AC-DF-216.8

**비고·가정**
- ASM-P1b-17(기울기 부호 표현은 차트 쪽, DF-215), ASM-P1b-18, ASM-P1b-19, ASM-P1b-20.
- 회원 앱 화면은 P2라 이 스토리는 Dart 규칙과 테스트만 추가하고 화면은 바꾸지 않는다.

**DoR 체크**
- [x] R1 · [x] R2 · [x] R3 DF-201(S14), DF-003(P0), DF-203(허용 범위 생성물; 같은 스프린트 앞순서, 없으면 테스트에서 상수 주입) · [x] R4 3점 · [x] R5 · [x] R6 `TrainerDomain/Series`, `lib/models/series_point.dart`, `lib/utils/series_segmenter.dart`, `test/`, `contracts/vectors/`, `tool/lint/static-guards.sh` · [x] R7 `schema-change` · [x] R8 벡터 · [x] R9 · [x] R10 해당 없음

**에이전트 브리프**
벡터 JSON부터 쓰고 Swift·Dart 두 구현이 같은 벡터를 읽게 한다. 비교 순서(프로토콜 → 기기 → 조건)와 `unknown` 규칙을 벡터로 먼저 못 박는다. MDC·판정 결과·정책 코드를 이 모듈에 넣지 않는다(정적 검사가 실패한다). 차트 뷰(DF-215)와 functions(DF-224)는 건드리지 않는다.

### MVP 범위(DEC-22)

- MVP 스프린트: S11(원래 계획 S15). 상태: 할 일. S10에서 옮겼다: 같은 S10에 DF-203 MVP 조각이 들어오며 약속 한도(18)를 넘지 않게 하고, 허용 범위 생성물(`PostureProtocolV1`, DF-203)이 먼저 병합되게 한다
- 왜 필요한가: 흐름 4: conditionKey 비교와 seriesBreak 분할(추이 차트의 끊김 규칙)
- 지금 만든다: Swift 구현과 공통 벡터 테스트
- MVP 뒤로 미룬다: Dart 구현(회원 앱, P2)

---

### DF-204 TR-07 촬영(정면·측면, roll·pitch 게이트, 인물·조명 검출, 동의 ②③ 게이트)을 구현한다

| 항목 | 값 |
|---|---|
| Epic | EP-14 체형평가(정적 2D) |
| Type | story |
| Phase | P1b |
| Sprint | S10(MVP 계획, DEC-22, [03 MVP 계획](../03_RELEASE_AND_SPRINT_PLAN.md#mvp-계획dec-22)). 원래 계획: S15 (2027-01-04~01-08) — 레인 A 두 번째(DF-203 뒤, DF-207 병합 뒤) |
| Points | 5 (size/L) |
| Priority | must |
| Area | trainer-app |
| Labels | `type/story` `area/trainer-app` `area/privacy` `phase/P1b` `prio/must` `size/L` `flag/bodyAssessment` `agent/claude` `privacy-impact` `needs-device-test` `scope/mvp` |
| Depends on | DF-203, DF-110 |
| PRD refs | F-ASM-01.1, F-ASM-01.4, F-ASM-01.5, F-ASM-01.6(뷰별 재촬영 UI), F-ASM-01.8(동의 서버 확인 조건), AC-ASM-01.1, AC-ASM-01.2, AC-ASM-01.3, AC-PRIV-01.2(클라이언트), AC-IA-02, M-04a, TR-07, NFR-12 |

**사용자 스토리**
트레이너로서, 수평이 맞을 때만 셔터가 눌리고 정면·측면 두 장을 1~2분 안에 찍고 싶다. 그래야 기울어진 사진으로 각도를 재는 일이 없고 회원을 오래 세워 두지 않는다.

**배경·맥락**
- 측면 CVA는 카메라 상하 기울기에 따른 원근 왜곡 영향을 받는다. 그래서 roll(`levelDeg`)과 **pitch**(`pitchDeg`)가 허용 범위를 벗어나면 셔터를 막는다(F-ASM-01.4).
- 동의 ②와 ③이 **모두** 서버에서 확인돼야 진입한다. 없으면 로컬 사진도 만들지 않는다(F-ASM-01.5, F-PRIV-03.7). 인물 1명·조명은 안내이며 셔터를 막지 않는다(PRD는 roll·pitch만 차단 조건으로 둔다).
- 조명·준비 판정 개념은 회원 앱 코드(dfet:lib/services/pose_detection_service.dart:164-205 밝기 계산, :328-361 준비 판정)를 참고해 네이티브로 다시 만든다(코드 이식 없음).

**수용 기준**
1. **AC-DF-204.1** (AC-ASM-01.1, AC-PRIV-01.2) Given `synthMember0002`(②만), When TR-03에서 '체형 촬영'을 누르면, Then TR-07은 '동의 필요: 신체 촬영(③) · 현장 동의 열기'만 보이고 카메라 세션이 시작되지 않으며, 앱 컨테이너의 `Posture/` 아래에 파일이 0개다. 동의가 로컬 캡처만 있고 서버 미확인이면 '동의 확인 대기'로 같은 차단. — UI·단위
2. **AC-DF-204.2** (AC-ASM-01.2) Given 체크리스트 완료, When `levelDeg=1.4`(허용 ±1.0) 또는 `pitchDeg=−2.6`(허용 ±2.0), Then 셔터가 비활성이고 수평계가 벗어난 축과 값을 보인다. 둘 다 범위 안이면 활성. — 단위(`ShutterGate`) + UI
3. **AC-DF-204.3** (F-ASM-01.1) 한 세션은 `front` 1장과 측면 1장(`sagittalLeft` 또는 `sagittalRight`)이다. 측면 방향 기본값은 그 회원의 현재 기준선 문서의 측면 방향이고, 기준선이 없으면 트레이너가 고른다. 다른 방향을 고르면 '기준선과 방향이 달라 비교하지 않아요' 안내가 보인다. — 단위·UI
4. **AC-DF-204.4** (F-ASM-01.6) 확정 전에는 뷰마다 '다시 찍기'가 있다. 다시 찍으면 이전 로컬 파일이 지워지고 새 파일로 바뀐다(Storage 정리는 DF-205·DF-206). — 단위
5. **AC-DF-204.5** (AC-ASM-01.3) 두 장이 찍히면 로컬 draft(`LocalAssessmentDraft`)에 `capturedAt`(첫 셔터, ASM-P1b-35), `protocolVersion`, `stationProfileId`, `captureConditions`(DF-203 값 + 셔터 시점 `levelDeg`·`pitchDeg`), `device {model: 하드웨어 식별자 예 "iPad14,5", osVersion}`, 뷰별 `imageRotationDeg`, `landmarkEngine`(DF-207 결과)가 모두 있다. — 단위
6. **AC-DF-204.6** (AC-IA-02) Given `bodyAssessment=false`, Then TR-03·TR-09·사이드바 어디에도 TR-07 진입점이 없다. — UI(`--preview-state=flags.allOff`)
7. **AC-DF-204.7** (M-04a) 게이트 통과 후 미리보기가 뜨면 `posture_capture_started`, 두 장 저장 시 `posture_capture_done{views_count:2, retake_count_band, elapsed_band}`가 DebugSink에 한 번씩 기록되고 속성은 허용 목록뿐이다. — 단위
8. **AC-DF-204.8** (NFR-12, ASM-P1b-40) Split View에서 카메라가 중단되면 '전체 화면에서 촬영할 수 있어요'와 재개 안내가 보이고 이미 찍은 사진·체크리스트는 유지된다. 회전해도 촬영 상태가 유지된다. — UI(시뮬레이터 인터럽트 주입) + DF-223 실기기
9. **AC-DF-204.9** 사진은 카메라 롤에 저장되지 않는다: `FeatureAssessment`·`PostureVision`에 `PHPhotoLibrary`, `UIImageWriteToSavedPhotosAlbum` 0건(static-guards 추가). — CI

**구현 노트**
- 촬영(`Sources/PostureVision/Capture/`)
  - `CaptureSessionController.swift`: `AVCaptureSession`(`.photo` 프리셋), 후면 광각 `AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)`, `AVCapturePhotoOutput`. 방향은 `AVCaptureDevice.RotationCoordinator`(iOS 17)의 `videoRotationAngleForHorizonLevelCapture`를 캡처 연결에 적용한다. 인터럽트는 `AVCaptureSession.wasInterruptedNotification`의 `.videoDeviceNotAvailableWithMultipleForegroundApps`를 상태로 올린다. `isMultitaskingCameraAccessSupported`면 `isMultitaskingCameraAccessEnabled = true`(DF-200 결론에 따름).
  - `MotionLevelMonitor.swift`: `CMMotionManager.deviceMotion` 30Hz, 중력 벡터로 roll·pitch(도) 계산 → `AsyncStream<LevelReading>`. 계산식과 부호는 V1-09(ASM-P1b-02). 모션 권한 문구는 필요 없다(device motion).
  - `FrameQualityAnalyzer.swift`: 미리보기 프레임을 2~5fps로 샘플해 `VNDetectHumanRectanglesRequest`로 인물 수, Y 평균으로 조명(0~1)을 낸다. 안내 전용.
- 도메인: `ShutterGate`(DF-203)에 `LevelReading`과 프로토콜 허용값을 넣는다. `AssessmentStore.createDraft(member:stationProfile:captureConditions:)`(V1-06 계약)는 동의 게이트(§4.3)를 다시 확인하고 로컬 draft만 만든다. 원격 문서 생성은 DF-206.
- LocalStore: `LocalAssessmentDraft`(`id`, `memberKey`, `status`(draft·pendingConfirm·confirmed·voided 로컬 거울), `views: [LocalViewCapture{view, localPhotoFile, imageRotationDeg, landmarks JSON, suggestionsGeneratedAt}]`, `captureConditionsJSON`, `stationProfileId`, `protocolVersion`, `capturedAt`, `deviceModel`, `osVersion`, `landmarkEngineJSON`, `retestGroupId?`, `supersedesId?`, `syncState`). 파일 경로 `Application Support/TrainerKit/Posture/{assessmentId}/{view}.jpg`, `NSFileProtectionComplete`, `isExcludedFromBackup`(DF-014 `FileStore` 헬퍼).
- 제안 실행: 두 번째 사진 저장 직후 뷰별 `LandmarkSuggester.suggest`를 백그라운드로 돌린다(UI를 막지 않음). 결과는 draft에 auto 랜드마크로 저장.
- 화면(`Sources/FeatureAssessment/Capture/`): `CaptureView.swift`(TR-07, 전체 화면 커버), `LevelIndicatorView.swift`(roll·pitch 두 축, 범위 밖은 문구+글리프, 색만으로 구분하지 않음), `CaptureGateView.swift`(동의 없음·동의 확인 대기·스테이션 없음·플래그 꺼짐), `ViewShotStrip.swift`(정면·측면 썸네일과 다시 찍기). `/// TR-07` 문서 주석.
- `Info.plist`: `NSCameraUsageDescription` = "회원 자세 평가와 세션 기록을 위해 카메라를 사용합니다."(기존 문구 재사용, dfet:trainer_ios/DFETTrainer/Info.plist:34-35).
- 문구 키(초안)

| 키 | 문구 |
|---|---|
| `tr07.title` | 체형 촬영 |
| `tr07.gate.consentMissing` | 동의 필요: {missing} · 현장 동의 열기 |
| `tr07.gate.awaitingConsent` | 동의 확인 대기 · 연결되면 촬영할 수 있어요 |
| `tr07.level.outOfRange` | 기기를 수평으로 맞춰 주세요 (좌우 {roll}°, 앞뒤 {pitch}°) |
| `tr07.detect.personCount` | 한 사람만 화면에 들어오게 해 주세요 |
| `tr07.detect.lowLight` | 조명이 어두워요 |
| `tr07.side.mismatchBaseline` | 기준선과 방향이 달라 비교하지 않아요 |
| `tr07.retake` | 다시 찍기 |
| `tr07.interrupted.multitasking` | 전체 화면에서 촬영할 수 있어요 |

- 접근성 식별자: `tr07.shutter`, `tr07.retake.front`, `tr07.retake.sagittal`, `tr07.side.picker`, `tr07.level.indicator`, `tr07.gate.openConsent`. VoiceOver: 수평계는 "좌우 1.4도, 허용 범위 밖" 식으로 읽는다.

**테스트**
- `TrainerDomainTests/ShutterGateLevelTests.swift`: `test_AC_ASM_01_2_rollOutOfRangeBlocks()`, `test_AC_ASM_01_2_pitchOutOfRangeBlocks()`, `test_AC_DF_204_2_bothInRangeAllows()`
- `TrainerDomainTests/AssessmentCreateGateTests.swift`: `test_AC_ASM_01_1_missingBodyImagingCreatesNoFiles()`(가짜 ConsentService, 임시 컨테이너 파일 수 0), `test_AC_DF_204_1_awaitingConsentBlocks()`, `test_AC_DF_204_3_sideDefaultsToBaselineView()`, `test_AC_ASM_01_3_draftHasProtocolLevelPitchDeviceEngine()`
- `TrainerAnalyticsTests/PostureCaptureEventsTests.swift`: `test_AC_DF_204_7_captureEventsAllowlistedOnly()`
- UI(`UITests/TR07CaptureUITests.swift`): `test_AC_IA_02_noCaptureEntryWhenFlagOff()`(`--preview-state=flags.allOff`), `test_AC_DF_204_1_consentGateShown()`(`--preview-state=tr07.consentMissing`), `test_AC_DF_204_8_multitaskingInterruptionState()`(`--preview-state=tr07.interrupted`)
- static-guards: 카메라 롤 API 0건(AC-DF-204.9)
- 실기기 확인(roll·pitch 실측, 4방향, Split View)은 DF-223 기록으로 증빙한다.

**비고·가정**
- ASM-P1b-02, ASM-P1b-05, ASM-P1b-35, ASM-P1b-40.
- 시뮬레이터에는 카메라가 없으므로 `CaptureSessionController`는 프로토콜 `PhotoCapturing` 뒤에 두고 `--preview-*`에서 픽스처 사진을 돌려주는 가짜를 쓴다.

**DoR 체크**
- [x] R1 · [x] R2 · [x] R3 DF-203(같은 스프린트 앞순서), DF-110(P1a), DF-207(같은 스프린트 레인 B 선병합) · [x] R4 5점 · [x] R5 · [x] R6 `PostureVision/Capture`, `FeatureAssessment/Capture`, `LocalStore/Models/LocalAssessmentDraft.swift`, `App/Info.plist` · [x] R7 `privacy-impact` · [x] R8 합성 회원 3종·픽스처 사진 · [x] R9 · [x] R10 `needs-device-test`(DF-223)

**에이전트 브리프**
`ShutterGate`와 동의 게이트 단위 테스트를 먼저 통과시키고, 카메라는 `PhotoCapturing` 가짜로 화면을 완성한 뒤 실제 `AVCaptureSession` 구현을 붙인다. 원격 저장(Outbox·Firestore)과 EXIF 제거(DF-205)는 이 스토리에서 하지 않는다. 사진을 카메라 롤·공유 시트·로그로 내보내는 코드를 만들지 않는다. `PostureVision/Landmarks/`(DF-207)는 호출만 하고 고치지 않는다.

### MVP 범위(DEC-22)

- MVP 스프린트: S10(원래 계획 S15). 상태: 할 일
- 왜 필요한가: 흐름 3: TR-07 정면·측면 촬영
- 지금 만든다: 정면·측면 두 장 촬영, 인물·조명 검출, 동의 ②③ 게이트. 시뮬레이터에는 카메라가 없으므로 DEBUG·시뮬레이터에서 사진 가져오기(PhotosPicker) 입력을 둔다. roll·pitch 게이트는 센서가 있을 때만 켠다
- 동의 게이트(AC-DF-204.1)는 DF-111 MVP 조각(S06)의 `EffectiveConsent`만 읽는다: `canCapturePosture`가 false면 진입 차단, ②③이 로컬 캡처만 있으면 '동의 확인 대기'
- 스테이션·촬영 조건은 DF-203 MVP 조각(같은 S10, 먼저 병합)을 쓴다: TR-07 진입 때 `StationProfileStore.ensureDefault`로 기본 프로필(`stationProfileId = "default-v1"`)을 받아 `createDraft(member:stationProfile:captureConditions:)`에 넘기고, `captureConditions`는 `CaptureConditionsBuilder.build(profile:clothing:)` 결과에 셔터 시점 `levelDeg`·`pitchDeg`를 더한다(AC-DF-204.5). `CaptureGateView`의 '스테이션 없음' 상태는 MVP에서 나오지 않는다(기본 프로필이 늘 있다). AC-DF-204.2의 'Given 체크리스트 완료'는 MVP에서 'Given 복장 선택 완료'로 읽고, AC-DF-204.8에서 유지할 것은 사진과 복장 선택이다
- 센서가 없는 시뮬레이터 가져오기 경로에서는 수평 값을 읽을 수 없다. 이때 `levelDeg`·`pitchDeg`는 `0`으로 채우지 말고 `captureConditions`에서 뺀다(규칙은 `hasOnly`라 키가 없어도 통과한다). 값을 지어내지 않는다
- `landmarkEngine`은 DF-207(S11)이 채운다. S10에는 로컬 draft의 `landmarkEngineJSON`이 비어 있어도 되며, 원격 create(DF-206, S11)는 DF-207 병합 뒤라 필수 필드가 채워진다
- MVP 뒤로 미룬다: 스테이션 편집·선택 UI와 회차 체크리스트 나머지 세 토글(DF-203 MVP 절)
- MVP에서 기다리지 않는 의존: DF-915(촬영 프로토콜 소유자 확정). DEC-21에 따라 v1 초안 값을 쓴다
- 분석 이벤트 AC는 MVP 뒤(DF-126·DF-033): AC-DF-204.7(`posture_capture_started`·`posture_capture_done`)과 `TrainerAnalyticsTests/PostureCaptureEventsTests.swift`는 만들지 않는다

---

### DF-220 AD-05 지표 카탈로그 조회 화면을 구현한다

| 항목 | 값 |
|---|---|
| Epic | EP-07 기능 플래그·관리자 화면 |
| Type | story |
| Phase | P1b |
| Sprint | S15 (2027-01-04~01-08) |
| Points | 3 (size/M) |
| Priority | should |
| Area | admin-web |
| Labels | `type/story` `area/admin-web` `phase/P1b` `prio/should` `size/M` `agent/codex` |
| Depends on | DF-004 |
| PRD refs | AD-05, §8.3, §10.7 화면 행, 부록 A.1·A.2 |

**사용자 스토리**
운영자 관리자로서, 지표 코드·단위·허용 출처 등급·신뢰 등급·가용성과 현재 활성 MDC를 한 화면에서 읽고 싶다. 그래야 정책 초안(DF-221, AD-04)을 만들 때 카탈로그와 어긋나는 값을 넣지 않는다.

**배경·맥락**
- 부록 A가 `metricCode`의 정본이고 `contracts/metric-catalog.v1.json`(DF-003)이 그 기계 판독본이다. AD-05는 이 생성물을 **읽기 전용**으로 보여 준다(§8.3 AD-05).
- 기존 설정 화면 패턴(서버 컴포넌트, `requireConsoleUser(['admin'])`, 표)을 따른다(dfet:admin_web/app/(console)/settings/reference-ranges/page.tsx:10-14).

**수용 기준**
1. **AC-DF-220.1** (AD-05) Given 생성된 카탈로그, When `/metric-catalog`를 열면, Then 카탈로그의 모든 `metricCode`가 한 행씩(행 수 = 카탈로그 길이) 보이고 열은 metricCode, 한글명, 지표군, 단위, 허용 sourceGrade, 신뢰 등급, 가용성, improvementDirection, conditionKeys, 활성 MDC다. — 단위(행 조립) + 수동
2. **AC-DF-220.2** (AD-05 '활성 MDC(읽기 전용)') Given `insightPolicyVersions`에 `kind=bodyChange, active=true` 문서가 없음, Then 활성 MDC 열이 모두 '활성 MDC 없음'이다. 있으면 해당 지표에 `±{mdcValue}{unit} · {문헌값, 자체 재검사 전 | 자체 재검사}`가 보인다. — 단위
3. **AC-DF-220.3** (§10.7 roleCanAccess) Given `trainer` 역할, When `/metric-catalog` 접근, Then `/unauthorized`로 이동하고 사이드바에 메뉴가 없다. — 단위(`roleCanAccess`) + 수동
4. **AC-DF-220.4** 화면에 입력·저장 컨트롤이 없다(읽기 전용). 금지어 린트 통과. — 코드 리뷰·CI

**구현 노트**
- 새 파일: `admin_web/app/(console)/metric-catalog/page.tsx`(ASM-P1b-32), `admin_web/lib/metric-catalog-rows.ts`(순수 함수 `buildCatalogRows(catalog, activePolicy)`; `@/` 별칭 없이 상대 import, ASM-P1b-30).
- 데이터: `import { metricCatalog } from '@/lib/generated/contracts'`(DF-004 생성물). 활성 정책은 `adminDb.collection('insightPolicyVersions').where('kind','==','bodyChange').where('active','==',true).limit(1).get()`.
- 사이드바: dfet:admin_web/components/console-shell.tsx:9-24의 `nav` 배열 '설정' 구역에 `{ section: '설정', label: '지표 카탈로그', href: '/metric-catalog', icon: '≡' }`를 추가한다. `roleCanAccess`(dfet:admin_web/lib/auth.ts:53-61)는 admin만 모든 경로를 허용하므로 변경이 필요 없다(trainer 허용 목록에 넣지 않는다).
- 문구: 페이지 제목 '지표 카탈로그', 설명 '부록 A 지표 정의와 판정 메타를 읽기 전용으로 확인합니다.' '정상범위' 같은 표현을 쓰지 않는다.
- 테스트 실행: `admin_web/package.json`의 `test` 스크립트(dfet:admin_web/package.json:14 `node --test test/*.test.mjs`)를 `node --experimental-strip-types --test test/*.test.mjs`로 바꾼다(ASM-P1b-30, DF-221과 공유).

**테스트**
- `admin_web/test/metric-catalog-rows.test.mjs`: `test('AC-DF-220.1 카탈로그 전 지표가 행으로 나온다', …)`, `test('AC-DF-220.2 활성 정책 없으면 활성 MDC 없음', …)`, `test('AC-DF-220.2 literature MDC 표기', …)`
- `admin_web/test/role-access.test.mjs`: `test('AC-DF-220.3 trainer는 /metric-catalog 접근 불가', …)`(`roleCanAccess`를 순수 함수로 import할 수 없으면 경로 목록 상수만 분리)
- 수동: 로컬 에뮬레이터 admin 계정으로 화면 확인 스크린샷(합성 데이터)을 PR에 첨부.

**비고·가정**
- ASM-P1b-30, ASM-P1b-32.

**DoR 체크**
- [x] R1 · [x] R2 · [x] R3 DF-004(P0) · [x] R4 3점 · [x] R5 · [x] R6 `admin_web/app/(console)/metric-catalog/`, `admin_web/lib/metric-catalog-rows.ts`, `admin_web/components/console-shell.tsx`, `admin_web/package.json`, `admin_web/test/` · [x] R7 없음 · [x] R8 에뮬레이터 합성 정책 문서 · [x] R9 · [x] R10 해당 없음

**에이전트 브리프**
`buildCatalogRows` 순수 함수와 `node:test`를 먼저 만들고, 페이지는 기존 reference-ranges 페이지 모양을 따른다. 정책 쓰기 API(`app/api/clinical/config`)는 DF-221 영역이니 건드리지 않는다. 카탈로그 값을 복사해 하드코딩하지 말고 생성물만 import한다.

---
### DF-205 EXIF·GPS 제거, 얼굴 가림 썸네일, 재촬영 폐기, 앱 전용 저장을 구현한다

| 항목 | 값 |
|---|---|
| Epic | EP-14 체형평가(정적 2D) |
| Type | story |
| Phase | P1b |
| Sprint | S11(MVP 계획, DEC-22, [03 MVP 계획](../03_RELEASE_AND_SPRINT_PLAN.md#mvp-계획dec-22)). 원래 계획: S16 (2027-01-11~01-15) |
| Points | 3 (size/M) |
| Priority | must |
| Area | trainer-app |
| Labels | `type/story` `area/trainer-app` `area/privacy` `phase/P1b` `prio/must` `size/M` `flag/bodyAssessment` `agent/claude` `privacy-impact` `scope/mvp` |
| Depends on | DF-204 |
| PRD refs | F-ASM-01.6, F-ASM-01.7, F-ASM-01.10, AC-ASM-01.4, AC-ASM-01.6, NFR-17, §9.5, RISK-06 |

**사용자 스토리**
회원(트레이너가 대신 지키는 입장)으로서, 내 신체 사진이 위치 정보 없이 앱 안에만 저장되고, 밖으로 나갈 수 있는 썸네일은 얼굴이 가려져 있기를 원한다. 그래야 사진이 원래 목적 밖에서 나를 드러내지 않는다.

**배경·맥락**
- 사진은 앱 전용 저장소에만 두고 카메라 롤에 저장하지 않으며, 업로드 전 EXIF를 제거한다(F-ASM-01.7). 교체된 사진은 업로드하지 않고 폐기한다(F-ASM-01.6).
- 회원 공유 썸네일과 연구 내보내기는 기본으로 얼굴을 가린다. 측면 원본은 이주가 보여야 하므로 얼굴이 포함된다(F-ASM-01.10). 가림본 공유는 P2지만 생성은 촬영 때 한다.
- 신체 사진 유출은 영향 '상' 리스크다(RISK-06).

**수용 기준**
1. **AC-DF-205.1** (AC-ASM-01.4) Given GPS·EXIF·TIFF 제조사 메타가 들어간 픽스처 JPEG, When `PhotoSanitizer.sanitize`, Then 출력의 `CGImageSourceCopyPropertiesAtIndex`에 `{GPS}` 사전이 없고 `{Exif}`의 `MakerNote`·`UserComment`·날짜 필드가 없으며, 방향은 1(`up`)이고 픽셀이 원래 방향으로 회전돼 있다. — 단위
2. **AC-DF-205.2** (§9.5, ASM-P1b-14) 출력 원본은 JPEG, 긴 변 ≤ 4032px, ≤ 10MB. 썸네일·가림본은 긴 변 480px, ≤ 512KB. 각 파일의 SHA-256·바이트 수가 `LocalBinary`에 기록된다. — 단위
3. **AC-DF-205.3** (F-ASM-01.10, ASM-P1b-13) Given 얼굴이 있는 정면 픽스처, When `FaceMasker.maskedThumbnail`, Then 얼굴 사각형(30% 확장) 영역의 픽셀이 단색이다. 얼굴을 못 찾으면 가림본을 만들지 않고 `.pendingLandmarkFallback`을 돌려준다. 확정 시점에 귀·이주 확정 좌표가 있으면 머리 상자로 가림본을 만든다(DF-209가 호출). — 단위(시뮬레이터, Vision)
4. **AC-DF-205.4** (AC-ASM-01.6 로컬 부분) Given 다시 찍기, Then 이전 원본·썸네일·가림본 로컬 파일이 삭제되고 해당 뷰의 대기 업로드 작업이 취소되며, 이미 업로드됐으면 Storage 삭제 작업이 큐에 들어간다(`OutboxItem.deleteBinary`). — 단위(가짜 Outbox)
5. **AC-DF-205.5** (NFR-17) 생성되는 모든 파일에 `FileProtectionType.complete`와 `isExcludedFromBackup=true`가 설정된다. — 단위
6. **AC-DF-205.6** (F-ASM-01.7) 촬영 원본이 앱 컨테이너 밖에 쓰이지 않는다: 임시 파일도 `Application Support/TrainerKit/Posture/…/tmp` 안에서 만들고 처리 후 지운다. 카메라 롤 API 0건(static-guards, DF-204에서 추가한 검사 재사용). — 단위·CI

**구현 노트**
- 새 파일(`Sources/PostureVision/Privacy/`)
  - `PhotoSanitizer.swift`: `func sanitize(input: URL, output: URL) throws -> SanitizedPhoto`(`CGImageSourceCreateWithURL` → 방향 적용한 `CGImage` → `CGImageDestinationCreateWithURL(… "public.jpeg" …)`에 `kCGImageDestinationLossyCompressionQuality: 0.85`, `kCGImagePropertyOrientation: 1`만 넣음. 원본 메타 사전을 복사하지 않는다).
  - `Thumbnailer.swift`: `kCGImageSourceThumbnailMaxPixelSize: 480`, `kCGImageSourceCreateThumbnailWithTransform: true`.
  - `FaceMasker.swift`: `VNDetectFaceRectanglesRequest` → 사각형 확장(30%) → Core Graphics로 중립 회색 채움. 폴백 `maskUsingHeadBox(landmarks:)`(귀 또는 이주 확정 좌표 중심, 이미지 높이 18% 정사각형).
  - `SanitizedPhoto`: `{fileURL, byteCount, sha256Hex, pixelWidth, pixelHeight}`(SHA-256은 `CryptoKit.SHA256`).
- 호출 지점: DF-204의 셔터 저장 경로에서 `raw → sanitize → thumb → masked` 순서로 바꾼다. 원시 캡처 데이터(`AVCapturePhoto.fileDataRepresentation()`)는 정규화 뒤 즉시 지운다. 랜드마크 정규화 좌표 기준(EXIF 방향 적용 원본, §9.2)과 정규화 결과가 같은 방향이 되도록 **정규화된 파일에서** 제안(DF-207)을 실행한다.
- 파일 규칙: `{assessmentId}/{view}.jpg`, `{view}_thumb.jpg`, `{view}_masked_thumb.jpg`(Storage 경로와 같은 이름, §9.5).
- 로그: 파일 경로·해시를 로그에 남기지 않는다. 실패는 `os.Logger`에 오류 종류만(`privacy: .private`).

**테스트**
- `PostureVisionTests/PhotoSanitizerTests.swift`: `test_AC_ASM_01_4_gpsAndExifRemoved()`, `test_AC_DF_205_1_orientationBakedIn()`, `test_AC_DF_205_2_sizeLimitsAndHash()`
- `PostureVisionTests/FaceMaskerTests.swift`: `test_AC_DF_205_3_faceRegionFilled()`, `test_AC_DF_205_3_noFaceReturnsFallbackPending()`, `test_AC_DF_205_3_headBoxFallbackFromLandmarks()`
- `FeatureAssessmentTests/RetakeTests.swift`: `test_AC_ASM_01_6_retakeCancelsUploadAndDeletesLocal()`, `test_AC_ASM_01_6_retakeAfterUploadEnqueuesStorageDelete()`
- `PostureVisionTests/FileProtectionTests.swift`: `test_NFR_17_protectionAndBackupExclusion()`
- 픽스처: GPS 태그를 **합성으로 주입한** JPEG(`Fixtures/gps_injected.jpg`, 테스트에서 `CGImageDestination`으로 생성해도 된다). 실제 장소 좌표는 쓰지 않는다(예: 0.0, 0.0).

**비고·가정**
- ASM-P1b-13, ASM-P1b-14, ASM-P1b-15.
- Storage 쪽 교체 파일 부재(AC-ASM-01.6 전체)는 DF-206 에뮬레이터 연동 테스트로 확인한다.

**DoR 체크**
- [x] R1 · [x] R2 · [x] R3 DF-204(S15) · [x] R4 3점 · [x] R5 · [x] R6 `PostureVision/Privacy`, `FeatureAssessment/Capture`의 저장 호출부 · [x] R7 `privacy-impact` · [x] R8 합성 GPS 주입 픽스처 · [x] R9 · [x] R10 해당 없음

**에이전트 브리프**
`PhotoSanitizer` 테스트(메타 제거·방향)를 먼저 통과시킨다. 원본 메타 사전을 통째로 복사한 뒤 일부만 지우는 방식은 쓰지 않는다(빠뜨리기 쉽다) — 필요한 속성만 새로 넣는다. 업로드·Outbox 구현(DF-206)과 TR-08 화면(DF-208)은 건드리지 않는다. 얼굴 가림은 블러가 아니라 단색 채움이다.

### MVP 범위(DEC-22)

- MVP 스프린트: S11(원래 계획 S16). 상태: 할 일
- 왜 필요한가: 흐름 3: EXIF·GPS 제거, 재촬영 폐기, 앱 전용 저장
- 지금 만든다: AC-DF-205.1(`PhotoSanitizer`), AC-DF-205.2의 원본과 **일반 썸네일**(`Thumbnailer`, `{view}_thumb.jpg`, 긴 변 480px. 가림본 규격은 뺀다), AC-DF-205.4(재촬영 폐기. 가림본 파일은 없다), AC-DF-205.5, AC-DF-205.6
- MVP 뒤로 미룬다: 얼굴 가림 썸네일만(AC-DF-205.3 `FaceMasker`, `{view}_masked_thumb.jpg`, `FaceMaskerTests`). 테스트 회원만 쓰는 동안 연기하고 실회원 전에는 필수다. 저장 경로 순서는 `raw → sanitize → thumb`

---

### DF-206 체형 draft 오프라인 저장과 사진 업로드 큐·확정 대기 표시를 구현한다

| 항목 | 값 |
|---|---|
| Epic | EP-14 체형평가(정적 2D) |
| Type | story |
| Phase | P1b |
| Sprint | S11(MVP 계획, DEC-22, [03 MVP 계획](../03_RELEASE_AND_SPRINT_PLAN.md#mvp-계획dec-22)). 원래 계획: S16 (2027-01-11~01-15) |
| Points | 3 (size/M) |
| Priority | must |
| Area | trainer-app |
| Labels | `type/story` `area/trainer-app` `area/storage` `phase/P1b` `prio/must` `size/M` `flag/bodyAssessment` `agent/claude` `privacy-impact` `scope/mvp` |
| Depends on | DF-204, DF-015 |
| PRD refs | F-ASM-01.8, AC-ASM-01.5, AC-ASM-01.6(Storage), AC-ASM-04.5, NFR-04, NFR-05, NFR-06, C-05, AC-C-05.1, §9.5, S-01~S-04, §6.0.3 |

**사용자 스토리**
트레이너로서, 와이파이가 끊긴 방에서도 촬영과 보정을 끝내고 싶고, 나중에 연결되면 알아서 올라가되 올라가기 전에는 '동기화됨'이 뜨지 않기를 원한다. 그래야 기록이 사라졌는지 걱정하지 않는다.

**배경·맥락**
- Storage 규칙은 부모 문서(`postureAssessments/{id}`)를 조회해 `trainerId`와 **draft 상태**를 확인한다. 부모가 서버에 없거나 이미 confirmed면 업로드가 거부된다(§9.5, S-03, S-04). 그래서 순서가 정해져 있다: 부모 draft 생성 → 사진 업로드 → 경로 기록 → 랜드마크 → **확정 전환은 맨 마지막**(ADR-002).
- 동의가 서버에서 확인된 회원만 오프라인 촬영이 가능하다(F-ASM-01.8). 확정본은 업로드가 끝나야 '동기화됨'이다(AC-ASM-04.5).

**Outbox 순서(체형평가 1건, 정본)**

| # | Outbox 항목 | 원격 동작 | 선행 조건 | 실패 시 |
|---|---|---|---|---|
| 1 | `createDocument` | `postureAssessments/{id}` create: status `draft`, `views[].photoPath=null`, `landmarks=[]`, `metrics` 없음, `createdAt`·`updatedAt`=serverTimestamp | 동의 ②③ 서버 확인(서버 상태 재조회, ASM-P1b-12) | 규칙 거부 → `syncFailed('권한 또는 동의 확인 실패')`, 로컬 유지 |
| 2 | `uploadBinary` ×(뷰 2 × 파일 3) | `{view}.jpg`, `{view}_thumb.jpg`, `{view}_masked_thumb.jpg` putData + contentType | #1 `serverCommitted`, 직전 동의 ③ 확인 | 지수 백오프, 연속 5회 실패 → `syncFailed` |
| 3 | `updateDocument` | `views[]` 경로(`photoPath`, `thumbPath`, `maskedThumbPath`) 기록 | 해당 뷰 업로드 크기·SHA-256 대조 성공 | 대조 불일치 → 재업로드 1회 후 `syncFailed` |
| 4 | `updateDocument`(합치기 키 `landmarks:{id}`) | `views[].landmarks`, `imageRotationDeg`, `landmarkEngine` | #1 | 마지막 로컬 값만 전송(중간 편집은 합침) |
| 5 | `updateDocument`(DF-209가 넣음) | `status: confirmed`, `metrics`, `isBaseline`, `updatedAt` | #2~#4 모두 완료 | 규칙 거부 → `syncFailed`, 로컬 확정 잠금 해제 |
| 6 | `updateDocument`(DF-209가 넣음) | 이전 버전 `status: voided`(`isBaseline` 이전) | #5 `serverCommitted` | 재시도, 실패 시 두 버전이 잠시 confirmed(ASM-P1b-09 설명) |
| — | `deleteBinary` | 재촬영·draft 삭제 시 Storage 객체 삭제 | 부모가 draft | 재시도 |
| — | `deleteDocument` | draft 삭제(F-ASM-04.1 'draft만 삭제') | Storage prefix 삭제 완료 | 재시도 |

**수용 기준**
1. **AC-DF-206.1** (AC-ASM-01.5) Given 비행기 모드, When 촬영·draft 저장, Then 배지가 '기기에 저장됨'이고, 네트워크를 켜면 '동기화 중' → 모든 항목 완료 뒤 '동기화됨'으로 바뀐다. — 에뮬레이터 연동(`trainer-app-emulator-it`)
2. **AC-DF-206.2** (NFR-05, S-03) Given #1이 서버에 반영되지 않은 상태, Then 업로드 시도가 0회다(가짜 `BinaryUploader` 호출 수 0, 에뮬레이터 요청 로그 0). — 단위·연동
3. **AC-DF-206.3** (AC-ASM-04.5) Given 오프라인에서 확정(DF-209), Then 노트 상태 '확정 대기'와 '동기화 중'이 함께 보이고, #2~#5가 끝나야 '동기화됨'이다. — 연동
4. **AC-DF-206.4** (AC-C-05.1, NFR-06) Given 에뮬레이터 규칙이 create를 거부하도록 동의 ③을 철회한 시드, When 동기화, Then '동기화 실패'와 사유·재시도가 보이고 '동기화됨'은 한 번도 표시되지 않으며 로컬 사진과 draft는 남는다. `save_failure_shown{entity_type:"postureAssessment"}`가 기록된다. — 연동
5. **AC-DF-206.5** (AC-ASM-01.6) Given 업로드 완료 후 정면 재촬영, When 동기화, Then Storage의 `front.jpg`·`front_thumb.jpg`·`front_masked_thumb.jpg`가 새 파일의 SHA-256과 같다(같은 경로 덮어쓰기는 부모 draft라 허용). 다시 찍은 뒤 올리지 않은 이전 파일은 Storage에 한 번도 올라가지 않는다. — 연동
6. **AC-DF-206.6** (NFR-04) Given 업로드 도중 앱 강제 종료, When 재실행, Then 남은 항목부터 이어서 완료되고 중복 문서가 0건이다(자동 ID 멱등). — 연동
7. **AC-DF-206.7** (F-ASM-04.1) Given draft, When '평가 삭제', Then Storage `postureAssessments/{id}/` 아래 객체 0, 문서 0, 로컬 파일 0. confirmed에는 삭제 메뉴가 없다. — 연동·UI
8. **AC-DF-206.8** (§4.2 매퍼) 매퍼가 쓰는 키가 V1-05 §4.6 화이트리스트와 정확히 같고(`schemaVersion=1`, `legalNature='coachingRecord'`, `trainerId==authorUid==uid`), `createdAt`은 create 때만 쓴다. — 단위

**구현 노트**
- `Sources/SyncEngine/Plans/PostureOutboxPlan.swift`: 위 표를 `[OutboxItem]`으로 만드는 순수 함수(`plan(for draft: LocalAssessmentDraft, event: PostureSyncEvent) -> [OutboxItem]`), 의존 관계는 `OutboxItem.dependsOn`. SyncEngine 본체(DF-015)의 회원별 순서와 백오프를 재사용한다. P1a에 `deleteBinary`·`deleteDocument` 종류가 없으면 여기서 추가한다(DF-123 draft 삭제와 공유).
- `Sources/FirebaseData/Posture/PostureAssessmentMapper.swift`: `LocalAssessmentDraft` ↔ Firestore 맵. 필드 이름은 V1-05 §4.6. `Timestamp`·`FieldValue.serverTimestamp()` 변환은 FirebaseData 공통 헬퍼.
- 업로드는 `StorageBinaryUploader.upload(localURL:path:contentType:sha256:)`(P1a DF-104). 업로드 뒤 메타데이터 `size`와 로컬 `byteCount` 대조, SHA-256은 업로드 전 로컬 값과 커스텀 메타 `sha256`으로 기록해 대조한다. `getDownloadURL` 금지.
- 동의 재확인(ASM-P1b-12): #1·#2 직전에 `ConsentService.currentServerState(member:)`를 읽고 ③이 false면 항목을 `awaitingConsent`가 아니라 `syncFailed('신체 촬영 동의가 없어 올리지 않았어요')`로 둔다. 로컬 파일 삭제는 DF-227(또는 대안: 이 스토리) 철회 경로가 한다.
- 표시: `SyncStateBadge`(DF-016), TR-09·TR-03 행에 배지. '확정 대기'는 `tr09.status.pendingConfirm`.
- **대안(DF-227 미채택 시)**: 동의 ③ 철회 감지 시 해당 회원의 `Posture/` 로컬 파일 삭제와 대기 업로드 취소를 이 스토리에 넣는다(+1점, S16 초과는 소유자 판단).

**테스트**
- `SyncEngineTests/PostureOutboxPlanTests.swift`: `test_NFR_05_parentBeforeBinary()`, `test_AC_DF_206_3_confirmIsLastStep()`, `test_AC_DF_206_7_draftDeleteDeletesPrefixThenDoc()`, `test_landmarkEditsCoalesce()`
- `FirebaseDataTests/PostureAssessmentMapperTests.swift`: `test_AC_DF_206_8_keysMatchWhitelist()`, `test_NFR_07_createdAtOnlyOnCreate()`
- `IntegrationTests/PostureSyncIT.swift`(에뮬레이터, 합성 `synthMember0001`): `test_AC_ASM_01_5_offlineThenSynced()`, `test_AC_DF_206_2_noUploadBeforeParent()`, `test_AC_ASM_04_5_pendingConfirmUntilUploads()`, `test_AC_C_05_1_ruleRejectShowsSyncFailed()`, `test_AC_ASM_01_6_retakeReplacesStorageObject()`, `test_AC_DF_206_6_resumeAfterKill()`(프로세스 재시작 시뮬레이션: SyncEngine 재생성)

**비고·가정**
- ASM-P1b-06(draft에는 `metrics`를 쓰지 않음), ASM-P1b-12, ASM-P1b-15, G-P1b-3.

**DoR 체크**
- [x] R1 · [x] R2 · [x] R3 DF-204(S15), DF-015(P0/S07), DF-104·DF-107(P1a) · [x] R4 3점 · [x] R5 · [x] R6 `SyncEngine/Plans`, `FirebaseData/Posture`, `IntegrationTests/PostureSyncIT.swift` · [x] R7 `privacy-impact` · [x] R8 에뮬레이터 시드(①②③, ③ 철회 변형) · [x] R9 · [x] R10 실기기 비행기 모드는 DF-223

**에이전트 브리프**
`PostureOutboxPlan` 순수 함수와 테스트로 순서를 먼저 고정한다. 확정 전환을 업로드보다 먼저 보내는 경로가 생기면 Storage 규칙에 거부되므로 테스트로 막는다. 규칙 파일(`firestore.rules`, `storage.rules`)은 고치지 않는다 — 규칙 보강이 필요하면 PR 본문에 G-P1b-3을 적고 소유자에게 넘긴다. FeatureAssessment 화면은 배지 표시 한 곳만 건드린다.

### MVP 범위(DEC-22)

- MVP 스프린트: S11(원래 계획 S16). 상태: 할 일
- 왜 필요한가: 흐름 3: 체형 draft 오프라인 저장과 사진 업로드 큐
- 지금 만든다: 카드 전체 범위에서 가림본만 뺀다. Outbox #2는 뷰마다 **두 파일**(`{view}.jpg`, `{view}_thumb.jpg`)을 올리고, #3은 `maskedThumbPath=null`로 쓴다(V1-05 §4.6 `str|null`). #5 확정 전환은 두 파일과 #3·#4 완료만 기다리고 가림본을 기다리지 않는다. AC-DF-206.5는 `front.jpg`·`front_thumb.jpg`만 대조한다
- 분석 이벤트 AC는 MVP 뒤(DF-126·DF-033): AC-DF-206.4의 `save_failure_shown` 기록 부분만 뺀다. '동기화 실패'·사유·재시도 표시와 로컬 보존은 그대로다
- 동의 ③ 철회 시 로컬 파일 삭제(DF-227 또는 카드 '대안')는 MVP 뒤다. MVP 테스트 회원은 철회 시나리오를 에뮬레이터 규칙 거부(AC-DF-206.4)로만 확인한다

---

### DF-208 TR-08 랜드마크 보정(확대 핀, 1px 방향 버튼, auto/확정 모양, '지정 필요')을 구현한다

| 항목 | 값 |
|---|---|
| Epic | EP-14 체형평가(정적 2D) |
| Type | story |
| Phase | P1b |
| Sprint | S11(MVP 계획, DEC-22, [03 MVP 계획](../03_RELEASE_AND_SPRINT_PLAN.md#mvp-계획dec-22)). 원래 계획: S16 (2027-01-11~01-15) |
| Points | 5 (size/L) |
| Priority | must |
| Area | trainer-app |
| Labels | `type/story` `area/trainer-app` `area/design` `phase/P1b` `prio/must` `size/L` `flag/bodyAssessment` `agent/claude` `scope/mvp` |
| Depends on | DF-207 |
| PRD refs | F-ASM-02.3, F-ASM-02.4, F-ASM-02.5, F-ASM-02.6, F-VIZ-02.1, F-VIZ-02.2, F-VIZ-02.3, F-VIZ-02.8, AC-ASM-02.1, AC-ASM-02.2, AC-VIZ-02.1, AC-VIZ-02.2, A-04, AC-A11Y-03, M-04b, TR-08 |

**사용자 스토리**
트레이너로서, 마커 스티커 위에 핀을 정확히 놓고, 자동 제안과 내가 확정한 점을 흑백 화면에서도 구분하고 싶다. 그래야 확정 근거가 분명한 값만 기록된다.

**배경·맥락**
- C7·견봉·ASIS는 자동 위치를 그대로 확정할 수 없고, 핀을 옮기거나 '이 위치로 지정'을 눌러야 `origin=manual`이 된다(F-ASM-02.3).
- 랜드마크 상태는 **모양과 문구**로 구분하고 색은 보조다(F-VIZ-02.2, A-02). 드래그 없이 방향 버튼·VoiceOver 조정 동작으로도 옮길 수 있어야 한다(A-04).
- 오버레이는 `imageRotationDeg`로 수평 보정한 좌표계에서 그리고, '원본 보기'로 보정 전 사진과 보정각을 볼 수 있다(F-VIZ-02.1). 저장 좌표는 보정 **전** 값이다(§9.2).

**수용 기준**
1. **AC-DF-208.1** (AC-ASM-02.1) Given `c7`이 `origin=auto`(또는 제안 없음), Then 그 랜드마크의 '확정'과 평가 '확정'이 비활성이고, '이 위치로 지정' 또는 핀 이동 후에만 `origin=manual, confirmed=true`가 된다. — UI·단위(`CalibrationViewModel`)
2. **AC-DF-208.2** (AC-ASM-02.2, AC-VIZ-02.2, F-ASM-02.6) Given 사람 미검출(제안 0개) 사진, Then 오른쪽 목록에 뷰별 필수 코드가 '지정 필요' 슬롯으로 나오고, 모두 수동 지정하면 평가 '확정'이 활성화된다. — UI
3. **AC-DF-208.3** (AC-VIZ-02.1, AC-A11Y-03) Given 같은 사진에 auto 미확정, auto 확정, manual 확정 점, When 회색조 스냅샷, Then 세 모양(점선 빈 원, 찬 원, 찬 원+핀)이 구분되고 각 점에 문구('자동 제안', '확정', '수동 확정')가 있다. — 스냅샷
4. **AC-DF-208.4** (F-VIZ-02.8, A-04) Given 선택한 핀, When 방향 버튼 ↑를 한 번 누르면, Then 원본 픽셀 기준 y가 정확히 1px(정규화로 1/height) 줄고, '되돌리기'로 이전 위치가 복원된다. VoiceOver 사용자 정의 동작 '위로 1픽셀'이 같은 결과를 낸다. — 단위·UI
5. **AC-DF-208.5** (F-ASM-02.5) Given auto 제안을 옮김, Then 저장값은 `origin=manual`, `confirmed=true`, `suggested={원 x, 원 y, confidence}`이고 좌표는 0~1이다(보정 전 좌표계로 역변환). — 단위
6. **AC-DF-208.6** (F-VIZ-02.1, F-VIZ-02.3) 보정 보기에서 CVA는 이주–C7 선, 수평선, 각도 호와 값·단위·출처 칩을 그리고, 미확정 점이 포함된 선은 점선이다. '원본 보기'를 켜면 보정 전 사진과 `보정각 {imageRotationDeg}°`가 보인다. — 스냅샷
7. **AC-DF-208.7** (M-04b) 보정 화면 첫 진입 시각을 로컬 draft에 기록하고(`calibrationStartedAt`), 핀 수동 조정 횟수를 센다(DF-209가 확정 때 `posture_landmarks_confirmed`로 전송). — 단위
8. **AC-DF-208.8** (§8.4 TR-08 동의 없음 ③) Given 보정 중 ③ 철회가 반영됨, Then 사진과 점을 숨기고 '사진 동의 없음'을 보이며 편집이 막힌다. — UI(`--preview-state=tr08.noPhotoConsent`)

**구현 노트**
- 화면(`Sources/FeatureAssessment/Calibration/`): `CalibrationView.swift`(TR-08, `/// TR-08`), `CalibrationViewModel.swift`(@Observable; 선택 핀, 되돌리기 스택, `Confirmability`(DF-201) 계산), `LandmarkListPanel.swift`(뷰별 필수 코드, 상태 문구, '지정 필요'), `LoupeView.swift`(드래그 중 손가락 위 3배 확대 원), `NudgePad.swift`(↑↓←→ 1px, 되돌리기).
- 오버레이(`Sources/DesignSystem/Posture/PostureOverlayCanvas.swift`): SwiftUI `Canvas`. 입력은 PostureMath가 만든 표시용 도형(`OverlayGeometry {points:[OverlayPoint{position, shape: .autoHollowDashed | .autoFilled | .manualFilledPinned, label}], lines:[OverlayLine{from, to, dashed}], arcs:[…], valueLabels:[…]}`)이다. DesignSystem은 PostureMath를 import하지 않고, `FeatureAssessment`가 도형을 만들어 넘긴다. 이 캔버스는 TR-09(DF-210)와 TR-10(DF-214)이 재사용한다.
- 좌표 변환: 화면 표시는 `PixelGeometry.rotateAboutCenter`(보정 적용), 저장은 역회전 후 정규화. 1px 이동은 **원본 픽셀** 단위다.
- 확대: `ScrollView` 대신 `MagnifyGesture` + 오프셋 상태(최대 6배). 핀 탭 대상 44pt 이상(A-04).
- 저장: 핀 변경마다 `AssessmentStore.setLandmark(_:view:code:point:origin:)` → LocalStore 즉시 저장(`localSaved`) → Outbox 합치기(#4, DF-206).
- 문구 키(초안): `tr08.title` 랜드마크 보정 · `tr08.slot.required` 지정 필요 · `tr08.state.suggested` 자동 제안 · `tr08.state.confirmed` 확정 · `tr08.state.manualConfirmed` 수동 확정 · `tr08.action.setHere` 이 위치로 지정 · `tr08.action.confirmLandmark` 이 점 확정 · `tr08.action.undo` 되돌리기 · `tr08.toggle.original` 원본 보기 · `tr08.rotation` 보정각 {deg}° · `tr08.engine` 제안 엔진 {name} {version} · `tr08.noPhotoConsent` 사진 동의 없음 · `tr08.a11y.nudgeUp` 위로 1픽셀(아래·왼쪽·오른쪽 동일).
- 접근성 식별자: `tr08.pin.<code>`(예 `tr08.pin.c7`), `tr08.nudge.up|down|left|right`, `tr08.undo`, `tr08.setHere`, `tr08.confirmAssessment`, `tr08.toggle.original`. VoiceOver 라벨: "C7, 수동 확정, 가로 46.8%, 세로 30.2%".

**테스트**
- `FeatureAssessmentTests/CalibrationViewModelTests.swift`: `test_AC_ASM_02_1_autoManualRequiredCannotConfirm()`, `test_AC_ASM_02_2_allManualWithoutSuggestionsConfirmable()`, `test_AC_DF_208_4_nudgeMovesOnePixel()`, `test_AC_DF_208_4_undoRestores()`, `test_AC_DF_208_5_moveKeepsSuggestedAndInverseRotates()`, `test_AC_DF_208_7_calibrationStartAndAdjustCount()`
- 스냅샷(`FeatureAssessmentTests/CalibrationSnapshotTests.swift`, swift-snapshot-testing): `test_AC_VIZ_02_1_landmarkShapesGrayscale()`, `test_AC_DF_208_6_cvaLinesAndOriginalToggle()`
- UI(`UITests/TR08CalibrationUITests.swift`): `test_AC_VIZ_02_2_requiredSlotsAndDisabledConfirm()`(`--preview-state=tr08.noSuggestions`), `test_AC_DF_208_4_voiceOverCustomActionNudges()`, `test_AC_DF_208_8_noPhotoConsentState()`

**비고·가정**
- ASM-P1b-02(역회전), ASM-P1b-33.
- 평가 '확정' 버튼의 동작(상태 전이, Outbox #5)은 DF-209다. 이 스토리는 버튼의 활성·비활성과 호출만 만든다.

**DoR 체크**
- [x] R1 · [x] R2 · [x] R3 DF-207(S15), DF-205(같은 스프린트, 정규화 사진) · [x] R4 5점 · [x] R5 · [x] R6 `FeatureAssessment/Calibration`, `DesignSystem/Posture/PostureOverlayCanvas.swift` · [x] R7 없음 · [x] R8 픽스처 사진·합성 랜드마크 · [x] R9 · [x] R10 해당 없음

**에이전트 브리프**
`CalibrationViewModel`의 좌표 변환·1px 이동·되돌리기 테스트를 먼저 쓰고, 그다음 캔버스와 회색조 스냅샷을 만든다. 오버레이 도형은 FeatureAssessment에서 만들어 DesignSystem에 값으로 넘긴다(DesignSystem → PostureMath 의존을 만들지 않는다). 확정 전환·버전·기준선 로직(DF-209)과 업로드(DF-206)는 호출만 한다. 색만으로 상태를 구분하는 코드는 만들지 않는다.

### MVP 범위(DEC-22)

- MVP 스프린트: S11(원래 계획 S16). 상태: 할 일
- 왜 필요한가: 흐름 3: TR-08 랜드마크 수동 보정
- 지금 만든다: 카드 전체 범위(분석용 AC-DF-208.7 제외)
- 분석 이벤트 AC는 MVP 뒤(DF-126·DF-033): AC-DF-208.7(`calibrationStartedAt`·조정 횟수 기록, DF-209 이벤트용)은 만들지 않는다

---

### DF-221 clinical config에 bodyChange kind 검증을 추가한다

| 항목 | 값 |
|---|---|
| Epic | EP-07 기능 플래그·관리자 화면 |
| Type | story |
| Phase | P1b |
| Sprint | S16 (2027-01-11~01-15) |
| Points | 3 (size/M) |
| Priority | must |
| Area | admin-web |
| Labels | `type/story` `area/admin-web` `phase/P1b` `prio/must` `size/M` `agent/codex` `schema-change` `regulatory` |
| Depends on | DF-004 |
| PRD refs | §10.7 정책 kind 행, §7.3.1, §7.6, §9.2 `insightPolicyVersions`(kind=bodyChange), R-25, AD-04(P3 운영의 선행) |

**사용자 스토리**
운영자 관리자로서, 변화 판정 정책 초안을 저장할 때 부록 A에 없는 지표나 출처 없는 MDC가 들어가면 서버가 거부하기를 원한다. 그래야 P3에 승인할 정책이 처음부터 규칙을 지킨다.

**배경·맥락**
- 현재 정책 API는 `policyKind`가 `gut|blood|integrated`뿐이고 `insightPolicyVersions`는 `integrated`만 허용한다(dfet:admin_web/app/api/clinical/config/route.ts:10-25). 승인 검증은 `validateApprovedConfig`(:27-87), 승인본 불변과 kind별 단일 활성은 트랜잭션(:89 이후)이 이미 한다.
- 저장 형태는 `transaction.set(document, {...input.config, kind, version, status, …})`라 `config.metrics`가 문서 최상위 `metrics`가 된다 — V1-05 §4.14 형태와 같다.
- 문헌 MDC는 출처 URL과 '문헌값, 자체 재검사 전' 표기가 필수이고(§7.3.1), 회원 배지는 inHouse만이다(§7.6). 이 스토리는 **검증만** 하고 운영 화면(AD-04)은 P3(DF-384)다.

**수용 기준**
1. **AC-DF-221.1** (§10.7) Given `collection='insightPolicyVersions'`, `policyKind='bodyChange'`, When POST, Then 스키마가 받아들인다. `referenceRangeVersions`에 `bodyChange`는 거부된다. — 단위
2. **AC-DF-221.2** (§10.7 metricCode는 부록 A) Given `config.metrics`에 카탈로그에 없는 키(`bodyScore`), Then draft든 approved든 `400`과 '부록 A에 없는 지표: bodyScore'. — 단위
3. **AC-DF-221.3** (§10.7) Given `status='approved'`, Then 지표마다 `mdcValue`가 유한한 양수, `mdcSource ∈ {literature, inHouse}`, `mdcReference`가 비어 있지 않음(literature는 `http(s)://` URL), `improvementDirection ∈ {higherIsBetter, lowerIsBetter, towardZero, none}`이고 카탈로그 값과 같음, `conditionKeys`가 비어 있지 않고 카탈로그 conditionKeys의 부분집합, 사진 계열 지표는 `protocolVersion` 문자열 필수. 하나라도 어기면 거부. — 단위(ASM-P1b-31)
4. **AC-DF-221.4** (§9.2 승인본 불변, kind별 단일 활성) Given 승인된 `bodyChange--v1`, When 같은 ID로 다시 POST, Then '승인된 버전은 변경할 수 없습니다'로 거부된다. `bodyChange--v2`를 approved+active로 저장하면 `bodyChange--v1.active=false`가 되고 `integrated` 활성 문서는 그대로다. — 단위(검증기) + 에뮬레이터 수동
5. **AC-DF-221.5** 기존 `gut`·`blood`·`integrated` 저장 동작이 바뀌지 않는다(회귀). — 단위
6. **AC-DF-221.6** ConfigEditor에서 통합 정책 화면일 때 `integrated | bodyChange`를 고를 수 있고, 목록 표에 kind 열이 생긴다. — 수동

**구현 노트**
- 새 파일 `admin_web/lib/body-change-policy.ts`(ASM-P1b-30: 상대 import만)

```ts
import catalog from '../../contracts/metric-catalog.v1.json' with { type: 'json' };  // 또는 lib/generated/contracts.ts 생성물(DF-004)의 상수
export type BodyChangeIssue = { metricCode: string; field: string; message: string };
export function validateBodyChangeConfig(config: unknown, opts: { approved: boolean }): BodyChangeIssue[];
```

  생성물(`admin_web/lib/generated/contracts.ts`)이 상대 경로로 import 가능하면 그것을 쓰고, JSON 직접 import는 대안이다.
- `route.ts` 수정
  - :12 `policyKind: z.enum(['gut', 'blood', 'integrated', 'bodyChange'])`
  - :17-25 `superRefine`: `insightPolicyVersions` ↔ `integrated | bodyChange`
  - `validateApprovedConfig` 앞에서 `policyKind==='bodyChange'`이면 `validateBodyChangeConfig(input.config, {approved: input.status==='approved'})`를 부르고 이슈가 있으면 첫 메시지로 `Error`를 던진다(기존 오류 처리 경로 재사용). draft에서는 AC-DF-221.2(키 존재)만 검사한다.
- `admin_web/components/config-editor.tsx`: :10 초기값과 :33 선택 상자를 `insightPolicyVersions`에서도 보이게 하고 옵션 `integrated`, `bodyChange`.
- `admin_web/app/(console)/settings/insight-policies/page.tsx`: 표에 `kind` 열 추가, 설명 문구를 '통합 점수·변화 판정 정책을 버전형으로 관리합니다.'로 바꾼다.
- 예시(합성, 승인하지 말 것 — G-08은 P3)

```json
{
  "collection": "insightPolicyVersions",
  "policyKind": "bodyChange",
  "version": "draft-2027-01",
  "status": "draft",
  "active": false,
  "config": {
    "metrics": {
      "craniovertebralAngle": {
        "mdcValue": 5.52, "mdcSource": "literature",
        "mdcReference": "https://www.mdpi.com/1660-4601/17/18/6521",
        "protocolVersion": "posture-v1", "improvementDirection": "higherIsBetter",
        "conditionKeys": ["protocolVersion", "view", "clothing", "station", "device.model"]
      }
    }
  }
}
```

  `conditionKeys` 문자열 표기는 metric-catalog의 `conditionKeys` 값과 같아야 한다(DF-003이 정한 표기를 따른다).
- 감사: 기존 `writeAudit` 호출(:140)이 그대로 남는다.

**테스트**
- `admin_web/test/body-change-policy.test.mjs`: `test('AC-DF-221.2 부록 A 밖 지표 거부', …)`, `test('AC-DF-221.3 mdcValue 0 거부', …)`, `test('AC-DF-221.3 literature URL 없으면 거부', …)`, `test('AC-DF-221.3 방향이 카탈로그와 다르면 거부', …)`, `test('AC-DF-221.3 conditionKeys 빈 배열 거부', …)`, `test('AC-DF-221.3 사진 지표 protocolVersion 필수', …)`, `test('AC-DF-221.3 유효한 승인본 통과', …)`
- `admin_web/test/config-schema.test.mjs`: `test('AC-DF-221.1 bodyChange는 insightPolicyVersions에서만', …)`, `test('AC-DF-221.5 integrated 회귀', …)`(zod 스키마를 `admin_web/lib/config-schema.ts`로 분리해 테스트 가능하게 한다)
- 수동: 에뮬레이터에서 v1 승인 → v2 활성화 → v1 비활성 확인(AC-DF-221.4), 스크린샷 첨부.

**비고·가정**
- ASM-P1b-30, ASM-P1b-31. P1b에 bodyChange 정책을 **활성화하지 않는 것**은 운영 규칙이다(판정 엔진이 P3, ASM-P1b-28). 화면에 '판정 엔진 도입(P3) 전에는 활성화해도 앱 표시가 바뀌지 않습니다' 안내를 둔다.

**DoR 체크**
- [x] R1 · [x] R2 · [x] R3 DF-004(P0) · [x] R4 3점 · [x] R5 · [x] R6 `admin_web/app/api/clinical/config/route.ts`, `admin_web/lib/body-change-policy.ts`, `admin_web/lib/config-schema.ts`, `admin_web/components/config-editor.tsx`, `admin_web/app/(console)/settings/insight-policies/page.tsx`, `admin_web/test/` · [x] R7 `schema-change`, `regulatory` · [x] R8 합성 정책 예시 · [x] R9 · [x] R10 해당 없음

**에이전트 브리프**
검증기 `validateBodyChangeConfig`와 테스트를 먼저 만들고 route에 연결한다. 기존 `gut`·`blood`·`integrated` 분기와 트랜잭션 코드는 바꾸지 않는다(회귀 테스트로 확인). MDC 값이나 문헌 URL을 코드 상수로 넣지 않는다 — 예시는 테스트 픽스처에만 둔다. Firestore 규칙(R-25)은 P0 범위라 건드리지 않는다.

---

### DF-211 회원 요청에 따른 사진 한 장 삭제(새 버전, 지표 유지)를 구현한다

| 항목 | 값 |
|---|---|
| Epic | EP-14 체형평가(정적 2D) |
| Type | story |
| Phase | P1b |
| Sprint | S16 (2027-01-11~01-15) — 추가 제안 채택 시 S18로 이동 |
| Points | 2 (size/S) |
| Priority | should |
| Area | trainer-app |
| Labels | `type/story` `area/trainer-app` `area/privacy` `phase/P1b` `prio/should` `size/S` `flag/bodyAssessment` `agent/claude` `privacy-impact` `rules-change`(G-P1b-2 채택 시) |
| Depends on | DF-206 |
| PRD refs | F-ASM-01.9, AC-ASM-01.7, F-ASM-04.3, §9.5, F-PRIV-07(정정·삭제 요구의 현장 처리) |

**사용자 스토리**
회원이 "그 사진은 지워 주세요"라고 하면, 트레이너로서 지표는 남기고 그 사진만 지우고 싶다. 그래야 회원 요청을 들어주면서 이전 추이가 끊기지 않는다.

**배경·맥락**
- 확정본은 수정할 수 없으므로 사진 없는 **새 버전**을 만들고 이전 버전 사진을 파기한다(F-ASM-01.9, F-ASM-04.3).
- 이전 버전은 voided가 된다. Storage 규칙은 부모가 draft일 때만 쓰기를 허용하므로 voided 부모의 사진 삭제에는 규칙 보강(G-P1b-2)이 필요하다.

**수용 기준**
1. **AC-DF-211.1** (F-ASM-01.9) Given draft의 정면 사진, When '이 사진 삭제(회원 요청)'를 확인하면, Then 로컬 파일과 Storage 객체(원본·썸네일·가림본)가 지워지고 `photoPath`·`thumbPath`·`maskedThumbPath`가 null이 되며 다시 찍을 수 있다. — 연동
2. **AC-DF-211.2** (AC-ASM-01.7) Given confirmed 평가, When 정면 사진 삭제, Then `supersedesId=이전 ID`인 새 문서가 사진 없는 정면 뷰(랜드마크 유지, ASM-P1b-36)와 **같은 `metrics`**로 확정되고, 이전 문서는 voided다. — 연동
3. **AC-DF-211.3** (AC-ASM-01.7) Given AC-DF-211.2 이후, Then 이전 버전의 모든 사진 객체가 Storage에 없다(G-P1b-2 채택 시 앱이 삭제, 미채택 시 '서버 삭제 대기' 표시와 소유자 스크립트 목록에 등재). 새 버전의 측면 사진은 새 경로에 있다(ASM-P1b-10). — 연동
4. **AC-DF-211.4** 기준선이었다면 새 버전이 기준선을 물려받는다(ASM-P1b-09). — 단위
5. **AC-DF-211.5** 사진이 없는 뷰는 TR-09·TR-10에서 '사진 삭제됨' 자리 표시를 보이고 오버레이를 그리지 않는다. 지표 표는 그대로다. — UI

**구현 노트**
- `Sources/TrainerDomain/Posture/PhotoRemovalService.swift`: `removePhoto(assessmentId:view:reason: .memberRequest)`. draft면 `deleteBinary`×3 + 경로 null update. confirmed면 `AssessmentLifecycle.supersede`(DF-209)로 새 draft를 만들고 해당 뷰 사진 참조를 비운 뒤 즉시 `confirm`(랜드마크가 확정 상태라 가능), 이전 버전 사진 삭제 작업을 `OutboxItem.deleteBinary(requiresParentStatus: .voided)`로 넣는다.
- G-P1b-2 미채택이면 `deleteBinary`가 규칙 거부를 받으므로, 이 항목을 `serverDeletionPending`으로 표시한다. 실제 삭제는 소유자용 Admin SDK 스크립트 `functions/scripts/ops/deleteVoidedPosturePhotos.js`(dry-run 기본, 수량만 출력)가 한다. 대상 조건은 `status=='voided'`이면서 `views[].photoPath`가 남은 문서다. 스크립트 작성은 이 스토리 범위에 넣고, 실행은 소유자만 한다.
- 문구 키: `tr09.photo.deleteForMember` 이 사진 삭제(회원 요청) · `tr09.photo.deleteConfirm` 지표는 남고 사진만 지워져요. 확정본이면 새 버전이 만들어져요. · `tr09.photo.deleted` 사진 삭제됨 · `tr09.photo.serverDeletionPending` 이전 버전 사진 삭제 대기.
- 감사: P1b는 `auditLogs`에 사진 삭제 이벤트가 없다(§9.7 P1a 이벤트 목록). 이유 선택값만 로컬 draft에 남긴다.

**테스트**
- `TrainerDomainTests/PhotoRemovalServiceTests.swift`: `test_AC_DF_211_1_draftPhotoRemovedAndPathsNull()`, `test_AC_ASM_01_7_confirmedCreatesNewVersionSameMetrics()`, `test_AC_DF_211_4_baselineTransfers()`
- `IntegrationTests/PhotoRemovalIT.swift`: `test_AC_ASM_01_7_previousVersionPhotosGone()`(G-P1b-2 규칙이 적용된 에뮬레이터 규칙 파일 기준; 미채택이면 `serverDeletionPending` 기대로 바뀜)
- `functions/test/unit/deleteVoidedPosturePhotos.test.js`: dry-run이 쓰기 호출 0회, 수량만 출력.

**비고·가정**
- ASM-P1b-09, ASM-P1b-10, ASM-P1b-11, ASM-P1b-36, G-P1b-2.

**DoR 체크**
- [x] R1 · [x] R2 · [x] R3 DF-206(같은 스프린트 앞순서), DF-209(S17 — confirmed 경로는 DF-209 병합 뒤 완성; 스프린트를 S18로 옮기는 제안과 맞음) · [x] R4 2점 · [x] R5 · [x] R6 `TrainerDomain/Posture/PhotoRemovalService.swift`, `FeatureAssessment/Result` 메뉴, `functions/scripts/ops/` · [ ] R7 **G-P1b-2 규칙 결정 필요**(`rules-change`) · [x] R8 합성 · [x] R9 · [x] R10 해당 없음

**에이전트 브리프**
draft 경로(AC-DF-211.1)를 먼저 끝내고, confirmed 경로는 DF-209의 `supersede`·`confirm`이 병합된 뒤에 붙인다. 규칙 파일은 고치지 않는다 — 규칙 보강 결정이 없으면 `serverDeletionPending` 경로와 소유자 스크립트로 끝낸다. 스크립트는 기본 dry-run이며 운영 프로젝트에 절대 직접 실행하지 않는다.

---

### DF-219 통증 NRS 추이(0~10 고정축, 배지 없음)를 구현한다

| 항목 | 값 |
|---|---|
| Epic | EP-15 O 자동 불러오기·비교·추이 |
| Type | story |
| Phase | P1b |
| Sprint | S16 (2027-01-11~01-15) |
| Points | 2 (size/S) |
| Priority | should |
| Area | trainer-app |
| Labels | `type/story` `area/trainer-app` `phase/P1b` `prio/should` `size/S` `flag/bodyAssessment` `agent/claude` `regulatory` |
| Depends on | DF-130, DF-117 |
| PRD refs | F-VIZ-04.4, AC-VIZ-04.3, F-VIZ-03.1, F-VIZ-03.4, F-VIZ-03.7, §7.2(painNrs reference), §7.6, C-01, C-04 |

**사용자 스토리**
트레이너로서, 회원이 말한 통증 점수가 세션마다 어떻게 기록됐는지 날짜 순으로 보고 싶다. 다만 변화 판정 배지는 없어야 한다. 그래야 통증 기록을 참고하되 효과를 단정하지 않는다.

**배경·맥락**
- `painNrs`는 wellnessMode에서 `reference` 지표라 어떤 정책 상태에서도 배지가 없다(§7.2, §7.6). 회원에게 통증 변화 문장을 보이면 통증 완화 효과 표시로 읽힐 수 있다(부록 C). P3의 참고 밴드는 이 스토리 범위 밖이다.
- y축 0~10 고정, 누락 보간 금지(F-VIZ-03.4, F-VIZ-03.7).

**수용 기준**
1. **AC-DF-219.1** (F-VIZ-04.4, F-VIZ-03.7) Given finalized 노트 3건(`painNrs` 7, 없음, 3), When TR-10 추이에서 '통증 NRS'를 고르면, Then 점 2개가 `sessionDate` 날짜 비례 위치에 있고, y축이 0~10 고정이며, 값 없는 노트는 점이 없다(0 아님). — 스냅샷·단위
2. **AC-DF-219.2** (AC-VIZ-04.3) Given 정책 상태 가짜 3종(없음, bodyChange 활성, painNrs 문헌 MDC 포함), Then 세 경우 모두 배지·밴드가 0개이고 변화 칸은 '참고 지표 · 판정하지 않음'이다. — 단위(렌더 모델)
3. **AC-DF-219.3** (C-01) 차트 머리에 출처 칩 '본인 보고'가 있고, 점 툴팁은 값·'점'·세션일·출처를 보인다. — 스냅샷
4. **AC-DF-219.4** (ASM-P1b-25) draft 노트의 NRS는 점으로 그리지 않는다. — 단위
5. **AC-DF-219.5** (AC-VIZ-04.1) 이 화면 문자열에 '근육', '진단', '치료', '완화', '개선'이 없다. — CI(copy-lint)

**구현 노트**
- `Sources/FeatureInsights/Trend/PainNrsSeriesSource.swift`: `SoapNoteStore.observeNotes(member:)`(P1a) 결과에서 `status == .finalized && subjective.painNrs != nil`만 `SeriesPoint(family: .pain, sourceGrade: .selfReport, unit: "점")`로 바꾼다. 조회는 §9.6 인덱스 `soap_notes(trainerId, memberUid, sessionDate↓)` 100건.
- 차트는 DF-130 `SeriesTrendChart`에 `yDomain: .fixed(0...10)`, `badgePolicy: .referenceNeverBadge`를 넘긴다(DF-130 API가 없으면 옵션을 추가하되 기본 동작은 바꾸지 않는다).
- TR-10 지표 선택기(DF-215)의 항목으로 들어간다. DF-215보다 먼저 병합되므로 임시로 TR-10 추이 자리 대신 TR-03 상세의 '통증 기록 보기' 시트로 연결하고, DF-215에서 선택기 항목으로 옮긴다.
- 문구 키: `tr10.metric.painNrs` 통증 점수(NRS) · `common.reference.noJudgement` 참고 지표 · 판정하지 않음 · `common.grade.selfReport` 본인 보고.

**테스트**
- `FeatureInsightsTests/PainNrsSeriesSourceTests.swift`: `test_AC_DF_219_1_missingNrsHasNoPoint()`, `test_AC_DF_219_4_draftExcluded()`
- `FeatureInsightsTests/PainNrsBadgePolicyTests.swift`: `test_AC_VIZ_04_3_noBadgeInAnyPolicyState()`
- 스냅샷: `test_AC_DF_219_1_fixedAxisDateScale()`, `test_AC_DF_219_3_sourceChipAndTooltip()`

**비고·가정**
- ASM-P1b-25.

**DoR 체크**
- [x] R1 · [x] R2 · [x] R3 DF-130(P1a S12), DF-117(P1a) · [x] R4 2점 · [x] R5 · [x] R6 `FeatureInsights/Trend/PainNrs*` · [x] R7 `regulatory`(통증 표현) · [x] R8 합성 노트 3건 · [x] R9 · [x] R10 해당 없음

**에이전트 브리프**
시리즈 변환과 '배지 없음' 렌더 모델 테스트를 먼저 쓴다. 판정·MDC·밴드 코드를 추가하지 않는다. `SeriesTrendChart`의 기존 동작을 바꾸지 말고 옵션만 추가한다. 회원 앱(Flutter)에는 NRS 추이를 만들지 않는다.

---

### DF-227 (추가 제안) 체형평가 원격 조회 저장소와 사진 바이트 캐시를 구현한다(동의 ③ 게이트, 철회 시 로컬 삭제)

| 항목 | 값 |
|---|---|
| Epic | EP-14 체형평가(정적 2D) |
| Type | story |
| Phase | P1b |
| Sprint | S16(제안, [2.1](#21-새-스토리-df-227-다음-빈-키) 재배치와 함께) |
| Points | 2 (size/S) |
| Priority | must |
| Area | trainer-app |
| Labels | `type/story` `area/trainer-app` `area/privacy` `phase/P1b` `prio/must` `size/S` `flag/bodyAssessment` `agent/claude` `privacy-impact` |
| Depends on | DF-206 |
| PRD refs | F-VIZ-02.7, AC-VIZ-02.5, NFR-17, F-PRIV-02.3(③ 행), F-SOAP-03.9, §9.5 트레이너 읽기, §9.6 쿼리 원칙, C-05 |

**사용자 스토리**
트레이너로서, 다른 날 찍은 체형평가를 목록으로 불러오고 사진은 동의가 있을 때만 받아 기기에 안전하게 두고 싶다. 회원이 촬영 동의를 철회하면 내 iPad에 남은 그 회원 사진도 사라져야 한다.

**배경·맥락**
- 트레이너 앱은 SDK 바이트 다운로드와 로컬 캐시를 쓰고 서명 URL·`getDownloadURL`을 쓰지 않는다(§9.5).
- 동의 ③ 철회 시 트레이너 앱은 사진 요청을 하지 않고(AC-VIZ-02.5), 다음 동기화에 해당 회원 로컬 사진을 지운다(NFR-17).

**수용 기준**
1. **AC-DF-227.1** (F-SOAP-03.9, §9.6) `PostureAssessmentReader.observe(member:)`는 `trainerId == uid`와 회원 키, `capturedAt` 내림차순, 100건 제한으로 조회하고, 권한·인덱스 오류를 빈 목록이 아니라 `.failed(code)`로 돌려준다. 대기 회원 키 조회는 G-P1b-4 인덱스가 있을 때만 켜고, 없으면 '승격 뒤 비교할 수 있어요' 상태를 돌려준다. — 단위(가짜 Firestore)·연동
2. **AC-DF-227.2** (AC-VIZ-02.5) Given ③이 철회된 회원, When TR-10·TR-03이 사진을 요청, Then `PhotoFetcher` 호출 수가 0이고 '사진 동의 없음'을 받는다. — 단위
3. **AC-DF-227.3** (§9.5) 사진은 `StorageReference.getData(maxSize:)`로 받아 `LocalBinary` 캐시(`NSFileProtectionComplete`, 백업 제외)에 두고, 같은 경로·같은 크기면 다시 받지 않는다. `getDownloadURL` 0건(static-guards). — 단위
4. **AC-DF-227.4** (NFR-17 수용 기준, F-PRIV-02.3) Given 회원의 사진 캐시·로컬 원본이 있는 상태에서 ③ 철회가 `memberConsentStates`에 반영, When 다음 동기화 주기, Then 그 회원의 `Posture/` 로컬 파일과 캐시가 0건이고 대기 중인 사진 업로드가 취소된다. — 단위·연동
5. **AC-DF-227.5** (NFR-17) 업로드 확인 7일이 지난 로컬 원본은 정리 작업이 지운다. 다운로드 캐시는 최근 사용 순으로 용량 상한까지만 둔다(상한은 V1-07 설정 절 값, 정해지기 전에는 ASM-P1b-41). — 단위

**구현 노트**
- `Sources/FirebaseData/Posture/FirestorePostureAssessmentReader.swift`(TrainerDomain 프로토콜 `PostureAssessmentReading` 구현), `Sources/FirebaseData/Storage/StoragePhotoFetcher.swift`, `Sources/TrainerDomain/Posture/PhotoAccessGate.swift`(동의 ③ 서버 상태 확인), `Sources/LocalStore/Maintenance/PostureLocalPurger.swift`(철회·7일 정리).
- 철회 감지는 `ConsentService.observeState` 스트림 변화(③ true→false)에서 시작하고, 동기화 주기(`SyncEngine` tick)에서 실행한다.
- 이 스토리가 채택되지 않으면 AC-DF-227.1~.3은 DF-214, AC-DF-227.4~.5는 DF-206으로 옮긴다([2.1](#21-새-스토리-df-227-다음-빈-키)).

**테스트**
- `FirebaseDataTests/PostureAssessmentReaderTests.swift`: `test_AC_DF_227_1_queryHasTrainerIdAndOrdering()`, `test_AC_DF_227_1_errorNotSwallowed()`
- `TrainerDomainTests/PhotoAccessGateTests.swift`: `test_AC_VIZ_02_5_noFetchWithoutBodyImaging()`
- `LocalStoreTests/PostureLocalPurgerTests.swift`: `test_NFR_17_withdrawalPurgesLocalPhotos()`, `test_NFR_17_sevenDayCleanup()`
- `IntegrationTests/PostureReadIT.swift`: `test_AC_DF_227_1_emulatorQueryProvableByRules()`

**비고·가정**
- ASM-P1b-12, ASM-P1b-27, G-P1b-4.

**DoR 체크**
- [x] R1 · [x] R2 · [x] R3 DF-206(같은 스프린트 앞순서) · [x] R4 2점 · [x] R5 · [x] R6 `FirebaseData/Posture`, `FirebaseData/Storage/StoragePhotoFetcher.swift`, `TrainerDomain/Posture/PhotoAccessGate.swift`, `LocalStore/Maintenance` · [x] R7 `privacy-impact` · [x] R8 합성 · [ ] R9 채택 뒤 지시서 · [x] R10 해당 없음

**에이전트 브리프**
채택된 경우에만 착수한다. 조회 쿼리에 `trainerId == uid`가 빠지는 코드 경로를 만들지 않는다(규칙이 목록 쿼리를 증명하지 못해 전체가 실패한다). 동의 확인 없이 사진 바이트를 받는 경로를 만들지 않는다. 화면 코드는 건드리지 않는다.

---
### DF-209 체형 확정, 새 버전(supersedesId), voided, 기준선 규칙을 구현한다

| 항목 | 값 |
|---|---|
| Epic | EP-14 체형평가(정적 2D) |
| Type | story |
| Phase | P1b |
| Sprint | S12(MVP 계획, DEC-22, [03 MVP 계획](../03_RELEASE_AND_SPRINT_PLAN.md#mvp-계획dec-22)). 원래 계획: S17 (2027-01-18~01-22) — 1일차에 프로토콜 PR 먼저(G-P1b-8) |
| Points | 5 (size/L) |
| Priority | must |
| Area | trainer-app |
| Labels | `type/story` `area/trainer-app` `phase/P1b` `prio/must` `size/L` `flag/bodyAssessment` `agent/claude` `scope/mvp` |
| Depends on | DF-208, DF-206 |
| PRD refs | F-ASM-04.1, F-ASM-04.2, F-ASM-04.3, F-ASM-04.4, F-ASM-04.6, AC-ASM-04.1, AC-ASM-04.2, AC-ASM-04.3, AC-ASM-04.4, AC-ASM-04.5, AS-33, M-04b, §9.4 postureAssessments update |

**사용자 스토리**
트레이너로서, 확정한 체형평가는 바뀌지 않고, 다시 보정하면 새 버전이 생기며, 회원·측면 방향마다 기준선이 하나만 있기를 원한다. 그래야 비교 기준이 흔들리지 않는다.

**배경·맥락**
- 상태는 `draft → confirmed → voided`로만 바뀐다. draft는 추이·판정에서 빠지고, confirmed만 추이·SOAP 참조 대상이다(F-ASM-04.1).
- confirmed 문서는 `status(→voided)`, `isBaseline`, `updatedAt`만 바꿀 수 있다(§9.4, [V1-05 §4.6](../05_DATA_MODEL_AND_RULES.md) 상태 전이 표). 원소 단위 확정 검증은 규칙이 못 하므로 도메인 단위 테스트가 보장한다(AC-ASM-04.1).

**수용 기준**
1. **AC-DF-209.1** (AC-ASM-04.1) Given 필수 랜드마크 하나가 미확정, Then `AssessmentLifecycle.confirm`이 `ConfirmError.requiredLandmarksMissing([codes])`를 던지고 TR-08·TR-09 '확정'이 비활성이다. — 단위
2. **AC-DF-209.2** (F-ASM-04.1, ASM-P1b-06·07) Given 확정 가능, When `confirm`, Then 확정 랜드마크로 지표를 다시 계산해 모두 `photoManual`로 저장하고(`pelvicTiltFrontal`은 옵션이 켜졌고 계산 가능할 때만), 로컬 상태가 `pendingConfirm`, Outbox 항목 #5(DF-206 표)가 생긴다. — 단위
3. **AC-DF-209.3** (AC-ASM-04.2) Given 에뮬레이터에 confirmed 문서, When 앱이 `metrics` 또는 `views`를 바꾸는 update를 보내도록 강제(테스트 훅), Then 규칙 거부 → `syncFailed`이고 로컬 확정본은 그대로다. — 연동
4. **AC-DF-209.4** (AC-ASM-04.3) Given confirmed A, When '수정(새 버전)', Then `supersedesId=A`인 새 draft B가 생기고(A의 랜드마크·조건·`capturedAt`·`retestGroupId` 복사, 사진은 새 경로로 다시 업로드, ASM-P1b-10), B를 확정하면 A가 `voided`가 된다(Outbox #6). — 단위·연동
5. **AC-DF-209.5** (AC-ASM-04.4) `voided` 문서는 `AssessmentQueries.history`, 기준선 후보, O 불러오기 후보(DF-217), 추이(DF-215) 입력에서 빠진다(공통 필터 함수 하나). — 단위
6. **AC-DF-209.6** (F-ASM-04.4, AS-33, ASM-P1b-08) Given 회원 × `sagittalLeft`에 기준선이 없음, When 첫 확정, Then 확정 화면의 '기준선' 토글이 켜진 채 제시되고 그대로 확정하면 `isBaseline=true`. Given 기준선 A가 있고 C를 기준선으로 지정, Then 한 번의 Outbox 묶음으로 A `isBaseline=false`, C `true`가 되고 같은 회원·같은 측면 방향에 `isBaseline=true`는 항상 1개 이하다. 다른 측면 방향의 기준선은 영향이 없다. — 단위·연동
7. **AC-DF-209.7** (ASM-P1b-09) Given 기준선 A를 새 버전 B로 대체, When B 확정, Then B `isBaseline=true`, A는 `status=voided, isBaseline=false`(한 update). 이미 저장된 SOAP 스냅샷은 바뀌지 않는다(F-ASM-04.4). — 단위
8. **AC-DF-209.8** (M-04b) 확정이 로컬에 저장되면 `posture_landmarks_confirmed{manual_adjust_count_band, engine_version, elapsed_band}`를 한 번 보낸다(`elapsed`는 DF-208의 `calibrationStartedAt`부터). — 단위
9. **AC-DF-209.9** (F-ASM-04.6) `capturedAt`은 확정·새 버전에서 바뀌지 않고 `createdAt`·`updatedAt`만 서버 시각이다. — 단위
10. **AC-DF-209.10** (ASM-P1b-13) 확정 시 가림본이 없던 뷰는 확정 좌표로 머리 상자 가림본을 만든다(DF-205 API 호출). — 단위

**구현 노트**
- 1일차 프로토콜 PR(`Sources/TrainerDomain/Posture/AssessmentLifecycle.swift`): 다른 S17 스토리가 쓸 수 있도록 먼저 병합한다.

```swift
public protocol AssessmentLifecycle: Sendable {
  func confirm(_ id: AssessmentID, options: MetricOptions, setBaseline: Bool) throws -> ConfirmResult   // .pendingSync | .confirmedLocally
  func supersede(_ id: AssessmentID) throws -> AssessmentID                                            // 새 draft
  func setBaseline(_ id: AssessmentID) throws                                                          // confirmed만
  func history(member: MemberKey) -> AsyncThrowingStream<[AssessmentSummary], Error>                    // voided 제외, 재검사 첫 기록만(DF-212)
}
public struct AssessmentSummary: Sendable {
  public var id: AssessmentID; public var capturedAt: Date; public var status: AssessmentStatus
  public var sagittalView: PostureView; public var isBaseline: Bool; public var supersedesId: AssessmentID?
  public var retestGroupId: String?; public var metrics: [PostureMetricResult]; public var syncState: SyncState
  public var protocolVersion: String; public var deviceModel: String; public var conditions: ConditionSnapshot
}
```

  `FakeAssessmentLifecycle`(테스트·`--preview-*`용)도 같은 PR에 넣는다.
- 구현: `Sources/TrainerDomain/Posture/DefaultAssessmentLifecycle.swift`(PostureMath `confirmability`·`computeMetrics` 호출, LocalStore 갱신, SyncEngine Outbox 등록)(이 위치는 모듈 경계·순환 문제로 잠정이다. [G-P1b-9](#22-스파인다른-문서와의-충돌보강-요청), V1-00 K-10 결정 대기, ASM-P1b-43), `Sources/TrainerDomain/Posture/BaselinePolicy.swift`(회원×측면 방향 유일성, 첫 확정 기본 켬, 재검사 묶음은 첫 기록만 후보), `Sources/TrainerDomain/Posture/AssessmentFilters.swift`(`activeConfirmed`, voided 제외).
- 기준선 교체는 Outbox 묶음 두 항목(해제 → 지정)으로 넣고, 해제가 실패하면 지정도 보내지 않는다(`dependsOn`). 서버 시점에 잠깐 두 개가 되는 틈은 없다: 해제가 먼저 커밋된다.
- 새 버전 사진: `PhotoRebaser.copyPhotos(from:to:)` — 로컬 원본(7일 안) → 없으면 캐시 → 없으면 `StoragePhotoFetcher`(DF-227 또는 DF-214)로 받아 새 경로로 업로드 항목 생성.
- 화면: `Sources/FeatureAssessment/Result/ConfirmSheet.swift`(확정 요약, 기준선 토글, 골반 기울기(참고) 계산 토글 — 기본 꺼짐), `Sources/FeatureAssessment/Lifecycle/SupersedeAction.swift`('수정(새 버전)' 메뉴). 확정본에는 삭제 메뉴가 없다.
- 문구 키: `tr09.action.confirm` 확정 · `tr09.action.newVersion` 수정(새 버전) · `tr09.baseline.toggle` 이 기록을 기준선으로 · `tr09.baseline.replaceNotice` 기존 기준선({date})이 해제돼요 · `tr09.status.pendingConfirm` 확정 대기 · `tr09.status.voided` 무효 처리됨 · `tr09.pelvicToggle` 골반 기울기(참고) 계산.
- 접근성 식별자: `tr09.confirm`, `tr08.confirmAssessment`(같은 동작), `tr09.newVersion`, `tr09.baselineToggle`.

**테스트**
- `TrainerDomainTests/AssessmentLifecycleTests.swift`: `test_AC_ASM_04_1_confirmBlockedWhenRequiredUnconfirmed()`, `test_AC_DF_209_2_confirmComputesPhotoManualMetrics()`, `test_AC_ASM_04_3_supersedeCreatesDraftAndVoidsOld()`, `test_AC_ASM_04_4_voidedExcludedEverywhere()`, `test_AC_DF_209_9_capturedAtImmutable()`
- `TrainerDomainTests/BaselinePolicyTests.swift`: `test_AC_DF_209_6_firstConfirmSuggestsBaseline()`, `test_AC_DF_209_6_singleBaselinePerMemberAndSide()`, `test_AC_DF_209_7_baselineTransfersOnSupersede()`
- `TrainerAnalyticsTests/PostureConfirmEventTests.swift`: `test_AC_DF_209_8_landmarksConfirmedEvent()`
- `IntegrationTests/PostureLifecycleIT.swift`: `test_AC_ASM_04_2_confirmedMetricsUpdateRejected()`, `test_AC_ASM_04_3_supersedeEndToEnd()`, `test_AC_DF_209_6_baselineSwapNeverTwo()`

**비고·가정**
- ASM-P1b-06, ASM-P1b-07, ASM-P1b-08, ASM-P1b-09, ASM-P1b-10, G-P1b-8.
- P2 `verifyPostureConfirmed`(DF-324)가 서버에서 같은 확정 조건을 다시 검사한다. 조건 정의는 PostureMath `LandmarkRequirements` 하나를 기준으로 V1-09에 적어 두어 JS 구현이 따라갈 수 있게 한다.

**DoR 체크**
- [x] R1 · [x] R2 · [x] R3 DF-208·DF-206(S16) · [x] R4 5점 · [x] R5 · [x] R6 `TrainerDomain/Posture`, `FeatureAssessment/Result/ConfirmSheet.swift`, `FeatureAssessment/Lifecycle` · [x] R7 없음(규칙 변경 없음) · [x] R8 합성 회원·기준선 시나리오 · [x] R9 · [x] R10 해당 없음

**에이전트 브리프**
1일차에 `AssessmentLifecycle` 프로토콜·`AssessmentSummary`·가짜 구현만 담은 작은 PR을 먼저 올려 병합받는다(다른 세 스토리가 기다린다). 그다음 기준선 유일성·voided 제외 단위 테스트, 마지막에 에뮬레이터 연동 테스트를 쓴다. confirmed 문서의 `metrics`·`views`를 바꾸는 코드 경로를 만들지 않는다(연동 테스트의 강제 훅은 `#if DEBUG` 테스트 전용). 편위 표(DF-210)와 TR-10(DF-214)은 건드리지 않는다.

### MVP 범위(DEC-22)

- MVP 스프린트: S12(원래 계획 S17). 상태: 할 일
- 왜 필요한가: 흐름 3: 체형 확정·새 버전·기준선
- 지금 만든다: 카드 전체 범위에서 아래 두 AC만 뺀다
- MVP 뒤로 미룬다: AC-DF-209.10(확정 시 머리 상자 가림본, DF-205 `FaceMasker` 연기와 같다). AC-DF-209.8(`posture_landmarks_confirmed`)과 `TrainerAnalyticsTests/PostureConfirmEventTests.swift`(분석 이벤트 AC는 MVP 뒤, DF-126·DF-033)
- `PhotoRebaser`(새 버전 사진)는 로컬 파일만 쓴다: 로컬 원본 → 캐시. 둘 다 없으면 원격에서 받지 않고 '사진 없음'으로 새 draft를 만들어 다시 찍게 한다. `StoragePhotoFetcher`(DF-227·DF-214, MVP 밖)는 만들지 않는다. 한 기기·한 트레이너 MVP에서는 원본이 기기에 있다
- 새 버전(AC-DF-209.4)은 A의 `stationProfileId`(MVP 기본 `default-v1`, DF-203 MVP 절)와 `captureConditions`(복장 선택, 세 불리언 `false`, 수평 값이 없으면 없는 그대로)를 바꾸지 않고 복사한다. 확정 조건(AC-DF-209.1)은 체크리스트 값을 보지 않는다
- 재검사(DF-212)는 MVP 뒤다. MVP의 체형 문서는 `retestGroupId = null`이고 복사 값도 null이다. `history`의 '재검사 첫 기록만' 필터와 `BaselinePolicy`의 재검사 묶음 규칙은 null이면 영향이 없으므로 null 경로만 테스트한다

---

### DF-210 TR-09 결과 화면과 자세 편위 표를 구현한다('산정 준비 중')

| 항목 | 값 |
|---|---|
| Epic | EP-15 O 자동 불러오기·비교·추이 |
| Type | story |
| Phase | P1b |
| Sprint | S12(MVP 계획, DEC-22, [03 MVP 계획](../03_RELEASE_AND_SPRINT_PLAN.md#mvp-계획dec-22)). 원래 계획: S17 (2027-01-18~01-22) |
| Points | 3 (size/M) |
| Priority | must |
| Area | trainer-app |
| Labels | `type/story` `area/trainer-app` `area/design` `phase/P1b` `prio/must` `size/M` `flag/bodyAssessment` `agent/claude` `regulatory` `scope/mvp` |
| Depends on | DF-209, DF-130 |
| PRD refs | F-VIZ-01.1~01.6, F-ASM-03.7, AC-VIZ-01.1~01.5, AC-ASM-03.5, AC-C-01.1, AC-C-03.1, AC-C-03.2, §6.5.0, §8.4 TR-09, A-01, A-03, TR-09 |

**사용자 스토리**
트레이너로서, 확정한 체형평가의 지표를 값·측면·출처와 함께 한 표로 보고, 기준선 대비 차이를 확인하고 싶다. 다만 판정 배지는 정책이 생기기 전까지 '산정 준비 중'이어야 한다.

**배경·맥락**
- 편위 표는 부록 A 가용성 v1·v1(참고) 코드만 행으로 그린다. 합계·평균·'체형 점수'·등급·진단성 라벨은 없다(F-VIZ-01.1, F-VIZ-01.6).
- 변화 상태 열: draft '확정 전', 참고 지표 '참고 지표 · 판정하지 않음', 그 외 '산정 준비 중'(F-VIZ-01.3, ASM-P1b-28). MDC 열은 P3라 P1b 표에는 두지 않는다.
- 렌더러는 TR-09와 TR-10이 함께 쓴다. 모듈 의존 때문에 `DesignSystem`에 둔다(G-P1b-5, ASM-P1b-38).

**수용 기준**
1. **AC-DF-210.1** (AC-VIZ-01.1) Given `metrics`에 카탈로그에 없는 코드(`legacyScore`), Then 그 행이 없고 DEBUG 빌드에서 `os.Logger` 경고가 metricCode만(값 없이) 남는다. — 단위
2. **AC-DF-210.2** (AC-VIZ-01.2) `headTiltFrontal`·`pelvicTiltFrontal` 행에는 배지가 없고 '참고' 칩과 변화 칸 '참고 지표 · 판정하지 않음'이 있다. — 단위·스냅샷
3. **AC-DF-210.3** (AC-VIZ-01.3, AC-C-03.1) P1b에서 모든 변화 칸(참고 제외)이 '산정 준비 중'이고 값·단위·출처 칩은 그대로 보인다. — 스냅샷
4. **AC-DF-210.4** (AC-VIZ-01.4, F-VIZ-01.4) draft 미리보기에서 Δ 열이 비어 있고 변화 칸이 '확정 전'이다. 미확정 랜드마크로 계산된 행은 '스크리닝' 칩과 점선 테두리다. — 스냅샷
5. **AC-DF-210.5** (F-VIZ-01.2) 비교 기준은 같은 회원·같은 측면 방향 기준선(confirmed)이다. 현재 기록과 기준선이 같은 세그먼트(DF-216 `compare`가 nil)일 때만 Δ = 현재 − 기준(반올림 저장값끼리, 예 `+2.4°`)을 보이고, 다르면 Δ 칸에 '—'와 '판정 불가 · {사유}' 보조 문구를 보인다. 기울기 지표 Δ는 크기(θ)로 계산하고 측면이 바뀌면 '측면 바뀜'을 붙인다(§7.5). — 단위
6. **AC-DF-210.6** (F-VIZ-01.5) 행을 탭하면 TR-10 추이가 그 `metricCode`·`sourceGrade`로 열린다. — UI
7. **AC-DF-210.7** (AC-VIZ-01.5, AC-ASM-03.5, F-ASM-03.7) 표와 TR-09 문자열이 금지어 린트를 통과하고, 지표 부제는 관찰 문구('머리 전방 자세 관찰', '어깨 높이 차이 관찰')다. — CI
8. **AC-DF-210.8** (A-01, A-03, AC-C-01.3) 가장 큰 글자 크기에서 표가 카드형 세로 배치로 바뀌고 값이 잘리지 않으며, VoiceOver가 "두개척추각 45.0도, 측면 없음, 출처 사진 측정 확정, 1월 18일, 변화 산정 준비 중"처럼 읽는다. — UI(스냅샷은 DF-226)
9. **AC-DF-210.9** (§8.4 TR-09) 동의 ③이 없으면 사진·오버레이 영역 대신 '사진 동의 없음'이 보이고 지표 표는 그대로다. — UI

**구현 노트**
- 행 조립(`Sources/TrainerDomain/Posture/DeviationRowBuilder.swift`): `build(current: AssessmentSummary, baseline: AssessmentSummary?, catalog: MetricCatalog, isDraft: Bool) -> [DeviationRow]`. `DeviationRow {metricCode, nameKey, viewLabelKey, valueText, unit, sideLabelKey, sourceGrade, reliabilityChip(.reference|nil), deltaText?, deltaNoteKey?, changeCell: .draft | .pendingPolicy | .referenceNoJudgement, dashedBorder: Bool}`. 판정 결과 enum 값(`meaningfulImprovement` 등)을 만들지 않는다.
- 렌더러(`Sources/DesignSystem/Posture/PostureDeviationTable.swift`): 열 순서 F-VIZ-01.2(MDC 열 제외). 값은 등폭 숫자(`.monospacedDigit()`), `SourceGradeChip`(DF-016) 재사용, `ChangeBadge`는 P1b에서 `.pendingPolicy`와 `.referenceNoJudgement`만 그린다.
- 화면(`Sources/FeatureAssessment/Result/AssessmentResultView.swift`, `/// TR-09`): 상단 상태(확정 전/확정 대기/확정/무효 처리됨 + `SyncStateBadge`), 오버레이(DF-208 `PostureOverlayCanvas`, 읽기 전용), 편위 표, 기준선 표시, '수정(새 버전)'(DF-209), '재검사 모드'(DF-212), 사진 메뉴(DF-211). '회원 리포트 만들기'는 P2라 만들지 않는다(진입점 없음).
- 문구 키: `metric.craniovertebralAngle.name` 두개척추각(CVA) · `metric.craniovertebralAngle.subtitle` 머리 전방 자세 관찰 · `metric.shoulderTiltAngle.name` 어깨 높이차 · `metric.shoulderTiltAngle.subtitle` 어깨 높이 차이 관찰 · `metric.headTiltFrontal.name` 머리 기울기(참고) · `metric.pelvicTiltFrontal.name` 골반 기울기(참고) · `metric.pelvicTiltFrontal.subtitle` 골반 좌우 높이 차이 관찰 · `common.pendingPolicy` 산정 준비 중 · `common.reference.noJudgement` 참고 지표 · 판정하지 않음 · `tr09.status.draft` 확정 전 · `common.chip.screening` 스크리닝 · `common.grade.photoManual` 사진 측정(확정) · `common.grade.photoAuto` 사진 자동 추정 · 스크리닝 · `tr09.delta.sideSwitched` 측면 바뀜 · `common.indeterminate.withReason` 판정 불가 · {reason} · `reason.protocolChanged` 프로토콜 변경 · `reason.deviceChanged` 기기 변경 · `reason.conditionMismatch` 조건 불일치 · `reason.noComparison` 비교 기록 없음.
- 분석: 변화 칸이 처음 그려질 때 `change_status_rendered{surface:"trainer"}` 1회(값·상태 없음).

**테스트**
- `TrainerDomainTests/DeviationRowBuilderTests.swift`: `test_AC_VIZ_01_1_unknownMetricNoRow()`, `test_AC_VIZ_01_2_referenceRowsNoBadge()`, `test_AC_VIZ_01_3_allPendingPolicy()`, `test_AC_VIZ_01_4_draftDeltaEmpty()`, `test_AC_DF_210_5_deltaOnlyWithinSameSegment()`, `test_AC_DF_210_5_tiltDeltaByMagnitudeAndSideSwitch()`, `test_AC_C_03_2_indeterminateAlwaysHasReason()`
- 스냅샷(`FeatureAssessmentTests/ResultSnapshotTests.swift`): `test_AC_VIZ_01_3_pendingPolicySnapshot()`, `test_AC_VIZ_01_4_draftScreeningSnapshot()`, `test_AC_DF_210_9_noPhotoConsent()`
- UI: `test_AC_DF_210_6_rowTapOpensTrend()`, `test_AC_DF_210_8_voiceOverSentence()`
- CI copy-lint: AC-DF-210.7

**비고·가정**
- ASM-P1b-07, ASM-P1b-28, ASM-P1b-38, G-P1b-5.

**DoR 체크**
- [x] R1 · [x] R2 · [x] R3 DF-209(같은 스프린트, 프로토콜 PR 선병합), DF-130(P1a) · [x] R4 3점 · [x] R5 · [x] R6 `TrainerDomain/Posture/DeviationRowBuilder.swift`, `DesignSystem/Posture/PostureDeviationTable.swift`, `FeatureAssessment/Result/AssessmentResultView.swift` · [x] R7 `regulatory` · [x] R8 합성 평가 2건(기준선·현재) · [x] R9 · [x] R10 해당 없음

**에이전트 브리프**
`DeviationRowBuilder` 단위 테스트로 열 규칙과 '산정 준비 중'을 먼저 고정한다. 판정 로직·MDC·점수·합계를 만들지 않는다. 확정·새 버전 로직(DF-209)과 오버레이 캔버스(DF-208)는 호출만 한다. 금지어 목록을 보고 지표 부제를 관찰 문구로만 쓴다.

### MVP 범위(DEC-22)

- MVP 스프린트: S12(원래 계획 S17). 상태: 할 일
- 왜 필요한가: 흐름 3: TR-09 결과 화면과 편위 표('산정 준비 중')
- 지금 만든다: 카드 전체 범위(분석 이벤트 제외)에서 아래 두 메뉴만 뺀다. 상태 표시, 오버레이, 편위 표, 기준선 표시, '수정(새 버전)'(DF-209)은 만든다
- MVP 뒤로 미룬다: '재검사 모드'(DF-212: `retestGroupId` 태깅, 동의 ⑤·연구 동의서 게이트)와 사진 메뉴(DF-211: 회원 요청에 따른 사진 한 장 삭제). 두 메뉴는 버튼·빈 슬롯·'추후 추가 예정' 화면도 두지 않는다(진입점 없음). 구현 노트의 화면 목록에서 이 둘을 뺀다
- 분석 이벤트 AC는 MVP 뒤(DF-126·DF-033): `change_status_rendered{surface:"trainer"}` 전송은 만들지 않는다

---

### DF-214 TR-10 나란히·겹쳐 보기(표시 전용 정렬, 조건 불일치 배너, 동의 ③ 게이트)를 구현한다

| 항목 | 값 |
|---|---|
| Epic | EP-15 O 자동 불러오기·비교·추이 |
| Type | story |
| Phase | P1b |
| Sprint | S17 (2027-01-18~01-22) |
| Points | 5 (size/L) |
| Priority | must |
| Area | trainer-app |
| Labels | `type/story` `area/trainer-app` `phase/P1b` `prio/must` `size/L` `flag/bodyAssessment` `agent/claude` `privacy-impact` |
| Depends on | DF-209, DF-216 |
| PRD refs | F-VIZ-02.1, F-VIZ-02.3, F-VIZ-02.4, F-VIZ-02.5, F-VIZ-02.6, F-VIZ-02.7, AC-VIZ-02.3, AC-VIZ-02.4, AC-VIZ-02.5, F-ASM-05(재검사 묶음 보기), §8.4 TR-10, TR-10 |

**사용자 스토리**
트레이너로서, 두 시점의 같은 방향 사진을 나란히 또는 겹쳐 보며 회원에게 변화를 설명하고 싶다. 다만 촬영 조건이 다르면 차이를 숫자로 보이지 않아야 한다.

**배경·맥락**
- 겹쳐 보기 정렬은 기준 랜드마크 하나와 신체 높이 비율로 맞추는 **표시 전용**이며 지표를 다시 계산하지 않는다(F-VIZ-02.5).
- 조건 불일치(§7.4)면 나란히 보기는 허용하되 '판정 불가 · {사유}' 배너를 보이고 Δ를 숨긴다(F-VIZ-02.6).
- 동의 ③이 없으면 사진을 요청하지 않고 좌표 도식도 보이지 않는다(F-VIZ-02.7). ③ 철회 시 좌표는 서버에서 파기된다(F-PRIV-02.3).

**수용 기준**
1. **AC-DF-214.1** (F-VIZ-02.4) Given 같은 회원·같은 view의 confirmed 기록 2개 이상, When TR-10 '전후 비교'에서 두 기록을 고르면, Then 좌우에 사진과 각 사진의 `capturedAt`, `protocolVersion`, 기기 모델이 보인다. 다른 view끼리는 고를 수 없다(정면 ↔ 정면, 측면은 같은 측면 방향끼리 기본, 다른 측면 방향은 선택 가능하되 AC-DF-214.3 배너). — UI
2. **AC-DF-214.2** (F-VIZ-02.5, AC-VIZ-02.4) Given 겹쳐 보기, When 불투명도 슬라이더(0~100%)와 정렬 기준을 바꿔도, Then 두 문서의 `metrics`가 바뀌지 않고(동등성 검사) 화면에 '정렬은 보기용' 문구가 항상 보인다. — 단위·UI
3. **AC-DF-214.3** (AC-VIZ-02.3, F-VIZ-02.6) Given `protocolVersion`이 다른 두 기록, Then 겹쳐·나란히 보기 모두 Δ가 없고 '판정 불가 · 프로토콜 변경(protocolChanged)' 배너가 보인다. 기기 변경·측면 방향·복장 차이도 같은 방식(DF-216 `compare` 사유). — 단위·스냅샷
4. **AC-DF-214.4** (AC-VIZ-02.5, F-VIZ-02.7) Given ③이 철회된 회원, When TR-10을 열면, Then 사진 바이트 요청 0회(가짜 `PhotoFetching` 호출 수 0), 사진·좌표 도식 대신 '사진 동의 없음'이 보이고 지표 값 비교(DF-215 추이)는 그대로 쓸 수 있다. — 단위·UI
5. **AC-DF-214.5** (F-VIZ-02.1, F-VIZ-02.3) 두 사진 모두 `imageRotationDeg` 보정 좌표계로 그리고, 각 지표 계산 선(DF-208 도형)을 켜고 끌 수 있다. — 스냅샷
6. **AC-DF-214.6** (F-ASM-05, TR-10 '재검사 묶음 보기') Given `retestGroupId` 묶음, When '재검사 묶음'을 열면, Then 묶음 기록이 촬영 순으로 나열되고 첫 확정 기록에 '추이 반영' 표시가 있다(DF-212 필터). — UI
7. **AC-DF-214.7** (§8.4 TR-10 빈 상태) confirmed 기록이 1개 이하면 '비교할 기록이 한 건뿐이에요' 빈 상태와 'TR-07 촬영' 버튼(플래그 켜짐일 때만). 조회 오류는 '불러오기 실패'와 재시도. — UI

**구현 노트**
- 화면(`Sources/FeatureInsights/Compare/`): `CompareView.swift`(`/// TR-10` 전후 비교 탭), `CompareViewModel.swift`, `OverlayAlignment.swift`(순수: 기준 랜드마크 — 측면 `c7`, 정면 좌우 견봉 중점 — 로 평행 이동, 배율 = 측면 `tragus–c7` 거리 비, 정면 귀 중점–견봉 중점 거리 비. 결과는 `CGAffineTransform`만 돌려주고 지표를 건드리지 않는다), `RetestGroupListView.swift`.
- 조건 비교: `SeriesSegmenter.compare(a.conditions, b.conditions, family: .posture)`(DF-216). Δ 표시는 DF-210 `DeviationRowBuilder`와 같은 규칙.
- 데이터: `AssessmentLifecycle.history(member:)`(DF-209) + 사진 바이트는 `PhotoAccessGate`·`StoragePhotoFetcher`(DF-227). **대안(DF-227 미채택 시)**: 이 스토리가 `FirestorePostureAssessmentReader`와 `StoragePhotoFetcher`, `PhotoAccessGate`를 같은 경로에 만든다(AC-DF-227.1~.3을 여기로 옮김).
- 문구 키: `tr10.tab.compare` 전후 비교 · `tr10.mode.sideBySide` 나란히 · `tr10.mode.overlay` 겹쳐 보기 · `tr10.alignNote` 정렬은 보기용 · `tr10.opacity` 불투명도 {value}% · `tr10.banner.indeterminate` 판정 불가 · {reason} · `tr10.noPhotoConsent` 사진 동의 없음 · `tr10.empty.single` 비교할 기록이 한 건뿐이에요 · `tr10.retest.title` 재검사 묶음 · `tr10.retest.usedInTrend` 추이 반영.
- 접근성 식별자: `tr10.mode.sideBySide`, `tr10.mode.overlay`, `tr10.opacitySlider`, `tr10.pickA`, `tr10.pickB`, `tr10.retestGroup`. 불투명도 슬라이더는 VoiceOver 조정 동작 10% 단위.

**테스트**
- `FeatureInsightsTests/OverlayAlignmentTests.swift`: `test_AC_VIZ_02_4_alignmentDoesNotChangeMetrics()`, `test_AC_DF_214_2_scaleFromTragusC7Distance()`
- `FeatureInsightsTests/CompareViewModelTests.swift`: `test_AC_VIZ_02_3_protocolChangedHidesDelta()`, `test_AC_DF_214_3_deviceChangedBanner()`, `test_AC_VIZ_02_5_noPhotoFetchWithoutConsent()`, `test_AC_DF_214_7_loadErrorNotEmpty()`
- 스냅샷: `test_AC_DF_214_5_sideBySideRotationCorrected()`, `test_AC_DF_214_3_bannerSnapshot()`
- UI: `test_AC_DF_214_6_retestGroupList()`(`--preview-state=tr10.retestGroup`)

**비고·가정**
- ASM-P1b-18, G-P1b-4(대기 회원은 인덱스 전까지 '승격 뒤 비교' 상태).

**DoR 체크**
- [x] R1 · [x] R2 · [x] R3 DF-209(같은 스프린트, 프로토콜 PR 선병합), DF-216(S15), DF-227(제안, S16) · [x] R4 5점 · [x] R5 · [x] R6 `FeatureInsights/Compare` (+대안 시 `FirebaseData/Posture`, `FirebaseData/Storage`) · [x] R7 `privacy-impact` · [x] R8 합성 평가 쌍(같은 조건·프로토콜 다름·기기 다름) · [x] R9 · [x] R10 해당 없음

**에이전트 브리프**
`OverlayAlignment`가 지표를 바꾸지 않는다는 테스트와 동의 ③ 게이트 테스트를 먼저 쓴다. 정렬 결과를 저장하거나 지표 재계산에 쓰지 않는다. 추이 차트(DF-215)와 편위 표 렌더러(DF-210)는 건드리지 않는다. 사진을 `getDownloadURL`로 받지 않는다.

---

### DF-212 재검사 모드 retestGroupId 태깅과 동의 ⑤·연구 동의서 게이트를 구현한다

| 항목 | 값 |
|---|---|
| Epic | EP-14 체형평가(정적 2D) |
| Type | story |
| Phase | P1b |
| Sprint | S17 (2027-01-18~01-22) — DF-209 본체가 3일차까지 병합되지 않으면 S18로 이동(G-P1b-8) |
| Points | 3 (size/M) |
| Priority | must |
| Area | trainer-app |
| Labels | `type/story` `area/trainer-app` `area/privacy` `phase/P1b` `prio/must` `size/M` `flag/bodyAssessment` `agent/claude` `privacy-impact` |
| Depends on | DF-209 |
| PRD refs | F-ASM-05.1, F-ASM-05.2, F-ASM-05.3, AC-ASM-05.1, AC-ASM-05.2, R-16, §7.3.3, §12.6, G-06 |

**사용자 스토리**
연구 책임자(소유자)로서, 연구에 동의한 회원만 같은 날 독립 재배치로 여러 번 찍고 하나의 묶음으로 태깅하고 싶다. 그래야 G-06 재검사 연구 자료가 모이면서도 회원 추이에는 한 번만 반영된다.

**배경·맥락**
- 재검사 모드는 동의 ⑤와, G-06 IRB가 승인한 별도 서면 연구참여 동의서가 있어야 켜진다. ⑤는 그 서면 동의 사실을 기록한다(F-ASM-05.2). 거부해도 운동 지도에 불이익이 없음을 고지한다(자발성 보호, §12.6).
- 실제 재검사 촬영은 IRB 승인(DF-912) 뒤에만 한다. 코드는 합성 데이터로 먼저 만든다(외부 게이트는 코딩을 막지 않음).
- 한 묶음의 첫 확정 기록만 회원 추이와 SOAP 불러오기에 쓴다(F-ASM-05.3).

**수용 기준**
1. **AC-DF-212.1** (AC-ASM-05.1) Given `synthMember0001`(⑤ 없음), Then TR-09·TR-07의 '재검사 모드'가 비활성이고 '연구 참여 동의(⑤) 필요' 안내와 TR-14 링크가 보인다. ⑤가 로컬 캡처만 있고 서버 미확인이어도 비활성. — UI·단위
2. **AC-DF-212.2** (F-ASM-05.2) Given `synthMember0003`(②③⑤), When '재검사 모드' 진입, Then 먼저 고지 화면('참여하지 않아도 운동 지도에는 영향이 없어요' + 독립 재배치 안내: 대상자 다시 서기, 카메라 다시 설치)이 나오고 확인해야 촬영(TR-07)으로 간다. — UI
3. **AC-DF-212.3** (F-ASM-05.1, ASM-P1b-37) 재검사 모드의 첫 촬영이 `retestGroupId`(UUID 소문자)를 만들고, 같은 날 같은 모드에서 이어 찍은 기록은 같은 ID를 쓴다. '재검사 종료'나 날짜가 바뀌면 묶음이 닫힌다. — 단위
4. **AC-DF-212.4** (AC-ASM-05.2, ASM-P1b-16) Given 묶음 3건 confirmed, Then `AssessmentFilters.trendEligible`이 첫 확정 기록 1건만 돌려주고, 추이·O 후보·기준선 후보가 이 필터를 쓴다. — 단위
5. **AC-DF-212.5** (R-16) Given 에뮬레이터에서 ⑤를 철회한 뒤 재검사 draft 동기화, Then 규칙 거부 → '동기화 실패'(사유: 연구 참여 동의 없음)이고 로컬 draft는 남는다. — 연동
6. **AC-DF-212.6** (F-PRIV-02.3 ⑤ 행) ⑤ 철회 뒤에는 새 `retestGroupId`를 만들 수 없고, 열린 묶음이 있으면 닫힌다. 이미 확정된 재검사 기록은 일반 기록으로 남는다(②가 유지될 때). — 단위

**구현 노트**
- `Sources/TrainerDomain/Posture/RetestSession.swift`: `start(member:) throws -> RetestGroupID`(⑤ 서버 확인 필수), `attach(to draft:)`, `close()`, 날짜 경계 감시. 열린 묶음은 LocalStore에 둔다(`LocalRetestGroup {id, memberKey, openedAt, closedAt?}`).
- `AssessmentFilters.trendEligible(_:)`(DF-209 파일에 추가): `retestGroupId`별로 `capturedAt` 최소(같으면 `createdAt`) confirmed 1건만 남긴다.
- UI: `Sources/FeatureAssessment/Retest/RetestIntroView.swift`(고지), TR-09·TR-07의 '재검사 모드' 진입점, 촬영 중 상단 '재검사 {n}회차' 표시. 회차 체크리스트(DF-203)는 그대로이고 재배치 안내는 문구만(기록 필드 추가 없음).
- 문구 키: `retest.entry` 재검사 모드 · `retest.consentMissing` 연구 참여 동의(⑤) 필요 · 현장 동의 열기 · `retest.voluntaryNotice` 참여하지 않아도 운동 지도에는 영향이 없어요 · `retest.repositionNotice` 회차마다 대상자는 다시 서고 카메라는 다시 설치해 주세요 · `retest.round` 재검사 {n}회차 · `retest.end` 재검사 종료.
- 연구 데이터 내보내기(F-ASM-05.5)와 블라인드 보정(F-ASM-05.4)은 P2(DF-325, DF-326)다. 이 스토리에서 만들지 않는다.

**테스트**
- `TrainerDomainTests/RetestSessionTests.swift`: `test_AC_ASM_05_1_noResearchConsentBlocks()`, `test_AC_DF_212_3_sameDaySameGroup()`, `test_AC_DF_212_3_dayChangeClosesGroup()`, `test_AC_DF_212_6_withdrawalClosesGroup()`
- `TrainerDomainTests/AssessmentFiltersTests.swift`: `test_AC_ASM_05_2_onlyFirstConfirmedInTrend()`
- `IntegrationTests/RetestRulesIT.swift`: `test_R_16_retestWithoutResearchConsentRejected()`
- UI: `test_AC_DF_212_2_voluntaryNoticeBeforeCapture()`(`--preview-state=tr09.retestEligible`)

**비고·가정**
- ASM-P1b-16, ASM-P1b-37. IRB 서면 동의서 자체는 앱 밖 문서이며 앱은 ⑤ 기록만 확인한다(F-ASM-05.2).

**DoR 체크**
- [x] R1 · [x] R2 · [x] R3 DF-209(같은 스프린트) · [x] R4 3점 · [x] R5 · [x] R6 `TrainerDomain/Posture/RetestSession.swift`, `AssessmentFilters.swift`, `FeatureAssessment/Retest`, `LocalStore/Models/LocalRetestGroup.swift` · [x] R7 `privacy-impact` · [x] R8 합성 회원 `synthMember0003` · [x] R9 · [x] R10 실제 재검사 촬영은 DF-912(IRB) 뒤 소유자

**에이전트 브리프**
동의 ⑤ 게이트와 '첫 확정만' 필터 테스트부터 쓴다. 연구 내보내기·블라인드 보정·가명 처리 코드를 만들지 않는다(P2). 재검사 기록을 추이에서 숨기는 로직은 `AssessmentFilters` 한 곳에만 둔다(추이·O 후보·기준선이 같은 함수를 쓰게).

---

### DF-225 TR-03 타임라인에 체형평가 이벤트(썸네일·기준선·주요 지표 2개)를 추가한다

| 항목 | 값 |
|---|---|
| Epic | EP-12 타임라인·공통 시각화 |
| Type | story |
| Phase | P1b |
| Sprint | S12(MVP 계획, DEC-22, [03 MVP 계획](../03_RELEASE_AND_SPRINT_PLAN.md#mvp-계획dec-22)). 원래 계획: S17 (2027-01-18~01-22) |
| Points | 2 (size/S) |
| Priority | must |
| Area | trainer-app |
| Labels | `type/story` `area/trainer-app` `phase/P1b` `prio/must` `size/S` `flag/bodyAssessment` `agent/claude` `scope/mvp` |
| Depends on | DF-114, DF-209 |
| PRD refs | F-VIZ-05.1(체형평가 행), F-VIZ-05.4, F-VIZ-05.6, F-VIZ-05.7, AC-VIZ-05.2, AC-VIZ-05.4, TR-03 |

**사용자 스토리**
트레이너로서, 회원 상세 타임라인에서 SOAP 기록과 같은 날 찍은 체형평가를 함께 보고, 탭해서 결과 화면으로 가고 싶다.

**배경·맥락**
- 타임라인은 측정 시각 내림차순, 커서 페이지네이션이다(F-VIZ-05.6, P1a DF-114). 체형평가 행은 썸네일(동의 ③), 기준선 표시, 주요 지표 2개를 보인다(F-VIZ-05.1).
- voided는 기본 숨김이고, 새 버전은 이전 버전과 묶는다(F-VIZ-05.4).

**수용 기준**
1. **AC-DF-225.1** (AC-VIZ-05.2) Given 같은 날 finalized SOAP 1건과 confirmed 체형평가 1건, Then 두 행이 모두 보이고 `capturedAt`/`sessionDate` 순으로 정렬된다. — 단위·UI
2. **AC-DF-225.2** (F-VIZ-05.1) 체형 행은 ③이 있을 때만 `{view}_thumb.jpg` 썸네일을 보이고(없으면 도식 아이콘), '기준선' 표시와 `craniovertebralAngle`·`shoulderTiltAngle` 값(없으면 있는 지표 순서대로 2개)을 출처 칩과 함께 보인다. — 스냅샷
3. **AC-DF-225.3** (F-VIZ-05.4) voided는 기본 숨김이고 '무효 처리됨 보기' 필터를 켜면 취소선과 '무효 처리됨'으로 보인다. `supersedesId` 사슬은 최신 버전 한 행 아래 '이전 버전 {n}'으로 묶인다. 재검사 묶음은 첫 기록 한 행 + '재검사 {n}건'이다. — 단위
4. **AC-DF-225.4** (F-VIZ-05.7) 체형 행을 탭하면 TR-09(해당 ID)로 이동한다. — UI
5. **AC-DF-225.5** (AC-VIZ-05.4) 체형평가 조회가 권한 오류면 타임라인 전체가 '불러오기 실패'와 재시도를 보이고 빈 상태 문구는 없다. — 단위
6. **AC-DF-225.6** (ASM-P1b-26, AS-18) `bodyAssessment=false`여도 이미 있는 체형 행은 보이고, 종류 필터에 '체형평가'가 있다. 행에서 새 촬영으로 가는 버튼은 없다. — UI

**구현 노트**
- `Sources/FeatureMembers/Timeline/PostureTimelineRow.swift`, `TimelineEvent`(DF-114)에 `.posture(PostureTimelineItem)` 케이스 추가: `{id, capturedAt, status, isBaseline, thumbPath?, keyMetrics:[PostureMetricResult](≤2), olderVersionCount, retestCount, syncState}`.
- 병합 커서: DF-114의 다중 컬렉션 커서 병합에 `postureAssessments(trainerId, memberUid, capturedAt↓)` 소스를 추가한다(25건씩). 버전 사슬 묶음은 클라이언트에서 같은 페이지 안 `supersedesId`로 한다(다른 페이지에 걸리면 '이전 버전 있음'만).
- 썸네일: DF-227 `PhotoAccessGate`·`StoragePhotoFetcher`(대안: DF-214가 만든 것).
- 문구 키: `tr03.posture.title` 체형평가 · `tr03.posture.baseline` 기준선 · `tr03.posture.olderVersions` 이전 버전 {n} · `tr03.posture.retestCount` 재검사 {n}건 · `tr03.filter.posture` 체형평가 · `tr03.filter.showVoided` 무효 처리됨 보기.

**테스트**
- `FeatureMembersTests/PostureTimelineMergeTests.swift`: `test_AC_VIZ_05_2_soapAndPostureSameDay()`, `test_AC_DF_225_3_voidedHiddenAndVersionGrouping()`, `test_AC_VIZ_05_4_postureLoadErrorShowsFailure()`
- 스냅샷: `test_AC_DF_225_2_rowWithThumbAndKeyMetrics()`, `test_AC_DF_225_2_rowWithoutPhotoConsent()`
- UI: `test_AC_DF_225_4_tapOpensTR09()`, `test_AC_DF_225_6_existingRowsVisibleWhenFlagOff()`

**비고·가정**
- ASM-P1b-26.

**DoR 체크**
- [x] R1 · [x] R2 · [x] R3 DF-114(P1a), DF-209(같은 스프린트) · [x] R4 2점 · [x] R5 · [x] R6 `FeatureMembers/Timeline` · [x] R7 없음 · [x] R8 합성 SOAP·체형 같은 날 · [x] R9 · [x] R10 해당 없음

**에이전트 브리프**
DF-114의 타임라인 병합 코드에 소스 하나를 더하는 방식으로 작업하고, 기존 SOAP·신체조성 행 동작은 바꾸지 않는다(회귀 테스트 유지). 사진은 동의 게이트를 거친 fetcher로만 받는다. TR-09 화면은 건드리지 않고 라우트만 호출한다.

### MVP 범위(DEC-22)

- MVP 스프린트: S12(원래 계획 S17). 상태: 할 일
- 왜 필요한가: 흐름 4: 타임라인에 체형평가 이벤트
- 지금 만든다: 카드 전체 범위. 썸네일은 **로컬 `{view}_thumb.jpg`만** 쓴다(DF-205 `Thumbnailer` 산출물, LocalStore 경로). 동의 ③ 확인은 로컬 동의 상태로 하고, 로컬 파일이 없으면 도식 아이콘(AC-DF-225.2). `PhotoAccessGate`·`StoragePhotoFetcher`(DF-227·DF-214, MVP 밖)와 원격 다운로드는 만들지 않는다
- 참고: 썸네일 얼굴 가림은 DF-205 연기분과 같다. 로컬 일반 썸네일은 기기 밖으로 공유하지 않는다

---
### DF-215 TR-10 추이 차트(seriesBreak, 날짜 척도, L/R, 툴팁, noComparison)를 구현한다

| 항목 | 값 |
|---|---|
| Epic | EP-15 O 자동 불러오기·비교·추이 |
| Type | story |
| Phase | P1b |
| Sprint | S12(MVP 계획, DEC-22, [03 MVP 계획](../03_RELEASE_AND_SPRINT_PLAN.md#mvp-계획dec-22)). 원래 계획: S18 (2027-01-25~01-29) |
| Points | 5 (size/L) |
| Priority | must |
| Area | trainer-app |
| Labels | `type/story` `area/trainer-app` `area/design` `phase/P1b` `prio/must` `size/L` `flag/bodyAssessment` `agent/claude` `scope/mvp` |
| Depends on | DF-216, DF-130, DF-209 |
| PRD refs | F-VIZ-03.1~03.4, F-VIZ-03.7~03.10, F-ASM-04.6, AC-VIZ-03.1, AC-VIZ-03.2, AC-VIZ-03.3, AC-VIZ-03.5, AC-VIZ-03.6, C-01, C-02, C-04, AC-C-02.1, AC-C-04.1, AC-A11Y-03, A-03, TR-10 |

**사용자 스토리**
트레이너로서, 한 지표의 기록을 실제 날짜 간격대로 보고, 기기·프로토콜·조건이 바뀐 곳에서 선이 끊기며 이유가 적혀 있기를 원한다. 그래야 조건 차이를 변화로 착각하지 않는다.

**배경·맥락**
- x축은 측정 시각의 실제 날짜 척도다. 순번 인덱스·하드코딩 라벨은 쓰지 않는다(반례: dfet:trainer_ios/DFETTrainer/DesignSystem/ChartsAndPencil.swift:20-26 하드코딩 주간 라벨, dfet:lib/screens/blood/components/blood_trend_chart.dart:99 인덱스 x축).
- 누락 보간·곡선 보간·0 채우기 금지(F-VIZ-03.4; 반례 blood_trend_chart.dart:101 `isCurved: true`).
- 한 차트에는 `metricCode` 하나·`sourceGrade` 하나만(F-VIZ-03.2). 밴드·배지는 P3다. P1b는 '산정 준비 중' 칩만(AC-VIZ-03.5).

**수용 기준**
1. **AC-DF-215.1** (AC-VIZ-03.1) Given `bodyFatPercent` 3건 중 세 번째만 `deviceModel`이 다름, Then 2·3번째 점 사이에 선이 없고 세로 점선 표식과 '기기 변경: InBody 570 → InBody 270' 라벨이 있다. — 스냅샷(Swift Charts)
2. **AC-DF-215.2** (AC-VIZ-03.2) Given 1일·30일·2일 간격 점, Then x 위치가 날짜에 비례한다(플롯 좌표 비교). — 단위(차트 모델)·스냅샷
3. **AC-DF-215.3** (AC-VIZ-03.3, AC-C-04.1) Given 누락 회차, Then 그 날짜에 점이 없고 보간값·0 점이 추가되지 않으며 `interpolationMethod`가 `.linear`(곡선 아님)다. — 단위
4. **AC-DF-215.4** (AC-VIZ-03.5, AC-C-03.1) 차트 어디에도 밴드·변화 배지가 없고 머리에 '산정 준비 중' 칩이 있다. — 스냅샷
5. **AC-DF-215.5** (AC-VIZ-03.6, AC-C-02.1, F-VIZ-07.2) `tape`와 `observedSection` 허리둘레가 같은 plot에 그려지지 않는다: 지표 선택기는 `sourceGrade`별 항목으로 나뉘고, 차트 입력에 등급이 섞이면 렌더를 거부하고 개발 경고를 남긴다(DF-130 규칙). — 단위
6. **AC-DF-215.6** (F-VIZ-03.8, ASM-P1b-17) 좌우가 별도 시리즈인 둘레 지표는 실선(L)·점선(R)과 끝 라벨 'L'·'R'로 두 선을 그린다. 기울기 지표는 부호 있는 한 선(오른쪽 +)과 0 기준선이다. — 스냅샷
7. **AC-DF-215.7** (F-VIZ-03.9) 점을 탭하면 툴팁에 값·단위·측정 시각·출처 등급·기기·프로토콜 버전이 보이고 '원 기록 열기'로 TR-09/TR-11/TR-12로 간다. — UI
8. **AC-DF-215.8** (F-VIZ-03.10) 점이 1개면 '비교할 측정이 없습니다 · 판정 불가(noComparison)'. — 스냅샷
9. **AC-DF-215.9** (F-VIZ-03.7) y축은 데이터에 맞춰 자동이고 0을 강제로 넣지 않는다(NRS는 DF-219 고정축). 이중 y축 없음. — 단위
10. **AC-DF-215.10** (AC-A11Y-03, A-03) 회색조 스냅샷에서 seriesBreak(점선+문구)와 L/R(실선·점선+라벨)이 구분되고, 차트에 `AXChartDescriptor`(기간, 점 개수, 최소·최대, 끊김 수, 출처)가 있다. — 스냅샷·UI
11. **AC-DF-215.11** (F-ASM-04.6, AC-ASM-04.4, AC-ASM-05.2) 자세 점의 x는 `capturedAt`이고, voided와 재검사 묶음의 두 번째 이후 기록은 점이 없다. — 단위

**구현 노트**
- 화면(`Sources/FeatureInsights/Trend/`): `TrendView.swift`(`/// TR-10` 추이 탭, 지표 선택기 + 차트 + 비교 기준 선택 자리(P3에서 활성, P1b는 기준선 표시만)), `TrendViewModel.swift`, `MetricSeriesSource.swift`(가족별 원천 → `SeriesPoint`).
- 원천과 쿼리(모두 `trainerId == uid` + 회원 키, 100건, §9.6 인덱스)

| 가족 | 컬렉션 | 정렬 | 포함 조건 | `SeriesPoint` 변환 |
|---|---|---|---|---|
| posture | `postureAssessments` | `capturedAt↓` | confirmed, `AssessmentFilters.trendEligible` | `metrics[]` 원소마다, 조건은 `protocolVersion`·측면 view·`clothing`·카메라 높이/거리·`device.model` |
| bodyComposition | `bodyCompositionRecords` | `measuredAt↓` | active | `values`의 키마다(`sourceGrade=device`), `derived.bmi`는 `bmi`/`derived` |
| tape | `circumferenceMeasurements` | `metricCode`, `measuredAt↓` | active, `sourceGrade=tape` | 같은 날·같은 측면 반복값은 평균 1점(툴팁에 개별값), 조건 `protocolId`·`protocolVersion` |
| pain | `soap_notes` | `sessionDate↓` | DF-219 | DF-219 |

- 차트: DF-130 `SeriesTrendChart`에 `SeriesSegmenter.segment`(DF-216) 결과를 넘긴다. Swift Charts `LineMark(x: .value("측정일", date), y:, series: .value("segment", segmentId))` + `PointMark`, 끊김은 `RuleMark(x:)` `.lineStyle(StrokeStyle(dash: [4,4]))` + `.annotation`. x축 `.chartXScale(domain:)` 날짜, `AxisMarks(values: .automatic)`.
- 기울기 부호 변환(ASM-P1b-17)은 `MetricSeriesSource`에서만 한다(저장값은 크기+side 그대로).
- 문구 키: `tr10.tab.trend` 추이 · `tr10.break.device` 기기 변경: {before} → {after} · `tr10.break.protocol` 프로토콜 변경 · `tr10.break.condition` 조건 불일치: {key} · `tr10.noComparison` 비교할 측정이 없습니다 · 판정 불가(noComparison) · `tr10.help.lines` 점 사이 직선은 표시일 뿐이에요 · `tr10.tooltip.openRecord` 원 기록 열기 · `condition.fasting` 공복 여부 · `condition.timeOfDayBand` 측정 시간대 · `condition.view` 측면 방향 · `condition.clothing` 복장 · `condition.station` 촬영 스테이션.
- 분석: `change_status_rendered{surface:"trainer"}`(칩이 처음 그려질 때 1회).

**테스트**
- `FeatureInsightsTests/TrendViewModelTests.swift`: `test_AC_VIZ_03_2_dateProportionalX()`, `test_AC_VIZ_03_3_noInterpolation()`, `test_AC_VIZ_03_6_mixedGradesRejected()`, `test_AC_DF_215_9_yAxisNotForcedZero()`, `test_AC_DF_215_11_voidedAndRetestExcluded()`, `test_AC_DF_215_6_tiltSignedRightPositive()`
- 스냅샷(`FeatureInsightsTests/TrendSnapshotTests.swift`): `test_AC_VIZ_03_1_deviceChangeBreakSnapshot()`, `test_AC_VIZ_03_5_noBandNoBadge()`, `test_AC_DF_215_6_leftRightLines()`, `test_AC_DF_215_8_singlePointNoComparison()`, `test_AC_A11Y_03_grayscaleBreakAndLR()`
- UI: `test_AC_DF_215_7_tooltipOpensRecord()`, `test_A_03_chartDescriptorPresent()`
- 합성 데이터: SB-01 벡터와 같은 신체조성 3건, 자세 4건(기준선·일반·voided·재검사 2건), 줄자 허벅지 L/R.

**비고·가정**
- ASM-P1b-17, ASM-P1b-22(줄자 평균 표시), ASM-P1b-28.
- fl_chart 쪽 AC-VIZ-03.1 스냅샷은 P1a DF-131 범위다.

**DoR 체크**
- [x] R1 · [x] R2 · [x] R3 DF-216(S15), DF-130(P1a), DF-209(S17) · [x] R4 5점 · [x] R5 · [x] R6 `FeatureInsights/Trend`(DF-219 파일과 같은 폴더, 순서상 DF-219가 먼저 병합됨) · [x] R7 없음 · [x] R8 위 합성 데이터 · [x] R9 · [x] R10 해당 없음

**에이전트 브리프**
`TrendViewModel` 단위 테스트(날짜 비례, 보간 없음, 등급 혼합 거부)를 먼저 쓴다. 끊김 계산은 DF-216 `SeriesSegmenter`만 호출하고 다시 구현하지 않는다. 밴드·배지·Δ 판정을 그리지 않는다. `SeriesTrendChart`(DF-130)의 공개 동작을 바꿔야 하면 옵션 추가로만 하고 TR-11 미니 추이 스냅샷이 그대로인지 확인한다.

### MVP 범위(DEC-22)

- MVP 스프린트: S12(원래 계획 S18). 상태: 할 일
- 왜 필요한가: 흐름 4: TR-10 추이 차트(seriesBreak, 날짜 척도, L/R)
- 지금 만든다: 카드 전체 범위(분석 이벤트 제외)
- 참고: 변화 판정은 '산정 준비 중'만 표시한다(MDC 엔진 없음, DEC-22)
- 분석 이벤트 AC는 MVP 뒤(DF-126·DF-033): `change_status_rendered{surface:"trainer"}` 전송은 만들지 않는다

---

### DF-217 Review O 자동 불러오기 후보 선택과 refs·snapshots(pendingPolicy) 저장을 구현한다

| 항목 | 값 |
|---|---|
| Epic | EP-15 O 자동 불러오기·비교·추이 |
| Type | story |
| Phase | P1b |
| Sprint | S18 (2027-01-25~01-29) |
| Points | 5 (size/L) |
| Priority | must |
| Area | trainer-app |
| Labels | `type/story` `area/trainer-app` `phase/P1b` `prio/must` `size/L` `flag/soapV2` `flag/bodyAssessment` `agent/claude` |
| Depends on | DF-209, DF-127, DF-129, DF-122 |
| PRD refs | F-SOAP-03.1~03.5, F-SOAP-03.8, F-SOAP-03.9, F-ASM-04.5, AC-SOAP-03.1, AC-SOAP-03.2, AC-SOAP-03.4, AC-SOAP-03.6, AC-SOAP-03.7, §7.8, §9.3 `objective.refs`·`objective.snapshots`, AS-23, M-11, TR-05 |

**사용자 스토리**
트레이너로서, Review에서 오늘 확정한 체형평가와 오늘 입력한 신체조성·둘레가 O에 자동으로 들어오기를 원한다. 그래야 같은 숫자를 두 번 입력하지 않고 Review를 1분 안에 끝낼 수 있다.

**배경·맥락**
- O 자동 불러오기는 구조화 부담을 줄이는 장치다(RISK-05 완화). 원 기록은 ID로 참조하고, 화면용 값은 그 시점 스냅샷으로 고정한다(D7, ADR-004).
- P3 전에는 스냅샷 `changeStatus=pendingPolicy`, `reasonCode`·`policyVersion`·`mdcSource`는 null이다(F-SOAP-03.4). SOAP 쪽에서 산식을 만들지 않는다.
- 사진·원문은 복사하지 않는다(F-SOAP-03.3). 출처 등급 없는 값은 불러오지 않는다(F-SOAP-03.5).

**수용 기준**
1. **AC-DF-217.1** (AC-SOAP-03.1) Given 같은 날 confirmed 체형평가 1건(지표 3개)과 active 신체조성 1건(`weightKg`, `bodyFatPercent`, `derived.bmi`), When Review를 열고 그대로 확정, Then 둘 다 기본 선택돼 있었고 `objective.refs.postureAssessmentIds`에 1개, `bodyCompositionRecordIds`에 1개, `objective.snapshots`에 6개(지표 3 + 신체조성 3)가 저장된다. — 단위·연동
2. **AC-DF-217.2** (AC-SOAP-03.2, AC-ASM-04.4) draft·voided 체형평가, voided 신체조성·둘레, 재검사 묶음의 두 번째 이후 기록은 후보에 없다. — 단위
3. **AC-DF-217.3** (F-SOAP-03.2, AS-23, ASM-P1b-22) 같은 날이 아닌 기록은 종류별 최근 1건(줄자는 가장 최근 측정일 묶음)만 후보로 보이고 기본 선택되지 않는다. — 단위
4. **AC-DF-217.4** (AC-SOAP-03.4, §7.8) 모든 스냅샷 원소는 `{refId, metricCode, value, unit, side, sourceGrade, changeStatus:"pendingPolicy", reasonCode:null, policyVersion:null, mdcSource:null, measuredAt}`이고 배지가 없다. `measuredAt`은 자세 `capturedAt`, 신체조성·줄자 `measuredAt`이다. — 단위
5. **AC-DF-217.5** (AC-SOAP-03.6) `lidarBeta=false`면 bodyScans·observedSection 후보 영역 자체가 없다. — 단위
6. **AC-DF-217.6** (AC-SOAP-03.7, F-SOAP-03.9) 후보 조회가 권한 오류면 '불러오기 실패'와 재시도가 보이고 O는 비어 있지 않은 기존 입력을 유지한다. 모든 쿼리에 `trainerId == uid`와 회원 키가 있다. — 단위·연동
7. **AC-DF-217.7** (F-SOAP-03.8) 후보가 0건이면 '불러올 기록 없음'이 보이고 `refs`·`snapshots`가 비어 있다(키를 쓰지 않거나 빈 배열). — 단위
8. **AC-DF-217.8** (§9.3 상한) 선택 결과가 종류별 refs 20개 또는 snapshots 60개를 넘으면 초과 선택을 막고 '최대 {n}개까지 불러올 수 있어요'를 보인다. — 단위
9. **AC-DF-217.9** (ASM-P1b-21, NFR-04) 오프라인에서 오늘 로컬 저장만 된 신체조성은 syncState 칩과 함께 후보에 보이고 선택하면 스냅샷에 들어간다(ID는 클라이언트 자동 ID라 동기화 후에도 같다). — 단위
10. **AC-DF-217.10** (M-11) 확정 시 `soap_review_finalized.auto_ref_count_band`가 refs 총수 구간(`0`, `1-2`, `3-5`, `6+`)으로 채워진다. — 단위

**구현 노트**
- 모듈 경계(ASM-P1b-42): `TrainerDomain`은 `TrainerContracts`에만 의존하고 SwiftPM이 이를 컴파일 단계에서 강제한다. 그래서 **선택 규칙은 TrainerDomain에 순수 함수로**, **원천 읽기(LocalStore·원격 저장소)는 SyncEngine에** 둔다. SyncEngine은 스파인상 `TrainerDomain`·`LocalStore`에 의존할 수 있고, 원격 읽기는 TrainerDomain 프로토콜(`AssessmentLifecycle`, `MeasurementStore`, `RecordReader`)을 주입받아서만 한다(FirebaseData import 없음, NFR-03).
- 도메인, 순수(`Sources/TrainerDomain/Objective/`)
  - `ObjectiveSource.swift`: 원천 추상화.

```swift
public protocol ObjectiveSource: Sendable {
  var kind: CandidateKind { get }                                   // .posture | .bodyComposition | .tapeGroup (P2: .observedSection)
  func candidates(member: MemberKey, sessionDate: Date) async throws -> [Candidate]   // 필터 전 원자료. 권한 오류는 ObjectiveSourceError.permissionDenied로 던진다
}
public enum ObjectiveSourceError: Error, Equatable { case permissionDenied, unavailable(String) }
```

  - `ObjectiveCandidateSelector.swift`: `static func select(raw: [CandidateKind: Result<[Candidate], ObjectiveSourceError>], sessionDate: Date, calendar: Calendar, lidarBeta: Bool) -> ObjectiveCandidates`. 규칙: `status`가 draft·voided인 후보 제외(자세는 DF-209 `AssessmentFilters.activeConfirmed`와 같은 조건), 재검사 묶음은 `isFirstInRetestGroup`만(DF-212), 같은 날(기기 시간대 달력일, ASM-P1b-23)은 `defaultSelected=true`, 이전은 종류별 최근 1건(줄자는 최근 측정일 묶음, ASM-P1b-22)·`defaultSelected=false`, `sourceGrade` 없는 값 제외(F-SOAP-03.5), `lidarBeta=false`면 `.observedSection` 영역 없음, 한 종류라도 `permissionDenied`면 `loadState=.failed(.permissionDenied)`.
  - `ObjectiveCandidates { sameDay: [Candidate], earlier: [Candidate], lidarSectionVisible: Bool, loadState: .loaded | .failed(code) }`, `Candidate { kind: CandidateKind, refIds: [String], measuredAt: Date, status: String /* confirmed|draft|voided|active */, retestGroupId: String?, isFirstInRetestGroup: Bool, preview: [MetricPreview], syncState, defaultSelected: Bool }`. 원천은 `defaultSelected`를 채우지 않는다(선택기가 정한다).
  - `SnapshotBuilder.swift`: `build(from selected: [Candidate]) -> (refs: ObjectiveRefs, snapshots: [ObjectiveSnapshot])`. 자세 → `metrics[]` 원소마다, 신체조성 → `values` 키마다 + `derived.bmi`(metricCode `bmi`, sourceGrade `derived`), 줄자 → 반복값 문서마다(ASM-P1b-22). 단위는 metric-catalog(TrainerContracts)에서. 상한 검사(refs 종류별 20, snapshots 60)도 여기서 한다. `ObjectiveRefs { postureAssessmentIds, bodyCompositionRecordIds, circumferenceMeasurementIds, bodyScanIds: [String]; var totalCount: Int; static func decode(_ objectiveJSON: Data?) -> ObjectiveRefs /* nil·키 없음은 빈 값 */ }`도 이 파일에 둔다.
  - `AutoRefCountBand.swift`: `static func band(refCount: Int) -> AutoRefCountBand`(`0`, `1-2`, `3-5`, `6+`, V1-09 `count_band` 규칙). 생성된 `TrainerEvent.soapReviewFinalized(elapsed:autoRefCount:queued:)`의 `AutoRefCountBand` 타입을 쓴다.
- 구체 원천과 저장소 구현(`Sources/SyncEngine/Objective/`, `Sources/SyncEngine/Stores/`)
  - `SyncEngine/Objective/PostureObjectiveSource.swift`: 주입된 `AssessmentLifecycle.history(member:)`(DF-209)의 첫 값을 `Candidate(kind: .posture)`로 바꾼다.
  - `SyncEngine/Objective/BodyCompositionObjectiveSource.swift`, `TapeObjectiveSource.swift`: 주입된 `MeasurementStore`(P1a DF-127·DF-129) 조회 + LocalStore `LocalMeasurementDraft` 가운데 아직 동기화되지 않은 기록(`syncState != .synced`)을 합친다. 같은 ID는 로컬 쪽이 이긴다(AC-DF-217.9).
  - `SyncEngine/Objective/ObjectiveSources.swift`: `static func make(assessments: AssessmentLifecycle, measurements: MeasurementStore, local: LocalStoreContainer) -> [ObjectiveSource]`. App(`AppShell` DI)이 조립한다.
  - `SyncEngine/Stores/SoapNoteStoreImpl+Objective.swift`(신규): V1-06 `SoapNoteStore.loadObjectiveCandidates(member:sessionDate:)` = 원천을 병렬 호출(`withTaskGroup`) → `ObjectiveCandidateSelector.select`. `applySnapshots(_:refs:)` = `SnapshotBuilder.build` → `LocalSoapDraft.objectiveJSON`(P0 DF-014 필드, v2 `objective` 맵 인코딩)의 `refs`·`snapshots`만 교체(typed `metrics`는 보존) → Outbox draft update(`objective.refs`·`objective.snapshots`, soap v2 update 화이트리스트 안).
  - `SyncEngine/Stores/SoapNoteStoreImpl+Finalize.swift`(DF-122 파일) **한 줄만 변경 허용**: DF-122가 `soap_review_finalized`에 고정값 `.zero`로 넣는 `autoRefCount` 인자를 `AutoRefCountBand.band(refCount: ObjectiveRefs.decode(draft.objectiveJSON).totalCount)`로 바꾼다. 이벤트 전송 위치가 DF-122 구현에서 `FeatureSOAP/Review` 호출부로 옮겨져 있으면 그 호출부의 같은 한 줄을 바꾼다. 확정 요건·Outbox 순서·잠금 로직은 건드리지 않는다.
- 화면(`Sources/FeatureSOAP/Review/Objective/ObjectiveAutoLoadPanel.swift`): TR-05 O 카드 위 패널. 같은 날(체크됨)·이전(체크 안 됨) 두 묶음, 각 행에 종류, 측정 시각, 주요 값 2~3개, 출처 칩, syncState. '불러오기 실패'·'불러올 기록 없음' 상태. 스냅샷 행은 O 표에 '불러옴' 표시와 함께 들어가고 typed O 행(DF-121)과 섞여 편집되지 않는다(읽기 전용, 제거만 가능).
- 예시(합성, 저장 결과)

```json
{
  "objective": {
    "metrics": [],
    "refs": {
      "postureAssessmentIds": ["SYNTHposture00000001"],
      "bodyCompositionRecordIds": ["SYNTHbodycomp0000001"],
      "circumferenceMeasurementIds": [],
      "bodyScanIds": []
    },
    "snapshots": [
      {"refId": "SYNTHposture00000001", "metricCode": "craniovertebralAngle", "value": 48.2, "unit": "deg", "side": "none",
       "sourceGrade": "photoManual", "changeStatus": "pendingPolicy", "reasonCode": null, "policyVersion": null, "mdcSource": null,
       "measuredAt": "2027-01-25T10:05:12+09:00"},
      {"refId": "SYNTHbodycomp0000001", "metricCode": "weightKg", "value": 62.4, "unit": "kg", "side": "none",
       "sourceGrade": "device", "changeStatus": "pendingPolicy", "reasonCode": null, "policyVersion": null, "mdcSource": null,
       "measuredAt": "2027-01-25T09:40:00+09:00"}
    ]
  }
}
```

- 쿼리는 DF-215 표와 같고, 같은 날 판정은 기기 시간대 달력일(ASM-P1b-23).
- 문구 키: `tr05.o.autoLoad.title` 오늘 기록 불러오기 · `tr05.o.autoLoad.sameDay` 오늘 측정 · `tr05.o.autoLoad.earlier` 이전 기록(종류별 최근 1건) · `tr05.o.noCandidates` 불러올 기록 없음 · `tr05.o.loadFailed` 불러오기 실패 · `tr05.o.retry` 다시 시도 · `tr05.o.limit` 최대 {n}개까지 불러올 수 있어요 · `tr05.o.snapshotBadge` 불러옴.

**테스트**
- `TrainerDomainTests/ObjectiveCandidateSelectorTests.swift`(가짜 원천 결과를 직접 넣는 순수 테스트): `test_AC_SOAP_03_1_sameDayDefaultSelected()`, `test_AC_SOAP_03_2_draftAndVoidedExcluded()`, `test_AC_DF_217_3_earlierOnlyLatestPerKind()`, `test_AC_SOAP_03_6_noLidarWhenFlagOff()`, `test_AC_SOAP_03_7_permissionErrorShowsFailure()`, `test_AC_DF_217_7_noCandidates()`
- `TrainerDomainTests/AutoRefCountBandTests.swift`: `test_AC_DF_217_10_bandBoundaries()`(0, 1, 2, 3, 5, 6, 20)
- `SyncEngineTests/ObjectiveSourcesTests.swift`(인메모리 LocalStore + `FakeAssessmentLifecycle`·가짜 `MeasurementStore`): `test_AC_DF_217_9_localUnsyncedIncluded()`, `test_AC_DF_217_9_localWinsOnSameId()`, `test_AC_SOAP_03_7_permissionDeniedPropagates()`
- `SyncEngineTests/SoapNoteStoreObjectiveTests.swift`: `test_applySnapshots_enqueuesDraftUpdateWithObjectiveOnly()`, `test_AC_DF_217_10_finalizeEventCarriesRefBand()`(DebugSink)
- `TrainerDomainTests/SnapshotBuilderTests.swift`: `test_AC_SOAP_03_4_pendingPolicyNullFields()`, `test_AC_DF_217_1_snapshotCountMatchesMetrics()`, `test_AC_DF_217_8_limits()`, `test_F_SOAP_03_5_noSourceGradeNotLoaded()`
- `IntegrationTests/ObjectiveAutoLoadIT.swift`: `test_AC_SOAP_03_1_finalizeWritesRefsAndSnapshots()`(에뮬레이터 soap v2 규칙 통과 확인)
- 교차 픽스처: `contracts/fixtures/soap_v2/`에 `objective_snapshots.json`(위 예시)을 추가하고 Dart 코덱(DF-007)이 왕복 무손실인지 확인한다(AC-SOAP-06.1 회귀).

**비고·가정**
- ASM-P1b-21, ASM-P1b-22, ASM-P1b-23, ASM-P1b-28, ASM-P1b-42.

**DoR 체크**
- [x] R1 · [x] R2 · [x] R3 DF-209(S17), DF-127·DF-129·DF-122(P1a) · [x] R4 5점 · [x] R5 · [x] R6 `TrainerDomain/Objective`, `SyncEngine/Objective`, `SyncEngine/Stores/SoapNoteStoreImpl+Objective.swift`(신규), `SyncEngine/Stores/SoapNoteStoreImpl+Finalize.swift`(`autoRefCount` 인자 한 줄만), `App/AppShell`(원천 DI 조립 몇 줄), `FeatureSOAP/Review/Objective`, `contracts/fixtures/soap_v2/objective_snapshots.json` · [x] R7 `schema-change`(픽스처 추가) · [x] R8 합성 회원 하루치 기록 · [x] R9 · [x] R10 해당 없음

**에이전트 브리프**
`SnapshotBuilder`의 필드·개수 테스트와 후보 선택 규칙 테스트를 먼저 쓴다. `changeStatus`는 항상 `pendingPolicy`이고 판정·MDC 코드를 넣지 않는다. TrainerDomain 파일에서 LocalStore·SyncEngine·FirebaseData를 import하지 않는다(컴파일 실패로 드러난다). 원천 읽기는 `SyncEngine/Objective/`에만 둔다. typed O 입력(DF-121)은 호출만 하고 바꾸지 않는다. 확정 로직(DF-122)은 `autoRefCount` 인자 한 줄 외에는 바꾸지 않는다. 원 기록 사진 경로·결과지 경로를 스냅샷에 넣지 않는다.

---

### DF-218 스냅샷 '원본 변경됨' 표시와 draft 재불러오기를 구현한다

| 항목 | 값 |
|---|---|
| Epic | EP-15 O 자동 불러오기·비교·추이 |
| Type | story |
| Phase | P1b |
| Sprint | S18 (2027-01-25~01-29) |
| Points | 2 (size/S) |
| Priority | must |
| Area | trainer-app |
| Labels | `type/story` `area/trainer-app` `phase/P1b` `prio/must` `size/S` `flag/soapV2` `agent/claude` |
| Depends on | DF-217 |
| PRD refs | F-SOAP-03.6, F-SOAP-03.7, AC-SOAP-03.3, F-SOAP-04.3, F-SOAP-04.4, §9.3 |

**사용자 스토리**
트레이너로서, SOAP에 불러온 체형평가를 나중에 새 버전으로 다시 보정했다면 노트에서 그 사실을 알고 원본으로 갈 수 있기를 원한다. 그래도 노트에 적힌 숫자는 그대로여야 한다.

**배경·맥락**
- 원본이 새 버전·voided·updatedAt 갱신되면 '원본 변경됨'과 원본 링크를 보이고 스냅샷 값은 바꾸지 않는다(F-SOAP-03.6). draft에서는 다시 불러올 수 있고, finalized에서는 addendum으로만 보완한다(F-SOAP-03.7).
- 스냅샷 원소에는 시각 필드가 없다(§9.3). 비교 기준 시각은 ASM-P1b-24.

**수용 기준**
1. **AC-DF-218.1** (AC-SOAP-03.3) Given 체형평가 A를 참조한 finalized 노트, When A를 새 버전 B로 재보정·확정(A voided), Then 노트 보기의 해당 스냅샷에 '원본 변경됨'과 'A 열기' 링크가 보이고 스냅샷 값은 그대로다. — 연동
2. **AC-DF-218.2** (F-SOAP-03.6) Given 참조한 신체조성이 '정정'으로 voided, Then '원본 변경됨(무효 처리됨)'이 보인다. 원본 `updatedAt` > 기준 시각이면(예: 기준선 지정) '원본 변경됨'. — 단위
3. **AC-DF-218.3** (F-SOAP-03.7) draft 노트에서 '스냅샷 다시 불러오기'를 누르면 선택된 refs로 스냅샷을 다시 만들고(voided 원본은 목록에서 빠지고 알림), 기준 시각을 갱신한다. finalized 노트에는 이 버튼이 없고 'addendum으로 보완' 안내가 있다. — 단위·UI
4. **AC-DF-218.4** (F-SOAP-04.3) finalized 노트의 `objective.snapshots`를 바꾸는 쓰기 경로가 없다(규칙도 거부, R-08 회귀). — 단위
5. **AC-DF-218.5** 원본 조회 실패(권한 해제 등)는 '원본 확인 불가'로 보이고 스냅샷은 그대로다(빈 칸 아님). — 단위

**구현 노트**
- `Sources/TrainerDomain/Objective/SnapshotStalenessChecker.swift`: `check(note: SoapNoteSummary, referenceTime: Date) async -> [RefId: Staleness]`(`.unchanged | .changed(reason: .superseded | .voided | .updated) | .unavailable`). 원본은 ID로 `get`(종류별 ≤20). 자세는 `status == voided`면 superseded 여부를 문구로만 구분하지 않고 '원본 변경됨'으로 통일한다(새 버전 링크는 TR-09가 보여 줌).
- 기준 시각: finalized는 `finalizedAt`, draft는 `LocalSoapDraft.snapshotsAppliedAt`(LocalStore 필드 추가, 서버에 쓰지 않음, ASM-P1b-24).
- UI: `Sources/FeatureSOAP/Review/Objective/SnapshotRow.swift`에 표식·링크, `ReloadSnapshotsButton.swift`(draft만).
- 문구 키: `tr05.o.sourceChanged` 원본 변경됨 · `tr05.o.sourceVoided` 원본 변경됨(무효 처리됨) · `tr05.o.sourceUnavailable` 원본 확인 불가 · `tr05.o.reload` 스냅샷 다시 불러오기 · `tr05.o.useAddendum` 확정된 노트는 addendum으로 보완해요 · `tr05.o.openSource` 원본 열기.

**테스트**
- `TrainerDomainTests/SnapshotStalenessCheckerTests.swift`: `test_AC_SOAP_03_3_supersededShowsChangedValueKept()`, `test_AC_DF_218_2_voidedAndUpdatedAt()`, `test_AC_DF_218_5_unavailable()`
- `TrainerDomainTests/ReloadSnapshotsTests.swift`: `test_AC_DF_218_3_draftReloadUpdatesReferenceTime()`, `test_AC_DF_218_4_finalizedNoWritePath()`
- `IntegrationTests/SnapshotStalenessIT.swift`: `test_AC_SOAP_03_3_endToEnd()`

**비고·가정**
- ASM-P1b-24.

**DoR 체크**
- [x] R1 · [x] R2 · [x] R3 DF-217(같은 스프린트 앞순서) · [x] R4 2점 · [x] R5 · [x] R6 `TrainerDomain/Objective/SnapshotStalenessChecker.swift`, `FeatureSOAP/Review/Objective/SnapshotRow.swift`, `LocalStore/Models/LocalSoapDraft.swift`(필드 1개) · [x] R7 없음(LocalStore 경량 이관) · [x] R8 합성 · [x] R9 · [x] R10 해당 없음

**에이전트 브리프**
판별 함수 단위 테스트부터 쓴다. 스냅샷 값을 원본 최신값으로 덮어쓰는 코드는 draft의 명시적 '다시 불러오기' 외에 어디에도 두지 않는다. addendum 흐름(DF-123)은 안내 문구만 연결한다.

---

### DF-223 P1b 실기기 촬영 프로토콜 테스트와 Instruments 성능 측정을 수행한다

| 항목 | 값 |
|---|---|
| Epic | EP-14 체형평가(정적 2D) |
| Type | chore |
| Phase | P1b |
| Sprint | S18 (2027-01-25~01-29) |
| Points | 2 (size/S) |
| Priority | must |
| Area | trainer-app |
| Labels | `type/chore` `area/trainer-app` `phase/P1b` `prio/must` `size/S` `flag/bodyAssessment` `agent/human` `needs-device-test` |
| Depends on | DF-209 |
| PRD refs | §12.5 iPad 실기기 촬영·성능 측정, NFR-04, NFR-05, NFR-12, NFR-15, M-04a, M-04b, M-G3, AC-ASM-01.5, AC-ASM-01.2 |

**사용자 스토리**
소유자로서, P1b 종료 전에 실제 iPad로 촬영부터 확정·동기화까지 해 보고 시간과 실패를 기록하고 싶다. 그래야 P1b 종료 검토(DF-928)에서 M-04a/b와 NFR-15를 숫자로 판단할 수 있다.

**배경·맥락**
- 시뮬레이터에는 카메라·모션이 없고 성능도 다르다. 촬영 게이트·수평계·Split View·오프라인은 실기기로만 확인할 수 있다(§12.5).
- 참여자는 합성 참여자(마네킹 또는 소유자 본인 자기 촬영)만 쓴다(ASM-P1b-39). 회원 촬영은 이 테스트에 쓰지 않는다.

**수용 기준**
1. **AC-DF-223.1** (§12.5) [V1-T09](../templates/DEVICE_TEST_RECORD.md) 양식으로 다음 시나리오 결과가 기록된다: ① 정면·측면 촬영(세로·가로 각각) ② roll·pitch 게이트(허용 경계 ±0.2° 안팎) ③ 4방향 회전 중 촬영·보정 상태 유지 ④ 1/3·1/2 Split View, Slide Over, Stage Manager ⑤ 밝은·어두운 조명 ⑥ 비행기 모드 촬영 → 보정 → 확정 → 복구 ⑦ 업로드 중 강제 종료 → 재실행. — 실기기
2. **AC-DF-223.2** (M-04a, M-04b) 5회 이상 측정한 촬영 소요(`posture_capture_started`→`done`)와 확정 소요(보정 시작→confirmed)의 중앙값이 기록된다(DebugSink 로그의 `elapsed_band` + Instruments 실측 초). — 실기기
3. **AC-DF-223.3** (NFR-15) Instruments(os_signpost)로 ① 제안 지연(`LandmarkSuggest`, 목표 ≤ 2초) ② 사진 업로드가 입력 화면을 막지 않음(메인 스레드 hang 0) ③ 콜드 스타트 → TR-01(≤ 2초)을 잰다. 목표를 넘으면 값과 원인 가설을 기록한다(P1b 종료 검토 입력). — 실기기
4. **AC-DF-223.4** (NFR-04, NFR-05, M-G3) 시나리오 ⑥·⑦에서 데이터 유실 0건, 중복 문서 0건, 알리지 않은 저장 실패 0건이다. 위반하면 버그 이슈(`type/bug`, [BUG_REPORT](../templates/BUG_REPORT.md))를 만들고 DF-928 검토에 올린다. — 실기기
5. **AC-DF-223.5** 기록에 회원 정보·사진이 없다(기기 모델, OS, 시나리오, 결과, 수치만). — 문서

**구현 노트**
- 기록 파일: `docs/v1/device-tests/DT-P1b-2027-01-XX.md`(V1-T09 복사, 합성 참여자만). 사진·화면 녹화는 저장소에 넣지 않는다.
- 필요한 빌드: TestFlight 내부 빌드 또는 로컬 Release 빌드(App Attest), 에뮬레이터가 아닌 운영 프로젝트면 `bodyAssessment` 플래그가 켜져 있어야 하므로 DF-929(S17) 뒤에 한다. 운영 데이터를 쓰기 싫으면 로컬 Debug 빌드 + 에뮬레이터(같은 Wi-Fi)로 수행하고 그 사실을 기록한다.
- 측정 도구: Xcode Instruments 'Points of Interest'(os_signpost), 'Hangs', 'App Launch'.

**테스트**
- 자동 테스트 없음. 증빙은 기록 파일과 PR 링크.

**비고·가정**
- ASM-P1b-39, ASM-P1b-40(멀티태스킹 결과 반영).

**DoR 체크**
- [x] R1 · [x] R2(시나리오 목록) · [x] R3 DF-209(S17), DF-929(소유자, S17) · [x] R4 2점 · [x] R5 · [x] R6 `docs/v1/device-tests/` · [x] R7 없음 · [x] R8 합성 참여자 · [ ] R9 소유자 직접(지시서 불필요) · [x] R10 `needs-device-test`

**에이전트 브리프**
소유자가 수행한다. 에이전트는 기록 양식 빈칸과 Instruments 템플릿 설정 안내만 준비한다. 측정 결과를 해석해 목표값을 바꾸지 않는다(목표 재설정은 DF-928 단계 종료 검토에서 소유자가 한다).

---

### DF-224 M-05 재평가 판정 가능 비율(조건 사유)을 opsMetrics에 추가한다

| 항목 | 값 |
|---|---|
| Epic | EP-15 O 자동 불러오기·비교·추이 |
| Type | story |
| Phase | P1b |
| Sprint | S18 (2027-01-25~01-29) — 추가 제안 채택 시 P2 첫 묶음(S19-S20)으로 이월 |
| Points | 2 (size/S) |
| Priority | could |
| Area | analytics |
| Labels | `type/story` `area/analytics` `area/functions` `phase/P1b` `prio/could` `size/S` `agent/codex` `privacy-impact` |
| Depends on | DF-137, DF-216 |
| PRD refs | M-05, §5.3, §7.4, §7.5(사유 순서), §9.2 `opsMetrics`, ASM-P1b-29 |

**사용자 스토리**
소유자로서, 재평가 비교 쌍 가운데 촬영·측정 조건이 달라 비교할 수 없던 비율을 매주 보고 싶다. 그래야 프로토콜·스테이션 관리가 잘 되는지 판단할 수 있다.

**배경·맥락**
- M-05는 회원 단위 결합이 필요해 분석 이벤트가 아니라 서버 주간 집계다(§5.3). 조건 키 비교는 정책 없이도 계산한다(M-05 측정 방법).
- 분모에서 정책·문헌 사유(noMdc, referenceMetric, betaMetric)를 뺀다. 정책이 없는 P1b에서는 noMdc를 알 수 없으므로 참고·베타 지표만 뺀다(ASM-P1b-29).

**수용 기준**
1. **AC-DF-224.1** (M-05) Given 합성 주간 데이터(자세 비교 쌍 4: 조건 같음 2, 기기 변경 1, 기준선 없음 1), When `aggregateOpsMetrics` 실행, Then `opsMetrics/{isoWeek}.m05 = {pairs: 4, comparable: 2, byReason: {deviceChanged: 1, noComparison: 1, protocolChanged: 0, conditionMismatch: 0}, excluded: {referenceMetric: n, betaMetric: 0}, ratio: 0.5}`. — 단위
2. **AC-DF-224.2** (§7.5 순서) 사유 판정은 DF-216 벡터(`contracts/vectors/series-break.v1.json`)를 JS 구현이 모두 통과하는 것으로 검증한다. — 단위(`node:test`)
3. **AC-DF-224.3** (§9.2 opsMetrics, NFR-10) 문서에 회원·트레이너 식별자와 지표 값이 없다(키 화이트리스트 테스트). — 단위
4. **AC-DF-224.4** (ASM-P1b-29) `headTiltFrontal`, `pelvicTiltFrontal`, `painNrs` 쌍은 `excluded.referenceMetric`으로만 센다. 재검사 묶음은 첫 기록만 쌍에 들어간다. — 단위

**구현 노트**
- `functions/src/ops/m05.js`(순수 core: `computeM05({postures, bodyComps, tapes, catalog, tolerance, weekRange}) -> m05`), `functions/src/ops/seriesConditions.js`(JS 비교 함수, `functions/src/shared/generated/`의 카탈로그·프로토콜 허용값 사용), `functions/src/ops/aggregateOpsMetrics.js`(DF-137)에서 호출.
- 쌍 정의(ASM-P1b-29): 자세 = 그 주 confirmed(재검사 첫 기록만) × 같은 회원·측면 방향 기준선(없으면 `noComparison`), 신체조성·줄자 = 그 주 active × 같은 시리즈 직전 active(없으면 `noComparison`). 지표 단위로 센다.
- 조회는 Admin SDK로 `capturedAt`·`measuredAt` 주간 범위(서버 전용, 규칙 무관). 로그에는 건수만.
- 새 npm 의존성 없음(ADR-017).

**테스트**
- `functions/test/unit/ops-m05.test.js`: `test('AC-DF-224.1 주간 M-05 집계', …)`, `test('AC-DF-224.3 식별자·값 없음', …)`, `test('AC-DF-224.4 참고 지표 제외·재검사 첫 기록만', …)`
- `functions/test/unit/series-conditions-vector.test.js`: `test('AC-DF-224.2 series-break 벡터 JS 통과', …)`

**비고·가정**
- ASM-P1b-29. could 항목이라 속도가 부족하면 스파인 규칙대로 가장 먼저 이월한다.

**DoR 체크**
- [x] R1 · [x] R2 · [x] R3 DF-137(P1a), DF-216(S15) · [x] R4 2점 · [x] R5 · [x] R6 `functions/src/ops/`, `functions/test/unit/` · [x] R7 `privacy-impact` · [x] R8 합성 주간 데이터 · [x] R9 · [x] R10 해당 없음

**에이전트 브리프**
벡터 통과 테스트로 JS 비교 함수를 먼저 맞추고, 그다음 집계 core를 만든다. 집계 결과에 uid·이름·수치를 넣지 않는다. `aggregateOpsMetrics`의 기존 지표(M-03 등) 계산은 바꾸지 않는다. 배포하지 않는다.

---

### DF-226 TR-07~TR-10 상태 매트릭스 스냅샷과 접근성 감사를 추가한다

| 항목 | 값 |
|---|---|
| Epic | EP-14 체형평가(정적 2D) |
| Type | story |
| Phase | P1b |
| Sprint | S18 (2027-01-25~01-29) |
| Points | 2 (size/S) |
| Priority | must |
| Area | trainer-app |
| Labels | `type/story` `area/trainer-app` `area/design` `phase/P1b` `prio/must` `size/S` `flag/bodyAssessment` `agent/claude` |
| Depends on | DF-214, DF-215 |
| PRD refs | AC-IA-01, AC-A11Y-01, AC-A11Y-02, AC-A11Y-03, §8.4 화면별 적용 매트릭스(TR-07~TR-10), §8.6, NFR-12 |

**사용자 스토리**
소유자로서, 체형 화면들의 모든 상태(동의 없음, 산정 준비 중, 판정 불가, 오프라인, 동기화 실패, 빈 상태)가 스냅샷으로 고정돼 회귀를 CI에서 잡기를 원한다.

**배경·맥락**
- 각 화면의 스냅샷·골든 테스트는 §8.4 매트릭스의 O 칸을 모두 포함해야 한다(AC-IA-01). 가장 큰 글자에서 TR-09 수치가 잘리지 않아야 한다(AC-A11Y-02).

**상태 매트릭스(§8.4에서 TR-07~TR-10 행)**

| 화면 | 빈 상태 | 동의 없음 | 산정 준비 중 | 판정 불가 | 오프라인·동기화 | 동기화 실패 |
|---|---|---|---|---|---|---|
| TR-07 | — | ②③ | — | — | O | O |
| TR-08 | — | ③ | — | — | O | O |
| TR-09 | — | ③ | O | O | O | O |
| TR-10 | O | ③ | O | O | O | — |

**수용 기준**
1. **AC-DF-226.1** (AC-IA-01) 위 표의 칸마다 `--preview-state=<화면>.<상태>`(ASM-P1b-34) 스냅샷이 하나 이상 있고, 세로·가로 2방향과 1/3 Split View 폭 1개를 포함한다. — 스냅샷
2. **AC-DF-226.2** (AC-A11Y-01) XCUITest `performAccessibilityAudit()`가 TR-07~TR-10에서 통과하고, 모든 수치 요소 라벨에 출처 등급과 '산정 준비 중'(또는 '참고 지표 · 판정하지 않음')이 있다. — UI
3. **AC-DF-226.3** (AC-A11Y-02) `UIContentSizeCategory.accessibilityExtraExtraExtraLarge`에서 TR-09 편위 표가 카드형으로 바뀌고 수치 텍스트에 말줄임이 없다(스냅샷 + 텍스트 잘림 검사). — 스냅샷·UI
4. **AC-DF-226.4** (AC-A11Y-03) 회색조 변환 스냅샷에서 랜드마크 auto/확정, seriesBreak, L/R 선, '산정 준비 중' 칩이 구분된다(DF-208·DF-215 스냅샷 재사용 + TR-09·TR-10 전체 화면). — 스냅샷
5. **AC-DF-226.5** (NFR-12) 1/3 Split View 폭에서 TR-07 셔터와 TR-08 '확정'이 스크롤 없이 닿는다. — UI

**구현 노트**
- `trainer_app/App/AppShell/PreviewStates.swift`: `--preview-state` 파서와 상태별 가짜 저장소 조합(DEBUG 전용, 릴리스 빌드에서 무효).
- 스냅샷: `trainer_app/UITests/Snapshots/PostureStateMatrixTests.swift`(swift-snapshot-testing, 테스트 타깃 전용 의존성, ADR-013). 기준 이미지는 `__Snapshots__/`에 커밋, 기준 시뮬레이터는 [V1-01 ASM-01-07](../01_AGILE_WORKING_AGREEMENT.md)의 기본 기기.
- 회색조: 렌더 이미지에 `CIColorControls(saturation: 0)` 적용 후 비교.
- 잘림 검사: 접근성 요소 `label`과 화면 텍스트의 `…` 포함 여부, 수치 요소 프레임이 컨테이너 안에 있는지.

**테스트**
- `PostureStateMatrixTests`: `test_AC_IA_01_tr07_consentMissing()`, `…_tr07_offline()`, `…_tr07_syncFailed()`, `test_AC_IA_01_tr08_noPhotoConsent()`, `…_tr08_offline()`, `…_tr08_syncFailed()`, `test_AC_IA_01_tr09_pendingPolicy()`, `…_tr09_indeterminate()`, `…_tr09_noPhotoConsent()`, `…_tr09_offline()`, `…_tr09_syncFailed()`, `test_AC_IA_01_tr10_empty()`, `…_tr10_noPhotoConsent()`, `…_tr10_pendingPolicy()`, `…_tr10_indeterminate()`, `…_tr10_offline()`
- `PostureAccessibilityAuditTests`: `test_AC_A11Y_01_auditTR07toTR10()`, `test_AC_A11Y_02_tr09LargestTextNoTruncation()`, `test_AC_A11Y_03_grayscaleDistinguishable()`, `test_NFR_12_splitViewReachability()`

**비고·가정**
- ASM-P1b-34. 상태 매트릭스 정본은 [V1-07](../07_TRAINER_APP_SPEC.md)이며 달라지면 V1-07을 따른다.

**DoR 체크**
- [x] R1 · [x] R2 · [x] R3 DF-214(S17), DF-215(같은 스프린트 앞순서) · [x] R4 2점 · [x] R5 · [x] R6 `trainer_app/UITests/`, `trainer_app/App/AppShell/PreviewStates.swift` · [x] R7 없음 · [x] R8 가짜 저장소 상태 · [x] R9 · [x] R10 해당 없음

**에이전트 브리프**
상태 주입(`PreviewStates`)부터 만들고 칸마다 스냅샷을 하나씩 추가한다. 스냅샷을 통과시키려고 화면 코드를 바꾸지 말고, 결함을 찾으면 해당 스토리 버그로 이슈를 남긴다. `--preview-state`가 릴리스 빌드에서 동작하지 않는지 테스트로 확인한다.

---

## 7 관련 소유자 행동·게이트

정본은 [OWNER_ACTIONS_AND_GATES.md](OWNER_ACTIONS_AND_GATES.md)(V1-02-OA)다. P1b 스토리와 직접 얽힌 항목만 적는다. 외부 게이트는 합성 데이터 코딩을 막지 않는다.

| 키 | 내용 | 스프린트 | 막는 것 | 막지 않는 것 |
|---|---|---|---|---|
| DF-912 | 자세 재검사 연구 IRB 신청(G-06 시작 조건). S14까지 승인·면제 확인 목표 | S06 신청 | 실제 재검사 촬영·연구 데이터 수집 | DF-212 코드와 합성 테스트 |
| DF-915 | 촬영 프로토콜 v1 수치(높이·거리·허용 범위·발 간격) 확정 | S13 | `contracts/posture-protocol.v1.json`의 `status` 해제, 실사용 촬영 | DF-203·DF-204 코딩(기본값 사용) |
| DF-927 | P1a 단계 종료 검토 | S15 | P1b 공식 진입, DF-929 | P1b 코딩 |
| DF-929 | `bodyAssessment` 플래그 개방(PRD §12.3 순서 2). TR-07~TR-09 동작 확인 뒤 | S17 | 운영에서 체형 촬영 | 에뮬레이터 개발 |
| DF-928 | P1b 단계 종료 검토(V1-T06). M-04a/b·M-03·M-05·M-G5, 유실 0, DF-223 기록 | S18 | P2 진입 | — |
| DF-914 | Q-10 디자인 토큰 결정(기존 P1a 항목) | S06 | — | 오버레이·차트는 중립 회색 + 브랜드 블루 기본값으로 진행 |

---

## 8 추적성: PRD 요구사항 → 스토리

| PRD 요구사항·수용 기준 | 스토리 |
|---|---|
| F-ASM-01.1, 01.4, 01.5, AC-ASM-01.1~01.3 | DF-204(촬영·게이트), DF-203(체크리스트·기록 필드) |
| F-ASM-01.2, 01.3 | DF-203 |
| F-ASM-01.6, 01.7, 01.10, AC-ASM-01.4, 01.6 | DF-205, DF-206(Storage 교체) |
| F-ASM-01.8, AC-ASM-01.5 | DF-206 |
| F-ASM-01.9, AC-ASM-01.7 | DF-211 |
| F-ASM-02.1, 02.2, 02.7, AC-ASM-02.3 | DF-200, DF-207 |
| F-ASM-02.3~02.6, AC-ASM-02.1, 02.2 | DF-208(화면), DF-201(확정 가능 도메인) |
| F-ASM-02.5, AC-ASM-02.4, 02.5 | DF-201, DF-208 |
| F-ASM-03.1~03.6, AC-ASM-03.1~03.4, 03.6 | DF-201 |
| F-ASM-03.7, AC-ASM-03.5 | DF-210 |
| F-ASM-04.1~04.4, 04.6, AC-ASM-04.1~04.4 | DF-209 |
| AC-ASM-04.5 | DF-206 |
| F-ASM-04.5 | DF-217 |
| F-ASM-05.1~05.3, AC-ASM-05.1, 05.2 | DF-212 |
| F-SOAP-03.1~03.5, 03.8, 03.9, AC-SOAP-03.1, 03.2, 03.4, 03.6, 03.7 | DF-217 |
| F-SOAP-03.6, 03.7, AC-SOAP-03.3 | DF-218 |
| F-VIZ-01.1~01.6, AC-VIZ-01.1~01.5 | DF-210 |
| F-VIZ-02.2, 02.8, AC-VIZ-02.1, 02.2 | DF-208 |
| F-VIZ-02.1, 02.3~02.7, AC-VIZ-02.3~02.5 | DF-214 (+DF-227 사진 접근) |
| F-VIZ-03.1~03.4, 03.7~03.10, AC-VIZ-03.1~03.3, 03.5, 03.6 | DF-215, DF-216 |
| F-VIZ-04.4, AC-VIZ-04.3 | DF-219 |
| F-VIZ-05.1(체형평가), 05.4, AC-VIZ-05.2 | DF-225 |
| §7.4 conditionKey·seriesBreak | DF-216 |
| C-01~C-04(체형·추이 화면) | DF-210, DF-215, DF-216, DF-219 |
| AC-IA-01, AC-A11Y-01~03(TR-07~TR-10) | DF-226 (+각 화면 스토리) |
| AC-IA-02(`bodyAssessment`) | DF-204, DF-225 |
| NFR-12 | DF-204, DF-223, DF-226 |
| NFR-15, M-04a, M-04b | DF-200, DF-204, DF-207, DF-208, DF-209, DF-223 |
| NFR-17(체형 사진) | DF-205, DF-227(또는 DF-206 대안) |
| M-05 | DF-224 |
| AD-05 | DF-220 |
| §10.7 정책 kind 검증, R-25 | DF-221 |
| TR-07 / TR-08 / TR-09 / TR-10 | DF-204 / DF-208 / DF-210·DF-209 / DF-214·DF-215·DF-219 |
| G-06(시작), Q-18, AS-12, AS-23, AS-30, AS-33 | DF-912·DF-212 / DF-200·DF-207 / DF-217 / DF-201·DF-209 / DF-209 |

**P1b 범위이지만 다른 단계로 넘긴 것(스파인 결정 유지)**
- F-ASM-05.4~05.6(블라인드 보정, 가명 내보내기) → P2 DF-325, DF-326.
- AC-ASM-04.1의 서버 재검증(onWrite) → P2 DF-324.
- F-VIZ-03.5, 03.6(MDC 밴드), 배지, AC-VIZ-03.4, 03.7, 03.8 → P3 DF-382.
- AC-SOAP-03.5(판정 결과 스냅샷) → P3 DF-381.
- AD-04 정책 운영 → P3 DF-384.

---

## 9 변경 이력

| 버전 | 날짜 | 내용 | 작성 |
|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성. 스파인 P1b 스토리 24개 카드화, 추가 제안 DF-227과 충돌 8건(G-P1b-1~8), 가정 ASM-P1b-01~41 | CJH(에이전트 초안) |
| v1.0(릴리스 편집) | 2026-09-24 | 순수 타깃 경로(PostureMath, TrainerDomain/Series)와 `swift test` 경로를 `Packages/TrainerCore`로 고침(V1-04 §6.2) | CJH(AI 에이전트, 릴리스 편집) |
| v1.0.1(정합 패스 2) | 2026-09-24 | 교차 정합성 조정: 경로 규칙 TrainerCore·TrainerKit(R4), 대기 회원 시드 ID·시드 스크립트 정본(R2), DF-209 경계 문제 기록(G-P1b-9, ASM-P1b-43), 리드 결정 기록(ASM-P1b-44), 덱 키 DoR(§4, K-11), 가정 ID 참조(R10) | CJH(AI 에이전트, 정합 편집) |
| v1.1 | 2026-09-25 | DEC-22 MVP 범위(소유자 확인 필요, PR #113): MVP 항목 카드에 `scope/mvp` 라벨과 `### MVP 범위(DEC-22)` 절(지금 만들 것, 미룰 것, 기다리지 않는 의존), MVP 계획에 따라 Sprint 값 변경(원래 계획 병기). 리뷰 반영: 체형 사진 파이프라인 MVP 절 정리(DF-205 FaceMasker만 연기·일반 썸네일 유지, DF-206 뷰당 두 파일·`maskedThumbPath=null`, DF-209 AC-DF-209.10 제외·PhotoRebaser 로컬만, DF-225 로컬 썸네일만), 분석 이벤트 AC는 MVP 뒤(DF-204·DF-206·DF-208·DF-209·DF-210·DF-215), DF-200·DF-207 Vision 대비책(시뮬레이터 실패 시 iPhone 하네스·수동 지정), 파일 머리 DEC-22 범위 안내. 리뷰 반영 3: DF-203 최소 조각을 `scope/mvp`(S10)로 넣고 MVP 절 추가(프로토콜 생성물, 기본 스테이션 `default-v1` 자동 생성, 복장 선택, 세 불리언 `false`), DF-204 MVP 절(기본 스테이션·복장, 시뮬레이터 수평 값 생략, `landmarkEngine`은 DF-207), DF-209(스테이션·조건 복사, `retestGroupId` null), DF-210(재검사 모드·사진 메뉴 제외), DF-216 S10→S11. | CJH(AI 에이전트) |
