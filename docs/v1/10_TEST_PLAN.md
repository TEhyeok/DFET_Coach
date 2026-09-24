# 테스트 계획

| 항목 | 내용 |
|---|---|
| 문서 ID | V1-10 |
| 버전 | v1.0.1 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | §12.5 테스트 전략, §9.3 교차 클라이언트 테스트, §9.4 규칙 테스트 매트릭스(R-01~R-31), §9.5 Storage 규칙 테스트(S-01~S-09), §7.9 판정 테스트 케이스(T01~T25), §10.8 NFR-01~NFR-18, §8.4 상태 매트릭스, §8.6 접근성, §5.4 가드레일(M-G1~M-G5), §12.1·§12.2 단계·게이트, §12.4 롤백, §11 MIG-03·MIG-11, 부록 C |
| 관련 에픽·스토리 | EP-01(DF-011, DF-107), EP-02(DF-004~DF-007, DF-009, DF-033), EP-03(DF-022, DF-023, DF-035, DF-038), EP-06(DF-010, DF-040), EP-12(DF-140, DF-141), EP-13(DF-031, DF-100), EP-14(DF-223, DF-226), EP-21(DF-380). 모든 스토리 카드의 '테스트' 절이 이 문서를 따른다 |
| 변경 규칙 | [문서 변경](01_AGILE_WORKING_AGREEMENT.md#문서-변경) |

## 목차

- [1 이 문서의 범위와 읽는 법](#1-이-문서의-범위와-읽는-법)
- [2 테스트 원칙](#2-테스트-원칙)
- [3 테스트 피라미드(플랫폼별)](#3-테스트-피라미드플랫폼별)
- [4 테스트 환경](#4-테스트-환경)
- [5 테스트 데이터·픽스처 정책](#5-테스트-데이터픽스처-정책)
- [6 계약·교차 클라이언트 테스트](#6-계약교차-클라이언트-테스트)
- [7 보안 규칙·Storage 테스트](#7-보안-규칙storage-테스트)
- [8 Functions 단위·e2e 테스트](#8-functions-단위e2e-테스트)
- [9 알고리즘 벡터](#9-알고리즘-벡터)
- [10 트레이너 앱 테스트](#10-트레이너-앱-테스트)
- [11 회원 앱·admin_web 테스트](#11-회원-앱admin_web-테스트)
- [12 이관 테스트](#12-이관-테스트)
- [13 실기기 수동 프로토콜](#13-실기기-수동-프로토콜)
- [14 성능 테스트](#14-성능-테스트)
- [15 접근성 테스트](#15-접근성-테스트)
- [16 금지어 린트·정적 가드·개인정보 테스트](#16-금지어-린트정적-가드개인정보-테스트)
- [17 회귀 전략](#17-회귀-전략)
- [18 수용 기준 → 테스트 카탈로그](#18-수용-기준--테스트-카탈로그)
- [19 CI 워크플로](#19-ci-워크플로)
- [20 단계별 테스트 종료 기준](#20-단계별-테스트-종료-기준)
- [21 결함 심각도·분류](#21-결함-심각도분류)
- [22 가정(ASM-10-NN)과 충돌](#22-가정asm-10-nn과-충돌)
- [23 변경 이력](#23-변경-이력)

---

## 1 이 문서의 범위와 읽는 법

이 문서는 D-FET Coach v1의 **테스트를 어디에, 어떤 층으로, 어떤 데이터로, 언제 돌리는지** 정한다. 테스트 결정의 근거는 [ADR-013](adr/ADR-013-testing-strategy.md)이고, PRD §12.5 표를 개발 단위로 풀었다.

정본 관계는 다음과 같다. 같은 내용을 이 문서에 다시 적지 않고 링크한다.

| 내용 | 정본 | 이 문서가 하는 일 |
|---|---|---|
| 요구사항·수용 기준(AC-*, C-*, NFR-*) | [PRD](../PRD_V1.md) | AC마다 증명할 층·위치·스토리를 정한다([§18](#18-수용-기준--테스트-카탈로그)) |
| 규칙 테스트 R-01~R-31, S-01~S-09의 Given/When/Expect와 시드 | [V1-05 §9, §16](05_DATA_MODEL_AND_RULES.md) | 파일 배치, 실행, 통과 기준만 적는다([§7](#7-보안-규칙storage-테스트)) |
| 스토리별 테스트 케이스 `TC-NNN-kk` | 백로그 카드([P0](backlog/P0.md), [P1a](backlog/P1a.md), [P1b](backlog/P1b.md), [P2·P3](backlog/P2_P3.md)) | 번호 체계와 최소 시나리오를 정한다 |
| 산식·판정 규칙의 의미 | [V1-09](09_ALGORITHMS_SPEC.md) | 벡터 파일 형식과 실행 위치를 정한다([§9](#9-알고리즘-벡터)) |
| 명령어·로컬 환경 준비 | [V1-13](13_DEV_ENVIRONMENT_AND_AGENT_PLAYBOOK.md) | CI job 정의만 둔다([§19](#19-ci-워크플로)) |
| 화면 상태·접근성 식별자 | [V1-07](07_TRAINER_APP_SPEC.md), [V1-08](08_MEMBER_APP_AND_ADMIN_SPEC.md) | 스냅샷·UI 테스트 규약을 정한다([§10.4](#104-ui-테스트와-상태-매트릭스-스냅샷)) |
| 금지어 JSON 구조·문구 | [V1-12](12_COPY_ANALYTICS_AND_LINT.md) | 린트 도구의 자체 테스트를 정한다([§16](#16-금지어-린트정적-가드개인정보-테스트)) |
| 이관 절차 | [V1-11](11_MIGRATION_RUNBOOK.md) | 이관 스크립트 테스트·리허설을 정한다([§12](#12-이관-테스트)) |
| 결함 보고 양식 | [V1-T13](templates/BUG_REPORT.md), [V1-01 버그](01_AGILE_WORKING_AGREEMENT.md#버그) | 분류 흐름과 CI 실패 처리를 더한다([§21](#21-결함-심각도분류)) |

**독자별 읽는 순서**

| 독자 | 먼저 읽을 절 |
|---|---|
| 소유자(PO·검토자) | §2, §17, §20, §21. 단계 종료 전에는 §18의 해당 단계 표 |
| 트레이너 앱 담당 에이전트 | §2, §4.3, §5, §6, §9, §10, §15, 해당 스토리의 §18 행 |
| 백엔드·규칙 담당 에이전트 | §2, §4.2, §5, §7, §8, §12 |
| 회원 앱·admin_web 담당 에이전트 | §2, §5, §6, §11, §15, §16 |
| Windows/GPU 협업자 | §5(합성 데이터 원칙)만 적용된다. v1 테스트에 협업자 환경은 쓰지 않는다 |

---

## 2 테스트 원칙

### 2.1 합성 데이터 원칙

1. **모든 개발·테스트 데이터는 합성이다.** 실제 회원 이름·사진·수치·uid·이메일·전화번호, `output/`, `tmp/`, 내보내기 파일, 운영 Firestore 데이터를 테스트 입력으로 쓰지 않는다(ADR-013, PRD §0 원칙). 자세한 규약은 [§5](#5-테스트-데이터픽스처-정책).
2. **비밀을 열지 않는다.** `.env*`, `.secret.local`, `GoogleService-Info.plist` 값, 서비스 계정 키 파일(저장소 `functions/`에 키 파일이 있으나 열지 않는다)은 테스트가 읽지 않는다. CI의 에뮬레이터용 HMAC 값처럼 **테스트 전용 가짜 값**만 워크플로에 적는다(기존 예: dfet:.github/workflows/ci.yml:54).
3. **운영 프로젝트에 자동 테스트를 돌리지 않는다.** 운영(`dfetmanage`)에서의 확인은 소유자만, 가상 회원으로, [§4.5](#45-운영-프로젝트에서-하는-확인소유자만)의 항목만 한다.

### 2.2 ID와 이름 규칙

| 종류 | 형식 | 정본 | 예 |
|---|---|---|---|
| PRD 규칙 테스트 | `R-NN`, `S-NN` | PRD §9.4, §9.5 | `R-21`, `S-08` |
| PRD 판정 벡터 | `T01`~`T25` | PRD §7.9 | `T13` |
| 스토리 테스트 케이스 | `TC-NNN-kk`(NNN=DF 번호 세 자리) | 스토리 카드 '테스트' 절 | `TC-116-03` |
| 스토리 전용 수용 기준 | `AC-DF-NNN.k` | 스토리 카드 | `AC-DF-107.1` |
| 교차 테스트(이 문서 소유) | `TC-X-<묶음>-NN` | 이 문서 | `TC-X-SYNC-02` |
| 벡터 사례 | 파일별 접두(`PM-NN`, `SB-NN`) + T 번호 | 벡터 파일 | `PM-03` |
| 실기기 시나리오 | `TC-X-DEV-NN` | [§13](#13-실기기-수동-프로토콜) | `TC-X-DEV-11` |

- 교차 테스트 묶음: `XC`(교차 클라이언트), `SYNC`(동기화·오프라인), `FLAG`(플래그 노출), `A11Y`(접근성), `PERF`(성능), `DEV`(실기기), `LINT`(금지어), `GUARD`(정적 가드), `PRIV`(로그·분석·데이터 위생), `MIG`(이관), `REG`(회귀).
- P0 백로그 일부 카드는 `TC-DFNNN-kk`로 적었다. 같은 뜻의 별칭으로 인정하고 새 카드는 `TC-NNN-kk`를 쓴다([ASM-10-01](#221-가정)).
- **테스트 이름에 ID를 넣는다.** V1-01 [완료 정의](01_AGILE_WORKING_AGREEMENT.md#완료-정의dod) 규칙을 따른다. 교차 테스트는 TC-X ID도 함께 넣는다.
  - JS: `test('R-07 해제 직후 재정렬 전 update 거부', …)`, `test('TC-X-XC-03 AC-SOAP-06.2 레거시 지표 수 보존', …)`
  - Swift: `func test_TC_X_SYNC_02_AC_C_05_1_rulesRejectionNeverEmitsSynced()`
  - Dart: `test('TC-X-XC-01 AC-SOAP-06.1 Dart 작성본 무손실', …)`
- 추적성은 새 도구 없이 grep으로 만든다: `git grep -nE "(AC[-_][A-Z]+[-_][0-9]+[._][0-9]+|R-[0-9]{2}|S-0[1-9]|T[0-2][0-9]|TC-X-[A-Z0-9]+-[0-9]{2})" -- functions test trainer_app admin_web tool`. 단계 종료 검토([V1-T06](templates/PHASE_EXIT_REVIEW.md))에서 [§18](#18-수용-기준--테스트-카탈로그)의 행과 대조한다.

### 2.3 층별 책임

한 수용 기준은 **가장 낮은 층에서 한 번 증명**하고, 위 층은 연결만 확인한다. 같은 판정을 여러 층에서 반복 구현하지 않는다.

| 무엇을 증명하나 | 증명하는 층 | 위 층에서 하는 일 |
|---|---|---|
| 규칙이 허용·거부하는가(권한, 동의, 플래그, 화이트리스트) | 규칙 에뮬레이터(R-·S-) | UI는 거부가 '동기화 실패'로 보이는지만 확인 |
| 서버 함수의 처리 결과(재정렬, 동의 파생, 삭제 범위) | Functions e2e(에뮬레이터) | 앱은 callable 오류 표시만 |
| 산식·판정·조건 비교 | 벡터(순수 단위) | 화면은 값이 그대로 렌더되는지만 |
| 필드 매핑·스키마 호환 | 교차 픽스처(Dart·Swift) | — |
| Outbox 순서·syncState 전이 | SyncEngine 단위(가짜 원격) → 에뮬레이터 통합 | UI는 배지 문구만 |
| 화면 상태·레이아웃 | 스냅샷·골든(상태 매트릭스) | 실기기는 Pencil·회전·멀티태스킹만 |
| 문구 규제 | 금지어 린트 | 서버 요약 검사(P2)는 e2e |
| 카메라·센서·Pencil·Instruments 수치 | 실기기 수동 | — |

---

## 3 테스트 피라미드(플랫폼별)

### 3.1 전체 구성

```
                 ┌──────────────────────────────┐
                 │ 실기기 수동(TC-X-DEV, PERF)   │  단계마다·릴리스 후보마다
               ┌─┴──────────────────────────────┴─┐
               │ UI·스냅샷·골든(XCUITest, Flutter)  │  매 PR(경로 해당 시), 야간 전체
             ┌─┴──────────────────────────────────┴─┐
             │ 통합: 에뮬레이터(규칙 R/S, Functions   │  매 PR
             │ e2e, 트레이너 IT, 이관 리허설)          │
           ┌─┴──────────────────────────────────────┴─┐
           │ 계약: 교차 픽스처, 벡터, 생성물 --check    │  매 PR
         ┌─┴──────────────────────────────────────────┴─┐
         │ 단위: swift test(macOS), node:test, flutter  │  매 PR, 로컬 매 커밋
         │ test, admin_web node:test, 린트·정적 가드     │
         └──────────────────────────────────────────────┘
```

| 층 | 도구 | 실행 위치 | CI job | 시간 예산(가설) |
|---|---|---|---|---|
| 단위(순수 Swift) | `swift test --package-path trainer_app/Packages/TrainerCore` | macOS(시뮬레이터 불필요) | `trainer-app` | 3분 |
| 단위(iOS 전용 Swift) | `xcodebuild test`(iPad 시뮬레이터) | macOS | `trainer-app` | 10분 |
| 단위(Node) | `node --test` | ubuntu | `functions-and-rules`, `contracts`, `copy-lint`, `docs-and-backlog` | 각 2분 |
| 단위·위젯(Dart) | `flutter test` | ubuntu | `flutter` | 8분 |
| 계약 | ajv, `generate.mjs --check`, 교차 픽스처 | ubuntu·macOS | `contracts`, `flutter`, `trainer-app` | 2분 |
| 규칙 에뮬레이터 | `@firebase/rules-unit-testing` | ubuntu + Java 21 | `functions-and-rules` | 5분 |
| Functions e2e | 에뮬레이터 + Admin SDK | ubuntu | `functions-and-rules` | 6분 |
| 이관 | 에뮬레이터 + 스크립트 | ubuntu | `migrations` | 4분 |
| 트레이너 통합 | 에뮬레이터 + `xcodebuild test -only-testing:IntegrationTests` | macOS | `trainer-app-emulator-it` | 20분 |
| UI·스냅샷 | XCUITest, swift-snapshot-testing, Flutter 골든 | macOS·ubuntu | `trainer-app`, `flutter` | 10분 |
| 실기기 | 수동 + Instruments | 소유자 기기 | 없음(V1-T09 기록) | 단계당 반나절 |

### 3.2 트레이너 iPad 앱(`trainer_app/`)

| 층 | 대상 타깃 | 테스트 위치 | 비고 |
|---|---|---|---|
| 순수 단위(macOS) | TrainerContracts, TrainerDomain, PostureMath, SyncEngine, TrainerAnalytics | `trainer_app/Packages/TrainerCore/Tests/<Target>Tests/` | 순수 타깃 5개([V1-04 §6.2](04_ARCHITECTURE.md#62-패키지-두-개로-나누는-이유)). Foundation만. 벡터·픽스처는 저장소 루트 `contracts/`를 읽는다 |
| 시뮬레이터 단위 | LocalStore(SwiftData, 파일 보호), FirebaseData(가짜 SDK 경계), PostureVision(매핑·EXIF), DesignSystem, Feature*(뷰 모델) | `trainer_app/Packages/TrainerKit/Tests/<Target>Tests/` | 파일 보호 속성, Vision, ImageIO는 iOS에서만 의미가 있다 |
| 스냅샷 | DesignSystem 컴포넌트, TR 화면 상태 | `Tests/DesignSystemTests/__Snapshots__/`, 화면 상태는 `Tests/Feature<화면>Tests/__Snapshots__/` | swift-snapshot-testing(테스트 타깃 전용, ADR-013). XCUITest(`UITests/`)에서는 스냅샷을 찍지 않는다 |
| 통합(에뮬레이터) | FirebaseData + SyncEngine + LocalStore 실제 구현 | `trainer_app/IntegrationTests/` | DF-107 하네스 |
| UI | 앱 전체(`--preview-state`) | `trainer_app/UITests/` | 접근성 감사, 흐름 스모크 |
| 실기기 | 앱 전체 | V1-T09 기록 | Pencil, 카메라, 센서, 성능 |

비율 목표(개수 기준, 가설): 순수 단위 60% 이상, 시뮬레이터 단위·스냅샷 25%, 통합 10%, UI 5% 이하. UI 테스트는 흐름당 1개 스모크와 접근성 감사만 두고 판정·계산을 UI에서 검사하지 않는다.

### 3.3 회원 앱(Flutter, `lib/`, `test/`)

| 층 | 대상 | 위치 | 비고 |
|---|---|---|---|
| 단위 | `SoapNoteV2Codec`, `SeriesSegmenter`, `AppFeatureFlags`(8키), 저장소 쿼리 형태 | `test/` | 저장소 테스트는 `fake_cloud_firestore` 같은 새 의존성 없이 쿼리 빌더 인자만 검증(ASM-10-11) |
| 위젯·골든 | `source_grade_chip`, `series_trend_chart`, MB-01~MB-06 상태 | `test/`, `test/goldens/` | 기존 골든 관례(dfet:test/clinical_widgets_golden_test.dart:75) |
| 빌드 | `flutter build web --release`, `apk --debug`, `ios --release --no-codesign` | CI | 기존 job 유지(dfet:.github/workflows/ci.yml:28-29, :81) |
| 수동 | P2 회원 흐름(MB-05→MB-06, MB-01·02) | 실기기 1대 | TC-X-DEV-31 |

### 3.4 Functions·규칙·이관(`functions/`, `firestore.rules`, `storage.rules`)

| 층 | 위치 | 실행 |
|---|---|---|
| 단위(순수 core) | `functions/test/unit/<domain>/<fn>.test.js` | `npm --prefix functions test` |
| 규칙 | `functions/test/firestore-rules.test.js`(기존), `functions/test/rules/*.rules.test.js` | `firebase emulators:exec --only firestore,storage --project dfet-rules-test "npm --prefix functions run test:rules"` |
| e2e | `functions/test/clinical-emulator-e2e.js`(기존), `functions/test/e2e/<fn>.e2e.test.js` | `firebase emulators:exec --only functions,firestore,storage --project dfet-e2e "npm --prefix functions run test:e2e"` |
| 이관 | `functions/test/migrations/*.test.js` | `firebase emulators:exec --only firestore,storage --project dfet-e2e "npm --prefix functions run test:migrations"` |

### 3.5 admin_web

- `admin_web/test/*.test.mjs`(기존 `node --test`, dfet:admin_web/package.json:14): zod 스키마(플래그 8키, bodyChange 정책), 동의 문서 다섯 고지 항목 검증, `recordHealthRead` 호출 여부(라우트 핸들러 단위).
- lint, typecheck, build는 기존대로(dfet:.github/workflows/ci.yml:66-70).

### 3.6 contracts

- `schemas/contracts-meta.schema.json`으로 `contracts/*.json`, 픽스처, 벡터를 검증(ajv), `node tool/contracts/generate.mjs --check`로 네 소비자 생성물 드리프트 검사, metricCode 중복·필수 필드 누락 검사.
- 생성기 자체 테스트: `tool/contracts/test/*.test.mjs`(node:test).

### 3.7 BodyPathCore(BodyPath 저장소, P2 준비)

- `swift test`(저장소 루트 `Package.swift`): `BodyPathResultTests`(DTO 왕복, 검증기 거부 규칙), `BodyPathCoreUITests`(단면 플롯 스냅샷).
- v1 product에 ARKit·SwiftData·UIKit import 0건 정적 검사(NFR-18).
- 기존 `bash tools/check_measurement.sh`는 BodyPath CI에서 그대로 돈다(bodypath:.github/workflows/detail-capture.yml:34).

---

## 4 테스트 환경

### 4.1 환경 목록

| 환경 | 용도 | 데이터 | 누가 | 근거 |
|---|---|---|---|---|
| 로컬·CI 에뮬레이터 | 규칙, Functions e2e, 이관, 트레이너 통합 | 합성 시드 | 에이전트, CI | ADR-013, AS-DEV-02 |
| preview(인메모리) | 스냅샷, XCUITest, 에이전트 수동 확인 | 앱 내장 합성 시나리오 | 에이전트, CI | [V1-04 §19](04_ARCHITECTURE.md) |
| iPad 시뮬레이터 | 단위·UI·통합 | 위 둘 | 에이전트, CI | — |
| 실기기(소유자) | Pencil, 카메라, 센서, 성능, 멀티태스킹 | 합성 참여자(가상 회원, 소유자 본인) | 소유자 | PRD §12.5 |
| 운영 `dfetmanage` | S-09, 감사 로그 설정 확인, 배포 후 스모크 | 가상 회원만(G-04·G-09 전) | 소유자만 | [§4.5](#45-운영-프로젝트에서-하는-확인소유자만) |

스테이징 Firebase 프로젝트는 없다(AS-DEV-02). 기존 문서의 'E2E staging'(dfet:docs/deliverables/06_TEST_AND_RELEASE.md:32)은 v1에서 에뮬레이터 e2e로 대체한다.

### 4.2 Firebase 에뮬레이터

| 항목 | 값 | 근거 |
|---|---|---|
| Firestore 포트 | 18080 | dfet:firebase.json:40 |
| Storage 포트 | 19199 | dfet:firebase.json:44 |
| Auth 포트 | 19099(추가) | [V1-04 §19.1](04_ARCHITECTURE.md), ASM-04-09 |
| Functions 포트 | 5001(추가, 기본값) | 기존 e2e의 `FUNCTIONS_EMULATOR_HOST` 기본값(dfet:functions/test/clinical-emulator-e2e.js:11) |
| singleProjectMode | true(유지) | dfet:firebase.json:49 |
| 프로젝트 ID: 규칙 | `dfet-rules-test` | dfet:.github/workflows/ci.yml:53 |
| 프로젝트 ID: Functions e2e·이관 | `dfet-e2e` | dfet:.github/workflows/ci.yml:55 |
| 프로젝트 ID: 트레이너 통합·로컬 개발 | `demo-dfet` | `demo-` 접두는 실제 리소스에 닿지 않는다([V1-04 §19.1](04_ARCHITECTURE.md)) |
| Java | 21 | dfet:.github/workflows/ci.yml:44-47 |
| Node | 22 | dfet:.github/workflows/ci.yml:39-41 |

`firebase.json` 추가분(P0 시드 스토리가 반영, DF-025·DF-107은 없을 때만):

```json
"emulators": {
  "auth": {"host": "127.0.0.1", "port": 19099},
  "functions": {"host": "127.0.0.1", "port": 5001},
  "firestore": {"host": "127.0.0.1", "port": 18080},
  "storage": {"host": "127.0.0.1", "port": 19199},
  "ui": {"enabled": false},
  "singleProjectMode": true
}
```

- 에뮬레이터를 쓰는 모든 스크립트는 `FIRESTORE_EMULATOR_HOST`(그리고 쓰는 경우 `FIREBASE_AUTH_EMULATOR_HOST`, `FIREBASE_STORAGE_EMULATOR_HOST`)가 없으면 아무것도 쓰지 않고 종료 코드 2로 끝난다(AC-DF-107.6과 같은 가드). 운영 오염을 막기 위해서다.
- 테스트 코드와 스크립트에 운영 프로젝트 ID 문자열(`dfetmanage`)이 들어가면 정적 가드가 실패한다(TC-X-GUARD-09).

### 4.3 시뮬레이터 매트릭스

| ID | 기기 | 방향·크기 | 용도 | CI |
|---|---|---|---|---|
| SIM-1 | iPad Pro 13-inch (M4) | 가로(기본), 세로 | 기본 단위·UI·통합·스냅샷 | 매 PR |
| SIM-2 | iPad Pro 11-inch (M4) | 가로 | AC-SOAP-01.1(11형 캔버스 60%), 레이아웃 스냅샷 | 매 PR(UI 스모크 1개), 야간 전체 |
| SIM-3 | 스냅샷 전용 크기 | 폭 320·375·507pt 고정 | NFR-12 Split View 근사(1/3, 1/2 폭) | 매 PR(스냅샷) |
| SIM-4 | iPad Pro 13-inch, iOS 17.x 런타임 | 가로 | 최저 배포 버전 회귀 | 야간(러너에 런타임이 있을 때, ASM-10-04) |

- 스킴 `DFETTrainer`, 기본 목적지 `platform=iOS Simulator,name=iPad Pro 13-inch (M4)`([V1-01 ASM-01-07](01_AGILE_WORKING_AGREEMENT.md#가정과-스파인-차이-기록)).
- 스냅샷의 Split View 폭은 근사값이다. 실제 1/3 Split View 확인은 실기기(TC-X-DEV-03)에서 한다.
- Q-22 결과 Universal로 바뀌면 iPhone 16 시뮬레이터 compact 스모크를 SIM-5로 추가한다.

### 4.4 실기기 매트릭스

| ID | 기기 | 필수 단계 | 용도 | 근거 |
|---|---|---|---|---|
| DEV-A | 대상 iPad(iPadOS 17 이상, Apple Pencil) | P1a부터 | Pencil, 오프라인, 4방향, Split View·Stage Manager, 성능(NFR-15), 촬영(P1b) | PRD §12.5, NFR-12, NFR-15 |
| DEV-B | 다른 크기 iPad(11형 또는 13형 중 DEV-A와 다른 것) | 있으면 P1a | AC-SOAP-01.1 실측 보조 | AC-SOAP-01.1 |
| DEV-C | LiDAR iPhone Pro(BodyPath 촬영) | P2(G-07a 뒤) | 결과 패키지 생성 → 트레이너 앱 가져오기 | F-LIDAR-01, Q-15 |
| DEV-D | 메시 원본 없는 iPad(보통 DEV-A) | P2 | AC-LIDAR-02.1(2D만, 업로드 요청 0) | NFR-13 |
| DEV-E | iPhone(iOS 15.5 이상) | P2 | 회원 앱 MB-01~MB-06 스모크 | NFR-01 |

- '대상 iPad' 기종은 소유자가 DF-140 첫 기록에 적는다. NFR-15의 수치는 이 기종 기준이다([ASM-10-05](#221-가정)).
- LiDAR iPad Pro는 필수가 아니다. v1 트레이너 앱에는 LiDAR 촬영 진입점이 없다(NFR-13, Q-03).

### 4.5 운영 프로젝트에서 하는 확인(소유자만)

| 확인 | 시점 | 데이터 | 기록 | 스토리 |
|---|---|---|---|---|
| S-09 교차 서비스 `firestore.get` 규칙 동작 | S03(DF-906 뒤) | 가상 회원 1명, 가상 사진 1장 | V1-T07(G-03) | DF-038 |
| Firestore·Storage Data Access 감사 로그 기록 | S08 | 가상 회원 열람 1회 | V1-T07 | DF-932 |
| 규칙·함수 배포 후 스모크(가상 회원 SOAP draft create·거부 1건씩) | 배포마다 | 가상 회원 | 릴리스 운영 이슈([V1-T14](templates/RELEASE_CHECKLIST.md)) | DF-931 |
| MIG-02 읽기 전용 실사 | S04 | 운영 데이터(수량만 출력) | V1-T10 | DF-907 |
| MIG-03~06 적용 후 검증 | S09 | 운영 데이터(수량만) | V1-T10 | DF-924 |

운영에서의 확인 결과는 **건수와 통과 여부만** 기록한다. 문서 ID, uid, 이름, 값은 적지 않는다.

### 4.6 비밀·구성 처리

| 항목 | CI 처리 | 없을 때 |
|---|---|---|
| `trainer_app/Config/GoogleService-Info.plist` | 시크릿 `TRAINER_GOOGLE_SERVICE_INFO_PLIST_B64`를 복호화해 배치(ADR-019, DF-034) | preview 구성으로만 빌드·테스트. 통합 테스트는 plist 없이 `FirebaseOptions`를 코드로 만든다(DF-107) |
| Functions 에뮬레이터 비밀 | 테스트 전용 가짜 값을 `functions/.secret.local`로 생성(기존 dfet:.github/workflows/ci.yml:54). P2에는 초대 코드 HMAC 가짜 키 추가 | — |
| BodyPath 패키지 읽기 자격(P2) | 시크릿(DF-923), 로그 미출력 | trainer-app job이 BodyPath 의존 전(P2 전)이므로 영향 없음 |

- 워크플로에서 시크릿 값을 `echo`하지 않는다. 아티팩트에 plist를 올리지 않는다(TC-X-PRIV-06).

---

## 5 테스트 데이터·픽스처 정책

### 5.1 금지 데이터와 허용 데이터

| 금지 | 허용 |
|---|---|
| 실제 회원·트레이너 이름, 사진, 필기, 수치, uid, 이메일, 전화번호, 생년월일 | 합성 ID·표시명([§5.2](#52-합성-식별자표시명-규약)) |
| `output/`, `tmp/`, 운영 내보내기, 운영 Firestore·Storage에서 가져온 문서 | 손으로 쓴 합성 픽스처, 스크립트로 생성한 합성 문서 |
| 운영 스크린샷(실데이터 포함) | preview·에뮬레이터 스크린샷 |
| 실제 신체 사진(회원), 얼굴이 식별되는 제3자 사진 | 코드로 그린 합성 이미지, 소유자 본인 자기 촬영(저장소 커밋 금지, 테스트 뒤 삭제), 라이선스가 확인된 마네킹·공개 이미지(ASM-P1b-39) |
| 비밀 파일, 서비스 계정 키 | 테스트 전용 가짜 비밀(워크플로에 명시) |

### 5.2 합성 식별자·표시명 규약

| 대상 | 규칙 테스트(`functions/test/rules/_harness.js`) | 에뮬레이터·통합·개발 시드 | 픽스처(`contracts/fixtures`) |
|---|---|---|---|
| 트레이너 uid | `trainerA`, `trainerB` | `synthTrainerA`, `synthTrainerB` | `fx-trainer-001` |
| 회원 uid | `member1`, `member2` | `synthMember0001`~`synthMember0003` | `fx-member-001` |
| 대기 회원 ID | `pendA` | `SYNTHpending00000001` | `fx-pending-001` |
| 관리자 | `adminX` | `synthAdmin` | — |
| 문서 ID | `N1`, `P1`, `B1`, `C1`, `M1` | `SYNTH` 접두 20자 | `fx-` 접두(예: `fx-note-v2-001`. 레거시 재현 예외 `native_fx_<yyyymmdd>`, `member-00000000-0000-4000-8000-00000000000N`) |
| 표시명 | `가상회원 대기` 등 | '가상회원 가/나/다' | '가상 회원 A' |
| 이메일 | 없음 | `synthTrainerA@example.invalid` | `@example.invalid`만 |
| 기준 시각 | `2026-11-16T01:00:00Z`(V1-05 §16) | 실행 시각 기준 상대값 | ISO 8601(`Z` 또는 오프셋) |

- 규칙 테스트의 짧은 ID는 V1-05 §16을 따른다.
- 픽스처(`contracts/fixtures`)는 `fx-` 접두, 에뮬레이터·통합·개발 시드는 `synth`/`SYNTH` 접두(R2). 픽스처 규약의 정본은 [P0 DF-005](backlog/P0.md#fixture-contract), 시드의 정본은 [ASM-10-24](#221-가정)다.
- 이메일 도메인은 `example.invalid`만 쓴다(RFC 2606 예약 도메인이라 실제로 전송되지 않는다).

### 5.3 파일 배치

| 경로 | 내용 | 소유 스토리 |
|---|---|---|
| `contracts/fixtures/soap_v2/*.json` | v2 문서: 지표 0개, O 행(romDeg·mmtGrade), 스냅샷(P1b), 대기 회원, addenda | DF-005 |
| `contracts/fixtures/soap_legacy/*.json` | 레거시 네 어휘, 두 status, 두 category 표기, 인라인 필기, `member-` seed, 한글 enum | DF-005 |
| `contracts/fixtures/soap_legacy/expected_v2/*.json` | 위 입력의 MIG-03 기대 v2 결과 | DF-031 |
| `contracts/fixtures/body/*.json` | 신체조성·둘레 경계 문서 | DF-127 |
| `contracts/fixtures/summaries/*.json` | memberSummaries(shared, revoked 묘비, 비렌더 출처 포함) | DF-309, DF-316 |
| `contracts/vectors/posture-metrics.v1.json` | 자세 산식 벡터 | DF-201 |
| `contracts/vectors/series-break.v1.json` | 조건 키·seriesBreak 벡터 | DF-216 |
| `contracts/vectors/change-eval.v1.json` | T01~T25 | DF-380 |
| `functions/test/rules/_harness.js` | 규칙 테스트 하네스·시드·합성 문서 생성기([§7.2](#72-파일-배치df-022df-035-카드-기준)) | DF-022(DF-035가 생성기 추가) |
| `functions/test/fixtures/emulator-seed.v1.json` | 통합·개발 시드 | P0 시드 스토리(DF-042 채택 시 DF-042, 아니면 DF-012)가 기본 파일·스크립트, DF-107이 P1a 추가분·변형(`no-consent`, `consent-fail`) |
| `functions/test/fixtures/emulator-seed.<변형>.v1.json` | 오류 주입용 변형(`emulator-seed.no-consent.v1.json`, `emulator-seed.consent-fail.v1.json`) | P0 시드 스토리(DF-042 채택 시 DF-042, 아니면 DF-012)가 기본 파일·스크립트, DF-107이 P1a 추가분·변형(`no-consent`, `consent-fail`) |
| `tool/lint/test/fixtures/{prohibited-terms,static-guards}/` | 린트 자체 테스트 입력(위반·정상) | DF-010, DF-011 |
| `trainer_app/Packages/TrainerCore/Tests/<Target>Tests/Resources/`(순수 타깃) | 타깃 전용 입력. 공용 픽스처·벡터는 복사하지 않고 `#filePath`로 `contracts/`를 직접 읽는다 | 각 스토리 |
| `trainer_app/Packages/TrainerKit/Tests/<Target>Tests/Resources/`(iOS 타깃, 예: PostureVisionTests 합성 이미지) | 타깃 전용 입력(합성 이미지 생성 코드 우선) | 각 스토리 |

- 픽스처는 **저장소 루트 `contracts/` 한 곳**에만 두고 Dart·Swift·Node가 같은 파일을 읽는다. 복사본을 만들지 않는다(생성물 복사는 enum·상수만, ADR-005).
- Swift 테스트는 `URL(fileURLWithPath: #filePath)`에서 저장소 루트를 찾아 읽는다(DF-201 카드 관례). Flutter 테스트는 작업 디렉터리가 저장소 루트다.

### 5.4 에뮬레이터 시드

| 시드 | 내용 | 적재 |
|---|---|---|
| 규칙 시드 S0·SS0 | V1-05 §16 | 테스트 `beforeEach`에서 `env.withSecurityRulesDisabled`(기존 패턴 dfet:functions/test/firestore-rules.test.js:31-61) |
| 통합·개발 시드 `emulator-seed.v1.json` | 가상 트레이너 2명(trainer claim), 가상 회원 3명(synthTrainerA가 0001·0002 담당), 대기 회원 1명, `appConfig/features` 8키(`soapV2`·`bodyComposition` true, 나머지 false), published 동의 문서 5종(`{type}--1.0`), 회원 0001의 ①②③ 상태 | `node functions/scripts/dev/seed-emulator.js --seed functions/test/fixtures/emulator-seed.v1.json`(스크립트·기본 파일은 P0 시드 스토리, P1a 추가분은 DF-107, [ASM-10-24](#221-가정)) |
| 단계별 추가 | P1b: `bodyAssessment` true, 스테이션 프로필. P2: `memberShare` true, 초대 코드 발급 전 대기 회원, bodyChange 정책 없음 | 같은 스크립트, 변형 파일 |

- 시드의 `appConfig/features`는 규칙과 같은 값이어야 한다. 플래그가 false면 create가 거부되므로, 개발 중 '동기화 실패'가 플래그 탓인지 먼저 확인한다([V1-13](13_DEV_ENVIRONMENT_AND_AGENT_PLAYBOOK.md) 흔한 실패).

### 5.5 합성 이미지

| 용도 | 방법 | 커밋 |
|---|---|---|
| 산식·좌표 변환 | 이미지 없이 좌표만(벡터) | 벡터 JSON |
| EXIF·GPS 제거(DF-205) | 테스트가 `CGImageDestination`으로 GPS 태그를 넣은 JPEG를 만들고, 제거 함수 통과 후 `CGImageSourceCopyPropertiesAtIndex`로 GPS 딕셔너리 부재 확인 | 생성 코드만 |
| 얼굴 가림 썸네일(DF-205) | 단색 배경에 타원·눈 모양을 그린 합성 얼굴 이미지. `VNDetectFaceRectanglesRequest`가 검출하면 얼굴 영역이 가려졌는지, 검출하지 못하면 썸네일 전체가 가려졌는지 검증([ASM-10-07](#221-가정)) | 생성 코드만 |
| Vision 좌우 매핑(AC-ASM-02.3) | 단위: Vision 관절 이름 → `LandmarkCode` 매핑표와 좌표 원점 변환(좌하단→좌상단)을 순수 함수로 검증. 종단: 라이선스가 확인된 정면 전신 이미지 1장(마네킹 또는 CC0)으로 시뮬레이터·실기기 확인 | 매핑 테스트는 CI. 종단 이미지는 라이선스 확인 후에만 커밋(ASM-10-06) |
| 촬영 흐름 UI | preview 시나리오의 번들 합성 이미지(단색 실루엣) | 합성 PNG |

### 5.6 픽스처 자동 검사

`static-guards`(DF-011)에 다음 검사를 둔다. 대상은 `contracts/fixtures/**`, `contracts/vectors/**`, `functions/test/**`, `test/**`, `trainer_app/**/Tests/**`, `trainer_app/IntegrationTests/**`, `trainer_app/UITests/**`, `admin_web/test/**`.

| ID | 검사 | 실패 조건 |
|---|---|---|
| TC-X-GUARD-08 | 이메일 형식 | `@` 뒤 도메인이 `example.invalid`, `example.com`이 아닌 이메일 |
| TC-X-GUARD-08 | 전화번호 형식 | `01[016789]-?\d{3,4}-?\d{4}` |
| TC-X-GUARD-09 | 운영 프로젝트 ID | 테스트·스크립트 안의 `dfetmanage`(배포 문서·firebase.json 제외) |
| TC-X-GUARD-10 | 비밀 파일 참조 | `service-account`, `GoogleService-Info.plist` 경로를 읽는 테스트 코드 |
| TC-X-GUARD-11 | 이미지 커밋 | 위 경로의 `.jpg`·`.jpeg`·`.heic` 신규 파일(허용 목록 `tool/lint/test-images.allow`에 라이선스 메모와 함께 등록한 것만 통과) |

---

## 6 계약·교차 클라이언트 테스트

PRD §9.3 '변경 절차와 교차 클라이언트 테스트'와 AC-SOAP-06.1~06.3을 구현한다. 기존 Swift 호환 테스트는 Swift→Swift 왕복만 검증하고 `isSharedWithMember == true`를 기대한다(dfet:trainer_ios/DFETTrainerTests/SoapNoteFirestoreCompatTests.swift:12-18). 새 테스트는 이것을 대체하며 옮기지 않는다.

### 6.1 픽스처 형식

Firestore 타입을 JSON으로 잃지 않도록 픽스처는 다음 봉투를 쓴다. V1-05의 JSON 예시(`"<serverTimestamp>"`, ISO 문자열)는 읽기용 표기다. 봉투·태그·파일 이름·합성 ID의 정본은 [P0 DF-005 픽스처 규약](backlog/P0.md#fixture-contract)이다.

파일 하나에 문서 하나, 최상위 키는 정확히 `_fixture`, `path`, `data` 셋이다(AC-DF-005.5). 아래는 규약의 `soap_v2/finalized_no_metrics.json` 예시다.

```json
{
  "_fixture": {
    "id": "soap_v2/finalized_no_metrics",
    "description": "확정 최소 요건(회원·날짜·한 줄·다음 계획)만 채운 v2 노트",
    "writer": "synthetic",
    "prdRefs": ["AC-SOAP-06.3", "§6.4.4"],
    "expect": {"roundTrip": "identical", "metricCount": 0, "uninterpretable": 0}
  },
  "path": "soap_notes/fx-note-v2-001",
  "data": {
    "schemaVersion": 2,
    "trainerId": "fx-trainer-001",
    "authorUid": "fx-trainer-001",
    "memberUid": "fx-member-001",
    "memberId": "fx-member-001",
    "pendingMemberId": null,
    "sessionDate": {"$ts": "2026-09-28T01:00:00Z"},
    "status": "finalized",
    "quickNote": "가상 회원 A, 오른쪽 어깨가 뻐근하다고 말함",
    "objective": {
      "metrics": [],
      "refs": {"postureAssessmentIds": [], "bodyCompositionRecordIds": [], "circumferenceMeasurementIds": [], "bodyScanIds": []},
      "snapshots": []
    },
    "plan": {"nextSession": "어깨 가동성 운동 이어서 진행", "homeExercise": ""},
    "legalNature": "coachingRecord",
    "isSharedWithMember": false,
    "finalizedAt": {"$ts": "2026-09-28T02:00:00Z"},
    "createdAt": {"$ts": "2026-09-28T01:00:05Z"},
    "updatedAt": {"$ts": "2026-09-28T02:00:00Z"}
  }
}
```

O 행과 정수 태그는 `soap_v2/draft_rom_mmt_pain.json`(`expect.metricCount: 2`)의 `data.objective.metrics`에서 다음처럼 쓴다.

```json
[
  {"metricCode": "romDeg", "value": 110, "unit": "deg", "side": "right", "sourceGrade": "trainerObserved",
   "joint": "hip", "motion": "flexion", "activeOrPassive": "active"},
  {"metricCode": "mmtGrade", "value": {"$int": 4}, "unit": "grade", "side": "left", "sourceGrade": "trainerObserved",
   "muscleGroup": "hipAbductors"}
]
```

- `_fixture.writer`: `synthetic`(손으로 작성) | `dart`(DF-007 기록 모드) | `swift`(DF-009 기록 모드). `_fixture.expect` 키와 파일 목록은 규약 1번·4번을 따른다.
- 코덱과 스키마 검증은 `data`만 대상으로 한다. `_fixture`와 `path`는 테스트 하네스만 읽는다(이관 하네스는 `path`로 시드한다).

| 표기 | 뜻 | Swift 로더 | Dart 로더 |
|---|---|---|---|
| `{"$ts": "<ISO 8601>"}` | Firestore Timestamp | `Date` | `Timestamp` |
| `{"$int": n}` | 정수여야 하는 값(`painNrs`, `mmtGrade.value`, `inkRevision`, `trialIndex`) | `Int64` | `int` |
| 맨 숫자 | 실수 허용 값(`value`) | `Double` | `num` |
| `{"$bytes": "<base64>"}` | 레거시 인라인 바이너리(`drawingData`) | `Data` | `Blob` |
| `{"$serverTimestamp": true}` | 쓰기 페이로드의 서버 시각 자리 | `FieldValue.serverTimestamp()` 대응 DTO | 같음 |

- 로더: Swift `trainer_app/Packages/TrainerCore/Tests/TrainerDomainTests/Support/FixtureLoader.swift`, Dart `test/support/fixture_loader.dart`. 두 로더는 위 표 외의 `$` 키를 만나면 실패한다.
- **비교 규칙(정규화 비교):** 키 정렬, `$int` 값은 정수로만 같음, 실수 값은 `abs(a-b) < 1e-9`, 문자열은 NFC 정규화 후 비교(한글 조합형·완성형 차이 방지), `null`과 키 없음은 **다르게** 본다(스키마가 둘을 구분한다).

### 6.2 교차 왕복 흐름

```
[contracts/fixtures/soap_v2/*.json] ──Dart decode──▶ SoapNoteV2(Dart) ──Dart encode──▶ out_dart.json
                                  └──Swift decode─▶ SoapNoteV2(Swift) ─Swift encode─▶ out_swift.json
검사 1: normalize(out_dart)  == normalize(fixture.data)          (Dart 무손실)
검사 2: normalize(out_swift) == normalize(fixture.data)          (Swift 무손실)
검사 3: Swift가 out_dart를, Dart가 out_swift를 다시 읽어 검사 1·2 반복 (교차 방향)
```

- 검사 3은 CI에서 두 job 사이에 파일을 주고받지 않는다. 대신 **양쪽 모두 같은 원본에 무손실**이면 교차 방향도 성립하므로, 검사 1·2를 두 플랫폼이 각각 통과하는 것으로 AC-SOAP-06.1을 증명한다. 추가로 `contracts/fixtures/soap_v2/`에는 `writer: dart`(Flutter 모델이 만든 모양)와 `writer: swift`(트레이너 앱이 만든 모양) 픽스처를 모두 둔다. 새 쓰기 모양이 생기면 해당 쪽 스토리가 픽스처를 추가한다.
- 트레이너 앱 쓰기 페이로드 테스트는 `createdAt`이 update 페이로드에 없고 `updatedAt`만 서버 시각 자리인지 따로 본다(AC-SOAP-04.6, NFR-07).

### 6.3 레거시 읽기

| 픽스처 묶음 | 내용 | 기대(두 플랫폼 공통) |
|---|---|---|
| `soap_legacy/flutter_rom_mmt_test_general.json` | type `rom`·`mmt`·`test`·`general`, value 문자열 `"110-120"`·`"4+"`, status `complete`, completedCategories `subjective` | 지표 수 불변, `test`는 '해석 불가'로 원문 보존 |
| `soap_legacy/trainer_ios_korean_enum.json`, `soap_legacy/status_shared_korean.json` | type `ROM`·`MMT`·`통증`·`특수검사`·`기능검사`, workflow `작성 중`, status `공유됨`(`isSharedWithMember: true`), completedCategories `S` | 같음. 한글 enum을 버리지 않음(반례 dfet:trainer_ios/DFETTrainer/Data/FirebaseTrainerRepository.swift:263-266) |
| `soap_legacy/schema_doc_vocab.json` | type `pain`·`functional`·`specialTest`, status `완료` | 같음 |
| `soap_legacy/native_bridge_label_only.json`, `soap_legacy/drawing_data_bytes.json` | `rom`·`mmt`·`exercise` label만, `nativeInkDataBase64`, `drawingData`(`$bytes`) | 같음. 인라인 필기는 읽기만 하고 v2로 다시 쓰지 않음 |
| `soap_legacy/native_bridge_label_only.json`(회원 seed 부분) | memberId `member-00000000-0000-4000-8000-000000000001` | 읽기 가능, '회원 연결 없음' 표시, 쓰기 경로 없음 |
| `soap_v2/finalized_no_metrics.json` | 지표 0개 | 열고 저장해도 원문 동일, 데모 문장 0(AC-SOAP-06.3) |
| `soap_v2/forward_compat_unknown_code.json` | `metricCode: "futureMetricX"` 행 1개 + 정상 행 1개 | 원문 보존, '해석 불가' 표시(F-SOAP-06.2) |

### 6.4 생성물 드리프트와 메타 스키마

- `node tool/contracts/generate.mjs --check`: 생성물(Swift `TrainerContracts/Generated`, Dart `lib/contracts/generated`, `functions/src/shared/generated`, `admin_web/lib/generated`)이 커밋본과 다르면 실패하고 다른 파일 목록을 출력한다.
- `ajv`로 `contracts/*.json`, `contracts/fixtures/**`, `contracts/vectors/**`를 `schemas/contracts-meta.schema.json`과 개별 스키마(`schemas/soap-note-v2.schema.json` 등)로 검증한다. 픽스처의 `document`는 `$ts` 등을 풀어낸 뒤 검증한다.
- 규칙 파일의 enum 리터럴(예: `status in ['draft','finalized']`, `fasting in ['yes','no','unknown']`)을 contracts와 대조하는 검사도 `--check`에 포함한다(ASM-05-18).

### 6.5 케이스(TC-X-XC)

| ID | 검증 | 층·위치 | 증명 AC | 구현 스토리 |
|---|---|---|---|---|
| TC-X-XC-01 | 모든 `soap_v2` 픽스처를 Dart가 decode→encode해도 정규화 비교 동일 | `test/contracts/soap_v2_fixture_test.dart` | AC-SOAP-06.1 | DF-007 |
| TC-X-XC-02 | 같은 픽스처를 Swift가 decode→encode해도 동일 | `TrainerDomainTests/SoapNoteV2FixtureTests.swift` | AC-SOAP-06.1, NFR-07 | DF-009 |
| TC-X-XC-03 | 레거시 픽스처 전체를 두 플랫폼이 읽을 때 지표 수(보존분 포함)가 원문과 같고, 해석 불가 항목 수가 같다 | 위 두 파일의 legacy 그룹 | AC-SOAP-06.2 | DF-007, DF-009 |
| TC-X-XC-04 | 알 수 없는 metricCode 원문 보존과 '해석 불가' 플래그 | 같음 | F-SOAP-06.2 | DF-007, DF-009 |
| TC-X-XC-05 | 지표 0개 노트 열기·저장 후 원문 동일, 데모 문장 목록(dfet:trainer_ios/DFETTrainer/Domain/SoapModels.swift:111-119의 문장) 포함 0 | Swift 단위 | AC-SOAP-06.3 | DF-009 |
| TC-X-XC-06 | `$int` 필드를 Swift가 `Int64`로 쓰는지(실수로 쓰면 규칙 `is int` 거부) | Swift 단위 | §9.3 타입, R-01 전제 | DF-009 |
| TC-X-XC-07 | MIG-03 기대 결과(`soap_legacy/expected_v2/`)를 두 플랫폼이 똑같이 읽는다(표시 모델 비교) | 두 플랫폼 | MIG-03 수용 기준 '똑같이 읽는다' | DF-031(픽스처), DF-007·DF-009(테스트 추가) |
| TC-X-XC-08 | `generate.mjs --check` 드리프트 0 | `contracts` job | F-SOAP-06.4 | DF-004 |
| TC-X-XC-09 | 모든 픽스처·벡터가 메타 스키마와 개별 스키마 통과 | `contracts` job | §9.3 변경 절차 | DF-004, DF-006 |
| TC-X-XC-10 | `painRegions`에 부록 A.7 밖 코드나 한글이 있으면 Swift·Dart 모두 쓰기 거부(읽기는 원문 보존) | 두 플랫폼 단위 | AC-SOAP-02.7 | DF-117, DF-007 |
| TC-X-XC-11 | `series-break.v1.json` 전 사례를 Swift·Dart가 같은 세그먼트로 나눈다 | 두 플랫폼 | AC-VIZ-03.1, C-02 | DF-216 |

---

## 7 보안 규칙·Storage 테스트

### 7.1 범위와 통과 기준

- 대상: PRD §9.4 R-01~R-31, §9.5 S-01~S-09, V1-05 §9.4의 스토리 전용 경계 케이스(AC-DF-020.x, AC-DF-021.x), 기존 describe 블록(dfet:functions/test/firestore-rules.test.js:67, :105, :151, :209, :226).
- 통과 기준: **100%**(M-G4, G-03). 규칙 테스트는 재시도·격리(quarantine)를 허용하지 않는다([§21.3](#213-ci-실패불안정-테스트)).
- 각 R·S 케이스의 Given/When/Expect와 시드는 [V1-05 §9, §16](05_DATA_MODEL_AND_RULES.md)이 정본이다.

### 7.2 파일 배치(DF-022·DF-035 카드 기준)

파일 이름과 R-ID 배정의 정본은 구현 스토리 카드다([P0 백로그](backlog/P0.md) DF-022·DF-035·DF-023 '구현 노트'). 에이전트는 카드를 받아 구현하므로 이 표는 카드를 그대로 옮긴다. V1-05 §9.1의 옛 배치(`access`, `measurements`, `consent_pending`)와 다르면 이 표와 카드가 우선한다(CF-10-13).

| 파일(`functions/test/rules/`) | 케이스 | 스토리 |
|---|---|---|
| `_harness.js` | `initRulesEnv({projectId, rulesTransform})`, 인증 컨텍스트, 시드 S0·SS0, 합성 문서 생성기(`seedTrainer`, `seedConsent`, `seedFlags`, `v2SoapDoc(overrides)`. DF-035가 `bodyCompDoc()`, `postureDoc()`, `tapeDoc()`, `pendingMemberDoc()` 추가) | DF-022(먼저 병합하는 쪽이 만들고 나중 쪽은 재사용) |
| `soap_notes.rules.test.js` | R-01~R-04, R-08, R-09, R-13, R-24, AC-DF-020.1~020.7 경계 케이스 | DF-022 |
| `assignment.rules.test.js` | R-05~R-07 | DF-022 |
| `member_access.rules.test.js` | R-10~R-12, R-23, AC-DF-020.9 | DF-022 |
| `legacy_switch.rules.test.js` | R-21, AC-DF-020.8 | DF-022 |
| `body_composition.rules.test.js` | R-14, R-17, R-27, AC-DF-021.3 | DF-035 |
| `posture.rules.test.js` | R-15, R-16, AC-DF-021.2 | DF-035 |
| `pending_members.rules.test.js` | R-18, R-19, R-30, R-31, AC-DF-021.1, AC-DF-021.5 | DF-035 |
| `server_only.rules.test.js` | R-20, AC-DF-021.6 | DF-035 |
| `flags.rules.test.js` | R-22, R-29 | DF-035 |
| `policies.rules.test.js` | R-25 | DF-035 |
| `circumference.rules.test.js` | R-26, AC-DF-021.4 | DF-035 |
| `consent_read.rules.test.js` | R-28, AC-DF-021.7 | DF-035 |
| `storage.rules.test.js` | S-01~S-08 | DF-023 |
| `users_in_query.rules.test.js` | `users where documentId in [≤10개]` 보조 테스트(R 번호 없음, AC-DF-013.3) | DF-013 |
| `queries.rules.test.js` | 화면별 목록 쿼리 '허용' 증명(아래 7.4의 DF-024 행). DF-024 카드에는 아직 없는 파일이다(CF-10-14) | DF-024 |

- 실행: `"test:rules": "node --test --test-concurrency=1 test/firestore-rules.test.js \"test/rules/**/*.test.js\""`. 파일마다 projectId를 `dfet-rules-<파일명>`으로 달리 써서 파일 사이 데이터 간섭을 막는다(DF-022 카드, ASM-P0-26). `emulators:exec --project dfet-rules-test`는 에뮬레이터 기동용 이름일 뿐이다.
- R 행 수: DF-022 16행(R-01~R-13, R-21, R-23, R-24), DF-035 15행(R-14~R-20, R-22, R-25~R-31). 합계 31행으로 R-01~R-31 전부를 한 번씩 덮는다.

### 7.3 작성 규칙

1. 테스트 이름은 `R-NN`/`S-NN`으로 시작한다. 한 R 행에 허용·거부가 모두 있으면 `R-09a`, `R-09b`처럼 나눈다.
2. **바뀐 규칙마다 허용 1건 + 거부 1건 이상.** 거부만 있는 테스트는 규칙이 전부 막혀도 통과하므로 무의미하다.
3. 쓰기 테스트는 서버 시각을 `serverTimestamp()`로 보낸다. 시각 비교(`== request.time`)를 위반하는 클라이언트 시각 케이스를 따로 둔다(AC-DF-020.2).
4. R-21은 규칙 파일의 레거시 스위치 함수(`legacyV1WritesOpen()`)를 `false`로 치환해 로드한 환경에서 `soapV2` true·false 두 시드로 돈다(V1-05 R-21 행). 스위치가 `true`인 현재 상태의 테스트도 함께 두어 MIG-03 전후를 모두 고정한다.
5. R-31 같은 연도 경계는 실행 연도로 계산한다(`new Date().getUTCFullYear() - 14`, V1-05 §16). 12월 31일 KST 15시 이후 UTC 연도 차이는 ASM-05-02를 따른다.
6. 요청당 문서 조회 수 한도(10) 초과 여부는 가장 조회가 많은 경로(대기 회원 + 동의 2종 + 플래그 + ⑤)로 한 번 더 확인한다(ASM-05-20).

### 7.4 쿼리 증명 테스트

트레이너 앱·회원 앱이 실제로 보내는 목록 쿼리를 규칙 에뮬레이터에서 그대로 실행해 **허용**되는지 확인한다. 쿼리가 규칙과 맞지 않으면 런타임에 빈 목록이 아니라 거부가 나고, 앱은 '불러오기 실패'를 보이게 된다(PRD §9.6).

| 쿼리(PRD §9.6 사용처) | 주체 | 기대 | 스토리 |
|---|---|---|---|
| `soap_notes where trainerId==uid orderBy sessionDate desc limit 25` | trainerA | 허용 | DF-024 |
| `soap_notes where trainerId==uid && memberUid==m orderBy sessionDate desc` | trainerA | 허용 | DF-024 |
| `soap_notes where memberUid==m`(trainerId 없음) | trainerA | 거부(R-13) | DF-022 |
| `postureAssessments / bodyCompositionRecords / circumferenceMeasurements where trainerId==uid && memberUid==m orderBy <측정 시각> desc` | trainerA | 허용 | DF-024 |
| 대기 회원 기록 `where trainerId==uid && pendingMemberId==p` | trainerA | 허용(ASM-05-27) | DF-024 |
| `pendingMembers where trainerId==uid && status=='pending'` | trainerA | 허용 | DF-024 |
| `memberSummaries where memberUid==uid orderBy sharedAt desc` | member1 | 허용(R-11) | DF-022 |
| `consentRecords where subjectUid==m orderBy recordedAt desc` | trainerA | 허용(R-28) | DF-035 |
| `insightPolicyVersions where kind=='bodyChange' && status=='approved' && active==true` | trainerA | 허용(R-25) | DF-035 |
| `users where documentId in [≤10개]` | trainerA | 허용 여부 확인. 거부면 문서별 get으로 전환(ASM-05-28) | DF-013 |

- 에뮬레이터 규칙 테스트는 복합 인덱스를 요구하지 않는다. 인덱스 누락은 `firestore.indexes.json`과 앱 쿼리 목록을 비교하는 단위 검사(`functions/test/unit/indexes.test.js`: 쿼리 카탈로그 JSON의 각 쿼리에 대응하는 인덱스가 있는지)로 잡는다(DF-024). 쿼리 카탈로그는 [V1-06](06_API_SPEC.md)의 Firestore 쿼리 카탈로그가 정본이다.

### 7.5 S-09 실환경 확인(소유자)

| 단계 | 내용 |
|---|---|
| 전제 | DF-906(Storage 서비스 계정 교차 조회 권한) 완료, 규칙 태그 배포 |
| 데이터 | 가상 회원 1명(`synthMember0001` 형식 uid를 운영에 만들지 않는다. 운영 전용 가상 계정 1개, 표시명 '가상회원 가'), 합성 JPEG 1장 |
| 절차 | ① 가상 담당 관계 준비(DF-905) ② 트레이너 계정으로 draft 체형 문서 create ③ `postureAssessments/{id}/front.jpg` 업로드(허용 기대) ④ 비담당 가상 트레이너로 읽기(거부 기대) ⑤ 테스트 문서·파일 삭제 |
| 기록 | [V1-T07](templates/GATE_EVIDENCE.md) G-03 절에 통과·거부 결과와 날짜만. 실패하면 ADR-007 대안 결정(DF-038) |

---

## 8 Functions 단위·e2e 테스트

### 8.1 구조

- 각 함수 파일은 handler와 순수 core를 따로 export한다(ADR-017). core는 Firestore를 인자로 받지 않는 순수 함수(입력 → 결정)이고 `functions/test/unit/<domain>/<fn>.test.js`에서 검증한다. handler는 e2e에서 검증한다.
- e2e는 에뮬레이터(Auth·Firestore·Storage·Functions)에서 Admin SDK로 시드하고, 클라이언트 SDK(`firebase` devDependency, dfet:functions/package.json의 devDependencies)로 callable을 호출한다. callable 리전은 `asia-northeast3`로 호출한다(NFR-16).
- 트리거·스케줄 함수는 e2e에서 **내부 모듈로 직접 호출**하는 경로(예: `syncRecordAccessKeys.run({memberUid})`)와 트리거 경로를 모두 둔다. 스케줄 함수는 시계 주입(`now` 인자)으로 기한 경계를 검증한다.
- 모든 쓰기 함수에 **멱등 테스트**(같은 입력 2회 → 결과 동일, 중복 문서 0)와 **감사 기록 테스트**(action이 `contracts/audit-actions.v1.json`에 있고 metadata가 화이트리스트 키만)를 둔다(V1-01 Functions DoD).

### 8.2 함수별 필수 시나리오

스토리 카드의 `TC-NNN-kk`가 아래 시나리오를 구체화한다. 카드에 없는 시나리오가 있으면 카드에 추가한다.

| 함수 | 단계 | 필수 시나리오(e2e 중심) | 증명 | 스토리 |
|---|---|---|---|---|
| `syncRecordAccessKeys` | P0 | ① 담당 해제 → 6개 컬렉션 `trainerId=null` ② ④ 없이 재배정 → 새 담당 0건 ③ ④ 있으면 finalized·confirmed·active만 새 담당으로, draft는 제외 ④ 두 번 실행해도 같음 ⑤ 520건(청크 경계) 처리 ⑥ 레거시 `authorUid` 채움 ⑦ 중간 실패 주입 후 재시도 완료 | F-LINK-03.4~03.6, F-LINK-05.4, AC-LINK-05.4, R-06 전제 | DF-025 |
| `assignMemberToTrainer`/`removeMemberFromTrainer`(수정) | P0 | 트랜잭션 후 재정렬 호출, 감사 `metadata.handover`, 다른 담당이 있을 때 conflict, 이름·리전 불변 | AD-01, NFR-16 | DF-025 |
| `recordConsent` | P1a | ① draft 버전 거부 ② 비담당 거부 ③ 한 트랜잭션에 append + 상태 갱신(부분 실패 없음) ④ 같은 시각 철회 우선 ⑤ 서명 PNG가 `consentSignatures/{recordId}.png` ⑥ ② 철회 → 요약 revoked·`trainerId=null` ⑦ ③ 철회 → 이후 체형 create 거부 ⑧ `consentChanged` 감사 ⑨ `clientCaptureId` 재시도 멱등(ASM-05-12) ⑩ 가입 회원 현장 동의(`subjectUid`) | F-PRIV-01.4, F-PRIV-02.1~02.3, F-PRIV-03.2·03.3·03.6, AC-PRIV-02.1, AC-PRIV-03.1 | DF-109, DF-112 |
| `auditSoapFinalized` | P1a | draft→finalized에서만 1건, 다른 update에는 0건, 수치·본문 없음 | F-SOAP-04.7 | DF-123 |
| `logRecordAccess` | P1a | 호출당 `healthRecordRead` 1건, 비담당 permission-denied, 수치 없음 | AC-PRIV-05.2 | DF-115 |
| `deleteMemberCascade` | P1a | PRD §9.7 범위표 대상을 모두 시드한 뒤 두 경로(탈퇴·관리자)가 같은 결과. soap_notes 두 키, posts 확장자 4종, `clinical-ingest` rawPath, 새 Storage prefix 0건. consentRecords·auditLogs 보존. `dataDeleted` 건수만 | AC-PRIV-04.1, F-PRIV-04.1~04.3 | DF-132 |
| `purgeExpiredRecords` | P1a | 시계 주입: 대기 회원 cancelled 후 기한 내 파기, pending 보유기간 경과 → expired → 파기, ③ 철회 → 사진·좌표 파기와 각도 유지, N=0이면 보유기간 파기 비활성 | AC-LINK-01.4, AC-LINK-01.5, AC-PRIV-02.2, AC-PRIV-02.3 | DF-133 |
| `alertOverdueObligations` | P1a | 기한 초과 항목마다 구조화 로그 1줄, 로그에 uid·이름·값 없음 | F-PRIV-04.4, F-PRIV-07.4 | DF-134 |
| `submitRightsRequest`/`exportMemberData` | P1a | dueAt = 접수 + 10일, zip에 범위표 대상 모두, 서명 URL만(클라이언트 직접 읽기 거부 S-07), `rightsRequestHandled` 2건(접수·완료) | AC-PRIV-07.1 | DF-135 |
| `aggregateOpsMetrics` | P1a | 합성 주간 데이터로 M-03 분자·분모 계산, 식별자·값 필드 0 | §5.3 | DF-137 |
| `issueInviteCode`/`redeemInviteCode` | P2 | 원문 미저장, 재발급 시 이전 revoked, 만료 거부, 다른 uid 재사용 거부, 중단 후 재개(기록 수 동일·Storage 경로 불변), 1시간 5회 제한, claim 계정 거부, 트랜잭션 원자성 | AC-LINK-02.1~02.5 | DF-304, DF-305 |
| `createMemberSummary`/`revokeMemberSummary` | P2 | 금지어 위반 시 `failed-precondition`과 위치, draft·대기 회원 거부, 제외 필드 0(필드 검사), 사진은 ③+토글일 때만, 묘비 문서, 재공유 = revoke + 새 문서 | AC-SOAP-05.1~05.12, AC-PRIV-06.2, AC-LINK-05.3 | DF-309, DF-310, DF-313 |
| `getSharedPhotoUrl` | P2 | 소유·shared·경로 포함 확인, revoked 뒤 발급 거부, 만료 뒤 403 | F-LINK-05.6, AC-LINK-05.3 | DF-314 |
| `linkMemberAlias` | P2 | (system, externalId) 유일, 비담당 permission-denied, `userId` 병기, 기존 임상 e2e 회귀 | AC-LINK-04.1~04.3 | DF-319 |
| `verifyPostureConfirmed` | P2 | 필수 랜드마크 미확정 confirmed 문서 → draft 복귀 + `postureReverted` | AC-ASM-04.1(P2) | DF-324 |
| `evaluateChange` | P3 | T01~T25 벡터 전부(엔진 사례), 클라이언트 판정 코드 0(정적 검사) | §7.9 | DF-380 |

### 8.3 기존 테스트 유지

- `functions/test/clinical.test.js`(단위)와 `functions/test/clinical-emulator-e2e.js`(e2e)는 v1 내내 초록이어야 한다. `memberAliases`를 확장할 때 특히 기존 임상 수집 e2e를 회귀로 본다(AC-LINK-04.3).
- `package.json` 스크립트 변경은 [§19.6](#196-스크립트-변경).

---

## 9 알고리즘 벡터

벡터는 **한 파일을 여러 구현이 읽는** 표 기반 테스트다. 의미·산식은 [V1-09](09_ALGORITHMS_SPEC.md)가 정본이고, 여기서는 파일 형식과 실행 위치를 정한다.

### 9.1 공통 형식

```json
{
  "schemaVersion": 1,
  "vector": "posture-metrics",
  "rounding": "halfAwayFromZero",
  "cases": [
    {"id": "PM-01", "trace": ["AC-ASM-03.1"], "input": {}, "expected": {}, "note": "선택"}
  ]
}
```

- 모든 사례에 `id`와 `trace`(PRD 또는 AC-DF ID 1개 이상)가 있어야 한다(메타 스키마 검사).
- 사례를 지우지 않는다. 산식이 바뀌면 `vector` 파일 버전(`.v2.json`)을 새로 만든다.
- 모든 값은 합성이다.

| 파일 | 실행하는 구현 | CI job | 스토리 |
|---|---|---|---|
| `contracts/vectors/posture-metrics.v1.json` | Swift `PostureMathTests`(macOS `swift test`) | `trainer-app` | DF-201 |
| `contracts/vectors/series-break.v1.json` | Swift `TrainerDomainTests`, Dart `test/series_segmenter_test.dart` | `trainer-app`, `flutter` | DF-216 |
| `contracts/vectors/change-eval.v1.json` | Node `functions/test/unit/change/evaluateChange.test.js`(엔진 사례), 요약·차트·표시 사례는 해당 스토리 테스트 | `functions-and-rules`, `trainer-app`, `flutter` | DF-380~DF-383 |

### 9.2 posture-metrics.v1.json

형식과 PM-01~PM-03은 DF-201 카드에 있다. 최소 사례는 다음과 같다.

| ID | 입력 요지 | 기대 | 증명 |
|---|---|---|---|
| PM-01 | 2000×2000, c7(0.5,0.5), tragusLeft(0.55,0.45), 회전 0 | CVA 45.0°, `photoManual` | AC-ASM-03.1 |
| PM-02 | 견봉 좌(0.6,0.4), 우(0.4,0.41) | `shoulderTiltAngle` 2.9°, `side=left` | AC-ASM-03.1 |
| PM-03 | 1600×1200, c7(0.5,0.5), tragusLeft(0.5625,0.4) | CVA 50.2°(픽셀 변환 회귀) | AC-ASM-03.4 |
| PM-04 | PM-01 좌표를 −2° 회전해 만든 점 + `imageRotationDeg=+2` | PM-01과 같은 값 | AC-ASM-03.2 |
| PM-05 | PM-01에서 c7 `confirmed=false` | CVA `photoAuto`, 다른 지표 영향 없음 | AC-ASM-03.3 |
| PM-06 | 기본 옵션 + ASIS 쌍 존재 | `pelvicTiltFrontal` 결과 없음 | AC-ASM-03.6 |
| PM-07 | 높이 차 0.5픽셀 | 값 0.0, `side=none` | F-ASM-03.4, ASM-05-19 |
| PM-08 | 이주가 C7보다 아래 | CVA 음수 | F-ASM-03.3 |
| PM-09 | 반올림 경계(x.x5) | halfAwayFromZero | F-ASM-03.6 |
| PM-10 | 정면 사진, 대상자 오른쪽 견봉이 이미지 왼쪽 | `acromionRight.x < 0.5` 입력에서 `side` 해부학 기준 | F-ASM-02.7 |

### 9.3 series-break.v1.json

DF-216 카드가 형식을 정했다. 최소 사례: 기기 변경 분할(AC-VIZ-03.1, AC-BC-03.3), `fasting=unknown`은 항상 분할, 프로토콜 변경 사유 우선, 카메라 높이·거리 허용 범위 안은 같은 세그먼트, `tape`와 `observedSection` 별도 시리즈(C-02, AC-VIZ-03.6), 누락일 점 없음(C-04, T22), 측면 방향 변경(`sagittalLeft`→`sagittalRight`) 분할(T06).

### 9.4 change-eval.v1.json(T01~T25)

판정 엔진은 서버 한 곳(ADR-009)이지만 T 사례 중 일부는 요약 생성·차트·표시를 검증한다. 그래서 사례마다 `harness`를 둔다.

```json
{
  "schemaVersion": 1,
  "vector": "change-eval",
  "precision": {"deg": 0.1, "kg": 0.1, "percent": 0.1, "cm": 0.1, "point": 1},
  "policies": {
    "draft-cva": {"version": "bodyChange--0.9-test", "active": true,
                  "metrics": {"craniovertebralAngle": {"mdcValue": 5.52, "mdcSource": "literature",
                                                       "conditionKeys": ["view", "clothing"]}}},
    "test-mdc-5.5": {"version": "bodyChange--0.9-t03", "active": true,
                     "metrics": {"craniovertebralAngle": {"mdcValue": 5.5, "mdcSource": "literature", "conditionKeys": []}}},
    "none": null
  },
  "cases": [
    {"id": "T01", "trace": ["§7.9"], "harness": "engine", "family": "posture",
     "metricCode": "craniovertebralAngle", "policy": "draft-cva",
     "comparison": {"value": 45.0, "sourceGrade": "photoManual", "protocolVersion": 1, "view": "sagittalLeft",
                    "clothing": "fitted", "device": {"model": "iPad16,6"}},
     "current":    {"value": 50.5, "sourceGrade": "photoManual", "protocolVersion": 1, "view": "sagittalLeft",
                    "clothing": "fitted", "device": {"model": "iPad16,6"}},
     "expected": {"changeStatus": "withinError", "delta": 5.5, "reasonCode": null,
                  "mdcSource": "literature", "policyVersion": "bodyChange--0.9-test"}},
    {"id": "T09", "trace": ["§7.9", "AC-C-03.1"], "harness": "engine", "family": "posture",
     "metricCode": "craniovertebralAngle", "policy": "none",
     "comparison": {"value": 45.0}, "current": {"value": 47.0},
     "expected": {"changeStatus": "pendingPolicy"}},
    {"id": "T24", "trace": ["§7.9", "§7.6"], "harness": "summary",
     "expected": {"highlight.changeStatus": null, "memberBadge": false}}
  ]
}
```

| harness | 사례 | 실행 위치 | 스토리 |
|---|---|---|---|
| `engine` | T01~T07, T09~T21, T23 | `functions/test/unit/change/evaluateChange.test.js` | DF-380 |
| `display` | T08(문헌값 문구와 URL 표시) | 트레이너 앱 `FeatureInsightsTests`(표시 모델 단위) | DF-382 |
| `chart` | T22(누락 점 없음) | Swift `DesignSystemTests`, Dart `test/series_trend_chart_test.dart` | DF-130, DF-131 |
| `summary` | T24, T25 | `functions/test/e2e/createMemberSummary.e2e.test.js` | DF-381 |

- 경계 사례(T02, T03, T04)는 부동소수 오차에 민감하다. 엔진은 저장 정밀도 단위의 정수(예: 각도 ×10)로 Δ를 계산하고, 테스트는 `delta`를 정밀도 단위로 비교한다([ASM-10-08](#221-가정)).
- T16은 정책에 tape MDC가 있을 때와 없을 때 두 하위 사례(`T16a`, `T16b`)로 나눈다.
- P3 전에는 `engine` 사례 가운데 T09만 의미가 있다(정책 없음 → `pendingPolicy`). 파일은 P1b에 초안을 만들고(DF-216 뒤) 엔진 테스트는 DF-380에서 켠다.

### 9.5 계산 규칙 단위 테스트(벡터 파일 없음)

한 구현만 쓰는 계산은 벡터 파일 대신 해당 타깃의 표 기반 단위 테스트로 둔다.

| 규칙 | 테스트 위치 | 경계 사례 | 증명 | 스토리 |
|---|---|---|---|---|
| BMI 파생 | `TrainerDomainTests/BodyCompositionRulesTests` | 키 없음 → `derived` 없음, 70kg·170cm → 24.2 | F-BC-01.3, AC-BC-01.5 | DF-127 |
| `timeOfDayBand` | 같음 | KST 10:59:59 → morning, 11:00 → midday, 16:59:59 → midday, 17:00 → evening, UTC 저장값 기준 변환 | F-BC-01.2 | DF-127 |
| 신체조성 범위 | 같음 | 체지방률 0 허용·100 허용·100.1 거부, 체중 0 거부·0.1 허용·600 허용 | F-BC-03.2, AC-BC-03.2 | DF-127 |
| 교차 일관성 경고 | 같음 | 체지방량 > 체중 경고·저장 허용 | AC-BC-03.4 | DF-127 |
| 소수점 쉼표 | 같음 | '72,5' → 72.5 | F-BC-03.1 | DF-127 |
| 줄자 3회째 개방 | `TrainerDomainTests/TapeTrialRulesTests` | 차이 0.9 → 닫힘, 1.0 → 열림, 평균 표시 0.1 반올림 | F-ASM-06.4, AC-ASM-06.2 | DF-129 |
| 확정 최소 요건 | `TrainerDomainTests/FinalizeRequirementsTests` | §6.4.4 #1~#4 각각 누락, A 비어 있음은 권장 배지만, 미완성 O 행 자동 제외 목록 | AC-SOAP-04.5, AC-SOAP-02.4 | DF-122 |
| O 후보 선택 | `TrainerDomainTests/ObjectiveCandidateTests` | 같은 날 기본 선택, 이전은 종류별 1건, draft·voided 제외, 재검사 묶음 첫 기록만 | AC-SOAP-03.1, AC-SOAP-03.2, AC-ASM-05.2 | DF-217 |
| `elapsed_band` | `TrainerAnalyticsTests` | 구간 경계값(구간 정의는 V1-12) | NFR-10, M-01 | DF-126 |
| 만 14세 | `TrainerDomainTests/AgeGateTests` | 실행 연도 − 14 경계(ASM-05-02) | AC-LINK-01.6 | DF-108 |

---

## 10 트레이너 앱 테스트

### 10.1 순수 타깃 단위(macOS `swift test`)

| 타깃 | 테스트 파일(예) | 핵심 검증 | 스토리 |
|---|---|---|---|
| TrainerContractsTests | `GeneratedCatalogTests.swift` | 생성 enum이 contracts와 같은 수·순서, 알 수 없는 원문 보존 케이스 존재 | DF-004 |
| TrainerDomainTests | `SoapNoteV2FixtureTests.swift`, `FinalizeRequirementsTests.swift`, `BodyCompositionRulesTests.swift`, `TapeTrialRulesTests.swift`, `SeriesSegmenterVectorTests.swift`, `ObjectiveCandidateTests.swift`, `AgeGateTests.swift`, `MemberKeyTests.swift` | 코덱, 확정 요건, 입력 검증, 세그먼트, 후보 선택, `MemberKey`에 로컬 UUID 불가 | DF-009, DF-122, DF-127, DF-129, DF-216, DF-217, DF-108 |
| PostureMathTests | `PostureMetricVectorTests.swift`, `ConfirmabilityTests.swift`, `GeometryTests.swift` | 벡터, 확정 가능 여부, 좌표 범위 | DF-201 |
| SyncEngineTests | `OutboxOrderTests.swift`, `SyncStateTransitionTests.swift`, `BackoffTests.swift`, `RelaunchResumeTests.swift` | 가짜 `RemoteWriter`·`BinaryUploader`·`CallableClient`로 순서, 전이, 백오프, 재적재 | DF-015 |
| TrainerAnalyticsTests | `EventAllowlistTests.swift`(예) | 허용 목록 밖 이벤트·속성은 컴파일 또는 테스트 실패, `DebugSink` 기본(NFR-10, AC-SOAP-01.10 전제) | DF-126 |

- 순수 타깃 5개는 `trainer_app/Packages/TrainerCore/Tests/<Target>Tests/`에 두고 `swift test --package-path trainer_app/Packages/TrainerCore`로 macOS에서 돈다. 픽스처·벡터는 `#filePath`로 저장소 루트 `contracts/`를 직접 읽고 번들 복사 단계를 두지 않는다([ASM-10-25](#221-가정)).
- 순수 타깃은 `SWIFT_STRICT_CONCURRENCY=complete`로 빌드한다. 경고를 오류로 본다.
- 시간·ID·네트워크는 주입한다: `Clock`(가짜 시계), `DocumentIDGenerator`(고정 ID), 원격 프로토콜 가짜 구현. 테스트에서 `Date()`·`UUID()`를 직접 부르지 않는다.
- 가짜 원격은 호출 로그(`[(kind, path, at)]`)를 남겨 순서를 비교한다.

### 10.2 시뮬레이터 단위(`xcodebuild test`, SIM-1)

| 타깃 | 핵심 검증 | 증명 | 스토리 |
|---|---|---|---|
| LocalStoreTests | 엔티티 저장·재적재, 파일 `NSFileProtectionComplete`·`isExcludedFromBackup` 속성, 업로드 확인 7일 뒤 삭제·`awaitingConsent` 7일 파기(가짜 시계) | NFR-04, NFR-17, AS-32 | DF-014 |
| FirebaseDataTests | 매핑 단위: `createdAt`은 create에만, `updatedAt` 서버 시각, `WriteAck.serverCommitted`·`hasPendingWrites` 반영, 알 수 없는 metric 보존, 오류를 빈 목록으로 바꾸지 않음(`throws` 확인), `print(` 대신 `Logger` | NFR-06, NFR-07, F-SOAP-04.8 | DF-104, DF-013 |
| PostureVisionTests | 관절 매핑·좌표 원점 변환, EXIF·GPS 제거(합성 JPEG), 얼굴 가림 썸네일 생성, 수평계 게이트 로직(가짜 CoreMotion 값) | AC-ASM-02.3(매핑), AC-ASM-01.4, AC-ASM-01.2 | DF-207, DF-205, DF-204 |
| DesignSystemTests | 컴포넌트 스냅샷, `MetricRow`는 sourceGrade 없으면 렌더 안 함, `SeriesTrendChart`는 등급 혼합 입력을 거부, 판정 불가 배지에 사유 없으면 `assertionFailure`(테스트에서 실패) | AC-C-01.1, AC-VIZ-07.1, AC-VIZ-07.2, AC-VIZ-07.4 | DF-016, DF-130 |
| Feature*Tests | 뷰 모델: 동의 게이트, 플래그 게이트, 오류 → '불러오기 실패', 확정 대기 잠금 | [§18](#18-수용-기준--테스트-카탈로그) 해당 행 | 화면 스토리 |

### 10.3 통합(에뮬레이터)과 오류 주입

하네스는 DF-107이 만든다: `trainer_app/IntegrationTests/Support/EmulatorHarness.swift`(plist 없이 `FirebaseOptions` 구성, 프로젝트 `demo-dfet`, Auth 19099·Firestore 18080·Storage 19199·Functions 5001), `FaultInjection.swift`(`NetworkFault.offline()/online()` = `disableNetwork/enableNetwork`, 시드 변형 선택, `OutboxReload.simulateRelaunch()` = SyncEngine 폐기 후 LocalStore에서 재적재).

오류 주입 수단:

| 주입 | 방법 | 쓰는 시나리오 |
|---|---|---|
| 네트워크 끊김 | `Firestore.disableNetwork()`, Storage·Functions 호출은 가짜 `URLProtocol`로 실패 | 오프라인 저장·복구 |
| 규칙 거부 | 시드 변형(`emulator-seed.no-consent.v1.json`: 대상 회원 `memberConsentStates` 없음) | syncFailed |
| 동의 실패 | 시드 변형(`consent-fail`: published 문서 없음 → `recordConsent`가 `failed-precondition`) | 순서 보장 |
| 업로드 불일치 | 테스트 전용 `BinaryUploader` 데코레이터가 SHA-256을 바꿔 보고 | uploadMismatch |
| 프로세스 재시작 | `OutboxReload.simulateRelaunch()` | 재시작 후 이어서 |
| 재시도 한도 | 백오프 상한을 테스트 구성으로 낮춤(예: 3회, 10ms) | retryLimit |
| 시계 | `Clock` 주입(7일 파기, 백오프) | 파기·백오프 |

**동기화·오프라인 시나리오(TC-X-SYNC)**

| ID | Given | When | Then | 층 | 증명 | 구현 |
|---|---|---|---|---|---|---|
| TC-X-SYNC-01 | 한 회원의 Outbox에 동의 캡처, 부모 문서, 필기 바이너리, 경로 기록, 확정 | 동기화 | 관찰 순서가 `recordConsent → 부모 create 커밋 → 업로드 완료 → 경로 update → finalize`이고 다른 순서가 0 | 단위(가짜) + 통합 | NFR-05 | DF-015, TC-107-02 |
| TC-X-SYNC-02 | 규칙이 거부하는 시드 | SOAP draft 저장·동기화 | 스트림 `localSaved → syncing → syncFailed(.rulesDenied)`, `synced` 방출 0, 로컬 원본 유지, 재시도 버튼 | 통합 | AC-C-05.1, AC-SOAP-01.4, NFR-06 | TC-107-01 |
| TC-X-SYNC-03 | 네트워크 끊김 | Live 저장 → 재시작 흉내 → 네트워크 복구 | 서버 문서 정확히 1건, `synced`, 필기 파일 1개 | 통합 | AC-SOAP-01.3, NFR-04 | TC-107-03 |
| TC-X-SYNC-04 | 동의 캡처가 서버에서 실패 | 동기화 | 그 회원의 부모 create 시작 0, 항목은 `awaitingConsent` 유지 | 통합 | NFR-05, AC-PRIV-03.3 | TC-107-04 |
| TC-X-SYNC-05 | 부모 문서가 서버에 없음(생성 실패) | 업로드 큐 처리 | Storage 업로드 시도 0 | 단위(가짜) | NFR-05, S-03 전제 | DF-015 |
| TC-X-SYNC-06 | 업로드 SHA-256 불일치 | 업로드 완료 | 경로 기록 안 함, `syncFailed(.uploadMismatch)` | 단위 | NFR-05 | DF-104 |
| TC-X-SYNC-07 | 재시도 한도 3회 구성, 항상 실패하는 원격 | 동기화 | 3회 후 `syncFailed(.retryLimit)`, 수동 재시도 시 다시 시도 | 단위 | NFR-05, NFR-06 | DF-015 |
| TC-X-SYNC-08 | 업로드 도중 | 재시작 흉내 | 재적재 후 업로드 완료, 중복 파일 0 | 단위 + 통합 | NFR-05 | DF-015, DF-107 |
| TC-X-SYNC-09 | 오프라인 | 확정 | 노트 '확정 대기'·편집 잠금, 복구 후 서버 `status=finalized`, `finalizedAt`이 서버 시각(클라이언트 시각과 다름을 가짜 시계로 확인) | 통합 | AC-SOAP-04.5 | DF-122 |
| TC-X-SYNC-10 | 확정 전환을 규칙이 거부(예: 필수 요건 누락을 서버가 거부) | 동기화 | `syncFailed`와 사유, 잠금 해제로 편집 가능 | 통합 | F-SOAP-04.2 | DF-122 |
| TC-X-SYNC-11 | 오프라인 현장 동의 후 기록, 7일간 미확인(가짜 시계) | 파기 점검 | 해당 draft 로컬 0건, 동의 캡처도 파기 | 단위 | F-PRIV-03.7, AS-32 | DF-111 |
| TC-X-SYNC-12 | 대기 항목 3건 | 전역 대기 수 스트림 구독 | 3 → 동기화마다 감소 → 0. 재시작 후에도 같은 수 | 단위 | NFR-06(대기 건수 표시) | DF-015 |
| TC-X-SYNC-13 | 같은 draft를 세 번 저장 | 동기화 | 서버 `createdAt` 불변, `updatedAt`만 변화 | 통합 | AC-SOAP-04.6, NFR-07 | DF-104 |
| TC-X-SYNC-14 | 같은 회원·같은 날 두 세션 | 오프라인에서 모두 저장 후 복구 | 서버 문서 2건, ID 서로 다름, `native_` 접두 0 | 통합 | AC-SOAP-01.6, R-24 | DF-116 |
| TC-X-SYNC-15 | 오프라인 체형 draft(사진 2장) | 복구 | 부모 → 사진 → 경로 순, `synced`는 두 사진 모두 확인 뒤 | 통합 | AC-ASM-01.5, AC-ASM-04.5 | DF-206 |
| TC-X-SYNC-16 | ③ 철회 뒤 기기에 해당 회원 로컬 사진 | 다음 동기화 | 로컬 사진 0, 업로드 시도 0 | 통합 | NFR-17, AC-PRIV-02.3 | DF-112 |
| TC-X-SYNC-17 | 기기 잠금(보호 데이터 접근 불가) 상태 | 백그라운드 동기화 시도 | `protectedDataUnavailable`로 미루고 실패로 표시하지 않음 | 단위 | NFR-17, ASM-05-32 | DF-015 |

### 10.4 UI 테스트와 상태 매트릭스 스냅샷

**상태 주입.** UI 테스트와 스냅샷은 DEBUG 전용 실행 인자로 화면 상태를 만든다.

| 인자 | 뜻 | 예 |
|---|---|---|
| `--preview-state=<화면>.<상태>` | 인메모리 합성 시나리오로 해당 화면·상태를 연다 | `--preview-state=tr09.pendingPolicy`, `--preview-state=tr04.offline` |
| `--preview-flags=<키>:<bool>,…` | 플래그 로컬 값(DEBUG 전용) | `--preview-flags=soapV2:false,bodyComposition:false` |
| `--reset-local-store` | 테스트 전 로컬 저장소 초기화 | — |
| `--use-emulator` | 에뮬레이터 연결(통합 스모크) | — |

- 인자 이름은 기존 `--preview-*` 관례를 잇는다(dfet:trainer_ios/DFETTrainer/App/DFETTrainerApp.swift:30-55, ASM-P1b-34). Release 빌드는 모두 무시한다([V1-04 §19.2](04_ARCHITECTURE.md)). Release 빌드에서 이 인자가 무시되는지는 TC-X-FLAG-05가 확인한다.
- **상태 이름**은 PRD §8.4 열 이름을 영문 키로 쓴다: `empty`, `noConsent`, `pendingPolicy`, `indeterminate`, `beta`, `offline`, `syncFailed`, `comingSoon`, 그리고 화면 고유 상태(`loadFailed`, `awaitingConsent`, `pendingFinalize`).

**상태 매트릭스 스냅샷(AC-IA-01).** PRD §8.4 화면별 적용 매트릭스의 O 칸마다 스냅샷 1장 이상. 파일 이름은 `<화면>.<상태>.<크기>.png`(예: `tr11.noConsent.13in-landscape.png`).

| 화면 | 필수 상태(§8.4 O 칸) | 스토리 |
|---|---|---|
| TR-01 | empty, offline, syncFailed, comingSoon | DF-125, DF-141 |
| TR-02 | empty, noConsent, offline, loadFailed | DF-113, DF-141 |
| TR-03 | empty, noConsent, pendingPolicy, indeterminate, beta(P2), offline, loadFailed | DF-114, DF-225, DF-141 |
| TR-04 | noConsent(②), offline, syncFailed, awaitingConsent | DF-116, DF-119, DF-141 |
| TR-05 | noConsent(②), pendingPolicy, indeterminate, offline, syncFailed, pendingFinalize | DF-120~DF-122, DF-141 |
| TR-06(P2) | noConsent(③), pendingPolicy, indeterminate, offline(온라인 필요), syncFailed | DF-311, DF-313 |
| TR-07 | noConsent(②③), offline, syncFailed | DF-204, DF-226 |
| TR-08 | noConsent(③), offline, syncFailed | DF-208, DF-226 |
| TR-09 | noConsent(③), pendingPolicy, indeterminate, offline, syncFailed | DF-210, DF-226 |
| TR-10 | empty, noConsent(③), pendingPolicy, indeterminate, offline | DF-214, DF-215, DF-226 |
| TR-11 | empty, noConsent(②), pendingPolicy, indeterminate, offline, syncFailed | DF-127, DF-128, DF-141 |
| TR-12 | empty, noConsent(②), pendingPolicy, indeterminate, beta(P2 대조), offline, syncFailed | DF-129, DF-141 |
| TR-13(P2) | empty, noConsent(②③), indeterminate(betaMetric), beta, offline, syncFailed | DF-320, DF-321 |
| TR-14 | offline(awaitingConsent), syncFailed | DF-110, DF-141 |
| TR-15 | offline, syncFailed, comingSoon | DF-018, DF-141 |

- 크기: 13형 가로(기본), 11형 가로, 폭 375pt(1/3 근사). 세 크기 모두 찍는 화면은 TR-04, TR-05, TR-09, TR-11. 나머지는 13형 가로 + 375pt.
- 스냅샷 기준 이미지는 `__Snapshots__/`에 커밋하고, 기준 변경은 PR에서 소유자가 이미지 diff를 본다(V1-01 트레이너 DoD). CI는 기록 모드를 켜지 않는다(`SNAPSHOT_RECORD` 미설정이면 비교만).
- 스냅샷은 시뮬레이터 런타임·Xcode 버전에 민감하다. 기준 이미지는 CI와 같은 런타임에서 만든다. 로컬 기준 갱신 시 런타임을 PR에 적는다([ASM-10-09](#221-가정)).

**UI 흐름 스모크(XCUITest).** 흐름당 하나, 판정 로직은 검사하지 않는다.

| ID | 흐름 | 검증 | 스토리 |
|---|---|---|---|
| UI-01 | TR-01 → 회원 → TR-04 입력 → '기록 완료' 1탭 | 확인창 0, `sync.localSaved` 표시, 탭 수 1 | DF-116(AC-SOAP-01.2) |
| UI-02 | TR-04 캔버스 면적 | 13형·11형 가로에서 `tr04.canvas` 면적 / 창 면적 ≥ 0.60 | DF-116(AC-SOAP-01.1) |
| UI-03 | TR-05 확정 | 최소 요건 4개 충족 전 버튼 비활성, 충족 후 확정 | DF-122 |
| UI-04 | TR-14 등록 → 동의 → 서명 | 연락처 입력란 0, 14세 미만 차단 문구, 기본 ①②③만 표시 | DF-108, DF-110 |
| UI-05 | TR-11 저장 | 공복 미선택 시 저장 비활성, 범위 오류 문구 | DF-127 |
| UI-06 | TR-12 반복값 | 차이 1cm 이상일 때만 3회째 칸 | DF-129 |
| UI-07 | TR-15 로그아웃 | 미동기 n건 경고 후 로그인 화면 | DF-018 |
| UI-08 | TR-07 → TR-08 → TR-09(합성 사진) | 필수 랜드마크 '지정 필요' 시 확정 비활성 | DF-208, DF-209 |

### 10.5 기능 플래그 노출(TC-X-FLAG)

| ID | 검증 | 층 | 증명 | 스토리 |
|---|---|---|---|---|
| TC-X-FLAG-01 | 모든 새 플래그 false(`--preview-flags` 전부 false)에서 TR-04·05·07~13 진입점 0(사이드바·TR-03 버튼·TR-01 칩 검색) | UI | AC-IA-02 | DF-017 |
| TC-X-FLAG-02 | 문서·키 없음 → 모든 키 false(Swift `FeatureFlags`, Dart `AppFeatureFlags`) | 단위 | §6.0.2 | DF-027 |
| TC-X-FLAG-03 | 규칙 `featureOn`: 각 플래그 false에서 해당 create 거부(R-22, R-29, AC-DF-020.6) | 규칙 | AC-ASM-06.5 등 | DF-020, DF-021 |
| TC-X-FLAG-04 | admin_web zod 8키, 저장이 기존 키를 지우지 않음(merge) | admin 단위 | AD-07, V1-05 CF-05-05 | DF-027 |
| TC-X-FLAG-05 | Release 구성 빌드에서 `--preview-*`·`--preview-flags`·`--use-emulator`가 무시된다(Release 스킴 UI 스모크 1개, 인자를 줘도 Preview 저장소가 아님) | UI(Release 구성, 시뮬레이터) | NFR-03, ADR-010 | DF-017 |
| TC-X-FLAG-06 | 회원 앱 체형·신체조성 세그먼트는 `memberShare && (bodyAssessment || bodyComposition)`일 때만 | Flutter 위젯 | F-VIZ-06.8 | DF-331 |
| TC-X-FLAG-07 | `lidarBeta=false`면 TR-13 진입점·타임라인 스캔 이벤트·필터 항목 0 | UI·위젯 | AC-LIDAR-01.1, AC-VIZ-05.1 | DF-320 |

---

## 11 회원 앱·admin_web 테스트

### 11.1 회원 앱(Flutter)

| 대상 | 파일(제안) | 검증 | 증명 | 스토리 |
|---|---|---|---|---|
| SOAP v2 코덱 | `test/contracts/soap_v2_fixture_test.dart` | TC-X-XC-01·03·04·07 | AC-SOAP-06.1, 06.2 | DF-007 |
| 플래그 | `test/app_feature_flags_test.dart` | 8키, 없으면 false | §6.0.2 | DF-027 |
| 출처 칩·추이 차트 | `test/widgets/source_grade_chip_test.dart`, `test/widgets/series_trend_chart_test.dart` | sourceGrade 없는 점 미렌더, `nullSpot` 끊김, `isCurved` 끔(기존 차트는 켜져 있음 dfet:lib/screens/blood/components/blood_trend_chart.dart:101), 날짜 x축 비례 | AC-VIZ-07.1, AC-VIZ-03.1~03.3, C-04 | DF-131 |
| 4축 색 미참조 | 정적 검사(`static-guards`) | 체형·신체조성 위젯이 `DfetAxisPalette` 등 4축 토큰을 import하지 않음 | AC-VIZ-07.3 | DF-131 |
| 세그먼트 | `test/series_segmenter_test.dart` | series-break 벡터 | TC-X-XC-11 | DF-216 |
| 규제 문구 교체 | 골든 갱신 + copy-lint | 4개 파일 금지어 0 | MIG-04 | DF-029 |
| MB-01~MB-06(P2) | `test/screens/body_report/*`, `test/screens/trainer_records/*`, `test/screens/consent/*` | 상태 매트릭스 골든(§8.4 MB 행), revoked 딥링크 문구, 비렌더 출처 건너뜀, 사진 영역 미렌더, 레이더 축 4개 유지, 쿼리 오류 → 실패 표시 | AC-VIZ-06.1~06.6, AC-IA-04, AC-SOAP-05.6 | DF-315, DF-316, DF-307 |
| 원 기록 경로 미사용 | `static-guards` | `lib/`에서 `soap_notes`·`postureAssessments`·`bodyCompositionRecords`·`circumferenceMeasurements`·`bodyScans` 경로 문자열 0(기준선 허용 목록은 제거 스토리까지) | AC-VIZ-06.1, AC-LINK-05.1 | DF-011, DF-315 |

- 저장소 테스트는 새 의존성 없이 **쿼리 형태**(컬렉션, where, orderBy)를 반환하는 빌더를 분리해 검증한다(ASM-10-11). 실제 규칙 허용은 [§7.4](#74-쿼리-증명-테스트)가 증명한다.
- 기존 테스트(dfet:test/ 25개 파일)와 골든은 회귀로 유지한다.

### 11.2 admin_web

| 대상 | 파일(제안) | 검증 | 스토리 |
|---|---|---|---|
| 플래그 라우트 | `admin_web/test/feature-flags.test.mjs` | 8키 zod, 알 수 없는 키 거부, 저장 시 merge(기존 3키 스키마로 저장해도 새 키 보존) | DF-027 |
| 동의 문서 버전 | `admin_web/test/consent-documents.test.mjs` | 다섯 고지 항목 하나라도 없으면 게시 거부, ④ 수령자 없으면 거부, published 수정 거부, 처리방침 버전 필수 | DF-032(AC-PRIV-01.3, 01.4) |
| 정책 kind 검증 | `admin_web/test/body-change-policy.test.mjs` | metricCode 부록 A, `mdcValue>0`, enum, `conditionKeys` 비어 있지 않음, 승인본 불변, kind별 단일 활성 | DF-221 |
| 열람 감사 | `admin_web/test/record-health-read.test.mjs` | 회원 상세 서버 조회마다 `recordHealthRead` 1회, 로그에 수치 필드 없음 | DF-136(AC-PRIV-05.1) |
| 관리자 판정 | `admin_web/test/auth-role.test.mjs` | `admin` claim만 관리자(`role` 대체 경로 제거 후) | DF-101 |
| P2 화면 | 같은 폴더 | AD-02 코드 원문 없음, AD-06 필터 | DF-317, DF-318 |

- admin_web 순수 검증기는 `@/` 경로 별칭 없이 import할 수 있게 둔다(ASM-P1b-30과 같음).

---

## 12 이관 테스트

이관 절차는 [V1-11](11_MIGRATION_RUNBOOK.md)이 정본이다. 여기서는 CI·리허설 테스트만 정한다.

| ID | 검증 | 층 | 증명 | 스토리 |
|---|---|---|---|---|
| TC-X-MIG-01 | MIG-02 스크립트에 쓰기 호출(`set`, `update`, `delete`, `add`, `batch`, `bulkWriter`, `runTransaction`)이 0건(정적 검사) | `migrations` job | MIG-02 | DF-030 |
| TC-X-MIG-02 | MIG-02 보고서가 수량·분포만(허용 키 화이트리스트) | 단위 | §11.3 | DF-030 |
| TC-X-MIG-03 | `soap_legacy` → MIG-03~06 → 결과가 `soap_legacy/expected_v2/`와 정규화 비교 동일 | 에뮬레이터 | MIG-03 수용 기준 | DF-031 |
| TC-X-MIG-04 | 같은 runId로 두 번 실행해도 결과 동일, 중복 0 | 에뮬레이터 | 멱등 | DF-031 |
| TC-X-MIG-05 | 파싱 실패 metric은 `legacy.metricsRaw`에, 0 채움 0, `migratedFrom`·`authorUid` 전 문서 존재 | 에뮬레이터 | MIG-03 | DF-031 |
| TC-X-MIG-06 | 이관 후 `exerciseAssessment` 문자열이 레거시 diagnosis와 같은 문서 0 | 에뮬레이터 | MIG-04 | DF-031 |
| TC-X-MIG-07 | `isSharedWithMember=true` 0, `legacy.originalIsShared` 보존 | 에뮬레이터 | MIG-05 | DF-031 |
| TC-X-MIG-08 | 인라인 필기 → Storage 해시 일치 후에만 인라인 제거, 불일치 문서는 인라인 유지·보고 | 에뮬레이터 | MIG-06 | DF-031 |
| TC-X-MIG-09 | `member-` seed 문서는 `memberUid`를 채우지 않고 보고서 건수에만 | 에뮬레이터 | MIG-07 | DF-031 |
| TC-X-MIG-10 | 적용 → 롤백 → 재적용 모두 성공, 최종 결과가 1회 적용과 같음 | 에뮬레이터 | MIG-11 | DF-100 |
| TC-X-MIG-11 | 이관된 finalized 문서의 원문 update 거부 | 규칙 | MIG-03 | DF-100 |
| TC-X-MIG-12 | 적용 가드: `--apply`에 `--project`·`--run-id`·확인 문구 없으면 종료 코드 2 | 단위 | §11 원칙 ⑤ | DF-100 |
| TC-X-MIG-13 | trainerWorkspaces 가져오기: 표시명만 후보, 건강정보 필드 0, 트레이너 확인 건만 생성 | 트레이너 단위 + 규칙 | MIG-08 | DF-138 |

- 운영 실행 전 체크: 에뮬레이터 리허설 결과(TC-X-MIG-10)가 PR에 첨부돼 있어야 DF-924를 시작한다.
- **동결 Runner 트레이너 관찰(수동):** MIG-03 적용 직후, 동결된 Runner 트레이너에서 SOAP 저장을 시도했을 때 '저장 실패'가 보이는지, 거짓 '저장됨'이 보이는지 기록한다. 거짓 성공이면 S2 결함으로 올리고 동결 예외로 문구만 고친다(MIG-09, C-05 취지). 기록은 V1-T10 비고에 남긴다(TC-X-DEV-09).

---

## 13 실기기 수동 프로토콜

기록 양식은 [V1-T09](templates/DEVICE_TEST_RECORD.md)이다. 참여자는 가상 회원 계정과 소유자 본인뿐이다. 회원 사진·실데이터는 쓰지 않는다. 결과는 단계 종료 검토의 증빙이 된다.

### 13.1 P1a(DF-140, 대상 iPad DEV-A)

| ID | 시나리오 | 절차 요지 | 통과 기준 | 증명 |
|---|---|---|---|---|
| TC-X-DEV-01 | 비행기 모드 Live | 비행기 모드 → TR-04 한 줄 + 필기 → '기록 완료' → 앱 강제 종료 → 재실행 → 비행기 모드 해제 | draft·필기 유지, '기기에 저장됨' → '동기화 중' → '동기화됨', 서버 1건 | AC-SOAP-01.3, NFR-04 |
| TC-X-DEV-02 | 4방향 회전 | TR-01, TR-04, TR-05, TR-11, TR-14에서 입력 중 회전 4회 | 입력·필기 유지, 잘림 0 | NFR-12 |
| TC-X-DEV-03 | 멀티태스킹 | Split View 1/3·1/2·2/3, Slide Over, Stage Manager에서 같은 화면 | 1/3에서 잘림 0, '기록 완료'가 스크롤 없이 보임 | NFR-12 |
| TC-X-DEV-04 | 외부 전송 관찰 | Mac 프록시(Charles 등, 소유자 기기)로 S1·S2 시나리오 30분 | 관찰 도메인이 Firebase·Google API·Apple뿐. 회원 uid·이름이 쿼리 문자열에 없음 | NFR-11 |
| TC-X-DEV-05 | Pencil | 필기 연속 5분, 손바닥 거부, 되돌리기 | 획 손실 0, 캔버스 위 조작 요소 겹침 0 | F-SOAP-01.1 |
| TC-X-DEV-06 | 한글 입력 | 한 줄 입력·S/A/P에 자음·모음 조합 중 전환, 받아쓰기 | 조합 깨짐 0 | A-04 |
| TC-X-DEV-07 | claim 회수 | 관리자에서 가상 트레이너 claim 제거 → 토큰 갱신 | 잠김, 로컬 데이터 비표시 | NFR-08 |
| TC-X-DEV-08 | 로그아웃 | 미동기 2건 상태에서 로그아웃 | 경고와 선택지, 로그아웃 후 `currentUser == nil`(디버그 메뉴 확인) | NFR-08 |
| TC-X-DEV-09 | 동결 Runner 관찰 | MIG-03 적용 뒤 Runner 트레이너 SOAP 저장 시도 | 거짓 성공 여부 기록([§12](#12-이관-테스트)) | MIG-09, C-05 |
| TC-X-DEV-10 | 성능 측정 | [§14](#14-성능-테스트) PERF-01·02·04 | 수치 기록 | NFR-15 |

### 13.2 P1b 촬영 프로토콜(DF-223, DEV-A)

촬영 프로토콜 v1 수치(높이·거리·허용 범위·발 간격)는 DF-915 문서가 정본이다.

| ID | 시나리오 | 절차 요지 | 통과 기준 | 증명 |
|---|---|---|---|---|
| TC-X-DEV-11 | 스테이션·체크리스트 | 스테이션 프로필 등록 → 체크리스트 4항목 중 1개 미확인 | 셔터 비활성 | AC-ASM-01.2 |
| TC-X-DEV-12 | 수평계 게이트 | 기기를 roll·pitch 허용 범위 밖으로 기울임 | 셔터 비활성, 범위 안에서 활성 | AC-ASM-01.2, F-ASM-01.4 |
| TC-X-DEV-13 | 조명·인물 | 역광, 저조도, 인물 2명 | 인물·조명 안내가 보인다. 셔터 비활성 조건은 roll·pitch와 체크리스트뿐이므로(PRD F-ASM-01.4, AC-ASM-01.2) 안내만 확인하고, 추가 차단 여부는 V1-07을 따른다 | F-ASM-01.4 |
| TC-X-DEV-14 | 제안 지연 | 정면·측면 각 10회 촬영 후 제안 표시까지 시간(signpost) | 중앙값·p95 기록(목표 ≤2초) | NFR-15, M-04b |
| TC-X-DEV-15 | 오프라인 촬영 | 비행기 모드에서 촬영·draft 저장·확정 → 복구 | '확정 대기 · 동기화 중' → '동기화됨' | AC-ASM-01.5, AC-ASM-04.5 |
| TC-X-DEV-16 | EXIF | 위치 서비스를 켠 채 실기기로 촬영 → 로컬 에뮬레이터에 연결(`--use-emulator --emulator-host=<Mac IP>`)해 업로드 → Storage 에뮬레이터에서 파일을 받아 GPS 태그 확인([ASM-10-19](#221-가정)). 운영에는 올리지 않는다 | GPS 태그 0 | AC-ASM-01.4 |
| TC-X-DEV-17 | 카메라 롤 | 촬영 후 사진 앱 확인 | 새 사진 0 | F-ASM-01.7 |
| TC-X-DEV-18 | 촬영·확정 소요 | 가상 참여자(소유자 본인) 5회 | M-04a·M-04b 중앙값 기록 | M-04a, M-04b |
| TC-X-DEV-19 | 좌우 매핑 종단 | 라이선스 확인 이미지 또는 본인 표식 촬영 | `acromionRight` 제안이 이미지 왼쪽 절반 | AC-ASM-02.3 |

### 13.3 P2(DEV-C, DEV-D, DEV-E)

| ID | 시나리오 | 통과 기준 | 증명 |
|---|---|---|---|
| TC-X-DEV-21 | BodyPath(iPhone)에서 `cameraOrbit`+`measurements` 촬영 → 결과 패키지 내보내기 → iPad 트레이너 앱 가져오기 | 검증 규칙 통과, `measuredAt == takenAt` | F-LIDAR-01, AC-LIDAR-01.2 |
| TC-X-DEV-22 | `isSynthetic=true`·미확정 윤곽 패키지 가져오기 | 거부 사유 표시, 기록 0 | AC-LIDAR-01.3 |
| TC-X-DEV-23 | 메시 원본 없는 iPad에서 TR-13, 프록시 관찰 | 2D만, 메시·깊이 업로드 요청 0 | AC-LIDAR-02.1, NFR-13 |
| TC-X-DEV-31 | 회원 앱(DEV-E): 초대 코드 입력 → MB-06 → MB-01·02 | 성공 흐름, revoked 후 목록에서 사라짐 | AC-LINK-02.x, AC-SOAP-05.7 |

---

## 14 성능 테스트

NFR-15 수치는 가설 목표다. CI 시뮬레이터 수치는 러너마다 달라 **판정에 쓰지 않고 추세만** 본다. 판정은 대상 iPad(DEV-A) 실측으로 한다.

### 14.1 계측 지점

앱은 `OSSignposter`(subsystem `kr.co.dfet.trainer`, category `perf`)로 다음 구간을 남긴다. 구간 이름은 고정이다.

| signpost 구간 | 시작 | 끝 | 목표(가설) | 연결 |
|---|---|---|---|---|
| `RecordComplete` | '기록 완료' 탭 | `localSaved` 표시 | p95 ≤ 300ms | NFR-15, M-01 |
| `ColdStartToday` | 프로세스 시작 | TR-01 첫 프레임(캐시) | ≤ 2초 | NFR-15 |
| `LandmarkSuggest` | 셔터 후 이미지 확보 | 제안 표시 | ≤ 2초(1장) | NFR-15, M-04b |
| `TimelineFirstScreen` | TR-03 진입 | 첫 25건 렌더 | 캐시 ≤ 1.5초, 네트워크 ≤ 3초 | NFR-15 |
| `PhotoUpload` | 업로드 시작 | 완료 | 입력 화면 멈춤 0(주 스레드 hang 0) | NFR-15, M-04a |

### 14.2 테스트

| ID | 방법 | 환경 | 판정 | 스토리 |
|---|---|---|---|---|
| TC-X-PERF-01 | XCTest `measure(metrics: [XCTOSSignpostMetric(subsystem:category:name:)])`로 `RecordComplete` 20회 | CI 시뮬레이터: 추세만. DEV-A: Instruments 'os_signpost'로 50회 | DEV-A p95 ≤ 300ms | DF-116, DF-140 |
| TC-X-PERF-02 | `XCTApplicationLaunchMetric` + `ColdStartToday` | DEV-A 10회 | 중앙값 ≤ 2초 | DF-140 |
| TC-X-PERF-03 | `LandmarkSuggest` | DEV-A 촬영 20회(TC-X-DEV-14) | p95 ≤ 2초 | DF-200, DF-223 |
| TC-X-PERF-04 | 합성 회원 12개월 기록(세션 150건 + 측정 60건) 시드 후 `TimelineFirstScreen` | 에뮬레이터 연결 DEV-A(네트워크), 캐시 재진입 | 캐시 ≤ 1.5초, 네트워크 ≤ 3초 | DF-114, DF-140 |
| TC-X-PERF-05 | 사진 업로드 중 TR-08 조작, Instruments Hangs | DEV-A | 250ms 이상 hang 0 | DF-206, DF-223 |
| TC-X-PERF-06 | M-01 계산 검증: DebugSink 이벤트의 `elapsed_band` 분포가 signpost 실측과 같은 구간 | 단위 + DEV-A | 구간 일치 | DF-126 |

- 결과는 V1-T09에 기종·OS·빌드·중앙값·p95로 적고 단계 종료 검토(PRD §12.7)에 제출한다. 목표를 넘으면 결함이 아니라 **목표 재설정 논의 항목**이다. 단, `RecordComplete` p95가 1초를 넘으면 M-01을 위협하므로 S2로 분류한다([ASM-10-10](#221-가정)).

---

## 15 접근성 테스트

PRD §8.6(A-01~A-05)과 AC-A11Y-01~03을 검증한다.

| ID | 검증 | 도구·방법 | 대상 | 증명 | 스토리 |
|---|---|---|---|---|---|
| TC-X-A11Y-01 | 자동 접근성 감사(라벨 누락, 대비, 탭 대상, Dynamic Type 잘림) | XCUITest `try app.performAccessibilityAudit()`(iOS 17+) | TR 화면마다 기본 상태 1회 | AC-A11Y-01 | DF-141(P1a 화면), DF-226(P1b 화면) |
| TC-X-A11Y-02 | 수치 요소 VoiceOver 라벨에 출처 등급과 변화 상태(또는 '산정 준비 중'·'판정 불가 · 사유')가 들어 있다 | 단위: `MetricRow.accessibilityLabel`을 A-03 템플릿과 비교. UI: 편위 표 셀 라벨 문자열 검사 | TR-09, TR-10, TR-11, TR-12, MetricRow 전체 | AC-A11Y-01, AC-C-01.3 | DF-016, DF-130, DF-210 |
| TC-X-A11Y-03 | 가장 큰 접근성 글자 크기(`accessibilityExtraExtraExtraLarge`)에서 수치 말줄임 0 | 스냅샷 `.environment(\.dynamicTypeSize, .accessibility5)` + 텍스트 잘림 검사 헬퍼(`Text.truncationMode` 발생 시 실패하는 레이아웃 측정) | TR-09, TR-11 | AC-A11Y-02 | DF-141, DF-226 |
| TC-X-A11Y-04 | 회색조 구분: 두 상태 스냅샷을 회색조로 변환해 픽셀 차이가 임계 이상 | 테스트 헬퍼 `assertDistinguishableInGrayscale(a, b, minDiff: 0.02)` | 배지 4상태·판정 불가, seriesBreak 유무, L/R 선, auto/확정 랜드마크, 바디맵 채움/빗금 | AC-A11Y-03, AC-VIZ-02.1, AC-VIZ-07.5 | DF-130, DF-208, DF-117 |
| TC-X-A11Y-05 | 탭 대상 44pt 이상 | 스냅샷 테스트에서 버튼 프레임 측정, 감사(01)와 중복 확인 | 모든 버튼·칩 | A-04 | DF-016 |
| TC-X-A11Y-06 | TR-08 핀을 드래그 없이 옮기기 | UI: 방향 버튼 탭 → 좌표 1px 변화, VoiceOver 조정 동작(`accessibilityAdjustableAction`) → 변화 | TR-08 | A-04, F-ASM-02.4 | DF-208 |
| TC-X-A11Y-07 | 차트 오디오 그래프 | 단위: `AXChartDescriptor` 제공 여부와 요약(기간, 점 개수, 끊김 수) | SeriesTrendChart | A-03 | DF-130 |
| TC-X-A11Y-08 | Flutter `meetsGuideline(textContrastGuideline)`, `labeledTapTargetGuideline`, `iOSTapTargetGuideline` | 위젯 테스트 | MB-01~MB-06, source_grade_chip, series_trend_chart | AC-A11Y-01 | DF-131, DF-316 |
| TC-X-A11Y-09 | 회원 앱 `textScaler` 2.0에서 MB-02 수치 잘림 0, overflow 오류 0 | 위젯 테스트(`FlutterError` 수집, 기존 관례) | MB-02 | AC-A11Y-02, A-01 | DF-316 |
| TC-X-A11Y-10 | 동작 줄이기 설정에서 애니메이션 없음 | 스냅샷 환경 `accessibilityReduceMotion` | 전환·차트 | A-05 | DF-016 |

- 실기기에서는 VoiceOver로 TR-04 한 줄 입력 → '기록 완료'를 끝까지 수행해 기록한다(TC-X-DEV-06 절차에 추가).

---

## 16 금지어 린트·정적 가드·개인정보 테스트

### 16.1 금지어 린트(`tool/lint/prohibited-terms.mjs`)

규칙 세트·패턴의 내용은 [V1-12](12_COPY_ANALYTICS_AND_LINT.md)와 `contracts/prohibited-terms.v1.json`이 정본이다. 여기서는 **린트 도구가 맞게 동작하는지**를 검증한다. 자체 테스트는 `tool/lint/test/prohibited-terms.test.mjs`(node:test), 입력은 `tool/lint/test/fixtures/prohibited-terms/`.

| ID | 입력 | 기대 | 증명 | 스토리 |
|---|---|---|---|---|
| TC-X-LINT-01 | Swift `Localizable.xcstrings`에 '치료계획' | 위반 1, 파일·키·위치 보고 | AC-C-06.1, 부록 C.1 | DF-010 |
| TC-X-LINT-02 | Swift 리터럴 `Text("체형 교정")`, Dart `'자세교정'`, TSX `<p>재활 트레이닝</p>` | 각 1건(띄어쓰기 변형 포함) | 부록 C.1 | DF-010 |
| TC-X-LINT-03 | 회원 경로(`lib/`) 문자열 '개선됐어요' / 트레이너 경로 '의미 있는 개선' | 회원 경로만 위반(회원 세트), 트레이너는 통과 | 부록 C.3 | DF-010 |
| TC-X-LINT-04 | 인과 패턴 '스트레칭 때문에 좋아졌어요' | 공통 세트 규칙에 따라 보고(문구·요약은 차단, 트레이너 원 기록 입력값은 대상 아님) | 부록 C.2 | DF-010 |
| TC-X-LINT-05 | 허용 목록 약어 SOAP·ROM·AROM·PROM·MMT·NRS·MDC / 목록 밖 약어 'SLR' | 회원 요약 템플릿에서만 'SLR' 위반 | F-SOAP-07.3 | DF-010 |
| TC-X-LINT-06 | 예외 경로(부록 C 문서, 법령 인용 문서, 테스트 픽스처, 레거시 필드명 `diagnosis` 식별자) | 위반 0 | 부록 C.3 예외 | DF-010 |
| TC-X-LINT-07 | `contracts/analytics-events.v1.json`에 이벤트명 `posture_correction_done`, `contracts/audit-actions.v1.json`에 action `diagnosisViewed` | 각 1건 | AC-PRIV-06.3, F-PRIV-06.3 | DF-033 |
| TC-X-LINT-08 | 보고 모드(`COPY_LINT_MODE=report`) | 위반이 있어도 종료 코드 0, 요약 출력 | ADR-016 | DF-010 |
| TC-X-LINT-09 | 차단 모드(`COPY_LINT_MODE=block`) | 위반 1건이면 종료 코드 1 | ADR-016, M-G1 | DF-040 |
| TC-X-LINT-10 | 출시 앱 문자열(Runner `ios/Runner/AppDelegate.swift`, 회원 앱 4개 파일) 스캔 포함 | 대상 목록에 포함, P0 종료 시 위반 0 | MIG-04, PRD §12.1 P0 종료 | DF-028, DF-029, DF-040 |
| TC-X-LINT-11 | LiDAR 화면 문자열 '측정값' | TR-13 경로에서만 위반 | AC-LIDAR-03.2 | DF-321 |
| TC-X-LINT-12 | 서버 요약 검사와 린트가 같은 JSON을 읽어 같은 위반을 낸다(같은 입력 문장 20개) | 두 구현 결과 동일 | F-PRIV-06.2 | DF-309 |

- 매칭 규칙(형태소·띄어쓰기 변형, 조사 결합)의 정의는 V1-09 '금지어 매칭 규칙'이 정본이다. 오탐이 나오면 규칙을 고치고 이 표의 사례를 추가한다. 예외 경로 추가는 `regulatory` 라벨 PR로만 한다.

### 16.2 정적 가드(`tool/lint/static-guards.sh`)

각 불변식은 **위반 샘플 1개**를 `tool/lint/test/fixtures/static-guards/`에 두고, 스크립트가 그 샘플에서 실패하는지 자체 테스트(`tool/lint/test/static-guards.test.sh`)로 확인한다. 기존 위반은 기준선 허용 목록(`tool/lint/static-guards.allow`, 한 줄에 `<가드ID> <경로> # <사유>`, 줄 번호 없이 파일+가드 단위)으로 고정한다(V1-01 ASM-01-15, [P0 DF-011](backlog/P0.md#df-011) AC-DF-011.4·011.5).

| ID | 불변식(0건이어야 함) | 대상 경로 | 증명 | 제거 스토리(기준선) |
|---|---|---|---|---|
| TC-X-GUARD-01 | `import Firebase*` | `trainer_app/Packages/TrainerCore/Sources/**`(TrainerContracts·TrainerDomain·PostureMath·SyncEngine·TrainerAnalytics), `trainer_app/Packages/TrainerKit/Sources/{Feature*,LocalStore}` | NFR-03 | — |
| TC-X-GUARD-02 | 원 기록 컬렉션 경로 문자열 | `lib/` | AC-VIZ-06.1 | DF-315(dfet:lib/services/firestore_service.dart의 soap_notes 조회) |
| TC-X-GUARD-03 | `getDownloadURL` | `trainer_app/`, `lib/`, `admin_web/` | §9.5 링크 정책 | 기존 dfet:lib/screens/create_request_screen.dart:100, dfet:lib/services/community_service.dart:45는 기준선(제거 스토리 없음, Q-DEV 후보) |
| TC-X-GUARD-04 | `"member-"` + UUID 키, `native_` 문서 ID, `nativeInkDataBase64`·`drawingData` 쓰기 | `trainer_app/` | AC-SOAP-01.9, AC-LINK-03.3, F-SOAP-01.7 | — |
| TC-X-GUARD-05 | `isSharedWithMember: true`, `isSharedWithMember = true` | 전체(동결 경로는 기준선) | AC-SOAP-05.8 | DF-387(dfet:lib/widgets/shells/trainer_shell.dart:565) |
| TC-X-GUARD-06 | `tapback.co` | `trainer_app/` | NFR-11 | — |
| TC-X-GUARD-07 | `print(` | `FirebaseData`, `SyncEngine` | NFR-06 | — |
| TC-X-GUARD-08 | 실제형 이메일·전화번호 | 테스트·픽스처 경로([§5.6](#56-픽스처-자동-검사)) | §2.1 | — |
| TC-X-GUARD-09 | 운영 프로젝트 ID `dfetmanage` | 테스트·스크립트 | §4.2 | — |
| TC-X-GUARD-10 | 비밀 파일 경로 읽기 | 테스트 코드 | §2.1 | — |
| TC-X-GUARD-11 | 허용 목록 밖 테스트 이미지 | 테스트 경로 | §5.5 | — |
| TC-X-GUARD-12 | 판정 로직·MDC 상수(`mdcValue` 리터럴, `meaningfulImprovement` 계산 분기) | `trainer_app/`, `lib/` | ADR-009, AC-DF-216 | — |
| TC-X-GUARD-13 | 4축 색 토큰 참조 | 체형·신체조성 위젯 경로(`lib/screens/body_report/`, `lib/widgets/clinical/source_grade_chip.dart`, `series_trend_chart.dart`) | AC-VIZ-07.3 | — |
| TC-X-GUARD-14 | Runner 의존성 그래프에 TrainerKit·BodyPathCore | `ios/Podfile.lock`, `ios/Runner.xcodeproj` | NFR-01 | — |
| TC-X-GUARD-15 | 트레이너 앱과 BodyPath 공유 App Group 식별자 | 두 앱 entitlements | NFR-14 | — |

### 16.3 로그·분석·데이터 위생(TC-X-PRIV)

| ID | 검증 | 층 | 증명 | 스토리 |
|---|---|---|---|---|
| TC-X-PRIV-01 | 이벤트·속성이 `analytics-events.v1.json` 허용 목록에만 있다. 목록 밖 속성을 넣은 이벤트는 테스트 실패 | Swift 단위 | NFR-10, §5.5 | DF-126 |
| TC-X-PRIV-02 | 이벤트 속성 값에 건강 수치·uid·이름 형식 값이 들어가지 않는다(모든 이벤트를 합성 세션으로 발생시켜 DebugSink 출력 검사) | Swift 단위 | NFR-10 | DF-126 |
| TC-X-PRIV-03 | 동의 변경은 분석 이벤트로 나가지 않고 `consentChanged` 감사만 | Swift 단위 + e2e | §5.5, ADR-011 | DF-109, DF-110 |
| TC-X-PRIV-04 | `auditLogs.metadata` 키가 `audit-actions.v1.json`의 `metadataKeys`에만 있다 | e2e(모든 감사 기록 함수) | §9.7 금지 항목 | 각 함수 스토리 |
| TC-X-PRIV-05 | `Logger` 호출에서 회원 식별자·수치 보간은 `privacy: .private` | 정적 검사(`static-guards`에서 `Logger` 보간의 `privacy:` 누락 검출) + 코드 리뷰 | NFR-10 | DF-104 |
| TC-X-PRIV-06 | CI 로그·아티팩트에 plist·시크릿 값이 없다(워크플로에서 `set -x` 금지, 아티팩트 목록 검사) | CI 설정 검토 | ADR-019 | DF-034 |
| TC-X-PRIV-07 | `opsMetrics` 문서에 식별자·값 필드 0 | e2e | §5.3 | DF-137 |
| TC-X-PRIV-08 | 회원 공유 알림 문구에 수치·지표명·부위 없음 | 린트 + 단위 | F-SOAP-05.12 | DF-309 |

---

## 17 회귀 전략

### 17.1 회귀 묶음

| 묶음 | 내용 | 실행 시점 | 실패 시 |
|---|---|---|---|
| TC-X-REG-01 매 PR | 필수 CI 전체([§19.2](#192-job-목록과-필수-체크)) | PR마다 | 병합 불가 |
| TC-X-REG-02 기존 자산 | 기존 규칙 describe 5개(dfet:functions/test/firestore-rules.test.js:67, :105, :151, :209, :226), 임상 단위·e2e, Flutter 기존 테스트와 골든, `flutter build ios --no-codesign`, admin_web 전체 | 매 PR(기존 job 안) | 병합 불가 |
| TC-X-REG-03 야간 | `trainer-app-emulator-it` 전체, SIM-2·SIM-4 UI·스냅샷, 이관 리허설(TC-X-MIG-10) | 매일 KST 03:00 | 다음 작업일 첫 일로 분류([§21.2](#212-분류-흐름)) |
| TC-X-REG-04 릴리스 후보 | 트레이너 앱 TestFlight 후보: TC-X-DEV-01·02·03·05·07·08 요약판(30분) + 해당 단계 신규 DEV 시나리오. 회원 앱 릴리스: DEV-31 + 기존 흐름 스모크 | 태그 전 | 태그 보류 |
| TC-X-REG-05 규칙·함수 배포 후 | 운영 스모크(가상 회원 create 1건 허용·1건 거부)([§4.5](#45-운영-프로젝트에서-하는-확인소유자만)) | 배포마다 | PRD §12.4 롤백 표 |
| TC-X-REG-06 단계 종료 | [§20](#20-단계별-테스트-종료-기준)의 증빙 전체 | 단계 종료 검토 | 단계 전환 보류 |

### 17.2 동결 앱 회귀

- Runner 내장 트레이너와 `trainer_ios/`는 동결이다(MIG-09, ADR-001). 동결 예외 PR(`freeze-exception`)은 다음을 통과해야 한다: `flutter build ios --no-codesign`, copy-lint(Runner 문자열 포함), 변경 줄 주변 수동 확인 기록.
- `trainer_ios/`는 P1a 종료 때 삭제된다(DF-142). 그 전까지 CI에서 빌드하지 않는다(현재도 CI 연결 없음).

### 17.3 결함에서 회귀 테스트로

- 버그 수정 PR에는 재현 테스트(수정 전 실패 → 수정 후 통과)가 반드시 들어간다(V1-01 버그 절).
- S1·S2 결함은 같은 유형이 다른 곳에 없는지 확인하고, 가능하면 정적 가드 규칙(TC-X-GUARD-NN 추가)으로 막는다(V1-T13 수정 조건).

---

## 18 수용 기준 → 테스트 카탈로그

PRD 수용 기준마다 **증명 층, 테스트 위치, 담당 스토리**를 정한다. 층 약어: U=단위(순수), SU=시뮬레이터 단위, R=규칙 에뮬레이터, F=Functions e2e, X=교차 픽스처·벡터, I=트레이너 통합(에뮬레이터), UI=XCUITest·Flutter 위젯, S=스냅샷·골든, L=린트·정적 가드, M=이관, D=실기기, A=admin_web 단위.

테스트 위치의 파일 이름은 제안이다. 담당 스토리 카드가 다르게 정하면 카드를 따르고 이 표를 같은 PR에서 고친다.

### 18.1 P0

| AC | 층 | 테스트 위치·ID | 스토리 |
|---|---|---|---|
| AC-SOAP-06.1 | X | TC-X-XC-01, TC-X-XC-02 | DF-007, DF-009 |
| AC-SOAP-06.2 | X | TC-X-XC-03 | DF-007, DF-009 |
| AC-SOAP-06.3 | X, U | TC-X-XC-05 | DF-009 |
| AC-LINK-03.1 | R, F | R-06, S-06, `syncRecordAccessKeys` e2e ①② | DF-022, DF-023, DF-025 |
| AC-LINK-03.2 | R | R-01, R-02, R-07 | DF-022 |
| AC-LINK-03.3 | L | TC-X-GUARD-04 | DF-011 |
| AC-PRIV-06.1 | R | R-04 | DF-022 |
| AC-PRIV-06.3 | L | TC-X-LINT-07 | DF-033 |
| AC-C-06.1 | L | TC-X-LINT-01~LINT-03, LINT-09, LINT-10 | DF-010, DF-040 |
| AC-IA-02 | UI, R, A | TC-X-FLAG-01~FLAG-04 | DF-017, DF-027 |
| AC-PRIV-01.3, AC-PRIV-01.4 | A | `admin_web/test/consent-documents.test.mjs` | DF-032 |
| AC-BC-04.1(v1: 필드 존재) | X | `schemas/body-composition-record.schema.json`에 `source`, `externalId`, `idempotencyKey`, `rawPath` 존재 검사 | DF-006 |
| MIG-02 | M | TC-X-MIG-01, TC-X-MIG-02 | DF-030 |
| MIG-03~06(dry-run) | M | TC-X-MIG-03~MIG-09 | DF-031 |
| R-01~R-31 | R | [§7.2](#72-파일-배치df-022df-035-카드-기준) 파일(DF-022: `soap_notes`·`assignment`·`member_access`·`legacy_switch`, DF-035: `body_composition`·`posture`·`pending_members`·`server_only`·`flags`·`policies`·`circumference`·`consent_read`) | DF-022, DF-035 |
| S-01~S-08 / S-09 | R / 수동 | `storage.rules.test.js` / [§7.5](#75-s-09-실환경-확인소유자) | DF-023 / DF-038 |
| §9.6 인덱스 | U, R | `functions/test/unit/indexes.test.js`, `queries.rules.test.js` | DF-024 |
| NFR-01 | L, CI | TC-X-GUARD-14, `ios-no-codesign`, 트레이너 앱 `IPHONEOS_DEPLOYMENT_TARGET=17.0` 확인(xcodegen diff) | DF-008 |
| NFR-02 | SU, D | claim 없음 → 즉시 signOut(가짜 Auth), 실계정은 G-02 기록 | DF-012, DF-903 |
| NFR-03 | L, UI | TC-X-GUARD-01, TC-X-FLAG-05 | DF-011, DF-017 |
| NFR-14 | L | TC-X-GUARD-15 | DF-008 |
| NFR-16 | U | 신규 export마다 region 선언 검사(`functions/test/unit/region.test.js`: `index.js` export를 순회해 `__endpoint.region` 확인) | DF-037 |

### 18.2 P1a

**SOAP Live·Review·확정(EP-10)**

| AC | 층 | 테스트 위치·ID | 스토리 |
|---|---|---|---|
| AC-SOAP-01.1 | UI | UI-02(SIM-1, SIM-2), 실기기 확인 TC-X-DEV-05 | DF-116 |
| AC-SOAP-01.2 | UI | UI-01 | DF-116 |
| AC-SOAP-01.3 | I, D | TC-X-SYNC-03, TC-X-DEV-01 | DF-116, DF-107 |
| AC-SOAP-01.4 | U, I | TC-X-SYNC-02, TC-X-SYNC-07 | DF-015, DF-107 |
| AC-SOAP-01.5 | I, R | TC-X-SYNC-01(필기), S-01~S-04 대응 `soapInk` 경로 규칙 테스트 | DF-118, DF-023 |
| AC-SOAP-01.6 | U, I | TC-X-SYNC-14, R-24 | DF-116 |
| AC-SOAP-01.7 | U | `FeatureSOAPTests`: NRS 미선택 시 `painNrs == nil`, 페이로드에 키 없음 | DF-117 |
| AC-SOAP-01.8 | SU, R | 뷰 모델 동의 게이트('동의 필요'와 TR-14 진입), `soap_notes.rules.test.js`에 R-01 대조 케이스(시드 `memberConsentStates/member1.healthData.granted=false`에서 같은 create 거부) | DF-119, DF-022 |
| AC-SOAP-01.9 | L | TC-X-GUARD-04 | DF-011 |
| AC-SOAP-01.10 | D, U | TC-X-PERF-06, P1a 자체 사용 지표(DF-927) | DF-126 |
| AC-SOAP-02.1 | U | Review 편집 후 `inkPath`·`inkRevision` 불변 | DF-120 |
| AC-SOAP-02.2 | U, X | 카탈로그 밖 코드 저장 불가, 생성 enum 사용 | DF-121 |
| AC-SOAP-02.3 | U | '45도 정도'·'좋음' 행 저장 불가, note 이동 안내 | DF-121 |
| AC-SOAP-02.4 | U | `FinalizeRequirementsTests` 미완성 행 자동 제외·목록 | DF-121, DF-122 |
| AC-SOAP-02.5 | R, L | R-04, 페이로드 키 검사 | DF-121, DF-022 |
| AC-SOAP-02.6 | U, UI | 특수검사·PROM 선택지 없음 | DF-121 |
| AC-SOAP-02.7 | X | TC-X-XC-10 | DF-117 |
| AC-SOAP-02.8 | U | 인라인 경고와 대체어(prohibited-terms 생성물 사용) | DF-120 |
| AC-SOAP-04.1 | R | R-08 | DF-022 |
| AC-SOAP-04.2 | R, U | R-09, 사유 빈 addendum 거부(UI·규칙) | DF-123 |
| AC-SOAP-04.3 | R, UI | finalized delete 거부 규칙, 메뉴 없음 스냅샷 | DF-123 |
| AC-SOAP-04.4 | I | draft 삭제 후 `soapInk/{noteId}/` 파일 0 | DF-123 |
| AC-SOAP-04.5 | I | TC-X-SYNC-09 | DF-122 |
| AC-SOAP-04.6 | I | TC-X-SYNC-13 | DF-104 |
| AC-SOAP-07.1, AC-SOAP-07.2 | U | 이어쓰기 draft O 값 비움·'지난 값', 새 자동 ID, 원본 불변 | DF-124 |
| F-SOAP-04.7(soapFinalized) | F | `auditSoapFinalized` e2e | DF-123 |
| AC-IA-03 | UI, I | `tr04.offline` 스냅샷 + TC-X-SYNC-03 | DF-116 |
| AC-IA-05 | U, UI | `TodayListEntry` 재시작 유지·다음 날 이월(가짜 시계) | DF-125 |

**회원·동의·개인정보(EP-08, EP-09)**

| AC | 층 | 테스트 위치·ID | 스토리 |
|---|---|---|---|
| AC-LINK-01.1 | R | R-05 | DF-022 |
| AC-LINK-01.2 | R, UI | R-30, 허용 키 밖(`phone`, `email`) 거부 규칙 케이스, UI-04 | DF-035, DF-108 |
| AC-LINK-01.3 | R | R-18(허용), ② 없는 대기 회원 키 create 거부 케이스 | DF-035 |
| AC-LINK-01.4, AC-LINK-01.5 | F | `purgeExpiredRecords` e2e(시계 주입) | DF-133 |
| AC-LINK-01.6 | R, U | R-31, `AgeGateTests` | DF-035, DF-108 |
| AC-PRIV-01.1 | R, UI | R-14, TR-11 `noConsent` 스냅샷 | DF-035, DF-127 |
| AC-PRIV-01.2 | R, UI | R-15, S-03 대응 동의 조건, TR-07 `noConsent`(P1b) | DF-035, DF-204 |
| AC-PRIV-02.1 | R | R-20 | DF-035 |
| AC-PRIV-02.2 | F | `recordConsent` ⑥ + `purgeExpiredRecords`(1분 내 요약 해제는 P2 요약 생성 후 재검증) | DF-112, DF-133 |
| AC-PRIV-02.3 | F, I | `purgeExpiredRecords` ③ 철회, TC-X-SYNC-16 | DF-133, DF-112 |
| AC-PRIV-03.1 | F | `recordConsent` ⑤, 승격 시 `subjectUid`(P2 e2e) | DF-109, DF-305 |
| AC-PRIV-03.2 | R, F | R-28, R-01 전제(가입 회원 현장 ② 후 create 허용) | DF-109, DF-035 |
| AC-PRIV-03.3 | I | TC-X-SYNC-04, TC-X-SYNC-11 | DF-111 |
| AC-PRIV-04.1 | F | `deleteMemberCascade` e2e | DF-132 |
| AC-PRIV-05.1 | A | `record-health-read.test.mjs` | DF-136 |
| AC-PRIV-05.2 | F, 수동 | `logRecordAccess` e2e, Data Access 로그는 운영 확인([§4.5](#45-운영-프로젝트에서-하는-확인소유자만)) | DF-115, DF-932 |
| AC-PRIV-07.1 | F | `exportMemberData` e2e | DF-135 |
| F-LINK-03.2(TR-02) | SU, R | 11명 이상 청크 로드, `users documentId in` 증명 | DF-013 |

**측정(EP-11)**

| AC | 층 | 테스트 위치·ID | 스토리 |
|---|---|---|---|
| AC-BC-01.1 | R, UI | R-17, UI-05 | DF-035, DF-127 |
| AC-BC-01.2 | U, S | 측정 시각 정렬, 미니 추이 x축 = `measuredAt` | DF-127, DF-130 |
| AC-BC-01.3 | U | `users.height/weight` 입력이 BMI·추이에 쓰이지 않음(저장소 경계 테스트) | DF-127 |
| AC-BC-01.4 | R | R-14 | DF-035 |
| AC-BC-01.5 | U | BMI 규칙(§9.5) | DF-127 |
| AC-BC-03.1 | U, R | 빈칸 미측정·0 저장 금지, R-17(b) | DF-127 |
| AC-BC-03.2 | U, UI | 범위 규칙, 오류 문구 | DF-127 |
| AC-BC-03.3(분할) | X, S | series-break 기기 변경 사례, 스냅샷 표식 | DF-128, DF-216 |
| AC-BC-03.4 | U | 교차 경고·저장 허용 | DF-127 |
| AC-BC-03.5 | U, R | '정정' = voided(사유) + 미리 채운 새 입력, voided 뒤 수정 거부 | DF-128 |
| F-BC-02.1(결과지) | R, I | `reportPhotoPath` 1회만(AC-DF-021.3), 업로드 순서 | DF-128 |
| AC-ASM-06.1 | U, R | side 필수 | DF-129 |
| AC-ASM-06.2 | U, UI | 3회째 개방 규칙, UI-06 | DF-129 |
| AC-ASM-06.3 | U | 빈 칸 문서 미생성 | DF-129 |
| AC-ASM-06.4 | R, U | R-26 | DF-035, DF-129 |
| AC-ASM-06.5 | R, UI | R-29, TC-X-FLAG-01 | DF-035, DF-017 |

**시각화·공통(EP-12)**

| AC | 층 | 테스트 위치·ID | 스토리 |
|---|---|---|---|
| AC-VIZ-04.1 | L | 바디맵·히트맵 문자열 금지어('근육', '진단', '치료') | DF-117 |
| AC-VIZ-04.4 | U | TR-04 뷰 트리에 차트 타입 인스턴스 0(뷰 검사) | DF-117 |
| AC-VIZ-05.1(P1a 부분) | UI | 플래그별 이벤트 종류 표시 | DF-114 |
| AC-VIZ-05.2 | S | 같은 날 SOAP·체형 모두 표시(P1b에 체형 추가 시 DF-225) | DF-114, DF-225 |
| AC-VIZ-05.4 | SU, S | 권한 오류 모의 → `loadFailed`, 빈 상태 문구 0 | DF-114 |
| AC-VIZ-07.1 | U, UI | Swift·Flutter 모두 sourceGrade 없는 점 미렌더 | DF-130, DF-131 |
| AC-VIZ-07.2 | U | 체형·신체조성 화면 뷰 트리에 레이더 0 | DF-130 |
| AC-VIZ-07.3 | L | TC-X-GUARD-13 | DF-131 |
| AC-VIZ-07.4 | U | 사유 없는 판정 불가 배지 생성 시 테스트 실패 | DF-130 |
| AC-VIZ-07.5 | S | TC-X-A11Y-04 | DF-130 |
| AC-C-01.1 | U | `MetricRow`·차트 입력 검증 | DF-016, DF-130 |
| AC-C-01.2 | U | 측정 시각 정렬(TR-03, TR-11) | DF-114, DF-127 |
| AC-C-01.3 | U | TC-X-A11Y-02 | DF-016 |
| AC-C-02.1 | X | TC-X-XC-11(tape·observedSection 분리) | DF-216 |
| AC-C-03.1 | S, U | `pendingPolicy` 상태 스냅샷(TR-09·10·11) | DF-130, DF-210 |
| AC-C-03.2 | U | TC-X-A11Y-02와 같은 표시 모델 검사: indeterminate인데 사유 null이면 실패 | DF-130 |
| AC-C-04.1 | X, S | series-break 누락일 사례, 차트 스냅샷 | DF-130, DF-216 |
| AC-C-05.1 | I | TC-X-SYNC-02 | DF-107 |
| AC-IA-01 | S | [§10.4](#104-ui-테스트와-상태-매트릭스-스냅샷) 매트릭스 | DF-141, DF-226 |
| AC-A11Y-01~03 | UI, S | TC-X-A11Y-01~04 | DF-141, DF-226 |

**NFR(P1a)**

| NFR | 층 | 테스트 위치·ID | 스토리 |
|---|---|---|---|
| NFR-04 | SU, I, D | LocalStore 재적재, TC-X-SYNC-03, TC-X-DEV-01, 퍼시스턴스·캐시 크기 설정 값 단위 테스트 | DF-014, DF-104, DF-140 |
| NFR-05 | U, I | TC-X-SYNC-01, 04, 05, 06, 08 | DF-015, DF-107 |
| NFR-06 | U, I, L | TC-X-SYNC-02, 07, 12, TC-X-GUARD-07 | DF-015, DF-107 |
| NFR-07 | X, I | TC-X-XC-02, TC-X-SYNC-13, TC-X-SYNC-14 | DF-009, DF-104 |
| NFR-08 | SU, D | 로그아웃 시 `signOut`·리스너 해제·캐시 삭제(가짜 Auth 호출 로그), TC-X-DEV-07·08 | DF-018, DF-012 |
| NFR-09 | CI | Release 구성에서 App Attest provider 선택 확인(구성 단위 테스트) | DF-008, DF-139 |
| NFR-10 | U | TC-X-PRIV-01~03 | DF-126 |
| NFR-11 | L, D | TC-X-GUARD-06, TC-X-DEV-04 | DF-011, DF-140 |
| NFR-12 | S, D | 375pt 스냅샷, TC-X-DEV-02·03 | DF-141, DF-140 |
| NFR-15 | D | TC-X-PERF-01·02·04·05 | DF-140 |
| NFR-17 | SU, I | LocalStoreTests 보호 속성·7일 파기, TC-X-SYNC-16 | DF-014, DF-112 |

### 18.3 P1b

| AC | 층 | 테스트 위치·ID | 스토리 |
|---|---|---|---|
| AC-ASM-01.1 | SU, S | 동의 게이트 뷰 모델, TR-07 `noConsent`, 로컬 사진 파일 0 | DF-204 |
| AC-ASM-01.2 | SU, D | 셔터 게이트 로직(가짜 모션), TC-X-DEV-11·12 | DF-203, DF-204 |
| AC-ASM-01.3 | U, R | 저장 문서 필수 필드(`protocolVersion`, `captureConditions.levelDeg`, `pitchDeg`, `device.model`, `landmarkEngine`) 단위 + create 규칙 화이트리스트 | DF-203, DF-207 |
| AC-ASM-01.4 | SU, D | 합성 GPS JPEG 제거 테스트, TC-X-DEV-16 | DF-205 |
| AC-ASM-01.5 | I, D | TC-X-SYNC-15, TC-X-DEV-15 | DF-206 |
| AC-ASM-01.6 | SU | 교체 사진 로컬 삭제·업로드 큐 제외 | DF-205 |
| AC-ASM-01.7 | I | 단일 사진 삭제 → 새 버전, 이전 Storage 객체 0, 지표 동일 | DF-211 |
| AC-ASM-02.1 | U | `ConfirmabilityTests` | DF-201, DF-208 |
| AC-ASM-02.2 | UI | 사람 미검출 합성 사진에서 수동 지정 확정(UI-08) | DF-208 |
| AC-ASM-02.3 | SU, D | 매핑 단위, TC-X-DEV-19 | DF-207, DF-200 |
| AC-ASM-02.4 | U | `GeometryTests` 좌표 범위·필드 존재 | DF-201 |
| AC-ASM-02.5 | X | PM 벡터 재계산 결정성 | DF-201 |
| AC-ASM-03.1~03.4, 03.6 | X | PM-01~PM-06 | DF-201 |
| AC-ASM-03.5 | L | 결과 화면·저장 문서 문자열 금지어 | DF-210 |
| AC-ASM-04.1 | U | 확정 가능 여부(도메인), P2에 F e2e(`verifyPostureConfirmed`) | DF-209, DF-324 |
| AC-ASM-04.2 | R | AC-DF-021.1(confirmed `metrics`·`landmarks` 수정 거부) | DF-021, DF-209 |
| AC-ASM-04.3 | U, I | `supersedesId` 새 draft, 새 확정 시 이전 voided | DF-209 |
| AC-ASM-04.4 | U | voided가 추이·기준선·후보에서 제외 | DF-209, DF-217 |
| AC-ASM-04.5 | I | TC-X-SYNC-15 | DF-206 |
| AC-ASM-05.1 | R, SU | R-16, 재검사 진입 게이트 | DF-212 |
| AC-ASM-05.2 | U | 재검사 3건 중 추이 1건 | DF-212, DF-217 |
| AC-SOAP-03.1, 03.2 | U, I | `ObjectiveCandidateTests`, 확정 후 refs·snapshots 개수 | DF-217 |
| AC-SOAP-03.3 | U | '원본 변경됨' 표식·스냅샷 불변 | DF-218 |
| AC-SOAP-03.4 | U, X | 스냅샷 `pendingPolicy`, T09 | DF-217 |
| AC-SOAP-03.6 | U | lidarBeta=false면 bodyScans·observedSection 후보 0 | DF-217 |
| AC-SOAP-03.7 | SU | 권한 오류 → '불러오기 실패'·재시도 | DF-217 |
| AC-VIZ-01.1 | U | 부록 A 밖 코드 행 없음·개발 빌드 경고 | DF-210 |
| AC-VIZ-01.2 | U, S | 참고 지표 '참고' 칩·배지 없음 | DF-210 |
| AC-VIZ-01.3 | S | `tr09.pendingPolicy` | DF-210 |
| AC-VIZ-01.4 | U | draft Δ 비움 | DF-210 |
| AC-VIZ-01.5 | L | 편위 표 문자열 린트 | DF-210 |
| AC-VIZ-02.1 | S | TC-X-A11Y-04(auto/확정 모양) | DF-208 |
| AC-VIZ-02.2 | UI | UI-08 | DF-208 |
| AC-VIZ-02.3 | U, S | protocolVersion 다르면 Δ 없음·배너 | DF-214 |
| AC-VIZ-02.4 | U | 정렬 변경 전후 `metrics` 동일 | DF-214 |
| AC-VIZ-02.5 | SU | ③ 철회 회원 열 때 사진 요청 0(가짜 다운로더 호출 로그) | DF-214 |
| AC-VIZ-03.1 | X, S | series-break 벡터, Swift Charts 스냅샷 | DF-215, DF-216 |
| AC-VIZ-03.2 | S | 불규칙 간격 날짜 비례 스냅샷(1일, 30일, 2일) | DF-215 |
| AC-VIZ-03.3 | X, S | 누락일 사례 | DF-215 |
| AC-VIZ-03.5 | S | 정책 없음 → 밴드·배지 0 | DF-215 |
| AC-VIZ-03.6 | X, U | tape·observedSection 같은 plot 입력 거부 | DF-215 |
| AC-VIZ-04.3 | U | NRS 7→3, 배지 0(표시 모델) | DF-219 |
| NFR-15(촬영) | D | TC-X-PERF-03·05 | DF-223 |
| M-04a, M-04b | D | TC-X-DEV-18 | DF-223 |

### 18.4 P2(요약)

P2 스토리 카드의 `TC-3NN-kk`가 상세를 가진다. 여기서는 증명 층만 정한다.

| AC 묶음 | 층 | 핵심 테스트 | 스토리 |
|---|---|---|---|
| AC-SOAP-05.1~05.9 | F, R, UI | `createMemberSummary`·`revokeMemberSummary` e2e(필드 검사, 금지어 거부, 묘비), R-10~R-12, 미리보기 없는 공유 경로 0(UI 검사) | DF-309, DF-310, DF-311 |
| AC-SOAP-05.10~05.12 | UI, F | bodyReport 제안 3~5개, ③·토글 없을 때 `sharedPhotoPaths` 빈 배열, 제외 출처 후보 0 | DF-313 |
| AC-SOAP-07.3 | U, L | 목록 밖 약어 시 공유 비활성, TC-X-LINT-05 | DF-311 |
| AC-SOAP-07.4 | 지표 | 맞춤 문구 도입 전후 M-03·M-11 비교 보고 | DF-327 |
| AC-LINK-02.1~02.5 | F | 초대 코드 e2e 전 시나리오([§8.2](#82-함수별-필수-시나리오)) | DF-304, DF-305 |
| AC-LINK-04.1~04.3 | F | `linkMemberAlias` e2e, 기존 임상 e2e 회귀 | DF-319 |
| AC-LINK-05.1~05.5 | R, F | R-10~R-12, ④ 인계 e2e, 서명 URL 만료 | DF-332, DF-314 |
| AC-VIZ-04.2 | S | 히트맵 범례 세션 수 단위 | DF-328 |
| AC-VIZ-05.3 | F, I | 승격 전후 타임라인 끊김 없음(에뮬레이터 E2E) | DF-329, DF-305 |
| AC-VIZ-06.1~06.6 | L, UI, S | TC-X-GUARD-02, MB 골든·상태 매트릭스, 레이더 축 수 | DF-315, DF-316 |
| AC-ASM-04.1(P2) | F | `verifyPostureConfirmed` e2e | DF-324 |
| AC-ASM-05.3, 05.4 | F, UI | 가명 내보내기 자동 검사(이름·이메일·uid·사진 경로 0), 블라인드 보정 화면 | DF-326, DF-325 |
| AC-LIDAR-01.1~01.5 | UI, U, F | TC-X-FLAG-07, 검증기 거부 규칙, `observedSection` highlight 0 | DF-320, DF-313 |
| AC-LIDAR-02.1 | D | TC-X-DEV-23 | DF-321 |
| AC-LIDAR-03.1, 03.2 | U, L | `referenceTapeCm` 입력 후 스캔값 불변, TC-X-LINT-11 | DF-322, DF-321 |
| AC-PRIV-02.4 | F | ③ 철회 → `contour2dMm`·`meshSHA256`·썸네일 0, `perimeterMm` 유지 | DF-320(DF-133 확장) |
| AC-BC-02.1 | F | 결과지 경로가 `sharedPhotoPaths`에 없음 | DF-313 |
| AC-IA-04 | UI | 내 정보 탭 'SOAP 노트' 행 0, '트레이너 기록' 행 존재 | DF-315 |
| NFR-13 | UI, D | TC-X-FLAG-07, TC-X-DEV-23 | DF-321 |
| NFR-18 | CI(BodyPath) | `bodypath-core` job | DF-300, DF-302 |

### 18.5 P3(요약)

| AC·테스트 | 층 | 핵심 테스트 | 스토리 |
|---|---|---|---|
| T01~T25 | X, F | [§9.4](#94-change-evalv1jsont01t25) harness별 | DF-380~DF-383 |
| AC-SOAP-03.5 | F | 기기 변경 스냅샷 `indeterminate(deviceChanged)` + policyVersion | DF-381 |
| AC-VIZ-03.4, 03.7, 03.8 | S, U | 문헌값 문구 없으면 밴드 없음, 기준점 변경 재계산 표시, 기준 세그먼트 구간 밴드 스냅샷 | DF-382 |
| AC-BC-03.3(P3 부분) | F | 정책 MDC 있는 지표의 기기 변경 첫 점 '판정 불가(기기 변경)' | DF-381 |
| F-VIZ-06.3(회원 배지) | S, F | inHouse만 배지, literature·pendingPolicy 배지 0(T24·T25) | DF-383 |
| NFR-09(강제) | 수동 | enforceAppCheck 전후 회원 앱·admin_web 경로 스모크 | DF-386 |
| MIG-09 | UI, 수동 | `dfet/native_trainer_home` 문자열 0(정적 가드 추가), 동등성 체크리스트 | DF-387 |
| M-G4 | R | 규칙 테스트 100% | DF-390 |

### 18.6 가드레일 지표와 테스트

| 지표 | 목표 | 자동 검사 | 수동·운영 |
|---|---|---|---|
| M-G1 금지어 노출 0 | 0건 | copy-lint 차단 모드, 서버 요약 거부 e2e | G-10 체크리스트(DF-921) |
| M-G2 동의 없는 민감정보 저장 0 | 0건 | R-14, R-15, R-16, R-18(허용 대조), S-03, TC-X-SYNC-04 | 단계 종료 시 동의 상태 대조 점검 |
| M-G3 알리지 않은 저장 실패 0 | 0건 | TC-X-SYNC-02·07·10, TC-X-GUARD-07 | TC-X-DEV-01, `save_failure_shown` 이벤트와 syncFailed 대조 |
| M-G4 규칙 테스트 통과율 | 100% | `functions-and-rules` | — |
| M-G5 트레이너 일 기록 총시간 | 중앙값 15분/일 이하(가설) | — | P1b 종료 검토에서 elapsed_band 합 |

---

## 19 CI 워크플로

### 19.1 기존 job(저장소 확인 결과)

`dfet:.github/workflows/ci.yml`(워크플로 이름 `D-FET CI`)을 직접 열어 확인했다. 트리거는 `pull_request`와 `push`(브랜치 `main`, `feature/**`, :3-6), `concurrency`는 `dfet-${{ github.workflow }}-${{ github.ref }}`에 진행 중 취소(:8-10)다.

| job 이름(정확한 표기) | 러너 | 하는 일 | 근거 |
|---|---|---|---|
| `flutter` | ubuntu-latest | Java 17, Flutter stable, `pub get`, `analyze`, `test`, `build web --release`, `build apk --debug`, APK 아티팩트 | dfet:.github/workflows/ci.yml:13-33 |
| `functions-and-rules` | ubuntu-latest | Node 22, Java 21, `npm ci`, lint, `npm test`, `jq empty schemas/*.json`, firebase-tools, 규칙 에뮬레이터(`dfet-rules-test`), 테스트 HMAC `.secret.local` 생성, e2e 에뮬레이터(`dfet-e2e`) | dfet:.github/workflows/ci.yml:35-55 |
| `admin-web` | ubuntu-latest | Node 22, `npm ci`, lint, typecheck, test, build | dfet:.github/workflows/ci.yml:57-70 |
| `ios-no-codesign` | macos-latest | Flutter stable, `pub get`, `flutter build ios --release --no-codesign` | dfet:.github/workflows/ci.yml:72-81 |

- 네 job 이름은 **바꾸지 않는다.** 브랜치 보호의 필수 체크 이름이 job 이름이기 때문이다.
- 현재 `npm --prefix functions test`는 `test/clinical.test.js`만 실행한다(dfet:functions/package.json:8). 새 테스트 경로는 [§19.6](#196-스크립트-변경)에서 스크립트를 넓힌다.
- 트레이너 앱 CI는 아직 없다. `trainer_ios/`는 CI에 연결된 적이 없다.
- BodyPath는 macos-15에서 xcodegen 재생성 후 `git diff --exit-code`로 생성물을 검증한다(bodypath:.github/workflows/detail-capture.yml:25, :37-47). 트레이너 앱도 같은 방식을 쓴다(ADR-001).

### 19.2 job 목록과 필수 체크

| 워크플로 | job | 신규·확장 | 트리거 | 필수 체크 | 시간 제한 |
|---|---|---|---|---|---|
| `ci.yml` | `changes-ci` | 신규 | PR, push | 아니오(보조) | 5분 |
| `ci.yml` | `flutter` | 확장(교차 픽스처, 벡터, 골든) | PR, push | 예 | 30분 |
| `ci.yml` | `functions-and-rules` | 확장(unit·rules·e2e 경로, Auth 에뮬레이터) | PR, push | 예 | 30분 |
| `ci.yml` | `admin-web` | 확장(계약 테스트) | PR, push | 예 | 20분 |
| `ci.yml` | `ios-no-codesign` | 유지 | PR, push | 예 | 40분 |
| `ci.yml` | `contracts` | 신규 | PR, push | 예 | 10분 |
| `ci.yml` | `copy-lint` | 신규 | PR, push | 예(P0 초 보고 모드) | 10분 |
| `ci.yml` | `static-guards` | 신규 | PR, push | 예 | 10분 |
| `ci.yml` | `migrations` | 신규 | PR·push(경로 해당 시 실행, 아니면 건너뜀) | 예(건너뜀 = 통과) | 20분 |
| `ci.yml` | `docs-and-backlog` | 신규 | PR·push(경로 해당 시) | 예(건너뜀 = 통과) | 10분 |
| `trainer-app.yml` | `changes-trainer` | 신규 | PR, push, 야간, 수동 | 아니오 | 5분 |
| `trainer-app.yml` | `trainer-app` | 신규 | 경로 해당 시 | 예(건너뜀 = 통과) | 60분 |
| `trainer-app.yml` | `trainer-app-emulator-it` | 신규(P1a) | 경로 해당 시 + 매일 KST 03:00 | 예(건너뜀 = 통과) | 60분 |
| `trainer-testflight.yml` | `trainer-testflight` | 신규(P1a, DF-139) | 수동(소유자) | 아니오 | — |
| BodyPath `bodypath-core.yml` | `bodypath-core` | 신규(P2 준비) | BodyPath PR·push·태그 | BodyPath 저장소 필수 | 20분 |

- 경로 조건은 워크플로 `paths` 필터가 아니라 `changes-*` job의 출력으로 건다. `paths` 필터로 워크플로 자체가 뜨지 않으면 필수 체크가 '대기'로 남아 병합이 막히기 때문이다. 조건으로 건너뛴 job은 GitHub에서 통과로 취급된다([ASM-10-14](#221-가정)).
- 필수 체크 목록은 V1-01 DoD D2와 같다. `trainer-testflight`는 배포용이라 필수가 아니다(배포 워크플로 세부는 [V1-03 §9.1](03_RELEASE_AND_SPRINT_PLAN.md)과 DF-139 카드).

### 19.3 `ci.yml` 개정 초안

기존 네 job의 단계는 그대로 두고, 바뀌는 부분만 적었다. 주석의 스토리가 해당 부분을 추가한다.

```yaml
name: D-FET CI

on:
  pull_request:
  push:
    branches: [main]          # G-01(DF-901) 뒤 feature/** 제거. ASM-10-15

concurrency:
  group: dfet-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  changes-ci:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    outputs:
      migrations: ${{ steps.diff.outputs.migrations }}
      docs: ${{ steps.diff.outputs.docs }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - id: diff
        shell: bash
        run: |
          if [ "${{ github.event_name }}" = "pull_request" ]; then
            base="${{ github.event.pull_request.base.sha }}"
          else
            base="${{ github.event.before }}"
          fi
          if ! files=$(git diff --name-only "$base" "${{ github.sha }}" 2>/dev/null); then
            echo "migrations=true" >> "$GITHUB_OUTPUT"
            echo "docs=true" >> "$GITHUB_OUTPUT"
            exit 0
          fi
          has() { if printf '%s\n' "$files" | grep -Eq "$1"; then echo true; else echo false; fi; }
          echo "migrations=$(has '^(functions/scripts/migrations/|functions/test/migrations/|contracts/fixtures/soap_legacy)')" >> "$GITHUB_OUTPUT"
          echo "docs=$(has '^(docs/|tool/backlog/|tool/lint/doc-headers)')" >> "$GITHUB_OUTPUT"

  flutter:                    # 기존 단계 유지(dfet:.github/workflows/ci.yml:13-33)
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test     # 저장소 루트에서 실행: contracts/fixtures·vectors를 읽는다(DF-007, DF-131, DF-216)
      - run: flutter build web --release
      - run: flutter build apk --debug
      - uses: actions/upload-artifact@v4
        with:
          name: android-debug-apk
          path: build/app/outputs/flutter-apk/app-debug.apk

  functions-and-rules:        # 기존 단계 확장(dfet:.github/workflows/ci.yml:35-55)
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: npm
          cache-dependency-path: functions/package-lock.json
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "21"
      - run: npm ci --prefix functions
      - run: npm --prefix functions run lint
      - run: npm --prefix functions test                       # clinical + test/unit/**(DF-037 이후)
      - run: jq empty schemas/*.json
      - run: npm install --global firebase-tools
      - run: firebase emulators:exec --only firestore,storage --project dfet-rules-test "npm --prefix functions run test:rules"
      - name: Emulator-only test secrets (fake values)
        run: |
          printf '%s\n' \
            'INGEST_HMAC_KEYS={"e2e":"e2e-secret"}' \
            'INVITE_CODE_HMAC_KEY=e2e-invite-secret' \
            > functions/.secret.local
          # INVITE_CODE_HMAC_KEY는 P2(DF-304)에서 추가. 테스트 전용 가짜 값이다
      - run: firebase emulators:exec --only auth,functions,firestore,storage --project dfet-e2e "npm --prefix functions run test:e2e"

  admin-web:                  # 기존 단계 유지(dfet:.github/workflows/ci.yml:57-70). 테스트 파일만 늘어난다
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: npm
          cache-dependency-path: admin_web/package-lock.json
      - run: npm ci --prefix admin_web
      - run: npm --prefix admin_web run lint
      - run: npm --prefix admin_web run typecheck
      - run: npm --prefix admin_web test
      - run: npm --prefix admin_web run build

  ios-no-codesign:            # 유지(dfet:.github/workflows/ci.yml:72-81)
    runs-on: macos-latest
    timeout-minutes: 40
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter build ios --release --no-codesign

  contracts:                  # DF-004
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: npm
          cache-dependency-path: tool/package-lock.json
      - run: npm ci --prefix tool                               # ajv(ASM-10-13)
      - run: node --test 'tool/contracts/test/**/*.test.mjs'
      - run: node tool/contracts/generate.mjs --check           # 생성물 드리프트 + 메타·개별 스키마 검증(TC-X-XC-08, 09)

  copy-lint:                  # DF-010(보고 모드), DF-040(차단 모드)
    runs-on: ubuntu-latest
    timeout-minutes: 10
    env:
      COPY_LINT_MODE: report  # DF-040 병합 시 block으로 바꾼다
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "22"
      - run: node --test tool/lint/test/prohibited-terms.test.mjs
      - run: node tool/lint/prohibited-terms.mjs --mode "$COPY_LINT_MODE"

  static-guards:              # DF-011
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "22"
      - run: bash tool/lint/test/static-guards.test.sh
      - run: bash tool/lint/static-guards.sh

  migrations:                 # DF-031, DF-100
    needs: changes-ci
    if: needs.changes-ci.outputs.migrations == 'true'
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: npm
          cache-dependency-path: functions/package-lock.json
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "21"
      - run: npm ci --prefix functions
      - run: npm install --global firebase-tools
      - run: firebase emulators:exec --only firestore,storage --project dfet-e2e "npm --prefix functions run test:migrations"

  docs-and-backlog:           # DF-001, DF-002
    needs: changes-ci
    if: needs.changes-ci.outputs.docs == 'true'
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "22"
      - run: node --test tool/lint/test/doc-headers.test.mjs
      - run: node tool/lint/doc-headers.mjs                     # 헤더 표준 + 상대 링크
      - run: node tool/backlog/build_issues.mjs --check          # issues.json 드리프트(TL-01 §6)
      - run: node tool/backlog/validate_backlog.mjs --prd docs/PRD_V1.md
      - run: bash tool/backlog/test/run.sh                        # 가짜 gh 시나리오
      - run: bash tool/backlog/create_backlog.sh --dry-run --offline > /dev/null
```

### 19.4 `trainer-app.yml` 초안(DF-008, DF-107)

```yaml
name: Trainer App

on:
  pull_request:
  push:
    branches: [main]
  schedule:
    - cron: '0 18 * * *'      # 매일 KST 03:00(AC-DF-107.5)
  workflow_dispatch:

concurrency:
  group: trainer-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

env:
  SIM_DEST: platform=iOS Simulator,name=iPad Pro 13-inch (M4)
  SIM_DEST_11: platform=iOS Simulator,name=iPad Pro 11-inch (M4)

jobs:
  changes-trainer:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    outputs:
      app: ${{ steps.diff.outputs.app }}
      it: ${{ steps.diff.outputs.it }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - id: diff
        shell: bash
        run: |
          if [ "${{ github.event_name }}" = "schedule" ] || [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
            echo "app=true" >> "$GITHUB_OUTPUT"; echo "it=true" >> "$GITHUB_OUTPUT"; exit 0
          fi
          if [ "${{ github.event_name }}" = "pull_request" ]; then
            base="${{ github.event.pull_request.base.sha }}"
          else
            base="${{ github.event.before }}"
          fi
          if ! files=$(git diff --name-only "$base" "${{ github.sha }}" 2>/dev/null); then
            echo "app=true" >> "$GITHUB_OUTPUT"; echo "it=true" >> "$GITHUB_OUTPUT"; exit 0
          fi
          has() { if printf '%s\n' "$files" | grep -Eq "$1"; then echo true; else echo false; fi; }
          echo "app=$(has '^(trainer_app/|contracts/|\.github/workflows/trainer-app\.yml)')" >> "$GITHUB_OUTPUT"
          echo "it=$(has '^(trainer_app/|firestore\.rules|storage\.rules|functions/src/|functions/scripts/dev/|functions/test/fixtures/|\.github/workflows/trainer-app\.yml)')" >> "$GITHUB_OUTPUT"

  trainer-app:
    needs: changes-trainer
    if: needs.changes-trainer.outputs.app == 'true'
    runs-on: macos-15
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@v4
      - name: Toolchain versions
        run: xcodebuild -version && swift --version && xcrun simctl list runtimes
      - name: Install pinned XcodeGen (2.44.1, ASM-10-26)
        run: |
          V=$(cat trainer_app/.xcodegen-version)
          curl -fsSL -o "$RUNNER_TEMP/xcodegen.zip" "https://github.com/yonaskolb/XcodeGen/releases/download/${V}/xcodegen.zip"
          echo "a2e905fb68446e9bb4008cdfe2e13e3f176d0cbcca828b71770f8e53fca91b73  $RUNNER_TEMP/xcodegen.zip" | shasum -a 256 -c -
          unzip -q "$RUNNER_TEMP/xcodegen.zip" -d "$RUNNER_TEMP/xcodegen"
          echo "$RUNNER_TEMP/xcodegen/xcodegen/bin" >> "$GITHUB_PATH"
      - name: Generated project is current (ADR-001)
        run: |
          xcodegen version
          xcodegen generate --spec trainer_app/project.yml --project trainer_app
          git diff --exit-code -- trainer_app/DFETTrainer.xcodeproj
      - name: Pure targets on macOS (TrainerContracts, TrainerDomain, PostureMath, SyncEngine, TrainerAnalytics)
        run: swift test --package-path trainer_app/Packages/TrainerCore
      - name: Firebase app config (optional secret, ADR-019)
        env:
          PLIST_B64: ${{ secrets.TRAINER_GOOGLE_SERVICE_INFO_PLIST_B64 }}
        run: |
          if [ -n "$PLIST_B64" ]; then
            printf '%s' "$PLIST_B64" | base64 --decode > trainer_app/Config/GoogleService-Info.plist
          fi
      - name: Unit, snapshot, UI smoke, accessibility audit (iPad 13)
        run: |
          set -o pipefail
          mkdir -p build
          xcodebuild test -project trainer_app/DFETTrainer.xcodeproj -scheme DFETTrainer -testPlan CI \
            -destination "$SIM_DEST" -resultBundlePath build/ci-13.xcresult \
            CODE_SIGNING_ALLOWED=NO | tee build/ci-13.log
      - name: Canvas ratio smoke (iPad 11, AC-SOAP-01.1)
        run: |
          set -o pipefail
          xcodebuild test -project trainer_app/DFETTrainer.xcodeproj -scheme DFETTrainer -testPlan CI \
            -destination "$SIM_DEST_11" -only-testing:UITests/LiveCanvasUITests \
            -resultBundlePath build/ci-11.xcresult CODE_SIGNING_ALLOWED=NO | tee build/ci-11.log
      - name: Release configuration build (no codesign)
        run: |
          set -o pipefail
          xcodebuild build -project trainer_app/DFETTrainer.xcodeproj -scheme DFETTrainer -configuration Release \
            -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO | tee build/release.log
      - name: Remove injected config
        if: always()
        run: rm -f trainer_app/Config/GoogleService-Info.plist
      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: trainer-app-results
          path: |
            build/*.xcresult
            build/*.log

  trainer-app-emulator-it:
    needs: changes-trainer
    if: needs.changes-trainer.outputs.it == 'true'
    runs-on: macos-15
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: npm
          cache-dependency-path: functions/package-lock.json
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "21"
      - run: npm ci --prefix functions
      - run: npm install --global firebase-tools
      - name: Install pinned XcodeGen (2.44.1, ASM-10-26)
        run: |
          V=$(cat trainer_app/.xcodegen-version)
          curl -fsSL -o "$RUNNER_TEMP/xcodegen.zip" "https://github.com/yonaskolb/XcodeGen/releases/download/${V}/xcodegen.zip"
          echo "a2e905fb68446e9bb4008cdfe2e13e3f176d0cbcca828b71770f8e53fca91b73  $RUNNER_TEMP/xcodegen.zip" | shasum -a 256 -c -
          unzip -q "$RUNNER_TEMP/xcodegen.zip" -d "$RUNNER_TEMP/xcodegen"
          echo "$RUNNER_TEMP/xcodegen/xcodegen/bin" >> "$GITHUB_PATH"
      - name: Generate project
        run: xcodegen generate --spec trainer_app/project.yml --project trainer_app
      - name: Emulator-only test secrets (fake values)
        run: printf '%s\n' 'INGEST_HMAC_KEYS={"e2e":"e2e-secret"}' > functions/.secret.local
      - name: Integration tests against emulators (demo-dfet)
        run: |
          set -o pipefail
          mkdir -p build
          firebase emulators:exec --only auth,firestore,storage,functions --project demo-dfet \
            "node functions/scripts/dev/seed-emulator.js --seed functions/test/fixtures/emulator-seed.v1.json && \
             xcodebuild test -project trainer_app/DFETTrainer.xcodeproj -scheme DFETTrainer -testPlan Integration \
               -destination '$SIM_DEST' -resultBundlePath build/it.xcresult CODE_SIGNING_ALLOWED=NO" \
            | tee build/it.log
      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: trainer-it-results
          path: |
            build/it.xcresult
            build/it.log
```

- 테스트 계획: `trainer_app/TestPlans/CI.xctestplan`(TrainerKit 시뮬레이터 단위 타깃 + 스냅샷 + `UITests`, `IntegrationTests` 제외), `Integration.xctestplan`(`IntegrationTests`만). 패키지 테스트 타깃을 스킴에 넣는 XcodeGen 설정은 DF-008이 정한다([ASM-10-12](#221-가정)).
- 스냅샷 기록 모드는 CI에서 켜지 않는다. `SNAPSHOT_RECORD` 환경 변수를 워크플로에 두지 않는다.
- 통합 테스트는 테스트 클래스마다 에뮬레이터를 초기화한다: Firestore REST `DELETE /emulator/v1/projects/demo-dfet/databases/(default)/documents`, Storage·Auth 에뮬레이터 초기화 엔드포인트 호출 뒤 같은 시드 JSON을 `Authorization: Bearer owner`로 다시 쓴다([ASM-10-18](#221-가정)). 시드 적재 스크립트와 하네스가 같은 파일을 읽는다.
- 야간 실행에서 SIM-2 전체 스냅샷과 SIM-4(iOS 17.x 런타임, 러너에 있을 때) 스모크를 추가로 돈다. 런타임이 없으면 건너뛰고 로그에 남긴다(ASM-10-04). 이 단계는 DF-141에서 `trainer-app` job에 `if: github.event_name == 'schedule'` 단계로 더한다.
- `trainer-app` job에서 `IntegrationTests`를 돌리지 않는 이유: 에뮬레이터 기동·시드에 수 분이 들고, 트레이너 앱 UI만 바꾼 PR에는 불필요하다. 규칙·함수를 바꾼 PR은 `it` 경로 조건으로 통합 테스트가 돈다.

### 19.5 `bodypath-core.yml` 초안(BodyPath 저장소, DF-300·DF-302)

```yaml
name: BodyPathCore

on:
  pull_request:
  push:
    branches: [main]
    tags: ['bodypathcore-v*']

permissions:
  contents: read

jobs:
  bodypath-core:
    runs-on: macos-15
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
      - name: v1 product import guard (NFR-18)
        run: |
          if grep -rnE '^[[:space:]]*import[[:space:]]+(ARKit|SwiftData|UIKit)([[:space:]]|$)' packages/BodyPathCore/Sources; then
            echo "BodyPathResult·BodyPathCoreUI에 금지 import가 있다"; exit 1
          fi
      - name: Package tests (DTO round-trip, validator, section plot snapshots)
        run: swift test
```

- 기존 `detail-capture.yml`(bodypath:.github/workflows/detail-capture.yml)은 그대로 둔다. 두 워크플로가 모두 병합 게이트다.

### 19.6 스크립트 변경

`functions/package.json`(현재 dfet:functions/package.json:6-16). 바뀌는 키만 적었고 `serve`, `shell`, `start`, `deploy`, `logs`는 그대로 둔다:

```json
"scripts": {
  "lint": "node --check index.js && find src scripts -name '*.js' -print0 | xargs -0 -n1 node --check",
  "test": "node --test test/clinical.test.js 'test/unit/**/*.test.js'",
  "test:rules": "node --test --test-concurrency=1 test/firestore-rules.test.js \"test/rules/**/*.test.js\"",
  "test:e2e": "node --test test/clinical-emulator-e2e.js 'test/e2e/**/*.test.js'",
  "test:migrations": "node --test 'test/migrations/**/*.test.js'"
}
```

- 디렉터리 인자 대신 glob을 쓴다(Node 22 테스트 러너의 glob 지원). `test/rules/_harness.js` 같은 도우미는 `*.test.js`가 아니므로 실행 대상이 아니다([ASM-10-23](#221-가정)).
- `test:rules`는 `--test-concurrency=1`로 파일을 하나씩 돌리고, 파일마다 projectId `dfet-rules-<파일명>`을 쓴다(DF-022 카드, ASM-P0-26). 규칙 파일이 16개로 늘어도 에뮬레이터 데이터가 섞이지 않게 하기 위해서다.
- lint 대상에 `scripts/`(이관·개발 시드 스크립트)를 넣는다.
- 새 npm 의존성은 없다(ADR-017). ajv는 `tool/package.json`에만 둔다(ASM-10-13).

---

## 20 단계별 테스트 종료 기준

단계 종료 검토([V1-T06](templates/PHASE_EXIT_REVIEW.md), PRD §12.7)에 아래 증빙을 첨부한다. 게이트 증빙은 [V1-T07](templates/GATE_EVIDENCE.md)이다. 공통 조건: **열린 S1·S2 결함 0**, 필수 CI 최근 main 커밋 초록, 해당 단계 [§18](#18-수용-기준--테스트-카탈로그) 표의 모든 행에 통과한 테스트 이름 또는 수동 기록 연결.

### 20.1 P0(MS-P0, S05 목표 2026-10-30)

| 구분 | 증빙 | 연결 |
|---|---|---|
| 자동 | R-01~R-31, S-01~S-08 100%(M-G4), 기존 describe 5개 초록 | G-03 |
| 자동 | TC-X-XC-01~05·08·09 두 플랫폼 초록(교차 왕복) | PRD §12.1 P0 종료 |
| 자동 | copy-lint 차단 모드 위반 0(출시 앱 문자열 포함, TC-X-LINT-09·10) | PRD §12.1 P0 종료, DF-040 |
| 자동 | static-guards 초록(기준선 고정), trainer-app 초록(xcodegen diff 0, swift test, Release 빌드) | NFR-01, NFR-03 |
| 자동 | `syncRecordAccessKeys` e2e ①~⑦ | F-LINK-03 |
| 자동 | migrations: TC-X-MIG-01~09 초록(dry-run, 멱등) | MIG-02, MIG-03 |
| 수동 | S-09 실환경 기록(DF-038) | G-03 |
| 수동 | claim 계정 로그인·memberIds 로드 기록(가상 회원, DF-012·DF-013) | G-02 |
| 수동 | MIG-02 보고서(수량만, DF-907) | MIG-02 |

### 20.2 P1a(MS-P1a, S15 목표 2027-01-08)

| 구분 | 증빙 | 연결 |
|---|---|---|
| 자동 | P0 증빙 유지 + [§18.2](#182-p1a) 전 행 | — |
| 자동 | `trainer-app-emulator-it` 최근 야간 5회 연속 초록, TC-X-SYNC-01~14·16 | NFR-04~NFR-06, C-05 |
| 자동 | P1a 화면 상태 매트릭스 스냅샷 전부, TC-X-A11Y-01~05·07 | AC-IA-01, AC-A11Y-01~03 |
| 자동 | Functions e2e: recordConsent, deleteMemberCascade, purgeExpiredRecords, 권리 요청, logRecordAccess, auditSoapFinalized, opsMetrics | F-PRIV-01~05, 07 |
| 자동 | TC-X-MIG-10 리허설(적용→롤백→재적용) 첨부 후 DF-924 실행 기록 | MIG-11 |
| 수동 | TC-X-DEV-01~10 기록(V1-T09) | NFR-04, NFR-11, NFR-12 |
| 지표 | TC-X-PERF-01·02·04·05 수치 제출(NFR-15 P1a 측정) | NFR-15 |
| 지표 | 2주 이상 자체 사용: 데이터 유실 0, 알리지 않은 저장 실패 0(M-G3), 금지어 노출 0(M-G1), M-01 텍스트 평균 10초 미만(30초 초과 비율 함께), M-02·M-08·M-11 측정 | PRD §12.1 P1a 종료 |

### 20.3 P1b(MS-P1b, S18 목표 2027-01-29)

| 구분 | 증빙 | 연결 |
|---|---|---|
| 자동 | [§18.3](#183-p1b) 전 행, PM 벡터 전부, series-break 벡터 두 플랫폼, TC-X-SYNC-15 | F-ASM-01~04, F-VIZ-01~03 |
| 자동 | TR-07~TR-10 상태 매트릭스 스냅샷, 접근성 감사(DF-226) | AC-IA-01, AC-A11Y |
| 자동 | change-eval 벡터 초안 존재(T09 엔진 사례는 P3에 활성) | ADR-009 |
| 수동 | TC-X-DEV-11~19 기록(촬영 프로토콜 v1 기준, DF-223) | PRD §12.5 iPad 실기기 촬영 |
| 지표 | TC-X-PERF-03·05, M-04a·M-04b·M-03·M-05(조건 사유), M-G5 검토 | NFR-15, PRD §12.1 P1b 종료 |

### 20.4 P2(MS-P2, S26 잠정 2027-03-26)

| 구분 | 증빙 | 연결 |
|---|---|---|
| 자동 | [§18.4](#184-p2요약) 전 행, 공유·해제 E2E(회원은 memberSummaries만), 담당 변경·④ 인계·탈퇴 연쇄(DF-332) | PRD §12.1 P2 종료 |
| 자동 | MB-01~MB-06 골든·상태 매트릭스, TC-X-A11Y-08·09 | AC-IA-01, AC-A11Y |
| 자동 | `bodypath-core` 초록과 태그(G-07a 전제, lidarBeta 개방 시) | NFR-18 |
| 수동 | TC-X-DEV-21~23·31 | F-LIDAR, MB 흐름 |
| 지표 | M-06·M-07·M-09·M-10, G-07 예비 결과와 베타 유지·해제 판단 | PRD §12.1 P2 종료 |

### 20.5 P3(MS-P3, S32 잠정 2027-05-07)

| 구분 | 증빙 | 연결 |
|---|---|---|
| 자동 | T01~T25 전부(harness별), 규칙 테스트 100% | §7.9, M-G4 |
| 자동 | Runner 트레이너 제거 후 회원 회귀(TC-X-REG-02), `dfet/native_trainer_home` 문자열 0 | MIG-09 |
| 수동 | App Check 강제 전후 스모크, TC-X-REG-04 전체, G-10 체크리스트 | NFR-09, G-10 |
| 지표 | 가설 목표 4주 유지, 중대 개인정보 사고(S1 개인정보 유형) 0 | PRD §12.1 P3 종료 |

---

## 21 결함 심각도·분류

### 21.1 심각도

심각도 정의는 [V1-01 버그](01_AGILE_WORKING_AGREEMENT.md#버그)와 [V1-T13](templates/BUG_REPORT.md)이 정본이다. 테스트에서 자주 나오는 경우를 심각도에 대응시킨다.

| 관찰(테스트·실사용) | 심각도 | 근거 |
|---|---|---|
| 규칙 거부·네트워크 오류 뒤 '동기화됨' 표시, 로컬 원본 유실, 중복 문서 | S1 | M-G3, C-05, NFR-04 |
| 비담당·해제 트레이너가 기록을 읽음(규칙 테스트 누락으로 운영에서 발견) | S1 | F-LINK-03, §12.4 |
| 동의 없는 회원 기록이 서버에 저장됨 | S1 | M-G2 |
| 회원 노출 문자열의 금지어(요약·알림·회원 앱) | S1 | M-G1 |
| 테스트·픽스처·로그에 실데이터·비밀 | S1 | §2.1, NFR-10 |
| 규칙 테스트 실패(main), 교차 픽스처 불일치, syncState 오표시(거짓 성공이 아닌 경우), 크래시 | S2 | M-G4, NFR-06 |
| `RecordComplete` p95 1초 초과(대상 iPad) | S2 | ASM-10-10 |
| 트레이너 전용 문자열의 금지어(린트가 놓친 경우) | S2 | 부록 C |
| 상태 매트릭스 누락, 1/3 Split View 잘림, 접근성 감사 위반, 성능 가설 목표 미달(1초 이하) | S3 | AC-IA-01, NFR-12, NFR-15 |
| 표기·정렬, 스냅샷 미세 차이 | S4 | — |

### 21.2 분류 흐름

```
발견(CI·야간·실기기·자체 사용·코드 검토)
  └▶ bug.yml 이슈(합성 데이터 재현, 심각도 필드) ─ 같은 스프린트 병합 스토리의 결함이면 스토리 reopen
       └▶ 소유자 분류(평일 매일 비동기, 수요일 게이트 점검에서 재확인)
            ├─ S1 ▶ 즉시 조치(PRD §12.4: 플래그 off·요약 revoked·단계적 출시 중지) ▶ 24시간 안에 사후 검토 절 ▶ 수정
            ├─ S2 ▶ 현재 스프린트 버퍼(2점)로 수정. 넘치면 가장 낮은 우선순위 스토리 이월
            ├─ S3 ▶ 다음 다듬기에서 우선순위 결정
            └─ S4 ▶ 백로그
       └▶ 수정 PR: 재현 테스트(실패→통과) + 관련 AC 회귀 + (S1·S2) 정적 가드 추가 검토
```

| 심각도 | 분류까지 | 즉시 조치까지 | 수정 목표 |
|---|---|---|---|
| S1 | 인지 즉시 | 같은 작업일 | 다음 작업일 안 수정 PR, 사후 검토 24시간 |
| S2 | 1작업일 | 필요 시 플래그 off | 현재 스프린트 |
| S3 | 다음 다듬기(목요일) | — | 다음 스프린트 이후 |
| S4 | 다음 다듬기 | — | 백로그 |

- 라벨: `type/bug`, `area/*`, `phase/*`, `prio/*`. 심각도는 이슈 폼 필드로 기록하고 별도 라벨을 만들지 않는다(labels.json 변경 없음, [ASM-10-16](#221-가정)). S1은 해당하면 `privacy-impact` 또는 `regulatory`를 붙인다.
- 비인가 노출·유출 S1은 통지 필요성 법률 검토를 소유자 행동으로 연다(V1-T13 사후 검토 절).

### 21.3 CI 실패·불안정 테스트

| 상황 | 처리 |
|---|---|
| main의 필수 체크가 빨강 | 새 병합 중지. 같은 작업일에 원인 PR을 되돌리거나(revert) 고친다. 원인이 규칙·함수면 S2 이슈 |
| 야간 `trainer-app-emulator-it` 실패 | 다음 작업일 첫 일로 분류. 이틀 연속 실패면 S2 |
| 불안정(같은 커밋에서 성공·실패가 섞임) | 단위·규칙·Functions·통합·교차 픽스처·벡터: **재시도·격리 금지**. 원인을 고친다(대개 시계·ID 주입 누락, 테스트 간 에뮬레이터 상태 공유). UI 테스트(`UITests`)만 `-retry-tests-on-failure -test-iterations 2`를 허용하고, 재시도로 통과한 테스트는 S3 이슈로 기록한다([ASM-10-17](#221-가정)) |
| 스냅샷 차이 | 의도한 변경이면 PR에서 기준 이미지 갱신과 소유자 확인. 런타임 변경 때문이면 기준 일괄 갱신 PR을 따로 연다 |
| 외부 요인(러너 이미지, Xcode 기본 버전 변경) | `Toolchain versions` 단계 로그로 확인하고 `chore` 이슈. V1-13 도구 버전 표 갱신 |

### 21.4 유출 결함 사후 조치

- 실기기·자체 사용·운영에서 발견된 결함(CI가 잡지 못한 것)은 스프린트 회고([V1-T11](templates/RETRO.md))에서 '어느 층에서 잡았어야 했나'를 적고, [§18](#18-수용-기준--테스트-카탈로그) 표에 빠진 테스트를 추가한다.
- 같은 유형이 두 번 유출되면 해당 층의 규칙(예: 쿼리 증명 테스트 필수, 정적 가드 추가)을 V1-01 DoD 개정 제안으로 올린다.

---

## 22 가정(ASM-10-NN)과 충돌

ID는 이 문서 한정이다. PRD로 올릴 때는 PRD §13.4에 따라 AS-34 이후 번호를 새로 받는다.

### 22.1 가정

| ID | 가정 | 관련 PRD·문서 | 틀리면 |
|---|---|---|---|
| ASM-10-01 | 스토리 테스트 ID는 `TC-NNN-kk`로 통일한다. P0 백로그의 `TC-DFNNN-kk`는 같은 뜻의 별칭이고 추적 grep은 `TC-(DF)?[0-9]{3}-[0-9]{2}`로 둘 다 찾는다 | V1-01 ID 체계, AS-DEV 목록 | P0 카드 ID를 일괄 치환한다 |
| ASM-10-02 | 테스트 픽스처는 [P0 DF-005 픽스처 규약](backlog/P0.md#fixture-contract)(봉투 `{_fixture, path, data}`, 태그 `$ts`·`$int`·`$bytes`·`$serverTimestamp`, `fx-` 합성 ID, 기대 결과 `soap_legacy/expected_v2/`)을 따른다(ASM-P0-01). V1-05 예시의 ISO 문자열·`"<serverTimestamp>"`는 읽기용 표기다 | PRD §9.3 교차 테스트, V1-05 §1, ASM-P0-01 | 두 로더의 변환 규칙만 바꾼다 |
| ASM-10-03 | 에뮬레이터 포트는 Firestore 18080, Storage 19199(기존), Auth 19099, Functions 5001이고 트레이너 통합 테스트 프로젝트 ID는 `demo-dfet`다 | V1-04 ASM-04-09, AS-DEV-02 | 포트·ID 상수만 바꾼다 |
| ASM-10-04 | macos-15 러너에 iOS 17.x 시뮬레이터 런타임이 없을 수 있다. 없으면 SIM-4를 건너뛰고 최저 버전 확인은 실기기(대상 iPad의 OS가 17.x일 때) 또는 P3 전 수동 1회로 대신한다 | NFR-01, AS-DEV-06 | 런타임 설치 단계를 추가한다 |
| ASM-10-05 | '대상 iPad' 기종은 소유자가 DF-140 첫 기록에 적고 NFR-15 판정은 그 기종 기준이다 | NFR-15, Q-15 | 기종별 목표를 따로 둔다 |
| ASM-10-06 | Vision 종단 테스트 이미지는 라이선스를 확인한 마네킹·CC0 이미지만 커밋하고, 확인 전에는 실기기 확인으로 대신한다 | AC-ASM-02.3, ASM-P1b-39, ADR-013 | 종단 테스트를 실기기 전용으로 둔다 |
| ASM-10-07 | 얼굴 가림 썸네일에서 얼굴을 검출하지 못하면 썸네일 전체를 가린다(보수적 기본값). 최종 규칙은 V1-09·V1-07 | F-ASM-01.10 | 테스트 기대값만 바꾼다 |
| ASM-10-08 | 판정 엔진은 저장 정밀도 단위 정수(각도·kg·%·cm ×10, NRS ×1)로 Δ를 계산하고, 벡터 비교도 그 단위로 한다 | PRD §7.5 Δ 계산, T02~T04 | V1-09 규칙에 맞춰 비교 허용 오차를 둔다 |
| ASM-10-09 | 스냅샷 기준 이미지는 CI와 같은 시뮬레이터 런타임에서 만든다 | ADR-013 | 허용 오차(precision) 옵션을 둔다 |
| ASM-10-10 | `RecordComplete` p95가 대상 iPad에서 1초를 넘으면 S2, 300ms~1초는 목표 재설정 논의 항목(S3) | NFR-15, M-01 | 소유자가 단계 종료 검토에서 조정 |
| ASM-10-11 | Flutter 저장소 테스트는 새 의존성 없이 쿼리 빌더 인자(컬렉션·where·orderBy)만 검증하고, 실제 허용은 규칙 쿼리 증명 테스트가 맡는다 | ADR-017 원칙, PRD §9.6 | `fake_cloud_firestore` 도입 ADR |
| ASM-10-12 | 테스트 계획 `CI.xctestplan`, `Integration.xctestplan`을 두고, TrainerKit 시뮬레이터 단위 타깃을 스킴에 넣는 방식은 DF-008이 정한다 | ADR-001 | 스킴 테스트 타깃 목록으로 대신 |
| ASM-10-13 | ajv는 `tool/package.json`(devDependency)에만 둔다. `functions/`·`admin_web/`에는 새 의존성이 없다 | ADR-005, ADR-017 | 생성기를 functions 안으로 옮긴다 |
| ASM-10-14 | 경로 조건 job은 `changes-*` job 출력으로 건너뛰며, 건너뛴 job은 필수 체크를 통과한 것으로 취급된다 | V1-01 DoD D2 | 경로 조건을 없애고 모든 PR에서 실행 |
| ASM-10-15 | `ci.yml` push 트리거는 G-01 뒤 `main`만 남긴다(`feature/integrated-care-2026` 삭제, AS-DEV-11) | ADR-014 | 기존 `feature/**` 유지 |
| ASM-10-16 | 결함 심각도는 이슈 폼 필드로만 기록하고 `sev/*` 라벨은 만들지 않는다 | V1-01 라벨 체계 | labels.json에 라벨 추가 |
| ASM-10-17 | 재시도는 `UITests`에만 1회 허용한다 | M-G4, ADR-013 | 재시도 전면 금지 |
| ASM-10-18 | 통합 테스트는 클래스마다 에뮬레이터 REST로 초기화하고 같은 시드를 owner 토큰으로 다시 쓴다 | ADR-013, DF-107 | 테스트마다 새 프로젝트 ID를 쓴다 |
| ASM-10-19 | 실기기 EXIF 확인은 기기를 로컬 에뮬레이터에 연결해(`--use-emulator --emulator-host=<Mac IP>`) 한다. 운영에 사진을 올리지 않는다 | AC-ASM-01.4, V1-04 §19.2 | 운영 가상 계정으로 1회 |
| ASM-10-20 | 인덱스 누락 검사용 쿼리 카탈로그는 DF-024가 `functions/test/fixtures/query-catalog.v1.json`으로 만든다(V1-06 쿼리 표에서 옮김) | PRD §9.6 | 인덱스 검사를 수동 검토로 대신 |
| ASM-10-21 | 성능 signpost는 subsystem `kr.co.dfet.trainer`, category `perf`, 구간 이름 5개([§14.1](#141-계측-지점))로 고정한다 | NFR-15 | 이름만 바꾼다 |
| ASM-10-22 | 상태 주입 인자는 `--preview-state=<화면>.<상태>`, 플래그는 `--preview-flags=`다(ASM-P1b-34와 같음) | AC-IA-01, V1-04 §19.2 | V1-07 규칙으로 맞춘다 |
| ASM-10-23 | Node 22 테스트 러너에 디렉터리 대신 glob을 넘긴다 | ADR-017 | 파일 목록을 스크립트에 나열 |
| ASM-10-24 | 시드 정본: `functions/scripts/dev/seed-emulator.js` + `functions/test/fixtures/emulator-seed.v1.json`(+변형 `emulator-seed.no-consent.v1.json`·`emulator-seed.consent-fail.v1.json`), 프로젝트 `demo-dfet`, synth ID(`synthTrainerA`·`synthMember0001`·`SYNTHpending00000001`)(R2, 결정 2026-09-24). 스크립트·기본 파일은 P0 시드 스토리(DF-042 채택 시 DF-042, 아니면 DF-012), P1a 추가분·변형은 DF-107 | ADR-013, AS-DEV-02, V1-05 §16, V1-13 ASM-13-02, P1a ASM-P1a-48 | 다른 경로·ID를 쓰는 문서를 이 정본으로 고친다 |
| ASM-10-25 | 순수 타깃 테스트는 `trainer_app/Packages/TrainerCore/Tests/<Target>Tests/`에 두고, 픽스처·벡터는 `#filePath`로 저장소 루트 `contracts/`를 직접 읽는다(번들 복사 단계 없음). iOS 전용 타깃 테스트는 `trainer_app/Packages/TrainerKit/Tests/<Target>Tests/`(R4, 결정 2026-09-24) | V1-04 §6.2, ADR-001 | 패키지 경계와 테스트 경로만 바꾼다 |
| ASM-10-26 | XcodeGen은 `trainer_app/.xcodegen-version`의 2.44.1 GitHub 릴리스 zip을 SHA-256 대조 후 설치한다. Homebrew 설치는 버전이 고정되지 않아 쓰지 않는다(R8, 결정 2026-09-24) | ADR-001, SPRINT_01 §7.4·ASM-S01-09, AS-DEV-06 | `.xcodegen-version`과 해시를 같은 PR에서 올린다 |

### 22.2 스파인·PRD·다른 문서와의 충돌

충돌 ID는 CF-10-NN(R10)이다. PRD 제약 C-01~C-06과 겹치지 않도록 이전 판의 `C-N`을 번호를 유지한 채 바꿨다(예: C-13 → CF-10-13).

| ID | 내용 | 이 문서의 처리 | 필요한 결정 |
|---|---|---|---|
| CF-10-01 | 테스트 ID 표기가 둘이다: P0 백로그 `TC-DFNNN-kk`, P1a·P2 백로그 `TC-NNN-kk` | `TC-NNN-kk`를 정본으로, 별칭 인정(ASM-10-01) | P0 백로그 표기 정리 |
| CF-10-02 | DF-107 카드의 에뮬레이터 포트(Auth 9099, Firestore 8080, Storage 9199)와 프로젝트 ID `dfet-e2e`가 실제 `firebase.json`(Firestore 18080 dfet:firebase.json:40, Storage 19199 :44)·V1-04(Auth 19099, `demo-dfet`)와 다르다 | 이 문서와 V1-04를 따른다(ASM-10-03) | DF-107 카드 수정 |
| CF-10-03 | 시드 스크립트 위치: V1-05 §16은 `tool/emulator/seed.mjs`, DF-107 카드는 `functions/scripts/dev/seed-emulator.js` | 구현 스토리를 따른다 → 해소(정합 패스 2): 정본 `functions/scripts/dev/seed-emulator.js`(R2, [ASM-10-24](#221-가정)). V1-05 §16 수정 완료 | 없음 |
| CF-10-04 | V1-05 §9.1은 `test:rules`에 디렉터리 `test/rules/`를 넘긴다 | DF-022 카드대로 glob과 `--test-concurrency=1`을 쓴다(ASM-10-23, ASM-P0-26) | V1-05 §9.1 문구 수정 |
| CF-10-13 | V1-05 §9.1(과 이 문서의 이전 판)은 규칙 테스트를 `soap_notes`·`access`·`measurements`·`consent_pending` 4개 파일로 나누고 R-18·R-19를 DF-022의 `soap_notes`에 두었다. DF-022 카드는 4개 파일(`soap_notes`, `assignment`, `member_access`, `legacy_switch`), DF-035 카드는 8개 파일을 두고 R-14~R-20을 DF-035에 배정한다. 하네스 이름도 `_seed.js`와 `_harness.js`로 달랐다 | 카드를 정본으로 [§7.2](#72-파일-배치df-022df-035-카드-기준)를 고쳤다. R-18·R-19는 DF-035 `pending_members.rules.test.js`, 하네스는 `_harness.js` | V1-05 §9.1 표와 하네스 이름을 카드에 맞춰 수정 |
| CF-10-14 | [§7.4](#74-쿼리-증명-테스트)의 목록 쿼리 '허용' 증명(`queries.rules.test.js`)은 DF-024 카드의 구현 노트·테스트 표에 없다(카드는 `indexes.test.js`와 리뷰 체크리스트만) | DF-024 소유로 두되, 카드에 반영되기 전에는 AC-DF-024.3 리뷰 체크리스트의 증빙으로 쓴다. R 번호가 있는 쿼리(R-11, R-13, R-25, R-28)는 각 R 파일에서 이미 검증한다 | DF-024 카드에 TC 1행 추가 |
| CF-10-05 | 미리보기 인자: V1-04 §19는 `--preview-<scenario>`, P1b 백로그는 `--preview-state=` | `--preview-state=`를 쓴다(ASM-10-22). 기존 `--preview-*` 접두와 호환 | V1-04·V1-07 표기 맞춤 |
| CF-10-06 | 스파인 ciJobs의 `trainer-app`은 경로 트리거지만 V1-01 DoD D2는 모든 PR의 필수 체크로 둔다 | `changes-trainer` 출력으로 건너뛰기(ASM-10-14) | 없음 |
| CF-10-07 | PRD §12.5 표가 규칙 에뮬레이터 단계를 `ci.yml:52`로 인용하나 실제 단계는 :53이다(:52는 firebase-tools 설치) | 이 문서는 :53으로 인용 | PRD 개정 때 줄 번호 정정 |
| CF-10-08 | AC-SOAP-01.1은 '12.9형·11형'이지만 현행 시뮬레이터 기종명은 13-inch(M4)다 | 13형을 12.9형 대응으로 본다 | 없음(PRD 개정 때 표기) |
| CF-10-09 | PRD §7.9의 T08·T22·T24·T25는 판정 엔진 입력만으로 검증할 수 없다(표시·차트·요약) | `harness` 필드로 실행 위치를 나눈다([§9.4](#94-change-evalv1jsont01t25)) | 없음 |
| CF-10-10 | AC-PRIV-02.2의 '1분 안에 회원 앱 요약이 사라짐'은 P1a AC지만 memberSummaries는 P2부터 생긴다 | P1a에는 트레이너 쿼리 0건·파기만 검증, 요약 부분은 P2 e2e(DF-310)에서 검증 | 없음(스파인 coverage 노트와 같은 처리) |
| CF-10-11 | 기존 산출물 문서의 'E2E staging'(dfet:docs/deliverables/06_TEST_AND_RELEASE.md:32)은 v1 스테이징 없음(AS-DEV-02)과 다르다 | 에뮬레이터 e2e로 대체 | 없음(기존 문서는 v1 이전 범위) |
| CF-10-12 | 기존 Swift 호환 테스트가 `isSharedWithMember == true`를 기대한다(dfet:trainer_ios/DFETTrainerTests/SoapNoteFirestoreCompatTests.swift:17) | 옮기지 않고 TC-X-XC-02로 대체. `trainer_ios/` 삭제(DF-142) 때 함께 제거 | 없음 |

---

## 23 변경 이력

| 버전 | 날짜 | 변경 요지 | PR | PRD 영향 |
|---|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성(개발 착수 기준) | — | 없음(CF-10-07 줄 번호는 PRD 개정 때 반영 제안) |
| v1.0(릴리스 편집) | 2026-09-24 | 순수 타깃 `swift test`·픽스처 로더 경로를 `Packages/TrainerCore`로 고침(V1-04 §6.2, §3.1·§6.1·§19.4) | — | 없음 |
| v1.0.1(정합 패스 2) | 2026-09-24 | 교차 정합성 조정: 순수 타깃 5개·TrainerCore 테스트 경로(R4), 시드 담당·ID(R2), 픽스처 봉투·레거시 파일 이름을 P0 규약으로, 기대 결과 경로 `soap_legacy/expected_v2/`, XcodeGen zip(R8), docs-and-backlog 명령(TL-01 §6), static-guards 파일명(DF-011), 충돌 ID CF-10-NN(R10), ASM-10-24~26 추가 | — | 없음 |
