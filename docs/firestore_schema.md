# Firestore Schema — D-FET 회원 앱 + 트레이너 앱 공유

D-FET 백엔드는 단일 Firebase 프로젝트(`dfetmanage`)를 회원(Flutter), 트레이너(iPad SwiftUI), 관리자(Web)가 공유한다. 본 문서는 양쪽 앱이 합의해야 하는 컬렉션·필드 스키마를 한 곳에 정리한다.

> **권한 모델 요약**
> - `admin: true` Custom Claim — 관리자 (관리 페이지)
> - `trainer: true` Custom Claim — 트레이너 (iPad SwiftUI)
> - 일반 사용자 — Claim 없음 (회원 Flutter)
> - 권한 부여/회수는 [functions/index.js](../functions/index.js)의 `setTrainerClaim`/`removeTrainerClaim` 등 Cloud Function을 통해서만 한다.

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
| `memberIds` | string[] | 담당 회원 uid 배열 |
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

## `soap_notes/{noteId}` — SOAP 노트 (트레이너 작성, 회원 읽기)

**작성**: SwiftUI 트레이너 앱 ([trainer_ios/DFETTrainer/Data/FirebaseTrainerRepository.swift](../trainer_ios/DFETTrainer/Data/FirebaseTrainerRepository.swift))
**조회**: 회원 Flutter 앱 ([lib/widgets/member_soap_notes_screen.dart](../lib/widgets/member_soap_notes_screen.dart)) + SwiftUI 트레이너 앱

### 정체성 필드 (권한 평가에 사용)
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

### 레거시 평탄 필드 (Flutter `SoapNote.fromFirestore`와 호환)
`subjective`, `painSite`, `painPattern`, `painNow`, `painBest`, `painWorst`, `observation`, `rom`, `mmt`, `neurologicalTests`, `specialTests`, `functionalTests`, `assessment`, `shortTermGoal`, `longTermGoal`, `treatmentPlan`, `homeExercise`, `nextPlan`, `diagnosis`, `bodyRegion`, `caseStatus`

### 구조화 필드 `structured`
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

**SwiftUI ↔ Flutter 매핑 규칙**:
- SwiftUI `SoapNote.subjective` (단일 문자열) → Firestore `subjective` (평탄 필드) + `structured.subjective.chiefComplaint`
- SwiftUI `SoapNote.objective` → `observation` + `structured.objective.observation`
- SwiftUI `SoapNote.assessment` → `assessment` + `structured.assessment.problemList`
- SwiftUI `SoapNote.plan` → `treatmentPlan` + `structured.plan.treatmentPlan`
- SwiftUI `RiskLevel.stable/attention/high` → Firestore `low/medium/high`
- SwiftUI `SoapWorkflowStatus.completed` → Firestore `complete`
- SwiftUI `SoapMetric.value: Double?` → Firestore `value: String` (빈 문자열 허용)
- SwiftUI `drawingData: Data?` → Firestore `drawingData` (Bytes). Flutter는 무시.

**규칙**:
- read: 작성자 트레이너 / `memberId == request.auth.uid && isSharedWithMember == true`인 회원 / 관리자
- create: 호출자가 트레이너이고 `trainerId == auth.uid`이고 `isAssignedTrainer(memberId)`인 경우
- update: 본인 트레이너(단 `trainerId` 변경 불가) 또는 관리자
- delete: 본인 트레이너 또는 관리자

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

1. 본 문서를 먼저 갱신한다 (작성자 = 변경 제안자).
2. SwiftUI/Flutter 양쪽 매핑 코드를 같은 PR에서 수정한다.
3. [trainer_ios/DFETTrainerTests/SoapNoteFirestoreCompatTests.swift](../trainer_ios/DFETTrainerTests/SoapNoteFirestoreCompatTests.swift)의 round-trip 케이스를 추가/수정한다.
4. [firestore.rules](../firestore.rules)와 [functions/index.js](../functions/index.js)를 함께 검토한다.
