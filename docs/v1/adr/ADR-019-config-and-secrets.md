# ADR-019 Firebase 앱 구성 파일·비밀 관리

| 항목 | 내용 |
|---|---|
| 문서 ID | ADR-019 |
| 버전 | v1.0.1 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | §10.2.4(G-02 plist 관리 방식), §11.2 MIG-01 #5, NFR-02 |
| 관련 에픽·스토리 | EP-01, EP-00 / DF-034, DF-903, DF-923, DF-139 |
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

**Proposed** (2026-09-24). G-02(DF-903)에서 plist 관리 방식을 확정하면 Accepted로 바꾼다.

## 2 맥락

- 새 트레이너 앱의 `GoogleService-Info.plist`가 없다(PRD §10.2.4). 회원 앱은 `ios/Runner/GoogleService-Info.plist`를 flutterfire 설정으로 둔다(dfet:firebase.json:60-66).
- 저장소는 `.env*`와 `functions/.secret.local`을 추적하지 않는다(dfet:.gitignore:50, :56-58). CI는 에뮬레이터용 `.secret.local`을 즉석에서 만든다(dfet:.github/workflows/ci.yml:54).
- HMAC 키는 Secret Manager(`defineSecret('INGEST_HMAC_KEYS')`, dfet:functions/index.js:29)를 쓴다.
- AI 에이전트가 저장소를 다루므로 비밀이 컨텍스트나 로그에 들어가면 안 된다.

## 3 결정

1. `trainer_app/Config/GoogleService-Info.plist`는 추적하지 않는다(`.gitignore`). `project.yml`은 이 파일을 소스로 참조하지 않는다. 앱 타깃 `postBuildScripts`("Copy Firebase config if present", `ENABLE_USER_SCRIPT_SANDBOXING: NO`)가 파일이 있을 때만 번들에 복사한다(plist 없는 CI·에이전트 빌드가 실패하지 않게, SPRINT_01 ASM-S01-12, V1-04 ASM-04-21).
2. 로컬에서는 소유자가 직접 배치한다. CI는 시크릿 `TRAINER_GOOGLE_SERVICE_INFO_PLIST_B64`를 디코딩해 배치하고, 시크릿이 없으면(포크·에이전트 환경) preview 구성 빌드만 만든다.
3. 릴리스 빌드에 plist가 없으면 구성 오류 화면을 띄운다. Preview 저장소로 대체하지 않는다(NFR-03).
4. 그 밖의 비밀: 서명 인증서·App Store Connect API 키·BodyPath 패키지 읽기 토큰은 GitHub Secrets, 초대 코드 HMAC 키는 Secret Manager. 로그·아티팩트에 출력하지 않는다.
5. AI 에이전트는 비밀 파일(`.env*`, `.secret.local`, plist 값, 키)을 열거나 출력하지 않는다.

## 4 결과

**좋아지는 점**
- 비밀과 환경 구성이 저장소 이력에 남지 않는다.
- 에이전트 환경에서도 preview 빌드로 UI 작업이 가능하다.

**비용·위험**
- 새 기기에서 개발할 때 plist 배치 절차가 필요하다([V1-13](../13_DEV_ENVIRONMENT_AND_AGENT_PLAYBOOK.md)).
- 회원 앱과 plist 관리 정책이 달라진다(회원 앱 plist 추적 여부는 이 ADR 범위 밖).

**후속 작업**
- DF-903 Firebase 등록과 방식 결정, DF-034 비추적·주입, DF-139 TestFlight 시크릿, DF-923 BodyPath 읽기 자격.

## 5 대안

| 대안 | 장점 | 채택하지 않은 이유 |
|---|---|---|
| plist를 저장소에 추적 | 설정 간단 | 비밀 정책이 저장소마다 달라지고 이력에 남음 |
| 앱 번들에 환경별 내장 | 전환 쉬움 | 환경 분리 불가, 유출 범위 확대 |

## 6 PRD 근거

§10.2.4(G-02 plist 관리 방식), §11.2 MIG-01 #5, NFR-02. 설계 반영 위치: [V1-04 §19.3](../04_ARCHITECTURE.md#193-비밀과-구성-파일).

## 7 재검토 조건

- G-02에서 plist를 추적하기로 결정하면(값이 비밀이 아니라는 판단) 1·2항을 개정하고 Accepted로 바꾼다.

## 8 관련 스토리

DF-034, DF-903, DF-923, DF-139.

## 9 변경 이력

| 버전 | 날짜 | 변경 요지 | PR | PRD 영향 |
|---|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성 | — | 없음 |
| v1.0(정합 패스 2) | 2026-09-24 | 정합 패스 2: plist 처리 방식 R4. 결정 1항의 `optional: true` 리소스 참조를 `postBuildScripts` 조건부 복사로 교체 | — | 없음 |
| v1.0.1 | 2026-09-24 | 교차 정합성 조정: R4(plist는 project.yml에 참조하지 않고 빌드 후 복사, ASM-S01-12·ASM-04-21과 정합) | — | 없음 |
