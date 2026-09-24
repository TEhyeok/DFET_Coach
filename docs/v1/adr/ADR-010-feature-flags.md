# ADR-010 기능 플래그: appConfig/features 5키 + 규칙 featureOn, 레거시 차단과 분리

| 항목 | 내용 |
|---|---|
| 문서 ID | ADR-010 |
| 버전 | v1.0 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | §6.0.2, §12.3, §12.4, AD-07, AS-18, AS-20, Q-20, AC-IA-02, R-21, R-22, R-29 |
| 관련 에픽·스토리 | EP-07, EP-00 / DF-027, DF-017, DF-331, DF-925, DF-929, DF-934, DF-935, DF-389 |
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

- 현재 플래그는 gut, blood, insights 3키이며 admin_web zod도 3키만 허용한다(dfet:admin_web/app/api/admin/feature-flags/route.ts:10). 회원 앱은 문서가 없으면 모두 false로 본다(dfet:lib/services/clinical_repository.dart:25-32).
- 1인 개발에서 미완성 기능을 장기 브랜치로 두면 미커밋 87개 같은 누적이 다시 생긴다.
- 보안 규칙은 Remote Config를 읽을 수 없다.

## 3 결정

1. `appConfig/features`에 `bodyAssessment`, `bodyComposition`, `soapV2`, `memberShare`, `lidarBeta`를 추가한다. 기본값은 모두 false이고 기존 3키는 그대로다.
2. 플래그 하나로 두 곳을 막는다: 클라이언트 진입점(AppShell이 라우트 생성 전에 숨김)과 규칙 create(`featureOn(key)`). 이미 저장된 기록의 트레이너 열람은 막지 않는다(AS-18).
3. v1 SOAP 쓰기 차단은 플래그와 무관하게 MIG-03 적용 시점부터 영구 적용한다(R-21).
4. 키 목록은 `contracts/feature-flags.v1.json`에서 생성해 zod(admin_web), `schemas/feature-flags.example.json`, Flutter `AppFeatureFlags`, Swift `FeatureFlagKey`가 공유한다. 키나 문서가 없으면 false다.
5. 미완성 기능은 플래그 false 상태로 main에 병합한다.
6. DEBUG 빌드에만 TR-15 로컬 오버라이드 메뉴를 둔다. 오버라이드는 클라이언트 진입점만 바꾸고 규칙은 바꾸지 못한다. 에뮬레이터는 시드 스크립트로 `appConfig/features`를 설정한다. 릴리스에서 오버라이드는 무효다.
7. 플래그는 전역 불리언이다(트레이너 단위 대상 지정 없음, AS-20).
8. 개방 순서는 §12.3이며 소유자 행동으로 실행한다: soapV2·bodyComposition(DF-925) → bodyAssessment(DF-929) → memberShare(DF-934) → lidarBeta(DF-935).

## 4 결과

**좋아지는 점**
- 트렁크 기반 개발이 가능하고, 문제 시 플래그 해제로 즉시 되돌린다(§12.4).
- 규칙이 같은 플래그를 보므로 클라이언트 우회로 생성할 수 없다.

**비용·위험**
- 규칙 create마다 `appConfig/features` get 1건이 추가된다.
- 전역 플래그라 P2의 '내부 트레이너만' 공개는 참여 인원이 내부뿐이라는 사실에 기댄다(Q-20).

**후속 작업**
- DF-027 키 확장과 AD-07, DF-017 진입점 숨김, DF-331 회원 앱 노출 조건.

## 5 대안

| 대안 | 장점 | 채택하지 않은 이유 |
|---|---|---|
| Remote Config | 대상 지정·점진 공개 | 보안 규칙에서 읽을 수 없음 |
| 트레이너 단위 대상 지정 | 세밀한 공개 | Q-20 미결, 규칙 복잡도 증가 |
| 장기 기능 브랜치 | 격리 | 누적·충돌 재발 |

## 6 PRD 근거

§6.0.2, §12.3, §12.4, AD-07, AS-18, AS-20, Q-20, AC-IA-02, R-21, R-22, R-29. 설계 반영 위치: [V1-04 §8.3](../04_ARCHITECTURE.md#83-상태-관리-패턴), [V1-04 §19.2](../04_ARCHITECTURE.md#192-빌드-구성과-실행-인자).

## 7 재검토 조건

- Q-20에서 트레이너 단위 대상 지정이 필요하다고 결정되면 `appConfig/features`에 허용 uid 목록을 두는 방식을 검토한다.

## 8 관련 스토리

DF-027, DF-017, DF-331, DF-925, DF-929, DF-934, DF-935, DF-389.

## 9 변경 이력

| 버전 | 날짜 | 변경 요지 | PR | PRD 영향 |
|---|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성 | — | 없음 |
