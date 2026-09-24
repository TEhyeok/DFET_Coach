# ADR-006 회원 공유는 서버가 만드는 소비자본 memberSummaries

| 항목 | 내용 |
|---|---|
| 문서 ID | ADR-006 |
| 버전 | v1.0 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | D9, F-SOAP-05, F-LINK-05, F-VIZ-06, §9.2 memberSummaries, §10.6, AC-SOAP-05.1~05.12, R-10~R-12, §7.6 |
| 관련 에픽·스토리 | EP-17 / DF-309, DF-310, DF-311, DF-313, DF-314, DF-315, DF-316, DF-331 |
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

**Accepted** (2026-09-24, 소유자 CJH). 구현은 P2(memberShare)다.

## 2 맥락

- Firestore는 필드 단위 읽기 제어가 불가능하다. 현재 회원 읽기 규칙은 `memberId == uid && isSharedWithMember == true`(dfet:firestore.rules:140-145)인데 회원 앱 쿼리는 `memberId`만으로 조회해 규칙이 증명하지 못한다(dfet:lib/services/firestore_service.dart:601-603, 정적 분석).
- 공유 여부가 코드에서 true로 고정돼 있다(dfet:trainer_ios/DFETTrainer/Data/FirebaseTrainerRepository.swift:94).
- 금지어 검사, 활성 정책 버전 스탬프, 회원 배지 자격(§7.6), 감사는 클라이언트에 맡길 수 없다.
- 기존 임상 리포트도 소비자본·전문가본을 분리하는 패턴이다(dfet:firestore.rules:219-260).

## 3 결정

1. 원 기록은 기본 비공유다. 공유 경로는 TR-06 미리보기 → 명시적 '공유' → callable `createMemberSummary` 하나뿐이다.
2. `createMemberSummary`(asia-northeast3)가 서버에서 처리한다: 원 기록 상태 확인(finalized·confirmed·active, memberUid 존재), 금지어·약어 검사(회원 규칙 세트, 위반 시 `failed-precondition`과 위치), 활성 정책 버전 스탬프, 회원 배지 자격(§7.6 inHouse만), highlights 구성(`seriesKey`, `mdc`, `comparedTo`), 제외 규칙(painNrs, photoAuto, observedSection, 결과지, 필기, A 원문), 사진은 동의 ③과 토글이 모두 있을 때만.
3. 회원 앱은 `memberSummaries where memberUid == uid orderBy sharedAt desc` 쿼리 하나만 쓴다.
4. 해제는 묘비 문서(`status = 'revoked'`, 내용 비움)로 남긴다. 재공유는 기존 요약 해제 + 새 문서 생성이다(AS-25).
5. 공유 사진은 회원 전용 `getSharedPhotoUrl`(15분 만료)로만 받는다.
6. 오프라인 공유는 불가하며 트레이너 앱은 '온라인 필요'를 표시한다. Outbox에 넣지 않는다.
7. `isSharedWithMember`는 false 고정 레거시 필드로 남긴다.

## 4 결과

**좋아지는 점**
- 회원이 원 기록을 읽을 경로가 없다(R-10). 노출 내용은 서버가 통제하고 감사한다.
- 정책 버전이 요약에 남아 판정을 재현할 수 있다(§12.4 롤백).

**비용·위험**
- 공유가 온라인 전용이다.
- 요약과 원 기록이 어긋날 수 있다(원본 정정 시 재공유 필요).

**후속 작업**
- DF-309·DF-310 서버 함수, DF-311 TR-06, DF-313 bodyReport, DF-314 서명 URL, DF-315·DF-316 회원 화면, DF-331 플래그 노출 조건.

## 5 대안

| 대안 | 장점 | 채택하지 않은 이유 |
|---|---|---|
| `isSharedWithMember` 플래그 유지 | 구현 적음 | 필드 단위 제어 불가, 현재 회원 쿼리가 규칙에 거부됨 |
| 클라이언트가 요약 문서 작성 | 오프라인 가능 | 금지어·배지 자격·감사를 서버에서 강제 못 함 |

## 6 PRD 근거

D9, F-SOAP-05, F-LINK-05, F-VIZ-06, §9.2 memberSummaries, §10.6, AC-SOAP-05.1~05.12, R-10~R-12, §7.6. 설계 반영 위치: [V1-04 §14](../04_ARCHITECTURE.md#14-회원-앱-flutter-변경), [V1-04 §15](../04_ARCHITECTURE.md#15-functions-구조), 계약은 [V1-06](../06_API_SPEC.md).

## 7 재검토 조건

- G-05b 결과가 웰니스가 아니면 공유 범위 자체를 재검토한다(P2 진입 금지).
- Q-19(한 번의 공유로 시계열 전달)가 채택되면 필드를 추가한다.

## 8 관련 스토리

DF-309, DF-310, DF-311, DF-313, DF-314, DF-315, DF-316, DF-331.

## 9 변경 이력

| 버전 | 날짜 | 변경 요지 | PR | PRD 영향 |
|---|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성 | — | 없음 |
