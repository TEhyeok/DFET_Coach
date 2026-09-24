# ADR-005 SOAP 스키마 v2와 어휘 단일 원본(contracts/ + 코드 생성)

| 항목 | 내용 |
|---|---|
| 문서 ID | ADR-005 |
| 버전 | v1.0 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | D7, F-SOAP-06, §9.3, 부록 A, 부록 B, MIG-03, R-21, AC-SOAP-06.1~06.3 |
| 관련 에픽·스토리 | EP-02, EP-13 / DF-003, DF-004, DF-005, DF-006, DF-007, DF-009, DF-031, DF-100 |
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

**Accepted** (2026-09-24, 소유자 CJH).

## 2 맥락

- SOAP 작성기 세 곳이 네 가지 어휘로 갈라져 있다. Swift는 metric type을 한글·대문자 rawValue로 쓰고(dfet:trainer_ios/DFETTrainer/Domain/SoapModels.swift:4-8), Flutter는 소문자(`rom`)다. Swift는 모르는 type을 조용히 버린다(dfet:trainer_ios/DFETTrainer/Data/FirebaseTrainerRepository.swift:263-266).
- 기존 호환 테스트는 Swift → Swift 왕복만 확인한다. 스키마 변경 절차는 문서 먼저 → 양쪽 매핑 같은 PR → 왕복 테스트 → 규칙 검토다(dfet:docs/firestore_schema.md:164-169).
- 어휘(metricCode, 부위 코드, 동의 유형, reasonCode 등)는 Swift, Dart, Functions, admin_web 네 곳이 모두 쓴다.

## 3 결정

1. `soap_notes`의 정본은 PRD §9.3 v2다: `schemaVersion = 2`, `metricCode`는 부록 A enum, `value`는 숫자이며 `unit`·`side`·`sourceGrade`를 함께 둔다. `status`는 `draft|finalized`, `diagnosis` 키는 없다.
2. 어휘의 단일 원본은 `contracts/metric-catalog.v1.json`과 `contracts/vocab.v1.json`이다(그 밖에 feature-flags, prohibited-terms, analytics-events, audit-actions). `tool/contracts/generate.mjs`가 다음을 생성해 커밋한다:
   - Swift: `trainer_app/Packages/TrainerCore/Sources/TrainerContracts/Generated/`
   - Dart: `lib/contracts/generated/`
   - Functions: `functions/src/shared/generated/`
   - admin_web: `admin_web/lib/generated/contracts.ts`
3. CI `contracts` job이 ajv 메타 스키마 검증과 `generate.mjs --check`로 드리프트를 막는다.
4. 교차 픽스처 `contracts/fixtures/{soap_v2, soap_legacy}`를 Dart(`SoapNoteV2Codec`)와 Swift(TrainerDomain 코덱)가 모두 읽는다. 알 수 없는 코드는 원문을 보존하고 '해석 불가'로 표시한다. Swift 테스트는 생성기가 `Tests/*/Fixtures/`로 복사한 사본을 읽는다.
5. 스키마를 바꾸는 PR은 `docs/firestore_schema.md`, [V1-05](../05_DATA_MODEL_AND_RULES.md), 양쪽 매핑, 픽스처, 규칙과 규칙 테스트를 같은 PR에서 고친다.
6. v1 쓰기는 MIG-03 적용 시점에 규칙에서 영구 false로 막는다(플래그와 분리, R-21).

## 4 결과

**좋아지는 점**
- 어휘가 한 곳에서 바뀌고 네 소비자가 동시에 따라온다.
- Flutter가 쓴 문서를 Swift가 무손실로 읽는지 CI가 매 PR 확인한다(AC-SOAP-06.1~06.3).

**비용·위험**
- 생성물이 저장소에 커밋돼 diff가 커진다. PR 규칙상 생성물은 400줄 권장 한도에서 제외한다.
- 부록 A.5~A.7은 초안이라 확정(DF-916) 뒤 재생성이 필요하다.

**후속 작업**
- DF-003 카탈로그·어휘, DF-004 생성기와 CI, DF-005 픽스처, DF-006 스키마 문서, DF-007 Dart 코덱, DF-009 Swift 코덱, DF-031 이관 dry-run, DF-100 v1 차단.

## 5 대안

| 대안 | 장점 | 채택하지 않은 이유 |
|---|---|---|
| 클라이언트마다 enum 수기 작성 | 도구 불필요 | 어휘 4벌이 다시 생김(PRD §2.2) |
| JSON Schema만 둠 | 검증은 가능 | 코드 enum 불일치를 잡지 못함 |
| protobuf | 강한 타입 | Firestore 맵 매핑과 맞지 않고 새 도구 필요 |

## 6 PRD 근거

D7, F-SOAP-06, §9.3, 부록 A, 부록 B, MIG-03, R-21, AC-SOAP-06.1~06.3. 설계 반영 위치: [V1-04 §17](../04_ARCHITECTURE.md#17-contracts-단일-원본-파이프라인), [V1-05 §5](../05_DATA_MODEL_AND_RULES.md#5-soap-스키마-v2).

## 7 재검토 조건

- 부록 A 개정(PRD 변경 이력)마다 `metric-catalog`의 major 버전 여부를 판정한다. 호환이 깨지면 `.v2.json`을 추가한다.
- 레거시 호환 기간(P0~P3 종료)이 끝나면 `memberId` 병기 코드를 제거한다.

## 8 관련 스토리

DF-003, DF-004, DF-005, DF-006, DF-007, DF-009, DF-031, DF-100.

## 9 변경 이력

| 버전 | 날짜 | 변경 요지 | PR | PRD 영향 |
|---|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성 | — | 없음 |
