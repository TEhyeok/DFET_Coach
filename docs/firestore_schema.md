# Firestore Schema — D-FET 회원 앱 + 트레이너 앱 공유

D-FET 백엔드는 단일 Firebase 프로젝트(`dfetmanage`)를 회원(Flutter), 트레이너(iPad SwiftUI), 관리자(Web)가 공유한다. 본 문서는 양쪽 앱이 합의해야 하는 컬렉션·필드 스키마를 한 곳에 정리한다.

> **정본 관계(v1, DF-006)**
> - 컬렉션·필드의 정본은 [PRD §9.2 컬렉션 명세](PRD_V1.md#92-컬렉션-명세)와 [PRD §9.3 SOAP 스키마 v2](PRD_V1.md#93-soap-스키마-v2)다. 이 문서는 필드 목록을 요약하고 PRD 표로 링크한다. 문자열 길이·배열 상한·범위 같은 **수치는 복사하지 않는다.** 수치는 PRD 표와 아래 JSON Schema에서 읽는다.
> - 구현 수준의 검증식·규칙 코드·JSON 예시는 [V1-05 데이터 모델·보안 규칙](v1/05_DATA_MODEL_AND_RULES.md)(§4 컬렉션, §5 SOAP v2)에 있다.
> - 기계 검증용 JSON Schema(draft 2020-12)는 `schemas/*.schema.json`이다. Firestore 네이티브 타입이 아니라 교차 클라이언트 중립 표기(`{"$ts"}`, `{"$serverTimestamp"}`, `{"$int"}` 태그, [픽스처 규약](../contracts/fixtures/README.md))를 검증한다. 테스트: `node --test tool/contracts/test/schemas.test.mjs`.
> - 충돌하면 PRD가 우선한다. 이 문서나 스키마를 먼저 고치지 않는다([변경 절차](#변경-절차)).

> **권한 모델 요약**
> - `admin: true` Custom Claim — 관리자 (관리 페이지)
> - `trainer: true` Custom Claim — 트레이너 (iPad SwiftUI)
> - 일반 사용자 — Claim 없음 (회원 Flutter)
> - 권한 부여/회수는 [functions/index.js](../functions/index.js)의 `setTrainerClaim`/`removeTrainerClaim` 등 Cloud Function을 통해서만 한다.

## 목차

1. [`users/{uid}`](#usersuid--회원트레이너-공통-프로필)
2. [`trainers/{trainerId}`](#trainerstrainerid--트레이너-메타데이터)
3. [`soap_notes/{noteId}` (v2)](#soap_notesnoteid--soap-노트-v2)
   - [v2 필드 표](#v2-필드-표)
   - [`addenda` 하위 컬렉션](#addenda-하위-컬렉션)
   - [레거시(v1) 읽기 전용](#레거시v1-읽기-전용)
4. [공통 필드 규약(새 원 기록 컬렉션)](#공통-필드-규약새-원-기록-컬렉션)
5. [`pendingMembers/{pendingMemberId}`](#pendingmemberspendingmemberid)
6. [`postureAssessments/{assessmentId}`](#postureassessmentsassessmentid)
7. [`bodyCompositionRecords/{recordId}`](#bodycompositionrecordsrecordid)
8. [`circumferenceMeasurements/{measurementId}`](#circumferencemeasurementsmeasurementid)
9. [`bodyScans/{scanId}`](#bodyscansscanid)
10. [`memberSummaries/{summaryId}`](#membersummariessummaryid)
11. [`consentRecords/{recordId}`](#consentrecordsrecordid)
12. [`memberConsentStates/{memberKey}`](#memberconsentstatesmemberkey)
13. [`consentDocumentVersions/{versionId}`](#consentdocumentversionsversionid)
14. [`rightsRequests/{requestId}`](#rightsrequestsrequestid)
15. [`opsMetrics/{isoWeek}`](#opsmetricsisoweek)
16. [`appConfig/features` (8키)](#appconfigfeatures-8키)
17. [`admins/{uid}`](#adminsuid--관리자-메타데이터), [`posts/{postId}`](#postspostid--커뮤니티-포스트), [`content_workouts`·`content_foods`](#content_workouts-content_foods--관리자-콘텐츠)
18. [변경 절차](#변경-절차)

---

## `users/{uid}` — 회원/트레이너 공통 프로필

| 필드 | 타입 | 작성자 | 비고 |
|------|------|-------|------|
| `uid` | string | Flutter | 문서 ID와 동일 |
| `email` | string | Flutter | |
| `displayName` | string | Flutter | |
| `name` | string | Flutter | 일부 환경에서 displayName 대신 사용 |
| `role` | string | Flutter | `'user'` \| `'trainer'` \| `'admin'` |
| `trainerId` | string? | Functions | 담당 트레이너 uid (`assignMemberToTrainer` 호출 시 세팅) |
| `bodyRegion` | string? | Flutter | SOAP/운동 관련 신체 부위 |
| `program` | string? | Flutter | 운동 프로그램 라벨 |

**규칙**:
- read: 본인, 관리자, 또는 담당 트레이너(`isAssignedTrainer(uid)`)
- write: 본인 또는 관리자만

**서브컬렉션** — `users/{uid}/meals`, `users/{uid}/workouts`
- read: 본인 / 관리자 / 담당 트레이너
- write: 본인만

v1 관련 필드(`assignedTrainerId`, `trainerAssignedAt` 등)는 [V1-05 §4.1](v1/05_DATA_MODEL_AND_RULES.md#41-usersuid-기존-v1-관련-필드만).

---

## `trainers/{trainerId}` — 트레이너 메타데이터

`setTrainerClaim` Cloud Function이 생성/관리. 클라이언트 직접 쓰기는 불가.

| 필드 | 타입 | 비고 |
|------|------|------|
| `trainerId` | string | uid와 동일 |
| `email` | string | |
| `displayName` | string | |
| `specialty` | string? | 전문 분야 (선택) |
| `approvalStatus` | string | `'approved'` \| `'pending'` \| `'revoked'` |
| `memberIds` | string[] | 담당 회원 uid 배열. 담당 관계의 단일 진실원(F-LINK-03.1) |
| `createdAt` | Timestamp | |
| `updatedAt` | Timestamp? | |
| `grantedBy` | string? | 권한 부여한 관리자 uid |
| `revokedAt` | Timestamp? | |
| `revokedBy` | string? | |

**규칙**:
- read: 본인 트레이너 또는 관리자
- write: 클라이언트 금지 (Cloud Function만)

**관계 유지 규칙**: `memberIds[]`와 `users/{uid}.trainerId`는 항상 일관 — `assignMemberToTrainer`/`removeMemberFromTrainer` 함수가 트랜잭션으로 동기 보장.

---

## `soap_notes/{noteId}` — SOAP 노트 (v2)

- 정본: [PRD §9.3 필드 정본](PRD_V1.md#필드-정본). 구현 형태: [V1-05 §5.1](v1/05_DATA_MODEL_AND_RULES.md#51-soap_notesnoteid-필드-정본)·[§5.2 중첩 맵](v1/05_DATA_MODEL_AND_RULES.md#52-중첩-맵-정의)·[§5.4 상태 전이](v1/05_DATA_MODEL_AND_RULES.md#54-상태-전이와-쓰기-가능-키).
- JSON Schema: [`schemas/soap-note-v2.schema.json`](../schemas/soap-note-v2.schema.json). 최상위 `additionalProperties: false`라 `diagnosis`, `structured`, `drawingData` 같은 v1 키는 통과하지 못한다.
- 작성: 트레이너 앱(`trainer_app/`, Swift 코덱 DF-009). 회원은 원 기록을 읽지 않고 `memberSummaries`로만 본다(D9). Flutter는 요약 읽기와 레거시 폴백만(Dart 코덱 DF-007).
- 문서 ID는 자동 ID만 쓴다. `native_<seed>_<date>` ID와 전체 `set` 덮어쓰기는 폐기한다([PRD §9.3 문서 ID 규칙](PRD_V1.md#문서-id-규칙)).

### v2 필드 표

PRD §9.3 필드 정본의 요약이다. 길이·배열 상한과 enum 전체 값은 PRD 표와 스키마를 본다. 필수: ● 필수, ○ 선택, S 서버만, C 조건부.

| 필드 | 타입 | 필수 | 요약 |
|---|---|---|---|
| `schemaVersion` | int `2` | ● | v2 문서 표식 |
| `trainerId` | str\|null | ● | 파생 접근 키. create 때 본인 uid, 이후 서버(`syncRecordAccessKeys`)만 |
| `authorUid` | str | ● | 불변 작성자 |
| `memberUid` / `pendingMemberId` | str\|null | ● 하나 | 회원 키. 대기 기록은 `memberUid=null` |
| `sessionDate` | ts | ● | 세션 시각. 하루 여러 건 허용 |
| `status` | `draft`\|`finalized` | ● | 한 방향 전환. finalized 뒤 정정은 addenda |
| `quickNote` | str | ○ | Live 한 줄 |
| `inkPath`, `inkRevision` | str\|null, int | ○ | 필기 Storage 경로(`soapInk/…`). 문서 인라인 필기 금지 |
| `subjective` | map | ○ | `chiefComplaint`, `painNrs`(정수\|null), `painRegions[]`(regionCode) |
| `objective` | map | ○ | `metrics[]`, `refs`, `snapshots[]`(아래) |
| `exerciseAssessment` | map | ○ | `summary`, `observations[]`. 진단명·KCD·원인 단정 금지 |
| `plan` | map | C | `nextSession`(확정 시 ●), `homeExercise` |
| `memberNote` | str | ○ | 회원에게 남길 한 줄(F-SOAP-02.10) |
| `legalNature` | `coachingRecord` | ● | v1 고정 |
| `memberSummaryId` | str\|null | S | P2 역참조 |
| `finalizedAt` | ts | C | 확정 전환 시 서버 시각 |
| `createdAt`, `updatedAt` | ts | ● | `serverTimestamp()` |
| `migratedFrom` | map | S | MIG-03 이관 표식 `{runId, schemaVersion}` |
| `legacy` | map | S | 이관 원문 보존 `{metricsRaw[], diagnosisRaw?, originalIsShared?, completedCategories?}`, 읽기 전용 |
| `memberId` (레거시) | str | ○ | 호환 기간(P0~P3)에 `memberUid`와 같은 값. 대기 기록에는 없음 |
| `isSharedWithMember` (레거시) | bool | ○ | `false`만. 공유는 `memberSummaries`로만 |
| 그 밖의 v1 필드 | — | ✕ | 쓰기 금지([레거시(v1) 읽기 전용](#레거시v1-읽기-전용)) |

중첩 원소:
- `objective.metrics[]`: `{metricCode, value(num), unit, side(none|left|right|bilateral), sourceGrade, note?}`. `romDeg`는 `joint`·`motion`·`activeOrPassive`, `mmtGrade`는 `muscleGroup`과 정수 `value`가 필수다. `metricCode`는 부록 A 코드이고 스키마는 형식(camelCase)만 본다. 모르는 코드는 버리지 않고 '해석 불가'로 보존한다(F-SOAP-06.2).
- `objective.refs`: `{postureAssessmentIds[], bodyCompositionRecordIds[], circumferenceMeasurementIds[], bodyScanIds[]}`.
- `objective.snapshots[]`: `{refId, metricCode, value, unit, side, sourceGrade, changeStatus, reasonCode|null, policyVersion|null, mdcSource|null, measuredAt}`. 원본이 바뀌어도 고치지 않는다(F-SOAP-03).
- `diagnosis`·KCD 키는 v2에 없다. 레거시 값은 이관 때 `legacy.diagnosisRaw`로만 옮긴다([PRD §9.3 diagnosis·KCD 처리](PRD_V1.md#diagnosiskcd-처리), MIG-04).

### `addenda` 하위 컬렉션

`soap_notes/{noteId}/addenda/{addendumId}` — 정본: [PRD §9.3 addenda 표](PRD_V1.md#soap_notesnoteidaddendaaddendumid), 구현: [V1-05 §5.3](v1/05_DATA_MODEL_AND_RULES.md#53-soap_notesnoteidaddendaaddendumid), JSON Schema: [`schemas/soap-addendum.schema.json`](../schemas/soap-addendum.schema.json).

- 필드: `authorUid`(● `== request.auth.uid`), `createdAt`(● `== request.time`), `reason`(● 수정 사유, 정보주체 정정 요구 포함), `text`(● 추가·정정 내용), `changedFields[]`(○ 정정 대상 필드 경로), `previousValues`(○ 정정 전 값 사본).
- 부모가 finalized일 때만 생성하고 수정·삭제하지 않는다. 필기 정정도 addendum 텍스트로 한다.

### 레거시(v1) 읽기 전용

> **쓰기 금지(MIG-03 적용 시).** 아래는 v1 문서(`schemaVersion` 없음)의 기존 설명이다. MIG-03 적용 시점(P1a 진입 전)부터 v1 create·update 규칙은 영구적으로 false이고, soapV2 플래그를 꺼도 다시 열리지 않는다(R-21, [PRD §9.3 레거시 쓰기 차단과 읽기 호환](PRD_V1.md#레거시-쓰기-차단과-읽기-호환)). 새 코드는 이 형식을 **읽기만** 한다: 코덱은 `schemaVersion`이 없으면 v1로 읽고 metric을 버리지 않으며, 파싱 실패 값은 '레거시(해석 불가)'로 표시한다. v1→v2 매핑은 [V1-05 §5.6](v1/05_DATA_MODEL_AND_RULES.md#56-v1v2-매핑-요약)과 PRD §11.4, 레거시 픽스처는 `contracts/fixtures/soap_legacy/`.

**작성(v1)**: SwiftUI 트레이너 앱 ([trainer_ios/DFETTrainer/Data/FirebaseTrainerRepository.swift](../trainer_ios/DFETTrainer/Data/FirebaseTrainerRepository.swift)), Runner 내장 트레이너(동결)
**조회(v1)**: 회원 Flutter 앱 ([lib/services/firestore_service.dart](../lib/services/firestore_service.dart)) + SwiftUI 트레이너 앱

#### 정체성 필드 (권한 평가에 사용)
| 필드 | 타입 | 비고 |
|------|------|------|
| `trainerId` | string | **필수**. Firestore 규칙 평가의 핵심 |
| `trainerName` | string? | 표시용 |
| `memberId` | string | **필수** |
| `memberName` | string | |
| `memberEmail` | string? | |
| `date` | int (millis) | 세션 일자 |
| `visitType` | string | `'initial'` \| ... |
| `setting` | string | `'field'` \| ... |
| `isSharedWithMember` | bool | 회원 조회 허용 여부 |
| `createdAt` | int (millis) | |
| `updatedAt` | int (millis) | |

#### 레거시 평탄 필드 (Flutter `SoapNote.fromFirestore`와 호환)
`subjective`, `painSite`, `painPattern`, `painNow`, `painBest`, `painWorst`, `observation`, `rom`, `mmt`, `neurologicalTests`, `specialTests`, `functionalTests`, `assessment`, `shortTermGoal`, `longTermGoal`, `treatmentPlan`, `homeExercise`, `nextPlan`, `diagnosis`, `bodyRegion`, `caseStatus`

#### 구조화 필드 `structured`
```jsonc
{
  "subjective":  { "chiefComplaint": "...", "painSite": "...", "painNow": 6, ... },
  "objective":   { "observation": "...", "neurologicalTests": "...", ... },
  "assessment":  { "problemList": "...", "shortTermGoal": "...", "longTermGoal": "..." },
  "plan":        { "treatmentPlan": "...", "homeExercise": "...", "nextPlan": "..." },
  "metrics": [
    {
      "type": "rom" | "mmt" | "pain" | "functional" | "specialTest",
      "label": "고관절 굴곡 ROM",
      "side": "좌" | "우" | "양측" | "해당 없음",
      "value": "120",  // 문자열로 저장 (Flutter 호환)
      "unit": "도",
      "score": 4,       // MMT용
      "note": "..."
    }
  ],
  "workflow": {
    "status": "draft" | "complete" | "shared",
    "completedCategories": ["S", "O", "A", "P"],  // 또는 Flutter는 ["subjective", ...]
    "riskLevel": "low" | "medium" | "high",
    "followUpDate": 1735689600000  // millis, nullable
  }
}
```

**SwiftUI ↔ Flutter 매핑 규칙(v1)**:
- SwiftUI `SoapNote.subjective` (단일 문자열) → Firestore `subjective` (평탄 필드) + `structured.subjective.chiefComplaint`
- SwiftUI `SoapNote.objective` → `observation` + `structured.objective.observation`
- SwiftUI `SoapNote.assessment` → `assessment` + `structured.assessment.problemList`
- SwiftUI `SoapNote.plan` → `treatmentPlan` + `structured.plan.treatmentPlan`
- SwiftUI `RiskLevel.stable/attention/high` → Firestore `low/medium/high`
- SwiftUI `SoapWorkflowStatus.completed` → Firestore `complete`
- SwiftUI `SoapMetric.value: Double?` → Firestore `value: String` (빈 문자열 허용)
- SwiftUI `drawingData: Data?` → Firestore `drawingData` (Bytes). Flutter는 무시.

**규칙(v1, 현행)**:
- read: 작성자 트레이너 / `memberId == request.auth.uid && isSharedWithMember == true`인 회원 / 관리자
- create: 호출자가 트레이너이고 `trainerId == auth.uid`이고 `isAssignedTrainer(memberId)`인 경우
- update: 본인 트레이너(단 `trainerId` 변경 불가) 또는 관리자
- delete: 본인 트레이너 또는 관리자

v2 규칙(DF-020)은 [V1-05 §7.3](v1/05_DATA_MODEL_AND_RULES.md#73-soap_notes와-addenda)에 있다.

---

## 공통 필드 규약(새 원 기록 컬렉션)

[PRD §9.1 공통 필드 규약](PRD_V1.md#공통-필드-규약), 구현: [V1-05 §3.3](v1/05_DATA_MODEL_AND_RULES.md#33-공통-필드-규약원-기록-컬렉션). 원 기록(`soap_notes`, `postureAssessments`, `bodyCompositionRecords`, `circumferenceMeasurements`, `bodyScans`)은 `schemaVersion`, `createdAt`, `updatedAt`, `legalNature`, `trainerId`(파생 접근 키), `authorUid`(신체조성은 `enteredBy`), 회원 키(`memberUid`·`pendingMemberId`)를 가진다. 키는 영문 camelCase만 쓰고, 바이너리는 문서에 넣지 않고 Storage 경로만 둔다. 새 컬렉션은 모두 루트 컬렉션이다(D7).

아래 절은 [PRD §9.2 컬렉션 명세](PRD_V1.md#92-컬렉션-명세)의 표마다 링크와 필드 한 줄 요약을 둔다.

---

## `pendingMembers/{pendingMemberId}`

- 정본: [PRD §9.2](PRD_V1.md#pendingmemberspendingmemberid-신규) · 구현: [V1-05 §4.3](v1/05_DATA_MODEL_AND_RULES.md#43-pendingmemberspendingmemberid-신규-p1a-ep-09) · 신규, P1a
- 필드: `trainerId`, `displayName`, `sex`, `birthYear`, `ageConfirmed14`, `heightCm`(동의 ② 이후), `status`(`pending|promoted|cancelled|expired`), `inviteCodeId`·`promotedUid`·`promotedAt`(S), `schemaVersion`, `createdAt`, `updatedAt`. 연락처 키는 두지 않는다.

## `postureAssessments/{assessmentId}`

- 정본: [PRD §9.2](PRD_V1.md#postureassessmentsassessmentid-신규) · 구현: [V1-05 §4.6](v1/05_DATA_MODEL_AND_RULES.md#46-postureassessmentsassessmentid-신규-규칙테스트-p0-사용-p1b-ep-14) · JSON Schema: [`schemas/posture-assessment.schema.json`](../schemas/posture-assessment.schema.json) · 신규, 사용 P1b
- 필드: 회원 키, `trainerId`, `authorUid`, `capturedAt`, `protocolVersion`, `stationProfileId`, `landmarkEngine{name, version}`, `device{model, osVersion}`, `captureConditions{clothing, barefoot, markersPlaced, verbalConsentCheck, cameraHeightCm, cameraDistanceM, levelDeg, pitchDeg}`, `views[]{view, photoPath, thumbPath, imageRotationDeg, landmarks[]}`, `metrics[]`, `status`(`draft|confirmed|voided`), `isBaseline`, `supersedesId`, `retestGroupId`, `legalNature`, `schemaVersion`, `createdAt`, `updatedAt`.

## `bodyCompositionRecords/{recordId}`

- 정본: [PRD §9.2](PRD_V1.md#bodycompositionrecordsrecordid-신규) · 구현: [V1-05 §4.7](v1/05_DATA_MODEL_AND_RULES.md#47-bodycompositionrecordsrecordid-신규-p1a-ep-11) · JSON Schema: [`schemas/body-composition-record.schema.json`](../schemas/body-composition-record.schema.json) · 신규, P1a
- 필드: 회원 키, `trainerId`, `enteredBy`, `source`(`manualEntry|inbodyApi|healthKit`), `sourceGrade`(`device`), `deviceModel`, `measuredAt`, `fasting`, `timeOfDayBand`, `values{weightKg, bodyFatPercent, bodyFatMassKg, skeletalMuscleMassKg, visceralFatLevel, totalBodyWaterL}`(측정한 키만, 1개 이상), `derived{bmi, heightCmUsed, heightMeasuredAt, sourceGrade}`, `reportPhotoPath`, `externalId`·`idempotencyKey`·`rawPath`(v2 서버 전용, F-BC-04.1), `status`(`active|voided`), `voidedAt`, `voidReason`, `legalNature`, `schemaVersion`, `createdAt`, `updatedAt`.

## `circumferenceMeasurements/{measurementId}`

- 정본: [PRD §9.2](PRD_V1.md#circumferencemeasurementsmeasurementid-신규) · 구현: [V1-05 §4.8](v1/05_DATA_MODEL_AND_RULES.md#48-circumferencemeasurementsmeasurementid-신규-tape-p1aobservedsection-p2) · JSON Schema: [`schemas/circumference-measurement.schema.json`](../schemas/circumference-measurement.schema.json) · 신규, tape P1a·observedSection P2
- 필드: 회원 키, `trainerId`, `authorUid`, `metricCode`, `side`(`none|left|right`), `valueCm`, `sourceGrade`(`tape|observedSection`), `protocolId`, `protocolVersion`, `landmarkNote`(custom이면 필수), `conditionsNote`, `measuredAt`, `trialIndex`, `scanId`, `referenceTapeCm`(비교 전용), `validationStatus`, `isBeta`, `status`, `voidedAt`, `voidReason`, `legalNature`, `schemaVersion`, `createdAt`, `updatedAt`.

## `bodyScans/{scanId}`

- 정본: [PRD §9.2](PRD_V1.md#bodyscansscanid-신규-lidarbeta-p2) · 구현: [V1-05 §4.9](v1/05_DATA_MODEL_AND_RULES.md#49-bodyscansscanid-신규-p2-lidarbeta-ep-19) · 신규, P2, lidarBeta(JSON Schema는 P2 스토리에서 추가)
- 필드: `memberUid`(대기 회원 불가), `trainerId`, `authorUid`, `takenAt`, `sourceApp`(`bodypath|trainerApp`), `device{model, hasLiDAR}`, `captureMode`(`cameraOrbit`), `algorithmVersion`, `meshAlgorithm`, `meshSHA256`, `quality{integratedFrames, flags[]}`, `thumbnailPath`, `rawLocation`(`deviceLocal`), `sections[]{metricCode, perimeterMm, contour2dMm, confirmed}`, `isBeta`, `legalNature`, `schemaVersion`, `createdAt`, `updatedAt`.

## `memberSummaries/{summaryId}`

- 정본: [PRD §9.2](PRD_V1.md#membersummariessummaryid-신규-소비자본-서버-작성) · 구현: [V1-05 §4.10](v1/05_DATA_MODEL_AND_RULES.md#410-membersummariessummaryid-신규-p2-서버-작성-ep-17) · JSON Schema: [`schemas/member-summary.schema.json`](../schemas/member-summary.schema.json) · 신규, P2, 소비자본(서버 작성)
- 필드: `memberUid`, `trainerId`, `sharedByUid`·`sharedByDisplayName`(V1-05 추가), `sourceType`(`soapNote|bodyReport`), `sourceIds[]`, `title`, `body`, `highlights[]{refId, metricCode, value, unit, side, sourceGrade, measuredAt, changeStatus, reasonCode, mdcSource, mdc, seriesKey, comparedTo}`, `sharedPhotoPaths[]`, `nextPlan`, `policyVersion`, `status`(`shared|revoked`), `sharedAt`, `revokedAt`, `firstViewedAt`(V1-05 추가), `schemaVersion`. 해제 시 내용 필드를 비운다.

## `consentRecords/{recordId}`

- 정본: [PRD §9.2](PRD_V1.md#consentrecordsrecordid-신규-append-only-서버-작성) · 구현: [V1-05 §4.11](v1/05_DATA_MODEL_AND_RULES.md#411-consentrecordsrecordid-신규-p1a-append-only-서버-작성-ep-08) · JSON Schema: [`schemas/consent-record.schema.json`](../schemas/consent-record.schema.json) · 신규, P1a, append-only(서버 작성)
- 필드: `subjectUid`, `pendingMemberId`, `consentType`(`required|healthData|bodyImaging|sharing|research`), `action`(`grant|withdraw`), `documentVersion`, `channel`(`memberApp|trainerDeviceInPerson`), `recordedAt`, `recordedBy`, `signaturePath`, `reconfirmedAt`, 그리고 V1-05 추가 `capturedAt`·`reconfirmOf`·`clientCaptureId`, `schemaVersion`.

## `memberConsentStates/{memberKey}`

- 정본: [PRD §9.2](PRD_V1.md#memberconsentstatesmemberkey-신규-서버-파생) · 구현: [V1-05 §4.12](v1/05_DATA_MODEL_AND_RULES.md#412-memberconsentstatesmemberkey-신규-p1a-서버-파생) · 신규, P1a, 서버 파생
- 필드: 유형별 맵 `required`·`healthData`·`bodyImaging`·`sharing`·`research` = `{granted, documentVersion, updatedAt, recordId}`, `updatedAt`, `schemaVersion`. 없는 유형은 미동의.

## `consentDocumentVersions/{versionId}`

- 정본: [PRD §9.2](PRD_V1.md#consentdocumentversionsversionid-신규-관리자-서버-작성) · 구현: [V1-05 §4.13](v1/05_DATA_MODEL_AND_RULES.md#413-consentdocumentversionsversionid-신규-p1a-진입-전-관리자-서버-작성-ad-03) · 신규, 관리자 서버 작성
- 필드: `consentType`, `version`, `title`, `purpose`, `items[]`, `retention`, `recipient`, `refusalNotice`, `privacyPolicyVersion`, `status`(`draft|published|retired`), `publishedAt`, `schemaVersion`. published는 불변.

## `rightsRequests/{requestId}`

- 정본: [PRD §9.2](PRD_V1.md#rightsrequestsrequestid-신규-서버-작성) · 구현: [V1-05 §4.15](v1/05_DATA_MODEL_AND_RULES.md#415-rightsrequestsrequestid-신규-p1a-서버-작성) · 신규, P1a, 서버 작성
- 필드: `memberUid`, `type`(`access|rectification|erasure|suspension`), `channel`(`memberApp|trainer|admin`), `status`(`received|inProgress|completed|rejected`), `receivedAt`, `dueAt`, `completedAt`, `handledBy`, `exportPath`, `schemaVersion`. 자유 텍스트 사유는 두지 않는다.

## `opsMetrics/{isoWeek}`

- 정본: [PRD §9.2](PRD_V1.md#opsmetricsisoweek-신규-서버-전용) · 구현: [V1-05 §4.16](v1/05_DATA_MODEL_AND_RULES.md#416-opsmetricsisoweek-신규-p1a-서버-전용) · 신규, 서버 전용
- 필드: `isoWeek`, `computedAt`, `schemaVersion`, 지표별 건수·비율 맵(`m03`, `m05`, `m06`, `m07`, `m09`, `m10`). 회원·트레이너 식별자와 건강 값은 넣지 않는다.

## `appConfig/features` (8키)

- 정본: [PRD §9.2](PRD_V1.md#appconfigfeatures-기존-확장) · 구현: [V1-05 §4.17](v1/05_DATA_MODEL_AND_RULES.md#417-appconfigfeatures-기존-확장-p0) · 예시: [`schemas/feature-flags.example.json`](../schemas/feature-flags.example.json) · 기존 확장, P0
- 필드(8키, 모두 bool): 기존 `gut`, `blood`, `insights`와 새 `bodyAssessment`, `bodyComposition`, `soapV2`, `memberShare`, `lidarBeta`(기본 false). 문서나 키가 없으면 false로 본다. admin_web이 `updatedAt`, `updatedBy`를 함께 쓴다. 규칙 `featureOn`이 이 문서를 get한다.

---

## `admins/{uid}` — 관리자 메타데이터

기존 컬렉션. `setAdminClaim` Cloud Function이 관리.

| 필드 | 타입 | 비고 |
|------|------|------|
| `email`, `displayName` | string | |
| `role` | string | `'admin'` \| `'super_admin'` |
| `approvalStatus` | string | `'approved'` \| `'pending'` \| `'rejected'` |
| `grantedAt`, `grantedBy` | Timestamp, string | |

---

## `posts/{postId}` — 커뮤니티 포스트

회원 Flutter 앱 전용. 트레이너 SwiftUI에서는 사용하지 않음.

| 필드 | 타입 |
|------|------|
| `authorId`, `title`, `body`, `createdAt`, ... | (생략) |

서브컬렉션: `likes/{userId}`, `comments/{commentId}`.

---

## `content_workouts/{...}`, `content_foods/{...}` — 관리자 콘텐츠

| 액세스 | |
|--------|--|
| read | 인증된 모든 사용자 |
| write | 관리자만 |

---

## 변경 절차

[PRD §9.3 변경 절차와 교차 클라이언트 테스트](PRD_V1.md#변경-절차와-교차-클라이언트-테스트)와 [V1-05 §14](v1/05_DATA_MODEL_AND_RULES.md#14-변경-절차같은-pr-동시-갱신)를 따른다(F-SOAP-06.4, ADR-005).

1. PRD(소유자 PR)가 먼저 바뀌어 있어야 한다. 그다음 본 문서, V1-05, `schemas/*.schema.json`을 같은 PR에서 고친다.
2. Swift(트레이너 앱)와 Flutter(요약 읽기, 레거시 폴백) 매핑 코드를 같은 PR에서 수정한다.
3. 교차 클라이언트 왕복 테스트를 추가·수정한다.
   - 공유 픽스처: `contracts/fixtures/soap_*`(`soap_v2/`, `soap_legacy/`, 규약은 [contracts/fixtures/README.md](../contracts/fixtures/README.md))
   - Dart: `test/contracts/`(DF-007)
   - Swift: `trainer_app/Packages/TrainerCore/Tests/TrainerDomainTests/`(DF-009)
   - JSON Schema: `node --test tool/contracts/test/schemas.test.mjs`(DF-006)
4. [firestore.rules](../firestore.rules)와 규칙 테스트(`functions/test/rules/`, PRD §9.4), [functions/index.js](../functions/index.js)를 함께 검토한다.
