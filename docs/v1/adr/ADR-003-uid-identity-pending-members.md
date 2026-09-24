# ADR-003 회원 식별: uid 단일 진실원 + 대기 회원·초대 코드 + 파생 접근 키 trainerId

| 항목 | 내용 |
|---|---|
| 문서 ID | ADR-003 |
| 버전 | v1.0 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | D6, F-LINK-01, F-LINK-02, F-LINK-03, F-LINK-05.4, §9.1 파생 접근 키, §9.4 헬퍼, §10.6, R-02, R-05~R-07, RISK-10, MIG-07, MIG-08 |
| 관련 에픽·스토리 | EP-04, EP-09, EP-16 / DF-013, DF-020, DF-021, DF-025, DF-108, DF-113, DF-138, DF-304, DF-305 |
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

**Accepted** (2026-09-24, 소유자 CJH). D6 채택 기본값의 구현 결정이다.

## 2 맥락

- Runner 내장 트레이너는 회원 식별자로 로컬 UUID seed를 쓴다: `avatarSeed: "member-\(UUID().uuidString)"`(dfet:ios/Runner/AppDelegate.swift:8117), SOAP `memberId`에 그대로 넣는다(:3839). 기존 규칙 `isAssignedTrainer(memberId)`(dfet:firestore.rules:47-51, :147-149)는 이 값을 거부할 가능성이 높다(정적 분석).
- trainer_ios는 `trainers/{uid}.memberIds`를 구독하고 `users`를 10개씩 조회한다(dfet:trainer_ios/DFETTrainer/Data/FirebaseTrainerRepository.swift:158-220). 이 방식만 uid 기반이다.
- 기존 soap_notes 읽기 규칙은 `resource.data.trainerId == request.auth.uid`라 담당이 해제돼도 이전 트레이너가 계속 읽는다(dfet:firestore.rules:140-145). 반대로 읽기 규칙에 `isAssignedTrainer`(get)를 넣으면 `where trainerId == uid` 목록 쿼리를 규칙이 증명하지 못한다.
- 현장에서는 회원 가입 전에 기록을 시작해야 한다(F-LINK-01).

## 3 결정

1. 담당 관계의 진실원은 `trainers/{uid}.memberIds` ↔ `users/{uid}.trainerId` 하나이며 Functions와 admin_web 서버만 쓴다.
2. 회원 키는 `MemberKey`(`.uid` | `.pending`)다. 로컬 UUID 회원 키는 쓰지 않는다. 문서 필드는 `memberUid`/`pendingMemberId`, 레거시 `memberId`는 호환 기간 동안 `memberUid`와 같은 값만 쓴다.
3. 원 기록은 **파생 접근 키 `trainerId`**(지금 접근 가능한 담당 트레이너)와 **불변 작성자 `authorUid`**(신체조성은 `enteredBy`)를 분리한다. create 때 `trainerId == authorUid == uid`만 허용하고, 이후 `trainerId` 변경은 서버만 한다.
4. 담당 변경 경로(assign, remove, redeem, 탈퇴, 동의 ④ 부여) 뒤 `syncRecordAccessKeys`가 6개 컬렉션(soap_notes, postureAssessments, bodyCompositionRecords, circumferenceMeasurements, bodyScans, memberSummaries)의 `trainerId`를 재정렬한다. ④가 없으면 null, 있으면 확정 기록만 인계하고 draft는 제외한다. 멱등·청크·재시도, 실패 시 경보.
5. 읽기 규칙은 `isAccessTrainer`(= `trainerId == uid`) 한 줄, 쓰기 규칙은 `canWriteFor`(가입 회원이면 `isAssignedTrainer`, 대기 회원이면 `isPendingOwner`)로 담당 여부를 다시 확인한다(RISK-10 이중 확인).
6. 대기 회원은 표시명·성별·출생연도·만 14세 확인만 받는다. 초대 코드는 HMAC-SHA256 해시만 저장하는 1회성·만료형이며, redeem은 트랜잭션으로 하고 중단 뒤 재개할 수 있다(P2).
7. 트레이너 앱은 `trainers/{uid}` 리스너 + `users` 10개 청크 조회, `pendingMembers where trainerId == uid && status == 'pending'`으로 회원을 불러온다. 쿼리 오류는 빈 목록으로 삼키지 않는다(반례 FirebaseTrainerRepository.swift:214-216).

## 4 결과

**좋아지는 점**
- 목록 쿼리를 규칙이 증명할 수 있고(R-13), 담당 해제 뒤 접근이 끊긴다(R-06).
- Storage 규칙이 부모 문서 1건만 조회해도 권한을 판정할 수 있다(ADR-007).
- 동의 ④ 인계를 문서 단위로 표현한다.

**비용·위험**
- 재정렬이 늦으면 짧은 기간 이전 트레이너가 읽을 수 있다(RISK-10). 쓰기는 `canWriteFor`로 막고, 재정렬 실패는 로그 경보로 드러낸다.
- 재정렬 함수가 P0 규칙의 전제가 되어 P0 범위가 커진다.

**후속 작업**
- DF-025 syncRecordAccessKeys, DF-020·DF-021 규칙, DF-013 회원 로드, DF-108 대기 회원 등록, DF-138 trainerWorkspaces 가져오기, DF-304·DF-305 초대 코드(P2).

## 5 대안

| 대안 | 장점 | 채택하지 않은 이유 |
|---|---|---|
| 읽기 규칙에 `isAssignedTrainer` 사용 | 해제 즉시 차단 | `trainerId` 목록 쿼리를 규칙이 증명 못 함 |
| 관리자 배정만 사용 | 단순 | 현장 선등록 불가 |
| 로컬 UUID + 이메일 매칭 유지 | 기존 코드 재사용 | 규칙 거부, 삭제 연쇄 누락(dfet:ios/Runner/AppDelegate.swift:3839, :8117) |

## 6 PRD 근거

D6, F-LINK-01, F-LINK-02, F-LINK-03, F-LINK-05.4, §9.1 파생 접근 키, §9.4 헬퍼, §10.6, R-02, R-05~R-07, RISK-10, MIG-07, MIG-08. 설계 반영 위치: [V1-04 §12](../04_ARCHITECTURE.md#12-인증과-권한), 규칙 코드는 [V1-05 §7](../05_DATA_MODEL_AND_RULES.md#7-firestore-보안-규칙-초안).

## 7 재검토 조건

- AS-15(회원당 담당 1명)가 깨지면 `trainerId` 단일 필드를 배열 접근 키로 바꾸는 개정이 필요하다.
- 재정렬 실패 경보가 P1a 동안 반복되면 트리거 대신 동기 호출 경로를 늘린다.

## 8 관련 스토리

DF-013, DF-020, DF-021, DF-025, DF-108, DF-113, DF-138, DF-304, DF-305.

## 9 변경 이력

| 버전 | 날짜 | 변경 요지 | PR | PRD 영향 |
|---|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성 | — | 없음 |
