# DB·권한 설계

## 주요 컬렉션

| 컬렉션 | 문서 ID | 핵심 필드 | 작성자 | 읽기 |
|---|---|---|---|---|
| `users` | Firebase UID | profile, careType, role | 본인 제한/서버 | 본인·담당 트레이너·관리자 |
| `trainers` | trainer UID | memberIds, approvalStatus | 서버 | 본인·관리자 |
| `memberAliases` | source+external ID hash | userId | 서버 | 관리자 |
| `gutReports` | 검사 식별 hash | userId, alpha, phylum, overall, policyVersion | Functions | 본인·담당 트레이너·관리자 |
| `gutReportExperts` | consumer와 동일 | normalized, scored, rawPath | Functions | 담당 트레이너·관리자 |
| `bloodReports` | 검사 식별 hash | biomarkers, panels, overall, policyVersion | Functions | 본인·담당 트레이너·관리자 |
| `bloodReportExperts` | consumer와 동일 | normalized, scored, rawPath | Functions | 담당 트레이너·관리자 |
| `healthSnapshots` | 기준시점 hash | axes, missingAxes, completeness, policyVersion | Functions | 본인·담당 트레이너·관리자 |
| `referenceRangeVersions` | kind--version | kind, version, status, active, publishedAt | 관리자 서버 | 관리자 |
| `insightPolicyVersions` | integrated--version | windowDays, weights, behavior, rules | 관리자 서버 | 관리자 |
| `ingestionJobs` | idempotency hash | payloadHash, status, reportId, error | Functions | 관리자 직접, lab은 관리자 서버 경유 |
| `clinicalReportKeys` | 검사 종류+외부 ID+revision hash | idempotencyKey, payloadHash, reportId | Functions | 클라이언트 접근 금지 |
| `auditLogs` | 자동 ID | actor, action, target, before/after, createdAt | 서버 | 관리자 |
| `appConfig/features` | 고정 | gut, blood, insights | 관리자 서버 | 인증 사용자 |

## Storage

`clinical-ingest/{type}/{jobId}/payload.json`에 원문을 저장한다. metadata에 SHA-256, schemaVersion, jobId를 둔다. 클라이언트 쓰기는 전부 거부하고 관리자만 읽을 수 있다.

## 역할 경계

| 주체 | 소비자본 | 전문가본 | 원문 | 수집 | 정책 | 감사 |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| 회원 | 본인 | - | - | - | - | - |
| 담당 트레이너 | 담당 회원 | 담당 회원 | - | - | - | - |
| 비담당 트레이너 | - | - | - | - | - | - |
| lab_operator | - | - | - | 서버 경유 | - | - |
| admin | 전체 | 전체 | 읽기 | 서버 경유 | 관리 | 읽기 |
| Functions Admin SDK | 쓰기 | 쓰기 | 쓰기 | 처리 | 읽기 | 쓰기 |

## 보안 불변식

- 회원은 `role`, `isAdmin`, `isTrainer`, `isApproved`, `isPremium`을 스스로 변경할 수 없다.
- 임상 리포트·스냅샷·정책·작업·감사 문서는 클라이언트가 직접 쓰지 못한다.
- 트레이너 배정은 `users.trainerId/assignedTrainerId`와 `trainers.memberIds`를 transaction으로 동기화한다.
- 관리자 서버는 페이지 가드뿐 아니라 각 POST API에서 역할·대상 범위를 재검증한다.
- HMAC secret, Firebase Admin 자격증명, 실제 건강데이터는 Git에 저장하지 않는다.

## 보존·삭제

실제 데이터 투입 전 기관이 보존기간, 회원탈퇴 시 삭제/비식별화, 감사로그 보존, 법적 보존 예외를 승인해야 한다. 현재 코드는 자동 임상 데이터 삭제 정책을 임의로 적용하지 않는다.
