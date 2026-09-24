# ADR-018 관리자 판정 통일: custom claim admin == true

| 항목 | 내용 |
|---|---|
| 문서 ID | ADR-018 |
| 버전 | v1.0 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | §9.4 isAdmin 통일 과제, §10.7 역할 판정 통일, §6.7.0, R-23, MIG-02 |
| 관련 에픽·스토리 | EP-04, EP-22 / DF-026, DF-101, DF-385, DF-907 |
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

**Accepted** (2026-09-24, 소유자 CJH). 대체 경로 제거 시점은 DF-026 스파이크와 MIG-02 실사(DF-907) 결과로 확정한다.

## 2 맥락

관리자 판정이 네 벌이다(모두 파일을 열어 확인함).

| 위치 | 현재 판정 |
|---|---|
| Firestore 규칙 `isAdmin()` | `admin` 또는 `super_admin` claim, `admins/{uid}` 승인 문서, `users/{uid}.role == 'admin'` 대체 경로(dfet:firestore.rules:5-20) |
| callable `verifyAdmin` | `callerToken.admin`만(dfet:functions/index.js:79) |
| admin_web `readRole` | `claims.admin === true` 또는 `claims.role === 'admin'`(dfet:admin_web/lib/auth.ts:18-23) |
| Storage 규칙 `isAdmin()` | `admin` 또는 `super_admin` claim(dfet:storage.rules:4-9) |

새 역할(센터 관리자 등)을 더할 때마다 네 곳을 고쳐야 하고, 한 곳이라도 빠지면 권한 우회가 생긴다.

## 3 결정

1. 관리자 판정의 정본은 서버가 부여하는 custom claim `admin == true` 하나다(부여는 기존 `setAdminClaim`, dfet:functions/index.js:96).
2. Firestore 규칙, Storage 규칙, callable `requireAdmin`(`functions/src/shared/auth.js`), admin_web `readRole`이 같은 의미를 쓴다.
3. `admins` 컬렉션은 승인 메타데이터로만 쓴다. `users.role` 대체 경로와 `super_admin` 분기는 MIG-02에서 운영 관리자 전원이 `admin` claim을 가진 것을 확인한 뒤 제거한다(DF-101).
4. 관리자도 원 기록을 클라이언트에서 읽지 못한다. admin_web 서버가 역할·범위를 다시 확인하고 `healthRecordRead`를 남긴 뒤 연다(R-23).
5. P3에서 운영자 관리자와 센터 관리자 역할 claim을 나눈다(DF-385, §6.7.0).

## 4 결과

**좋아지는 점**
- 역할 추가·변경이 한 의미로 일관된다.
- 대체 경로가 없어져 `users` 문서 조작으로 권한을 얻는 경로가 사라진다.

**비용·위험**
- 제거 전 claim 보유 확인이 늦으면 관리자가 잠길 수 있다. 제거 PR은 MIG-02 보고서를 증빙으로 첨부한다.

**후속 작업**
- DF-026 설계 스파이크, DF-907 MIG-02 실행, DF-101 통일, DF-385 역할 분리.

## 5 대안

| 대안 | 장점 | 채택하지 않은 이유 |
|---|---|---|
| 네 벌 유지 | 변경 없음 | 역할 추가 때마다 누락 위험 |
| `admins` 컬렉션을 정본으로 | 콘솔에서 관리 쉬움 | 규칙 get 비용, callable·Storage와 불일치 지속 |

## 6 PRD 근거

§9.4 isAdmin 통일 과제, §10.7 역할 판정 통일, §6.7.0, R-23, MIG-02. 설계 반영 위치: [V1-04 §12.1](../04_ARCHITECTURE.md#121-클레임-모델), [V1-04 §16](../04_ARCHITECTURE.md#16-admin_web-변경).

## 7 재검토 조건

- P3 역할 분리 설계에서 claim 이름이 바뀌면 이 ADR을 대체(Superseded)하는 새 ADR을 쓴다.

## 8 관련 스토리

DF-026, DF-101, DF-385, DF-907.

## 9 변경 이력

| 버전 | 날짜 | 변경 요지 | PR | PRD 영향 |
|---|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성 | — | 없음 |
