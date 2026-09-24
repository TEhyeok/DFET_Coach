# ADR-017 Functions 구조·리전·런타임

| 항목 | 내용 |
|---|---|
| 문서 ID | ADR-017 |
| 버전 | v1.0.1 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | §10.6, NFR-16, NFR-09, F-PRIV-05, dfet:firebase.json:30-36 |
| 관련 에픽·스토리 | EP-04, EP-08 / DF-037, DF-025, DF-109, DF-132, DF-386 |
| 변경 규칙 | [문서 변경](../01_AGILE_WORKING_AGREEMENT.md#문서-변경) |

## 목차

1. [상태](#1-상태)
2. [맥락](#2-맥락)
3. [결정](#3-결정)
4. [결과](#4-결과)
5. [대안](#5-대안)
6. [PRD 근거](#6-prd-근거)
7. [재검토 조건](#7-재검토-조건)
8. [관련 스토리](#8-관련-스토리)
9. [변경 이력](#9-변경-이력)

## 1 상태

**Accepted** (2026-09-24, 소유자 CJH). Firestore 트리거 리전은 V1-04 ASM-04-15에 따라 G-09(Q-08)에서 확인한 DB 위치를 쓴다.

## 2 맥락

- `functions/index.js` 한 파일에 onCall 12개(dfet:functions/index.js:96-745)와 onRequest `clinicalApi`(:50)가 있다. v1 계열 `(data, context)` 계약을 v2로 등록하는 어댑터가 있다(:32-48).
- 런타임은 Node 22(dfet:firebase.json:35, dfet:functions/package.json:18), 테스트는 `node --test`다(package.json:8-10).
- `clinicalApi`(dfet:firebase.json:18-22)와 회원용 callable 3개(`deleteOwnAccount` :378-380, `toggleCommunityLike` :450-452, `addCommunityComment` :488-490)는 asia-northeast3이다. 회원 앱도 이 리전으로 호출한다(dfet:lib/screens/settings_screen.dart:857, dfet:lib/services/community_service.dart:21). 관리자·트레이너 역할 callable 9개(`setAdminClaim`, `removeAdminClaim`, `listAllUsers`, `getUserDetails`, `deleteUserData`, `setTrainerClaim`, `removeTrainerClaim`, `assignMemberToTrainer`, `removeMemberFromTrainer`)는 기본 리전이다.
- 관리자 판정은 `callerToken.admin`만 본다(dfet:functions/index.js:79).

## 3 결정

1. **신규 callable과 스케줄**은 asia-northeast3, Node 22, v2(`onCall`, `onSchedule`)다. 기존 어댑터(:32-48)는 `src/shared/callable.js`로 옮기고 `src/shared/region.js`의 `regionalCallable(handler, opts)`로 감싼다.
2. **Firestore 트리거**(`syncRecordAccessKeys` 트리거부, `auditSoapFinalized`, `verifyPostureConfirmed`)는 Eventarc 제약상 Firestore DB 위치와 같은 리전에 둔다. 상수 `FIRESTORE_TRIGGER_REGION`로 관리하고 G-09에서 값을 확정한다.
3. **CommonJS JavaScript와 `node:test`를 유지**한다(AS-DEV-12). 새 npm 의존성은 ADR 없이 추가하지 않는다.
4. 코드는 `src/<domain>/<functionName>.js`에 두고 각 파일은 등록용 `handler`와 테스트 가능한 순수 `core`를 export한다. `index.js`는 export만 모은다.
5. 오류 코드는 `invalid-argument`, `permission-denied`, `failed-precondition`, `not-found`, `already-exists`, `resource-exhausted` 여섯 가지로 표준화하고 응답은 `{ok: true, ...}`다.
6. 쓰기는 트랜잭션이나 배치로 하고 같은 단위에서 감사 기록을 남긴다(`src/shared/audit.js`, audit-actions 화이트리스트).
7. 클라이언트 재시도가 있는 callable은 멱등 키 `requestId`(recordConsent는 `clientCaptureId`, V1-06 §3.7)를 받는다(`src/shared/idempotency.js`).
8. 로그는 구조화 로그(`fn`, `code`, `count`, `durationMs`)만 남기고 uid·이메일·건강 값을 넣지 않는다.
9. 기존 기본 리전 callable의 이름·리전은 옮기지 않는다. callable `enforceAppCheck`는 P3 진입 체크리스트 항목이다(DF-386).

## 4 결과

**좋아지는 점**
- 에이전트가 도메인 폴더 단위로 병렬 작업해도 충돌이 적다.
- 순수 core 테스트로 에뮬레이터 없이 로직을 검증한다.

**비용·위험**
- 리전이 섞인다(기존 기본 리전, 신규 asia-northeast3, 트리거는 DB 위치). 클라이언트는 callable마다 리전을 지정해야 한다.

**후속 작업**
- DF-037 shared 구조, DF-025 재정렬, DF-109 recordConsent, DF-132 삭제 통합, DF-386 App Check 강제.

## 5 대안

| 대안 | 장점 | 채택하지 않은 이유 |
|---|---|---|
| TypeScript 전환 | 타입 안전 | v1 범위 밖 비용 |
| index.js 단일 파일 확장 | 변경 적음 | 병렬 작업 충돌, 가독성 저하 |
| 기존 callable까지 리전 이전 | 리전 통일 | 회원 앱 호출 경로 변경 위험(NFR-16) |

## 6 PRD 근거

§10.6, NFR-16, NFR-09, F-PRIV-05, dfet:firebase.json:30-36. 설계 반영 위치: [V1-04 §15](../04_ARCHITECTURE.md#15-functions-구조), 계약은 [V1-06](../06_API_SPEC.md).

## 7 재검토 조건

- G-09에서 Firestore DB 위치가 asia-northeast3이 아닌 것으로 확인되면 트리거 리전과 처리방침 문구를 함께 검토한다(Q-DEV-04-01).
- 함수 수가 늘어 콜드 스타트가 문제되면 codebase 분리를 검토한다.

## 8 관련 스토리

DF-037, DF-025, DF-109, DF-132, DF-386.

## 9 변경 이력

| 버전 | 날짜 | 변경 요지 | PR | PRD 영향 |
|---|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성 | — | 없음 |
| v1.0.1 | 2026-09-24 | 교차 정합성 조정 — 정합 패스 2: 멱등 키 이름 R5(§3 결정 7 `clientRequestId` → `requestId`, recordConsent는 `clientCaptureId`, V1-06 §3.7) | — | 없음 |
