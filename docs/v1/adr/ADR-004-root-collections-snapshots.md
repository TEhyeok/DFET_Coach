# ADR-004 루트 컬렉션 + SOAP O의 ID 참조와 표시용 스냅샷

| 항목 | 내용 |
|---|---|
| 문서 ID | ADR-004 |
| 버전 | v1.0 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | D7, §9.1 공통 필드 규약·루트 컬렉션 근거, §9.2, F-SOAP-03, F-ASM-04, F-BC-03.5, §7.8, C-01 |
| 관련 에픽·스토리 | EP-02, EP-11, EP-14, EP-15 / DF-006, DF-021, DF-127, DF-129, DF-209, DF-217, DF-218 |
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

**Accepted** (2026-09-24, 소유자 CJH). D7 채택 기본값이다.

## 2 맥락

- 트레이너가 쓰고 회원은 요약본으로만 읽는 구조다. `users/{uid}/{collection}/**`는 회원이 쓰고 트레이너는 쓸 수 없다(dfet:firestore.rules:97-100).
- SOAP 문서 안에 측정을 넣으면 SOAP 없는 평가와 시계열 쿼리가 불가능하다. 현재 SOAP metric의 value는 문자열·null이 섞여 있다(dfet:trainer_ios/DFETTrainer/Domain/SoapModels.swift:22-31).
- 기존 저장은 createdAt을 매번 덮어쓰고(dfet:trainer_ios/DFETTrainer/Data/FirebaseTrainerRepository.swift:95) 측정 시각과 저장 시각을 구분하지 않는다.

## 3 결정

1. `postureAssessments`, `bodyCompositionRecords`, `circumferenceMeasurements`, `bodyScans`는 루트 컬렉션이다.
2. SOAP O는 `objective.refs`(ID 목록, 종류별 ≤20)와 `objective.snapshots`(§7.8 필드, ≤60)를 저장한다. 스냅샷은 원본이 바뀌어도 고정하고, 원본이 새 버전·voided·수정되면 '원본 변경됨'을 표시한다(DF-218).
3. 정정은 덮어쓰지 않는다: SOAP는 addendum, 체형은 `supersedesId`로 새 버전, 신체조성·둘레는 `voided` 후 재입력.
4. 모든 원 기록에 공통 필드를 강제한다: `schemaVersion`(새 컬렉션 1, soap_notes 2), `createdAt`·`updatedAt == request.time`, 측정 시각(`capturedAt`/`measuredAt`/`takenAt`/`sessionDate`)은 클라이언트 값이되 `request.time + 5분` 상한, `legalNature = 'coachingRecord'`, 수치마다 `sourceGrade`, `trainerId`·`authorUid`.
5. 추이·정렬은 측정 시각 기준이다(AC-C-01.2).

## 4 결과

**좋아지는 점**
- 시계열 쿼리·인덱스·삭제 연쇄를 컬렉션 단위로 관리한다.
- SOAP 확정 뒤 원본이 바뀌어도 기록 당시 값이 보존된다.

**비용·위험**
- 스냅샷과 원본이 다를 수 있어 UI가 '원본 변경됨'을 설명해야 한다.
- 컬렉션이 늘어 규칙·인덱스·삭제 범위가 커진다(§9.6, §9.7).

**후속 작업**
- DF-006 스키마 문서, DF-021 새 컬렉션 규칙, DF-217·DF-218 O 자동 불러오기와 스냅샷.

## 5 대안

| 대안 | 장점 | 채택하지 않은 이유 |
|---|---|---|
| `users/{uid}` 하위 컬렉션 | 회원 단위 격리 | 트레이너가 쓸 수 없음(dfet:firestore.rules:97-100) |
| SOAP 문서에 측정 임베드 | 읽기 1회 | SOAP 없는 평가·시계열 불가, 문서 크기 증가 |
| 스냅샷 없이 참조만 | 중복 없음 | 확정 기록의 재현성 상실 |

## 6 PRD 근거

D7, §9.1 공통 필드 규약·루트 컬렉션 근거, §9.2, F-SOAP-03, F-ASM-04, F-BC-03.5, §7.8, C-01. 설계 반영 위치: [V1-05 §3~§4](../05_DATA_MODEL_AND_RULES.md#3-엔티티-관계와-공통-규약), [V1-04 §9.1](../04_ARCHITECTURE.md#91-엔티티-책임).

## 7 재검토 조건

- 스냅샷 크기가 문서 한도(1MiB)에 근접하면 상한(≤60)을 낮춘다.
- Q-19(회원 요약 시계열 필드)가 채택되면 memberSummaries 구조를 함께 재검토한다.

## 8 관련 스토리

DF-006, DF-021, DF-127, DF-129, DF-209, DF-217, DF-218.

## 9 변경 이력

| 버전 | 날짜 | 변경 요지 | PR | PRD 영향 |
|---|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성 | — | 없음 |
