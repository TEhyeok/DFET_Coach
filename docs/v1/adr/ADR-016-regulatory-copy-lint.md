# ADR-016 규제 문구 가드: 금지어 단일 원본 + CI 린트 + 서버 거부

| 항목 | 내용 |
|---|---|
| 문서 ID | ADR-016 |
| 버전 | v1.0 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | F-PRIV-06, 부록 C(C.1~C.3), §3.4, §3.8, C-06, AC-C-06.1, AC-SOAP-05.5, M-G1, G-10, MIG-04 |
| 관련 에픽·스토리 | EP-06, EP-10, EP-17 / DF-010, DF-028, DF-029, DF-040, DF-120, DF-309 |
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

- 출시 중인 앱에 규제 경계 문구가 있다: diagnosis 자동 채움(`"diagnosis": selectedMember.subtitle`, dfet:ios/Runner/AppDelegate.swift:3844), '치료계획' 등(:4319, :4328, :4725-4726, :8717), '진단/이슈' 입력(:8958), 회원 앱 가이드·온보딩 문구(PRD §10.5).
- 제품은 웰니스 범위를 유지해야 한다(D1). 문구는 Swift, Dart, TS, 요약 템플릿, 분석 이벤트, audit action에 흩어진다.

## 3 결정

1. 부록 C를 `contracts/prohibited-terms.v1.json`으로 옮긴다: `ruleSets{common, member, trainer}`, `causalPatterns[]`, `abbreviationAllowlist[]`, `allowPaths[]`(레거시 식별자·이관 스크립트 등 예외 경로).
2. `tool/lint/prohibited-terms.mjs`가 검사한다: 트레이너 앱 `Localizable.xcstrings`와 Swift 리터럴, Dart, TS/TSX, 요약·알림 템플릿, 분석 이벤트명, audit action. 공통 세트는 전체, 회원 세트는 회원 노출 문자열, 트레이너 세트는 트레이너 앱에 적용한다. 출시 중인 Runner 문자열도 포함한다.
3. P0 초에는 **보고 모드**(위반 목록 출력, 실패 아님)로 시작하고 DF-028·DF-029 정리 뒤 P0 종료 전에 **차단 모드**(DF-040)로 바꾼다.
4. 같은 JSON을 `createMemberSummary` 서버 검사(`functions/src/summaries/prohibitedTerms.js`, 위반 시 `failed-precondition`과 위치)와 트레이너 앱 인라인 경고(Review, TR-06)가 쓴다.
5. 트레이너 앱의 사용자 노출 문자열은 모두 `Localizable.xcstrings`에 모은다(리터럴 하드코딩 금지).

## 4 결과

**좋아지는 점**
- 금지어 노출을 매 PR에서 막고(M-G1) 서버가 회원 노출을 한 번 더 막는다.

**비용·위험**
- 형태소·띄어쓰기 변형 탐지는 완전하지 않다. 규칙은 [V1-09](../09_ALGORITHMS_SPEC.md)의 매칭 규칙을 따르고 G-10 수동 검수로 보완한다.
- 예외 경로가 남용되면 가드가 약해진다. `allowPaths` 변경은 `regulatory` 라벨과 소유자 검토가 필요하다.

**후속 작업**
- DF-010 JSON과 린트, DF-028·DF-029 문구 정리, DF-040 차단 전환, DF-120 인라인 경고, DF-309 서버 검사.

## 5 대안

| 대안 | 장점 | 채택하지 않은 이유 |
|---|---|---|
| 수동 검수만 | 도구 불필요 | 누락을 막지 못함 |
| 정규식을 여러 곳에 하드코딩 | 빠른 시작 | 세트 사이가 어긋남 |

## 6 PRD 근거

F-PRIV-06, 부록 C(C.1~C.3), §3.4, §3.8, C-06, AC-C-06.1, AC-SOAP-05.5, M-G1, G-10, MIG-04. 설계 반영 위치: [V1-04 §17](../04_ARCHITECTURE.md#17-contracts-단일-원본-파이프라인), 규칙 세트는 [V1-12](../12_COPY_ANALYTICS_AND_LINT.md).

## 7 재검토 조건

- G-05b 결과(웰니스 여부)나 부록 C 개정 시 규칙 세트를 갱신한다.
- 오탐으로 차단이 잦으면 매칭 규칙을 보정하되 예외 경로를 늘리지 않는다.

## 8 관련 스토리

DF-010, DF-028, DF-029, DF-040, DF-120, DF-309.

## 9 변경 이력

| 버전 | 날짜 | 변경 요지 | PR | PRD 영향 |
|---|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성 | — | 없음 |
