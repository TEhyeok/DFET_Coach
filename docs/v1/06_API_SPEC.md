# API·인터페이스 명세

| 항목 | 내용 |
|---|---|
| 문서 ID | V1-06 |
| 버전 | v1.0 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | §5.3, §5.5, §6.0.2, §6.0.3, §6.4.2, §6.4.4, F-SOAP-03~05, §6.6(F-LINK-01~05), §6.7(F-PRIV-01~07), §7.5~§7.9, §9.1~§9.7, §10.2.3, §10.4.3, §10.5~§10.8(NFR-04~NFR-10, NFR-16), §11, §12.3, 부록 A·B |
| 관련 에픽·스토리 | EP-03, EP-04, EP-07, EP-08, EP-09, EP-10, EP-16, EP-17, EP-18, EP-19, EP-20, EP-21 / DF-025, DF-027, DF-037, DF-101, DF-104, DF-107, DF-109, DF-112, DF-115, DF-123, DF-132~DF-137, DF-221, DF-304~DF-319, DF-324, DF-331, DF-380~DF-381, DF-386 |
| 변경 규칙 | [문서 변경](01_AGILE_WORKING_AGREEMENT.md#문서-변경) |

## 목차

- [1. 범위와 읽는 법](#1-범위와-읽는-법)
- [2. 현행 Functions 기준선(코드 확인)](#2-현행-functions-기준선코드-확인)
- [3. 공통 규약](#3-공통-규약)
  - [3.1 런타임·리전·배포 옵션](#31-런타임리전배포-옵션)
  - [3.2 파일 배치와 모듈 형태](#32-파일-배치와-모듈-형태)
  - [3.3 인증·역할·담당 판정](#33-인증역할담당-판정)
  - [3.4 요청 검증](#34-요청-검증)
  - [3.5 응답과 오류 형식](#35-응답과-오류-형식)
  - [3.6 오류 코드·messageKey 카탈로그](#36-오류-코드messagekey-카탈로그)
  - [3.7 멱등성](#37-멱등성)
  - [3.8 트랜잭션·배치 규칙](#38-트랜잭션배치-규칙)
  - [3.9 감사 기록 공통 형식](#39-감사-기록-공통-형식)
  - [3.10 로깅](#310-로깅)
  - [3.11 App Check·레이트 리밋·시간](#311-app-check레이트-리밋시간)
  - [3.12 공통 JSON Schema 정의](#312-공통-json-schema-정의)
- [4. Functions 카탈로그(요약)](#4-functions-카탈로그요약)
- [5. 기존 함수 변경 명세](#5-기존-함수-변경-명세)
- [6. 신규 Functions 상세 명세](#6-신규-functions-상세-명세)
- [7. admin_web 서버 API](#7-admin_web-서버-api)
- [8. 트레이너 앱 Swift 계약](#8-트레이너-앱-swift-계약)
- [9. 회원 앱 Dart 계약](#9-회원-앱-dart-계약)
- [10. Firestore 쿼리 카탈로그](#10-firestore-쿼리-카탈로그)
- [11. 분석 이벤트·결과 패키지 계약(참조)](#11-분석-이벤트결과-패키지-계약참조)
- [12. 버전 관리·호환 규칙](#12-버전-관리호환-규칙)
- [13. 테스트 케이스 총괄](#13-테스트-케이스-총괄)
- [14. 가정(ASM)·충돌·열린 질문](#14-가정asm충돌열린-질문)
- [15. 변경 이력](#15-변경-이력)

---

## 1. 범위와 읽는 법

이 문서는 D-FET Coach v1의 **호출 계약**을 정본으로 정한다. 대상은 다음과 같다.

| 대상 | 이 문서가 정하는 것 | 정본이 다른 문서인 것 |
|---|---|---|
| Cloud Functions(callable·trigger·scheduled·http) | 이름, 종류, 리전, 권한, 요청·응답 JSON Schema, 검증, 멱등 키, 오류, 부수효과, 감사, 레이트 리밋, 단계, 테스트 케이스 | 컬렉션 필드 정의는 [05_DATA_MODEL_AND_RULES.md](05_DATA_MODEL_AND_RULES.md)(PRD §9.2·§9.3), 판정·산식은 [09_ALGORITHMS_SPEC.md](09_ALGORITHMS_SPEC.md)(PRD §7) |
| admin_web 서버 라우트 | 경로, 메서드, 요청·응답, 검증, 감사 | 화면 구성은 [08_MEMBER_APP_AND_ADMIN_SPEC.md](08_MEMBER_APP_AND_ADMIN_SPEC.md) |
| 트레이너 앱 Swift 도메인 프로토콜 | 프로토콜·메서드 시그니처, 오류 enum, callable DTO, 오류→syncState 대응 | 화면 동작은 [07_TRAINER_APP_SPEC.md](07_TRAINER_APP_SPEC.md), 모듈 구조는 [04_ARCHITECTURE.md](04_ARCHITECTURE.md) |
| 회원 앱 Dart 저장소 | 클래스·메서드 시그니처, 예외 | 화면은 V1-08 |
| Firestore 쿼리 | 화면별 쿼리·인덱스·오류 표시 | 인덱스 정의 파일은 V1-05 |
| 분석 이벤트·금지어·문구 | 이벤트 계약 요약만 | [12_COPY_ANALYTICS_AND_LINT.md](12_COPY_ANALYTICS_AND_LINT.md) |

읽는 법

- **PRD가 우선한다.** 이 문서와 PRD가 다르면 PRD를 따르고 [§14](#14-가정asm충돌열린-질문)에 충돌로 기록한다.
- **ASM-NN**은 이 문서 안의 가정 번호다. 다른 문서에서는 `V1-06/ASM-06-03`처럼 인용한다. PRD로 올릴 때는 AS-34부터 새 번호를 받는다(PRD §13.4).
- **TC-06-XXX-NN**은 이 문서의 테스트 케이스 ID다. XXX는 함수 약어다([§13](#13-테스트-케이스-총괄)).
- 모든 예시 값은 **합성 데이터**다. 실제 회원·트레이너 정보와 비밀값은 어디에도 넣지 않는다.
- 코드 근거는 `dfet:경로:줄` 형식이며, 이 문서를 쓸 때 원본 파일을 직접 열어 확인했다. 기준은 저장소 작업 트리(브랜치 `feature/integrated-care-2026`, 미커밋 변경 포함, 2026-09-24)다.
- 표기: ● 필수, ○ 선택, S 서버만 씀. JSON Schema는 draft 2020-12 문법이다. 공통 정의는 `common#/$defs/…`로 참조한다([§3.12](#312-공통-json-schema-정의)).

---

## 2. 현행 Functions 기준선(코드 확인)

작업 트리의 `functions/index.js`(745줄)에는 onCall 12개와 onRequest 1개가 있다. 커밋본(HEAD d841412)에는 onCall 9개만 있고, `deleteOwnAccount`, `toggleCommunityLike`, `addCommunityComment`는 미커밋이다(MIG-01 A분류 대상).

| export | 종류 | 리전 | 권한 판정 | 응답 형식 | 근거 |
|---|---|---|---|---|---|
| `clinicalApi` | onRequest(HMAC) | asia-northeast3 | HMAC 키 | HTTP JSON | dfet:functions/index.js:50-63 |
| `setAdminClaim` | onCall | 기본(us-central1, 옵션 없음) | `token.admin` | `{success, message, uid}` | dfet:functions/index.js:96-157 |
| `removeAdminClaim` | onCall | 기본 | `verifyAdmin` | `{success, message, uid}` | dfet:functions/index.js:162-203 |
| `listAllUsers` | onCall | 기본 | `verifyAdmin` | `{users, pageToken}` | dfet:functions/index.js:209-245 |
| `getUserDetails` | onCall | 기본 | `verifyAdmin` | `{auth, profile, recentMeals, recentWorkouts}` | dfet:functions/index.js:251-324 |
| `deleteUserData` | onCall | 기본 | `verifyAdmin` | `{success, message}` | dfet:functions/index.js:330-371 |
| `deleteOwnAccount` | onCall | asia-northeast3 | 로그인 본인 | `{success}` | dfet:functions/index.js:378-444 |
| `toggleCommunityLike` | onCall | asia-northeast3 | 로그인 | `{success}` | dfet:functions/index.js:450-485 |
| `addCommunityComment` | onCall | asia-northeast3 | 로그인 | `{success, commentId}` | dfet:functions/index.js:488-519 |
| `setTrainerClaim` | onCall | 기본 | `verifyAdmin` | `{success, message, uid}` | dfet:functions/index.js:528-580 |
| `removeTrainerClaim` | onCall | 기본 | `verifyAdmin` | `{success, message, uid}` | dfet:functions/index.js:586-629 |
| `assignMemberToTrainer` | onCall | 기본 | `verifyAdmin` | `{success, message}` | dfet:functions/index.js:635-696 |
| `removeMemberFromTrainer` | onCall | 기본 | `verifyAdmin` | `{success, message}` | dfet:functions/index.js:701-745 |

확인된 사실과 이 명세에 주는 영향

1. **어댑터.** v2 `onCall`을 감싸 `(data, context)` 계약을 유지한다(dfet:functions/index.js:32-48). `context`에는 `auth`만 들어 있고 `app`(App Check)이나 `rawRequest`는 없다. 신규 함수는 이 어댑터를 `src/shared/callable.js`로 옮기고 확장한다([§3.2](#32-파일-배치와-모듈-형태)).
2. **리전 혼재.** 회원 앱은 `FirebaseFunctions.instanceFor(region: 'asia-northeast3')`로 호출한다(dfet:lib/screens/settings_screen.dart:857-858, dfet:lib/services/community_service.dart:21). 기본 리전 callable의 이름·리전은 v1에서 바꾸지 않는다(NFR-16).
3. **트랜잭션 읽기 순서 결함(정적 분석, 실행 미확인).** `removeMemberFromTrainer`는 트랜잭션 안에서 `tx.update(trainerRef)` 뒤에 `tx.get(memberRef)`를 호출한다(dfet:functions/index.js:720-726). Firestore 서버 SDK 트랜잭션은 모든 읽기를 쓰기 전에 해야 하므로, 트레이너 문서가 있을 때 이 호출은 실패할 가능성이 높다. DF-025에서 읽기를 앞으로 옮긴다([§5.1](#51-assignmembertotrainer--removememberfromtrainer)).
4. **담당 변경 경로가 두 개다.** admin_web AD-01은 callable을 쓰지 않고 Admin SDK로 직접 `users.trainerId`와 `trainers.memberIds`를 바꾼다(dfet:admin_web/app/api/admin/assignments/route.ts:18-61). 따라서 `syncRecordAccessKeys`는 callable 호출만으로는 부족하고 **`users/{uid}` 문서 트리거가 필수**다([§6.1](#61-syncrecordaccesskeys)).
5. **플래그 라우트는 덮어쓰기다.** `appConfig/features`를 `set()`으로 merge 없이 쓰고 zod는 3키만 허용한다(dfet:admin_web/app/api/admin/feature-flags/route.ts:10, :20-24). 5키를 추가하지 않은 채 저장하면 새 키가 지워진다. DF-027에서 8키 스키마로 바꾼다([§7.1](#71-post-apiadminfeature-flags-ad-07-df-027)).
6. **감사 기록 형식이 두 가지다.** admin_web `writeAudit`은 `target` 맵, `actorEmail`, `createdAt`을 쓴다(dfet:admin_web/lib/audit.ts:12-20). PRD §9.2는 `targetCollection`, `targetId`, `memberUid`, `at`, 화이트리스트 `metadata`를 요구하고 §9.7은 이메일을 금지한다. Functions 신규 기록은 PRD 형식을 쓰고, admin_web은 DF-136에서 맞춘다([§3.9](#39-감사-기록-공통-형식), 충돌 CF-06-03).
7. **별칭 해석은 `userId`를 읽는다.** `resolveMemberId`는 `memberAliases.userId`만 본다(dfet:functions/src/clinical/ingestion.js:94-101). `linkMemberAlias`는 `memberUid`와 `userId`에 같은 값을 쓴다(F-LINK-04.2).
8. **에뮬레이터 구성.** `firebase.json`에는 firestore(18080)와 storage(19199) 포트만 있고 auth·functions 항목이 없다(dfet:firebase.json:37-50). CI e2e는 `--only functions,firestore,storage`로 실행한다(dfet:.github/workflows/ci.yml:55). 인증이 필요한 callable e2e를 위해 auth 에뮬레이터를 추가한다(ASM-06-19).

---

## 3. 공통 규약

### 3.1 런타임·리전·배포 옵션

| 항목 | 값 | 근거 |
|---|---|---|
| 런타임 | Node 22, CommonJS, `'use strict'` | dfet:firebase.json:35, dfet:functions/package.json, ADR-017 |
| SDK | `firebase-functions` ^7.3.2(v2 API), `firebase-admin` ^13.6 | dfet:functions/package.json:25-26 |
| 신규 리전 | `asia-northeast3` 고정. 모든 신규 export에 명시 | NFR-16 |
| 기존 callable | 이름·리전 유지. 기본 리전 함수는 계속 기본 리전 | NFR-16, PRD §10.6 '건드리지 않는 것' |
| 기본 옵션 | `memory: '256MiB'`, `timeoutSeconds: 60`, `maxInstances: 10`, `concurrency: 80` | 제안값(ASM-06-01) |
| 무거운 작업 | `exportMemberData`, `deleteMemberCascade` 사용 함수, `purgeExpiredRecords`: `memory: '1GiB'`, `timeoutSeconds: 540` | 제안값(ASM-06-01) |
| App Check | `enforceAppCheck: false`(P0~P2). P3 진입 체크리스트에서 true(DF-386) | NFR-09, ADR-017 |
| 비밀 | `defineSecret('INVITE_CODE_HMAC_KEY')`(P2). 에뮬레이터는 `functions/.secret.local` | ADR-019, dfet:.github/workflows/ci.yml:54 패턴 |
| 배포 | 소유자만 `firebase deploy --project dfetmanage --only functions:<name>`(`.firebaserc` 없음). 태그 `functions-YYYYMMDD-N` | ADR-014 |

배포 순서 규칙: **Functions → 규칙·인덱스 → 클라이언트**. 새 callable이나 필드를 쓰는 클라이언트는 서버가 배포된 뒤에만 출시한다([§12](#12-버전-관리호환-규칙)).

### 3.2 파일 배치와 모듈 형태

```
functions/
├─ index.js                          # export만 모은다. 로직 금지
├─ src/shared/
│  ├─ region.js                      # REGION = 'asia-northeast3', 기본 옵션 객체
│  ├─ callable.js                    # defineCallable() — v2 onCall 어댑터(index.js:32-48 이전·확장)
│  ├─ errors.js                      # fail(code, messageKey, details), 표준 코드 목록
│  ├─ auth.js                        # requireAuth, requireTrainer, requireAdmin, requireMemberSelf, isStaff
│  ├─ access.js                      # isAssignedTrainer(tx|db, trainerUid, memberUid), isPendingOwner(...)
│  ├─ validate.js                    # 의존성 없는 스키마 검증기(§3.4)
│  ├─ audit.js                       # writeAuditLog(writer, entry) — contracts/audit-actions 화이트리스트
│  ├─ log.js                         # 구조화 로그, hashId()
│  ├─ time.js                        # addBusinessDaysKst(), isoWeekKst()
│  ├─ krHolidays.js                  # 영업일 계산용 공휴일 표(ASM-06-20)
│  ├─ zipStore.js                    # 무압축 ZIP 작성기(zlib.crc32, 신규 의존성 없음)
│  └─ generated/                     # contracts/*.json 복사본(생성물, 손대지 않음)
├─ src/access/syncRecordAccessKeys.js
├─ src/consent/recordConsent.js
├─ src/members/{issueInviteCode,redeemInviteCode,linkMemberAlias}.js
├─ src/privacy/{deleteMemberCascade,purgeMemberRecords,submitRightsRequest,exportMemberData,
│               purgeExpiredRecords,logRecordAccess,auditSoapFinalized,alertOverdueObligations}.js
├─ src/summaries/{createMemberSummary,revokeMemberSummary,getSharedPhotoUrl,markSummaryViewed,prohibitedTerms}.js
├─ src/posture/verifyPostureConfirmed.js
├─ src/change/evaluateChange.js
└─ src/ops/aggregateOpsMetrics.js
```

모든 도메인 파일은 **순수 core와 handler를 분리해 export**한다. core는 `{db, bucket, now, auth}`를 주입받아 단위 테스트에서 가짜로 바꿀 수 있어야 한다.

```js
// functions/src/consent/recordConsent.js
'use strict';
const {defineCallable} = require('../shared/callable');
const {schema} = require('./recordConsent.schema');   // §6.2 JSON Schema를 validate.js DSL로 옮긴 것

async function recordConsentCore({db, bucket, now, auth, data}) { /* §6.2 처리 절차 */ }

module.exports = {
  recordConsentCore,
  recordConsent: defineCallable({
    name: 'recordConsent',
    schema,
    auth: 'signedIn',            // 'signedIn' | 'trainer' | 'admin' | 'memberNonStaff'
    options: {memory: '512MiB'},
    handler: recordConsentCore,
  }),
};
```

```js
// functions/src/shared/callable.js — 계약
// defineCallable({name, schema, auth, options, handler}) 는 다음을 보장한다.
// 1) region = REGION, enforceAppCheck = ENFORCE_APP_CHECK(환경 변수, 기본 false)
// 2) auth 수준 검사(§3.3) → 실패 시 unauthenticated / permission-denied
// 3) validate(schema, request.data) → 실패 시 invalid-argument, details.fields
// 4) handler({db, bucket, now: () => Timestamp.now(), auth: request.auth, app: request.app, data})
// 5) handler 결과에 ok:true가 없으면 붙인다
// 6) HttpsError가 아닌 예외는 로그(§3.10) 후 internal / 'common.internal'로 바꾼다(원문 메시지 미노출)
```

`index.js`는 다음처럼 export만 추가한다.

```js
Object.assign(exports,
  require('./src/access/syncRecordAccessKeys').triggers,  // {syncRecordAccessKeys, syncRecordAccessKeysOnConsent, syncRecordAccessKeysOnPending}
  {recordConsent: require('./src/consent/recordConsent').recordConsent},
  /* … */);
```

### 3.3 인증·역할·담당 판정

| 수준 | 조건 | 실패 코드 / messageKey |
|---|---|---|
| `signedIn` | `request.auth != null` | `unauthenticated` / `auth.required` |
| `trainer` | `signedIn` && `auth.token.trainer === true` | `permission-denied` / `auth.notTrainer` |
| `admin` | `signedIn` && `auth.token.admin === true` | `permission-denied` / `auth.notAdmin` |
| `memberNonStaff` | `signedIn` && `trainer`·`admin`·`super_admin`·`lab_operator`(또는 `role=='lab_operator'`) claim이 모두 없음 | `permission-denied` / `auth.staffAccountNotAllowed` |

- 관리자 판정은 **custom claim `admin === true` 하나**다(ADR-018). 기존 `verifyAdmin`(dfet:functions/index.js:68-87)과 같은 의미이며, Firestore 규칙의 `admins`·`users.role` 대체 경로는 Functions에서 쓰지 않는다.
- 담당 판정은 트랜잭션 안에서 읽는다. 규칙 헬퍼(PRD §9.4)와 같은 의미여야 한다.

```js
// functions/src/shared/access.js
// reader: Transaction 또는 Firestore. 트랜잭션 안에서는 반드시 쓰기 전에 호출한다(§3.8).
async function isAssignedTrainer(db, reader, trainerUid, memberUid) {
  const snap = await reader.get(db.doc(`trainers/${trainerUid}`));
  return snap.exists && Array.isArray(snap.data().memberIds) && snap.data().memberIds.includes(memberUid);
}
async function isPendingOwner(db, reader, trainerUid, pendingMemberId) {
  const snap = await reader.get(db.doc(`pendingMembers/${pendingMemberId}`));
  return snap.exists && snap.data().trainerId === trainerUid && snap.data().status === 'pending';
}
// canWriteFor(memberKey): memberUid가 있으면 isAssignedTrainer, 없으면 isPendingOwner (PRD §9.4)
```

- 담당 여부 확인에 `users.trainerId`를 쓰지 않는다. 단일 진실원은 `trainers/{uid}.memberIds ↔ users.trainerId` 쌍이고(F-LINK-03.1) 규칙이 `memberIds`를 보므로 서버도 `memberIds`를 본다.

### 3.4 요청 검증

- 신규 npm 의존성은 ADR 없이 추가하지 않는다(ADR-017). 검증은 `src/shared/validate.js`의 작은 DSL로 한다. 이 문서의 JSON Schema가 계약 정본이고, DSL 정의는 그 번역이다. 단위 테스트는 각 절의 예시 요청(유효·무효)을 그대로 쓴다.
- 공통 규칙
  1. **최상위 알 수 없는 키는 거부**한다(`additionalProperties: false`). 클라이언트가 새 필드를 보내려면 서버가 먼저 배포돼야 한다([§12](#12-버전-관리호환-규칙)).
  2. 문자열은 앞뒤 공백을 제거한 뒤 길이를 잰다. 길이는 UTF-16 코드 단위가 아니라 **코드 포인트** 기준이다(`[...s].length`).
  3. 문서 ID 형식 문자열은 `^[A-Za-z0-9_-]{1,128}$`이다. `/`, `.`, `..`를 거부한다.
  4. 시각은 ISO 8601 UTC 문자열(`2026-11-02T01:23:45.000Z`)로 받고, 서버에서 `Timestamp`로 바꾼다.
  5. 실패하면 `invalid-argument`, `details.fields = ["selections[1].consentType", …]`를 돌려준다. 값 자체는 details에 넣지 않는다(NFR-10).

### 3.5 응답과 오류 형식

성공 응답(신규 함수 전부)

```json
{ "ok": true, "replayed": false, "...": "함수별 필드" }
```

- `replayed: true`는 같은 멱등 키로 이미 처리된 요청을 다시 받았다는 뜻이다([§3.7](#37-멱등성)). 응답 본문은 최초 처리 결과와 같다.
- 기존 함수(§2 표)는 `{success, message}` 형식을 그대로 둔다(하위 호환, [§12](#12-버전-관리호환-규칙)).

오류 응답은 `HttpsError(code, message, details)`다.

```json
{
  "code": "failed-precondition",
  "message": "consent.healthDataRequired",
  "details": {
    "messageKey": "consent.healthDataRequired",
    "retryable": false,
    "fields": [],
    "violations": []
  }
}
```

- `message`와 `details.messageKey`는 같은 **영문 키**다. 사용자 문장은 클라이언트가 키로 찾아 표시한다(트레이너 앱 `Localizable.xcstrings`, 회원 앱 문자열 표). 서버는 한국어 문장을 보내지 않는다. 이렇게 하면 금지어 린트(ADR-016)가 클라이언트 문자열 카탈로그 한 곳만 보면 된다.
- `details`에는 건강 수치, 이름, 이메일, uid, 경로, 자유 텍스트를 넣지 않는다(NFR-10). 예외: `createMemberSummary`의 `violations`는 호출자 자신이 보낸 본문의 위치 정보다([§6.13](#613-createmembersummary)).
- 클라이언트는 모르는 `messageKey`를 받으면 코드별 기본 문장(`common.<code>`)을 쓴다.

### 3.6 오류 코드·messageKey 카탈로그

callable 코드와 HTTP 상태, 재시도 가능 여부

| callable code | HTTP | `retryable` | SyncEngine 처리(§8.7) | 쓰는 경우 |
|---|---:|---|---|---|
| `invalid-argument` | 400 | false | `syncFailed`(영구) | 스키마·형식 위반 |
| `failed-precondition` | 400 | false | `syncFailed`(영구). 단 `consent.notYetConfirmed`는 `awaitingConsent` | 상태·동의·플래그 조건 불충족 |
| `unauthenticated` | 401 | false | 세션 잠금 → 로그인 | 로그인 없음 |
| `permission-denied` | 403 | false | `syncFailed`(영구), 담당 해제 안내 | claim·담당 불일치 |
| `not-found` | 404 | false | `syncFailed`(영구) | 대상 문서 없음 |
| `already-exists` | 409 | false | `syncFailed`(영구) | 멱등 키 재사용 충돌, 초대 conflict, 별칭 중복 |
| `aborted` | 409 | true | 백오프 재시도 | 트랜잭션 경합 |
| `resource-exhausted` | 429 | true(대기 후) | 백오프 재시도 | 레이트 리밋 |
| `internal` | 500 | true | 백오프 재시도, 연속 5회면 `syncFailed` | 예상 못 한 오류 |
| `unavailable` | 503 | true | 백오프 재시도 | 일시 장애 |
| `deadline-exceeded` | 504 | true | 백오프 재시도 | 타임아웃 |

공통 messageKey

| messageKey | code | 의미 |
|---|---|---|
| `auth.required` | unauthenticated | 로그인 필요 |
| `auth.notTrainer` | permission-denied | trainer claim 없음 |
| `auth.notAdmin` | permission-denied | admin claim 없음 |
| `auth.staffAccountNotAllowed` | permission-denied | 직원 계정은 회원 기능 사용 불가(F-LINK-02.8) |
| `member.notAssigned` | permission-denied | 호출자가 담당 트레이너가 아님 |
| `member.pendingNotOwned` | permission-denied | 대기 회원 생성자가 아니거나 pending 아님 |
| `member.notFound` | not-found | 회원·대기 회원 문서 없음 |
| `flag.disabled` | failed-precondition | 관련 기능 플래그가 꺼짐 |
| `idempotency.keyReused` | already-exists | 같은 멱등 키(`requestId`, `recordConsent`는 `clientCaptureId`)로 다른 내용을 보냄 |
| `common.invalidArgument` | invalid-argument | 스키마 위반(세부는 fields) |
| `common.internal` | internal | 서버 내부 오류 |
| `common.rateLimited` | resource-exhausted | 호출 한도 초과 |

함수별 messageKey는 각 절의 오류 표에 있다. messageKey 전체 목록은 `contracts/`에 두지 않고 이 문서가 정본이다. 클라이언트 문자열 카탈로그는 DF-012(트레이너)와 DF-306(회원)에서 이 표를 옮긴다(ASM-06-02).

### 3.7 멱등성

| 종류 | 멱등 키 | 방식 |
|---|---|---|
| 클라이언트가 문서를 만드는 callable | 요청의 `requestId`(UUID v4, 클라이언트 생성) | **결정적 문서 ID**로 `create()`한다. 이미 있으면 내용(회원 키·유형)을 비교해 같으면 기존 결과를 `replayed:true`로 돌려주고, 다르면 `already-exists / idempotency.keyReused` |
| `recordConsent`(문서 여러 개를 자동 ID로 만듦) | 요청의 `clientCaptureId`(= 트레이너 앱 `LocalConsentCapture.captureId`) | 레코드는 자동 ID로 만들고 각 레코드에 `clientCaptureId`를 저장한다. 트랜잭션 안에서 `consentRecords where clientCaptureId == X limit 1`을 조회해 있으면 비교 후 `replayed:true` 또는 `idempotency.keyReused`([§6.2.5](#625-멱등성), V1-05 §4.11·ASM-05-12) |
| 상태 전환 callable(`revokeMemberSummary` 등) | 대상 문서 ID | 이미 목표 상태면 `replayed:true` |
| 읽기·URL 발급 | 없음 | 부수효과가 감사 로그뿐 |
| 트리거 | 이벤트 재전달을 전제 | 결과가 입력 상태로만 정해지게(결정적) 짜고, 감사 로그는 결정적 ID(`<action>_<targetId>`)로 `create()`한다 |
| 스케줄 | 실행 시각 | 매 실행이 현재 상태만 보고 남은 일을 처리한다. 두 번 실행돼도 결과 같음 |

- 트레이너 앱 Outbox는 `OutboxItem.requestId`를 처음 만들 때 한 번 정하고, 재시도에서 바꾸지 않는다([§8.6](#86-syncengine--outbox)). 동의 항목(`.callConsent`)은 `OutboxItem.requestId == UUID(LocalConsentCapture.captureId)`이고 요청 본문에는 `clientCaptureId`로 실린다.
- 새 멱등 전용 컬렉션은 만들지 않는다(PRD §9.2 컬렉션 목록 밖).

### 3.8 트랜잭션·배치 규칙

1. 트랜잭션은 **모든 `get`을 모든 쓰기보다 먼저** 한다(§2의 3번 결함 재발 방지). 코드 리뷰 체크 항목이다.
2. 한 트랜잭션·배치의 쓰기는 **400건 이하**로 나눈다(한도 500, 여유 100).
3. 여러 컬렉션을 훑는 작업(재정렬, 승격, 삭제)은 청크 단위로 커밋하고, 각 청크가 독립적으로 멱등이어야 한다. 중간에 끊겨도 다시 실행하면 남은 것만 처리한다.
4. `serverTimestamp()`는 `FieldValue.serverTimestamp()`만 쓴다. 클라이언트 시각을 저장 시각으로 쓰지 않는다(PRD §9.1 공통 필드 규약).
5. Storage 파일은 Firestore 트랜잭션에 포함되지 않는다. 순서는 함수별로 정하고, 고아 파일은 `purgeExpiredRecords`가 치운다([§6.8](#68-purgeexpiredrecords)).

### 3.9 감사 기록 공통 형식

모든 Functions 감사 기록은 `src/shared/audit.js`의 `writeAuditLog(writer, entry)`로 쓴다. `writer`는 트랜잭션·배치·db 중 하나다.

```json
{
  "action": "consentChanged",
  "actorUid": "synthTrainerA",
  "actorRole": "trainer",
  "targetCollection": "consentRecords",
  "targetId": "3f2b8c1e-5d7a-4b1e-9a51-0c8e2d7f1a90_healthData",
  "memberUid": "synthMember0001",
  "at": "<serverTimestamp>",
  "metadata": { "consentType": "healthData", "action": "grant", "channel": "trainerDeviceInPerson" },
  "schemaVersion": 1
}
```

| 필드 | 규칙 |
|---|---|
| `action` | `contracts/audit-actions.v1.json`에 있는 값만. 없으면 예외(테스트에서 실패) |
| `actorRole` | `member \| trainer \| admin \| system` |
| `memberUid` | 대기 회원이면 `null`이고 `metadata.pendingMember: true` |
| `metadata` | 해당 action의 `metadataKeys` 화이트리스트만. 값은 enum·bool·정수 건수만. 건강 수치, 이름, 이메일, 자유 메모, 경로 금지(PRD §9.7) |
| 문서 ID | 트리거는 `<action>_<targetId>`(중복 방지), 그 밖에는 자동 ID |

action별 metadataKeys(정본은 `contracts/audit-actions.v1.json`, DF-033)

| action | 단계 | metadataKeys |
|---|---|---|
| `healthRecordRead` | P1a | `surface`(`TR-03` \| `adminMemberDetail` \| `adminExport`), `pendingMember` |
| `soapFinalized` | P1a | (없음) |
| `consentChanged` | P1a | `consentType`, `action`(`grant`\|`withdraw`), `channel`, `reconfirm`(bool) |
| `dataDeleted` | P1a | `trigger`(`memberSelf`\|`admin`\|`retention`\|`consentWithdrawal`\|`pendingCancelled`), `scope`(`all`\|`healthData`\|`bodyImaging`), `counts`(맵: 컬렉션·prefix → 정수) |
| `rightsRequestHandled` | P1a | `type`, `stage`(`received`\|`completed`\|`rejected`), `channel` |
| `member.assignment.update`(기존 admin_web 이름 유지) | P0 | `handover`(bool), `mode`(`assign`\|`reassign`\|`remove`), `trainerUid`(기존 키, 트레이너 uid) |
| `summaryShared`, `summaryRevoked` | P2 | `sourceType`, `reason`(revoke만: `trainer`\|`consentWithdrawal`\|`reshare`) |
| `memberPromoted` | P2 | `recordCount`(정수), `resumed`(bool) |
| `postureReverted` | P2 | `violation`(`landmarkUnconfirmed`\|`sourceGradeMismatch`) |

- 담당 변경 감사는 PRD §9.7의 '기존 관리자 쓰기 감사 유지 + `metadata.handover` 추가'를 따라 admin_web 기존 action `member.assignment.update`(dfet:admin_web/app/api/admin/assignments/route.ts:62)를 callable 경로에서도 같은 이름으로 쓴다. 기존 admin_web action 문자열(`app.feature_flags.update` 등)도 `contracts/audit-actions.v1.json`에 등록해야 린트·화이트리스트 검사를 통과한다(DF-033, ASM-06-03).
- 기존 admin_web 기록의 `createdAt`은 읽을 때 `at`으로 간주한다(PRD §9.2).

### 3.10 로깅

- `firebase-functions/logger`의 구조화 로그만 쓴다. `console.log` 금지(기존 `console.error`는 해당 파일을 고칠 때 교체).
- 로그에 넣지 않는 것: uid 원문, 이메일, 이름, 건강 수치, 경로, 요청 본문(NFR-10). 식별이 필요하면 `hashId(uid) = sha256("log:" + uid).slice(0, 12)`를 쓴다.
- 공통 필드: `{fn, event, requestIdHash?, code?, count?, durationMs}`. `event`는 `dfet.<domain>.<what>` 형식이다.
- 경보용 이벤트(로그 기반 알림, DF-933): `dfet.obligation.overdue`, `dfet.access.syncFailed`, `dfet.delete.failed`. severity는 `ERROR`다.

### 3.11 App Check·레이트 리밋·시간

- **App Check.** 클라이언트는 P0부터 토큰을 붙인다(트레이너 앱 App Attest·Debug provider, 회원 앱 기존 `firebase_app_check`). 서버 강제는 P3(DF-386) 전까지 끈다. 그 전에는 `request.app`이 없을 때 로그만 남긴다(`dfet.appcheck.missing`, 건수 확인용).
- **레이트 리밋.** 공통 리밋은 두지 않는다. 함수별 리밋은 해당 절에 적는다(`redeemInviteCode` 1시간 5회 실패, `issueInviteCode` 대기 회원당 1시간 10회).
- **시간.** 서버 시각은 `Timestamp.now()`. 영업일·ISO 주·'당일'은 **Asia/Seoul** 기준이다(M-03 '센터 현지'). 영업일 계산은 `krHolidays.js`의 공휴일 표를 쓴다(ASM-06-20).
- **측정 시각 상한.** 클라이언트가 보내는 측정·캡처 시각은 `now + 5분` 이하(PRD §9.1 공통 필드 규약과 같은 제안값), `now − 7일` 이상(오프라인 draft 파기 기준 AS-32과 같은 값)이어야 한다.

### 3.12 공통 JSON Schema 정의

```json
{
  "$id": "common",
  "$defs": {
    "DocId": { "type": "string", "pattern": "^[A-Za-z0-9_-]{1,128}$" },
    "RequestId": { "type": "string", "format": "uuid" },
    "ClientCaptureId": { "type": "string", "pattern": "^[A-Za-z0-9_-]{8,64}$", "description": "recordConsent 전용 멱등 키. 트레이너 앱은 LocalConsentCapture.captureId(UUID 문자열), 회원 앱은 호출마다 만든 UUID v4(§6.2.5, V1-05 ASM-05-12)" },
    "IsoTime": { "type": "string", "format": "date-time" },
    "MemberKey": {
      "oneOf": [
        { "type": "object", "required": ["memberUid"], "additionalProperties": false,
          "properties": { "memberUid": { "$ref": "#/$defs/DocId" } } },
        { "type": "object", "required": ["pendingMemberId"], "additionalProperties": false,
          "properties": { "pendingMemberId": { "$ref": "#/$defs/DocId" } } }
      ]
    },
    "ConsentType": { "enum": ["required", "healthData", "bodyImaging", "sharing", "research"] },
    "ConsentAction": { "enum": ["grant", "withdraw"] },
    "ConsentChannel": { "enum": ["trainerDeviceInPerson", "memberApp"] },
    "SourceGrade": { "enum": ["tape", "device", "photoManual", "photoAuto", "observedSection",
                              "modelEstimate", "aiAppearance", "selfReport", "trainerObserved", "derived"] },
    "Side": { "enum": ["none", "left", "right", "bilateral"] },
    "ChangeStatus": { "enum": ["meaningfulImprovement", "withinError", "meaningfulDecline", "indeterminate", "pendingPolicy"] },
    "ReasonCode": { "enum": ["conditionMismatch", "deviceChanged", "protocolChanged", "noMdc",
                             "noComparison", "referenceMetric", "betaMetric"] },
    "MdcSource": { "enum": ["literature", "inHouse"] },
    "MetricCode": { "type": "string", "description": "contracts/metric-catalog.v1.json의 metricCode 중 하나(생성 코드로 enum 검사)" },
    "RightsRequestType": { "enum": ["access", "rectification", "erasure", "suspension"] },
    "ConsentStateEntry": {
      "type": "object", "additionalProperties": false,
      "required": ["granted", "documentVersion", "recordId", "updatedAt"],
      "properties": {
        "granted": { "type": "boolean" },
        "documentVersion": { "type": "string" },
        "recordId": { "type": "string" },
        "updatedAt": { "$ref": "#/$defs/IsoTime" }
      }
    },
    "ConsentState": {
      "type": "object", "additionalProperties": false,
      "properties": {
        "required": { "$ref": "#/$defs/ConsentStateEntry" },
        "healthData": { "$ref": "#/$defs/ConsentStateEntry" },
        "bodyImaging": { "$ref": "#/$defs/ConsentStateEntry" },
        "sharing": { "$ref": "#/$defs/ConsentStateEntry" },
        "research": { "$ref": "#/$defs/ConsentStateEntry" }
      }
    }
  }
}
```

- enum 값의 정본은 PRD 부록 B이며, 코드에서는 `contracts/vocab.v1.json`에서 생성한 상수를 쓴다(ADR-005). 이 표와 생성물이 다르면 생성물이 틀린 것이다.
- `ConsentState`에서 키가 없으면 미동의다(PRD §9.2 `memberConsentStates`).

---

## 4. Functions 카탈로그(요약)

리전 열의 '신규'는 asia-northeast3, '기본'은 코드에 region이 없는 기존 함수다. 인증 열은 [§3.3](#33-인증역할담당-판정) 수준이다.

| # | export | 종류 | 리전 | 호출 주체 / 트리거 | 인증 | 단계 | 스토리 | PRD |
|---|---|---|---|---|---|---|---|---|
| 6.1 | `syncRecordAccessKeys`, `syncRecordAccessKeysOnConsent`, `syncRecordAccessKeysOnPending` + core | trigger ×3 + 내부 모듈 | 신규 | `users/{uid}` 갱신, `memberConsentStates/{key}` 쓰기, `pendingMembers/{id}` 갱신 | — | P0 | DF-025 | F-LINK-03.4~03.6, F-LINK-05.4 |
| 5.1 | `assignMemberToTrainer`, `removeMemberFromTrainer`(수정) | callable | 기본(유지) | admin_web·관리 스크립트 | admin | P0 | DF-025 | F-LINK-03.4, AD-01 |
| 6.2 | `recordConsent` | callable | 신규 | 트레이너 앱 TR-14, 회원 앱 MB-06(P2) | signedIn(+조건) | P1a | DF-109, DF-112 | F-PRIV-01~03 |
| 6.3 | `auditSoapFinalized` | trigger | 신규 | `soap_notes/{noteId}` 갱신 | — | P1a | DF-123 | F-SOAP-04.7 |
| 6.4 | `logRecordAccess` | callable | 신규 | 트레이너 앱 TR-03 | trainer | P1a | DF-115 | F-PRIV-05.1, 05.3 |
| 6.5 | `submitRightsRequest` | callable | 신규 | 트레이너·관리자(P1a), 회원(P2) | signedIn(+조건) | P1a | DF-135 | F-PRIV-07.1, 07.4 |
| 6.6 | `exportMemberData` | callable | 신규 | admin_web·관리자 | admin | P1a | DF-135 | F-PRIV-07.2 |
| 6.7 | `deleteOwnAccount`, `deleteUserData`(수정) → `deleteMemberCascade` core | callable | 각각 유지 | 회원 / 관리자 | signedIn / admin | P1a | DF-132 | F-PRIV-04 |
| 6.8 | `purgeExpiredRecords` | scheduled(매일 03:00 KST) | 신규 | — | — | P1a | DF-133 | §9.7, F-PRIV-02.3, F-LINK-01.5 |
| 6.9 | `alertOverdueObligations` | scheduled(매일 09:00 KST) | 신규 | — | — | P1a | DF-134 | F-PRIV-04.4, F-PRIV-07.4, F-LINK-03.5 |
| 6.10 | `aggregateOpsMetrics` | scheduled(매주 월 04:00 KST) | 신규 | — | — | P1a(M-03), P1b(M-05), P2(나머지) | DF-137, DF-224 | §5.3 |
| 6.11 | `issueInviteCode` | callable | 신규 | 트레이너 앱 TR-14 | trainer | P2 | DF-304 | F-LINK-02.1~02.3 |
| 6.12 | `redeemInviteCode` | callable | 신규 | 회원 앱 MB-05 | memberNonStaff | P2 | DF-305 | F-LINK-02.4~02.8, F-PRIV-03.4 |
| 6.13 | `createMemberSummary` | callable | 신규 | 트레이너 앱 TR-06 | trainer | P2 | DF-309, DF-313 | F-SOAP-05, F-LINK-05.2, F-VIZ-06 |
| 6.14 | `revokeMemberSummary` | callable | 신규 | 트레이너 앱 TR-06 | trainer | P2 | DF-310 | F-SOAP-05.8~05.9, F-LINK-05.3 |
| 6.15 | `getSharedPhotoUrl` | callable | 신규 | 회원 앱 MB-01·02 | memberNonStaff | P2 | DF-314 | F-LINK-05.6, F-VIZ-06.5 |
| 6.16 | `markSummaryViewed` | callable | 신규 | 회원 앱 MB-02·MB-04 | memberNonStaff | P2 | DF-335(추가 제안, 채택 대기) | M-06, M-07(ASM-06-04) |
| 6.17 | `linkMemberAlias` | callable | 신규 | 트레이너 앱 TR-13 | trainer | P2 | DF-319 | F-LINK-04 |
| 6.18 | `verifyPostureConfirmed` | trigger | 신규 | `postureAssessments/{id}` 쓰기 | — | P2 | DF-324 | AC-ASM-04.1, AS-30 |
| 6.19 | `evaluateChange` + core | callable + 내부 모듈 | 신규 | 트레이너 앱 TR-10, 요약·스냅샷 | trainer | P3 | DF-380, DF-381 | §7.5, §7.9 |
| 6.20 | `clinicalApi`(bodycomp kind) | http(기존) | 기존 | 센터 서버(HMAC) | HMAC | V2 | DF-500 | F-BC-04 |

---

## 5. 기존 함수 변경 명세

### 5.1 `assignMemberToTrainer` / `removeMemberFromTrainer`

| 항목 | 내용 |
|---|---|
| 스토리·단계 | DF-025, P0 |
| 리전·이름 | 변경 없음(기본 리전). NFR-16 |
| 인증 | 변경 없음(`verifyAdmin`, `token.admin`) |
| 응답 | 기존 `{success, message}` 유지 + 추가 필드 `accessKeySync: {status, updated}`(하위 호환 추가) |

요청(추가 필드는 선택이며 없으면 기존 동작과 같다)

```json
{
  "type": "object", "additionalProperties": false,
  "required": ["trainerUid", "memberUid"],
  "properties": {
    "trainerUid": { "$ref": "common#/$defs/DocId" },
    "memberUid": { "$ref": "common#/$defs/DocId" },
    "allowReassign": { "type": "boolean", "default": true, "description": "assign 전용. false면 다른 담당이 있을 때 conflict" }
  }
}
```

- 기존 함수는 최상위 알 수 없는 키를 거부하지 않았다. 호환을 위해 **이 두 함수만** 알 수 없는 키를 무시한다([§3.4](#34-요청-검증) 예외).
- `allowReassign` 기본값을 true로 둬서 현재 동작(이전 트레이너에서 자동 제거, dfet:functions/index.js:668-674)을 유지한다. AD-01의 '담당 변경'은 확인 대화 뒤 true로, 신규 배정 화면은 false로 호출한다(ASM-06-05).

변경 사항

1. **읽기 순서 수정(remove).** `trainerSnap`과 `memberSnap`을 모두 읽은 뒤 쓴다([§3.8](#38-트랜잭션배치-규칙) 1번).
2. **conflict(assign).** `allowReassign === false`이고 `users.trainerId`가 있으며 요청 트레이너와 다르면 `failed-precondition / assignment.conflict`.
3. **감사.** 트랜잭션 안에서 `member.assignment.update`를 쓴다. `metadata = {mode, handover}`. `handover`는 트랜잭션 시점 `memberConsentStates/{memberUid}.sharing.granted === true`이고 이전 담당이 있었을 때 true.
4. **재정렬.** 트랜잭션 커밋 직후 `syncRecordAccessKeysCore({memberKey: {memberUid}, reason: 'assignment'})`를 **동기 호출**하고 결과를 `accessKeySync`로 돌려준다. 실패해도 배정은 되돌리지 않고 `accessKeySync.status = 'deferred'`로 응답한다. 트리거(§6.1)가 같은 일을 다시 하므로 결과는 수렴한다.
5. **트레이너 문서 없음(assign).** 기존대로 `not-found`(메시지는 기존 한국어 유지).

테스트

| ID | 상황 | 기대 |
|---|---|---|
| TC-06-ASG-01 | 트레이너 문서가 있는 상태에서 remove | 성공(기존 결함 회귀 방지), `users.trainerId` 삭제, `memberIds`에서 제거 |
| TC-06-ASG-02 | 담당 A인 회원을 B에게 assign(`allowReassign` 생략) | A.memberIds 제거, B 추가, `member.assignment.update(mode=reassign)` 1건 |
| TC-06-ASG-03 | 같은 상황, `allowReassign:false` | `failed-precondition / assignment.conflict`, 변경 없음 |
| TC-06-ASG-04 | ④ 없는 회원 재배정 후 B로 soap_notes list | B 결과 0건(AC-LINK-05.4) |
| TC-06-ASG-05 | ④ 있는 회원 재배정 | finalized·confirmed·active 기록만 `trainerId=B`, draft는 null |
| TC-06-ASG-06 | 알 수 없는 키 `foo` 포함 | 무시하고 성공(호환) |

### 5.2 `deleteOwnAccount` / `deleteUserData`

두 함수는 이름·리전·인증을 유지하고 본문을 `deleteMemberCascade` core 호출로 바꾼다. 상세는 [§6.7](#67-deletemembercascade와-deleteownaccount--deleteuserdata).

### 5.3 역할 claim 함수

- `setAdminClaim`, `removeAdminClaim`, `setTrainerClaim`, `removeTrainerClaim`은 v1에서 계약을 바꾸지 않는다.
- DF-101(P1a)에서 판정만 통일한다. `setAdminClaim`이 쓰는 `users.role='admin'`, `isAdmin:true`(dfet:functions/index.js:141-146)는 규칙의 대체 경로 제거 뒤에도 메타데이터로만 남는다.
- `removeTrainerClaim` 뒤 트레이너 앱은 다음 토큰 갱신에서 잠긴다(NFR-08). 서버 쪽 추가 동작은 없다.

### 5.4 `clinicalApi`

v1에서는 변경하지 않는다. V2(DF-500)에서 `INGESTION_TYPES`(dfet:functions/src/clinical/constants.js:42)에 `bodycomp`를 더하고, `resolveMemberId`가 `memberUid ?? userId`를 읽게 바꾼다([§6.20](#620-clinicalapi-bodycomp-kind-v2)).

---
## 6. 신규 Functions 상세 명세

각 절의 구성은 같다: 개요 → 요청·응답 스키마(callable) 또는 트리거 조건 → 검증 → 처리 절차 → 멱등성 → 오류 → 부수효과 → 감사 → 레이트 리밋 → 테스트 케이스. 공통 규약([§3](#3-공통-규약))은 반복하지 않는다.

### 6.1 `syncRecordAccessKeys`

| 항목 | 내용 |
|---|---|
| 종류 | 내부 모듈 `syncRecordAccessKeysCore` + Firestore 트리거 3개 |
| export | `syncRecordAccessKeys`(`onDocumentUpdated('users/{uid}')`), `syncRecordAccessKeysOnConsent`(`onDocumentWritten('memberConsentStates/{memberKey}')`), `syncRecordAccessKeysOnPending`(`onDocumentUpdated('pendingMembers/{pendingMemberId}')`) — 트리거를 셋으로 나눈 이유는 ASM-06-06 |
| 리전·옵션 | asia-northeast3, `retry: true`, `memory: '512MiB'`, `timeoutSeconds: 300` |
| 파일 | `functions/src/access/syncRecordAccessKeys.js` |
| 단계·스토리 | P0, DF-025 |
| PRD | F-LINK-03.4~03.6, F-LINK-05.4, F-PRIV-02.3(② 철회 시 `trainerId=null`), §9.1 파생 접근 키, R-06, R-07, RISK-10 |
| 호출자(내부) | `assignMemberToTrainer`, `removeMemberFromTrainer`([§5.1](#51-assignmembertotrainer--removememberfromtrainer)), `recordConsent`(§6.2), `redeemInviteCode`(§6.12) |

#### 6.1.1 트리거 조건

| 트리거 | 실행 조건(아니면 즉시 종료) | memberKey |
|---|---|---|
| `syncRecordAccessKeys` | `before.trainerId !== after.trainerId` | `{memberUid: uid}` |
| `syncRecordAccessKeysOnConsent` | 생성·삭제이거나 `healthData.granted` 또는 `sharing.granted` 값이 바뀜 | 문서 ID가 `users/{id}`로 존재하면 `{memberUid}`, 아니면 `{pendingMemberId}` |
| `syncRecordAccessKeysOnPending` | `before.status === 'pending' && after.status !== 'pending'` 이고 `after.status !== 'promoted'` | `{pendingMemberId}` |

- `users/{uid}` 문서의 다른 필드(`lastLoginAt` 등) 변경은 1번 조건에서 걸러진다. 이 함수가 `users`에 쓰는 `accessKeySync` 필드도 `trainerId`를 바꾸지 않으므로 재귀 호출이 생기지 않는다.

#### 6.1.2 대상 컬렉션

| 컬렉션 | 조회 키 | 작성자 필드 | 인계 대상('확정') 상태 |
|---|---|---|---|
| `soap_notes` | `memberUid`, `pendingMemberId`, 레거시 `memberId`(memberUid 없는 v1 문서) | `authorUid`(없으면 `trainerId`로 채움, F-LINK-03.6) | `status == 'finalized'` |
| `postureAssessments` | `memberUid`, `pendingMemberId` | `authorUid` | `status == 'confirmed'` |
| `bodyCompositionRecords` | `memberUid`, `pendingMemberId` | `enteredBy` | `status == 'active'` |
| `circumferenceMeasurements` | `memberUid`, `pendingMemberId` | `authorUid` | `status == 'active'` |
| `bodyScans` | `memberUid` | `authorUid` | 항상(상태 필드 없음) |
| `memberSummaries` | `memberUid` | `sharedByUid`(ASM-06-07) | `status == 'shared'` |

`voided` 기록은 PRD F-LINK-05.4의 인계 목록(finalized, confirmed, active)에 없으므로 인계하지 않는다.

#### 6.1.3 목표 접근 키 계산(결정적 함수)

```js
// ctx는 같은 트랜잭션에서 읽은 현재 상태다.
// ctx.currentTrainerUid: memberUid면 users/{uid}.trainerId ?? null,
//                        pendingMemberId면 pendingMembers/{p}.status === 'pending' ? trainerId : null
// ctx.healthData: 'granted' | 'notGranted' | 'noStateDoc'
//   memberConsentStates/{memberKey} 문서가 없으면 'noStateDoc'(동의 모델 도입 전 레거시 회원, ASM-06-31)
// ctx.sharing: memberConsentStates/{memberKey}.sharing.granted === true (문서가 없으면 false)
function resolveAccessKey(collection, record, ctx) {
  if (ctx.healthData === 'notGranted') return null;       // ② 미동의·철회 → 전부 비표시 (F-PRIV-02.3)
  const current = ctx.currentTrainerUid;
  if (!current) return null;                              // 담당 없음
  const author = authorOf(collection, record);            // 표 6.1.2의 작성자 필드
  if (author === current) return current;                 // 본인이 쓴 기록은 draft 포함 접근 유지
  if (isHandoverState(collection, record) && ctx.sharing) return current;   // ④ 인계: 확정 기록만
  return null;                                            // draft·voided·④ 없음
}
```

- `noStateDoc`은 P0 배포 시점과 동의 모델 도입 전 레거시 회원을 위한 값이다. 이때는 동의 사유로 접근을 끊지 않고 담당·④ 규칙만 적용한다. 새 기록은 규칙 `hasConsent`가 상태 문서를 요구하므로(PRD §9.4) 이 경우가 생기지 않는다(ASM-06-31).
- 대기 회원 기록은 작성자와 생성 트레이너가 같으므로 pending 상태 동안 `trainerId`가 유지되고, `cancelled`·`expired`가 되면 null이 된다.
- `memberSummaries`는 회원 열람과 무관하다(회원 규칙은 `memberUid`만 봄, F-LINK-05.5).

#### 6.1.4 처리 절차(`syncRecordAccessKeysCore({db, memberKey, reason})`)

1. `accessKeySync = {status: 'running', attempts: FieldValue.increment(1), updatedAt}`를 대상 문서(`users/{uid}` 또는 `pendingMembers/{p}`)에 merge한다. 대상 문서가 없으면(탈퇴 중) 종료한다.
2. 표 6.1.2의 각 컬렉션·조회 키마다 문서 ID 순으로 **200건씩** 페이지를 읽는다(트랜잭션 밖).
3. 페이지마다 트랜잭션 하나를 연다.
   1. `ctx`를 읽는다(users 또는 pendingMembers, memberConsentStates).
   2. 페이지 문서를 `tx.getAll()`로 다시 읽는다.
   3. 문서마다 `next = resolveAccessKey(...)`를 계산하고, `trainerId !== next`이면 `{trainerId: next}`를 update한다. `soap_notes`에 `authorUid`가 없고 `trainerId`가 있으면 `authorUid = trainerId`를 함께 쓴다.
   4. `updatedAt`은 **바꾸지 않는다**. F-SOAP-03.6의 '원본 변경됨' 판정이 `updatedAt`을 보기 때문이다.
   - `ctx`를 같은 트랜잭션에서 읽으므로, 실행 도중 담당이 다시 바뀌면 트랜잭션이 경합으로 재시도되고 최신 담당 기준으로 계산된다. 오래된 실행이 새 결과를 덮어쓰지 않는다.
4. 모두 끝나면 `accessKeySync = {status: 'ok', attempts: 0, lastErrorCode: null, updatedAt}`.
5. 예외가 나면 `accessKeySync = {status: attempts >= 5 ? 'failed' : 'running', lastErrorCode, updatedAt}`로 기록하고, 트리거 실행이면 예외를 다시 던져 재시도하게 한다. 내부 호출이면 결과 `{status: 'deferred'}`를 돌려준다. `failed`는 로그 `dfet.access.syncFailed`(ERROR)와 `alertOverdueObligations`(§6.9)로 알린다.

반환값: `{status: 'ok' | 'deferred', updated: <정수>, scanned: <정수>}`.

#### 6.1.5 멱등성·오류·부수효과·감사

- 멱등: 같은 입력 상태면 두 번째 실행에서 update 0건이다(TC-06-SRA-08).
- 오류: 트리거는 오류 코드를 돌려주지 않는다. 내부 호출은 예외를 던지지 않고 `deferred`를 돌려준다.
- 부수효과: 표 6.1.2 컬렉션의 `trainerId`(와 레거시 `authorUid`), `users/{uid}.accessKeySync` 또는 `pendingMembers/{p}.accessKeySync`(ASM-06-08).
- 감사: 이 함수 자체는 감사 기록을 쓰지 않는다. 담당 변경 감사는 호출자가 쓴다([§5.1](#51-assignmembertotrainer--removememberfromtrainer)).
- 레이트 리밋: 없음.

#### 6.1.6 테스트 케이스(`functions/test/e2e/access-keys.e2e.test.js`, 단위는 `functions/test/unit/access-core.test.js` — DF-025 카드와 같은 파일)

| ID | 준비(합성) | 동작 | 기대 | 연결 |
|---|---|---|---|---|
| TC-06-SRA-01 | 회원 m(②있음, ④없음), A 담당, A가 쓴 finalized SOAP 2·draft 1 | `removeMemberFromTrainer(A,m)` | 3건 모두 `trainerId=null`, A의 get·list 거부 | AC-LINK-03.1, R-06 |
| TC-06-SRA-02 | 위 상태에서 B 배정(④없음) | assign | B가 보이는 기록 0건 | AC-LINK-05.4 |
| TC-06-SRA-03 | 이어서 ④ grant | `recordConsent` | finalized 2건만 `trainerId=B`, draft는 null | AC-LINK-05.4 |
| TC-06-SRA-04 | A가 쓴 confirmed 체형·active 신체조성·voided 둘레, ④있음 | A→B 재배정 | confirmed·active → B, voided → null | F-LINK-05.4 |
| TC-06-SRA-05 | ② 철회 | `recordConsent(withdraw healthData)` | 6개 컬렉션 전부 null | F-PRIV-02.3 |
| TC-06-SRA-06 | 레거시 soap(`memberId=m`, `memberUid` 없음, `authorUid` 없음) | 재정렬 | `authorUid = trainerId`가 채워지고 규칙대로 `trainerId` 계산 | F-LINK-03.6 |
| TC-06-SRA-07 | 대기 회원 p, `status → cancelled` | pendingMembers update | p 키 기록 전부 null | F-LINK-01.5 |
| TC-06-SRA-08 | 재정렬 완료 상태 | 같은 core 재실행 | `updated == 0` | 멱등 |
| TC-06-SRA-09 | 기록 450건 | 재배정 | 3개 이상 청크로 전부 반영, 트랜잭션당 쓰기 ≤ 200 | §3.8 |
| TC-06-SRA-10 | 실행 중 담당을 다시 변경(동시 실행 주입) | 두 실행 완료 | 최종 `trainerId`가 마지막 담당 기준 | 경합 |
| TC-06-SRA-11 | `users` 문서에서 `lastLoginAt`만 변경 | update | 트리거 즉시 종료, 쓰기 0 | 6.1.1 |
| TC-06-SRA-12 | 쿼리 오류 주입(5회) | 트리거 재시도 | `accessKeySync.status = 'failed'`, 로그 `dfet.access.syncFailed` 1건 이상 | F-LINK-03.5 |
| TC-06-SRA-13 | 단위: `resolveAccessKey` 진리표(②(3값)×④×작성자×상태 24조합) | — | 표와 일치 | — |
| TC-06-SRA-14 | 동의 상태 문서가 없는 레거시 회원(`memberId`만 있는 v1 SOAP), 담당 유지 | 재정렬 | `trainerId` 유지(동의 사유로 null 아님) | ASM-06-31 |
| ASM-06-32 | recordConsent 멱등 키는 `clientCaptureId`, 문서 버전 ID는 `{consentType}--{version}`, markSummaryViewed는 DF-335 소유(R5) | §9.2 consentRecords·consentDocumentVersions·memberSummaries, M-06·M-07 | 교차 정합 결정(2026-09-24), V1-05 §4.11·§4.13·§4.10 |
| ASM-06-33 | 시드 경로·ID는 V1-10 §5.2~§5.4(R2) | §12.5 | 교차 정합 결정(2026-09-24), DF-107 |
| ASM-06-34 | 배포 명령은 `firebase deploy --project dfetmanage --only …`(R7) | — | 교차 정합 결정(2026-09-24), ADR-014 |

---

### 6.2 `recordConsent`

| 항목 | 내용 |
|---|---|
| 종류·리전 | callable, asia-northeast3, `memory: '512MiB'` |
| 파일 | `functions/src/consent/recordConsent.js` |
| 호출 주체 | 트레이너 앱 TR-14(대기·가입 회원 현장 동의, P1a), 회원 앱 MB-06(본인 동의·철회·재확인, P2) |
| 인증 | `signedIn` + 채널별 조건(6.2.3) |
| 단계·스토리 | P1a, DF-109(기록·파생), DF-110·DF-111(클라이언트), DF-112(철회 즉시 처리), DF-308(재확인, P2) |
| PRD | F-PRIV-01.1~01.5, F-PRIV-02.1~02.3, F-PRIV-03.1~03.8, AC-PRIV-02.1~02.4, AC-PRIV-03.1~03.3, R-20, R-28 |
| 플래그 | 없음(F-PRIV-*는 항상 적용, PRD §6.0.2) |

#### 6.2.1 요청 스키마

```json
{
  "type": "object", "additionalProperties": false,
  "required": ["clientCaptureId", "memberKey", "channel", "selections"],
  "properties": {
    "clientCaptureId": { "$ref": "common#/$defs/ClientCaptureId" },
    "memberKey": { "$ref": "common#/$defs/MemberKey" },
    "channel": { "$ref": "common#/$defs/ConsentChannel" },
    "selections": {
      "type": "array", "minItems": 1, "maxItems": 5,
      "items": {
        "type": "object", "additionalProperties": false,
        "required": ["consentType", "action", "documentVersion"],
        "properties": {
          "consentType": { "$ref": "common#/$defs/ConsentType" },
          "action": { "$ref": "common#/$defs/ConsentAction" },
          "documentVersion": { "$ref": "common#/$defs/DocId", "description": "consentDocumentVersions 문서 ID" }
        }
      }
    },
    "signaturePngBase64": { "type": "string", "maxLength": 1400000, "description": "PNG 원본 1MB 이하(S 경로 제한 §9.5)" },
    "capturedAt": { "$ref": "common#/$defs/IsoTime", "description": "오프라인 캡처 시각(ASM-06-09)" },
    "reconfirmOf": { "type": ["string", "null"], "maxLength": 200, "description": "재확인 대상 consentRecords ID. memberApp 채널만" }
  }
}
```

예시(대기 회원 현장 동의, 합성)

```json
{
  "clientCaptureId": "3f2b8c1e-5d7a-4b1e-9a51-0c8e2d7f1a90",
  "memberKey": { "pendingMemberId": "SYNTHpending00000001" },
  "channel": "trainerDeviceInPerson",
  "selections": [
    { "consentType": "required", "action": "grant", "documentVersion": "required--1.0" },
    { "consentType": "healthData", "action": "grant", "documentVersion": "healthData--1.0" },
    { "consentType": "bodyImaging", "action": "grant", "documentVersion": "bodyImaging--1.0" }
  ],
  "signaturePngBase64": "iVBORw0KGgoAAAANSUhEUgAA...",
  "capturedAt": "2026-11-16T01:12:30.000Z",
  "reconfirmOf": null
}
```

#### 6.2.2 응답 스키마

```json
{
  "type": "object", "required": ["ok", "replayed", "recordIds", "state"],
  "properties": {
    "ok": { "const": true },
    "replayed": { "type": "boolean" },
    "recordIds": { "type": "array", "items": { "type": "string" } },
    "state": { "$ref": "common#/$defs/ConsentState" },
    "signaturePath": { "type": ["string", "null"] }
  }
}
```

```json
{
  "ok": true, "replayed": false,
  "recordIds": ["SYNTHconsentRec00001", "SYNTHconsentRec00002", "SYNTHconsentRec00003"],
  "state": {
    "required":   { "granted": true, "documentVersion": "required--1.0",   "recordId": "SYNTHconsentRec00001", "updatedAt": "2026-11-16T01:12:41.000Z" },
    "healthData": { "granted": true, "documentVersion": "healthData--1.0", "recordId": "SYNTHconsentRec00002", "updatedAt": "2026-11-16T01:12:41.000Z" },
    "bodyImaging":{ "granted": true, "documentVersion": "bodyImaging--1.0","recordId": "SYNTHconsentRec00003","updatedAt": "2026-11-16T01:12:41.000Z" }
  },
  "signaturePath": "consentSignatures/SYNTHconsentRec00001.png"
}
```

`signaturePath`는 트레이너 앱 응답에만 들어간다. 경로는 로컬 캐시 대조용이며 트레이너는 이 파일을 읽을 수 없다(S 규칙 §9.5, 관리자 서버 경유만).

#### 6.2.3 검증

| # | 규칙 | 실패 |
|---|---|---|
| V1 | `selections[].consentType` 중복 없음 | invalid-argument / `consent.duplicateType` |
| V2 | `channel == 'trainerDeviceInPerson'`: `auth.token.trainer === true`. `memberUid`면 `isAssignedTrainer`, `pendingMemberId`면 `isPendingOwner` | permission-denied / `auth.notTrainer`, `member.notAssigned`, `member.pendingNotOwned` |
| V3 | `channel == 'trainerDeviceInPerson'`: `signaturePngBase64` 필수, 디코드 결과가 PNG 시그니처(`89 50 4E 47`)로 시작하고 1MB 이하 | invalid-argument / `consent.signatureInvalid` |
| V4 | `channel == 'memberApp'`: `memberKey.memberUid === auth.uid`, `memberNonStaff`. 서명은 받지 않는다(있으면 거부) | permission-denied / `auth.staffAccountNotAllowed`, invalid-argument / `consent.signatureNotAllowed` |
| V5 | `grant`: `consentDocumentVersions/{documentVersion}`가 있고 `status == 'published'`이며 `consentType`이 같다 | failed-precondition / `consent.documentNotPublished` |
| V6 | `withdraw`: 문서가 있고 `consentType`이 같다(retired 허용) | failed-precondition / `consent.documentMismatch` |
| V7 | `required` + `withdraw`는 받지 않는다. 가입 회원은 탈퇴(§6.7), 대기 회원은 등록 취소(TR-14 → `pendingMembers.status = cancelled`)로 처리한다 | failed-precondition / `consent.requiredWithdrawNotSupported` |
| V8 | `required` 외 유형을 `grant`하려면 결과 상태에서 `required.granted == true`여야 한다(같은 요청의 grant 포함) | failed-precondition / `consent.requiredFirst` |
| V9 | `reconfirmOf`: `channel == 'memberApp'`, 대상 레코드가 호출자 것(`subjectUid == uid`)이고 `channel == 'trainerDeviceInPerson'`이며, selections가 그 레코드와 같은 `consentType`·`action`·`documentVersion` 1건 | invalid-argument / `consent.reconfirmMismatch` |
| V10 | `capturedAt`: `now − 7일` 이상, `now + 5분` 이하 | invalid-argument / `consent.capturedAtOutOfRange` |
| V11 | 대기 회원은 `status == 'pending'`, 가입 회원은 `users/{uid}` 존재 | not-found / `member.notFound` |

#### 6.2.4 처리 절차

1. **멱등 사전 확인(트랜잭션 밖).** `consentRecords where clientCaptureId == X limit 1`이 있으면 업로드 없이 [§6.2.5](#625-멱등성)로 간다(재시도 때 서명 파일이 새로 생기지 않게).
2. **레코드 ID 선발급과 서명 업로드(트랜잭션 전).** selection 수만큼 `db.collection('consentRecords').doc().id`로 자동 ID를 미리 만든다. 서명이 있으면 `consentSignatures/{첫 recordId}.png`에 `contentType: image/png`로 저장한다(V1-05 §4.11·ASM-05-13, ADR-007, ADR-011). 같은 캡처의 레코드는 모두 이 경로를 `signaturePath`로 가리킨다.
3. **트랜잭션**(읽기 먼저)
   1. 읽기: 멱등 재확인용 `consentRecords where clientCaptureId == X limit 1`(트랜잭션 안 쿼리. 동시 호출 경합은 Firestore 직렬화로 한쪽만 커밋된다), `trainers/{auth.uid}` 또는 `pendingMembers/{p}`, `users/{uid}`, `memberConsentStates/{memberKey}`, `consentDocumentVersions/{documentVersion}`(최대 5).
   2. 결과가 있으면 → 트랜잭션을 쓰기 없이 끝내고, 2단계에서 올린 서명 파일을 지운 뒤 멱등 처리([§6.2.5](#625-멱등성))로 간다.
   3. V2·V5~V9·V11 검증.
   4. 쓰기: selection마다 선발급한 ID로 `consentRecords/{recordId}`를 create한다.

      ```json
      {
        "subjectUid": "synthMember0001 | null",
        "pendingMemberId": "SYNTHpending00000001 | null",
        "consentType": "healthData",
        "action": "grant",
        "documentVersion": "healthData--1.0",
        "channel": "trainerDeviceInPerson",
        "recordedAt": "<serverTimestamp>",
        "recordedBy": "synthTrainerA",
        "signaturePath": "consentSignatures/SYNTHconsentRec00001.png",
        "capturedAt": "2026-11-16T01:12:30.000Z",
        "reconfirmedAt": null,
        "reconfirmOf": null,
        "clientCaptureId": "3f2b8c1e-5d7a-4b1e-9a51-0c8e2d7f1a90",
        "schemaVersion": 1
      }
      ```

      - 회원 앱 채널: `recordedBy = auth.uid`, `signaturePath = null`. 재확인이면 `reconfirmedAt = serverTimestamp()`이고 원 레코드는 바꾸지 않는다(PRD §9.2).
   5. 쓰기: `memberConsentStates/{memberKey}`를 결정적으로 갱신한다. 유형별로 기존 항목과 새 레코드 중 `recordedAt`이 최신인 것을 쓰고, 같은 시각이면 철회가 이긴다(F-PRIV-02.2). 새 레코드는 모두 같은 서버 시각이므로 이번 요청 값이 이긴다. 재확인은 `recordId`만 새 레코드로 바꾼다.
      - `healthData`·`bodyImaging` withdraw: `pendingPurge.<type> = serverTimestamp()`(ASM-06-10).
      - 같은 유형을 다시 grant하면 `pendingPurge.<type>`을 지운다(파기 전 재동의).
   6. 쓰기: 레코드마다 감사 `consentChanged`(`targetCollection: 'consentRecords'`, `metadata: {consentType, action, channel, reconfirm}`).
   7. 트랜잭션이 실패(검증 실패 포함)하면 2단계의 서명 파일을 지운다. 이 삭제마저 실패한 고아 파일은 `purgeExpiredRecords`가 1일 뒤 지운다(§6.8 D).
4. **커밋 후 즉시 처리**(F-PRIV-02.3 '즉시' 열)
   - `healthData` withdraw: 해당 회원의 `memberSummaries where memberUid == uid && status == 'shared'`를 `revokeSummaryCore(reason: 'consentWithdrawal')`로 해제하고(§6.14, P2부터 존재), `syncRecordAccessKeysCore(memberKey)`를 호출한다(결과 `trainerId = null`).
   - `bodyImaging` withdraw: 해당 회원의 shared 요약에서 `sharedPhotoPaths = []`로 바꾼다. 원 기록 파기는 `purgeExpiredRecords`(5영업일 안).
   - `sharing` grant 또는 withdraw: `syncRecordAccessKeysCore(memberKey)`.
   - `research` withdraw: 즉시 처리 없음(다음 가명 내보내기부터 제외, DF-326).
   - 4단계가 실패해도 동의 기록은 되돌리지 않는다. 트리거 `syncRecordAccessKeysOnConsent`가 재정렬을 다시 하고, 요약 해제는 `purgeExpiredRecords`가 `pendingPurge.healthData`를 보고 다시 확인한다.
5. 응답: `recordIds`, 새 `state`, `signaturePath`.

분석 이벤트는 보내지 않는다(PRD §5.5 '동의 변경은 auditLogs에만').

#### 6.2.5 멱등성

- 멱등 키: `clientCaptureId`(V1-05 §4.11 필드, ASM-05-12). 레코드 ID는 자동 ID이고, 서명 경로는 `consentSignatures/{첫 recordId}.png` 하나를 같은 캡처의 레코드가 공유한다(V1-05 ASM-05-13, DF-109 ASM-P1a-03·04). 이 결정의 정본은 V1-05이며 이 문서는 따른다.
- 같은 `clientCaptureId`의 레코드가 있으면 그 캡처의 레코드 전체(`where clientCaptureId == X`)를 읽어 `memberKey`, `channel`, selections 집합을 요청과 비교한다. 같으면 현재 `state`와 **저장된** `recordIds`·`signaturePath`를 `replayed: true`로 돌려준다(두 응답의 `recordIds`가 같다, AC-DF-109.6). 다르면 `already-exists / idempotency.keyReused`.
- 트레이너 앱은 오프라인 캡처 때 `LocalConsentCapture.captureId`를 만들어 재시도 내내 `clientCaptureId`로 보낸다(F-PRIV-03.7). 회원 앱은 호출마다 UUID v4를 만들고 같은 호출의 재시도에 재사용한다.
- `consentRecords.clientCaptureId` 단일 필드 조회는 자동 단일 필드 인덱스로 충분하다(복합 인덱스 추가 없음).

#### 6.2.6 오류(함수 전용)

| messageKey | code | 조건 | 클라이언트 처리 |
|---|---|---|---|
| `consent.duplicateType` | invalid-argument | V1 | 개발 결함 |
| `consent.signatureInvalid` | invalid-argument | V3 | 서명 다시 받기 |
| `consent.signatureNotAllowed` | invalid-argument | V4 | 개발 결함 |
| `consent.documentNotPublished` | failed-precondition | V5 | '동의 문서가 갱신됐어요' → 최신 문서 다시 표시 |
| `consent.documentMismatch` | failed-precondition | V6 | 개발 결함 |
| `consent.requiredWithdrawNotSupported` | failed-precondition | V7 | 탈퇴·등록 취소 안내 |
| `consent.requiredFirst` | failed-precondition | V8 | ① 먼저 |
| `consent.reconfirmMismatch` | invalid-argument | V9 | 개발 결함 |
| `consent.capturedAtOutOfRange` | invalid-argument | V10 | 7일 지난 로컬 캡처는 파기(AS-32) |

#### 6.2.7 부수효과·감사·레이트 리밋

- 쓰기: `consentRecords`(append), `memberConsentStates`, Storage `consentSignatures/`, `auditLogs`. 커밋 후: `memberSummaries`(해제·사진 경로 비움), 원 기록 `trainerId`(재정렬 경유).
- 감사: `consentChanged` 레코드당 1건.
- 레이트 리밋: 없음.

#### 6.2.8 테스트 케이스(`functions/test/e2e/recordConsent.e2e.test.js`, 단위 `functions/test/unit/consent/deriveConsentState.test.js`·`validateRequest.test.js` — DF-109 카드와 같은 파일)

| ID | 상황 | 기대 | 연결 |
|---|---|---|---|
| TC-06-RC-01 | 대기 회원 생성자 A, ①②③ grant + 서명 | 레코드 3건 `channel=trainerDeviceInPerson`, 3건 모두 같은 `signaturePath='consentSignatures/{첫 recordId}.png'`, 상태 3유형 granted | AC-PRIV-03.1, AC-DF-109.2 |
| TC-06-RC-02 | 가입 회원 담당 A, ② grant | 상태 `healthData.granted`, 이후 R-01 조건으로 soap create 허용 | AC-PRIV-03.2, F-PRIV-03.6 |
| TC-06-RC-03 | 비담당 B가 가입 회원에 대해 호출 | permission-denied / `member.notAssigned` | R-28 |
| TC-06-RC-04 | draft 상태 문서 버전으로 grant | failed-precondition / `consent.documentNotPublished` | F-PRIV-01.2 |
| TC-06-RC-05 | 같은 `clientCaptureId`로 2회 호출 | 두 번째 `replayed: true`, 레코드 수 불변, 두 응답 `recordIds` 동일, Storage 서명 파일 1개 | AC-DF-109.6, TC-109-08 |
| TC-06-RC-06 | 같은 `clientCaptureId`, 다른 selections | already-exists / `idempotency.keyReused`, 새 서명 파일 없음 | 멱등 |
| TC-06-RC-07 | ② withdraw(요약 1건 shared, P2 환경) | 요약 revoked·내용 비움, 6개 컬렉션 `trainerId=null`, `pendingPurge.healthData` 있음 | AC-PRIV-02.2(즉시 부분) |
| TC-06-RC-08 | ③ withdraw | shared 요약 `sharedPhotoPaths=[]`, `pendingPurge.bodyImaging` 있음 | F-PRIV-02.3 |
| TC-06-RC-09 | ① 없이 ② grant | failed-precondition / `consent.requiredFirst` | V8 |
| TC-06-RC-10 | `required` withdraw | failed-precondition / `consent.requiredWithdrawNotSupported` | V7 |
| TC-06-RC-11 | 회원 앱 채널, 다른 uid의 memberKey | permission-denied | V4 |
| TC-06-RC-12 | 서명 없이 현장 채널 | invalid-argument / `consent.signatureInvalid` | V3 |
| TC-06-RC-13 | 단위: 같은 `recordedAt`의 grant·withdraw 파생 | withdraw 우선 | F-PRIV-02.2 |
| TC-06-RC-14 | 클라이언트 SDK로 `consentRecords` 직접 create | 규칙 거부 | AC-PRIV-02.1, R-20 |
| TC-06-RC-15 | 감사 레코드 검사 | `metadata` 키가 화이트리스트뿐, 수치·이름 없음 | §9.7 |
| TC-06-RC-16 | 회원 앱 재확인(`reconfirmOf`) | 새 레코드 `reconfirmedAt` 있음, 원 레코드 불변, 감사 `reconfirm:true` | F-PRIV-03.8 |

---

### 6.3 `auditSoapFinalized`

| 항목 | 내용 |
|---|---|
| 종류·리전 | `onDocumentUpdated('soap_notes/{noteId}')`, asia-northeast3, `retry: true` |
| 단계·스토리 | P1a, DF-123 |
| PRD | F-SOAP-04.7, F-PRIV-05.1, §9.7 auditLogs |

- 조건: `before.status === 'draft' && after.status === 'finalized' && after.schemaVersion === 2`. 아니면 종료.
- 처리: `auditLogs/soapFinalized_{noteId}`를 `create()`한다. 이미 있으면(재전달) 무시한다.

```json
{
  "action": "soapFinalized", "actorUid": "<after.trainerId>", "actorRole": "trainer",
  "targetCollection": "soap_notes", "targetId": "<noteId>",
  "memberUid": "<after.memberUid 또는 null>", "at": "<serverTimestamp>",
  "metadata": { "pendingMember": false }, "schemaVersion": 1
}
```

- 본문·수치·quickNote는 넣지 않는다.

| ID | 상황 | 기대 |
|---|---|---|
| TC-06-ASF-01 | draft → finalized | 감사 1건, `targetId == noteId` |
| TC-06-ASF-02 | 같은 이벤트 재전달 | 감사 여전히 1건 |
| TC-06-ASF-03 | draft 편집(상태 불변) | 감사 0건 |
| TC-06-ASF-04 | 대기 회원 노트 확정 | `memberUid: null`, `metadata.pendingMember: true` |

---

### 6.4 `logRecordAccess`

| 항목 | 내용 |
|---|---|
| 종류·리전 | callable, asia-northeast3 |
| 호출 주체·시점 | 트레이너 앱 TR-03 화면이 나타날 때 1회(`onAppear`, 같은 회원 재진입마다) |
| 인증 | `trainer` + (`isAssignedTrainer` 또는 `isPendingOwner`) |
| 단계·스토리 | P1a, DF-115 |
| PRD | F-PRIV-05.1, F-PRIV-05.3, AC-PRIV-05.2 |

요청·응답

```json
{ "type": "object", "additionalProperties": false, "required": ["memberKey", "surface"],
  "properties": { "memberKey": { "$ref": "common#/$defs/MemberKey" }, "surface": { "const": "TR-03" } } }
```

```json
{ "ok": true }
```

- 처리: 담당 확인 → `auditLogs`에 `healthRecordRead`(`targetCollection: 'users' | 'pendingMembers'`, `targetId: memberKey 값`, `metadata: {surface: 'TR-03', pendingMember}`).
- 멱등 키 없음(진입마다 1건이 요구사항).
- 오류: `member.notAssigned`, `member.pendingNotOwned`. 클라이언트는 실패해도 화면을 막지 않고 로그만 남긴다(DF-115 수용 기준).
- 1차 증빙은 Cloud Audit Logs Data Access 로그다(DF-932, 소유자 설정).

| ID | 상황 | 기대 |
|---|---|---|
| TC-06-LRA-01 | 담당 트레이너 호출 | 감사 1건, 수치·이름 필드 없음 |
| TC-06-LRA-02 | 비담당 트레이너 | permission-denied, 감사 0건 |
| TC-06-LRA-03 | 대기 회원 생성자 | 감사 1건, `memberUid: null` |

---

### 6.5 `submitRightsRequest`

| 항목 | 내용 |
|---|---|
| 종류·리전 | callable, asia-northeast3 |
| 호출 주체 | 트레이너 앱(담당 회원 대리 접수, P1a), admin_web 서버(관리자 접수, P1a), 회원 앱 MB-06(P2) |
| 인증 | 채널별: `trainer`+담당, `admin`, `memberNonStaff`+본인 |
| 단계·스토리 | P1a, DF-135(P2 회원 경로는 DF-307) |
| PRD | F-PRIV-07.1, F-PRIV-07.4, §9.2 rightsRequests |

요청·응답

```json
{
  "type": "object", "additionalProperties": false,
  "required": ["requestId", "memberUid", "type", "channel"],
  "properties": {
    "requestId": { "$ref": "common#/$defs/RequestId" },
    "memberUid": { "$ref": "common#/$defs/DocId" },
    "type": { "$ref": "common#/$defs/RightsRequestType" },
    "channel": { "enum": ["memberApp", "trainer", "admin"] }
  }
}
```

```json
{ "ok": true, "replayed": false, "requestId": "0b6f…", "dueAt": "2026-11-26T14:59:59.999Z" }
```

- 대기 회원(uid 없음)의 권리 요청은 이 함수 대상이 아니다. 삭제는 등록 취소, 열람은 관리자 수동 처리로 한다(ASM-06-12).
- 검증: 채널과 인증 수준 일치(`channel=trainer`인데 admin claim이면 거부). `users/{memberUid}` 존재.
- 처리: `rightsRequests/{requestId}` create.

```json
{
  "memberUid": "synthMember0001", "type": "access", "channel": "trainer",
  "status": "received", "receivedAt": "<serverTimestamp>",
  "dueAt": "<receivedAt의 KST 날짜 + 10일, 23:59:59.999 KST>",
  "completedAt": null, "handledBy": null, "exportPath": null,
  "requestedBy": "synthTrainerA", "schemaVersion": 1
}
```

  - `dueAt`은 달력일 10일이다. 기한은 법률 검토 대상이다(PRD §9.2, G-04). `requestedBy`는 PRD 필드 목록에 없는 추가 필드다(ASM-06-13).
  - 자유 텍스트 사유 필드는 받지 않는다.
- 감사: `rightsRequestHandled`(`metadata: {type, stage: 'received', channel}`).
- 멱등: `requestId` = 문서 ID. 같은 내용이면 `replayed`.
- 상태 갱신(inProgress, completed, rejected)은 이 함수가 아니다. 열람은 `exportMemberData`(§6.6), 삭제는 `deleteUserData({uid, rightsRequestId})`(§6.7), 정정은 트레이너 addendum 뒤 관리자가 완료 처리(P1a 소유자 스크립트, P2 AD-06 라우트 §7.3), 처리정지는 ②③ 철회(§6.2) 뒤 관리자가 완료 처리한다(F-PRIV-07.3).

| ID | 상황 | 기대 |
|---|---|---|
| TC-06-SRR-01 | 담당 트레이너가 access 접수 | 문서 1건 `status=received`, `dueAt = +10일`, 감사 1건 |
| TC-06-SRR-02 | 비담당 트레이너 | permission-denied |
| TC-06-SRR-03 | 회원 본인(memberApp) | 성공. 다른 uid면 permission-denied |
| TC-06-SRR-04 | 같은 `requestId` 재호출 | `replayed: true`, 문서 1건 |
| TC-06-SRR-05 | 본문에 `reason` 키 | invalid-argument(알 수 없는 키) |

---

### 6.6 `exportMemberData`

| 항목 | 내용 |
|---|---|
| 종류·리전 | callable, asia-northeast3, `memory: '1GiB'`, `timeoutSeconds: 540` |
| 호출 주체 | admin_web 서버(관리자 세션) 또는 관리자 콘솔 스크립트 |
| 인증 | `admin` |
| 단계·스토리 | P1a, DF-135 |
| PRD | F-PRIV-07.2, AC-PRIV-07.1, §9.5 `rightsExports`, §9.7 삭제 범위표 |

요청·응답

```json
{ "type": "object", "additionalProperties": false, "required": ["requestId"],
  "properties": { "requestId": { "$ref": "common#/$defs/DocId", "description": "rightsRequests 문서 ID(type=access)" } } }
```

```json
{ "ok": true, "replayed": false,
  "exportPath": "rightsExports/0b6f….zip",
  "downloadUrl": "https://storage.googleapis.com/…(서명 URL)",
  "expiresAt": "2026-11-18T03:00:00.000Z",
  "counts": { "soap_notes": 12, "postureAssessments": 3, "files": 9 } }
```

- 검증: 요청 문서가 있고 `type == 'access'`, `status in ['received', 'inProgress']`. 이미 `completed`이고 파일이 있으면 새 서명 URL만 발급해 `replayed: true`.
- 처리
  1. `status = 'inProgress'`, `handledBy = auth.uid`.
  2. §9.7 범위표의 모든 대상을 `memberUid`(레거시 `memberId`, 승격 전 `pendingMemberId`·`promotedUid` 포함)로 모은다: `users/{uid}`와 하위 컬렉션, 원 기록 5종과 addenda, `memberSummaries`, `consentRecords`, `memberConsentStates`, `rightsRequests`, `memberAliases`, 임상 소비자본·전문가본·스냅샷, `requests`, 본인 `posts`, `auditLogs where memberUid == uid`(action·시각만).
  3. ZIP(무압축, `src/shared/zipStore.js`)을 Storage 쓰기 스트림으로 바로 만든다. 구조:

     ```
     manifest.json                 # {schemaVersion:1, requestId, generatedAt, memberUid, counts{}, excluded[]}
     firestore/<collection>/<docId>.json
     firestore/soap_notes/<noteId>/addenda/<addendumId>.json
     files/<원래 Storage 경로>       # 사진, 필기, 결과지, 서명, 스캔 썸네일
     ```

     `excluded[]`에는 기기 로컬 LiDAR 원본처럼 서버에 없는 항목을 적는다.
  4. `rightsExports/{requestId}.zip`(`application/zip`) 업로드 후 서명 URL(만료 24시간, ASM-06-14)을 발급한다.
  5. `status = 'completed'`, `completedAt`, `exportPath`.
  6. 감사: `rightsRequestHandled(stage: 'completed')`, `healthRecordRead(surface: 'adminExport')`.
- 오류: `rights.notFound`(not-found), `rights.typeMismatch`(failed-precondition), `rights.alreadyRejected`(failed-precondition).
- 서명 URL 발급에는 런타임 서비스 계정의 `iam.serviceAccounts.signBlob` 권한이 필요하다(소유자 설정, ASM-06-15).

| ID | 상황 | 기대 | 연결 |
|---|---|---|---|
| TC-06-EXP-01 | 합성 회원(모든 컬렉션 1건 이상) | ZIP의 `manifest.counts`가 각 컬렉션 실제 건수와 같음 | AC-PRIV-07.1 |
| TC-06-EXP-02 | 다른 회원 기록 섞인 DB | 다른 회원 문서 0건 | F-PRIV-07.2 |
| TC-06-EXP-03 | trainer claim 호출 | permission-denied | §3.3 |
| TC-06-EXP-04 | 완료된 요청 재호출 | 파일 1개 유지, 새 URL, `replayed: true` | §3.7 |
| TC-06-EXP-05 | 감사 | `rightsRequestHandled`·`healthRecordRead` 각 1건 | F-PRIV-07.4 |

---

### 6.7 `deleteMemberCascade`와 `deleteOwnAccount` / `deleteUserData`

| 항목 | 내용 |
|---|---|
| 종류 | 내부 모듈 `deleteMemberCascade`, `purgeMemberRecords` + 기존 callable 2개 |
| 기존 callable | `deleteOwnAccount`(asia-northeast3, 로그인 본인, 응답 `{success: true}` 유지), `deleteUserData`(기본 리전, admin, 응답 `{success, message}` 유지 + `counts`) |
| 옵션 | 두 callable 모두 `memory: '1GiB'`, `timeoutSeconds: 540`(기본 리전 함수는 옵션만 추가, 리전 유지) |
| 단계·스토리 | P1a, DF-132 |
| PRD | F-PRIV-04.1~04.4, AC-PRIV-04.1, §9.7 삭제 연쇄 범위표 |

#### 6.7.1 요청

- `deleteOwnAccount`: 기존처럼 인자 없음(`{}`).
- `deleteUserData`: `{uid: DocId, rightsRequestId?: DocId}`. `rightsRequestId`가 있으면 그 요청(`type == 'erasure'`)을 완료 처리한다.
- 트레이너·관리자 claim 계정이 `deleteOwnAccount`를 호출하면 `failed-precondition / account.staffSelfDeleteNotSupported`로 거부한다. 담당 기록의 접근 키가 끊기기 때문이다. 직원 계정 정리는 관리자 절차로 한다(ASM-06-16).

#### 6.7.2 `purgeMemberRecords({db, bucket, memberKey, scope})`

`scope`는 `all | healthData | bodyImaging`이다. 탈퇴, ② 철회, ③ 철회, 대기 회원 파기, 보유기간 파기가 이 루틴 하나를 공유한다.

| scope | 대상 | 처리 |
|---|---|---|
| `all`, `healthData` | `soap_notes`(+addenda), `postureAssessments`, `bodyCompositionRecords`, `circumferenceMeasurements`, `bodyScans`, `memberSummaries` | 부모마다 Storage prefix(`soapInk/{id}/`, `postureAssessments/{id}/`, `bodyCompositionRecords/{id}/`, `bodyScans/{id}/`)를 먼저 지운 뒤 `recursiveDelete` |
| `bodyImaging` | `postureAssessments`, `bodyScans`, `memberSummaries` | 체형: prefix 삭제, `views[].photoPath = null`, `views[].thumbPath = null`, `views[].landmarks = []`, `imagingPurgedAt = serverTimestamp()`(ASM-06-17). 스캔: `thumb.jpg` 삭제, `thumbnailPath = null`, `sections[].contour2dMm = null`, `meshSHA256 = null`. 요약: `sharedPhotoPaths = []`. 각도 지표·`perimeterMm`은 유지 |

- 조회 키: `memberUid`, 레거시 `soap_notes.memberId`, `pendingMemberId`(승격 전 기록과 대기 회원).
- 각 단계는 400건 청크, 청크마다 멱등이다. 반환값은 대상별 건수 맵이다.

#### 6.7.3 `deleteMemberCascade({db, bucket, auth, uid, trigger, rightsRequestId})` 처리 순서

1. 추적 요청: `rightsRequestId`가 없으면 `rightsRequests/erasure-{uid}-{yyyymmdd(KST)}`를 만들거나 재사용한다(`type: 'erasure'`, `channel: trigger === 'memberSelf' ? 'memberApp' : 'admin'`, `status: 'inProgress'`). 기한 초과 경보(§6.9)의 근거가 된다.
2. 연결된 대기 회원 ID 수집: `pendingMembers where promotedUid == uid`.
3. `purgeMemberRecords(scope: 'all')`를 `{memberUid: uid}`와 각 `{pendingMemberId}`에 대해 실행한다.
4. 임상: `gutReportExperts`·`bloodReportExperts`의 `rawPath` 파일을 먼저 지우고, 전문가본·소비자본·`healthSnapshots`(`userId == uid`)를 지운다.
5. `memberAliases`(`memberUid == uid`와 레거시 `userId == uid`), `inviteCodes`(수집한 `pendingMemberId`), `pendingMembers`(수집분), `memberConsentStates/{uid}`와 `/{pendingMemberId}`.
6. 기존 대상: `requests`(`userId`), `posts`(`authorId`), Storage `requests/{uid}/`, `posts/*_{uid}.(jpg|jpeg|png|webp)`(확장자 4종, F-PRIV-04.3 — 현행 `.jpg`만 dfet:functions/index.js:429).
7. `trainers where memberIds array-contains uid` → `arrayRemove`.
8. `users/{uid}` `recursiveDelete`.
9. Auth 계정 삭제. `auth/user-not-found`는 성공으로 본다(재실행 대비).
10. 보존 대상은 지우지 않는다: `consentRecords`, `consentSignatures/*`, `rightsRequests`, `auditLogs`(Q-07, F-PRIV-05.4).
11. 감사 `dataDeleted`(`actorRole: member|admin`, `memberUid: uid`, `metadata: {trigger, scope: 'all', counts}`).
12. 추적 요청 `status = 'completed'`, `completedAt`. 실패하면 `inProgress`로 두고 로그 `dfet.delete.failed`(ERROR, `stage`만)를 남긴 뒤 `internal / account.deleteFailed`를 던진다. 같은 호출을 다시 하면 남은 단계만 처리된다.

- Auth 삭제를 마지막에 두므로 1~8 단계가 실패해도 회원이 다시 시도할 수 있다. Auth 삭제 뒤 실패는 관리자가 `deleteUserData({uid, rightsRequestId})`로 마무리한다.
- `trainerWorkspaces` 안의 로컬 UUID 회원 데이터는 이 루틴으로 찾을 수 없다. MIG-08(DF-138, DF-330)로 해소한다.

#### 6.7.4 오류

| messageKey | code | 조건 |
|---|---|---|
| `account.staffSelfDeleteNotSupported` | failed-precondition | 직원 claim 계정의 `deleteOwnAccount` |
| `account.deleteFailed` | internal | 단계 실패(재시도 가능) |
| `rights.typeMismatch` | failed-precondition | `rightsRequestId`의 type이 erasure가 아님 |

#### 6.7.5 테스트 케이스(`functions/test/e2e/deleteMemberCascade.e2e.test.js`, DF-132 카드와 같은 파일)

| ID | 상황 | 기대 | 연결 |
|---|---|---|---|
| TC-06-DEL-01 | §9.7 범위표 모든 대상에 1건 이상 있는 합성 회원, `deleteOwnAccount` | 범위표 삭제 대상 0건, `consentRecords`·`auditLogs`·`rightsRequests` 남음, `dataDeleted` 1건 | AC-PRIV-04.1 |
| TC-06-DEL-02 | 같은 회원 `deleteUserData`(관리자) | 01과 같은 결과(두 경로 동일) | F-PRIV-04.1 |
| TC-06-DEL-03 | posts 파일 `.png`, `.webp` | 모두 삭제 | F-PRIV-04.3 |
| TC-06-DEL-04 | 레거시 soap(`memberId`만) | 삭제 | F-PRIV-04.3 |
| TC-06-DEL-05 | 5단계 뒤 예외 주입 후 재호출 | 남은 대상만 처리, 최종 0건 | 멱등 |
| TC-06-DEL-06 | `purgeMemberRecords(scope: 'bodyImaging')` | 사진 0건, `landmarks` 빈 배열, 각도 지표 유지, 스캔 `contour2dMm`·`meshSHA256` null, `perimeterMm` 유지 | AC-PRIV-02.3, AC-PRIV-02.4 |
| TC-06-DEL-07 | 트레이너 계정 `deleteOwnAccount` | failed-precondition | ASM-06-16 |
| TC-06-DEL-08 | 승격된 대기 회원 이력 | `pendingMembers`, 대기 키 기록, `memberConsentStates/{p}` 0건 | §9.7 |

---

### 6.8 `purgeExpiredRecords`

| 항목 | 내용 |
|---|---|
| 종류·리전 | `onSchedule({schedule: '0 3 * * *', timeZone: 'Asia/Seoul'})`, asia-northeast3, `memory: '1GiB'`, `timeoutSeconds: 540` |
| 단계·스토리 | P1a, DF-133 |
| PRD | §9.7 보존 정책, F-PRIV-02.3, F-LINK-01.5, AC-LINK-01.4, AC-LINK-01.5, AC-PRIV-02.2, AC-PRIV-02.3, Q-24 |
| 매개변수 | `defineInt('COACHING_RECORD_RETENTION_MONTHS', {default: 0})`, `defineInt('PENDING_MEMBER_RETENTION_DAYS', {default: 0})`. 0이면 해당 작업 비활성(Q-24·G-04 결정 전 기본, ASM-06-18) |

작업 순서(한 실행 안에서 A→E, 실행 시간 480초를 넘기면 남은 일은 다음 날로 넘기고 로그에 남긴다)

| 작업 | 대상 조회 | 처리 | 감사 `dataDeleted.trigger` |
|---|---|---|---|
| A. 동의 철회 파기 | `memberConsentStates where pendingPurge.healthData != null`, `…bodyImaging != null` | 현재도 `granted != true`면 `purgeMemberRecords(scope)` 후 `pendingPurge.<type>` 삭제. 재동의로 granted면 삭제만 | `consentWithdrawal` |
| B1. 대기 회원 만료 | `pendingMembers where status == 'pending' && createdAt < now − PENDING_MEMBER_RETENTION_DAYS` | `status = 'expired'`(→ 6.1 트리거가 접근 키 해제) | — |
| B2. 대기 회원 파기 | `pendingMembers where status in ['cancelled', 'expired']` | `purgeMemberRecords({pendingMemberId}, 'all')`, `inviteCodes`, `memberConsentStates/{p}`, `pendingMembers/{p}` 삭제(`consentRecords`는 Q-07로 보존) | `pendingCancelled` |
| C. 보유기간 경과 | 회원·대기 회원마다 최근 측정 시각(`sessionDate`, `capturedAt`, `measuredAt`, `takenAt`의 최댓값)과 담당 종료 시각(`users.trainerUnassignedAt` 또는 `assignmentUpdatedAt`) 중 늦은 값 | 그 값이 `now − N개월`보다 이르면 `purgeMemberRecords(scope: 'all')`(계정은 유지) | `retention` |
| D. 고아 파일 | `consentSignatures/{recordId}.png` 중 `consentRecords/{recordId}` 문서가 없고 1일 지난 것(recordConsent 실패 후 삭제 누락분), `rightsExports/*` 중 서명 URL 만료 후 1일 지난 것 | 삭제 | — |
| E. 요약 해제 재확인 | A의 `healthData` 대상 회원의 `memberSummaries where status == 'shared'` | `revokeSummaryCore(reason: 'consentWithdrawal')` | — |

- 5영업일 기한은 `pendingPurge.<type>` 시각에 `addBusinessDaysKst(5)`를 더해 계산한다. 이 함수는 매일 돌며 즉시 처리하므로 보통 1영업일 안에 끝난다. 기한 초과 감시는 §6.9가 한다.
- 로그: 실행마다 `dfet.purge.run {A, B1, B2, C, D, E, durationMs, truncated}`(건수만).

| ID | 상황 | 기대 | 연결 |
|---|---|---|---|
| TC-06-PUR-01 | ② 철회 회원 | 실행 후 원 기록·Storage 0건, `pendingPurge.healthData` 없음 | AC-PRIV-02.2 |
| TC-06-PUR-02 | ③ 철회 회원 | 사진 0건, 각도 유지 | AC-PRIV-02.3 |
| TC-06-PUR-03 | 철회 후 파기 전에 재동의 | 파기 없음 | A 작업 |
| TC-06-PUR-04 | 대기 회원 cancelled | 연결 기록·Storage·동의 상태 0건, `consentRecords` 유지 | AC-LINK-01.4 |
| TC-06-PUR-05 | `PENDING_MEMBER_RETENTION_DAYS=30`, 31일 된 pending | expired → 파기 | AC-LINK-01.5 |
| TC-06-PUR-06 | 매개변수 0 | B1·C 작업 0건 | ASM-06-18 |
| TC-06-PUR-07 | 두 번 연속 실행 | 두 번째 처리 0건 | 멱등 |
| TC-06-PUR-08 | 로그 검사 | uid·경로 문자열 없음 | NFR-10 |

---

### 6.9 `alertOverdueObligations`

| 항목 | 내용 |
|---|---|
| 종류·리전 | `onSchedule({schedule: '0 9 * * *', timeZone: 'Asia/Seoul'})`, asia-northeast3 |
| 단계·스토리 | P1a, DF-134(알림 정책 설정은 소유자 DF-933) |
| PRD | F-PRIV-04.4, F-PRIV-07.4, F-LINK-03.5, AS-DEV-13 |

| 검사 | 조건 | 로그 `event` / `kind` |
|---|---|---|
| 권리 요청 기한 초과 | `rightsRequests where status in ['received','inProgress'] && dueAt < now` | `dfet.obligation.overdue` / `rightsRequest` |
| 삭제 실패 | `rightsRequests where type == 'erasure' && status == 'inProgress' && receivedAt < now − 5영업일` | `dfet.obligation.overdue` / `erasure` |
| 파기 지연 | `memberConsentStates`의 `pendingPurge.*`가 5영업일 초과 | `dfet.obligation.overdue` / `consentPurge` |
| 재정렬 실패 | `users`·`pendingMembers where accessKeySync.status == 'failed'`, 또는 `running`이고 `updatedAt < now − 1시간` | `dfet.obligation.overdue` / `accessKeySync` |

- 로그는 `severity: 'ERROR'`, `jsonPayload = {event, kind, count}`만 남긴다. 식별자는 넣지 않는다. 0건이면 INFO 한 줄.
- 알림 정책 필터 예: `jsonPayload.event="dfet.obligation.overdue" AND severity>=ERROR`(DF-933).
- 쓰기 없음.

| ID | 상황 | 기대 |
|---|---|---|
| TC-06-AOO-01 | 기한 지난 received 요청 2건 | ERROR 로그 `{kind:'rightsRequest', count:2}` |
| TC-06-AOO-02 | 해당 없음 | INFO 1줄, ERROR 0 |
| TC-06-AOO-03 | 로그 페이로드 검사 | uid·requestId 없음 |

---

### 6.10 `aggregateOpsMetrics`

| 항목 | 내용 |
|---|---|
| 종류·리전 | `onSchedule({schedule: '0 4 * * 1', timeZone: 'Asia/Seoul'})`, asia-northeast3 |
| 출력 | `opsMetrics/{isoWeek}`(예: `2026-W45`, 직전 주 월 00:00 ~ 일 24:00 KST). `set()`으로 덮어써 멱등 |
| 단계·스토리 | P1a(M-03, DF-137), P1b(M-05, DF-224), P2(M-06·M-07·M-09·M-10, DF-137 확장) |
| PRD | §5.3, §9.2 opsMetrics |

```json
{
  "isoWeek": "2026-W45",
  "weekStart": "2026-11-02T00:00:00+09:00",
  "weekEnd": "2026-11-08T23:59:59.999+09:00",
  "generatedAt": "<serverTimestamp>",
  "schemaVersion": 1,
  "m03": { "numerator": 42, "denominator": 55, "rate": 0.7636 },
  "m05": { "numerator": 17, "denominator": 20, "rate": 0.85,
           "byReason": { "conditionMismatch": 1, "deviceChanged": 1, "protocolChanged": 0, "noComparison": 1 } },
  "m06": null, "m07": null, "m09": null, "m10": null
}
```

| 지표 | 분모 | 분자 | 코호트 | 단계 |
|---|---|---|---|---|
| M-03 | `sessionDate`가 대상 주(KST)인 v2 `soap_notes`(삭제된 draft는 집계 불가) | `finalizedAt ≤ sessionDate 당일 24:00 KST` | 대상 주 | P1a |
| M-05 | 대상 주에 confirmed·active가 된 재평가 기록 중 비교 후보가 있는 쌍(정책 사유 제외) | 조건 사유가 없는 쌍. 조건 비교는 [09_ALGORITHMS_SPEC.md](09_ALGORITHMS_SPEC.md) conditionKey 규칙을 공유 | 대상 주 | P1b |
| M-06 | 7일 전 주에 공유된 `memberSummaries` | `firstViewedAt − sharedAt ≤ 7일`(§6.16) | 대상 주 −1 | P2 |
| M-07 | 대상 주에 세션(v2 노트 `sessionDate`)이 있던 담당 회원 | ① Live 저장 ② 확정 ③ 공유 후 열람 중 2개 이상을 같은 주에 충족 | 대상 주 | P2 |
| M-09 | 7일 전 주에 finalized된 노트 | 7일 안에 `memberSummaryId`가 생김(요약 `sharedAt − finalizedAt ≤ 7일`) | 대상 주 −1 | P2 |
| M-10 | 7일 전 주에 발급된 `inviteCodes` | 7일 안에 `redeemedAt` | 대상 주 −1 | P2 |

- 트레이너·회원 식별자와 건강 값은 저장하지 않는다. 비율은 소수 넷째 자리 반올림, 분모 0이면 `rate: null`.
- 아직 해당 단계가 아닌 지표는 `null`.

| ID | 상황 | 기대 |
|---|---|---|
| TC-06-AGG-01 | 합성: 주중 노트 10건, 당일 확정 7건, 다음 날 확정 1건 | `m03 = {7, 10, 0.7}` |
| TC-06-AGG-02 | 같은 주 재실행 | 문서 1개, 값 동일 |
| TC-06-AGG-03 | 문서 필드 검사 | uid·이름·수치 필드 없음 |
| TC-06-AGG-04 | 분모 0 | `rate: null` |

---
### 6.11 `issueInviteCode`

| 항목 | 내용 |
|---|---|
| 종류·리전 | callable, asia-northeast3, 비밀 `INVITE_CODE_HMAC_KEY` |
| 호출 주체 | 트레이너 앱 TR-14 '초대 코드 발급' |
| 인증 | `trainer` + `isPendingOwner(pendingMemberId)` |
| 플래그 | `memberShare == true`(초대 코드는 memberShare 묶음, ADR-010) |
| 단계·스토리 | P2, DF-304 |
| PRD | F-LINK-02.1~02.3, AC-LINK-02.2 |

요청·응답

```json
{ "type": "object", "additionalProperties": false, "required": ["pendingMemberId"],
  "properties": { "pendingMemberId": { "$ref": "common#/$defs/DocId" } } }
```

```json
{ "ok": true, "code": "K7QM-3XPA", "expiresAt": "2027-02-09T05:00:00.000Z", "revokedCount": 1 }
```

- **코드 생성.** 문자 집합 `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`(32자, 0·O·1·I 제외)에서 `crypto.randomInt`로 8자를 뽑는다. 표시 형식은 `XXXX-XXXX`다. 정규화: 대문자로 바꾸고 `-`와 공백을 제거한다(ASM-06-21). 엔트로피는 40비트다.
- **저장.** `codeHash = hex(HMAC_SHA256(INVITE_CODE_HMAC_KEY, normalizedCode))`. 원문은 어디에도 저장하지 않고 로그에도 남기지 않는다(AC-LINK-02.2, NFR-10).
- **트랜잭션**(읽기 먼저)
  1. 읽기: `pendingMembers/{p}`, `appConfig/features`, `inviteCodes where pendingMemberId == p && status == 'active'`(트랜잭션 쿼리), 새 `inviteCodes/{codeHash}`(충돌 확인).
  2. 검증: 소유·pending, 플래그. 새 해시가 이미 있으면 코드를 다시 뽑는다(최대 3회, 그 뒤 `internal`).
  3. 쓰기: 기존 active 코드 → `status: 'revoked'`(F-LINK-02.3). 새 코드:

     ```json
     { "codeHash": "9c1e…", "pendingMemberId": "SYNTHpending00000001", "trainerId": "synthTrainerA",
       "status": "active", "expiresAt": "<now + 7일>", "createdAt": "<serverTimestamp>",
       "redeemedByUid": null, "redeemedAt": null, "schemaVersion": 1 }
     ```

     `pendingMembers/{p}.inviteCodeId = codeHash`, `updatedAt`.
- **멱등성.** 없음. 재호출은 이전 코드를 폐기하고 새 코드를 만든다. 응답을 못 받은 트레이너는 다시 발급하면 된다.
- **레이트 리밋.** 대기 회원당 1시간 10회. `inviteCodes where pendingMemberId == p && createdAt > now − 1h` 건수로 판단한다(별도 저장소 없음).

| messageKey | code | 조건 |
|---|---|---|
| `member.pendingNotOwned` | permission-denied | 소유자 아님 또는 pending 아님 |
| `flag.disabled` | failed-precondition | memberShare 꺼짐 |
| `invite.issueRateLimited` | resource-exhausted | 1시간 10회 초과 |

| ID | 상황 | 기대 | 연결 |
|---|---|---|---|
| TC-06-INV-01 | 정상 발급 | 응답 코드 형식 `^[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$`, `inviteCodes`에 해시만, 원문 필드 0 | AC-LINK-02.2 |
| TC-06-INV-02 | 재발급 | 이전 코드 `revoked`, active 1개 | F-LINK-02.3 |
| TC-06-INV-03 | 다른 트레이너의 대기 회원 | permission-denied | F-LINK-02.1 |
| TC-06-INV-04 | 전 컬렉션 스캔으로 원문 검색 | 0건 | AC-LINK-02.2 |
| TC-06-INV-05 | 11번째 발급(1시간 안) | resource-exhausted | 레이트 리밋 |

---

### 6.12 `redeemInviteCode`

| 항목 | 내용 |
|---|---|
| 종류·리전 | callable, asia-northeast3, 비밀 `INVITE_CODE_HMAC_KEY`, `memory: '512MiB'`, `timeoutSeconds: 300` |
| 호출 주체 | 회원 앱 MB-05 |
| 인증 | `memberNonStaff`(F-LINK-02.8) |
| 플래그 | `memberShare == true` |
| 단계·스토리 | P2, DF-305(서버), DF-306(MB-05) |
| PRD | F-LINK-02.4~02.8, F-PRIV-03.4, AC-LINK-02.1~02.5, AC-VIZ-05.3 |

요청·응답

```json
{ "type": "object", "additionalProperties": false, "required": ["code", "ageConfirmed14"],
  "properties": {
    "code": { "type": "string", "minLength": 8, "maxLength": 12 },
    "ageConfirmed14": { "const": true }
  } }
```

```json
{ "ok": true, "status": "promoted", "trainerId": "synthTrainerA", "recordCount": 14 }
```

`status`는 `promoted`(이번 호출에서 완료) 또는 `resumed`(이전 중단분을 이어서 완료)다.

#### 6.12.1 처리 절차

**레이트 리밋 선검사.** `users/{uid}.inviteRedeemGuard = {windowStartedAt, failures}`(서버 전용 필드, ASM-06-22)를 읽어 1시간 창 안에서 `failures >= 5`이면 `resource-exhausted / invite.tooManyAttempts`.

**T1 — 검증과 담당·동의 이관(트랜잭션)**

1. 읽기: `inviteCodes/{hash}`, `users/{uid}`, `pendingMembers/{p}`, `trainers/{t}`, `memberConsentStates/{p}`, `memberConsentStates/{uid}`, `appConfig/features`.
2. 판정
   - 코드 없음, `status in ['expired', 'revoked']`, `expiresAt < now`, 또는 `redeemed`이면서 `redeemedByUid != uid` → **실패 카운트 증가**(별도 쓰기) 후 `invalid-argument / invite.invalidOrExpired`. 사유를 나누지 않는다(F-LINK-02.7).
   - `redeemed`이고 `redeemedByUid == uid` → 재개 모드, T2로 간다(F-LINK-02.5).
   - `users/{uid}`가 없으면 `failed-precondition / invite.profileMissing`.
   - `users.trainerId`가 있고 `t`와 다르면 `already-exists / invite.conflict`(F-LINK-02.6). 코드 상태는 바꾸지 않는다.
   - `pendingMembers/{p}.status != 'pending'`이고 `promotedUid != uid` → `invite.invalidOrExpired`.
3. 쓰기(한 트랜잭션, AC-LINK-02.5)
   - `inviteCodes/{hash}`: `status: 'redeemed'`, `redeemedByUid`, `redeemedAt`.
   - `trainers/{t}.memberIds`: `arrayUnion(uid)`, `updatedAt`.
   - `users/{uid}`: `trainerId = t`, `assignedTrainerId = t`, `trainerAssignedAt`(기존 패턴 dfet:functions/index.js:680-684).
   - `memberConsentStates/{uid}`: 유형별로 `{p}`와 `{uid}` 항목 중 `updatedAt` 최신, 같으면 철회 우선으로 병합(F-PRIV-02.2).
   - `pendingMembers/{p}`: `promotedUid = uid`, `updatedAt`. `status`는 T3에서 바꾼다.
   - `users/{uid}.inviteRedeemGuard` 삭제.

**T2 — 기록 채움(청크 배치, 멱등)**

- `soap_notes`, `postureAssessments`, `bodyCompositionRecords`, `circumferenceMeasurements`에서 `pendingMemberId == p && memberUid == null`을 400건씩 찾아 `memberUid = uid`를 쓴다. `soap_notes`는 레거시 호환을 위해 `memberId = uid`도 쓴다(PRD §9.3 호환 기간).
- `consentRecords where pendingMemberId == p && subjectUid == null` → `subjectUid = uid`(F-PRIV-03.4, append-only 예외).
- Storage 경로는 바꾸지 않는다(기록 ID 기준, AC-LINK-02.3).
- `bodyScans`는 대기 회원 대상이 아니므로 제외한다(F-LINK-01.7).

**T3 — 마무리(트랜잭션)**

1. T2 쿼리를 한 번 더 돌려 남은 문서가 0건인지 확인한다(트레이너가 T2 도중 대기 키로 새 기록을 만들었을 수 있음). 남았으면 T2를 반복한다(최대 3회, 그래도 남으면 `aborted`로 응답해 클라이언트가 재호출).
2. `pendingMembers/{p}`: `status = 'promoted'`, `promotedAt`.
3. `memberConsentStates/{p}` 삭제(F-PRIV-03.4).
4. 감사 `memberPromoted`(`actorRole: member`, `targetCollection: 'pendingMembers'`, `targetId: p`, `memberUid: uid`, `metadata: {recordCount, resumed}`).
5. 커밋 후 `syncRecordAccessKeysCore({memberUid: uid})`.

- 트레이너 규칙 `isPendingOwner`는 T3까지 `status == 'pending'`이므로 참이다. T3 뒤에는 `memberUid` 기준 `isAssignedTrainer`로 넘어간다.

#### 6.12.2 오류

| messageKey | code | 조건 | 회원 앱 문구 키 |
|---|---|---|---|
| `invite.invalidOrExpired` | invalid-argument | 없음·만료·폐기·타인 사용 | '유효하지 않거나 만료된 코드' 하나(F-LINK-02.7) |
| `invite.tooManyAttempts` | resource-exhausted | 1시간 5회 실패 | 잠시 뒤 다시 |
| `invite.conflict` | already-exists | 다른 담당 트레이너 있음 | 센터에 문의 |
| `invite.profileMissing` | failed-precondition | `users/{uid}` 없음 | 프로필 설정 먼저 |
| `auth.staffAccountNotAllowed` | permission-denied | 직원 claim 계정 | 회원 계정으로 |
| `flag.disabled` | failed-precondition | memberShare 꺼짐 | '추후 추가 예정' |

#### 6.12.3 테스트 케이스(`functions/test/e2e/invite.e2e.test.js`)

| ID | 상황 | 기대 | 연결 |
|---|---|---|---|
| TC-06-RED-01 | 대기 기록 14건(SOAP·신체조성·둘레·체형), 정상 사용 | 전 기록 `memberUid == uid && pendingMemberId == p`, 수 동일, Storage 경로 불변, `status=promoted` | AC-LINK-02.3 |
| TC-06-RED-02 | 다른 uid가 redeemed 코드 입력 | invalid-argument, 담당·기록 불변 | AC-LINK-02.1 |
| TC-06-RED-03 | 만료 코드 | invalid-argument(같은 messageKey) | AC-LINK-02.2 |
| TC-06-RED-04 | T2 도중 예외 주입 후 같은 uid 재호출 | `status: resumed`, 중복·누락 0 | AC-LINK-02.4 |
| TC-06-RED-05 | T1 커밋 직후 `trainers.memberIds`와 `users.trainerId` | 항상 함께 존재(부분 커밋 없음) | AC-LINK-02.5 |
| TC-06-RED-06 | 다른 담당이 있는 회원 | already-exists / `invite.conflict` | F-LINK-02.6 |
| TC-06-RED-07 | 6번째 실패 | resource-exhausted | F-LINK-02.7 |
| TC-06-RED-08 | trainer claim 계정 | permission-denied | F-LINK-02.8 |
| TC-06-RED-09 | 동의 병합: 대기 ② grant(10:00), 회원 앱 ② withdraw(10:05) | 결과 `healthData.granted = false` | F-PRIV-02.2 |
| TC-06-RED-10 | 승격 후 TR-03 쿼리 | 승격 전·후 기록이 하나의 타임라인으로 조회 | AC-VIZ-05.3 |

---

### 6.13 `createMemberSummary`

| 항목 | 내용 |
|---|---|
| 종류·리전 | callable, asia-northeast3, `memory: '512MiB'` |
| 호출 주체 | 트레이너 앱 TR-06 미리보기의 '공유' 확인(오프라인이면 호출하지 않고 '온라인 필요') |
| 인증 | `trainer` + `isAssignedTrainer(memberUid)` + 모든 원천 기록 `trainerId == auth.uid` |
| 플래그 | `memberShare == true` |
| 단계·스토리 | P2, DF-309(soapNote·서버 검사), DF-313(bodyReport), P3 DF-381(판정 연동) |
| PRD | F-SOAP-05.1~05.15, F-LINK-05.2, F-VIZ-06, F-PRIV-06.2, §7.6, §7.8, AC-SOAP-05.*, AC-PRIV-06.2 |

#### 6.13.1 요청 스키마

스파인의 `sourceIds[]`, `highlightRefIds[]`를 구체화했다(ASM-06-23). 저장 문서의 `sourceIds`는 PRD §9.2 그대로 ID 배열이다.

```json
{
  "type": "object", "additionalProperties": false,
  "required": ["requestId", "sourceType", "sources", "title", "body", "nextPlan", "highlights"],
  "properties": {
    "requestId": { "$ref": "common#/$defs/RequestId" },
    "sourceType": { "enum": ["soapNote", "bodyReport"] },
    "sources": {
      "type": "array", "minItems": 1, "maxItems": 20,
      "items": { "type": "object", "additionalProperties": false, "required": ["collection", "id"],
        "properties": {
          "collection": { "enum": ["soap_notes", "postureAssessments", "bodyCompositionRecords", "circumferenceMeasurements"] },
          "id": { "$ref": "common#/$defs/DocId" } } }
    },
    "title": { "type": "string", "minLength": 1, "maxLength": 100 },
    "body": { "type": "string", "maxLength": 8000 },
    "nextPlan": { "type": "string", "maxLength": 1000 },
    "highlights": {
      "type": "array", "maxItems": 10,
      "items": { "type": "object", "additionalProperties": false, "required": ["refId", "metricCode", "side"],
        "properties": {
          "refId": { "$ref": "common#/$defs/DocId" },
          "metricCode": { "$ref": "common#/$defs/MetricCode" },
          "side": { "$ref": "common#/$defs/Side" } } }
    },
    "photoPaths": { "type": "array", "maxItems": 6, "items": { "type": "string", "maxLength": 300 } }
  }
}
```

예시(soapNote, 합성)

```json
{
  "requestId": "a8d1e0b2-7c44-4e0f-8d0a-2b9f5d1c3e77",
  "sourceType": "soapNote",
  "sources": [{ "collection": "soap_notes", "id": "Xk2pQ9sVb3LmN0aR7tYe" }],
  "title": "11월 18일 운동 기록",
  "body": "오늘은 어깨 주변 스트레칭과 가벼운 근력 운동을 했어요.",
  "nextPlan": "다음 시간에는 하체 운동을 이어서 해요.",
  "highlights": [{ "refId": "Pa7Vn2QkLx0sT9dE4mWc", "metricCode": "craniovertebralAngle", "side": "none" }]
}
```

#### 6.13.2 검증(순서대로, 첫 실패에서 중단)

| # | 규칙 | 실패 |
|---|---|---|
| V1 | 플래그 `memberShare` | failed-precondition / `flag.disabled` |
| V2 | `soapNote`: `sources`는 `soap_notes` 정확히 1건, `highlights` ≤ 3, `photoPaths` 없음(AS-24) | invalid-argument / `summary.shapeInvalid` |
| V3 | `bodyReport`: `sources`는 `postureAssessments`·`bodyCompositionRecords`·`circumferenceMeasurements`만, `highlights` ≤ 10 | invalid-argument / `summary.shapeInvalid` |
| V4 | 모든 원천 문서가 있고 `trainerId == auth.uid`, 같은 `memberUid`(null 아님). 대기 회원이면 거부(F-SOAP-05.2) | permission-denied / `member.notAssigned`, failed-precondition / `summary.memberNotLinked` |
| V5 | 원천 상태: SOAP `finalized`, 체형 `confirmed`, 신체조성·둘레 `active`, 둘레 `sourceGrade == 'tape'` | failed-precondition / `summary.sourceNotFinal` |
| V6 | `isAssignedTrainer(memberUid)`, `memberConsentStates/{uid}.healthData.granted` | permission-denied / `member.notAssigned`, failed-precondition / `consent.healthDataRequired` |
| V7 | highlight마다 원천 값이 있어야 한다. soapNote는 노트의 `objective.snapshots`에서 `(refId, metricCode, side)`가 일치하는 항목, bodyReport는 원천 기록의 `metrics`·`values`·`valueCm` | invalid-argument / `summary.highlightNotFound` |
| V8 | 제외 규칙: `metricCode == 'painNrs'`, `sourceGrade in ['photoAuto', 'observedSection', 'modelEstimate', 'aiAppearance']`는 거부(F-SOAP-05.5, F-SOAP-05.15) | failed-precondition / `summary.highlightExcluded` |
| V9 | `photoPaths`: `bodyImaging.granted == true`. 각 경로가 `postureAssessments/{원천 ID}/{front\|sagittalLeft\|sagittalRight}_masked_thumb.jpg` 또는 `_thumb.jpg`와 일치하고 파일이 존재. 원본 사진·결과지·스캔 썸네일은 불가 | failed-precondition / `summary.photoNotAllowed` |
| V10 | 금지어·약어 검사(6.13.3) | failed-precondition / `summary.prohibitedTerms` |

#### 6.13.3 금지어 검사

- 규칙 원본: `functions/src/shared/generated/prohibited-terms.v1.json`(contracts 복사본, ADR-016). 적용 세트는 `common` + `member`이고, 약어는 `abbreviationAllowlist` 밖이면 위반이다. 매칭 규칙(정규화, 띄어쓰기 변형)은 [09_ALGORITHMS_SPEC.md](09_ALGORITHMS_SPEC.md)와 [12_COPY_ANALYTICS_AND_LINT.md](12_COPY_ANALYTICS_AND_LINT.md)가 정본이다. 트레이너 앱 TR-06은 **같은 JSON**으로 먼저 검사한다(F-SOAP-05.6).
- 검사 필드: `title`, `body`, `nextPlan`.
- 위반 응답의 `details.violations`

```json
{
  "messageKey": "summary.prohibitedTerms", "retryable": false,
  "violations": [
    { "field": "body", "term": "교정", "start": 14, "end": 16, "ruleSet": "common", "suggestion": "자세 관리" },
    { "field": "body", "term": "ROM", "start": 30, "end": 33, "ruleSet": "abbreviation", "suggestion": "관절 움직임 범위" }
  ]
}
```

  `start`·`end`는 정규화 전 원문 기준 코드 포인트 위치다. `violations`는 호출자가 보낸 문장 안의 위치 정보이므로 NFR-10 예외다([§3.5](#35-응답과-오류-형식)).
- 인과 표현 패턴(`causalPatterns`)은 거부하지 않고 성공 응답의 `warnings[]`로 돌려준다(F-PRIV-06.2 '경고만').

#### 6.13.4 처리 절차

1. 읽기(트랜잭션): 원천 문서들, `memberConsentStates/{uid}`, `trainers/{auth.uid}`, `appConfig/features`, `memberSummaries/{requestId}`(멱등), soapNote면 노트의 현재 `memberSummaryId`가 가리키는 요약.
2. highlight 구성(§7.8, §9.2). 필드별 출처:

   | 필드 | soapNote | bodyReport |
   |---|---|---|
   | `value`, `unit`, `side`, `sourceGrade`, `measuredAt` | 노트 스냅샷 값(고정) | 원천 기록 값 |
   | `changeStatus`, `reasonCode`, `mdcSource`, `mdc` | P3 전: 모두 `null`(§7.6, 회원 배지 비대상). P3: `evaluateChangeCore` 결과를 받아 `mdcSource == 'inHouse'`이고 같은 `protocolVersion`일 때만 값을 두고 나머지는 `changeStatus = null` | 같음 |
   | `seriesKey` | `sha256(metricCode \| sourceGrade \| side \| conditionKey)` 앞 16자. conditionKey 구성은 [09_ALGORITHMS_SPEC.md](09_ALGORITHMS_SPEC.md) | 같음 |
   | `comparedTo` | 같은 `seriesKey`의 비교 기록(체형은 기준선, 그 밖에는 직전 active 기록) `{refId, measuredAt, value}` 또는 null(ASM-06-24) | 같음 |

3. `policyVersion`: P3 전 `null`. P3는 활성 bodyChange 정책 버전.
4. 쓰기
   - soapNote이고 기존 요약이 `shared`면 `revokeSummaryCore(reason: 'reshare')`로 먼저 해제한다(F-SOAP-05.9, AS-25).
   - `memberSummaries/{requestId}` create:

     ```json
     {
       "memberUid": "synthMember0001", "trainerId": "synthTrainerA", "sharedByUid": "synthTrainerA",
       "sourceType": "soapNote", "sourceIds": ["Xk2pQ9sVb3LmN0aR7tYe"],
       "title": "11월 18일 운동 기록", "body": "…", "nextPlan": "…",
       "highlights": [{
         "refId": "Pa7Vn2QkLx0sT9dE4mWc", "metricCode": "craniovertebralAngle", "value": 48.3, "unit": "deg",
         "side": "none", "sourceGrade": "photoManual", "measuredAt": "2026-11-18T02:10:00.000Z",
         "changeStatus": null, "reasonCode": null, "mdcSource": null, "mdc": null,
         "seriesKey": "5f1c0a9e3b7d2c44", "comparedTo": { "refId": "Lm0…", "measuredAt": "2026-10-21T02:05:00.000Z", "value": 46.1 }
       }],
       "sharedPhotoPaths": [], "policyVersion": null,
       "status": "shared", "sharedAt": "<serverTimestamp>", "revokedAt": null,
       "firstViewedAt": null, "schemaVersion": 1
     }
     ```

   - soapNote: `soap_notes/{id}.memberSummaryId = requestId`(서버 전용 필드, 규칙 우회는 Admin SDK).
   - 감사 `summaryShared`(`metadata: {sourceType}`).
5. 응답 `{ok, replayed, summaryId, revokedSummaryId, warnings}`.

- 제외 필드는 어떤 경우에도 복사하지 않는다: `inkPath`, `quickNote`, `objective.metrics[].note`, `exerciseAssessment`, `subjective`, addendum, `reportPhotoPath`(AC-SOAP-05.4).
- 공유 알림(F-SOAP-05.12)은 이 함수 범위 밖이다. 회원 앱에 푸시 SDK가 없어(dfet:pubspec.yaml에 `firebase_messaging` 없음) 별도 결정이 필요하다(ASM-06-25, Q-DEV-03).

#### 6.13.5 멱등성·레이트 리밋

- 멱등 키 `requestId` = 요약 문서 ID. 같은 원천·같은 본문이면 `replayed`, 다르면 `idempotency.keyReused`.
- 레이트 리밋 없음.

#### 6.13.6 테스트 케이스(`functions/test/e2e/createMemberSummary.e2e.test.js`, 단위 `functions/test/unit/summaries/*.test.js` — V1-10과 같은 파일)

| ID | 상황 | 기대 | 연결 |
|---|---|---|---|
| TC-06-CMS-01 | finalized 노트 확정 직후, 함수 호출 없음 | `memberSummaries` 0건 | AC-SOAP-05.1 |
| TC-06-CMS-02 | 정상 soapNote 공유 | 요약 1건, `memberSummaryId` 역참조, 감사 1건 | F-SOAP-05.7 |
| TC-06-CMS-03 | draft 노트 | failed-precondition / `summary.sourceNotFinal` | AC-SOAP-05.3 |
| TC-06-CMS-04 | 대기 회원 노트 | failed-precondition / `summary.memberNotLinked` | AC-SOAP-05.3 |
| TC-06-CMS-05 | 본문에 '치료', '교정', '원인은', '개선' | failed-precondition, `violations` 4건과 위치 | AC-SOAP-05.5, AC-PRIV-06.2 |
| TC-06-CMS-06 | 저장 문서 필드 검사 | `inkPath`, `quickNote`, 트레이너 note, `exerciseAssessment`, 결과지 경로, `painNrs` 없음 | AC-SOAP-05.4 |
| TC-06-CMS-07 | `painNrs` highlight | failed-precondition / `summary.highlightExcluded` | F-SOAP-05.5 |
| TC-06-CMS-08 | 활성 정책 없음 | 모든 highlight `changeStatus: null`, `policyVersion: null` | AC-SOAP-05.9 |
| TC-06-CMS-09 | 재공유 | 이전 요약 revoked(내용 비움), 새 요약 shared, `revokedSummaryId` 응답 | F-SOAP-05.9 |
| TC-06-CMS-10 | bodyReport, ③ 없음 + `photoPaths` | failed-precondition / `summary.photoNotAllowed` | AC-SOAP-05.11 |
| TC-06-CMS-11 | bodyReport, photoAuto 지표 highlight | failed-precondition / `summary.highlightExcluded` | AC-SOAP-05.12 |
| TC-06-CMS-12 | 비담당 트레이너 | permission-denied | F-LINK-05.2 |
| TC-06-CMS-13 | memberShare false | failed-precondition / `flag.disabled` | ADR-010 |
| TC-06-CMS-14 | (P3) CVA `mdcSource=literature`, `withinError` | highlight `changeStatus: null` | T24 |
| TC-06-CMS-15 | (P3) CVA `mdcSource=inHouse`, `meaningfulImprovement`, 같은 protocolVersion | highlight에 상태 저장 | T25 |

---

### 6.14 `revokeMemberSummary`

| 항목 | 내용 |
|---|---|
| 종류·리전 | callable + 내부 모듈 `revokeSummaryCore`, asia-northeast3 |
| 인증 | `trainer` + 요약 `trainerId == auth.uid` + `isAssignedTrainer(memberUid)` |
| 플래그 | 없음(플래그를 꺼도 해제는 가능해야 함, PRD §6.0.2 memberShare 롤백) |
| 단계·스토리 | P2, DF-310 |
| PRD | F-SOAP-05.8, F-SOAP-05.9, F-LINK-05.3, AC-SOAP-05.7, AC-LINK-05.3 |

```json
{ "type": "object", "additionalProperties": false, "required": ["summaryId"],
  "properties": { "summaryId": { "$ref": "common#/$defs/DocId" } } }
```

```json
{ "ok": true, "replayed": false }
```

- 처리(`revokeSummaryCore({summaryId, reason})`): `status: 'revoked'`, `revokedAt`, `body: ''`, `highlights: []`, `sharedPhotoPaths: []`, `nextPlan: ''`(F-LINK-05.3). `title`은 PRD 비움 목록에 없어 남긴다. soapNote 원천의 `memberSummaryId`가 이 요약이면 `null`로 바꾼다(ASM-06-26). 감사 `summaryRevoked`(`metadata: {sourceType, reason}`).
- 멱등: 이미 revoked면 `replayed: true`.
- 해제 전 발급된 서명 URL은 만료(15분)까지 유효하다. 이후 `getSharedPhotoUrl`은 발급하지 않는다(AC-LINK-05.3).

| ID | 상황 | 기대 |
|---|---|---|
| TC-06-RMS-01 | shared 요약 해제 | 묘비 문서(내용 비움, `status=revoked`), 회원 쿼리 결과에서 사라짐(클라이언트 필터 `status == shared`) |
| TC-06-RMS-02 | 재호출 | `replayed: true` |
| TC-06-RMS-03 | 다른 트레이너 | permission-denied |
| TC-06-RMS-04 | 해제 후 `getSharedPhotoUrl` | failed-precondition / `summary.notShared` |

---

### 6.15 `getSharedPhotoUrl`

| 항목 | 내용 |
|---|---|
| 종류·리전 | callable, asia-northeast3 |
| 호출 주체 | **회원 전용**. 트레이너 앱은 SDK 바이트 다운로드를 쓰고 이 함수를 호출하지 않는다 |
| 인증 | `memberNonStaff` |
| 단계·스토리 | P2, DF-314 |
| PRD | F-LINK-05.6, F-VIZ-06.5, §9.5 회원 읽기 |

```json
{ "type": "object", "additionalProperties": false, "required": ["summaryId", "path"],
  "properties": { "summaryId": { "$ref": "common#/$defs/DocId" }, "path": { "type": "string", "maxLength": 300 } } }
```

```json
{ "ok": true, "url": "https://storage.googleapis.com/…", "expiresAt": "2027-02-20T05:15:00.000Z" }
```

- 검증: 요약 존재(`summary.notFound`), `memberUid == auth.uid`(`permission-denied / summary.notOwner`), `status == 'shared'`(`failed-precondition / summary.notShared`), `path ∈ sharedPhotoPaths`(`permission-denied / summary.pathNotShared`), `memberConsentStates/{uid}.bodyImaging.granted`(`failed-precondition / consent.bodyImagingRequired`).
- 처리: `bucket.file(path).getSignedUrl({version: 'v4', action: 'read', expires: now + 15분})`(제안값). 공개 URL·`getDownloadURL` 토큰은 쓰지 않는다.
- 서비스 계정 `signBlob` 권한 필요(ASM-06-15). 에뮬레이터에서는 서명기를 주입 가능한 인터페이스(`signer.sign(path, expires)`)로 두고 가짜 서명기로 테스트한다.
- 감사 없음(회원 본인 열람). 레이트 리밋 없음.

| ID | 상황 | 기대 | 연결 |
|---|---|---|---|
| TC-06-GSP-01 | 본인 shared 요약의 포함 경로 | URL과 `expiresAt = now+15m` | F-LINK-05.6 |
| TC-06-GSP-02 | 다른 회원 | permission-denied | F-LINK-05.6 |
| TC-06-GSP-03 | 요약 revoked | failed-precondition | AC-LINK-05.3 |
| TC-06-GSP-04 | 포함되지 않은 경로(원본 사진) | permission-denied | §9.5 |
| TC-06-GSP-05 | trainer claim | permission-denied | 회원 전용 |

---

### 6.16 `markSummaryViewed`

| 항목 | 내용 |
|---|---|
| 상태 | **제안(ASM-06-04).** 스파인 함수 목록에 없다. M-06(`member_summary_viewed` 서버 기록)과 M-07을 계산하려면 회원이 요약을 열었다는 서버 기록이 필요한데, 회원은 `memberSummaries`에 쓸 수 없다(PRD §9.4). 소유자 승인 전에는 구현하지 않는다(Q-DEV-04) |
| 종류·리전 | callable, asia-northeast3 |
| 인증 | `memberNonStaff` + 요약 `memberUid == auth.uid` |
| 단계·스토리 | P2, DF-335(추가 제안, 02 §8.8.1) |
| 호출 | MB-02·MB-04 첫 렌더 1회 |

```json
{ "type": "object", "additionalProperties": false, "required": ["summaryId"],
  "properties": { "summaryId": { "$ref": "common#/$defs/DocId" } } }
```

- 처리: `status == 'shared'`이고 `firstViewedAt == null`이면 `firstViewedAt = serverTimestamp()`. 이미 있으면 아무것도 쓰지 않고 `{ok: true, replayed: true}`.
- 호출 시점: MB-02·MB-04에서 요약 상세가 처음 렌더될 때 1회(V1-08, V1-05 §4.10). 실패해도 화면을 막지 않는다.

| ID | 상황 | 기대 |
|---|---|---|
| TC-06-MSV-01 | 첫 열람 | `firstViewedAt` 설정 |
| TC-06-MSV-02 | 두 번째 열람 | 값 불변 |
| TC-06-MSV-03 | 다른 회원 | permission-denied |

---

### 6.17 `linkMemberAlias`

| 항목 | 내용 |
|---|---|
| 종류·리전 | callable, asia-northeast3 |
| 호출 주체 | 트레이너 앱 TR-13 결과 패키지 첫 가져오기 시 회원 확인 뒤 |
| 인증 | `trainer` + `isAssignedTrainer(memberUid)` |
| 플래그 | `lidarBeta == true`(TR-13 전용, ASM-06-27) |
| 단계·스토리 | P2, DF-319 |
| PRD | F-LINK-04.1~04.4, F-LIDAR-01.2, AC-LINK-04.1~04.3 |

```json
{ "type": "object", "additionalProperties": false, "required": ["system", "externalId", "memberUid"],
  "properties": {
    "system": { "const": "bodypath" },
    "externalId": { "type": "string", "pattern": "^[A-Za-z0-9._:-]{1,64}$", "description": "BodyPath Subject.code" },
    "memberUid": { "$ref": "common#/$defs/DocId" } } }
```

```json
{ "ok": true, "replayed": false, "aliasId": "e3b0c442…(64 hex)" }
```

- `aliasId = hex(sha256("bodypath:" + externalId))`(기존 규약 dfet:functions/src/clinical/ingestion.js:94).
- 트랜잭션: 별칭이 있고 `memberUid`가 같으면 `replayed`, 다르면 `already-exists / alias.alreadyLinked`(AC-LINK-04.1). 없으면 create:

```json
{ "memberUid": "synthMember0001", "userId": "synthMember0001", "system": "bodypath",
  "externalId": "SUBJ-0007", "createdBy": "synthTrainerA", "createdAt": "<serverTimestamp>", "schemaVersion": 1 }
```

- `system`은 v1에서 `bodypath`만 받는다. `inbody`는 V2, `clinicalLab`은 admin_web 경로다.
- 감사: PRD §9.7에 action이 없어 쓰지 않는다.

| ID | 상황 | 기대 | 연결 |
|---|---|---|---|
| TC-06-LMA-01 | 신규 연결 | 문서 1건, `userId == memberUid` | F-LINK-04.2 |
| TC-06-LMA-02 | 같은 externalId를 다른 회원으로 | already-exists | AC-LINK-04.1 |
| TC-06-LMA-03 | 비담당 트레이너 | permission-denied | AC-LINK-04.2 |
| TC-06-LMA-04 | 기존 `clinical-emulator-e2e.js` | 통과(회귀) | AC-LINK-04.3 |

---

### 6.18 `verifyPostureConfirmed`

| 항목 | 내용 |
|---|---|
| 종류·리전 | `onDocumentWritten('postureAssessments/{assessmentId}')`, asia-northeast3, `retry: true` |
| 단계·스토리 | P2, DF-324 |
| PRD | AC-ASM-04.1(P2 재검증), F-ASM-03.5, AS-30, 부록 A.3 |

- 조건: `after` 존재, `after.status == 'confirmed'`, `after.imagingPurgedAt` 없음(③ 철회 파기로 랜드마크가 비워진 문서는 검사하지 않는다, ASM-06-17).
- 검사: `after.metrics[]`마다 부록 A.3의 필수 랜드마크(`contracts/metric-catalog.v1.json`의 `requiredLandmarks`, CVA는 촬영 방향 `tragus{Left|Right}`+`c7`, 머리 기울기 `ear` 쌍, 어깨 `acromion` 쌍, 골반 `asis` 쌍)가 해당 view에 있고 모두 `confirmed == true`인지, `sourceGrade == 'photoManual'`인지 본다.
- 위반: `status = 'draft'`, `updatedAt`, 감사 `postureReverted`(문서 ID `postureReverted_{event.id}`, `metadata: {violation}`). 되돌린 뒤 다시 발생하는 이벤트는 `status == 'draft'`라 종료된다.

| ID | 상황 | 기대 |
|---|---|---|
| TC-06-VPC-01 | Admin SDK로 c7 `confirmed:false`인 confirmed 문서 작성 | draft로 되돌림, 감사 1건 `landmarkUnconfirmed` |
| TC-06-VPC-02 | photoAuto 지표가 든 confirmed | 되돌림 `sourceGradeMismatch` |
| TC-06-VPC-03 | 정상 confirmed | 변경 없음 |
| TC-06-VPC-04 | `imagingPurgedAt` 있는 confirmed | 변경 없음 |

---

### 6.19 `evaluateChange`

| 항목 | 내용 |
|---|---|
| 종류·리전 | 내부 모듈 `evaluateChangeCore` + callable `evaluateChange`, asia-northeast3 |
| 호출 주체 | 트레이너 앱 TR-10(표시용), `createMemberSummary`·SOAP 스냅샷 생성(내부) |
| 인증 | `trainer` + 현재·비교 기록 모두 `trainerId == auth.uid` |
| 단계·스토리 | P3, DF-380(엔진·벡터), DF-381(연동) |
| PRD | §7.5, §7.6, §7.9, F-SOAP-03.4, AC-SOAP-03.5, G-08, ADR-009 |

요청·응답

```json
{
  "type": "object", "additionalProperties": false,
  "required": ["memberUid", "metricCode", "sourceGrade", "currentRefId"],
  "properties": {
    "memberUid": { "$ref": "common#/$defs/DocId" },
    "metricCode": { "$ref": "common#/$defs/MetricCode" },
    "sourceGrade": { "$ref": "common#/$defs/SourceGrade" },
    "side": { "$ref": "common#/$defs/Side", "description": "좌우 지표(thigh 등)에서 필수(ASM-06-28)" },
    "currentRefId": { "$ref": "common#/$defs/DocId" },
    "comparisonRefId": { "$ref": "common#/$defs/DocId", "description": "없으면 기본 비교 기준(§7.5)" }
  }
}
```

```json
{
  "ok": true,
  "changeStatus": "withinError",
  "reasonCode": null,
  "delta": 5.5,
  "mdcSource": "literature",
  "mdc": { "value": 5.52, "source": "literature", "reference": "https://www.mdpi.com/1660-4601/17/18/6521" },
  "policyVersion": "bodyChange-2027-04-01",
  "comparison": { "refId": "Lm0…", "measuredAt": "2027-03-02T02:05:00.000Z", "value": 45.0 },
  "sideChanged": false
}
```

- 대상 컬렉션은 카탈로그 `family`로 정한다: 자세 → `postureAssessments`, 신체조성 → `bodyCompositionRecords`, 둘레 → `circumferenceMeasurements`. `painNrs`·`romDeg`·`mmtGrade`는 호출 없이 `referenceMetric`/`noMdc`가 되므로 클라이언트는 호출하지 않는다.
- 판정 의사코드·반올림·`towardZero`·`DEVICE_KEY`·조건 키 순서는 [09_ALGORITHMS_SPEC.md](09_ALGORITHMS_SPEC.md)(PRD §7.5)가 정본이다. 이 함수는 입력 수집, 권한, 응답 형식만 책임진다.
- 기본 비교 기준: 체형은 같은 회원·같은 측면 방향의 `isBaseline`, 그 밖에는 같은 시리즈의 직전 active 기록. 비교 후보에서 draft·voided·재검사 묶음의 첫 기록이 아닌 것은 뺀다(§7.5).
- 오류: `change.recordNotFound`(not-found), `member.notAssigned`, `change.metricNotInRecord`(invalid-argument).
- 오프라인이면 트레이너 앱은 호출하지 않고 '온라인 필요'를 표시한다(ADR-009).
- P3 전에는 배포하지 않는다. 스냅샷은 `pendingPolicy`로 저장된다(F-SOAP-03.4).

| ID | 상황 | 기대 |
|---|---|---|
| TC-06-EVC-T01~T25 | `contracts/vectors/change-eval.v1.json` 25건을 `evaluateChangeCore`에 입력 | PRD §7.9 기대값과 모두 일치 |
| TC-06-EVC-26 | 비담당 트레이너 | permission-denied |
| TC-06-EVC-27 | 활성 정책 없음 | `changeStatus: pendingPolicy`, 나머지 null |
| TC-06-EVC-28 | 정적 검사: `trainer_app`·`lib/`에 MDC 상수·판정 분기 없음 | 0건(DF-216 정적 검사와 공유) |

---

### 6.20 `clinicalApi` bodycomp kind (V2)

- v1에서는 구현하지 않는다(DF-500, `prio/could`, 미추정). 재검토 조건: LookinBody API 승인·요금 확인과 별도 PRD 승인(PRD F-BC-04, RISK-08).
- v1이 미리 보장하는 것: `bodyCompositionRecords`에 `source`, `externalId`, `idempotencyKey`, `rawPath` 필드 자리(PRD §9.2, AC-BC-04.1, DF-006), `memberAliases.system = 'inbody'` 예약.
- 구현 시 계약은 기존 수집 API([docs/deliverables/05_API_INTERFACE.md](../deliverables/05_API_INTERFACE.md))의 HMAC·envelope·idempotency를 그대로 쓰고 `POST /v1/ingestions/bodycomp`만 추가한다.

---

## 7. admin_web 서버 API

- 공통: Next.js route handler, `assertSameOrigin`, `getConsoleUser()`로 세션 확인(dfet:admin_web/lib/auth.ts:25-42), Admin SDK 쓰기. 응답은 기존처럼 `{ok: true}` 또는 `{error}`(dfet:admin_web/app/api/admin/feature-flags/route.ts:26-28).
- 역할: DF-101 전에는 `actor.role === 'admin'`, DF-101 뒤에는 `admin` claim만(ADR-018).
- 감사: DF-136에서 `writeAudit`을 PRD 형식(`targetCollection`, `targetId`, `memberUid`, `at`, 화이트리스트 `metadata`, `actorEmail` 제거)으로 바꾼다. 기존 기록은 읽을 때 `createdAt → at`으로 해석한다(ASM-06-30).
- 스키마: zod 스키마는 `admin_web/lib/generated/contracts.ts`(생성물)에서 enum을 가져온다(ADR-005).

### 7.1 `POST /api/admin/feature-flags` (AD-07, DF-027)

```ts
// 8키 모두 필수. 문서가 없거나 키가 없으면 클라이언트는 false로 읽는다(ADR-010).
const schema = z.object({
  gut: z.boolean(), blood: z.boolean(), insights: z.boolean(),
  bodyAssessment: z.boolean(), bodyComposition: z.boolean(), soapV2: z.boolean(),
  memberShare: z.boolean(), lidarBeta: z.boolean(),
}).strict();
```

- 쓰기: `appConfig/features`에 8키 + `updatedAt`, `updatedBy`를 `set()`한다. 8키가 모두 필수이므로 일부 키가 지워지는 문제(§2의 5번)가 사라진다.
- 감사: 기존 action `app.feature_flags.update`, `metadata`는 8키 불리언.
- 테스트: 7키만 보내면 400, 8키 저장 뒤 Dart·Swift 파서가 같은 값을 읽음(DF-027 AC).

### 7.2 `GET·POST /api/admin/consent-documents` (AD-03, DF-032)

| 요청 | 본문 | 처리 |
|---|---|---|
| `POST {op: 'createDraft', ...}` | `consentType`, `version`, `title`, `purpose`, `items[]`(1~50, 각 ≤200자), `retention`(구체 기간 문자열), `recipient`(④ 필수), `refusalNotice`, `privacyPolicyVersion` | `consentDocumentVersions/{consentType}--{version}` create(예: `healthData--1.0`, V1-05 §4.13). 같은 ID가 있으면 409, `status: 'draft'` |
| `POST {op: 'updateDraft', versionId, ...}` | 같음 | draft만 수정 |
| `POST {op: 'publish', versionId}` | — | 다섯 고지 항목(목적·항목·보유기간·거부권·불이익) 비어 있지 않음, `sharing`은 `recipient` 필수, `privacyPolicyVersion` 필수. 통과 시 `status: 'published'`, `publishedAt`. 같은 유형의 이전 published는 `retired` |
| `POST {op: 'retire', versionId}` | — | published → retired |
| `GET ?consentType=` | — | 목록 |

- published 문서는 수정·삭제 불가(PRD §9.2). 위반 시 409.
- 감사 action: `consentDocument.publish`, `consentDocument.retire`(audit-actions 등록, DF-033).
- 테스트: 보유기간 빈 문서 publish → 400(AC-PRIV-01.3), `sharing`에 `recipient` 없음 → 400(AC-PRIV-01.4).

### 7.3 `GET·POST /api/admin/rights-requests` (AD-06, P2 DF-317)

- `GET ?status=received|inProgress|completed|rejected` → 큐(`dueAt` 오름차순, 인덱스 `status, dueAt`).
- `POST {op: 'setStatus', requestId, status: 'inProgress'|'completed'|'rejected'}` → 상태·`handledBy`·`completedAt` 갱신, 감사 `rightsRequestHandled`.
- 열람 내보내기는 라우트가 아니라 브라우저의 Firebase 클라이언트 SDK(`admin_web/lib/firebase-client.ts`)가 관리자 본인 ID 토큰으로 callable `exportMemberData`를 호출한다. admin_web 서버는 세션 쿠키만 가지므로 callable을 대신 호출하지 않는다.
- P1a에는 이 화면이 없다. 같은 동작을 소유자가 Admin SDK 스크립트 `functions/scripts/ops/rights-request.js`(`--dry-run` 기본)로 수행한다(ASM-06-29).

### 7.4 `GET /api/admin/pending-members` (AD-02, P2 DF-318)

- 쿼리 `?status=pending|promoted|cancelled|expired`. 응답 필드: `pendingMemberId`, `displayName`, `status`, `trainerId`, `createdAt`, `inviteStatus`(active 코드 여부만). **코드 원문·해시는 돌려주지 않는다.**
- 조회마다 `healthRecordRead`(`surface: 'adminMemberDetail'`, `pendingMember: true`)를 남긴다.

### 7.5 `POST /api/clinical/config` bodyChange kind (P1b DF-221, 운영 P3 DF-384)

기존 `policyKind` enum에 `bodyChange`를 더하고 다음을 검증한다(PRD §10.7).

```ts
const bodyChangeMetric = z.object({
  mdcValue: z.number().positive(),
  mdcSource: z.enum(['literature', 'inHouse']),
  mdcReference: z.string().min(1).max(500),
  protocolVersion: z.string().min(1),
  improvementDirection: z.enum(['higherIsBetter', 'lowerIsBetter', 'towardZero', 'none']),
  conditionKeys: z.array(z.string().min(1)).min(1),
}).strict();
const bodyChangePolicy = z.object({
  kind: z.literal('bodyChange'),
  version: z.string().min(1),
  metrics: z.record(z.enum(METRIC_CODES), bodyChangeMetric),   // METRIC_CODES는 생성물
}).strict();
```

- `mdcSource == 'inHouse'`면 `mdcReference`가 G-06 연구 보고서 식별자여야 한다(P3 운영 검증).
- 승인본 불변, kind별 단일 활성은 기존 로직을 재사용한다.

### 7.6 `lib/audit.ts` `recordHealthRead` (DF-136)

```ts
export async function recordHealthRead(
  actor: ConsoleUser,
  memberUid: string,
  targetCollection: 'users' | 'soap_notes' | 'postureAssessments' | 'bodyCompositionRecords'
    | 'circumferenceMeasurements' | 'bodyScans' | 'memberSummaries' | 'pendingMembers',
  targetId: string,
): Promise<void>;
// auditLogs: {action:'healthRecordRead', actorUid, actorRole, targetCollection, targetId, memberUid,
//             at: serverTimestamp(), metadata:{surface:'adminMemberDetail'}, schemaVersion:1}
```

- 회원 상세(`app/(console)/users/[uid]/page.tsx`)를 서버에서 렌더할 때마다 1건(AC-PRIV-05.1).

### 7.7 `POST /api/admin/assignments` (AD-01, 기존)

- 계약 변경 없음(`{memberUid, trainerUid | null}`, dfet:admin_web/app/api/admin/assignments/route.ts:10).
- 추가: 트랜잭션 안에서 `memberConsentStates/{memberUid}.sharing.granted`를 읽어 감사 `metadata.handover`와 `mode`를 넣는다. 재정렬은 `users/{uid}` 트리거(§6.1)가 처리하므로 라우트가 따로 호출하지 않는다.

### 7.8 `POST /api/admin/audit-reviews` (AD-06, P2 DF-317)

- 권한: admin claim 필수(ADR-018). 공통 `assertSameOrigin`·`getConsoleUser()`를 쓴다.
- 본문: `{period: 'YYYY-MM', reviewedCount: int ≥ 0}`. `period`는 패턴 `^\d{4}-(0[1-9]|1[0-2])$`이고 현재 월(Asia/Seoul) 이하다. 다른 키는 거부(zod `.strict()`).
- 처리: `writeAuditEvent({action: 'auditLogReviewed', targetCollection: 'auditLogs', targetId: period, memberUid: null, metadata: {period, reviewedCount}})`. action은 DF-317 PR에서 `contracts/audit-actions.v1.json`에 등록한다(`metadataKeys: ['period', 'reviewedCount']`). 새 컬렉션을 만들지 않는다(V1-08 §9.6, ASM-08-35).
- 응답: `{ok: true}`.
- 오류: §3 형식. 400 `invalid-argument`(잘못된 `period`·`reviewedCount`, 미래 월), 403 `permission-denied`(admin 아님).
- 근거: V1-08 CF 요청 C-08-14, backlog P2_P3 DF-317 수용 기준 3.

---
## 8. 트레이너 앱 Swift 계약

### 8.1 이름 대응과 배치

현행 `TrainerRepository`는 동기 메서드와 `changes: AnyPublisher<Void, Never>`뿐이라 쓰기 결과를 표현할 수 없다(dfet:trainer_ios/DFETTrainer/Domain/TrainerRepository.swift:4-15). v1은 이를 책임별 프로토콜로 나누고 모두 `async throws`와 `AsyncStream`으로 다시 정의한다(PRD §10.2.3, ADR-002). 이름은 [04_ARCHITECTURE.md](04_ARCHITECTURE.md) 모듈 표를 따른다.

| 흔히 부르는 이름 | v1 프로토콜 | 타깃(선언 / 구현) | 단계 | 스토리 |
|---|---|---|---|---|
| TrainerRepository(인증) | `AuthService` | TrainerDomain / FirebaseData | P0 | DF-012 |
| TrainerRepository(회원) | `MemberDirectory` | TrainerDomain / FirebaseData | P0~P1a | DF-013, DF-108, DF-113 |
| SoapRepository | `SoapNoteStore` | TrainerDomain / LocalStore+SyncEngine | P1a~P1b | DF-116~DF-124, DF-217 |
| BodyCompositionRepository | `MeasurementStore` | TrainerDomain / LocalStore+SyncEngine | P1a | DF-127~DF-129 |
| AssessmentRepository | `AssessmentStore` | TrainerDomain / LocalStore+SyncEngine+PostureVision | P1b | DF-203~DF-212 |
| ConsentRepository | `ConsentService` | TrainerDomain / LocalStore+SyncEngine+FirebaseData | P1a | DF-110~DF-112 |
| SyncOutbox | `OutboxProcessing`(SyncEngine) + `RemoteWriter`·`BinaryUploader`·`CallableClient` | SyncEngine·TrainerDomain / FirebaseData | P0~P1a | DF-014, DF-015, DF-104 |
| (조회 전용) | `RecordQueries`, `TimelineQueries` | TrainerDomain / FirebaseData | P1a | DF-114 |
| (설정) | `FeatureFlagReader`, `PolicyReader` | TrainerDomain / FirebaseData | P0, P3 | DF-017, DF-382 |
| (감사·권리) | `RecordAccessLogger`, `RightsRequestService` | TrainerDomain / FirebaseData | P1a | DF-115, DF-135 |
| (공유·초대·별칭) | `MemberSummaryService`, `InviteService`, `AliasLinker` | TrainerDomain / FirebaseData | P2 | DF-304, DF-311, DF-313, DF-319 |
| (판정 표시) | `ChangeEvaluator` | TrainerDomain / FirebaseData | P3 | DF-382 |
| (분석) | `AnalyticsClient` | TrainerAnalytics | P1a | DF-126 |

배치 규칙

- 프로토콜과 값 타입은 `TrainerDomain`(Foundation만 import)에 둔다. Firebase 타입(`Timestamp`, `DocumentReference`, `FunctionsErrorCode`)은 프로토콜 시그니처에 나타나지 않는다(NFR-03).
- 로컬 저장 메서드(`throws`, 동기)는 `@MainActor`에서 SwiftData `ModelContext`에 쓰고 곧바로 반환한다. `localSaved` p95 300ms(NFR-15)를 지키기 위해 네트워크를 기다리지 않는다.
- 원격 조회 메서드는 `async throws` 또는 `AsyncThrowingStream`이다. 오류를 빈 배열로 바꾸지 않는다(PRD §9.6).

### 8.2 공통 값 타입과 오류

```swift
// TrainerDomain/Identifiers.swift
public struct MemberUID: RawRepresentable, Hashable, Codable, Sendable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
public struct PendingMemberID: RawRepresentable, Hashable, Codable, Sendable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
public typealias NoteID = DocumentID<SoapNoteTag>
public typealias RecordID = DocumentID<BodyCompositionTag>
public typealias MeasurementID = DocumentID<CircumferenceTag>
public typealias AssessmentID = DocumentID<PostureAssessmentTag>
public typealias SummaryID = DocumentID<MemberSummaryTag>
public struct DocumentID<Tag>: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: String                        // Firestore 자동 ID와 같은 20자. 클라이언트에서 생성(ADR-002)
  public init(rawValue: String) { self.rawValue = rawValue }
  public static func generate() -> Self               // 62진 20자, SecRandomCopyBytes
}

/// 회원 키. 로컬 UUID는 존재하지 않는다(ADR-003, AC-LINK-03.3).
public enum MemberKey: Hashable, Codable, Sendable {
  case member(MemberUID)
  case pending(PendingMemberID)
  /// memberConsentStates 문서 ID, 규칙 memberKeyOf와 같은 값
  public var stateDocumentID: String { switch self { case .member(let u): u.rawValue; case .pending(let p): p.rawValue } }
}

/// SyncState는 TrainerContracts 생성물(contracts/vocab.v1.json syncState)이다.
/// localSaved | syncing | synced | syncFailed | awaitingConsent  (PRD §6.0.3)
```

```swift
// TrainerDomain/DomainError.swift
public struct MessageKey: RawRepresentable, Hashable, Codable, Sendable {   // §3.6 카탈로그, Localizable.xcstrings 키
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
}

public enum RemoteErrorCode: String, Codable, Sendable {                    // §3.6 callable code와 1:1
  case invalidArgument = "invalid-argument", failedPrecondition = "failed-precondition"
  case unauthenticated, permissionDenied = "permission-denied", notFound = "not-found"
  case alreadyExists = "already-exists", aborted, resourceExhausted = "resource-exhausted"
  case internalError = "internal", unavailable, deadlineExceeded = "deadline-exceeded", unknown
  public var isRetryable: Bool { [.aborted, .resourceExhausted, .internalError, .unavailable, .deadlineExceeded, .unknown].contains(self) }
}

public enum DomainError: Error, Equatable, Sendable {
  case notSignedIn                                        // 세션 없음 → 로그인 화면
  case notTrainer                                         // claim 없음 → 즉시 signOut(NFR-02)
  case onlineRequired                                     // 공유·초대·판정 등 온라인 전용 동작
  case remote(code: RemoteErrorCode, key: MessageKey?)    // 서버·규칙 거부, callable 오류
  case validation([ValidationIssue])                      // 로컬 도메인 검증(서버 호출 전)
  case prohibitedTerms([TermViolation])                   // TR-05·TR-06 금지어(차단 대상일 때)
  case consentRequired(ConsentType)                       // ②③⑤ 없음 — UI는 TR-14로 안내
  case flagDisabled(FeatureFlagKey)                       // 플래그 false
  case notFound
  case localStore(LocalStoreFailure)                      // SwiftData 저장 실패(디스크 등)
}

public struct ValidationIssue: Equatable, Sendable {
  public let field: String            // 예: "values.weightKg", "objective.metrics[2].joint"
  public let rule: Rule
  public enum Rule: Equatable, Sendable {
    case required, tooLong(max: Int), outOfRange(min: Double, max: Double), zeroNotAllowed
    case notInCatalog, landmarkNoteRequired, sideRequired, ageUnder14, measuredAtInFuture
    case finalizeRequirement(FinalizeRequirement)
  }
}
public enum FinalizeRequirement: String, Codable, Sendable { case memberKey, sessionDate, todayNote, nextPlan }   // §6.4.4 #1~#4
public struct TermViolation: Equatable, Codable, Sendable { public let field: String; public let term: String; public let start: Int; public let end: Int; public let ruleSet: String; public let suggestion: String? }
public enum LocalStoreFailure: String, Error, Sendable { case diskFull, protectedDataUnavailable, schemaMismatch, unknown }
```

- `DomainError.remote`의 `key`는 서버 `details.messageKey`다. UI 문자열은 `Localizable.xcstrings`의 같은 키로 찾는다. 모르는 키면 `common.<code>`를 쓴다([§3.5](#35-응답과-오류-형식)).

### 8.3 `AuthService`

```swift
public struct TrainerSession: Equatable, Sendable { public let uid: String; public let displayName: String?; public let claimsCheckedAt: Date }

public protocol AuthService: Sendable {
  /// trainer claim이 없으면 내부에서 signOut 후 DomainError.notTrainer (NFR-02, LoginView.swift:226-249 흐름 이식)
  func signIn(email: String, password: String) async throws -> TrainerSession
  /// 미동기 항목이 있고 discardUnsynced == false면 DomainError.remote(.failedPrecondition, "auth.unsyncedItems")를 던진다.
  /// 성공 시 Firebase signOut, 모든 리스너 해제, Firestore 캐시·SwiftData·로컬 파일 삭제(NFR-08)
  func signOut(discardUnsynced: Bool) async throws
  /// 토큰 갱신마다 claim을 다시 확인. claim 회수 시 nil을 내보낸다.
  func sessionStream() -> AsyncStream<TrainerSession?>
}
```

| 오류 | 조건 | UI |
|---|---|---|
| `.notTrainer` | claim 없음 | 로그인 화면 오류, 입력 유지 |
| `.remote(.unauthenticated, nil)` | 비밀번호 오류 등 | Firebase Auth 오류 문구 매핑(07 문서) |
| `.remote(.failedPrecondition, "auth.unsyncedItems")` | 미동기 n건 | TR-15 경고 대화(NFR-08) |

### 8.4 `MemberDirectory`

```swift
public struct Member: Identifiable, Equatable, Sendable {
  public let id: MemberUID; public let displayName: String; public let initials: String   // 로컬 이니셜(NFR-11)
  public let consent: ConsentState?; public let linkedAt: Date?
}
public struct PendingMember: Identifiable, Equatable, Sendable {
  public let id: PendingMemberID; public let displayName: String; public let sex: Sex; public let birthYear: Int
  public let status: PendingStatus; public let consent: ConsentState?; public let createdAt: Date
}
public struct PendingMemberDraft: Sendable { public var displayName: String; public var sex: Sex; public var birthYear: Int; public var ageConfirmed14: Bool }
public struct PendingMemberPatch: Sendable { public var displayName: String?; public var sex: Sex?; public var birthYear: Int?; public var heightCm: Double?; public var heightMeasuredAt: Date? }

public protocol MemberDirectory: Sendable {
  /// trainers/{uid} 리스너 → memberIds를 10개씩 나눠 users 문서 ID `in` 조회(F-LINK-03.2, FirebaseTrainerRepository.swift:158-220 이식)
  func observeAssignedMembers() -> AsyncThrowingStream<[Member], Error>
  /// pendingMembers where trainerId == uid && status == 'pending' orderBy createdAt desc (인덱스 §9.6)
  func observePendingMembers() -> AsyncThrowingStream<[PendingMember], Error>
  /// 로컬 검증: displayName 1~40자, birthYear ≤ 현재연도 − 14(AC-LINK-01.6), ageConfirmed14 == true. 연락처 필드 없음.
  /// 쓰기: Outbox createDocument(pendingMembers/{id}). 온라인 확인 전에는 로컬 목록에 'localSaved'로 표시
  func createPendingMember(_ draft: PendingMemberDraft) throws -> PendingMemberID
  /// heightCm는 동의 ② 확인 뒤에만(R-30). 아니면 DomainError.consentRequired(.healthData)
  func updatePendingMember(_ id: PendingMemberID, _ patch: PendingMemberPatch) throws
  /// status pending → cancelled (규칙 허용 전이). 파기는 서버(§6.8 B2)
  func cancelPendingMember(_ id: PendingMemberID) throws
}
```

- 스트림 오류(권한 거부, 인덱스 누락)는 스트림 종료로 전달하고, 화면은 '불러오기 실패, 다시 시도'를 보인다(§10).

### 8.5 `SoapNoteStore`

```swift
public enum LiveSessionMode: Equatable, Sendable { case new; case continueDraft(NoteID) }
public struct SoapReviewInput: Equatable, Sendable {
  public var chiefComplaint: String?; public var painNrs: Int?; public var painRegions: [RegionCode]
  public var objectiveRows: [ObjectiveRowInput]            // metricCode enum, value, unit, side, joint/motion/activeOrPassive, muscleGroup, note
  public var exerciseAssessment: ExerciseAssessmentInput?  // summary, observations
  public var plan: PlanInput                               // nextSession, homeExercise
  public var memberNote: String?                           // ≤200자(F-SOAP-02.10)
}
public struct FinalizeResult: Equatable, Sendable {
  public let lock: NoteLock                                // .pendingFinalize('확정 대기') — 서버 확인 전 로컬 잠금
  public let excludedIncompleteRows: [Int]                 // §6.4.4 #6 자동 제외 행
  public let termWarnings: [TermViolation]                 // §6.4.4 #7 비차단 경고
}
public enum NoteLock: String, Codable, Sendable { case editable, pendingFinalize, finalized }

@MainActor
public protocol SoapNoteStore: AnyObject {
  /// 같은 memberKey·같은 날 draft가 있고 mode == .new면 두 번째 문서를 만든다(AC-SOAP-01.6, NFR-07). 자동 ID
  func startLiveSession(member: MemberKey, sessionDate: Date, mode: LiveSessionMode) throws -> NoteID
  /// 변경 즉시 SwiftData 저장(localSaved). ②가 서버에서 확인되지 않았으면 awaitingConsent(F-PRIV-03.7)
  func updateLive(_ id: NoteID, quickNote: String?, ink: InkRevisionRef?, painNrs: Int?, painRegions: [RegionCode]?) throws
  /// M-01 종료 시점. 확인창 없음(AC-IA-03). 반환값은 localSaved가 확인된 시각
  func markRecordComplete(_ id: NoteID) throws -> Date
  /// O 행 검증: metricCode는 카탈로그 enum, romDeg는 joint·motion·activeOrPassive 필수, mmtGrade는 0~5 정수(AC-SOAP-02.2~02.6)
  func saveReview(_ id: NoteID, _ review: SoapReviewInput) throws
  /// §6.4.4 #1~#4 미충족이면 DomainError.validation(.finalizeRequirement). 충족 시 로컬 잠금 + Outbox finalize(⑤)
  func finalize(_ id: NoteID) throws -> FinalizeResult
  /// 부모가 finalized일 때만. reason 1~500자, text ≤4,000자(PRD §9.3 addenda). 온라인 반영 전 localSaved
  func addAddendum(_ id: NoteID, reason: AddendumReason, text: String, changedFields: [String], previousValues: [String: JSONValue]) throws
  /// draft만. soapInk/{noteId}/ 개정본 삭제를 같은 Outbox 항목으로(AC-SOAP-04.4)
  func deleteDraft(_ id: NoteID) throws
  /// 새 자동 ID, O 값은 비우고 '지난 값'만 참조로 보인다(F-SOAP-07.2)
  func continueFromPrevious(member: MemberKey) throws -> NoteID
  /// trainerId == uid && memberUid(또는 pendingMemberId) == key, sessionDate desc(인덱스 §9.6)
  func observeNotes(member: MemberKey) -> AsyncThrowingStream<[SoapNoteSummary], Error>
  /// P1b(F-SOAP-03.1~03.2): 같은 날 기본 선택 + 종류별 최근 1건. lidarBeta일 때만 bodyScans·observedSection
  func loadObjectiveCandidates(member: MemberKey, sessionDate: Date) async throws -> ObjectiveCandidates
  /// P1b: refs와 snapshots 저장. P3 전 changeStatus = .pendingPolicy (F-SOAP-03.4)
  func applySnapshots(_ id: NoteID, refs: [RecordRef]) throws
}
public enum AddendumReason: String, Codable, Sendable { case trainerCorrection, subjectRectificationRequest }   // '정보주체 정정 요구'(F-SOAP-04.4)
```

로컬 → 원격 투영(SyncEngine이 만드는 Firestore 쓰기)

| 로컬 동작 | Outbox 단계 | Firestore 쓰기 | 규칙 근거 |
|---|---|---|---|
| `startLiveSession` 첫 저장 | ② | `soap_notes/{id}` create: `schemaVersion: 2`, `trainerId = authorUid = uid`, 회원 키, `sessionDate`, `status: 'draft'`, `legalNature: 'coachingRecord'`, `memberId`(가입 회원만, = memberUid), `createdAt = updatedAt = serverTimestamp` | PRD §9.4 soap create |
| 편집 | ② | update: 화이트리스트 키 + `updatedAt = serverTimestamp`. `createdAt`은 다시 쓰지 않는다(AC-SOAP-04.6) | soap update |
| 필기 저장 | ③→④ | `soapInk/{id}/{rev}.drawing`, `.png` 업로드 → `inkPath`, `inkRevision` update → 이전 개정본 삭제 | §9.5 |
| `finalize` | ⑤ | update: `status: 'finalized'`, `finalizedAt = serverTimestamp`, `updatedAt`(오프라인 확정도 동기화 시점 서버 시각) | soap update 전환 |
| `addAddendum` | ② | `soap_notes/{id}/addenda/{autoId}` create: `authorUid`, `createdAt = serverTimestamp`, `reason`, `text`, `changedFields`, `previousValues` | addenda create |
| `deleteDraft` | ② | `soapInk/{id}/` 삭제 → 문서 delete | soap delete(draft) |

### 8.6 SyncEngine / Outbox

```swift
// TrainerDomain/Remote.swift — Firebase에 의존하지 않는 원격 경계
public enum RemoteValue: Codable, Equatable, Sendable {           // Firestore 값의 중립 표현
  case string(String), int(Int64), double(Double), bool(Bool), null
  case timestamp(Date), serverTimestamp, deleteField
  case array([RemoteValue]), map([String: RemoteValue])
}
public typealias RemoteFields = [String: RemoteValue]
public struct DocumentPath: Hashable, Codable, Sendable { public let collection: String; public let id: String; public let parent: DocumentPathParent? }
public struct WriteAck: Equatable, Sendable { public let serverCommitted: Bool; public let hasPendingWrites: Bool }
public struct UploadReceipt: Equatable, Sendable { public let path: String; public let size: Int64; public let md5Base64: String; public let sha256Hex: String }

public protocol RemoteWriter: Sendable {
  /// 서버 커밋 확인까지 기다린다(Firestore completion). 재시도 시 서버에 같은 문서가 이미 있으면
  /// 내용 비교 후 WriteAck(serverCommitted: true)를 돌려준다(create 멱등, ADR-002)
  func create(_ path: DocumentPath, fields: RemoteFields) async throws -> WriteAck
  func update(_ path: DocumentPath, fields: RemoteFields) async throws -> WriteAck
  func delete(_ path: DocumentPath) async throws -> WriteAck
}
public protocol BinaryUploader: Sendable {
  /// putFile + customMetadata["sha256"]. 업로드 뒤 메타데이터를 다시 읽어 size와 md5Hash를 로컬 값과 대조한다.
  /// 불일치면 DomainError.remote(.internalError, "upload.integrityMismatch")(재시도 대상). getDownloadURL은 호출하지 않는다.
  func upload(localURL: URL, path: String, contentType: String, sha256: String) async throws -> UploadReceipt
  func deletePrefix(_ prefix: String) async throws
  /// 트레이너 전용 바이트 다운로드 + 로컬 캐시(NFR-17). 서명 URL 사용 금지
  func download(path: String, maxSize: Int64) async throws -> URL
}
public protocol CallableClient: Sendable {
  /// region asia-northeast3. 오류는 DomainError.remote(code, details.messageKey)로 변환
  func call<Request: Encodable & Sendable, Response: Decodable & Sendable>(_ name: CallableName, _ request: Request) async throws -> Response
}
public enum CallableName: String, CaseIterable, Sendable {
  case recordConsent, logRecordAccess, submitRightsRequest                      // P1a
  case issueInviteCode, createMemberSummary, revokeMemberSummary, linkMemberAlias // P2
  case evaluateChange                                                           // P3
}
```

도메인 타입 정본은 V1-04 §10.2, SwiftData 엔티티·상태 값(`queued|inFlight|acked|failed|blocked`)은 V1-05 §12.2다. 이 절은 SyncEngine 경계만 보인다.

```swift
// SyncEngine/Outbox.swift
public enum OutboxStage: Int, Codable, Comparable, Sendable {       // NFR-05 순서
  case memberKey = 0, consent = 1, document = 2, upload = 3, pathRecord = 4, finalize = 5
}
public enum OutboxOperation: Codable, Equatable, Sendable {
  case callConsent(RecordConsentRequest)                            // ① callable
  case createDocument(DocumentPath, RemoteFields)                   // ⓪ 대기 회원 create, ②
  case updateDocument(DocumentPath, RemoteFields)                   // ② 편집
  case deleteDocument(DocumentPath, storagePrefix: String?)         // ② 삭제(prefix 먼저)
  case uploadBinary(localBinaryID: UUID, path: String, contentType: String, sha256: String)   // ③
  case deleteBinary(remotePath: String)                             // ③ 철회 파기 등 원격 파일 삭제
  case recordBinaryPath(DocumentPath, fields: RemoteFields)         // ④ 업로드 확인 뒤 경로 기록
  case finalize(DocumentPath)                                       // ⑤
  case callFunction(CallableName, RemoteFields)                     // 동의 외 callable
}
public struct OutboxItem: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID                  // 로컬 식별자
  public let requestId: UUID           // 서버 멱등 키(§3.7). 재시도에서 바뀌지 않음
  public let memberKey: MemberKey
  public let sequence: Int64           // 회원별 단조 증가(같은 stage 안 순서)
  public let entityRef: LocalEntityRef // syncState를 갱신할 로컬 항목
  public let stage: OutboxStage
  public let operation: OutboxOperation
  public let dependsOn: [UUID]         // 예: recordBinaryPath → uploadBinary
  public var attempts: Int
  public var nextAttemptAt: Date
  public var lastFailure: SyncFailure?
  public let createdAt: Date
}
public struct SyncFailure: Codable, Equatable, Sendable {
  public let code: RemoteErrorCode; public let key: MessageKey?; public let terminal: Bool; public let at: Date
}

public protocol OutboxProcessing: AnyObject, Sendable {
  func enqueue(_ item: OutboxItem) throws
  func start()                                   // 앱 시작·포그라운드·연결 복구 시. 재시작 후 이어서 처리(NFR-05)
  func stop()                                    // 로그아웃
  func syncState(for entity: LocalEntityRef) -> AsyncStream<SyncState>
  func pendingCount() -> AsyncStream<Int>        // 전역 표시줄(NFR-06, M-G3)
  func retry(_ item: UUID)
  func retryAll()
}
```

처리 규칙(구현 지시)

1. **회원별 순서.** 같은 `memberKey`의 항목은 `(stage, createdAt)` 순이다. 앞선 항목이 끝나지 않으면 뒤 항목을 시작하지 않는다. `.consent` 항목이 `synced`가 아니면 그 회원의 나머지 항목은 모두 `awaitingConsent`다(AC-PRIV-03.3). 회원 사이에는 병렬(최대 2) 처리한다.
2. **부모 먼저.** `.uploadBinary`는 같은 문서의 `.createDocument`가 `serverCommitted`일 때만 시작한다(PRD §9.5 '부모 문서 서버 반영 뒤 업로드').
3. **백오프.** 재시도 가능 오류(§3.6)는 `min(2^attempts × 2초, 5분)` + 0~1초 지터. 연속 5회 실패하면 `syncFailed`(사유 표시, 재시도 버튼)로 바꾸고 자동 재시도를 멈춘다.
4. **영구 오류.** `permission-denied`, `invalid-argument`, `failed-precondition`(아래 예외 제외), `not-found`, `already-exists`는 즉시 `syncFailed`다. 로컬 원본은 지우지 않는다(C-05). 확정 대기 노트는 잠금을 풀어 다시 편집할 수 있게 한다(F-SOAP-04.2).
5. **오프라인.** 연결이 없으면 항목을 보내지 않는다(Firestore 대기 쓰기가 쌓이지 않게). 보낸 뒤 30초 안에 커밋 확인이 없으면 `syncing`을 유지한 채 같은 작업을 계속 기다리고, 새로 보내지 않는다. 앱 재시작 뒤에는 `RemoteWriter.create`의 존재 확인으로 중복을 막는다(NFR-04 '중복 0건').
6. **synced 판정.** 문서의 `WriteAck.serverCommitted && !hasPendingWrites`이고, 그 엔티티의 모든 업로드 영수증이 대조를 통과했을 때만 `synced`(PRD §6.0.3).
7. **로컬 파일 정리.** 업로드 확인 7일 뒤 로컬 원본 삭제, `awaitingConsent`가 7일을 넘으면 draft 파기(NFR-17, AS-32).

### 8.7 원격 오류 → syncState·UI 대응

| 원격 결과 | syncState | 노트 잠금 | UI 문구 키(예) |
|---|---|---|---|
| 성공(커밋 확인 + 업로드 대조) | `synced` | 확정이면 `finalized` | `sync.synced` '동기화됨' |
| 진행 중·대기 | `syncing` | 유지 | `sync.syncing` '동기화 중' |
| `.consent` 미확인 | `awaitingConsent` | 유지 | `sync.awaitingConsent` '동의 확인 대기' |
| `failed-precondition / consent.healthDataRequired` 또는 규칙 거부 중 동의 사유 | `syncFailed` | 해제 | `consent.healthDataRequired` |
| 규칙 `permission-denied`(담당 해제 등) | `syncFailed` | 해제 | `member.notAssigned` |
| `unavailable`·`deadline-exceeded`·`aborted`·`internal` 5회 미만 | `syncing` | 유지 | — |
| 위 오류 5회 이상 | `syncFailed` | 해제 | `sync.failedRetry` |
| `unauthenticated` | 변경 없음, 세션 잠금 | 유지 | 로그인 화면 |

'저장됨' 단독 문구는 어느 상태에도 쓰지 않는다(PRD §6.0.3).

### 8.8 `MeasurementStore`

```swift
public struct BodyCompositionDraft: Equatable, Sendable {
  public var member: MemberKey
  public var deviceModel: String                  // 1~64자, 목록 + 기본값
  public var measuredAt: Date                     // ≤ now + 5분
  public var fasting: Fasting                     // .yes | .no (UI 필수 선택). .unknown은 저장 가능하나 UI 기본 아님
  public var values: [BodyCompositionKey: Double] // 빈칸 = 키 없음(0 저장 금지, bodyFatPercent만 0 허용)
  public var trainerHeightCm: Double?             // 있을 때만 derived.bmi(F-BC-01.3). users.height 미사용
}
public protocol MeasurementStore: AnyObject {
  /// 검증: values 1개 이상, 키별 범위(F-BC-03), timeOfDayBand 자동, ② 없으면 DomainError.consentRequired(.healthData)
  @MainActor func saveBodyComposition(_ draft: BodyCompositionDraft) throws -> RecordID
  /// reportPhotoPath가 null일 때 1회. Outbox ③→④
  @MainActor func attachReportPhoto(_ id: RecordID, image: CGImage) throws
  /// 기존 active → voided(voidReason ≤200자) + 값이 채워진 새 draft 반환(F-BC-03.5)
  @MainActor func voidAndPrefill(_ id: RecordID, reason: String) throws -> BodyCompositionDraft
  /// trials 1~3개(차이 ≥ 1cm일 때만 3번째), 빈 값은 문서 미생성, custom은 landmarkNote 필수(R-26), side 규칙(부록 A.1)
  @MainActor func saveTapeRow(member: MemberKey, metricCode: MetricCode, side: Side, trials: [Double], protocolId: ProtocolID,
                              landmarkNote: String?, conditionsNote: String?, measuredAt: Date) throws -> [MeasurementID]
  @MainActor func voidMeasurement(_ id: MeasurementID, reason: String) throws
  /// trainerId == uid, memberUid == key, metricCode(둘레) measuredAt desc. seriesBreak는 TrainerDomain 공통 규칙으로 분할
  func observeSeries(member: MemberKey, metricCode: MetricCode, sourceGrade: SourceGrade) -> AsyncThrowingStream<[SeriesSegment], Error>
}
```

### 8.9 `AssessmentStore` (P1b)

```swift
public protocol AssessmentStore: AnyObject {
  /// ②③ 서버 확인 필요(오프라인 캡처 동의로는 촬영 불가, F-PRIV-03.7). 아니면 DomainError.consentRequired
  @MainActor func createDraft(member: MemberKey, stationProfile: StationProfileID, captureConditions: CaptureConditions) throws -> AssessmentID
  /// EXIF·GPS 제거, 얼굴 가림 썸네일 생성 후 로컬 저장. 업로드는 Outbox ③
  @MainActor func attachPhoto(_ id: AssessmentID, view: PostureView, image: CGImage, levelDeg: Double, pitchDeg: Double) throws
  func suggestLandmarks(_ id: AssessmentID, view: PostureView) async throws -> [LandmarkSuggestion]   // PostureVision
  @MainActor func setLandmark(_ id: AssessmentID, view: PostureView, code: LandmarkCode, point: NormalizedPoint, origin: LandmarkOrigin) throws
  @MainActor func computeMetrics(_ id: AssessmentID, options: MetricOptions) throws -> [PostureMetric]  // PostureMath
  /// 필수 랜드마크가 모두 confirmed가 아니면 DomainError.validation (AC-ASM-04.1)
  @MainActor func confirm(_ id: AssessmentID) throws
  @MainActor func supersede(_ id: AssessmentID) throws -> AssessmentID
  @MainActor func setBaseline(_ id: AssessmentID) throws
  /// ⑤ 필요(R-16). 아니면 DomainError.consentRequired(.research)
  @MainActor func tagRetest(_ id: AssessmentID, groupId: RetestGroupID) throws
}
```

### 8.10 `ConsentService`

```swift
public struct ConsentSelection: Codable, Equatable, Sendable { public let consentType: ConsentType; public let action: ConsentAction; public let documentVersion: String }
public protocol ConsentService: AnyObject {
  /// consentDocumentVersions where status == 'published'. 오프라인이면 마지막 캐시(버전 ID 포함)
  func publishedDocuments() async throws -> [ConsentDocumentVersion]
  /// memberConsentStates/{memberKey} 리스너. 로컬 미확인 캡처가 있으면 그 상태를 겹쳐 awaitingConsent 표시
  func observeState(member: MemberKey) -> AsyncThrowingStream<ConsentState, Error>
  /// 로컬 캡처를 저장하고 Outbox 첫 항목(.consent)으로 넣는다. LocalConsentCapture.captureId(= clientCaptureId)는 여기서 한 번 생성(§6.2.5)
  @MainActor func captureInPerson(member: MemberKey, selections: [ConsentSelection], signaturePNG: Data,
                                  capturedAt: Date) throws -> CaptureID
  /// 현장 철회도 같은 경로(F-PRIV-03.3). 온라인이면 즉시 전송, 아니면 Outbox
  @MainActor func withdraw(member: MemberKey, type: ConsentType, documentVersion: String, signaturePNG: Data) throws -> CaptureID
}
```

### 8.11 조회·설정·감사·공유 프로토콜

```swift
public struct TimelinePage: Sendable { public let items: [TimelineItem]; public let cursor: TimelineCursor? }   // cursor nil = 마지막
public enum TimelineKind: String, CaseIterable, Sendable { case soap, bodyComposition, circumference, posture, bodyScan }
public protocol TimelineQueries: Sendable {
  /// TR-03(F-VIZ-05.1~05.7). 종류별 쿼리(§10)를 측정 시각 내림차순으로 병합, 25건 커서 페이지.
  /// voided는 includeVoided == false면 제외. 어느 한 종류라도 실패하면 그 종류만 실패로 표시할 수 있게 부분 결과와 오류를 함께 준다.
  func page(member: MemberKey, kinds: Set<TimelineKind>, includeVoided: Bool, after: TimelineCursor?) async -> (TimelinePage, [TimelineKind: DomainError])
}
public protocol RecordQueries: Sendable {
  /// 단건 조회(TR-05 원본 링크, '원본 변경됨' 판정). trainerId != uid면 권한 거부가 그대로 전달된다
  func posture(_ id: AssessmentID) async throws -> PostureAssessment
  func bodyComposition(_ id: RecordID) async throws -> BodyCompositionRecord
  func circumference(_ id: MeasurementID) async throws -> CircumferenceMeasurement
}

public protocol FeatureFlagReader: Sendable {
  /// appConfig/features. 문서·키가 없으면 false(ADR-010). DEBUG 빌드에서만 로컬 오버라이드 병합
  func observeFlags() -> AsyncStream<FeatureFlags>
}
public protocol PolicyReader: Sendable {
  /// insightPolicyVersions where kind == 'bodyChange' && status == 'approved' && active == true. P3 전에는 nil
  func observeActiveBodyChangePolicy() -> AsyncStream<BodyChangePolicy?>
}
public protocol RecordAccessLogger: Sendable {
  /// TR-03 onAppear마다 1회. 실패는 로그만(화면 차단 없음, DF-115)
  func logTR03Access(member: MemberKey) async
}
public protocol RightsRequestService: Sendable {
  func submit(member: MemberUID, type: RightsRequestType) async throws -> (requestId: String, dueAt: Date)   // 온라인 전용
}
public protocol MemberSummaryService: Sendable {           // P2, 온라인 전용(오프라인이면 .onlineRequired)
  func share(_ request: CreateMemberSummaryRequest) async throws -> CreateMemberSummaryResponse
  func revoke(_ summaryId: SummaryID) async throws
  /// TR-06 미리보기에서 서버와 같은 JSON으로 검사(F-SOAP-05.6). 네트워크 없음
  func localTermCheck(title: String, body: String, nextPlan: String) -> (violations: [TermViolation], warnings: [TermViolation])
}
public protocol InviteService: Sendable {                   // P2
  func issue(for pending: PendingMemberID) async throws -> (code: String, expiresAt: Date)   // 원문은 화면에만, 저장·로그 금지
}
public protocol AliasLinker: Sendable {                     // P2
  func link(subjectCode: String, to member: MemberUID) async throws -> String
}
public protocol ChangeEvaluator: Sendable {                 // P3, 오프라인이면 .onlineRequired
  func evaluate(_ request: EvaluateChangeRequest) async throws -> EvaluateChangeResponse
}
```

### 8.12 callable DTO(Codable)

JSON 키는 §6의 스키마와 같다. `Date`는 ISO 8601 문자열로 인코딩한다(`JSONEncoder.dateEncodingStrategy = .iso8601` + 밀리초).

```swift
public struct RecordConsentRequest: Codable, Equatable, Sendable {
  public let clientCaptureId: String                  // LocalConsentCapture.captureId(UUID 문자열). 재시도에서 불변(§6.2.5)
  public let memberKey: MemberKeyDTO                  // {"memberUid": …} 또는 {"pendingMemberId": …}
  public let channel: String                          // "trainerDeviceInPerson"
  public let selections: [ConsentSelection]
  public let signaturePngBase64: String?
  public let capturedAt: Date?
  public let reconfirmOf: String?                     // 트레이너 앱은 항상 nil
}
public struct RecordConsentResponse: Codable, Equatable, Sendable {
  public let ok: Bool; public let replayed: Bool; public let recordIds: [String]
  public let state: ConsentState; public let signaturePath: String?
}
public struct LogRecordAccessRequest: Codable, Sendable { public let memberKey: MemberKeyDTO; public let surface: String }   // "TR-03"
public struct SubmitRightsRequestRequest: Codable, Sendable { public let requestId: UUID; public let memberUid: String; public let type: RightsRequestType; public let channel: String }  // "trainer"
public struct SubmitRightsRequestResponse: Codable, Sendable { public let ok: Bool; public let replayed: Bool; public let requestId: String; public let dueAt: Date }

public struct CreateMemberSummaryRequest: Codable, Equatable, Sendable {
  public struct Source: Codable, Equatable, Sendable { public let collection: String; public let id: String }
  public struct Highlight: Codable, Equatable, Sendable { public let refId: String; public let metricCode: MetricCode; public let side: Side }
  public let requestId: UUID; public let sourceType: String; public let sources: [Source]
  public let title: String; public let body: String; public let nextPlan: String
  public let highlights: [Highlight]; public let photoPaths: [String]?
}
public struct CreateMemberSummaryResponse: Codable, Sendable {
  public let ok: Bool; public let replayed: Bool; public let summaryId: String; public let revokedSummaryId: String?; public let warnings: [TermViolation]
}
public struct IssueInviteCodeResponse: Codable, Sendable { public let ok: Bool; public let code: String; public let expiresAt: Date; public let revokedCount: Int }
public struct LinkMemberAliasRequest: Codable, Sendable { public let system: String; public let externalId: String; public let memberUid: String }
public struct EvaluateChangeRequest: Codable, Sendable {
  public let memberUid: String; public let metricCode: MetricCode; public let sourceGrade: SourceGrade
  public let side: Side?; public let currentRefId: String; public let comparisonRefId: String?
}
public struct EvaluateChangeResponse: Codable, Sendable {
  public let ok: Bool; public let changeStatus: ChangeStatus; public let reasonCode: ReasonCode?; public let delta: Double?
  public let mdcSource: MdcSource?; public let policyVersion: String?; public let sideChanged: Bool?
  public let comparison: Comparison?
  public struct Comparison: Codable, Sendable { public let refId: String; public let measuredAt: Date; public let value: Double }
}
```

`CallableClient` 구현(FirebaseData)의 오류 변환

```swift
// FirebaseData/FirebaseCallableClient.swift (요지)
catch let error as NSError where error.domain == FunctionsErrorDomain {
  let code = FunctionsErrorCode(rawValue: error.code)                       // Firebase 코드
  let details = error.userInfo[FunctionsErrorDetailsKey] as? [String: Any]
  let key = (details?["messageKey"] as? String).map(MessageKey.init(rawValue:))
  throw DomainError.remote(code: RemoteErrorCode(firebase: code), key: key)
}
```

### 8.13 테스트 대역(fakes)

- `TrainerDomain`에 `FakeRemoteWriter`, `FakeBinaryUploader`, `FakeCallableClient`를 테스트 전용 타깃으로 둔다. 기능: 호출 순서 기록, 지정 호출에 오류 주입(`permission-denied`, `unavailable`), 지연 주입, 서버 존재 상태 시뮬레이션.
- SyncEngine 단위 테스트(`swift test`, macOS)는 가짜 원격으로 [§13](#13-테스트-케이스-총괄)의 TC-06-SYN-*을 검증한다. 에뮬레이터 연동(`IntegrationTests`)은 같은 시나리오를 실제 규칙으로 다시 돌린다(DF-107).

---

## 9. 회원 앱 Dart 계약

- 배치: `lib/models/`, `lib/services/`(PRD §10.5, 기존 구조 유지). callable은 기존 패턴대로 `FirebaseFunctions.instanceFor(region: 'asia-northeast3')`(dfet:lib/services/community_service.dart:21).
- 쿼리 오류를 빈 목록으로 삼키지 않는다. 스트림 오류를 그대로 흘려 화면이 '불러오기 실패'를 보이게 한다(PRD §9.6, 반례 firestore_service.dart:650-653).

### 9.1 기능 플래그 확장(P0, DF-027)

```dart
// lib/services/clinical_repository.dart — 기존 AppFeatureFlags(3키, :4-33)를 8키로 확장
class AppFeatureFlags {
  final bool gut, blood, insights;
  final bool bodyAssessment, bodyComposition, soapV2, memberShare, lidarBeta;
  const AppFeatureFlags({required this.gut, required this.blood, required this.insights,
    this.bodyAssessment = false, this.bodyComposition = false, this.soapV2 = false,
    this.memberShare = false, this.lidarBeta = false});
  factory AppFeatureFlags.fromMap(Map<String, dynamic>? map) {
    bool read(String k) => map?[k] as bool? ?? false;           // 없으면 false (ADR-010)
    return AppFeatureFlags(gut: read('gut'), blood: read('blood'), insights: read('insights'),
      bodyAssessment: read('bodyAssessment'), bodyComposition: read('bodyComposition'),
      soapV2: read('soapV2'), memberShare: read('memberShare'), lidarBeta: read('lidarBeta'));
  }
  /// 리포트 탭 '체형·신체조성' 세그먼트 노출 조건(F-VIZ-06.8)
  bool get showsBodyReport => memberShare && (bodyAssessment || bodyComposition);
}
```

- 키 문자열은 `lib/contracts/generated/feature_flag_keys.dart`(생성물) 상수를 쓴다. `AppFeatureFlags.enabled()`와 `disabled()` 생성자도 8키로 맞춘다.

### 9.2 예외

```dart
// lib/services/dfet_functions_exception.dart
class DfetFunctionsException implements Exception {
  DfetFunctionsException({required this.code, required this.messageKey, this.details = const {}});
  final String code;          // §3.6 callable code
  final String messageKey;    // details['messageKey'] ?? 'common.<code>'
  final Map<String, dynamic> details;
  bool get retryable => const {'aborted', 'resource-exhausted', 'internal', 'unavailable', 'deadline-exceeded'}.contains(code);
  factory DfetFunctionsException.from(FirebaseFunctionsException e) { /* details 맵에서 messageKey 추출 */ }
}
```

### 9.3 저장소

```dart
// lib/models/member_summary.dart — memberSummaries 문서(PRD §9.2) 읽기 모델
class MemberSummary {
  final String id, memberUid, sourceType, title, body, nextPlan, status;   // status: shared | revoked
  final List<SummaryHighlight> highlights;
  final List<String> sharedPhotoPaths;
  final String? policyVersion;
  final DateTime sharedAt; final DateTime? revokedAt;
  factory MemberSummary.fromMap(Map<String, dynamic> map, String id);   // sourceGrade 없는 highlight는 버리고 로그(C-01)
}

// lib/services/member_summary_repository.dart (P2, DF-315·DF-316)
class MemberSummaryRepository {
  MemberSummaryRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions});
  /// where memberUid == uid orderBy sharedAt desc (인덱스 memberUid, sharedAt↓). 오류는 스트림 오류로 전달
  Stream<List<MemberSummary>> watchSummaries(String uid);
  /// revoked면 null이 아니라 status == 'revoked' 객체(화면이 '공유가 해제된 기록'을 안내)
  Future<MemberSummary?> getSummary(String id);
  /// callable getSharedPhotoUrl. 15분 만료 URL. 캐시하지 않는다
  Future<Uri> getSharedPhotoUrl(String summaryId, String path);
  /// callable markSummaryViewed(ASM-06-04 승인 시). 실패는 무시하고 로그
  Future<void> markViewed(String summaryId);
}

// lib/services/consent_repository.dart (P2, DF-307·DF-308)
class ConsentRepository {
  Stream<ConsentState> watchState(String uid);                   // memberConsentStates/{uid}
  Stream<List<ConsentRecord>> watchRecords(String uid);          // consentRecords where subjectUid == uid orderBy recordedAt desc
  Stream<List<ConsentDocumentVersion>> watchPublishedDocuments();// consentDocumentVersions where status == 'published'
  /// callable recordConsent(channel: memberApp). clientCaptureId는 호출마다 Uuid().v4()로 만들고 재시도에 재사용(§6.2.5)
  Future<ConsentState> recordConsent(List<ConsentSelection> selections, {required String clientCaptureId});
  Future<ConsentState> reconfirm(ConsentRecord inPersonRecord, {required String clientCaptureId});
}

// lib/services/invite_repository.dart (P2, DF-306)
class InviteRepository {
  /// 입력 정규화는 서버가 한다. ageConfirmed14는 true만 허용
  Future<RedeemResult> redeem(String code, {required bool ageConfirmed14});   // RedeemResult {status: promoted|resumed, trainerId}
}

// lib/services/rights_request_repository.dart (P2, DF-307)
class RightsRequestRepository {
  Future<({String requestId, DateTime dueAt})> submit(RightsRequestType type, {required String requestId});
  Stream<List<RightsRequest>> watch(String uid);                  // rightsRequests where memberUid == uid
}

// lib/models/soap_note_v2.dart (P0, DF-007) — 교차 픽스처 테스트와 레거시 읽기용
class SoapNoteV2Codec {
  static SoapNoteV2 fromMap(Map<String, dynamic> map, String id);   // 알 수 없는 metricCode는 원문 보존 + 'uninterpretable'
  static Map<String, dynamic> toMap(SoapNoteV2 note);               // 서버 타임스탬프 필드는 쓰지 않음(읽기 전용 왕복 테스트)
}
```

| 저장소 메서드 | 오류 | 화면 표시 |
|---|---|---|
| `watchSummaries` | `FirebaseException(permission-denied)` | '불러오기 실패, 다시 시도' |
| `redeem` | `invite.invalidOrExpired` | '유효하지 않거나 만료된 코드' |
| `redeem` | `invite.conflict` | 센터 문의 안내 |
| `recordConsent` | `consent.documentNotPublished` | 최신 동의 문서 다시 불러오기 |
| `getSharedPhotoUrl` | `summary.notShared` | 사진 영역 미렌더(F-VIZ-06) |

---

## 10. Firestore 쿼리 카탈로그

모든 목록 쿼리는 규칙이 증명할 수 있는 필터를 포함한다(PRD §9.6). 페이지 크기는 목록 25건, 추이 100건(제안값). 인덱스 정의는 [05_DATA_MODEL_AND_RULES.md](05_DATA_MODEL_AND_RULES.md)(DF-024).

| 화면 | 쿼리 | 인덱스(§9.6) | 오류 표시 | 단계 |
|---|---|---|---|---|
| TR-01 오늘 | `soap_notes where trainerId == uid && sessionDate >= 오늘 00:00 orderBy sessionDate desc` + 로컬 SwiftData | trainerId, sessionDate↓ | 보드 상단 배너 '불러오기 실패' | P1a |
| TR-02 회원 | `trainers/{uid}` 리스너 → `users where __name__ in [≤10]` 청크 | 자동 | 목록 대신 오류 상태 | P0 |
| TR-02 대기 회원 | `pendingMembers where trainerId == uid && status == 'pending' orderBy createdAt desc` | trainerId, status, createdAt↓ | 같음 | P1a |
| TR-03 타임라인(SOAP) | `soap_notes where trainerId == uid && memberUid == m orderBy sessionDate desc limit 25` (대기 회원은 `pendingMemberId == p`) | trainerId, memberUid, sessionDate↓ | 섹션별 '불러오기 실패'와 재시도 | P1a |
| TR-03 타임라인(신체조성) | `bodyCompositionRecords where trainerId == uid && memberUid == m orderBy measuredAt desc limit 25` | trainerId, memberUid, measuredAt↓ | 같음 | P1a |
| TR-03 타임라인(체형) | `postureAssessments where trainerId == uid && memberUid == m orderBy capturedAt desc limit 25` | trainerId, memberUid, capturedAt↓ | 같음 | P1b |
| TR-05 addenda | `soap_notes/{id}/addenda orderBy createdAt` | 자동 | 원문 아래 '추가 기록을 불러오지 못함' | P1a |
| TR-10·TR-12 추이 | `circumferenceMeasurements where trainerId == uid && memberUid == m && metricCode == c orderBy measuredAt desc limit 100` | trainerId, memberUid, metricCode, measuredAt↓ | 차트 자리 오류 상태 | P1a |
| TR-13 스캔 | `bodyScans where trainerId == uid && memberUid == m orderBy takenAt desc` | trainerId, memberUid, takenAt↓ | 같음 | P2 |
| TR-14 동의 이력 | `consentRecords where pendingMemberId == p orderBy recordedAt desc` / 가입 회원 `subjectUid == m` | pendingMemberId·subjectUid, recordedAt↓ | 이력 영역 오류 | P1a |
| TR-14 문서 | `consentDocumentVersions where status == 'published'` | 자동 | 동의 진행 차단 + 재시도 | P1a |
| 설정·정책 | `appConfig/features` 문서, `insightPolicyVersions where kind == 'bodyChange' && status == 'approved' && active == true` | kind, status, active, publishedAt↓ | 플래그 오류 시 모두 false로 간주 | P0, P3 |
| MB-01·MB-03 | `memberSummaries where memberUid == uid orderBy sharedAt desc` | memberUid, sharedAt↓ | '불러오기 실패, 다시 시도' | P2 |
| MB-06 | `memberConsentStates/{uid}`, `consentRecords where subjectUid == uid orderBy recordedAt desc`, `rightsRequests where memberUid == uid` | subjectUid, recordedAt↓ | 같음 | P2 |

- `status == 'shared'` 필터는 클라이언트에서 적용한다(해제 묘비를 목록에서 숨김). 규칙은 `memberUid`만 요구하므로 서버 필터를 추가하면 인덱스가 하나 더 필요하다.
- `in` 필터 다중 회원 조회는 에뮬레이터에서 규칙 증명을 확인한 뒤에만 쓴다(PRD §9.6). TR-02의 `users` 청크 조회는 `isAssignedTrainer(userId)` 규칙(dfet:firestore.rules:76)으로 문서마다 증명된다.

---

## 11. 분석 이벤트·결과 패키지 계약(참조)

### 11.1 분석 이벤트

- 정본은 `contracts/analytics-events.v1.json`과 [12_COPY_ANALYTICS_AND_LINT.md](12_COPY_ANALYTICS_AND_LINT.md)다. 이 문서는 API 경계만 정한다.
- 트레이너 앱은 `AnalyticsClient.track(_ event: TrainerEvent)`만 쓰고, `TrainerEvent`는 생성된 enum이다. 속성은 허용 목록의 키·타입만 가진다.
- 서버 함수는 분석 이벤트를 보내지 않는다. 회원 단위 결합 지표는 `aggregateOpsMetrics`(§6.10)가 계산한다.
- 동의 변경, 공유, 초대 결과의 **서버 사실**은 auditLogs·opsMetrics가 정본이다. 분석 이벤트(`member_summary_shared`, `invite_code_redeemed`)는 클라이언트 보조 신호이며 서버 응답을 받은 뒤에만 보낸다.

| 이벤트 | 보내는 시점(API 기준) |
|---|---|
| `onboarding_consent_completed` | `recordConsent` 응답 성공 또는 오프라인 캡처 로컬 저장 직후(`channel` 속성) |
| `soap_review_finalized` | `SoapNoteStore.finalize` 반환 직후(`queued` = 오프라인 여부) |
| `member_summary_shared` / `member_summary_revoked` | 각 callable 성공 응답 뒤(`source_type`) |
| `invite_code_redeemed` | `redeemInviteCode` 응답 뒤(`result`: success \| expired \| reused \| invalid. 서버는 사유를 하나로 묶으므로 회원 앱은 `invalid`만 보낸다) |
| `save_failure_shown` | syncState가 `syncFailed`로 표시될 때(`entity_type`, `retry_result`) |

### 11.2 BodyPath 결과 패키지 v1

- 스키마 정본은 BodyPath 저장소 `docs/RESULT_PACKAGE_V1.md`, 코드 정본은 `BodyPathResult` 패키지다(ADR-012, PRD §10.4.3).
- 트레이너 앱 API 경계: `ResultPackageDecoder.decode(_:)` → `ResultPackageValidator.validate(_:knownAlgorithms:)` → 문제가 없으면 `AliasLinker.link`(첫 가져오기) → Outbox로 `bodyScans` create와 `circumferenceMeasurements`(`sourceGrade: observedSection`, `isBeta: true`, `validationStatus: 'unvalidated'`, `measuredAt = takenAt`) create.
- 거부 조건(`isSynthetic`, `takenAt` 없음, 모르는 스키마·알고리즘, 미확정 단면, ②③ 없는 회원, 대기 회원)은 서버 호출 전에 로컬에서 막는다(F-LIDAR-01, AC-LIDAR-01.1~01.4). 서버 규칙(R-22)이 두 번째 방어선이다.

---

## 12. 버전 관리·호환 규칙

| 대상 | 규칙 |
|---|---|
| callable 이름 | 한 번 배포한 이름·리전은 바꾸지 않는다. 호환되지 않는 변경은 새 이름(`<name>V2`)으로 추가하고, 이전 함수는 모든 클라이언트가 옮긴 뒤 제거한다 |
| 요청 필드 | 추가는 **선택 필드**로만 한다. 서버는 알 수 없는 최상위 키를 거부하므로(§3.4) 배포 순서는 서버 → 클라이언트다. 필수 필드 추가·의미 변경은 새 이름 |
| 응답 필드 | 추가는 언제든 가능하다. 클라이언트 디코더는 모르는 키를 무시해야 한다(Swift `Decodable` 기본, Dart `fromMap`은 필요한 키만 읽음). 제거·이름 변경은 새 함수 |
| messageKey | 추가만 한다. 의미를 바꾸지 않는다. 클라이언트는 모르는 키에 `common.<code>` 문장을 쓴다 |
| enum 값(contracts) | 추가는 `vocab.v1.json` 안에서 하고 생성물을 같은 PR에서 갱신한다. 클라이언트는 모르는 값을 '해석 불가'로 보존·표시한다(ADR-005). 제거·이름 변경은 `v2` 파일 |
| Firestore 문서 | `schemaVersion`(새 컬렉션 1, `soap_notes` 2). 호환되지 않는 변경은 버전을 올리고 규칙이 `schemaVersion`으로 분기한다. 필드 추가는 PRD §9.2·V1-05·픽스처·규칙 테스트를 같은 PR에서 고친다 |
| 기존 함수 응답 | `{success, message}` 형식을 유지한다. 새 필드 추가만 허용한다(§5.1 `accessKeySync`, §6.7 `counts`) |
| 레거시 SOAP 호환 | P0~P3 동안 v2 작성기는 `memberId = memberUid`를 함께 쓴다. `isSharedWithMember`는 false 고정(PRD §9.3). 호환 코드 제거는 P3 종료 체크리스트 |
| BodyPath 패키지 | SemVer 태그 `bodypathcore-vX.Y.Z`. 트레이너 앱은 정확한 버전으로 고정한다(ADR-012). 결과 패키지 `schemaVersion`이 모르는 값이면 가져오기 거부 |
| 규칙·함수 배포 | 순서: Functions → 규칙·인덱스 → 클라이언트. v1 SOAP 쓰기 차단 규칙은 롤백하지 않는다(R-21, ADR-014) |
| App Check 강제 | P3 전 `enforceAppCheck: false`. 켤 때는 회원 앱·admin_web·트레이너 앱 모든 호출 경로가 토큰을 보내는지 로그(`dfet.appcheck.missing` 0건 7일)로 확인한 뒤(DF-386) |

---
## 13. 테스트 케이스 총괄

### 13.1 테스트 배치와 CI

| 접두 | 대상 | 파일(신규) | 실행 | CI job |
|---|---|---|---|---|
| TC-06-ASG | assign/remove 수정 | `functions/test/e2e/assignment.e2e.test.js` | 에뮬레이터 e2e | functions-and-rules |
| TC-06-SRA | syncRecordAccessKeys | `functions/test/unit/access-core.test.js`, `test/e2e/access-keys.e2e.test.js` | 단위 + e2e | functions-and-rules |
| TC-06-RC | recordConsent | `test/unit/consent/deriveConsentState.test.js`, `test/unit/consent/validateRequest.test.js`, `test/e2e/recordConsent.e2e.test.js`(철회 즉시 처리 TC-06-RC-07·08은 DF-112의 `test/e2e/withdrawal.e2e.test.js`) | 단위 + e2e | functions-and-rules |
| TC-06-ASF | auditSoapFinalized | `test/e2e/auditSoapFinalized.e2e.test.js` | e2e | functions-and-rules |
| TC-06-LRA | logRecordAccess | `test/e2e/logRecordAccess.e2e.test.js` | e2e | functions-and-rules |
| TC-06-SRR, TC-06-EXP | 권리 요청·내보내기 | `test/e2e/rightsRequests.e2e.test.js`, `test/unit/shared/zipStore.test.js` | 단위 + e2e | functions-and-rules |
| TC-06-DEL | 삭제 연쇄 | `test/e2e/deleteMemberCascade.e2e.test.js`, `test/unit/privacy/deletionTargets.test.js` | e2e | functions-and-rules |
| TC-06-PUR, TC-06-AOO, TC-06-AGG | 스케줄 함수 | 단위 `test/unit/privacy/*.test.js`·`test/unit/ops/alertOverdueObligations.test.js`·`test/unit/shared/businessDays.test.js`(core 직접 호출, 시각 주입), e2e `test/e2e/purgeExpiredRecords.e2e.test.js`·`alertOverdueObligations.e2e.test.js`·`aggregateOpsMetrics.e2e.test.js` | 단위 + e2e(core) | functions-and-rules |
| TC-06-INV, TC-06-RED | 초대 | `test/e2e/invite.e2e.test.js` | e2e | functions-and-rules |
| TC-06-CMS, TC-06-RMS, TC-06-GSP, TC-06-MSV | 요약 | `test/unit/summaries/*.test.js`, `test/e2e/createMemberSummary.e2e.test.js`(CMS·RMS·GSP·MSV 공용) | 단위 + e2e | functions-and-rules |
| TC-06-LMA | 별칭 | `test/e2e/alias.e2e.test.js` + 기존 `clinical-emulator-e2e.js` | e2e | functions-and-rules |
| TC-06-VPC | 재검증 트리거 | `test/e2e/posture.e2e.test.js` | e2e | functions-and-rules |
| TC-06-EVC | 판정 엔진 | `test/unit/change/evaluateChange.test.js`(벡터 T01~T25) | 단위 | functions-and-rules(P3) |
| TC-06-SYN | SyncEngine·RemoteWriter | `trainer_app/Packages/TrainerCore/Tests/SyncEngineTests/*` | `swift test`(macOS) + `IntegrationTests`(에뮬레이터) | trainer-app, trainer-app-emulator-it |
| TC-06-DRT | Dart 저장소 | `test/*_repository_test.dart`(기존 `test/` 평면 배치, Firestore·Functions는 생성자 주입으로 대역 사용) | `flutter test` | flutter |
| TC-06-ADM | admin_web 라우트 | `admin_web/test/*.test.mjs`(기존 `node --test test/*.test.mjs` 규약, dfet:admin_web/package.json:14) | node:test | admin-web |

### 13.2 에뮬레이터·시드

- `firebase.json` `emulators`에 `auth`(19099)를 추가하고, CI e2e를 `firebase emulators:exec --only auth,functions,firestore,storage`로 바꾼다(ASM-06-19(`firebase.json` auth·functions 항목은 P0 시드 스토리가 먼저 추가하고 DF-025는 없을 때만 추가), DF-025에서 처음 필요). Functions 에뮬레이터 포트는 기존 e2e 기본값 `127.0.0.1:5001`을 유지한다.
- `functions/.secret.local`에 테스트 값 `INVITE_CODE_HMAC_KEY=e2e-invite-key`를 추가한다(P2, 기존 `INGEST_HMAC_KEYS` 패턴 dfet:.github/workflows/ci.yml:54). 실제 키는 GitHub Secrets·Secret Manager에만 둔다(ADR-019).
- 시드: `node functions/scripts/dev/seed-emulator.js --seed functions/test/fixtures/emulator-seed.v1.json`(변형 `.no-consent.v1.json`·`.consent-fail.v1.json`, V1-10 §5.4). e2e 하네스가 더 필요한 회원(0004~)은 테스트가 직접 만든다.

| 계정 | claim | 용도 |
|---|---|---|
| `synthTrainerA`, `synthTrainerB` | `trainer: true` | 담당·비담당 |
| `synthAdmin` | `admin: true` | 관리자 |
| `synthMember0001`~`synthMember0005` | 없음 | 가입 회원(동의 상태 조합별) |
| `SYNTHpending00000001`~`SYNTHpending00000003` | — | 대기 회원(pending, cancelled, expired) |
| `synthLabOperator` | `role: 'lab_operator'` | 직원 거부 확인 |

- 식별자는 [V1-10 §5.2](10_TEST_PLAN.md#52-합성-식별자표시명-규약)의 에뮬레이터·통합 시드 규약(`synth`/`SYNTH` 접두)을 따른다. 공통 시드에는 `synthMember0001`~`0003`만 있으므로 `0004`·`0005`와 대기 회원 `…02`·`…03`은 e2e 하네스가 추가로 만든다. 레거시 로컬 UUID 형식(`member-…`)은 MIG-07 보고 대상이라 합성 ID에도 쓰지 않는다.
- 실데이터·운영 프로젝트는 테스트에 쓰지 않는다(ADR-013).

### 13.3 클라이언트 계약 테스트

| ID | 대상 | 시나리오 | 기대 | 연결 |
|---|---|---|---|---|
| TC-06-SYN-01 | SyncEngine | 동의(①) → 부모(②) → 업로드(③) → 경로(④) → 확정(⑤) | 가짜 원격 호출 순서가 정확히 이 순서 | NFR-05 |
| TC-06-SYN-02 | SyncEngine | 동의 호출 실패(`unavailable`) | 같은 회원의 ②~⑤ 호출 0, 상태 `awaitingConsent` | NFR-05, AC-PRIV-03.3 |
| TC-06-SYN-03 | SyncEngine | ② create가 `permission-denied` | 즉시 `syncFailed`, `synced` 표시 0회, 로컬 원본 유지 | C-05, AC-C-05.1 |
| TC-06-SYN-04 | SyncEngine | 업로드 md5 불일치 | 재시도, 경로 기록(④) 호출 0 | NFR-05 |
| TC-06-SYN-05 | SyncEngine | 앱 재시작 시뮬레이션(큐 영속) 후 재개, 서버에 이미 문서 있음 | create 중복 0, `synced` | NFR-04 |
| TC-06-SYN-06 | SyncEngine | `unavailable` 5회 연속 | 5회째 `syncFailed`, 재시도 버튼 동작 | §8.6 3번 |
| TC-06-SYN-07 | SyncEngine | 오프라인 확정 → 복구 | `pendingFinalize` → 서버 `finalized`, `finalizedAt`은 서버 시각 | AC-SOAP-04.5 |
| TC-06-SYN-08 | CallableClient | 서버 `failed-precondition` + `details.messageKey` | `DomainError.remote(.failedPrecondition, key)` | §8.12 |
| TC-06-DRT-01 | `AppFeatureFlags.fromMap` | 빈 맵·null | 8키 모두 false | ADR-010 |
| TC-06-DRT-02 | `MemberSummaryRepository.watchSummaries` | 쿼리 권한 오류 | 스트림 오류(빈 목록 아님) | PRD §9.6 |
| TC-06-DRT-03 | `DfetFunctionsException.from` | details에 messageKey 없음 | `common.<code>` | §3.5 |
| TC-06-DRT-04 | `SoapNoteV2Codec` | `contracts/fixtures/soap_v2/*`, `soap_legacy/*` | 왕복 무손실, 레거시 metric 수 불변 | AC-SOAP-06.1~06.2 |
| TC-06-DRT-05 | `ConsentRepository.recordConsent` | 같은 clientCaptureId 재시도 | 서버 `replayed:true`를 성공으로 처리 | §3.7 |
| TC-06-ADM-01 | feature-flags | 7키 본문 | 400 | DF-027 |
| TC-06-ADM-02 | consent-documents publish | 보유기간 빈 값 | 400 | AC-PRIV-01.3 |
| TC-06-ADM-03 | consent-documents publish | `sharing`에 recipient 없음 | 400 | AC-PRIV-01.4 |
| TC-06-ADM-04 | 회원 상세 렌더 | 1회 열람 | `healthRecordRead` 1건, 수치 필드 없음 | AC-PRIV-05.1 |
| TC-06-ADM-05 | clinical/config bodyChange | `mdcValue: 0`, 빈 `conditionKeys` | 400 | DF-221 |

### 13.4 단계별 필수 통과 목록

| 단계 종료 | 필수 TC |
|---|---|
| P0(DF-926) | TC-06-ASG-*, TC-06-SRA-*, TC-06-DRT-01·04 |
| P1a(DF-927) | P0 + TC-06-RC-*, ASF, LRA, SRR, EXP, DEL, PUR, AOO, AGG-01~04, SYN-*, DRT-02·03·05, ADM-01~04 |
| P1b(DF-928) | P1a + TC-06-ADM-05, AGG(M-05) |
| P2(DF-936) | P1b + INV, RED, CMS-01~13, RMS, GSP, MSV(승인 시), LMA, VPC |
| P3(DF-938) | P2 + EVC-*, CMS-14·15 |

---

## 14. 가정(ASM)·충돌·열린 질문

### 14.1 가정

| ID | 가정 | 관련 PRD | 확인 시점·방법 |
|---|---|---|---|
| ASM-06-01 | 함수 기본 옵션(256MiB, 60초, maxInstances 10)과 무거운 함수 옵션(1GiB, 540초)은 제안값이다 | NFR-15, NFR-16 | P1a 종료 시 실행 로그로 조정 |
| ASM-06-02 | 서버는 한국어 문장 대신 messageKey만 보내고, 문장은 클라이언트 문자열 카탈로그에 둔다. messageKey 목록 정본은 이 문서다 | §3.8, F-PRIV-06.3, C-06 | DF-012·DF-306 리뷰 |
| ASM-06-03 | `contracts/audit-actions.v1.json`은 PRD §9.7 action과 함께 admin_web 기존 action 문자열(`member.assignment.update`, `app.feature_flags.update` 등)도 등록한다. 담당 변경 감사는 기존 이름을 재사용한다 | §9.7 auditLogs | DF-033 |
| ASM-06-04 | M-06·M-07 계산을 위해 `markSummaryViewed` callable과 `memberSummaries.firstViewedAt` 서버 필드가 필요하다. 스파인·PRD §10.6에 없다 | §5.3 M-06, M-07, §9.2 | 소유자 승인(Q-DEV-04), P2 진입 전 |
| ASM-06-05 | `assignMemberToTrainer`의 `allowReassign` 기본값은 true(현행 동작 유지)이고, AD-01 신규 배정 화면만 false로 호출한다 | F-LINK-05.4, F-LINK-02.6 | DF-025 |
| ASM-06-06 | `syncRecordAccessKeys`는 트리거 3개(`users`, `memberConsentStates`, `pendingMembers`)로 export한다. PRD 이름은 '(가칭)' | §10.6 | DF-025 |
| ASM-06-07 | `memberSummaries.sharedByUid`(불변, 서버 작성)를 추가한다. 요약의 ④ 인계 판단에 작성자가 필요하다 | §9.2 memberSummaries, F-LINK-05.4 | DF-309 전에 V1-05·PRD §9.2 반영 |
| ASM-06-08 | 재정렬 상태 추적용 서버 필드 `accessKeySync`를 `users/{uid}`와 `pendingMembers/{id}`에 둔다(새 컬렉션 없음) | F-LINK-03.5 | DF-025, V1-05 반영 |
| ASM-06-09 | `consentRecords`에 `capturedAt`(오프라인 캡처 시각)을 추가한다. `recordedAt`은 서버 시각이다. 멱등 키 `clientCaptureId`는 V1-05 §4.11(ASM-05-12)에 이미 있으므로 여기서 새로 만들지 않는다. `capturedAt`은 V1-05 §4.11 필드 표에 아직 없어 DF-109 PR에서 V1-05에 함께 반영한다 → V1-05 §4.11에 `capturedAt` 반영(ASM-05-44) | §9.2 consentRecords, F-PRIV-03.7, AS-32 | G-04 법률 검토에서 '동의 시각' 정의 확인, DF-109 |
| ASM-06-10 | 철회 파기 대기 표시 `memberConsentStates.pendingPurge.{healthData, bodyImaging}`를 둔다 | F-PRIV-02.3 | DF-112, DF-133 |
| ASM-06-11 | (철회, v1.0 검토 반영) 별도 서명 경로를 두지 않는다. V1-05 §4.11·ASM-05-13과 DF-109 ASM-P1a-03의 `consentSignatures/{첫 recordId}.png`(같은 캡처의 레코드가 공유)를 따른다 | §9.5 | — |
| ASM-06-12 | 대기 회원(uid 없음)의 권리 요청은 `submitRightsRequest` 대상이 아니다. 삭제는 등록 취소, 열람은 관리자 수동 처리 | F-PRIV-07.1, F-LINK-01.5, Q-07 | G-04 |
| ASM-06-13 | `rightsRequests.requestedBy`(접수자 uid)를 추가한다 | §9.2 rightsRequests | DF-135 |
| ASM-06-14 | 열람 내보내기 서명 URL은 24시간 만료, 파일은 만료 1일 뒤 파기 | §9.5 rightsExports, Q-07 | G-04 |
| ASM-06-15 | 서명 URL 발급을 위해 Functions 런타임 서비스 계정에 `iam.serviceAccounts.signBlob`(Service Account Token Creator) 권한이 필요하다. 소유자 행동으로 추가해야 한다 | §9.5, F-LINK-05.6 | DF-135·DF-314 DoR, EP-00 항목 추가 제안 |
| ASM-06-16 | 직원 claim 계정의 `deleteOwnAccount`는 거부하고 관리자 절차로 처리한다 | F-PRIV-04(범위 밖) | 소유자 확인(Q-DEV-06) |
| ASM-06-17 | ③ 철회 파기한 체형평가에 `imagingPurgedAt`을 기록하고 재검증 트리거가 이를 건너뛴다 | F-PRIV-02.3, AC-ASM-04.1 | DF-133, DF-324 |
| ASM-06-18 | `COACHING_RECORD_RETENTION_MONTHS`, `PENDING_MEMBER_RETENTION_DAYS` 매개변수 기본값 0(비활성). 값은 동의 문서 보유기간과 같아야 한다 | Q-24, G-04, F-LINK-01.5 | G-04 뒤 소유자가 설정 |
| ASM-06-19 | callable e2e를 위해 auth 에뮬레이터(19099)를 추가한다 | §12.5 | DF-025 |
| ASM-06-20 | 영업일·당일·ISO 주는 Asia/Seoul 기준이며 공휴일 표는 `functions/src/shared/krHolidays.js`에 연 1회 갱신한다 | §9.7(5영업일), M-03 | DF-133, 매년 12월 |
| ASM-06-21 | 초대 코드 문자 집합은 32자(0·O·1·I 제외), 표시 `XXXX-XXXX` | F-LINK-02.2 | DF-304 |
| ASM-06-22 | 초대 코드 실패 횟수는 `users/{uid}.inviteRedeemGuard` 서버 필드에 둔다 | F-LINK-02.7, §9.2 inviteCodes | DF-305 |
| ASM-06-23 | `createMemberSummary` 요청은 `sources[{collection,id}]`, `highlights[{refId,metricCode,side}]`다(스파인 `sourceIds`, `highlightRefIds`를 구체화). 저장 필드는 PRD 그대로 | §9.2, F-SOAP-05.3 | DF-309 |
| ASM-06-24 | P3 전 `comparedTo`는 체형은 기준선, 그 밖에는 같은 seriesKey의 직전 active 기록이다 | §7.5 비교 기준, §9.2, Q-19 | DF-309, P2 진입 |
| ASM-06-25 | 공유 알림(F-SOAP-05.12)은 회원 앱에 푸시 SDK가 없어 v1 API 범위에 넣지 않았다 | F-SOAP-05.12 | 소유자 결정(Q-DEV-03) |
| ASM-06-26 | 해제 시 `title`은 남기고, soapNote 원천의 `memberSummaryId`는 null로 바꾼다 | F-LINK-05.3, F-SOAP-05.8 | DF-310 |
| ASM-06-27 | `linkMemberAlias`는 `lidarBeta` 플래그를 요구하고 `externalId` 패턴은 `^[A-Za-z0-9._:-]{1,64}$`다 | F-LINK-04.3 | DF-319, BodyPath Subject.code 형식 확인 |
| ASM-06-28 | `evaluateChange` 요청에 좌우 지표용 `side`를 더한다 | §7.5 | DF-380 |
| ASM-06-29 | P1a 권리 요청 상태 갱신은 소유자 Admin SDK 스크립트 `functions/scripts/ops/rights-request.js`(기본 dry-run)로 한다 | §10.7 권리 요청 처리 | DF-135 |
| ASM-06-30 | admin_web `writeAudit`은 DF-136에서 PRD 형식으로 바꾸고 `actorEmail`을 뺀다. 기존 기록은 읽을 때 `createdAt → at`으로 해석 | §9.2 auditLogs, §9.7 금지 항목 | DF-136 |
| ASM-06-31 | `memberConsentStates` 문서가 없는 회원(동의 모델 도입 전 레거시)은 동의 사유로 접근 키를 null로 만들지 않는다. 상태 문서가 있고 ②가 false일 때만 null | F-PRIV-02.3, §9.4 hasConsent, MIG-02 | 소유자 확인(Q-DEV-05), MIG-02 실사 결과 |

### 14.2 스파인·PRD·코드와의 충돌

충돌 ID는 PRD 공통 규칙 C-01~C-06과 겹치지 않도록 `CF-06-NN`을 쓴다. 본문에서 접두 없는 `C-01`~`C-06`은 PRD 공통 규칙이다.

| ID | 내용 | 처리 |
|---|---|---|
| CF-06-01 | 스파인은 '현재 onCall 11개'라고 적었으나 작업 트리에는 12개(커밋본 9개)다(§2) | 이 문서는 코드 기준으로 적었다. 스파인 문구 수정 필요 |
| CF-06-02 | `removeMemberFromTrainer`가 트랜잭션에서 쓰기 뒤 읽기를 한다(dfet:functions/index.js:720-726). PRD·스파인에 없음 | DF-025 범위에 포함(§5.1). 실행 확인은 TC-06-ASG-01 |
| CF-06-03 | admin_web `writeAudit`이 `actorEmail`을 저장한다(dfet:admin_web/lib/audit.ts:14). PRD §9.7은 이메일을 금지 | ASM-06-30, DF-136 |
| CF-06-04 | admin_web 담당 변경이 callable을 거치지 않는다(dfet:admin_web/app/api/admin/assignments/route.ts:18-61). PRD F-LINK-03.4의 호출 경로 목록에 없다 | `users/{uid}` 트리거로 해소(§6.1). PRD F-LINK-03.4에 AD-01 직접 경로 추가 제안 |
| CF-06-05 | 플래그 라우트가 3키 스키마로 merge 없이 덮어쓴다(dfet:admin_web/app/api/admin/feature-flags/route.ts:10, :20) | §7.1, DF-027 |
| CF-06-06 | 스파인 `createMemberSummary({sourceIds[], highlightRefIds[]})`로는 bodyReport 원천 컬렉션과 한 기록 안 여러 지표를 구분할 수 없다 | ASM-06-23 |
| CF-06-07 | 스파인 `recordConsent` 시그니처에 멱등 키가 없다(ADR-017은 멱등 키를 요구) | V1-05 `clientCaptureId`(ASM-05-12)를 요청 필드로 받는다(§6.2.5). 서명 경로는 V1-05 `consentSignatures/{첫 recordId}.png`를 따른다(ASM-06-11 철회). `capturedAt`은 ASM-06-09 |
| CF-06-08 | M-06은 '서버 기록'을 요구하지만 PRD §10.6·스파인 함수 목록에 열람 기록 수단이 없다 | ASM-06-04 |
| CF-06-09 | F-SOAP-05.12 공유 알림에 필요한 푸시 기반이 회원 앱에 없다 | ASM-06-25 |
| CF-06-10 | 스파인은 assign에 'conflict 처리'를 요구하지만 PRD F-LINK-05.4는 관리자 재배정을 허용한다 | ASM-06-05(`allowReassign`) |
| CF-06-11 | ③ 철회 파기(랜드마크 삭제)와 P2 재검증 트리거(필수 랜드마크 확인)가 충돌해 파기된 문서를 draft로 되돌릴 수 있다 | ASM-06-17 |
| CF-06-12 | 열람 내보내기 ZIP에 라이브러리가 필요하지만 ADR-017은 ADR 없는 새 의존성을 금지한다 | 무압축 ZIP 작성기(`zlib.crc32`, Node 22)로 해결. 압축이 필요하면 ADR 추가 |
| CF-06-13 | `firebase.json`에 auth·functions 에뮬레이터 설정이 없다(dfet:firebase.json:37-50) | ASM-06-19 |
| CF-06-14 | `syncRecordAccessKeys`는 P0인데 동의 상태는 P1a부터 생긴다. `hasConsent`와 같은 의미(문서 없음 = 미동의)로 계산하면 P0 배포 즉시 레거시 기록 접근이 모두 끊긴다 | ASM-06-31 |

### 14.3 개발 열린 질문(Q-DEV, 00_README 목록에 합칠 후보)

| ID | 질문 | 결정 전 기본값 | 기한 |
|---|---|---|---|
| Q-DEV-03 | 공유 알림(F-SOAP-05.12)을 어떤 수단으로 보낼 것인가(FCM 도입, 앱 내 배지만) | 앱 내 목록 갱신만, 푸시 없음 | P2 진입 |
| Q-DEV-04 | `markSummaryViewed`와 `firstViewedAt`을 승인하는가 | 미구현, M-06·M-07은 `null` | P2 진입 |
| Q-DEV-05 | 동의 상태 문서가 없는 레거시 회원 기록의 트레이너 열람을 언제 끊는가(MIG-02 실사 뒤 현장 동의 요청, 일정 기간 뒤 비표시 등) | ASM-06-31(끊지 않음) | G-04 |
| Q-DEV-06 | 트레이너 계정 탈퇴·정리 절차 | ASM-06-16(자기 삭제 거부) | P3 진입 |

Q-DEV-01·02는 다른 문서(ADR-015, AS-DEV-08)에서 이미 쓴다.

---

## 15. 변경 이력

| 버전 | 날짜 | 작성 | 내용 |
|---|---|---|---|
| v1.0 | 2026-09-24 | CJH(AI 에이전트 초안) | 최초 작성. 현행 Functions 기준선 확인, 신규 함수 18종(트리거 분할 제외, 제안 1종 포함)·기존 함수 변경·admin_web 라우트·Swift·Dart 계약·쿼리 카탈로그·호환 규칙·테스트 케이스 정의 |
| v1.0 | 2026-09-24 | CJH(AI 에이전트, 교차 검토 반영) | `recordConsent` 멱등 키를 V1-05·DF-109의 `clientCaptureId`로 통일(자동 레코드 ID, 서명 `consentSignatures/{첫 recordId}.png`, ASM-06-11 철회). 충돌 ID를 `C-06-NN`으로 변경. 테스트 파일명과 합성 식별자를 스토리 카드·V1-10 §5.2에 맞춤 |
| v1.0 | 2026-09-24 | CJH(AI 에이전트, 릴리스 편집) | TC-06-SYN 경로를 `Packages/TrainerCore/Tests/SyncEngineTests`로 고침(V1-04 §6.2) |
| v1.0(정합 패스 2) | 2026-09-24 | CJH(AI 에이전트) | 배포 명령 --project, consentDocumentVersions ID `--`, markSummaryViewed DF-335·MB-02·MB-04, §8.6 Outbox 이름을 V1-05에 맞춤, §7.8 audit-reviews 추가, 시드 경로, CF-06-NN·ASM-06-NN 이름 변경 |
| v1.0.1 | 2026-09-24 | CJH(AI 에이전트) | 교차 정합성 조정: R2·R5·R7·R10 결정 반영(ASM-06-32~34), §7.8 추가 |
